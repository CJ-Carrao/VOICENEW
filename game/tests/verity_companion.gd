extends SceneTree

var failures := []
var game
var lex
var parser
var assembler
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func spawn(phrase: String, at: Vector3):
	var parsed: Dictionary = parser.parse(phrase, lex)
	check(parsed.get("ok", false) and parsed.unknown_words.is_empty() and parsed.ignored_words.is_empty(), "Invalid Verity phrase: " + phrase)
	var animal = assembler.build(parsed.recipe, "head", lex)
	animal.set_owner_info(1, 1, game.player, null)
	game.add_thing(animal)
	animal.global_position = at
	animal.activate()
	animal.set_physics_process(false)
	return animal
func _run() -> void:
	await process_frame
	lex = root.get_node("Lexicon").data
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
	game.player.global_position = Vector3(0, 30, 10)
	game.opponent.set_physics_process(false)
	game.opponent.global_position = Vector3(30, 30, -30)
	for phrase in ["quero veriti", "quero uma bolinha amarela", "quero um verity com infinito", "quero um verity com uma ak 47", "quero um cachorro com cara de verity"]:
		var mixed = spawn(phrase, Vector3(15, 30, 0))
		check(mixed.unsupported.is_empty(), "Verity composition unsupported: " + phrase)
		mixed.remove()
	await process_frame
	var orb = spawn("quero um verity", Vector3(0, 30, 0))
	var orders = orb.get_node("AnimalOrders")
	check(orders.mode == "follow", "Verity did not follow by default")
	var start: Vector3 = orb.global_position
	for i in 35: await physics_frame
	check(orb.global_position.z > start.z + .5 and orb.move.hovers(), "Verity did not float toward its trainer")
	var forge = root.get_node("Forge")
	check(forge.request(1, "verity fique aqui", false, true).get("animal_order") == "stay", "Verity ignored stay")
	check(forge.request(1, "verity volte ao normal", false, true).get("animal_order") == "free" and orders.mode == "follow", "Normal command did not restore companion follow")
	orb.move.set_physics_process(false)
	orders.set_physics_process(false)
	orb.global_position = game.player.global_position + Vector3(1.7, 1.6, 0)
	var helper = orb.get_node("VerityCompanion")
	helper.set_physics_process(false)
	var second = spawn("quero um verity", orb.global_position + Vector3(1,0,0))
	second.move.set_physics_process(false)
	var helper2 = second.get_node("VerityCompanion")
	helper2.set_physics_process(false)
	game.player.health = 40
	game.player.set_meta("verity_next_heal", 0)
	helper.check_left = 0
	helper2.check_left = 0
	helper._physics_process(.3)
	helper2._physics_process(.3)
	check(game.player.health == 44, "Multiple Veritys stacked healing or failed to heal")
	game.player.health = game.player.max_health * .6 - 1
	game.player.set_meta("verity_next_heal", 0)
	helper.check_left = 0
	helper._physics_process(.3)
	check(game.player.health == game.player.max_health * .6, "Support healing exceeded 60% threshold")
	var ball = spawn("quero uma pokebola", Vector3(0,30,9))
	var catcher = ball.get_node("CaptureBall")
	check(catcher._attempt(weakref(orb), 0.0), "Verity could not be captured")
	game.player.health = 40
	game.player.set_meta("verity_next_heal", 0)
	helper.check_left = 0
	helper._physics_process(.3)
	check(game.player.health == 40, "Captured Verity healed trainer")
	check(catcher.release() == orb and orders.mode == "follow", "Capture lost Verity or follow order")
	game.player.look_at_point(second.center())
	await physics_frame
	check(forge.request(1, "veritys me sigam", false, true).get("animal_count") == 2, "Plural Verity command failed")
	var network = load("res://scripts/network/thing_network_state.gd")
	var replica = assembler.build_replica({"thing":"verity"}, "head", lex, 9201, 1)
	game.add_thing(replica)
	replica.activate()
	network.apply(replica, network.capture(orb))
	check(replica.get_node("AnimalOrders").mode == "follow" and replica.get_node_or_null("VerityCompanion") != null, "Verity companion presentation did not replicate")
	var hp: float = game.player.health
	replica.get_node("VerityCompanion")._physics_process(1.0)
	check(game.player.health == hp, "Replica applied duplicate healing")
	for item in game.get_node("Things").get_children(): item.remove()
	await create_timer(.25).timeout
	print("VERITY_COMPANION ", JSON.stringify({"failures": failures, "pieces": lex.models.verity.pieces.size()}))
	quit(0 if failures.is_empty() else 1)
