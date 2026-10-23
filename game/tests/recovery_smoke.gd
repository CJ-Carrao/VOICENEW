extends SceneTree

var failures: Array[String] = []
var scripts_loaded := 0
var scenes_loaded := 0
var json_loaded := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		push_error(description)


func _walk(path: String) -> void:
	for file in DirAccess.get_files_at(path):
		var full := path.path_join(file)
		if file.ends_with(".gd") and not full.begins_with("res://tests/"):
			_check(load(full) is GDScript, "Cannot load script: " + full)
			scripts_loaded += 1
		elif file.ends_with(".tscn"):
			_check(load(full) is PackedScene, "Cannot load scene: " + full)
			scenes_loaded += 1
		elif file.ends_with(".json"):
			var parser := JSON.new()
			_check(parser.parse(FileAccess.get_file_as_string(full)) == OK, "Invalid JSON: " + full)
			json_loaded += 1
	for folder in DirAccess.get_directories_at(path):
		if not folder.begins_with(".") and path.path_join(folder) not in ["res://voice", "res://licenses"]:
			_walk(path.path_join(folder))


func _run() -> void:
	await process_frame
	_walk("res://")
	_check(scripts_loaded >= 160, "Recovered gameplay scripts are missing")
	_check(scenes_loaded == 10, "Expected 10 recovered scenes")
	var lexicon = root.get_node("Lexicon")
	_check(lexicon.data.errors.is_empty(), "Lexicon has loading errors")
	_check(lexicon.data.phrases.size() >= 1461, "Recovered lexicon entries are missing")
	var parsed := []
	for phrase in ["pistola", "espada", "quero uma parede", "bazuca", "katana", "granada", "quero uma formiga", "quero tres formigas", "formiguinha"]:
		var result := PhraseParser.parse(phrase, lexicon.data)
		_check(bool(result.get("ok", false)), "Parser rejected: " + phrase)
		_check(result.get("unknown_words", []).is_empty(), "Unknown words in: " + phrase)
		parsed.append({"phrase": phrase, "ok": result.get("ok"), "recipe": result.get("recipe")})
	_check(ProjectSettings.get_setting("application/config/custom_user_dir_name") == "LAVOICE-Lab", "User data must be isolated")
	var report := {"scripts_loaded": scripts_loaded, "scenes_loaded": scenes_loaded, "json_loaded": json_loaded, "phrases": parsed, "failures": failures}
	var report_path := ProjectSettings.globalize_path("res://").path_join("../analysis/recovery-smoke.json").simplify_path()
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  "))
	print("RECOVERY_SMOKE ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
