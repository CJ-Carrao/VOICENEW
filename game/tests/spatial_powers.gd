extends SceneTree

var failures := []
var game
var lex
var assembler
var recipe
var parser
var spatial
var evidence := {}

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func spawn(id: String, at: Vector3, team: int = 1):
	var item = assembler.build(recipe.new_node(id), "head", lex)
	item.set_owner_info(team, team, game.player if team == 1 else game.opponent, game.player)
	game.add_thing(item)
	item.global_position = at
	item.activate()
	return item

func clear() -> void:
	for item in game.get_node("Things").get_children(): item.remove()
	await process_frame
	root.get_node("Forge").production.reset()

func _run() -> void:
	await process_frame
	load("res://scenes/main.gd").next_mode = "practice"
	game = load("res://scenes/main.tscn").instantiate()
	game.voice_enabled = false
	root.add_child(game)
	current_scene = game
	lex = root.get_node("Lexicon").data
	assembler = load("res://scripts/things/assembler.gd")
	recipe = load("res://scripts/language/recipe.gd")
	parser = load("res://scripts/language/phrase_parser.gd")
	spatial = load("res://scripts/things/spatial_orb.gd")
	await create_timer(0.5).timeout
	for pair in [["quero um buraco negro", "black_hole"], ["invocar um buraco branco", "white_hole"], ["quero o azul", "cursed_blue"], ["quero o vermelho", "reversal_red"], ["quero fazio roxo", "hollow_purple"], ["quero vazio roxo", "hollow_purple"], ["quero um pato azul", "duck"], ["quero um pato vermelho", "duck"]]:
		var parsed: Dictionary = parser.parse(pair[0], lex)
		check(parsed.get("ok", false) and parsed.recipe.thing == pair[1] and parsed.get("unknown_words", []).is_empty() and parsed.get("ignored_words", []).is_empty(), "Spatial phrase or color regressed: " + pair[0] + " " + str(parsed))
	var blue_cfg: Dictionary = lex.thing_def("cursed_blue").spatial_orb
	var red_cfg: Dictionary = lex.thing_def("reversal_red").spatial_orb
	check(red_cfg.force == blue_cfg.force * 2 and red_cfg.damage == blue_cfg.damage * 2, "Red is not twice Blue's force/damage")
	var cow = spawn("cow", Vector3(4, 40, 0))
	cow.move.set_physics_process(false)
	cow.set_physics_process(false)
	var blue = spawn("cursed_blue", Vector3(0, 40, 0))
	blue.get_node("SpatialOrb")._field(blue.center())
	check(cow.velocity.x < 0 and cow.hp < cow.max_hp, "Blue did not attract and compress a creature")
	cow.velocity = Vector3.ZERO
	var red = spawn("reversal_red", Vector3(0, 40, 0))
	red.get_node("SpatialOrb")._field(red.center())
	check(cow.velocity.x > 0, "Red did not repel a creature")
	await clear()
	# Same-team and enemy orbs combine; claiming both prevents duplicate reactions.
	for enemy in [false, true]:
		var before: int = spatial.annihilations
		var black = spawn("black_hole", Vector3(0, 40, 0))
		var white = spawn("white_hole", Vector3(.5, 40, 0), 2 if enemy else 1)
		for step in 8: await physics_frame
		await process_frame
		check(spatial.annihilations == before + 1 and (not is_instance_valid(black) or black.is_dead) and (not is_instance_valid(white) or white.is_dead), "Black/white collision failed or executed twice")
		await clear()
	var before_purple: int = spatial.purple_fusions
	blue = spawn("cursed_blue", Vector3(-2, 40, 0))
	red = spawn("reversal_red", Vector3(2, 40, 0), 2)
	blue.velocity = Vector3.RIGHT * 35
	red.velocity = Vector3.LEFT * 35
	for step in 12: await physics_frame
	await process_frame
	var purples := []
	for item in game.get_node("Things").get_children():
		if item.thing_id == "hollow_purple" and not item.is_dead: purples.append(item)
	check(spatial.purple_fusions == before_purple + 1 and purples.size() == 1, "Moving Blue/Red did not create exactly one Purple")
	if not purples.is_empty(): check(purples[0].velocity.x < 0 and purples[0].team == 2, "Purple did not inherit Red's heading/team")
	await clear()
	blue = spawn("cursed_blue", Vector3(0, 40, 0))
	var blue2 = spawn("cursed_blue", Vector3(.3, 40, 0))
	for step in 4: await physics_frame
	check(not blue.is_dead and not blue2.is_dead, "Same powers incorrectly annihilated")
	await clear()
	# Purple must hit real actors and remove actual world cells, including a fast sweep.
	cow = spawn("cow", Vector3(0, 40, -3))
	cow.move.set_physics_process(false)
	cow.set_physics_process(false)
	var purple = spawn("hollow_purple", Vector3(0, 40, 0))
	purple.velocity = Vector3.FORWARD * 20
	var volume = load("res://scripts/world/block_volume.gd").new()
	volume.setup(99999, Vector3i(8, 8, 8), Vector3.ZERO)
	var wood: int = volume.add_type("wood", Color.BROWN)
	volume.blocks.fill(wood)
	game.add_child(volume)
	volume.global_position = Vector3(-1, 39, -5)
	volume.commit_base()
	await create_timer(.4).timeout
	var cells := 0
	for cell in volume.blocks:
		if cell != 0: cells += 1
	check(not is_instance_valid(cow) or cow.is_dead, "Purple did not damage the actor along its path")
	check(cells < 512, "Purple did not cut actual blocks")
	evidence.purple_cells_removed = 512 - cells
	volume.queue_free()
	await clear()
	blue = spawn("cursed_blue", Vector3(0, 40, 0))
	blue.get_node("SpatialOrb").elapsed = 6.0
	await create_timer(.1).timeout
	check(not is_instance_valid(blue) or blue.is_dead, "Spatial field did not expire")
	evidence.annihilations = spatial.annihilations
	evidence.purple_fusions = spatial.purple_fusions
	var report := {"evidence": evidence, "failures": failures}
	var file := FileAccess.open(ProjectSettings.globalize_path("res://").path_join("../analysis/spatial-powers.json").simplify_path(), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("SPATIAL_POWERS ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
