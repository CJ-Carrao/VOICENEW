extends SceneTree

var failures := []
var game
var lex
var forge
var parser
var assembler
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func spawn(phrase: String, at: Vector3, team: int = 1):
	var animal = assembler.build(parser.parse(phrase, lex).recipe, "head", lex)
	animal.set_owner_info(team, team, game.player if team == 1 else game.opponent, null)
	game.add_thing(animal)
	animal.global_position = at
	animal.activate()
	animal.move.set_physics_process(false)
	animal.set_physics_process(false)
	animal.get_node("AnimalOrders").set_physics_process(false)
	return animal
func _run() -> void:
	await process_frame
	lex = root.get_node("Lexicon").data
	forge = root.get_node("Forge")
	parser = load("res://scripts/language/phrase_parser.gd")
	assembler = load("res://scripts/things/assembler.gd")
	load("res://scenes/main.gd").next_mode = "practice"
	game = load("res://scenes/main.tscn").instantiate()
	game.voice_enabled = false
	root.add_child(game)
	current_scene = game
	await create_timer(.6).timeout
	game.player.frozen = false
	game.player.set_physics_process(false)
	game.player.global_position = Vector3(0, 30, 15)
	game.opponent.set_physics_process(false)
	game.opponent.global_position = Vector3(0, 30, -15)
	var species := 0
	for key: String in lex.defs.commands:
		if not key.begins_with("animal_group_"): continue
		var phrase: String = lex.lexicon.commands[key].words[0]
		var parsed: Dictionary = parser.parse(phrase, lex)
		check(parsed.get("ok", false) and parsed.recipe.get("command") == key and parsed.unknown_words.is_empty() and parsed.ignored_words.is_empty(), "Plural order not parsed: " + phrase)
		if key.ends_with("_follow"): species += 1
	var dogs := []
	for i in 3: dogs.append(spawn("quero um cachorro", Vector3(-6 + i * 6, 30, 0)))
	var enemy = spawn("quero um cachorro", Vector3(9, 30, 0), 2)
	var far = spawn("quero um cachorro", Vector3(90, 30, 0))
	var captured = spawn("quero um cachorro", Vector3(4, 30, 0))
	captured.set_captured(true)
	var cat = spawn("quero um gato", Vector3(-10, 30, 0))
	game.player.look_at_point(enemy.center())
	await physics_frame
	for phrase in ["cachorros, me sigam", "cachoros me sigam", "cachorros me siga", "todos os cachorros venham comigo"]:
		var reply: Dictionary = forge.request(1, phrase, false, true)
		check(reply.get("animal_order") == "follow" and reply.get("animal_count") == 3, "Plural command did not address three dogs: " + phrase + " " + str(reply))
	for dog in dogs:
		var orders = dog.get_node("AnimalOrders")
		orders._physics_process(1.0)
		var start: Vector3 = dog.global_position
		orders.drive(.1)
		check(dog.global_position.z > start.z, "Dog did not come toward trainer")
	for animal in [enemy, far, captured, cat]:
		check(animal.get_node("AnimalOrders").mode == "free", "Plural dog order affected enemy, distant, captured or other species")
	var stay: Dictionary = forge.request(1, "cachorros fiquem aqui", false, true)
	check(stay.get("animal_count") == 3, "Group stay failed")
	for dog in dogs:
		var orders = dog.get_node("AnimalOrders")
		orders._physics_process(1.0)
		orders.drive(.1)
		check(absf(dog.velocity.x) + absf(dog.velocity.z) < .01, "Group stay kept walking")
	game.player.look_at_point(dogs[0].center())
	await physics_frame
	check(forge.request(1, "cachorro me siga", false, true).get("animal_order") == "follow", "Singular command broke")
	var followers := 0
	for dog in dogs:
		if dog.get_node("AnimalOrders").mode == "follow": followers += 1
	check(followers == 1, "Singular command addressed a whole group")
	check(forge.request(1, "todos me sigam", false, true).get("animal_count") == 4, "All-species follow failed")
	for phrase in ["cachorros protejam minha casa", "cachorros fujam das bombas", "cachorros ataquem só quem me atacar", "cachorros voltem ao normal", "cachorros sejam agressivos"]:
		check(forge.request(1, phrase, false, true).get("animal_count") == 3, "Other plural order failed: " + phrase)
	game.player.look_at_point(enemy.center())
	await physics_frame
	var attack: Dictionary = forge.request(1, "cachorros ataquem", false, true)
	check(attack.get("animal_order") == "attack" and attack.get("animal_count") == 3, "Short plural attack failed")
	for dog in dogs:
		check(dog.get_node("AnimalOrders").combat_target() == enemy, "Attack did not select aimed enemy creature")
	game.player.look_at_point(cat.center())
	await physics_frame
	var friendly: Dictionary = forge.request(1, "cachorros ataquem aquela criatura", false, true)
	for dog in dogs:
		check(dog.get_node("AnimalOrders").combat_target() != cat, "Attack command selected friendly creature")
	print("GROUP_ANIMAL_ORDERS ", JSON.stringify({"failures": failures, "species_and_generic": species}))
	quit(0 if failures.is_empty() else 1)
