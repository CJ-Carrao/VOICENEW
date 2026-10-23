class_name WorldReplication
extends Node



signal baseline_ready(epoch: int)

var epoch: = 0
var revision: = 0
var stats: = {"batches": 0, "rows": 0, "max_bytes": 0, "rejected": 0, "baselines": 0}
var _world: Match
var _session: NetworkSession
var _ready_epoch: = 0
var _serial: = 0
var _received: = 0
var _elapsed: = 0.0
var _rubble_serial: = 0

var _watched: Dictionary = {}
var _pending: Dictionary = {}

var _pending_blocks: Dictionary = {}

const BLOCKS_PER_ROW: = 2400
var _piles: Dictionary = {}
var _last_piles: Dictionary = {}
var _last_round: Dictionary = {}
var _max_bytes: = 16384
var _hz: = 10.0
var _generation: = -1
var _peer_serials: Dictionary = {}


func _ready() -> void :
	_session = get_parent() as NetworkSession
	process_mode = Node.PROCESS_MODE_ALWAYS
	_session.changed.connect(_on_session_changed)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/network.json"))
	var config: Dictionary = parsed.get("world", {}) if parsed is Dictionary and parsed.get("world") is Dictionary else {}
	var bytes: Variant = config.get("max_batch_bytes")
	var hz: Variant = config.get("state_hz")
	if not _finite_number(bytes) or not _finite_number(hz) or float(bytes) != floorf(float(bytes))\
	or float(bytes) < 4096.0 or float(bytes) > 16384.0 or float(hz) <= 0.0 or float(hz) > 60.0:
		_max_bytes = 0
		return
	_max_bytes = int(bytes)
	_hz = float(hz)


func bind_world(world: Match) -> void :
	if _world == world:
		return
	unbind_world()
	if _max_bytes == 0:
		_session.stop_online("Configuração de mundo em rede indisponível.")
		return
	_world = world
	_world.arena.world_reset.connect(_on_reset)
	_on_reset()


func unbind_world(world: Match = null) -> void :
	if world != null and world != _world:
		return
	if is_instance_valid(_world):
		_world.arena.world_reset.disconnect(_on_reset)
	_unwatch_volumes()
	_world = null
	epoch = 0
	_ready_epoch = 0
	_pending.clear()
	_pending_blocks.clear()
	_piles.clear()
	_last_piles.clear()
	_peer_serials.clear()


func is_ready_for_epoch(value: int) -> bool:
	return is_instance_valid(_world) and value > 0 and value == _ready_epoch



func _on_reset() -> void :
	_unwatch_volumes()
	_pending.clear()
	_pending_blocks.clear()
	_piles.clear()
	_last_piles.clear()
	if _session.has_authority():
		revision += 1
	for volume: BlockVolume in _volumes().values():
		var callback: = _on_cells.bind(volume)
		volume.cells_changed.connect(callback)
		_watched[volume] = callback


func _unwatch_volumes() -> void :
	for volume: Object in _watched:
		if is_instance_valid(volume) and (volume as BlockVolume).cells_changed.is_connected(_watched[volume]):
			(volume as BlockVolume).cells_changed.disconnect(_watched[volume])
	_watched.clear()



func _volumes() -> Dictionary:
	var out: = {}
	if is_instance_valid(_world):
		for node in _world.get_tree().get_nodes_in_group(BlockVolume.GROUP):
			var volume: = node as BlockVolume
			if volume != null and _world.is_ancestor_of(volume):
				out[volume.volume_id] = volume
	return out




func _on_cells(changes: Dictionary, volume: BlockVolume) -> void :
	var waiting: Dictionary = _pending_blocks.get_or_add(volume.volume_id, {})
	for index: int in changes:
		waiting[index] = int(changes[index])



static func block_rows(volume_id: int, changes: Dictionary) -> Array:
	var rows: Array = []
	var indices: = PackedInt32Array()
	var types: = PackedByteArray()
	for index: int in changes:
		indices.append(index)
		types.append(int(changes[index]))
		if indices.size() >= BLOCKS_PER_ROW:
			rows.append(["k", volume_id, indices, types])
			indices = PackedInt32Array()
			types = PackedByteArray()
	if not indices.is_empty():
		rows.append(["k", volume_id, indices, types])
	return rows


func _collect_piles() -> Array:
	var current: = {}
	var changes: Array = []
	for node in get_tree().get_nodes_in_group(Rubble.GROUP):
		var pile: = node as Rubble
		if pile.is_queued_for_deletion() or not _world.arena.destructibles.is_ancestor_of(pile):
			continue
		if pile.network_id == 0:
			_rubble_serial += 1
			pile.network_id = _rubble_serial
		var row: = pile.network_state()
		current[pile.network_id] = row
		if _last_piles.get(pile.network_id, []) != row:
			changes.append(["r", row])
	for id: int in _last_piles:
		if not current.has(id):
			changes.append(["d", id])
	_last_piles = current
	return changes




func prepare_epoch(value: int, peer: int) -> void :
	if not _session.has_authority() or not is_instance_valid(_world):
		return
	if epoch != value:
		epoch = value
		_peer_serials.clear()
	_peer_serials[peer] = 0
	_ready_epoch = value


	for volume: BlockVolume in _volumes().values():
		volume.flush()
	_collect_piles()
	_send(peer, "begin", [])
	var rows: Array = []
	for volume: BlockVolume in _volumes().values():
		rows.append_array(block_rows(volume.volume_id, volume.network_changes))
	for row: Array in _last_piles.values():
		rows.append(["r", row])
	_send_rows(peer, rows)
	_send(peer, "end", [])
	_pending.clear()
	_pending_blocks.clear()
	stats.baselines += 1


func _process(delta: float) -> void :
	if not is_instance_valid(_world) or not _session.has_authority() or not _session.replication.is_active():
		return
	_elapsed += delta
	if _elapsed < 1.0 / _hz:
		return
	_elapsed = 0.0
	var rows: Array = _pending.values()
	_pending.clear()
	for id: int in _pending_blocks:
		rows.append_array(block_rows(id, _pending_blocks[id]))
	_pending_blocks.clear()
	rows.append_array(_collect_piles())
	var round_changed: = _world.export_round_state() != _last_round
	for peer: int in _session.remote_peer_ids():
		_send_rows(peer, rows)
		if round_changed: _send(peer, "state", [])


func _send_rows(peer: int, rows: Array) -> void :
	var batch: Array = []
	var bytes: = 0
	for row: Array in rows:
		var size: = var_to_bytes(row).size()
		if bytes + size > _max_bytes - 2048 and not batch.is_empty():
			_send(peer, "rows", batch)
			batch = []
			bytes = 0
		batch.append(row)
		bytes += size
	if not batch.is_empty():
		_send(peer, "rows", batch)


func _send(peer: int, kind: String, rows: Array) -> void :
	if peer <= 1: return
	_peer_serials[peer] = int(_peer_serials.get(peer, 0)) + 1
	_serial = int(_peer_serials[peer])
	_last_round = _world.export_round_state()
	var packet: = {"epoch": epoch, "revision": revision, "seq": _serial, "kind": kind, "rows": rows, 
		"round": _last_round}
	var bytes: = var_to_bytes(packet).size()
	assert (bytes <= _max_bytes)
	stats.max_bytes = maxi(stats.max_bytes, bytes)
	stats.batches += 1
	stats.rows += rows.size()
	_receive.rpc_id(peer, packet)


@rpc("authority", "call_remote", "reliable", 0)
func _receive(packet: Dictionary) -> void :
	if _session.has_authority() or multiplayer.get_remote_sender_id() != 1 or not _session.is_ready() or not is_instance_valid(_world):
		return
	if not valid_packet(packet, _max_bytes):
		stats.rejected += 1
		return
	var incoming: = int(packet.get("epoch", 0))
	var kind: = str(packet.get("kind", ""))
	if kind == "begin" and incoming > epoch:
		epoch = incoming
		_ready_epoch = 0
		_received = 0
		_session.replication.suspend_for_world()
		_world.arena.reset_world()
		revision = int(packet.revision)
	if incoming != epoch or int(packet.revision) != revision or int(packet.get("seq", 0)) != _received + 1:
		stats.rejected += 1
		return
	_received = int(packet.seq)
	var blocks: Dictionary = {}
	for row: Array in packet.rows:
		match str(row[0]):
			"k":
				var target: Dictionary = blocks.get_or_add(int(row[1]), {})
				var indices: PackedInt32Array = row[2]
				var types: PackedByteArray = row[3]
				for i in indices.size():
					target[indices[i]] = types[i]
			"r":
				var values: Array = row[1]
				var id: = int(values[0])
				var pile: = _piles.get(id) as Rubble
				if not is_instance_valid(pile):
					pile = Rubble.new()
					_world.arena.destructibles.add_child(pile)
					_piles[id] = pile
				pile.apply_network_state(values)
			"d":
				var pile: = _piles.get(int(row[1])) as Rubble
				if is_instance_valid(pile): pile.queue_free()
				_piles.erase(int(row[1]))
	if not blocks.is_empty():
		var volumes: = _volumes()
		for id: int in blocks:
			var volume: = volumes.get(id) as BlockVolume
			if volume != null:
				volume.apply_network_cells(blocks[id])
	_world.apply_round_state(packet.round)
	if kind == "end":
		_ready_epoch = epoch
		baseline_ready.emit(epoch)


func request_rematch() -> void :
	if not is_instance_valid(_world) or _world.state != "match_over" or not _session.replication.is_active():
		return
	if _session.has_authority():
		_world.start_match()
	else:
		_rematch.rpc_id(1, epoch)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rematch(value: int) -> void :
	if _session.has_authority() and _session.player_for_peer(multiplayer.get_remote_sender_id()) > 1 and value == epoch:
		request_rematch()


func _on_session_changed() -> void :
	if _generation != _session.generation:
		_generation = _session.generation
		epoch = 0
		_ready_epoch = 0
		_received = 0
		_peer_serials.clear()
	for peer: int in _peer_serials.keys():
		if not _session.remote_peer_ids().has(peer): _peer_serials.erase(peer)




static func valid_packet(packet: Dictionary, max_bytes: int = 16384) -> bool:
	if packet.size() != 6 or var_to_bytes(packet).size() > max_bytes:
		return false
	for key in ["epoch", "revision", "seq"]:
		if not packet.get(key) is int or int(packet[key]) <= 0:
			return false
	if packet.get("kind") not in ["begin", "rows", "end", "state"] or not packet.get("rows") is Array:
		return false
	if packet.kind == "begin" and packet.seq != 1:
		return false
	if packet.kind != "rows" and not packet.rows.is_empty():
		return false
	var round_data: Variant = packet.get("round")
	if not round_data is Dictionary or round_data.size() != 6:
		return false
	if round_data.get("state") not in ["session", "countdown", "online_play", "round_over", "match_over"]:
		return false
	if not round_data.get("number") is int or int(round_data.number) < 0 or not round_data.get("winner") is int or int(round_data.winner) < 0 or int(round_data.winner) > 4:
		return false
	if not round_data.get("score") is Dictionary or round_data.score.is_empty() or round_data.score.size() > 4:
		return false
	for id: Variant in round_data.score:
		if not id is int or id < 1 or id > 4 or not round_data.score[id] is int or int(round_data.score[id]) < 0:
			return false
	if int(round_data.winner) != 0 and not round_data.score.has(int(round_data.winner)): return false
	for key in ["countdown", "intermission"]:
		if not _finite_number(round_data.get(key)) or float(round_data[key]) < 0.0:
			return false
	for row: Variant in packet.rows:
		if not row is Array or row.is_empty():
			return false
		match row[0]:
			"k":

				if row.size() != 4 or not row[1] is int or row[1] < 1 or row[1] > 1024 or not row[2] is PackedInt32Array or not row[3] is PackedByteArray or row[2].size() != row[3].size() or row[2].size() > BLOCKS_PER_ROW:
					return false
				for index: int in row[2]:
					if index < 0 or index > 50000000:
						return false
			"r":
				if row.size() != 2 or not row[1] is Array or row[1].size() != 4:
					return false
				var pile: Array = row[1]
				if not pile[0] is int or pile[0] <= 0 or not pile[1] is Vector3 or not pile[1].is_finite() or not _finite_number(pile[2]) or pile[2] <= 0.0 or not pile[3] is Dictionary or pile[3].size() > 32:
					return false
				for material: Variant in pile[3]:
					if not material is String or material.length() > 64 or not _finite_number(pile[3][material]) or float(pile[3][material]) < 0.0:
						return false
			"d":
				if row.size() != 2 or not row[1] is int or row[1] <= 0:
					return false
			_: return false
	return true


static func _finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))
