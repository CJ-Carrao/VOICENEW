extends Node




const CONFIG_PATH: = "res://data/network_diagnostics.json"
const EVENT_KINDS: = ["auth_started", "auth_rejected", "auth_failed", "peer_joined", "peer_left", "failure"]
const REASONS: = ["none", "timeout", "incompatible", "invalid_request", "transport", "closed", "unavailable", "other"]
const COUNTERS: = {
	"players": ["input_packets", "input_rejected", "event_packets", "event_rejected", "snapshots_sent", "snapshots_received", "stale_packets", "epochs", "snapshot_parts_sent", "snapshot_parts_rejected", "max_input_payload_bytes", "max_snapshot_chunk_bytes", "prediction_reconciliations", "prediction_revision_resets", "prediction_corrections", "prediction_correction_total_m", "prediction_correction_max_m", 
		"input_starved_ticks", "input_catch_up_frames", "input_lost_frames", "input_dropped_frames", "input_neutral_steps", 
		"input_event_waits", "input_late_events"], 
	"creations": ["requests", "confirms", "cancels", "rejected", "spawns", "states_sent", "states_applied"], 
	"world": ["batches", "rows", "max_bytes", "rejected", "baselines"], 
	"voice": ["sent_packets", "sent_bytes", "received_packets", "received_bytes", "played_samples", "rejected", "stale_packets", "lost_packets", "plc_frames", "dropped_overflow", "underruns", "max_packet_bytes", "relayed_packets"], 
	"lobby": ["rejected_packets", "states_received", "launches"], 
}

class ErrorCounts extends Logger:
	var _mutex: = Mutex.new()
	var _enabled: = false
	var _counts: = {"engine": 0, "script": 0, "shader": 0, "warning": 0}
	var _recent: Array[Dictionary] = []
	func enable(value: bool) -> void :
		_mutex.lock()
		_enabled = value
		_mutex.unlock()
	func take() -> Dictionary:
		_mutex.lock()
		var result: = {"counts": _counts.duplicate(), "recent": _recent.duplicate(true)}
		for key in _counts: _counts[key] = 0
		_recent.clear()
		_mutex.unlock()
		return result
	func _log_error(_function: String, source: String, line: int, code: String, rationale: String, 
			_editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void :
		_mutex.lock()
		if _enabled:
			var key: = "engine"
			if error_type == ERROR_TYPE_SCRIPT: key = "script"
			elif error_type == ERROR_TYPE_SHADER: key = "shader"
			elif error_type == ERROR_TYPE_WARNING: key = "warning"
			_counts[key] += 1
			var filename: = source.replace("\\", "/").get_file().left(80)
			var safe_name: = ""
			for character in filename:
				if character in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-": safe_name += character
			if safe_name.get_extension() not in ["gd", "gdc", "cpp", "h"]: safe_name = "unknown"
			if _recent.size() >= 8: _recent.pop_front()
			_recent.append({"kind": key, "source": safe_name, "line": maxi(0, line), 
				"fingerprint": (code.left(2048) + "\n" + rationale.left(2048)).sha256_text().left(16)})
		_mutex.unlock()
	func _log_message(_message: String, _error: bool) -> void : pass

var session_id: = ""
var attempt_id: = ""
var _session: Node
var _enabled: = true
var _directory: = "user://network_logs"
var _config: = {"sample_seconds": 2.0, "max_file_bytes": 2097152, "max_files": 8, "max_frame_samples": 512, "max_record_bytes": 16384}
var _file: FileAccess
var _path: = ""
var _part: = 0
var _error_code: Error = OK
var _attempt_generation: = -1
var _started_ms: = 0
var _sample_ms: = 0
var _last_frame_us: = 0
var _frames: = PackedFloat64Array()
var _frame_count: = 0
var _frame_total_ms: = 0.0
var _frame_max_ms: = 0.0
var _last_state: Dictionary = {}
var _errors: = ErrorCounts.new()
var _error_totals: = {"engine": 0, "script": 0, "shader": 0, "warning": 0}
var _metadata: Dictionary = {}


func _ready() -> void :
	_session = get_parent()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_enabled = bool(UserSettings.get_value("network", "diagnostics", true))
	_load_config()
	OS.add_logger(_errors)
	_session.changed.connect(_on_state_changed)
	_session.lobby.changed.connect(_on_state_changed)
	_session.replication.active_changed.connect(_on_state_changed)


func _exit_tree() -> void :
	finish("application_exit")
	OS.remove_logger(_errors)


func _load_config() -> void :
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if not parsed is Dictionary: return
	var bounds: = {"sample_seconds": [0.5, 60.0], "max_file_bytes": [65536, 8388608], "max_files": [2, 32], "max_frame_samples": [32, 2048], "max_record_bytes": [4096, 32768]}
	for key in bounds:
		var value: Variant = parsed.get(key)
		if not (value is int or value is float) or not is_finite(float(value)): continue
		_config[key] = clampf(float(value), float(bounds[key][0]), float(bounds[key][1])) if key == "sample_seconds" else clampi(int(value), int(bounds[key][0]), int(bounds[key][1]))


func is_enabled() -> bool:
	return _enabled


func set_enabled(value: bool) -> void :
	if _enabled == value: return
	if not value: finish("disabled")
	_enabled = value
	UserSettings.set_value("network", "diagnostics", value)
	if value and _session.is_online() and _session.state not in ["failed", "disconnected"]:
		_open_attempt()


func folder_path() -> String:
	return ProjectSettings.globalize_path(_directory)


func open_folder() -> Error:
	var result: = _ensure_directory()
	if result != OK: return result
	return OS.shell_open(folder_path())


func status() -> Dictionary:
	return {"enabled": _enabled, "path": folder_path(), "logging": _file != null, "error_code": _error_code}


func begin_attempt() -> void :
	finish("replaced")
	_attempt_generation = int(_session.generation)
	attempt_id = Crypto.new().generate_random_bytes(16).hex_encode()
	session_id = Crypto.new().generate_random_bytes(16).hex_encode() if _session._role == "host" else ""
	_started_ms = Time.get_ticks_msec()
	_part = 0
	_error_code = OK
	_last_state.clear()
	_error_totals = {"engine": 0, "script": 0, "shader": 0, "warning": 0}
	_errors.take()
	if _enabled: _open_attempt()


func adopt_session_id(value: Variant) -> void :
	if not value is String or value.length() != 32 or not value.is_valid_hex_number(false): return
	if _session._role != "client" or not session_id.is_empty(): return
	session_id = value.to_lower()
	_record("correlated", {})


func _open_attempt() -> void :
	if attempt_id.is_empty(): return
	if not _open_part(): return
	_errors.enable(true)
	_reset_frames()
	var intro: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/intro.json"))
	var build: = str(intro.get("menu", {}).get("build_label", "")) if intro is Dictionary else ""
	var valid_build: = ""
	for character in build.left(32):
		if character in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 .-_": valid_build += character
	var manifest: Dictionary = _session.compatibility
	var content: String = str(manifest.get("content", ""))
	if content.length() != 64 or not content.is_valid_hex_number(false): content = ""
	_metadata = {"build": valid_build, "protocol": SessionCompatibility.PROTOCOL_VERSION, 
		"gameplay": SessionCompatibility.GAMEPLAY_VERSION, "engine": Engine.get_version_info().string, 
		"content": content, "headless": DisplayServer.get_name() == "headless", 
		"counter_scope": "process_lifetime", "sample_seconds": float(_config.sample_seconds)}
	_record("begin", {})
	_on_state_changed()


func note_event(kind: String, code: String = "none", player_id: int = 0) -> void :
	if kind not in EVENT_KINDS: return
	_record(kind, {"code": code if code in REASONS else "other", "player": player_id if player_id in [1, 2, 3, 4] else 0})



func reason_code(reason: String) -> String:
	var lower: = reason.to_lower()
	if "tempo" in lower or "timeout" in lower: return "timeout"
	if "incompat" in lower or "mesma versão" in lower: return "incompatible"
	if "inválid" in lower or "argument" in lower: return "invalid_request"
	if "encerr" in lower or "desconect" in lower: return "closed"
	if "indispon" in lower or "godotsteam" in lower: return "unavailable"
	if "conex" in lower or "conectar" in lower: return "transport"
	return "other"


func finish(reason: String = "closed") -> void :
	if _file != null:
		capture_sample()
		_record("end", {"code": reason if reason in ["closed", "replaced", "offline", "failed", "disconnected", "disabled", "application_exit"] else "other"})
		if _file != null: _file.close()
		_file = null
	_errors.enable(false)


func _process(_delta: float) -> void :
	if _file == null: return
	var now: = Time.get_ticks_usec()
	if _last_frame_us > 0:
		var elapsed_ms: = float(now - _last_frame_us) / 1000.0
		if _frames.size() < int(_config.max_frame_samples): _frames.append(elapsed_ms)
		else: _frames[_frame_count % int(_config.max_frame_samples)] = elapsed_ms
		_frame_count += 1
		_frame_total_ms += elapsed_ms
		_frame_max_ms = maxf(_frame_max_ms, elapsed_ms)
	_last_frame_us = now
	if Time.get_ticks_msec() - _sample_ms >= int(float(_config.sample_seconds) * 1000.0): capture_sample()


func _on_state_changed() -> void :
	if _file == null: return
	var current: = _state()
	if current != _last_state:
		_last_state = current.duplicate(true)
		_record("state", current)
	if _session.state in ["failed", "disconnected", "offline"]: finish(str(_session.state))


func _state() -> Dictionary:
	return {"state": str(_session.state), "player": int(_session.local_player_id), 
		"players": _session.player_ids() if _session.is_online() else [], "roster_revision": int(_session.roster_revision), 
		"phase": str(_session.lobby.phase), "lobby_epoch": int(_session.lobby.epoch), 
		"ready": _session.lobby.ready_players.duplicate(), "votes": _session.lobby.vote_players.duplicate(), 
		"transition_locked": bool(_session.lobby.transition_locked), "match_committed": bool(_session.lobby.launch_committed), 
		"replication_active": bool(_session.replication.is_active()), "replication_epoch": int(_session.replication.epoch)}


func capture_sample() -> void :
	if _file == null: return
	var error_snapshot: = _errors.take()
	for key in _error_totals: _error_totals[key] += int(error_snapshot.counts.get(key, 0))
	var ordered: = _frames.duplicate()
	ordered.sort()
	var perf: = {"fps": float(Engine.get_frames_per_second()), "frame_count": _frame_count, 
		"frame_mean_ms": _frame_total_ms / _frame_count if _frame_count > 0 else 0.0, 
		"frame_p95_ms": ordered[mini(ordered.size() - 1, int(ceil(ordered.size() * 0.95)) - 1)] if not ordered.is_empty() else 0.0, 
		"frame_max_ms": _frame_max_ms, "sampled_frames": ordered.size(), 
		"process_work_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 
		"physics_work_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 
		"static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)), 
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))}
	var counters: = {}
	var sources: Dictionary = {"players": _session.replication.stats, "creations": _session.creations.stats, 
		"world": _session.world_sync.stats, "voice": _session.voice_sync.stats, "lobby": _session.lobby.stats}
	for group in COUNTERS: counters[group] = _numbers(sources[group], COUNTERS[group])
	var speakers: = {}
	for player_id in _session.player_ids():
		speakers[str(player_id)] = _numbers(_session.voice_sync.speaker_stats(player_id), ["packets", "played_samples", "sequence", "queued_frames"])
	_record("sample", {"performance": perf, "counters": counters, "speakers": speakers, 
		"enet": _enet_metrics(), "errors": _error_totals.duplicate(), "recent_errors": error_snapshot.recent, 
		"window_ms": Time.get_ticks_msec() - _sample_ms})
	_reset_frames()


func _numbers(source: Dictionary, keys: Array) -> Dictionary:
	var result: = {}
	for key in keys:
		var value: Variant = source.get(key)
		if (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0:
			result[key] = mini(int(value), 9007199254740991) if value is int else minf(float(value), 9.00719925474099e+15)
	return result


func _enet_metrics() -> Dictionary:
	var result: = {"available": false, "scope": "enet_reliable_packets_estimate", "peers": []}
	if not _session._peer is ENetMultiplayerPeer: return result
	for peer_id: int in _session.remote_peer_ids():
		var peer: ENetPacketPeer = (_session._peer as ENetMultiplayerPeer).get_peer(peer_id)
		if peer == null or peer.get_state() != ENetPacketPeer.STATE_CONNECTED: continue
		var loss_epoch: = peer.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS_EPOCH)
		result.peers.append({"player": _session.player_for_peer(peer_id), 
			"rtt_ms": peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME), 
			"rtt_variance_ms": peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME_VARIANCE), 
			"reliable_loss_available": loss_epoch > 0.0, 
			"reliable_packet_loss_ratio": peer.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS) / ENetPacketPeer.PACKET_LOSS_SCALE if loss_epoch > 0.0 else null})
	result.available = not result.peers.is_empty()
	return result


func _reset_frames() -> void :
	_frames.clear()
	_frame_count = 0
	_frame_total_ms = 0.0
	_frame_max_ms = 0.0
	_sample_ms = Time.get_ticks_msec()
	_last_frame_us = Time.get_ticks_usec()


func _open_part() -> bool:
	if _file != null: _file.close()
	_file = null
	_error_code = _ensure_directory()
	if _error_code != OK: return false
	if not _prune_files(int(_config.max_files) - 1):
		_error_code = ERR_CANT_CREATE
		return false
	_part += 1
	_path = _directory.path_join("net-%d-%s-p%04d.jsonl" % [_started_ms, attempt_id, _part])
	_file = FileAccess.open(_path, FileAccess.WRITE)
	if _file == null:
		_error_code = FileAccess.get_open_error()
		return false
	return true


func _ensure_directory() -> Error:


	var path: = folder_path().simplify_path()
	var missing: Array[String] = []
	while not DirAccess.dir_exists_absolute(path):
		if FileAccess.file_exists(path): return ERR_CANT_CREATE
		var parent: = path.get_base_dir()
		if parent == path or parent.is_empty() or missing.size() >= 64: return ERR_INVALID_PARAMETER
		missing.append(path)
		path = parent
	missing.reverse()
	for directory in missing:
		var result: = DirAccess.make_dir_absolute(directory)
		if result != OK: return result
	return OK


func _prune_files(keep: int) -> bool:
	var dir: = DirAccess.open(_directory)
	if dir == null: return false
	var files: Array[Dictionary] = []
	for filename in dir.get_files():
		if not filename.begins_with("net-") or not filename.ends_with(".jsonl"): continue
		var path: = _directory.path_join(filename)
		files.append({"path": path, "modified": FileAccess.get_modified_time(path)})
	files.sort_custom( func(a: Dictionary, b: Dictionary): return a.modified < b.modified if a.modified != b.modified else a.path < b.path)
	var remaining: = files.size()
	while remaining > keep and not files.is_empty():
		var candidate: Dictionary = files.pop_front()

		if DirAccess.remove_absolute(candidate.path) == OK: remaining -= 1
	return remaining <= keep


func _record(kind: String, payload: Dictionary) -> void :
	if _file == null: return
	var row: = {"schema": 1, "utc_ms": int(Time.get_unix_time_from_system() * 1000.0), 
		"elapsed_ms": Time.get_ticks_msec() - _started_ms, "attempt_id": attempt_id, "session_id": session_id, 
		"generation": _attempt_generation, "role": "host" if _session._role == "host" else "client", 
		"transport": "steam" if _session.transport.kind == "steam" else "enet", "event": kind, "meta": _metadata, "data": payload}
	var line: = (JSON.stringify(row) + "\n").to_utf8_buffer()
	if line.size() > int(_config.max_record_bytes) or line.size() > int(_config.max_file_bytes):
		_error_code = ERR_OUT_OF_MEMORY
		return
	if _file.get_position() + line.size() > int(_config.max_file_bytes):
		if not _open_part(): return
	_file.store_buffer(line)
	_file.flush()
	_error_code = _file.get_error()
	if _error_code != OK:
		_file.close()
		_file = null
		_errors.enable(false)
