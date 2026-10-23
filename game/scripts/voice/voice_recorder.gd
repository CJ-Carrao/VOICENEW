class_name VoiceRecorder
extends Node





signal prompt_changed(text: String)

const PHRASES_PATH: = "res://tests/voice_phrases.json"
const DATASET_ROOT: = "user://voice_dataset"

var folder: String = ""
var _phrases: Array = []
var _samples: Array = []


func start(voice: VoiceInput, count: int) -> void :
	var all: Array = JSON.parse_string(FileAccess.get_file_as_string(PHRASES_PATH))["phrases"]
	_phrases = all.slice(0, count)
	var stamp: = Time.get_datetime_string_from_system().replace("-", "").replace(":", "").replace("T", "_")
	folder = "mic_" + stamp
	DirAccess.make_dir_recursive_absolute(_dir())
	voice.heard.connect(_on_heard)
	_prompt()


func _unhandled_input(event: InputEvent) -> void :
	if event is InputEventKey and event.is_pressed() and not event.is_echo()\
	and (event as InputEventKey).physical_keycode == KEY_BACKSPACE and not _samples.is_empty():
		_samples.pop_back()
		_write_index()
		_prompt()
		get_viewport().set_input_as_handled()


func _on_heard(samples: PackedFloat32Array) -> void :
	if _samples.size() >= _phrases.size():
		return
	var file: = "%02d.wav" % _samples.size()
	_save_wav(_dir().path_join(file), samples)
	_samples.append({"file": file, "text": _phrases[_samples.size()]})
	_write_index()
	_prompt()


func _prompt() -> void :
	if _samples.size() >= _phrases.size():
		prompt_changed.emit("GRAVAÇÃO PRONTA: %d frases em voice_dataset/%s\n(Backspace refaz a última)" % [_samples.size(), folder])
		print("[Voz] gravação pronta: ", ProjectSettings.globalize_path(_dir()))
		return
	prompt_changed.emit("GRAVANDO SUA VOZ %d/%d · segure %s e diga:\n“%s”" % [_samples.size() + 1, _phrases.size(), 
		UserSettings.talk_key_name(), _phrases[_samples.size()]])


func _write_index() -> void :
	var index: = FileAccess.open(_dir().path_join("index.json"), FileAccess.WRITE)
	index.store_string(JSON.stringify({"voice": "microfone", "samples": _samples}, "  "))
	index.close()


func _dir() -> String:
	return DATASET_ROOT.path_join(folder)


static func _save_wav(path: String, samples: PackedFloat32Array) -> void :
	SpeechEngine.to_wav(samples).save_to_wav(path)
