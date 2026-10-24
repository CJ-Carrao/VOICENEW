extends SceneTree

const IDS := ["tung_sahur", "tralalero", "saturnita", "bombardiro", "udin", "cappuccino_assassino", "ballerina_cappuccina", "patapim", "lirili", "chimpanzini"]
const SPOKEN := ["tung tung sahur", "tralalelo tralala", "vaca saturni sa tinita", "bombardino crocodilo", "udindindum", "capuchino assassino", "balerina capuchinha", "brr brr patapim", "lirili larila", "chimpanzini bananini"]
var failures := []

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
	check(lex.errors.is_empty(), "Lexicon errors: " + str(lex.errors))
	for index in IDS.size():
		var id: String = IDS[index]
		var phrase: String = SPOKEN[index]
		var parsed: Dictionary = parser.parse("quero um " + phrase, lex)
		check(parsed.get("ok", false) and parsed.get("recipe", {}).get("thing") == id and parsed.get("unknown_words", []).is_empty(), "Alias failed: " + phrase)
		var item = assembler.build(parsed.recipe, "head", lex)
		check(item.unsupported.is_empty() and item.model_pieces.size() >= 15, "Invalid model: " + id)
		check(item.bounds.size.is_finite() and item.bounds.size.length() < 7.0, "Invalid size: " + id)
		check(item.get_node_or_null("VoxelCreatureMotion") != null, "Missing animation: " + id)
		check(costs.of(parsed.recipe, lex) >= 70, "Unbalanced cost: " + id)
		item.free()
		for section in ["cara", "corpo", "patas"]:
			var hybrid: Dictionary = parser.parse("quero um cachorro com " + section + " de " + phrase, lex)
			check(hybrid.get("ok", false), "Mixture rejected: " + phrase)
			var animal = assembler.build(hybrid.recipe, "head", lex)
			var donors := 0
			for piece in animal.model_pieces:
				if piece.get_meta("source", "") == id: donors += 1
			# The aircraft has wings instead of legs; its other parts remain usable.
			if id != "bombardiro" or section != "patas": check(donors > 0, "Missing donor geometry: " + id + "/" + section)
			check(animal.unsupported.is_empty(), "Unsupported mixture: " + id)
			animal.free()
		var hunter: Dictionary = parser.parse("quero um cachorro que só ataque " + phrase, lex)
		check(hunter.recipe.mods.get("diet") == "species:" + id, "Missing diet: " + id)
		var bomb: Dictionary = parser.parse("quero uma bomba que mate todos os " + phrase, lex)
		check(bomb.recipe.thing == "species_bomb" and bomb.recipe.mods.get("target_species") == id, "Missing selective bomb target: " + id)
		var powered: Dictionary = parser.parse("quero um " + phrase + " com a habilidade do mahoraga com uma AK47", lex)
		var fighter = assembler.build(powered.recipe, "head", lex)
		check(fighter.get_node_or_null("Jujutsu") != null and not fighter.grafts.is_empty(), "Lost powers or weapon: " + id)
		fighter.free()
	# Real flight/bomb production and capture use the same live entities as animals.
	load("res://scenes/main.gd").next_mode = "practice"
	var game = load("res://scenes/main.tscn").instantiate()
	game.voice_enabled = false
	root.add_child(game)
	current_scene = game
	var bomber = assembler.build(parser.parse("quero um bombardino crocodilo", lex).recipe, "head", lex)
	bomber.set_owner_info(1, 1, game.player, game.player)
	game.add_thing(bomber)
	bomber.global_position = Vector3(0, 5, 0)
	bomber.activate()
	var start: Vector3 = bomber.global_position
	for frame in 310: await physics_frame
	check(is_instance_valid(bomber) and not bomber.is_dead, "Bomber died during flight")
	if is_instance_valid(bomber):
		check(bomber.global_position.distance_to(start) > 1.0, "Bomber did not fly")
		check(bomber.thing_id == "bombardiro", "Bomber lost its species")
		var grenades := 0
		for entity in game.get_node("Things").get_children():
			if is_instance_valid(entity) and entity.thing_id == "grenade": grenades += 1
		check(grenades > 0, "Bomber did not drop its grenade")
		var ball = assembler.build(parser.parse("quero uma pokebola", lex).recipe, "head", lex)
		ball.set_owner_info(1, 1, game.player, game.player)
		game.add_thing(ball)
		ball.activate()
		var catcher = ball.get_node("CaptureBall")
		var identity: int = bomber.get_instance_id()
		check(catcher._attempt(weakref(bomber), 0.0) and bomber.is_captured, "Cannot capture brainrot")
		var released = catcher.release()
		check(is_instance_valid(released) and released.get_instance_id() == identity and not released.is_captured, "Capture did not preserve original brainrot")
		ball.remove()
		bomber.remove()
	print("BRAINROT_PACK ", JSON.stringify({"failures": failures, "characters": IDS.size(), "mixtures": 30}))
	quit(0 if failures.is_empty() else 1)
