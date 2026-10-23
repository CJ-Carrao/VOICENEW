class_name SpeechEngines
extends RefCounted




const CONFIG_PATH: = "res://data/voice.json"



static func load_config() -> Dictionary:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	return VoicePaths.resolve_config(config)



static func installed(config: Dictionary = {}) -> bool:
	var chosen: = config if not config.is_empty() else load_config()
	return FileAccess.file_exists(String(chosen.get("model", "")))


static func create(id: String) -> SpeechEngine:
	match id:
		"sherpa":
			return SherpaEngine.new()
	return null
