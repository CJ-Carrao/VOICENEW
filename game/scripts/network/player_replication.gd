class_name PlayerReplication
extends Node




signal active_changed

const CONFIG_PATH: = "res://data/network.json"

var epoch: int = 0
var config: Dictionary = {}
var stats: Dictionary = {
	"input_packets": 0, "input_rejected": 0, "event_packets": 0, 
	"event_rejected": 0, "snapshots_sent": 0, "snapshots_received": 0, 
	"stale_packets": 0, "epochs": 0, 
	"snapshot_parts_sent": 0, "snapshot_parts_rejected": 0, 
	"max_input_payload_bytes": 0, "max_snapshot_chunk_bytes": 0, 
	"prediction_reconciliations": 0, "prediction_corrections": 0, 
	"prediction_correction_total_m": 0.0, "prediction_correction_max_m": 0.0, 
	"prediction_revision_resets": 0, 


	"input_starved_ticks": 0, "input_catch_up_frames": 0, "input_lost_frames": 0, "input_dropped_frames": 0, 
	"input_neutral_steps": 0, "input_event_waits": 0, "input_late_events": 0, 
}

var _session: NetworkSession
var _world: Node
var _active: = false
var _scene_token: = 0
var _remote_scene_token: = 0
var _ready_sent_token: = 0
var _remote_peer: = 0
var _session_generation: = -1
var _epoch_counter: = 0
var _baseline_waiting: = false
var _baseline_applied: = false
var _ready_deadline_ms: = 0
var _snapshot_seq: = 0
var _last_snapshot_seq: = 0
var _snapshot_elapsed: = 0.0
var _recent_inputs: Array[Dictionary] = []
var _stream_started_ms: = 0
var _snapshot_assemblies: Dictionary = {}


var _pending_snapshot: Dictionary = {}

var _peers: Dictionary = {}


func _ready() -> void :
	_session = get_parent() as NetworkSession
	process_mode = Node.PROCESS_MODE_ALWAYS

	process_physics_priority = 50
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if parsed is Dictionary:
		config = parsed
		for key in ["snapshot_hz", "input_redundancy", "max_input_packet_bytes", "max_snapshot_bytes", 
				"input_packets_per_second", "input_packet_burst", "event_packets_per_second", "event_packet_burst", 
				"max_sequence_lead", "scene_ready_timeout_seconds"]:
			var value: Variant = config.get(key)
			if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 1.0:
				config = {}
				break
		for key in ["snapshot_chunk_bytes", "max_snapshot_assemblies", "snapshot_assembly_timeout_seconds"]:
			var value: Variant = config.get(key)
			if not (value is int or value is float) or not is_finite(float(value)) or float(value) <= 0.0:
				config = {}
				break
		if not config.is_empty():
			for key in ["snapshot_chunk_bytes", "max_snapshot_assemblies"]:
				var value: = float(config[key])
				if value < 1.0 or value != floorf(value):
					config = {}
					break
		if not config.is_empty() and (int(config.snapshot_chunk_bytes) > 1000 or int(config.max_snapshot_assemblies) > 2):
			config = {}
	_session.changed.connect(_on_session_changed)
	_session.creations.baseline_ready.connect(_on_creation_baseline_ready)
	_session.world_sync.baseline_ready.connect(_on_creation_baseline_ready)
	_on_session_changed()


func is_active() -> bool:
	return _active and _session.is_online() and _session.is_ready() and is_instance_valid(_world)


func bind_world(world: Node) -> void :
	if _world == world:
		return
	unbind_world()
	_world = world
	_scene_token += 1
	_ready_sent_token = 0
	if config.is_empty():
		_session.stop_online("Configuração de rede indisponível.")
		return


	for player_id in _world.player_ids():
		var player: Player = _world.get_player(player_id)
		if player == null:
			continue
		var role: = "offline"
		if _session.is_online():
			role = "authority" if _session.has_authority() else ("predicted" if player_id == _session.local_player_id else "proxy")
		player.configure_network(role)
		player.set_network_active(false, epoch)
		if not player.input_generated.is_connected(_on_local_input):
			player.input_generated.connect(_on_local_input)
	_on_session_changed()


func unbind_world(world: Node = null) -> void :
	if world != null and world != _world:
		return
	if is_instance_valid(_world):
		for player_id in _world.player_ids():
			var player: Player = _world.get_player(player_id)
			if is_instance_valid(player) and player.input_generated.is_connected(_on_local_input):
				player.input_generated.disconnect(_on_local_input)
		if _session.is_online() and _session.is_ready():
			if _session.has_authority():
				for peer: int in _session.remote_peer_ids():
					_suspend.rpc_id(peer, epoch)
			elif not _session.has_authority():
				_scene_not_ready.rpc_id(1, _scene_token)
	_set_active(false)
	_world = null
	_ready_sent_token = 0
	_baseline_waiting = false
	_baseline_applied = false
	for peer: int in _peers:
		_peers[peer].waiting = false
		_peers[peer].acked = false
		_peers[peer].deadline = 0
	_ready_deadline_ms = 0


func _on_session_changed() -> void :
	if _session_generation != _session.generation:
		_session_generation = _session.generation
		epoch = 0
		_remote_scene_token = 0
		_remote_peer = 0
		_ready_sent_token = 0
		_baseline_applied = false
		_peers.clear()
		_reset_streams()
	if not _session.is_online() or not _session.is_ready():
		_set_active(false)
		_remote_peer = 0
		_remote_scene_token = 0
		_ready_sent_token = 0
		_baseline_waiting = false
		_baseline_applied = false
		_ready_deadline_ms = 0
		_peers.clear()
		return
	if _session.has_authority():
		var connected: = _session.remote_peer_ids()
		_remote_peer = int(connected[0]) if not connected.is_empty() else 0
		var added: = false
		for peer: int in _peers.keys():
			if not connected.has(peer): _peers.erase(peer)
		for peer: int in connected:
			if not _peers.has(peer):
				_peers[peer] = _new_peer_state()
				added = true
		if added and is_instance_valid(_world): _invalidate_barrier()
	else:
		_remote_peer = 1
	if not is_instance_valid(_world):
		return


	if not _session.has_authority() and _ready_deadline_ms == 0 and not _active:


		_ready_deadline_ms = Time.get_ticks_msec() + int(float(config.get("scene_ready_timeout_seconds", 15.0)) * 2000.0) + 1000
	if _session.has_authority():
		for peer: int in _peers:
			if (int(_peers[peer].scene_token) == 0 or bool(_peers[peer].waiting)) and int(_peers[peer].deadline) == 0:
				_peers[peer].deadline = _deadline()
		_maybe_begin_baseline()
		_try_start_all()
		_update_ready_deadline()
	elif _ready_sent_token != _scene_token:
		_ready_sent_token = _scene_token
		_scene_ready.rpc_id(1, _scene_token)


func _physics_process(delta: float) -> void :
	_consume_pending_snapshot()
	_expire_snapshot_assemblies()
	if _session.has_authority() and is_instance_valid(_world):
		for peer: int in _peers.keys():
			if not _peers.has(peer): continue
			var deadline: = int(_peers[peer].deadline)
			if deadline > 0 and Time.get_ticks_msec() > deadline:
				_session.reject_peer(peer, "O jogador não concluiu o carregamento da arena.")
		_update_ready_deadline()
	elif _ready_deadline_ms > 0 and not _active and Time.get_ticks_msec() > _ready_deadline_ms:
		_ready_deadline_ms = 0
		if _session.is_online():
			_session.stop_online("Tempo esgotado ao preparar a arena com o host.")
	if not is_active() or not _session.has_authority():
		return
	_snapshot_elapsed += delta
	var interval: = 1.0 / float(config.snapshot_hz)
	if _snapshot_elapsed >= interval:
		_snapshot_elapsed = fmod(_snapshot_elapsed, interval)
		_snapshot_seq += 1
		for peer: int in _session.remote_peer_ids():
			_send_snapshot(_make_snapshot(peer), peer)
		stats.snapshots_sent += 1


@rpc("any_peer", "call_remote", "reliable", 0)
func _scene_ready(scene_token: int) -> void :
	var sender: = multiplayer.get_remote_sender_id()
	if not _valid_remote_sender(sender) or scene_token <= 0 or scene_token > 2147483647:
		return
	if not _peers.has(sender): _peers[sender] = _new_peer_state()
	var state: Dictionary = _peers[sender]
	if scene_token == int(state.scene_token) and (_active or bool(state.waiting) or bool(state.acked)):
		return
	if scene_token < int(state.scene_token):
		stats.stale_packets += 1
		return
	state.scene_token = scene_token
	state.deadline = 0
	_remote_scene_token = scene_token if sender == _remote_peer else _remote_scene_token
	_invalidate_barrier()
	if is_instance_valid(_world): _maybe_begin_baseline()


func _new_peer_state() -> Dictionary:
	return {"scene_token": 0, "waiting": false, "acked": false, "deadline": 0, 
		"event_seq": 0, "input_tokens": float(config.get("input_packet_burst", 120.0)), 
		"event_tokens": float(config.get("event_packet_burst", 120.0)), "budget_ms": Time.get_ticks_msec()}


func _deadline() -> int:
	return Time.get_ticks_msec() + int(float(config.get("scene_ready_timeout_seconds", 15.0)) * 1000.0)


func _update_ready_deadline() -> void :
	_ready_deadline_ms = 0
	for state: Dictionary in _peers.values():
		var deadline: = int(state.deadline)
		if deadline > 0 and (_ready_deadline_ms == 0 or deadline < _ready_deadline_ms):
			_ready_deadline_ms = deadline


func _invalidate_barrier() -> void :
	if _active:
		for peer: int in _session.remote_peer_ids(): _suspend.rpc_id(peer, epoch)
	_set_active(false)
	_baseline_waiting = false
	for state: Dictionary in _peers.values():
		state.waiting = false
		state.acked = false
		if not is_instance_valid(_world) or int(state.scene_token) > 0:
			state.deadline = 0
		elif int(state.deadline) == 0:
			state.deadline = _deadline()


func _maybe_begin_baseline() -> void :
	if _active or _baseline_waiting or not is_instance_valid(_world) or _peers.is_empty(): return
	for state: Dictionary in _peers.values():
		if int(state.scene_token) <= 0: return
	_begin_baseline()


func _begin_baseline() -> void :
	_epoch_counter += 1
	epoch = _epoch_counter
	stats.epochs += 1
	_reset_streams()
	_set_active(false)
	_snapshot_seq = 1
	_baseline_waiting = true
	_ready_deadline_ms = Time.get_ticks_msec() + int(float(config.scene_ready_timeout_seconds) * 1000.0)
	for peer: int in _peers:
		_peers[peer].waiting = true
		_peers[peer].acked = false
		_peers[peer].deadline = _deadline()
		_session.world_sync.prepare_epoch(epoch, peer)
		_session.creations.prepare_epoch(epoch, peer)
		_baseline.rpc_id(peer, _make_snapshot(peer))


@rpc("authority", "call_remote", "reliable", 0)
func _baseline(packet: Dictionary) -> void :
	if _session.has_authority() or not _session.is_ready() or not is_instance_valid(_world):
		return
	if not _valid_snapshot(packet) or int(packet.scene_token) != _scene_token or int(packet.epoch) < epoch:
		stats.stale_packets += 1
		return
	if int(packet.epoch) == epoch and _baseline_applied:
		if _all_baselines_ready():
			_baseline_ack.rpc_id(1, epoch, _scene_token)
		return
	epoch = int(packet.epoch)
	_reset_streams()
	_set_active(false)
	_apply_snapshot(packet, true)
	_baseline_applied = true
	if _all_baselines_ready():
		_baseline_ack.rpc_id(1, epoch, _scene_token)


func _on_creation_baseline_ready(value: int) -> void :
	if not _session.has_authority() and _baseline_applied and value == epoch and _all_baselines_ready():
		_baseline_ack.rpc_id(1, epoch, _scene_token)


@rpc("any_peer", "call_remote", "reliable", 0)
func _baseline_ack(packet_epoch: int, scene_token: int) -> void :
	var sender: = multiplayer.get_remote_sender_id()
	if not _valid_remote_sender(sender) or not _baseline_waiting or not _peers.has(sender):
		return
	if packet_epoch != epoch or scene_token != int(_peers[sender].scene_token) or not is_instance_valid(_world):
		stats.stale_packets += 1
		return
	_peers[sender].waiting = false
	_peers[sender].acked = true
	_peers[sender].deadline = 0
	_try_start_all()
	_update_ready_deadline()


func _try_start_all() -> void :
	if _active or not _baseline_waiting or _peers.is_empty() or not is_instance_valid(_world): return
	for state: Dictionary in _peers.values():
		if not bool(state.acked): return
	_baseline_waiting = false
	for peer: int in _peers:
		_start_play.rpc_id(peer, epoch, int(_peers[peer].scene_token))
	_set_active(true)


@rpc("authority", "call_remote", "reliable", 0)
func _start_play(packet_epoch: int, scene_token: int) -> void :
	if _session.has_authority() or not _baseline_applied or not is_instance_valid(_world):
		return
	if packet_epoch != epoch or scene_token != _scene_token:
		stats.stale_packets += 1
		return
	_set_active(true)


@rpc("any_peer", "call_remote", "reliable", 0)
func _scene_not_ready(scene_token: int) -> void :
	var sender: = multiplayer.get_remote_sender_id()
	if not _valid_remote_sender(sender) or not _peers.has(sender) or scene_token != int(_peers[sender].scene_token):
		return
	_peers[sender].scene_token = 0
	_invalidate_barrier()


@rpc("authority", "call_remote", "reliable", 0)
func _suspend(packet_epoch: int) -> void :
	if packet_epoch == epoch and not _session.has_authority():
		_baseline_applied = false
		_set_active(false)


func _set_active(value: bool) -> void :
	var changed: = _active != value
	_active = value
	if not value:
		_pending_snapshot = {}
	if value:
		_ready_deadline_ms = 0
		if changed:
			_stream_started_ms = Time.get_ticks_msec()
	if is_instance_valid(_world):
		for player_id in _world.player_ids():
			var player: Player = _world.get_player(player_id)
			if is_instance_valid(player):
				player.set_network_active(value and _session.peer_for_player(player_id) > 0, epoch)
	if changed:
		active_changed.emit()


func _reset_streams() -> void :
	_recent_inputs.clear()
	_snapshot_assemblies.clear()
	_pending_snapshot = {}
	_last_snapshot_seq = 0
	_snapshot_seq = 0
	_snapshot_elapsed = 0.0
	_stream_started_ms = Time.get_ticks_msec()
	for state: Dictionary in _peers.values():
		state.event_seq = 0
		state.input_tokens = float(config.get("input_packet_burst", 120.0))
		state.event_tokens = float(config.get("event_packet_burst", 120.0))
		state.budget_ms = _stream_started_ms


func _on_local_input(frame: PlayerInputFrame) -> void :
	if not is_active() or _session.has_authority():
		return

	_recent_inputs.append(frame.movement_only().to_wire())
	while _recent_inputs.size() > int(config.input_redundancy):
		_recent_inputs.pop_front()
	var payload: = encode_packet(_recent_inputs, int(config.max_input_packet_bytes))


	if not payload.is_empty() and payload.size() <= int(config.snapshot_chunk_bytes):
		stats.max_input_payload_bytes = maxi(int(stats.max_input_payload_bytes), payload.size())
		_input_frames.rpc_id(1, epoch, payload)
	if frame.has_events():
		_input_event.rpc_id(1, epoch, frame.event_seq, frame.to_wire())


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _input_frames(packet_epoch: int, payload: PackedByteArray) -> void :
	stats.input_packets += 1
	var sender: = multiplayer.get_remote_sender_id()
	if not _valid_remote_sender(sender) or not is_active() or packet_epoch != epoch:
		stats.input_rejected += 1
		return
	if not _spend_budget(false, sender) or payload.size() > int(config.snapshot_chunk_bytes):
		stats.input_rejected += 1
		return
	var frames: Variant = decode_packet(payload, int(config.max_input_packet_bytes))
	if not frames is Array or frames.is_empty() or frames.size() > int(config.input_redundancy):
		stats.input_rejected += 1
		return
	var player: Player = _world.get_player(_session.player_for_peer(sender))
	if player == null: return
	for wire: Variant in frames:
		var frame: = PlayerInputFrame.from_wire(wire)
		if frame == null or frame.has_events() or frame.event_seq > frame.seq or frame.seq > _maximum_input_sequence():
			stats.input_rejected += 1
			continue
		player.submit_network_input(frame)


@rpc("any_peer", "call_remote", "reliable", 0)
func _input_event(packet_epoch: int, event_seq: int, wire: Dictionary) -> void :
	stats.event_packets += 1
	var sender: = multiplayer.get_remote_sender_id()
	if not _valid_remote_sender(sender) or not is_active() or packet_epoch != epoch or event_seq <= int(_peers.get(sender, {}).get("event_seq", 0)):
		stats.event_rejected += 1
		return
	if not _spend_budget(true, sender) or var_to_bytes(wire).size() > int(config.max_input_packet_bytes):
		stats.event_rejected += 1
		return
	var frame: = PlayerInputFrame.from_wire(wire)
	if frame == null or not frame.has_events() or frame.event_seq != event_seq or event_seq > frame.seq or frame.seq > _maximum_input_sequence():
		stats.event_rejected += 1
		return
	var player: Player = _world.get_player(_session.player_for_peer(sender))
	if player == null: return
	if player.submit_network_event(event_seq, frame):
		_peers[sender].event_seq = event_seq
	else:
		stats.event_rejected += 1


func _valid_remote_sender(peer_id: int) -> bool:
	return _session.is_online() and _session.has_authority() and _session.is_ready() and peer_id > 1 and _session.player_for_peer(peer_id) > 1


func _maximum_input_sequence() -> int:



	var elapsed: = maxf(0.0, float(Time.get_ticks_msec() - _stream_started_ms) / 1000.0)
	return int(elapsed * Engine.physics_ticks_per_second) + int(config.max_sequence_lead)


func _spend_budget(event: bool, peer: int) -> bool:
	if not _peers.has(peer): return false
	var state: Dictionary = _peers[peer]
	var now: = Time.get_ticks_msec()
	var elapsed: = maxf(0.0, float(now - int(state.budget_ms)) / 1000.0)
	state.budget_ms = now
	state.input_tokens = minf(float(config.input_packet_burst), float(state.input_tokens) + elapsed * float(config.input_packets_per_second))
	state.event_tokens = minf(float(config.event_packet_burst), float(state.event_tokens) + elapsed * float(config.event_packets_per_second))
	if event:
		if float(state.event_tokens) < 1.0: return false
		state.event_tokens -= 1.0
	else:
		if float(state.input_tokens) < 1.0: return false
		state.input_tokens -= 1.0
	return true


func _make_snapshot(peer: int = 0) -> Dictionary:
	if peer == 0: peer = _remote_peer
	var states: Array[Dictionary] = []
	var tick: = Engine.get_physics_frames()
	for player_id in _session.player_ids():
		var player: Player = _world.get_player(player_id)
		if player == null: continue
		var state: = player.export_network_state()
		state["player_id"] = player_id
		state["epoch"] = epoch
		state["snapshot_seq"] = _snapshot_seq
		state["server_tick"] = tick
		states.append(state)
	return {"epoch": epoch, "snapshot_seq": _snapshot_seq, "server_tick": tick, "scene_token": int(_peers.get(peer, {}).get("scene_token", _remote_scene_token)), "players": states}


func _snapshot(packet: Dictionary) -> void :
	if _session.has_authority() or not is_active() or not _valid_snapshot(packet):
		return
	if int(packet.epoch) != epoch or int(packet.snapshot_seq) <= _last_snapshot_seq or int(packet.scene_token) != _scene_token:
		stats.stale_packets += 1
		return
	if not _pending_snapshot.is_empty() and int(packet.snapshot_seq) <= int(_pending_snapshot.snapshot_seq):
		stats.stale_packets += 1
		return
	_pending_snapshot = packet


func _consume_pending_snapshot() -> void :
	if _pending_snapshot.is_empty():
		return
	var packet: = _pending_snapshot
	_pending_snapshot = {}

	if _session.has_authority() or not is_active() or int(packet.epoch) != epoch\
	or int(packet.scene_token) != _scene_token or int(packet.snapshot_seq) <= _last_snapshot_seq:
		return
	_apply_snapshot(packet, false)


func _send_snapshot(packet: Dictionary, peer: int = 0) -> void :
	if peer == 0: peer = _remote_peer
	var payload: = encode_packet(packet, int(config.max_snapshot_bytes))
	if payload.is_empty():
		return
	var chunk_bytes: = int(config.snapshot_chunk_bytes)
	var count: = ceili(float(payload.size()) / chunk_bytes)
	for index in count:
		var chunk: = payload.slice(index * chunk_bytes, mini((index + 1) * chunk_bytes, payload.size()))
		_snapshot_part.rpc_id(peer, int(packet.epoch), int(packet.snapshot_seq), index, count, payload.size(), chunk)
		stats.snapshot_parts_sent += 1
		stats.max_snapshot_chunk_bytes = maxi(int(stats.max_snapshot_chunk_bytes), chunk.size())


@rpc("authority", "call_remote", "unreliable", 2)
func _snapshot_part(packet_epoch: int, sequence: int, index: int, count: int, total_bytes: int, chunk: PackedByteArray) -> void :
	if _session.has_authority() or not is_active():
		return
	if packet_epoch != epoch or sequence <= _last_snapshot_seq:
		stats.stale_packets += 1
		return
	var chunk_bytes: = int(config.snapshot_chunk_bytes)
	var maximum: = int(config.max_snapshot_bytes) + 256
	if total_bytes <= 4 or total_bytes > maximum or count != ceili(float(total_bytes) / chunk_bytes) or index < 0 or index >= count:
		stats.snapshot_parts_rejected += 1
		return
	var expected_size: = mini(chunk_bytes, total_bytes - index * chunk_bytes)
	if chunk.size() != expected_size:
		stats.snapshot_parts_rejected += 1
		return
	_expire_snapshot_assemblies()
	if not _snapshot_assemblies.has(sequence):
		if _snapshot_assemblies.size() >= int(config.max_snapshot_assemblies):
			var oldest: = int(_snapshot_assemblies.keys().min())
			if sequence < oldest:
				stats.stale_packets += 1
				return
			_snapshot_assemblies.erase(oldest)
		var parts: Array = []
		parts.resize(count)
		_snapshot_assemblies[sequence] = {"parts": parts, "total": total_bytes, "received": 0, "started": Time.get_ticks_msec()}
	var assembly: Dictionary = _snapshot_assemblies[sequence]
	if int(assembly.total) != total_bytes or assembly.parts.size() != count:
		stats.snapshot_parts_rejected += 1
		return
	if assembly.parts[index] != null:
		return
	assembly.parts[index] = chunk
	assembly.received += 1
	if int(assembly.received) != count:
		return
	var payload: = PackedByteArray()
	for part: PackedByteArray in assembly.parts:
		payload.append_array(part)
	_snapshot_assemblies.erase(sequence)
	var packet: Variant = decode_packet(payload, int(config.max_snapshot_bytes))
	if not packet is Dictionary or packet.get("epoch") != packet_epoch or packet.get("snapshot_seq") != sequence:
		stats.snapshot_parts_rejected += 1
		return
	_snapshot(packet)
	_expire_snapshot_assemblies()


func _expire_snapshot_assemblies() -> void :
	var now: = Time.get_ticks_msec()
	var timeout_ms: = int(float(config.get("snapshot_assembly_timeout_seconds", 0.5)) * 1000.0)
	for sequence: int in _snapshot_assemblies.keys():
		if sequence <= _last_snapshot_seq or now - int(_snapshot_assemblies[sequence].started) > timeout_ms:
			_snapshot_assemblies.erase(sequence)


static func encode_packet(value: Variant, maximum_bytes: int = 65536) -> PackedByteArray:
	var raw: = var_to_bytes(value)
	if raw.is_empty() or raw.size() > maximum_bytes:
		return PackedByteArray()
	var compressed: = raw.compress(FileAccess.COMPRESSION_ZSTD)
	if compressed.is_empty() or compressed.size() > maximum_bytes + 252:
		return PackedByteArray()
	var packet: = PackedByteArray()
	packet.resize(4)
	packet.encode_u32(0, raw.size())
	packet.append_array(compressed)
	return packet


static func decode_packet(packet: PackedByteArray, maximum_bytes: int = 65536) -> Variant:
	if packet.size() <= 4 or packet.size() > maximum_bytes + 256:
		return null
	var raw_size: = packet.decode_u32(0)

	if raw_size <= 0 or raw_size > maximum_bytes:
		return null
	var raw: = packet.slice(4).decompress(raw_size, FileAccess.COMPRESSION_ZSTD)
	if raw.size() != raw_size or not raw.has_encoded_var(0, false) or raw.decode_var_size(0, false) != raw.size():
		return null
	return raw.decode_var(0, false)


func _valid_snapshot(packet: Dictionary) -> bool:
	if packet.size() != 5 or var_to_bytes(packet).size() > int(config.max_snapshot_bytes):
		return false
	for field in ["epoch", "snapshot_seq", "server_tick", "scene_token"]:
		if typeof(packet.get(field)) != TYPE_INT or int(packet[field]) < 0:
			return false
	if packet.epoch == 0 or packet.snapshot_seq == 0 or packet.scene_token == 0:
		return false
	var states: Variant = packet.get("players")
	var ids: = _session.player_ids()
	if not states is Array or states.size() != ids.size():
		return false
	for index in ids.size():
		if not states[index] is Dictionary:
			return false
		if typeof(states[index].get("player_id")) != TYPE_INT or int(states[index].player_id) != ids[index]:
			return false
	return true


func _apply_snapshot(packet: Dictionary, baseline: bool) -> void :
	_last_snapshot_seq = int(packet.snapshot_seq)
	for state: Dictionary in packet.players:
		var player: Player = _world.get_player(int(state.player_id))
		if player == null: continue
		var previous_corrections: = player.network_corrections
		var previous_order: = player._network_last_snapshot
		var revision_reset: = int(state.get("revision", 0)) != player._network_received_revision
		player.receive_authoritative_state(state, baseline)



		if player.network_role != "predicted" or baseline or player._network_last_snapshot == previous_order:
			continue
		if revision_reset:
			stats.prediction_revision_resets += 1
		elif not bool(state.get("rigid", false)):
			stats.prediction_reconciliations += 1
			stats.prediction_corrections += maxi(0, player.network_corrections - previous_corrections)
			stats.prediction_correction_total_m += player.last_correction_distance
			stats.prediction_correction_max_m = maxf(float(stats.prediction_correction_max_m), player.last_correction_distance)
	stats.snapshots_received += 1


func _all_baselines_ready() -> bool:
	return _session.creations.is_ready_for_epoch(epoch) and _session.world_sync.is_ready_for_epoch(epoch)


func restart_round_baseline() -> void :
	if _session.has_authority() and _session.is_ready() and not _peers.is_empty():
		_invalidate_barrier()
		_maybe_begin_baseline()


func suspend_for_world() -> void :
	_set_active(false)
