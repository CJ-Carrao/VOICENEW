class_name SoundBank
extends RefCounted





const FOLDER: = "res://assets/sfx"
const CONFIG: = "res://data/sfx.json"
const EXTENSIONS: = ["ogg", "wav", "mp3"]

static var _files: Dictionary = {}
static var _scanned: = false
static var _cfg: Dictionary = {}
static var _turn: Dictionary = {}
static var _last_ms: Dictionary = {}



static func stream(id: String, variant: int = -1) -> AudioStream:
	_scan()
	var paths: Array = _files.get(id, [])
	if paths.is_empty():
		return null
	var index: = variant
	if index < 0:
		index = int(_turn.get(id, 0))
		_turn[id] = index + 1
	var loaded: = load(paths[posmod(index, paths.size())]) as AudioStream
	if loaded != null and not loaded.has_meta("sfx_db"):
		loaded.set_meta("sfx_db", float(_entry(id).get("db", 0.0)))
		if id.ends_with("_loop"):

			if loaded is AudioStreamWAV:
				var wav: = loaded as AudioStreamWAV
				wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
				wav.loop_begin = 0
				wav.loop_end = int(wav.get_length() * wav.mix_rate)
			elif "loop" in loaded:
				loaded.set("loop", true)
	return loaded


static func has(id: String) -> bool:
	_scan()
	return _files.has(id)



static func is_sound(audio: AudioStream, id: String) -> bool:
	if audio == null:
		return false
	_scan()
	if (_files.get(id, []) as Array).has(audio.resource_path):
		return true
	return not has(id) and audio == FeelSounds.fallback_for(id)



static func pick(id: String, fallback: AudioStream, variant: int = -1) -> AudioStream:
	var found: = stream(id, variant)
	return found if found != null else fallback



static func gain(audio: AudioStream) -> float:
	return float(audio.get_meta("sfx_db", 0.0)) if audio != null else 0.0



static func pitch(id: String) -> float:
	var spread: = float(_entry(id).get("pitch_var", 0.0))
	return 1.0 + randf_range( - spread, spread) if spread > 0.0 else 1.0



static func allow(id: String) -> bool:
	var interval: = int(_entry(id).get("min_interval_ms", 0))
	var now: = Time.get_ticks_msec()
	if interval > 0 and now - int(_last_ms.get(id, -100000)) < interval:
		return false
	_last_ms[id] = now
	return true



static func play_at(parent: Node, id: String, at: Vector3, volume_db: float = 0.0, fallback: AudioStream = null, 
		pitch_scale: float = 1.0) -> void :
	if parent == null or not parent.is_inside_tree() or not allow(id):
		return
	var audio: = pick(id, fallback)
	if audio == null:
		return
	var player: = AudioStreamPlayer3D.new()
	player.bus = AudioMix.bus(AudioMix.EFFECTS)
	player.stream = audio
	player.volume_db = volume_db + gain(audio)
	player.pitch_scale = pitch_scale * pitch(id)
	player.unit_size = float(_entry(id).get("unit_size", 6.0))
	player.max_distance = float(_entry(id).get("max_distance", 0.0))
	parent.add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()



static func play_flat(parent: Node, id: String, volume_db: float = 0.0, fallback: AudioStream = null, 
		bus: StringName = AudioMix.EFFECTS, pitch_scale: float = 1.0) -> void :
	if parent == null or not parent.is_inside_tree() or not allow(id):
		return
	var audio: = pick(id, fallback)
	if audio == null:
		return
	var player: = AudioStreamPlayer.new()
	player.bus = AudioMix.bus(bus)
	player.stream = audio
	player.volume_db = volume_db + gain(audio)
	player.pitch_scale = pitch_scale * pitch(id)
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


static func _entry(id: String) -> Dictionary:
	if _cfg.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG)) if FileAccess.file_exists(CONFIG) else null
		_cfg = parsed.get("sounds", {}) if parsed is Dictionary else {"_": {}}
	return _cfg.get(id, {})


static func _scan() -> void :
	if _scanned:
		return
	_scanned = true
	_scan_dir(FOLDER, "")


static func _scan_dir(path: String, prefix: String) -> void :
	if not DirAccess.dir_exists_absolute(path):
		return
	var names: = ResourceLoader.list_directory(path)
	names.sort()
	for name: String in names:
		if name.begins_with("_") or name.begins_with("."):
			continue
		if name.ends_with("/"):
			_scan_dir(path.path_join(name.trim_suffix("/")), prefix + name)
			continue
		if not EXTENSIONS.has(name.get_extension().to_lower()):
			continue
		var base: = name.get_basename()

		var cut: = base.rfind("_")
		if cut > 0 and base.substr(cut + 1).is_valid_int():
			base = base.substr(0, cut)
		(_files.get_or_add(prefix + base, []) as Array).append(path.path_join(name))
