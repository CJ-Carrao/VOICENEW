extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func _run() -> void:
	await process_frame
	var lex = root.get_node("Lexicon").data
	var parser = load("res://scripts/language/phrase_parser.gd")
	var assembler = load("res://scripts/things/assembler.gd")
	var voice = load("res://scripts/voice/voice_vocabulary.gd")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chaos_catalog.json"))
	var checked := []
	for entry in catalog.creations:
		var result: Dictionary = parser.parse("quero " + String(entry.name), lex)
		_check(result.get("ok", false), "Cannot parse: " + entry.name)
		_check(String(result.get("recipe", {}).get("thing", "")) == entry.id, "Wrong recipe for: " + entry.name)
		if not result.get("ok", false):
			continue
		var item = assembler.build(result.recipe, "head", lex)
		_check(item.unsupported.is_empty(), "Unsupported behavior: " + entry.name + " " + str(item.unsupported))
		_check(item.model_pieces.size() == int(entry.pieces), "Model pieces missing: " + entry.name)
		_check(item.model_pieces.size() > 3, "Placeholder model: " + entry.name)
		_check(item.bounds.size.is_finite() and item.bounds.size.length() > 0.05, "Invalid bounds: " + entry.name)
		_check(item.max_hp > 0 and lex.thing_statf(entry.id, "cost") > 0, "Invalid stats: " + entry.name)
		for piece in lex.models[entry.id].pieces:
			_check(piece.shape == "box", "Non-block shape in new model: " + entry.name)
		checked.append(entry.id)
		item.free()
	for phrase in ["quero uma granada que explode em formigas", "quero uma granada que explode em galinhas", "quero uma granada que exploda seis formigas", "quero uma bomba de neutrons", "quero uma bomba hipotetica de gravidade", "quero uma faca que corte o espaço", "quero três capivaras", "quero um dragão gigante"]:
		var parsed: Dictionary = parser.parse(phrase, lex)
		_check(parsed.get("ok", false) and parsed.get("unknown_words", []).is_empty(), "Composition failed: " + phrase + " " + str(parsed))
	_check(voice.hotwords(lex).has("capivara"), "New vocabulary missing from speech recognition")
	_check(voice.hotwords(lex).has("faça") and voice.hotwords(lex).has("use"), "Creative composition verbs missing from voice vocabulary")
	_check(lex.errors.is_empty(), "Lexicon errors: " + str(lex.errors))
	var colloquial: Dictionary = parser.parse("quero uma granada que exploda seis formigas", lex)
	var burst: Dictionary = colloquial.recipe.behaviors[0].do
	_check(burst.type == "burst_into" and burst.arg.thing == "ant" and int(burst.arg.mods.count) == 6, "Colloquial creature explosion lost its payload")
	var plain: Dictionary = parser.parse("quero uma granada que explode depois de três segundos", lex)
	_check(plain.recipe.behaviors[0].do.type == "explode", "Normal timed grenade syntax regressed")
	var ui = root.get_node("CreationCatalog")
	_check(not ui.panel.visible, "Catalog must start closed")
	ui.toggle()
	_check(ui.panel.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "F2 catalog did not open")
	ui._populate("Bombas especiais")
	_check(ui.entries.get_child_count() == 12, "Bomb catalog is incomplete")
	ui.toggle()
	_check(not ui.panel.visible, "Catalog did not close")
	var report := {"checked": checked.size(), "ids": checked, "failures": failures, "phrases": lex.phrases.size()}
	var path := ProjectSettings.globalize_path("res://").path_join("../analysis/chaos-catalog.json").simplify_path()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("CHAOS_CATALOG ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
