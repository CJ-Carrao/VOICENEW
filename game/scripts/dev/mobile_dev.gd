class_name MobileDev
extends RefCounted



static var _loaded: = false
static var _args: = PackedStringArray()


static func args() -> PackedStringArray:
	if _loaded:
		return _args
	_loaded = true
	_args = OS.get_cmdline_user_args()
	if not OS.has_feature("android") or not OS.is_debug_build():
		return _args
	var path: = "user://mobile_dev.json"
	if not FileAccess.file_exists(path):
		return _args
	var file: = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 16384:
		return _args
	var config: Variant = JSON.parse_string(file.get_as_text())
	if config is Dictionary and config.get("args") is Array:
		for argument: Variant in config.args:
			if argument is String and argument.begins_with("--") and argument.length() <= 1024:
				_args.append(argument)
	return _args
