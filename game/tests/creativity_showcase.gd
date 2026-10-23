extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	root.size = Vector2i(1600, 1000)
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#24313e")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#d5dfe3")
	environment.environment.ambient_light_energy = 0.65
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -35, 0)
	light.light_energy = 1.8
	light.shadow_enabled = true
	stage.add_child(light)
	var lex = root.get_node("Lexicon").data
	var builder = load("res://scripts/things/model_builder.gd")
	var ids := ["queen_ant", "ant_nest", "duck", "anteater", "walking_house", "house", "queen_bee", "beehive", "blast_shield", "neutron_shield", "shield_projector", "chicken_coop"]
	for i in ids.size():
		var id: String = ids[i]
		var built: Dictionary = builder.build(id, {}, lex)
		var box: AABB = built.bounds
		var visual := built.root as Node3D
		var multiplier := 1.85 / maxf(box.size.x, maxf(box.size.y, box.size.z))
		visual.scale = Vector3.ONE * multiplier
		var offset := Vector3((float(i % 4) - 1.5) * 3.0, 0, (float(i / 4) - 1.0) * 3.25)
		visual.position = offset - Vector3(box.get_center().x, box.position.y, box.get_center().z) * multiplier
		stage.add_child(visual)
		var base := MeshInstance3D.new()
		var base_mesh := BoxMesh.new()
		base_mesh.size = Vector3(2.7, 0.12, 2.7)
		base.mesh = base_mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("#475968")
		base.material_override = material
		base.position = offset + Vector3(0, -.07, 0)
		stage.add_child(base)
		var label := Label3D.new()
		label.text = lex.thing_name(id).to_upper()
		label.font_size = 36
		label.pixel_size = .004
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color("#f0e6c9")
		label.position = offset + Vector3(0, .10, -1.28)
		stage.add_child(label)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(4.4, 13.5, -14.5)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13.9
	camera.look_at(Vector3(0, .3, 0))
	camera.current = true
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://").path_join("../analysis/creativity-showcase.png").simplify_path()
	root.get_texture().get_image().save_png(path)
	print("SHOWCASE_SAVED ", path)
	quit()
