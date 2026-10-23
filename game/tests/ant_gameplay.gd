extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _run() -> void:
	await process_frame
	var match_script = load("res://scenes/main.gd")
	match_script.next_mode = "practice"
	var game = load("res://scenes/main.tscn").instantiate()
	game.voice_enabled = false
	root.add_child(game)
	current_scene = game
	await create_timer(1.0).timeout
	var forge = root.get_node("Forge")
	var lexicon = root.get_node("Lexicon")
	var voice_vocabulary = load("res://scripts/voice/voice_vocabulary.gd")
	_check(voice_vocabulary.hotwords(lexicon.data).has("formiga"), "Ant must be in recognition hotwords")
	game.player.add_matter(100.0)
	var matter_before: float = game.player.matter
	var result: Dictionary = forge.request(game.player.player_id, "quero uma formiga")
	_check(bool(result.get("ok", false)), "Ant request was rejected")
	_check(result.get("unsupported", []).is_empty(), "Ant request contains unsupported features")
	_check(float(result.get("cost", 0.0)) > 0.0, "Ant must use normal matter economy")
	await create_timer(2.5).timeout
	var ant
	var ant_count := 0
	for candidate in game.get_node("Things").get_children():
		if candidate.get("thing_id") == "ant":
			ant = candidate
			ant_count += 1
	_check(ant_count == 1, "Expected exactly one spawned ant")
	if ant != null:
		_check(ant.category == "creature" and ant.is_active and not ant.is_dead, "Ant must be a live creature")
		_check(ant.model_pieces.size() == 25, "Ant voxel model did not load completely")
		_check(ant.get_node("Move").get_script().resource_path.ends_with("move_chase_enemy.gd"), "Ant must use terrestrial creature movement")
		_check(game.player.matter < matter_before, "Creation did not spend matter")
		var start: Vector3 = ant.global_position
		await create_timer(1.0).timeout
		var distance: float = ant.global_position.distance_to(start)
		_check(distance > 0.02, "Ant did not move towards a target")
		if OS.get_cmdline_user_args().has("--ant-preview"):
			ant.set_physics_process(false)
			game.get_node("HUD").hide()
			var camera := Camera3D.new()
			game.add_child(camera)
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = 0.72
			camera.near = 0.01
			var center: Vector3 = ant.global_position + ant.up() * 0.11
			camera.global_position = center + ant.global_basis * Vector3(0.55, 0.35, -0.65)
			camera.look_at(center, ant.up())
			camera.current = true
			await create_timer(0.5).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://").path_join("../analysis/ant-preview.png").simplify_path())
		print("ANT_GAMEPLAY ", JSON.stringify({"request": result, "spawned": ant_count, "pieces": ant.model_pieces.size(), "travelled_m": distance, "matter_after": game.player.matter, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
