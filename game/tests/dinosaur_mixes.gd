extends SceneTree

const DINOS := ["trex", "triceratops", "stegosaurus", "brachiosaurus", "spinosaurus", "ankylosaurus", "parasaurolophus", "diplodocus"]
var failures := []
var evidence := {}

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	await process_frame
	var lex = root.get_node("Lexicon").data
	var parser = load("res://scripts/language/phrase_parser.gd")
	var assembler = load("res://scripts/things/assembler.gd")
	var costs = load("res://scripts/language/cost.gd")
	var cases := [
		["eu quero um elefante com cara de cachorro", "elephant", "head", "dog"],
		["eu quero um cachorro com cara de tiranossauro rex", "dog", "head", "trex"],
		["quero um cachorro com rosto de t-rex", "dog", "head", "trex"],
		["quero um pato com cabeça de tricerátops", "duck", "head", "triceratops"],
		["quero um elefante com corpo de espinossauro", "elephant", "body", "spinosaurus"],
		["quero um cachorro com patas de braquiossauro", "dog", "legs", "brachiosaurus"],
		["quero um cachorro com cauda de anquilossauro", "dog", "tail", "ankylosaurus"],
		["quero um tiranossauro rex com cara de cachorro", "trex", "head", "dog"],
		["quero um cachorro com cara de tiranossauro rex com a habilidade do mahoraga", "dog", "head", "trex"],
		["quero um tiranossauro rex com cara de cachorro com uma AK47", "trex", "head", "dog"]
	]
	for row in cases:
		var parsed: Dictionary = parser.parse(row[0], lex)
		check(parsed.get("ok", false) and parsed.get("unknown_words", []).is_empty() and parsed.get("ignored_words", []).is_empty(), "Failed request: " + row[0] + " " + str(parsed))
		var node: Dictionary = parsed.get("recipe", {})
		check(node.get("thing") == row[1] and node.get("mods", {}).get("anatomy", {}).get(row[2]) == row[3], "Wrong anatomy: " + row[0])
		var item = assembler.build(node, "head", lex)
		check(item.unsupported.is_empty(), "Unsupported mixture: " + row[0])
		var donor_pieces := 0
		for piece in item.model_pieces:
			if piece.get_meta("source", "") == row[3]: donor_pieces += 1
			check(piece.transform.origin.is_finite(), "Invalid hybrid geometry")
		check(donor_pieces > 0 and item.bounds.size.is_finite(), "Mixture did not replace actual model pieces: " + row[0])
		check(costs.of(node, lex) > lex.thing_statf(row[1], "cost"), "Mixture did not charge donor anatomy")
		if row[0].contains("mahoraga"): check(item.get_node_or_null("Jujutsu") != null, "Mixed dinosaur lost adaptation")
		if row[0].contains("AK47"): check(not item.grafts.is_empty(), "Mixed dinosaur lost its weapon")
		item.free()
	# Every dinosaur can donate each anatomical section and receive a dog's head.
	var combinations := 0
	for id in DINOS:
		var name: String = lex.defs.things[id].get("category", "")
		check(name == "creature", "Dinosaur is not a real creature: " + id)
		var word_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/lexicon/pt_br/things.json"))[id]
		for section in ["head", "body", "legs", "tail"]:
			var node = load("res://scripts/language/recipe.gd").new_node("dog")
			node.mods.anatomy = {section: id}
			var animal = assembler.build(node, "head", lex)
			var found := false
			for piece in animal.model_pieces:
				if piece.get_meta("source", "") == id: found = true
			check(found and animal.unsupported.is_empty(), "Missing dinosaur section: " + id + "/" + section)
			animal.free()
			combinations += 1
		var parsed: Dictionary = parser.parse("quero um " + word_data.name + " com cara de cachorro", lex)
		check(parsed.recipe.thing == id and parsed.recipe.mods.anatomy.head == "dog", "Reverse mixture failed: " + id)
		var prey: Dictionary = parser.parse("quero um cachorro que só ataque " + word_data.name, lex)
		check(prey.get("ok", false) and prey.recipe.mods.get("diet") == "species:" + id, "Dinosaur species restriction failed: " + id)
	evidence.anatomy_sections_checked = combinations
	# One live hybrid must move and keep the substituted head after activation.
	load("res://scenes/main.gd").next_mode = "practice"
	var game = load("res://scenes/main.tscn").instantiate()
	game.voice_enabled = false
	root.add_child(game)
	current_scene = game
	var hybrid: Dictionary = parser.parse("quero um cachorro com cara de tiranossauro rex", lex).recipe
	var live = assembler.build(hybrid, "head", lex)
	live.set_owner_info(1, 1, game.player, game.player)
	game.add_thing(live)
	live.global_position = Vector3(0,2,0)
	live.activate()
	var start: Vector3 = live.global_position
	for step in 60: await physics_frame
	var distance := Vector2(live.global_position.x - start.x, live.global_position.z - start.z).length()
	check(distance > .1 and not live.is_dead, "Live dinosaur hybrid did not move")
	evidence.live_hybrid_distance_m = distance
	live.remove()
	await process_frame
	var report := {"failures": failures, "evidence": evidence}
	var file := FileAccess.open(ProjectSettings.globalize_path("res://").path_join("../analysis/dinosaur-mixes.json").simplify_path(), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("DINOSAUR_MIXES ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
