extends SceneTree

var failures := []
var game
var parser
var assembler
var lex
var shots := 0

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func spawn(phrase: String, at: Vector3, team: int = 1):
	var parsed: Dictionary = parser.parse(phrase, lex)
	check(parsed.get("ok", false) and parsed.unknown_words.is_empty(), "Bad phrase: " + phrase)
	var animal = assembler.build(parsed.recipe, "head", lex)
	animal.set_owner_info(team, team, game.player if team == 1 else game.opponent, null)
	game.add_thing(animal)
	animal.global_position = at
	animal.activate()
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
	game.player.global_position = Vector3(0, 20, 15)
	game.dummy.set_physics_process(false)
	game.dummy.global_position = Vector3(0, -100, 0)
	var maho = spawn("quero um mahoraga", Vector3(15, 20, 0))
	maho.move.set_physics_process(false)
	maho.set_physics_process(false)
	var user = maho.get_node("Jujutsu")
	user.set_physics_process(false)
	for frame in 2: await process_frame
	var above: Vector3 = maho.bounds.get_center() + Vector3.UP * (maho.bounds.size.y * .5 + .45)
	check(user.wheel.global_position.distance_to(maho.to_global(above)) < .01, "Wheel did not spawn above Mahoraga")
	maho.global_position += Vector3(7, 2, -3)
	maho.rotate_y(.7)
	for frame in 2: await process_frame
	check(user.wheel.global_position.distance_to(maho.to_global(above)) < .01, "Wheel did not follow Mahoraga's translation and rotation")
	maho.set_captured(true)
	await process_frame
	check(not user.wheel.is_visible_in_tree(), "Captured creature left its wheel visible")
	maho.global_position += Vector3(2, 0, 0)
	maho.set_captured(false)
	await process_frame
	check(user.wheel.is_visible_in_tree() and user.wheel.global_position.distance_to(maho.to_global(above)) < .01, "Released wheel did not return with creature")
	var replica = assembler.build_replica(parser.parse("quero um mahoraga", lex).recipe, "head", lex, 9001, 1)
	game.add_thing(replica)
	replica.activate()
	replica.receive_network_pose(Transform3D(Basis(Vector3.UP, .9), Vector3(28, 22, -4)), true)
	await process_frame
	var remote_wheel = replica.get_node("Jujutsu").wheel
	check(remote_wheel.global_position.distance_to(replica.to_global(above)) < .01, "Remote Mahoraga wheel did not follow replicated pose")
	replica.set_captured(true)
	check(not remote_wheel.is_visible_in_tree(), "Remote captured wheel stayed visible")
	replica.remove()
	var bird_a = spawn("quero um pombo agressivo com um rifle", Vector3(-10, 20, 0))
	var bird_b = spawn("quero um pombo agressivo com um rifle", Vector3(-6, 20, 0))
	for bird in [bird_a, bird_b]:
		bird.hp = 1000.0
		bird.max_hp = 1000.0
		bird.grafts[0].fired.connect(func(_ctx): shots += 1)
		check(bird.get_collision_exceptions().has(bird.grafts[0]), "Bird can collide with its mounted rifle")
	var start_a: Vector3 = bird_a.global_position
	var start_b: Vector3 = bird_b.global_position
	for frame in 90: await physics_frame
	var distance_a: float = bird_a.global_position.distance_to(start_a)
	var distance_b: float = bird_b.global_position.distance_to(start_b)
	check(distance_a > .8 and distance_b > .8, "Armed aggressive birds stayed still without a target: %s / %s" % [distance_a, distance_b])
	check(bird_a.grafts.size() == 1 and bird_b.grafts.size() == 1, "Bird rifles missing")
	var victim = spawn("quero um elefante", bird_a.global_position - bird_a.global_basis.z * 6, 2)
	victim.hp = 1000.0
	victim.max_hp = 1000.0
	victim.move.set_physics_process(false)
	victim.set_physics_process(false)
	var hp: float = game.player.health
	for frame in 90: await physics_frame
	check(shots > 0, "Aggressive birds did not use rifles")
	check(game.player.health == hp, "Aggressive bird hurt trainer")
	var wheel = user.wheel
	maho.remove()
	await create_timer(.2).timeout
	check(not is_instance_valid(wheel), "Wheel survived its creature")
	for animal in [bird_a, bird_b, victim]: animal.remove()
	print("MAHORAGA_BIRD_MOTION ", JSON.stringify({"failures": failures, "bird_travel": [distance_a, distance_b]}))
	quit(0 if failures.is_empty() else 1)
