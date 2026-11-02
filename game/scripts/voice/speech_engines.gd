class_name SpeechEngines
extends RefCounted




const CONFIG_PATH: = "res://data/voice.json"



static func load_config() -> Dictionary:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if OS.has_feature("android"):
		return {"engine": "android", "language": "pt-BR", "hotwords": true, "max_record_s": config.get("max_record_s", 8.0)}
	return VoicePaths.resolve_config(config)



static func installed(config: Dictionary = {}) -> bool:
	var chosen: = config if not config.is_empty() else load_config()
	if OS.has_feature("android"):
		return AndroidSpeechEngine.new().is_available(chosen)
	return FileAccess.file_exists(String(chosen.get("model", "")))


static func create(id: String, platform: String = "") -> SpeechEngine:

	if (OS.get_name() if platform.is_empty() else platform) == "Android":
		return AndroidSpeechEngine.new()
	match id:
		"sherpa":
			return SherpaEngine.new()
	return null
