class_name VoicePaths
extends RefCounted




static func native_path(path: String) -> String:
	if path.begins_with("res://voice/") and not OS.has_feature("editor"):
		return OS.get_executable_path().get_base_dir().path_join(path.trim_prefix("res://"))
	return path


static func resolve_config(config: Dictionary) -> Dictionary:
	for key in ["model", "model_dir", "sidecar", "denoiser"]:
		if config.has(key):
			config[key] = native_path(String(config[key]))
	return config
