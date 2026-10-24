extends SceneTree

var failures := []
var game
var lex
var assembler
var recipes

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func spawn(recipe: Dictionary, at: Vector3):
	var item = assembler.build(recipe, "head", lex)
	item.set_owner_info(1, 1, game.player, game.player)
	game.add_thing(item)
	item.global_position = at
	item.activate()
	item.set_physics_process(false)
	item.move.set_physics_process(false)
	return item

func _run() -> void:
	await process_frame
	load("res://scenes/main.gd").next_mode = "practice"
	game = load("res://scenes/main.tscn").instantiate()
	game.voice_enabled = false
	root.add_child(game)
	current_scene = game
	lex = root.get_node("Lexicon").data
	assembler = load("res://scripts/things/assembler.gd")
	recipes = load("res://scripts/language/recipe.gd")
	var parser = load("res://scripts/language/phrase_parser.gd")
	await create_timer(0.5).timeout
	var species_checked := 0
	for id: String in lex.defs.things:
		if lex.thing_def(id).get("category", "") != "creature": continue
		var parsed: Dictionary = parser.parse("quero uma bomba que mate todos os " + lex.thing_name(id), lex)
		check(parsed.get("ok", false) and parsed.recipe.thing == "species_bomb" and parsed.recipe.mods.get("target_species", "") == id and parsed.get("unknown_words", []).is_empty() and parsed.get("ignored_words", []).is_empty(), "Species bomb phrase failed: " + id)
		species_checked += 1
	var request: Dictionary = parser.parse("quero uma bomba que mate todas as borboletas", lex)
	check(load("res://scripts/language/cost.gd").of(request.recipe, lex) >= 290, "Species bomb is not expensive")
	for i in 150: spawn(recipes.new_node("butterfly"), Vector3(i % 15, 40, i / 15))
	var chicken = spawn(recipes.new_node("chicken"), Vector3(1, 40, 1))
	var hp: float = chicken.hp
	var bomb = spawn(request.recipe, Vector3(0, 40, 0))
	bomb.get_node("Do_purge_species").run(bomb.context_here())
	await create_timer(1.5).timeout
	var remaining := 0
	for item in game.get_node("Things").get_children():
		if item.thing_id == "butterfly" and not item.is_dead: remaining += 1
	check(remaining == 0 and is_instance_valid(chicken) and chicken.hp == hp, "Global bomb failed to remove all butterflies or harmed a chicken")
	# A dense nuclear blast must outlive its bomb and process every creation beyond 128 hits.
	var cows := []
	for i in 160:
		var cow = spawn(recipes.new_node("cow"), Vector3((i % 10) * 0.12, 80, (i / 10) * 0.12))
		cow.hp = 1.0
		cow.matter = 0.0
		cows.append(weakref(cow))
	await physics_frame
	var original = spawn(recipes.new_node("nuclear_bomb"), Vector3(0, 80, 0))
	var nuclear = root.get_node("Forge").spawn_child(original.node_data, "projectile", Vector3(0, 80, 0), Vector3.DOWN, original, 0.0, Vector3.ZERO, true)
	original.remove()
	nuclear.set_physics_process(false)
	nuclear.move.set_physics_process(false)
	await create_timer(0.3).timeout
	check(not is_instance_valid(original), "Held nuclear bomb was not freed before detonation")
	nuclear.get_node("Do_anomaly").run(nuclear.context_here())
	await create_timer(2.0).timeout
	var survivors := 0
	for ref in cows:
		var cow = ref.get_ref()
		if is_instance_valid(cow) and not cow.is_dead: survivors += 1
	check(survivors == 0, "Crowded nuclear blast skipped creations: " + str(survivors))
	var chain: Dictionary = parser.parse("quero um cachorro que atira gato que atira pombo que atira rato", lex)
	check(chain.get("ok", false) and chain.get("unknown_words", []).is_empty(), "Dog/cat/pigeon/rat chain did not parse")
	spawn(chain.recipe, Vector3(0, 1, 0))
	await create_timer(6.0).timeout
	var tiers := {}
	for item in game.get_node("Things").get_children():
		if not item.is_dead and item.thing_id in ["dog", "cat", "pigeon", "rat"]: tiers[item.thing_id] = true
	check(tiers.size() == 4, "Nested chain did not produce all four animal species: " + str(tiers))
	for i in 64:
		var crowded = spawn(recipes.new_node("cow"), Vector3(float(i % 8) * 0.1, 1, float(i / 8) * 0.1))
		crowded.hp = 1.0
		crowded.matter = 0.0
	var held = spawn(recipes.new_node("nuclear_bomb"), Vector3(0, 2, 0))
	game.player.hands._throw(held, Vector3(0, 2, 0), Vector3.DOWN)
	await create_timer(5.0).timeout
	check(not is_instance_valid(held), "Actual thrown nuclear retained its held source")
	var report := {"failures": failures, "species_checked": species_checked, "butterflies_before": 150, "butterflies_after": remaining, "nuclear_targets": 160, "nuclear_survivors": survivors}
	report.nested_chain = tiers.keys()
	report.real_throw_completed = true
	var file := FileAccess.open(ProjectSettings.globalize_path("res://").path_join("../analysis/crowd-bombs.json").simplify_path(), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("CROWD_BOMBS ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
