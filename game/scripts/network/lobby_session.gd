class_name LobbySession
extends Node



signal changed
signal match_requested

signal paints_changed

const MAX_SEQUENCE: = 2147483647
const MAX_REQUEST_LEAD: = 64
const TRANSITION_SECONDS: = 2.2
const MAX_COLOR: = 16777215

const MAPS_PATH: = "res://data/world/maps.json"

var ready_players: Dictionary = {1: false, 2: false, 3: false, 4: false}
var vote_players: Dictionary = {1: false, 2: false, 3: false, 4: false}

var map_votes: Dictionary = {1: 0, 2: 0, 3: 0, 4: 0}


var chosen_map: int = -1


var selected_colors: Dictionary = {1: -1, 2: -1, 3: -1, 4: -1}

var player_paints: Dictionary = {1: PackedByteArray(), 2: PackedByteArray(), 3: PackedByteArray(), 4: PackedByteArray()}
var launch_committed: = false
var synchronized: = false
var phase: = "characters"
var epoch: = 0

var presentation_seed: = 0
var transition_locked: bool:
	get: return _transition_waiting
var transition_remaining: float:
	get: return maxf(0.0, float(_transition_deadline_ms - Time.get_ticks_msec()) / 1000.0) if _transition_waiting else 0.0
var stats: Dictionary = {"rejected_packets": 0, "states_received": 0, "launches": 0}

var _session: NetworkSession
var _generation: = -1
var _epoch_counter: = 0
var _revision: = 0
var _last_revision: = 0
var _request_sequence: = 0
var _last_remote_request: Dictionary = {}
var _known_roster: Dictionary = {}
var _transition_waiting: = false
var _transition_deadline_ms: = 0
var _match_entered: = false
var _presentation_rng: = RandomNumberGenerator.new()
var _allowed_colors: Dictionary = {}


func _ready() -> void :
	_session = get_parent() as NetworkSession
	process_mode = Node.PROCESS_MODE_ALWAYS
	_presentation_rng.randomize()
	_load_color_palette()
	_session.changed.connect(_on_session_changed)
	_on_session_changed()


func _process(_delta: float) -> void :
	if _session.has_authority() and _transition_waiting and Time.get_ticks_msec() >= _transition_deadline_ms:
		_transition_waiting = false
		_transition_deadline_ms = 0
		if phase == "characters": _session.set_join_allowed( not _match_entered)
		_publish()


func all_ready() -> bool:
	if not _available() or not synchronized or _match_entered:
		return false
	var players: = _session.player_ids()
	if players.size() < 2 or players.size() > NetworkSession.MAX_PLAYERS:
		return false
	if not _colors_valid(selected_colors, ready_players): return false
	for player_id: int in players:
		if not bool(ready_players.get(player_id, false)): return false
	return true


func all_voted() -> bool:
	if not all_ready() or phase != "arena": return false
	for player_id: int in _session.player_ids():
		if not bool(vote_players.get(player_id, false)): return false
	return true


func set_local_ready(value: bool) -> void :
	_submit_action("ready", value)


func color_count() -> int:
	return _allowed_colors.size()


func _load_color_palette() -> void :
	_allowed_colors.clear()
	var presets: Variant = RobotBody.config().get("player_colors", [])
	if not presets is Array: return
	for preset: Variant in presets:
		if not preset is String or not Color.html_is_valid(preset): continue
		_allowed_colors[RobotColor.to_rgb24(Color.html(preset))] = true


func color_for_player(player_id: int) -> int:
	if not synchronized or not _session.player_ids().has(player_id): return -1
	return int(selected_colors.get(player_id, -1))



func color_owner(rgb24: int) -> int:
	if not synchronized or not _allowed_colors.has(rgb24): return 0
	for player_id: int in _session.player_ids():
		if int(selected_colors.get(player_id, -1)) == rgb24: return player_id
	return 0




func set_local_color(rgb24: int) -> bool:
	return _submit_action("color", rgb24)



func paint_for_player(player_id: int) -> PackedByteArray:
	if not synchronized or not _session.player_ids().has(player_id): return PackedByteArray()
	return player_paints.get(player_id, PackedByteArray())


func set_local_paint(bytes: PackedByteArray) -> bool:
	return _submit_action("paint", bytes)


static func max_paint_bytes() -> int:
	return int(RobotPaint.config().get("max_net_bytes", 196608))


static func paint_bytes_valid(value: Variant) -> bool:
	if not value is PackedByteArray: return false
	var bytes: = value as PackedByteArray
	return bytes.is_empty() or (bytes.size() <= max_paint_bytes() and not RobotPaint.decode(bytes).is_empty())





func mark_match_entered() -> void :
	if not _available(): return
	_match_entered = true
	_transition_waiting = false
	_transition_deadline_ms = 0
	if _session.has_authority(): _session.set_join_allowed(false)
	changed.emit()


func set_local_vote(value: bool) -> void :
	_submit_action("vote", value)



func set_local_map(index: int) -> bool:
	return _submit_action("map", index)


static func map_ids() -> Array[String]:
	var out: Array[String] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAPS_PATH))
	if parsed is Dictionary:
		for map: Variant in (parsed as Dictionary).get("maps", []):
			if map is Dictionary: out.append(String((map as Dictionary).get("id", "original")))
	if out.is_empty(): out.append("original")
	return out



func chosen_map_id() -> String:
	var ids: = map_ids()
	return ids[chosen_map] if chosen_map >= 0 and chosen_map < ids.size() else ""



func _resolve_map() -> int:
	var counts: = {}
	for player_id: int in _session.player_ids():
		var index: = int(map_votes.get(player_id, 0))
		counts[index] = int(counts.get(index, 0)) + 1
	var best: = 0
	var tied: Array[int] = []
	for index: int in counts:
		if int(counts[index]) > best:
			best = int(counts[index])
			tied = [index]
		elif int(counts[index]) == best:
			tied.append(index)
	if tied.is_empty(): return 0
	tied.sort()
	return tied[presentation_seed % tied.size()]


func request_arena() -> bool:

	return false


func request_characters() -> bool:
	return _submit_action("characters", null)



func can_start() -> bool:
	return false


func request_start() -> bool:
	return request_arena()


func _submit_action(action: String, value: Variant) -> bool:
	if not _available() or not synchronized or launch_committed or _match_entered: return false
	var player_id: = _session.local_player_id
	if not _action_allowed(player_id, action, value): return false
	if _session.has_authority():
		return _apply_action(player_id, action, value)
	_request_sequence += 1
	_action.rpc_id(1, _generation, epoch, _request_sequence, action, value)
	return true


func _action_allowed(player_id: int, action: String, value: Variant) -> bool:
	if not _session.player_ids().has(player_id) or launch_committed or _match_entered: return false


	if action == "ready" and value is bool and not bool(value):
		return phase in ["characters", "arena"]
	if action == "characters" and value == null:
		return phase == "arena" or (phase == "characters" and transition_locked)
	if transition_locked: return false
	match action:
		"color":
			return phase == "characters" and value is int and int(value) >= -1 and int(value) <= MAX_COLOR\
			and (int(value) == -1 or (_allowed_colors.has(int(value)) and color_owner(int(value)) in [0, player_id]))
		"ready":
			return phase == "characters" and value is bool\
			and ( not bool(value) or color_for_player(player_id) >= 0)
		"vote": return phase == "arena" and not transition_locked and value is bool
		"map":
			return phase == "arena" and value is int and int(value) >= 0 and int(value) < map_ids().size()\
			and not bool(vote_players.get(player_id, false))
		"paint":
			return phase == "characters" and not bool(ready_players.get(player_id, false)) and paint_bytes_valid(value)
	return false


func _apply_action(player_id: int, action: String, value: Variant) -> bool:
	if not _action_allowed(player_id, action, value): return false
	match action:
		"color":
			if int(selected_colors[player_id]) == int(value): return true


			selected_colors[player_id] = int(value)
			ready_players[player_id] = false
		"ready":
			if bool(ready_players[player_id]) == bool(value): return true
			ready_players[player_id] = bool(value)
			if not bool(value) and phase == "arena":
				_return_to_characters()
			elif bool(value) and all_ready():
				_enter_arena()
		"vote":
			if bool(vote_players[player_id]) == bool(value): return true
			vote_players[player_id] = bool(value)
			if all_voted():
				chosen_map = _resolve_map()
				launch_committed = true
				phase = "versus"
		"map":
			if int(map_votes[player_id]) == int(value): return true
			map_votes[player_id] = int(value)
		"characters":
			if phase == "characters" and not bool(ready_players[player_id]): return true
			ready_players[player_id] = false
			if phase == "arena": _return_to_characters()
		"paint":
			if player_paints[player_id] == value: return true
			player_paints[player_id] = (value as PackedByteArray).duplicate()
			_send_paint(player_id)
			paints_changed.emit()
			return true
	_publish()
	if launch_committed:
		stats.launches += 1
		match_requested.emit()
	return true


func _enter_arena() -> void :
	var next_seed: = _presentation_rng.randi_range(1, MAX_SEQUENCE)
	if next_seed == presentation_seed: next_seed = next_seed % MAX_SEQUENCE + 1
	presentation_seed = next_seed
	phase = "arena"
	vote_players = _empty_flags()
	map_votes = _empty_maps()
	chosen_map = -1
	_begin_transition()


func _return_to_characters() -> void :
	phase = "characters"
	vote_players = _empty_flags()
	map_votes = _empty_maps()
	chosen_map = -1


	_begin_transition()


func _begin_transition() -> void :
	_transition_waiting = true
	_transition_deadline_ms = Time.get_ticks_msec() + int(TRANSITION_SECONDS * 1000.0)
	_session.set_join_allowed(false)


func _available() -> bool:
	return _session.is_online() and _session.state in ["hosting", "ready"]


func _empty_flags() -> Dictionary:
	return {1: false, 2: false, 3: false, 4: false}


func _empty_maps() -> Dictionary:
	return {1: 0, 2: 0, 3: 0, 4: 0}


func _empty_colors() -> Dictionary:
	return {1: -1, 2: -1, 3: -1, 4: -1}


func _colors_valid(colors: Variant, ready: Dictionary) -> bool:
	if not colors is Dictionary or colors.size() != NetworkSession.MAX_PLAYERS: return false
	var used: = {}
	for player_id in range(1, NetworkSession.MAX_PLAYERS + 1):
		var rgb24: Variant = colors.get(player_id)
		if not rgb24 is int or int(rgb24) < -1 or int(rgb24) > MAX_COLOR: return false
		if int(rgb24) >= 0 and not _allowed_colors.has(int(rgb24)): return false
		if _session.peer_for_player(player_id) == 0 and int(rgb24) != -1: return false
		if bool(ready.get(player_id, false)) and int(rgb24) < 0: return false
		if int(rgb24) >= 0:
			if used.has(rgb24): return false
			used[rgb24] = player_id
	return true


func _on_session_changed() -> void :
	var new_generation: = _generation != _session.generation
	if new_generation or not _available(): _match_entered = false
	var roster_changed: = _known_roster != _session.roster
	var previous_roster: = _known_roster
	var departed: = false
	for player_id: int in _known_roster:
		if int(_known_roster[player_id]) > 0 and int(_known_roster[player_id]) != _session.peer_for_player(player_id):
			departed = true
	if new_generation or not _available():
		_reset()
		_generation = _session.generation
	_known_roster = _session.roster.duplicate()
	if not _available():
		changed.emit()
		return
	if _session.has_authority():
		if new_generation or roster_changed or epoch == 0:
			if departed:
				ready_players = _empty_flags()
			for player_id in range(1, NetworkSession.MAX_PLAYERS + 1):
				if _session.peer_for_player(player_id) == 0 or int(previous_roster.get(player_id, 0)) != _session.peer_for_player(player_id):
					ready_players[player_id] = false
					selected_colors[player_id] = -1
					player_paints[player_id] = PackedByteArray()
			vote_players = _empty_flags()
			map_votes = _empty_maps()
			chosen_map = -1
			launch_committed = false
			phase = "characters"
			presentation_seed = 0
			_transition_waiting = false
			_transition_deadline_ms = 0
			_epoch_counter += 1
			epoch = _epoch_counter
			_revision = 0
			_last_remote_request.clear()
			synchronized = true
			_session.set_join_allowed( not _match_entered)
			_publish()

			for player_id: int in _session.player_ids():
				if not (player_paints[player_id] as PackedByteArray).is_empty(): _send_paint(player_id)
			paints_changed.emit()
	else:
		if new_generation or roster_changed:
			_reset()
			_generation = _session.generation
			_known_roster = _session.roster.duplicate()
	changed.emit()


func _reset() -> void :
	ready_players = _empty_flags()
	vote_players = _empty_flags()
	map_votes = _empty_maps()
	chosen_map = -1
	selected_colors = _empty_colors()
	for player_id: int in player_paints: player_paints[player_id] = PackedByteArray()
	launch_committed = false
	synchronized = false
	phase = "characters"
	epoch = 0
	presentation_seed = 0
	_revision = 0
	_last_revision = 0
	_request_sequence = 0
	_last_remote_request.clear()
	_transition_waiting = false
	_transition_deadline_ms = 0


@rpc("any_peer", "call_remote", "reliable", 0)
func _action(client_generation: int, packet_epoch: int, sequence: int, action: String, value: Variant) -> void :
	var sender: = multiplayer.get_remote_sender_id()
	var player_id: = _session.player_for_peer(sender)
	var last: = int(_last_remote_request.get(sender, 0))
	if not _available() or not _session.has_authority() or sender <= 1 or player_id <= 1\
	or packet_epoch != epoch or client_generation != _session.generation_for_peer(sender)\
	or sequence <= last or sequence > MAX_SEQUENCE or sequence - last > MAX_REQUEST_LEAD\
	or action not in ["color", "ready", "vote", "characters", "paint", "map"]:
		stats.rejected_packets += 1
		return
	_last_remote_request[sender] = sequence
	if not _apply_action(player_id, action, value): stats.rejected_packets += 1


func _send_paint(player_id: int) -> void :
	for peer_id: int in _session.remote_peer_ids():
		_receive_paint.rpc_id(peer_id, _session.generation_for_peer(peer_id), epoch, player_id, player_paints[player_id])


@rpc("any_peer", "call_remote", "reliable", 0)
func _receive_paint(client_generation: int, packet_epoch: int, player_id: int, bytes: PackedByteArray) -> void :
	if not _available() or _session.has_authority() or _session.state != "ready" or multiplayer.get_remote_sender_id() != 1 or client_generation != _generation or not synchronized or packet_epoch != epoch or not _session.player_ids().has(player_id) or not paint_bytes_valid(bytes):
		stats.rejected_packets += 1
		return
	player_paints[player_id] = bytes
	paints_changed.emit()


func _publish() -> void :
	_revision += 1
	var packet: = {
		"epoch": epoch, "revision": _revision, "roster_revision": _session.roster_revision, 
		"phase": phase, "ready": ready_players, "votes": vote_players, "launched": launch_committed, 
		"transition_ms": ceili(transition_remaining * 1000.0), 
		"presentation_seed": presentation_seed, 
		"colors": selected_colors, 
		"maps": map_votes, "map": chosen_map, 
	}
	for peer_id: int in _session.remote_peer_ids():
		_receive_state.rpc_id(peer_id, _session.generation_for_peer(peer_id), packet)
	changed.emit()


@rpc("any_peer", "call_remote", "reliable", 0)
func _receive_state(client_generation: int, packet: Dictionary) -> void :
	if not _available() or _session.has_authority() or _session.state != "ready"\
	or multiplayer.get_remote_sender_id() != 1 or client_generation != _generation\
	or not _valid_state(packet):
		stats.rejected_packets += 1
		return
	epoch = int(packet.epoch)
	_last_revision = int(packet.revision)
	phase = str(packet.phase)
	presentation_seed = int(packet.presentation_seed)
	ready_players = packet.ready.duplicate()
	vote_players = packet.votes.duplicate()
	map_votes = packet.maps.duplicate()
	chosen_map = int(packet.map)
	selected_colors = packet.colors.duplicate()
	synchronized = true
	_transition_waiting = int(packet.transition_ms) > 0
	_transition_deadline_ms = Time.get_ticks_msec() + int(packet.transition_ms)
	var launch_now: = bool(packet.launched) and not launch_committed
	launch_committed = bool(packet.launched)
	stats.states_received += 1
	changed.emit()
	if launch_now:
		stats.launches += 1
		match_requested.emit()


func _valid_state(packet: Dictionary) -> bool:
	if packet.size() != 12 or var_to_bytes(packet).size() > 2048: return false
	var map_count: = map_ids().size()
	var maps: Variant = packet.get("maps")
	if not maps is Dictionary or (maps as Dictionary).size() != NetworkSession.MAX_PLAYERS: return false
	for player_id in range(1, NetworkSession.MAX_PLAYERS + 1):
		var index: Variant = (maps as Dictionary).get(player_id)
		if not index is int or int(index) < 0 or int(index) >= map_count: return false
	if not packet.get("map") is int or int(packet.map) < -1 or int(packet.map) >= map_count\
	or (int(packet.map) >= 0) != (packet.get("phase") == "versus"):
		return false
	for key in ["epoch", "revision", "roster_revision", "transition_ms", "presentation_seed"]:
		if not packet.get(key) is int or int(packet[key]) < 0 or int(packet[key]) > MAX_SEQUENCE: return false
	if int(packet.epoch) <= 0 or int(packet.revision) <= _last_revision\
	or (epoch != 0 and int(packet.epoch) != epoch)\
	or int(packet.roster_revision) != _session.roster_revision\
	or packet.get("phase") not in ["characters", "arena", "versus"]\
	or not packet.get("launched") is bool\
	or bool(packet.launched) != (packet.phase == "versus")\
	or (launch_committed and not bool(packet.launched))\
	or int(packet.transition_ms) > int(TRANSITION_SECONDS * 1000.0)\
	or (int(packet.transition_ms) > 0 and packet.phase not in ["characters", "arena"]):
		return false
	if packet.phase in ["arena", "versus"] and int(packet.presentation_seed) == 0: return false


	if synchronized and not (phase == "characters" and packet.phase == "arena")\
	and int(packet.presentation_seed) != presentation_seed:
		return false
	for field in ["ready", "votes"]:
		var flags: Variant = packet.get(field)
		if not flags is Dictionary or flags.size() != NetworkSession.MAX_PLAYERS: return false
		for player_id in range(1, NetworkSession.MAX_PLAYERS + 1):
			if not flags.get(player_id) is bool: return false
			if _session.peer_for_player(player_id) == 0 and flags[player_id]: return false
	if not _colors_valid(packet.get("colors"), packet.ready): return false
	if synchronized and (phase != "characters" or packet.phase != "characters") and packet.colors != selected_colors:
		return false
	var everyone_ready: = _session.player_ids().size() >= 2
	for player_id: int in _session.player_ids():
		if not packet.ready[player_id]: everyone_ready = false
		if packet.phase == "characters" and packet.votes[player_id]: return false
		if synchronized and packet.colors[player_id] != selected_colors[player_id]\
		and (packet.ready[player_id] or transition_locked or int(packet.transition_ms) > 0): return false
		if packet.phase in ["arena", "versus"] and not packet.ready[player_id]: return false
		if packet.phase == "versus" and not packet.votes[player_id]: return false
	if packet.phase == "characters" and everyone_ready: return false
	if packet.phase != "characters" and _session.player_ids().size() < 2: return false
	return true
