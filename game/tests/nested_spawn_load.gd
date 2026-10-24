extends SceneTree

var failures := []
var evidence := {}
var game
var lex
var forge
var parser
var assembler
var recipes
var context

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
	return item

func _run() -> void:
	await process_frame
	load("res://scenes/main.gd").next_mode = "practice"
	game = load("res://scenes/main.tscn").instantiate()
	game.voice_enabled = false
	root.add_child(game)
	current_scene = game
	lex = root.get_node("Lexicon").data
	forge = root.get_node("Forge")
	parser = load("res://scripts/language/phrase_parser.gd")
	assembler = load("res://scripts/things/assembler.gd")
	recipes = load("res://scripts/language/recipe.gd")
	context = load("res://scripts/things/action_context.gd")
	await create_timer(0.7).timeout
	var parsed: Dictionary = parser.parse("quero uma minigun que atire aviões que atirem elefantes", lex)
	check(parsed.get("ok", false) and parsed.get("unknown_words", []).is_empty() and parsed.get("ignored_words", []).is_empty(), "Nested minigun phrase rejected: " + str(parsed))
	evidence.recipe = parsed.recipe
	var gun = spawn(parsed.recipe, Vector3(0, 12, 0))
	gun.set_physics_process(false)
	gun.move.set_physics_process(false)
	gun.set_held(true)
	var ammo: int = gun.ammo
	var fired := 0
	var worst_us := 0
	# A burst in one frame must neither build dozens of bodies nor spend blocked rounds.
	for i in 64:
		var at := Time.get_ticks_usec()
		if gun.fire(context.make(gun.center(), Vector3.FORWARD)): fired += 1
		worst_us = maxi(worst_us, Time.get_ticks_usec() - at)
	check(fired > 0 and fired <= 2, "One-frame burst created too many aircraft: " + str(fired))
	check(ammo - gun.ammo == fired, "Blocked heavy shots consumed ammunition")
	var count_before: int = forge.live_things(1).size()
	# Continued use competes with aircraft producing elephants for the same budget.
	for i in 180:
		var at := Time.get_ticks_usec()
		gun.fire(context.make(gun.center(), Vector3.FORWARD))
		worst_us = maxi(worst_us, Time.get_ticks_usec() - at)
		await create_timer(0.025).timeout
	var planes := 0
	var elephants := 0
	for item in game.get_node("Things").get_children():
		if item.thing_id == "plane": planes += 1
		elif item.thing_id == "elephant": elephants += 1
	check(planes > 0 and elephants > 0, "Nested creation no longer produces aircraft and elephants")
	check(planes + elephants < 110, "Nested production still grows without pacing")
	check(forge.stats.production_paused > 0 and forge.stats.evicted == 0, "Production was not paced or existing animals were evicted")
	evidence.production = {"planes": planes, "elephants": elephants, "paused_attempts": forge.stats.production_paused, "burst_shots": fired, "initial_population": count_before, "worst_fire_us": worst_us, "static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC)}
	# Ordinary ammunition retains the minigun's original firing rate.
	var ordinary = spawn(recipes.new_node("minigun"), Vector3(15, 12, 0))
	ordinary.set_physics_process(false)
	ordinary.move.set_physics_process(false)
	ordinary.set_held(true)
	var bullets := 0
	for i in 64:
		if ordinary.fire(context.make(ordinary.center(), Vector3.UP)): bullets += 1
	check(bullets == 64, "Normal minigun ammunition was throttled")
	evidence.normal_rounds = bullets
	var effects = load("res://scripts/things/action/action_anomaly.gd")
	var before_nukes: int = effects.executed.get("nuclear", 0)
	for i in 6:
		var bomb = spawn(recipes.new_node("nuclear_bomb"), Vector3(i * 40, 80, 0))
		bomb.set_physics_process(false)
		bomb.move.set_physics_process(false)
		bomb.get_node("Do_anomaly").run(bomb.context_here())
	check(int(effects.executed.get("nuclear", 0)) - before_nukes <= 1, "Nuclear effects still all execute in one frame")
	await create_timer(1.5).timeout
	check(int(effects.executed.get("nuclear", 0)) - before_nukes == 6, "Delayed explosions were lost instead of spread over time")
	evidence.delayed_nukes = int(effects.executed.get("nuclear", 0)) - before_nukes
	# Existing actors stay alive, and production resumes after pressure falls.
	var old = game.get_node("Things").get_children()[0]
	await create_timer(0.5).timeout
	check(is_instance_valid(old) and not old.is_dead, "Pacing removed an existing actor")
	for item in game.get_node("Things").get_children(): item.remove()
	await process_frame
	forge.production.reset()
	check(forge.production.available(1), "Production never resumed")
	var report := {"evidence": evidence, "failures": failures}
	var path := ProjectSettings.globalize_path("res://").path_join("../analysis/nested-spawn-load.json").simplify_path()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("NESTED_SPAWN_LOAD ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
