extends SceneTree

var failures := []
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func _run() -> void:
	await process_frame
	var lex = root.get_node("Lexicon").data
	load("res://scenes/main.gd").next_mode = "practice"
	var game = load("res://scenes/main.tscn").instantiate()
	game.voice_enabled = false
	root.add_child(game)
	current_scene = game
	await create_timer(.6).timeout
	game.player.set_physics_process(false)
	game.dummy.set_physics_process(false)
	var recipe = load("res://scripts/language/phrase_parser.gd").parse("quero um avião", lex).recipe
	var assembler = load("res://scripts/things/assembler.gd")
	for role in ["head", "projectile"]:
		var plane = assembler.build(recipe, role, lex)
		plane.set_owner_info(1, 1, game.player, null)
		game.add_thing(plane)
		plane.activate()
		plane.move.set_physics_process(false)
		check(plane.move.get_script().resource_path.ends_with("move_flyover.gd"), "Plane lost flyover movement: " + role)
		plane.global_position = Vector3(-20, 30, 0)
		plane.move.launch(Vector3.RIGHT, plane.speed)
		game.player.global_position = Vector3(-20, 30, 8)
		game.dummy.global_position = Vector3(-20, 30, -8)
		var start: Vector3 = plane.global_position
		for i in 90: plane.move.step(1.0 / 60.0)
		check(plane.velocity.normalized().dot(Vector3.RIGHT) > .99, "Plane turned toward player: " + role)
		check(absf(plane.global_position.z - start.z) < .01, "Plane drifted toward player: " + role)
		check(absf(plane.global_position.y - start.y) < .01, "Plane descended from flight path: " + role)
		check(plane.global_position.x > start.x + 1.0, "Plane did not fly forward: " + role)
		game.player.global_position = Vector3(0, 30, -20)
		game.dummy.global_position = Vector3(0, 30, 20)
		for i in 30: plane.move.step(1.0 / 60.0)
		check(plane.velocity.normalized().dot(Vector3.RIGHT) > .99, "Plane followed relocated players: " + role)
		plane.move.pilot(Vector3.FORWARD, 0, Vector3.FORWARD, .016)
		plane.move.step(.016)
		check(plane.velocity.z < 0, "Pilot lost control: " + role)
		plane.remove()
	print("PLANE_FLYOVER ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)
