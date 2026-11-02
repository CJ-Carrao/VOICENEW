class_name VoiceDiagnostics
extends RefCounted






const DIRECTORY: = "user://voice_logs"
const PREFIX: = "diagnostico-voz-"
const MAX_FILE_BYTES: = 1024 * 1024
const MAX_FILES: = 6

static var _file: FileAccess

static var _mutex: = Mutex.new()
static var _started_ms: = 0
static var _full: = false

static var _repeats: Dictionary = {}



static func current_text(max_bytes: int = 60000) -> String:
	_mutex.lock()
	var path: = _file.get_path() if _file != null else ""
	if _file != null:
		_file.flush()
	_mutex.unlock()
	if path.is_empty():
		return ""
	var text: = FileAccess.get_file_as_string(path)
	return text if text.length() <= max_bytes else """[…]
""" + text.right(max_bytes)



static func note(category: String, message: String) -> void :
	_mutex.lock()
	_note_locked(category, message)
	_mutex.unlock()


static func _note_locked(category: String, message: String) -> void :
	if not _ensure_open() or _full:
		return
	var line: = "[%8.2f] %-6s %s" % [(Time.get_ticks_msec() - _started_ms) / 1000.0, category, message]
	if _file.get_length() + line.length() > MAX_FILE_BYTES:
		_file.store_line("[arquivo cheio: o resto desta execução não foi registrado]")
		_full = true
	else:
		_file.store_line(line)
	_file.flush()




static func note_repeat(key: String, category: String, message: String, every: int = 10) -> void :
	_mutex.lock()
	var count: = int(_repeats.get(key, 0)) + 1
	_repeats[key] = count
	_mutex.unlock()
	if count == 1 or count % every == 0:
		note(category, "%s (x%d)" % [message, count])


static func folder_path() -> String:
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	return ProjectSettings.globalize_path(DIRECTORY)



static func current_path() -> String:
	return _file.get_path_absolute() if _file != null else ""


static func _ensure_open() -> bool:
	if _file != null:
		return true
	if DirAccess.make_dir_recursive_absolute(DIRECTORY) != OK:
		return false
	_prune()
	var stamp: = Time.get_datetime_string_from_system().replace(":", "-")
	_file = FileAccess.open("%s/%s%s-%d.txt" % [DIRECTORY, PREFIX, stamp, OS.get_process_id()], FileAccess.WRITE)
	if _file == null:
		return false
	_started_ms = Time.get_ticks_msec()
	_header()
	return true



static func _header() -> void :
	_file.store_line("LAVOICE · diagnóstico da voz · %s" % Time.get_datetime_string_from_system(false, true))
	_file.store_line("Sem áudio e sem as palavras faladas: só eventos e números do microfone e do reconhecedor.")
	var version: Dictionary = Engine.get_version_info()
	var intro: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/intro.json"))
	var build: = str(intro.get("menu", {}).get("build_label", "?")) if intro is Dictionary else "?"
	_file.store_line("%s · Godot %s · %s %s · %s" % [build, version.get("string", "?"), OS.get_name(), OS.get_version(), 
		OS.get_locale()])
	_file.store_line("cpu %s (%d núcleos) · vídeo %s · %s · %s" % [OS.get_processor_name(), OS.get_processor_count(), 
		RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version(), 
		RenderingServer.get_current_rendering_method()])
	_file.store_line("saída %s · mix_rate %d · input_mix_rate %d · latência %.1f ms · saídas %s" % [AudioServer.output_device, 
		AudioServer.get_mix_rate(), AudioServer.get_input_mix_rate(), AudioServer.get_output_latency() * 1000.0, 
		AudioServer.get_output_device_list()])
	_file.store_line("microfones %s · escolhido %s · entrada ligada no projeto: %s" % [AudioServer.get_input_device_list(), 
		AudioServer.input_device, ProjectSettings.get_setting("audio/driver/enable_input", false)])
	_file.store_line("---")
	_file.flush()



static func _prune() -> void :
	var names: Array[String] = []
	for name in DirAccess.get_files_at(DIRECTORY):
		if name.begins_with(PREFIX) and name.ends_with(".txt"):
			names.append(name)
	names.sort()
	while names.size() >= MAX_FILES:
		DirAccess.remove_absolute("%s/%s" % [DIRECTORY, names.pop_front()])
