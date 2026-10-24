extends SceneTree

const IDS := ["pikachu", "charmander", "squirtle", "bulbasaur"]
const NAMES := ["picachu", "charmander", "squitle", "bulbasaur"]
var failures := []
var game
var parser
var assembler
var forge
var lex

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func spawn(phrase: String, at: Vector3, team: int = 1):
	var item = assembler.build(parser.parse(phrase, lex).recipe, "head", lex)
	item.set_owner_info(team, team, game.get_player(team), null)
	game.add_thing(item)
	item.global_position = at
	item.activate()
	item.set_physics_process(false)
	item.move.set_physics_process(false)
	return item

func _run() -> void:
	await process_frame
	lex = root.get_node("Lexicon").data
	parser = load("res://scripts/language/phrase_parser.gd")
	assembler = load("res://scripts/things/assembler.gd")
	forge = root.get_node("Forge")
	check(lex.errors.is_empty(), "Lexicon errors: " + str(lex.errors))
	for index in IDS.size():
		var parsed: Dictionary = parser.parse("quero um " + NAMES[index], lex)
		check(parsed.get("ok", false) and parsed.recipe.get("thing") == IDS[index], "Creation alias failed: " + NAMES[index])
		var hybrid: Dictionary = parser.parse("quero um cachorro com cara de " + IDS[index] + " com a habilidade do mahoraga", lex)
		var item = assembler.build(hybrid.recipe, "head", lex)
		check(item.unsupported.is_empty() and item.get_node_or_null("PokemonCompanion") != null and item.get_node_or_null("Jujutsu") != null, "Hybrid powers missing: " + IDS[index])
		item.free()
	for command: String in lex.defs.commands:
		if not command.begins_with("pokemon_"): continue
		for phrase: String in lex.lexicon.commands[command].words:
			var parsed: Dictionary = parser.parse(phrase, lex)
			check(parsed.get("ok", false) and parsed.recipe.get("command") == command and parsed.unknown_words.is_empty() and parsed.ignored_words.is_empty(), "Order parsed as creation: " + phrase)
	load("res://scenes/main.gd").next_mode = "practice"
	game = load("res://scenes/main.tscn").instantiate()
	game.voice_enabled = false
	root.add_child(game)
	current_scene = game
	await create_timer(.6).timeout
	game.player.frozen = false
	game.player.set_physics_process(false)
	game.player.global_position = Vector3(12, 6, 7)
	check(forge.request(1, "pikachu choque do trovão").get("blocked", false), "Order created a free Pokemon")
	var moves_checked := 0
	for id in IDS:
		var actor = spawn("quero um " + id, Vector3(12, 6, 3))
		var enemy = spawn("quero um squirtle" if id == "pikachu" else "quero um cachorro", Vector3(12, 6, -3), 2)
		enemy.hp = 1000.0
		enemy.max_hp = 1000.0
		game.player.look_at_point(enemy.center())
		await physics_frame
		await physics_frame
		var power = actor.get_node("PokemonCompanion")
		for command: String in lex.defs.commands:
			if not command.begins_with("pokemon_"): continue
			var config: Dictionary = lex.defs.commands[command]
			if config.get("pokemon") != id or not config.has("move"): continue
			power.remaining = 0.0
			var phrase: String = lex.lexicon.commands[command].words[0]
			var before: float = enemy.hp
			var result: Dictionary = forge.request(1, phrase)
			check(not result.get("blocked", false) and result.get("pokemon_move") == config.move and enemy.hp < before, "Command failed to damage enemy: " + phrase + " " + str(result))
			check(float(result.cost) == 0.0, "Command charged another creature")
			var after: float = enemy.hp
			check(forge.request(1, phrase).get("blocked", false) and enemy.hp == after, "Cooldown bypass: " + id)
			check(forge.request(2, phrase).get("blocked", false), "Opponent commanded someone else's Pokemon")
			moves_checked += 1
		# A stored Pokemon cannot attack; capture keeps the same instance and cooldown.
		var ball = spawn("quero uma pokebola", Vector3(10, 6, 4))
		var catcher = ball.get_node("CaptureBall")
		power.remaining = 2.0
		check(catcher._attempt(weakref(actor), 0.0), "Cannot capture Pokemon: " + id)
		var phrase: String = lex.lexicon.commands["pokemon_" + id + "_" + String(power.moves.keys()[0])].words[0]
		check(forge.request(1, phrase).get("blocked", false), "Stored Pokemon attacked: " + id)
		var identity: int = actor.get_instance_id()
		var released = catcher.release()
		check(is_instance_valid(released) and released.get_instance_id() == identity and released.get_node("PokemonCompanion").remaining == 2.0, "Capture reset Pokemon or cooldown: " + id)
		actor.remove()
		enemy.remove()
		ball.remove()
		await process_frame
	var fx = load("res://scripts/fx/pokemon_fx.gd")
	check(fx.count == 8, "Missing move effects")
	var wire = load("res://scripts/network/forge_replication.gd")
	check(wire._valid_fx("pokemon_move", [Vector3.ZERO, Vector3.ONE, "electric", "Choque do trovão"]), "Valid Pokemon FX rejected")
	check(not wire._valid_fx("pokemon_move", [Vector3.ZERO, Vector3.ONE, "invalid", "x"]), "Invalid FX style accepted")
	print("POKEMON_ORDERS ", JSON.stringify({"failures": failures, "moves": moves_checked, "effects": fx.count}))
	quit(0 if failures.is_empty() else 1)
