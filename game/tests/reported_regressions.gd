extends SceneTree

var game
var lex
var assembler
var recipes
var parser
var combat
var context
var failures := []
var results := {}

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func spawn(id: String, at: Vector3, team: int = 1, data: Dictionary = {}):
	var item = assembler.build(recipes.new_node(id) if data.is_empty() else data, "head", lex)
	item.set_owner_info(team, team, game.player if team == 1 else game.opponent, game.player)
	game.add_thing(item)
	item.global_position = at
	item.activate()
	return item

func clear() -> void:
	for item in game.get_node("Things").get_children():
		item.remove()
	await process_frame

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
	parser = load("res://scripts/language/phrase_parser.gd")
	combat = load("res://scripts/things/combat.gd")
	context = load("res://scripts/things/action_context.gd")
	await create_timer(0.7).timeout
	var checked_animals := 0
	for id: String in lex.defs.things:
		if lex.thing_def(id).get("category", "") != "creature": continue
		var phrase: String = "quero " + lex.thing_name(id) + " com uma pistola que atira formigas com uma pistola"
		var parsed: Dictionary = parser.parse(phrase, lex)
		check(parsed.get("ok", false) and parsed.get("unknown_words", []).is_empty() and parsed.get("ignored_words", []).is_empty(), "Armed animal phrase failed: " + phrase)
		if parsed.get("ok", false):
			var animal = assembler.build(parsed.recipe, "head", lex)
			check(animal.grafts.size() == 1 and animal.unsupported.is_empty(), "Animal cannot carry a working weapon: " + id)
			animal.free()
		var diet_phrase: String = "quero um pato que só coma " + lex.thing_name(id)
		var diet_result: Dictionary = parser.parse(diet_phrase, lex)
		check(diet_result.get("ok", false) and diet_result.get("unknown_words", []).is_empty() and not diet_result.recipe.mods.get("diet", "").is_empty(), "Missing species diet: " + id)
		var hybrid_recipe: Dictionary = recipes.new_node(id)
		hybrid_recipe.mods.anatomy = {"head": "dragon"}
		var hybrid_animal = assembler.build(hybrid_recipe, "head", lex)
		check(hybrid_animal.unsupported.is_empty() and hybrid_animal.get_node_or_null("Do_shoot") != null, "New species cannot use donor anatomy: " + id)
		hybrid_animal.free()
		checked_animals += 1
	results.species_compositions_checked = checked_animals
	var flight := []
	for id in ["dragon", "cave_bat", "butterfly", "helicopter", "pigeon", "plane", "bee"]:
		var item = spawn(id, Vector3(0, 8, 0))
		item.set_physics_process(false)
		var start: Vector3 = item.global_position
		await create_timer(0.65).timeout
		check(is_instance_valid(item) and not item.is_dead, "Flyer disappeared: " + id)
		if is_instance_valid(item):
			var horizontal: float = Vector2(item.global_position.x - start.x, item.global_position.z - start.z).length()
			check(horizontal > 0.1, "Flyer never traveled horizontally: " + id)
			flight.append({"id": id, "horizontal_m": horizontal, "vertical_speed": item.velocity.y})
		await clear()
	results.flight = flight
	var house = spawn("walking_house", Vector3(0, 1, 0))
	var home: Vector3 = house.global_position
	await create_timer(1.2).timeout
	check(is_instance_valid(house) and house.global_position.distance_to(home) > 0.15, "Walking house remained stationary")
	await clear()
	var duck_recipe: Dictionary = parser.parse("quero um pato que só coma formigas", lex).recipe
	var duck = spawn("duck", Vector3(0, 1, 0), 1, duck_recipe)
	var ant = spawn("ant", Vector3(0.65, 1, 0))
	var hen = spawn("chicken", Vector3(1.5, 1, 0))
	hen.move.set_physics_process(false)
	var hen_hp: float = hen.hp
	await create_timer(2.7).timeout
	check(is_instance_valid(duck) and not duck.is_dead, "Duck vanished while eating an ant")
	check(not is_instance_valid(ant) or ant.is_dead, "Ant diet failed in physical contact")
	check(is_instance_valid(hen) and hen.hp == hen_hp, "Ant eater attacked another species")
	await clear()
	var flying_diet: Dictionary = parser.parse("quero uma borboleta que só coma formigas", lex).recipe
	var hunter = spawn("butterfly", Vector3(0, 2.2, 0), 1, flying_diet)
	var ground_prey = spawn("ant", Vector3(0.65, 1, 0))
	ground_prey.move.set_physics_process(false)
	await create_timer(3.5).timeout
	check(is_instance_valid(hunter) and not hunter.is_dead, "Flying predator vanished while eating")
	check(not is_instance_valid(ground_prey) or ground_prey.is_dead, "Flying diet cannot reach ground prey")
	await clear()
	for phrase in ["quero um lobo que só coma capivaras", "quero um dragão que só coma elefantes", "quero um pato com cabeça de um dragão", "quero uma formiga com asas de borboleta", "quero uma capivara misturada com um pato", "quero um pato com uma pistola que atira formigas com uma pistola"]:
		var parsed: Dictionary = parser.parse(phrase, lex)
		check(parsed.get("ok", false) and parsed.get("unknown_words", []).is_empty() and parsed.get("ignored_words", []).is_empty(), "Composition discarded words: " + phrase + " " + str(parsed))
		if parsed.get("ok", false):
			var item = assembler.build(parsed.recipe, "head", lex)
			check(item.unsupported.is_empty(), "Unsupported composition: " + phrase)
			item.free()
	var hybrid: Dictionary = parser.parse("quero um pato com cabeça de um dragão", lex).recipe
	var mixed = assembler.build(hybrid, "head", lex)
	var donor := 0
	for mesh in mixed.model_pieces:
		if mesh.get_meta("source", "") == "dragon": donor += 1
	check(donor > 0 and mixed.get_node_or_null("Do_shoot") != null, "Hybrid lost dragon anatomy or fire breath")
	mixed.free()
	var chain: Dictionary = parser.parse("quero um pato com uma pistola que atira formigas com uma pistola", lex).recipe
	var carrier = spawn("duck", Vector3(0, 4, 0), 1, chain)
	check(carrier.grafts.size() == 1, "Carrier has no weapon")
	if carrier.grafts.size() == 1:
		var gun = carrier.grafts[0]
		gun.get_node("Do_shoot").run(context.make(gun.center(), Vector3.FORWARD))
		await process_frame
		var armed_ant
		for item in game.get_node("Things").get_children():
			if item.thing_id == "ant": armed_ant = item
		check(armed_ant != null and armed_ant.grafts.size() == 1 and armed_ant.lifetime == 0, "Launched animal lost its weapon or expires")
		if armed_ant != null and armed_ant.grafts.size() == 1:
			check(armed_ant.grafts[0].fire(context.make(armed_ant.center(), Vector3.FORWARD)), "Nested animal weapon cannot fire")
	await clear()
	var forge = root.get_node("Forge")
	var old
	for i in 55:
		var item = spawn("ant", Vector3(0, 2, 0))
		item.move.set_physics_process(false)
		forge._register(item)
		if i == 0: old = item
	check(is_instance_valid(old) and not old.is_dead and forge.live_things(1).size() >= 55, "Animal count still removes older creatures")
	results.unlimited_count = forge.live_things(1).size()
	await clear()
	for id in ["plane", "elephant"]:
		var persistent = spawn(id, Vector3(0, 8, 0))
		persistent.age = 10000.0
		persistent._physics_process(0.1)
		check(not persistent.is_dead and persistent.lifetime == 0, "Animal/vehicle still expires: " + id)
		persistent.global_position = Vector3(persistent._arena_limit + 10, 8, 0)
		persistent._physics_process(0.1)
		check(not persistent.is_dead and absf(persistent.global_position.x) < persistent._arena_limit, "Animal/vehicle removed at map edge: " + id)
	await clear()
	var elephant = spawn("elephant", Vector3(0, 8, 0))
	elephant.move.set_physics_process(false)
	elephant.set_physics_process(false)
	forge._register(elephant)
	var rifle = spawn("rifle", Vector3(0, 9, -6))
	rifle.set_physics_process(false)
	rifle.face(elephant.center() - rifle.center(), true)
	var shots := 0
	while is_instance_valid(elephant) and not elephant.is_dead and shots < 30:
		rifle.get_node("Do_shoot").run(context.make(rifle.center(), (elephant.center() - rifle.center()).normalized()))
		shots += 1
		await create_timer(0.12).timeout
	check(not is_instance_valid(elephant) or elephant.is_dead, "Own elephant survives real rifle projectiles")
	results.elephant_rifle_hits = shots
	var shield: Dictionary = parser.parse("quero um escudo anti rifle", lex).recipe
	var shield_item = assembler.build(shield, "head", lex)
	var body = load("res://scenes/player/robot/robot_body.gd")
	check(body.hold_class(shield_item) == "shield", "Shield still uses a sight-obscuring rifle posture")
	var grip: Vector3 = shield_item.grip_local("main")
	var pose: Array = root.get_node("Lexicon").bal("player.hold.classes.shield.hip", [])
	var offset := Vector3(pose[0], pose[1], pose[2]) - grip
	var central_ray := Vector3.FORWARD
	for piece in shield_item.model_pieces:
		var box: AABB = Transform3D(Basis.IDENTITY, offset) * shield_item.model.transform * piece.transform * piece.mesh.get_aabb()
		check(box.intersects_ray(Vector3.ZERO, central_ray) == null, "Shield obstructs the central aiming ray")
	shield_item.free()
	await clear()
	var replication = root.get_node("Session").creations
	check(int(replication._config.get("max_entities", -1)) == 0, "Online animal limit was not removed")
	check(replication._budget_warning(1, 200, 0, {"registered": 1, "spawn_bytes": 64, "state_bytes": 64}).is_empty(), "Online budget still enforces a population cap")
	var player = game.player
	player.set_physics_process(false)
	player.global_position = Vector3(0, 5, 0)
	player.yaw = 0.0
	player.head.rotation.x = 0.0
	var ray: Dictionary = player.look_ray()
	var wall = spawn("wall", ray.origin + ray.direction * 2.0)
	wall.set_physics_process(false)
	wall.move.set_physics_process(false)
	wall.global_position += (ray.origin + ray.direction * 2.0) - wall.center()
	await physics_frame
	await physics_frame
	var snapshot: Dictionary = player.export_network_state()
	player.network_role = "predicted"
	player.network_active = true
	player.input_enabled = true
	player.frozen = false
	player._network_use_held = true
	player._predicted_extract_event = 7
	player._network_ack_event = 6
	player.set_extracting(true)
	player._apply_replicated_values(snapshot)
	check(player.extracting and player._network_use_held, "Stale snapshot undid the local extraction input")
	var matter_before: float = player.matter
	var wall_before: float = wall.matter
	player.extractor._process(0.016)
	check(player.extractor.pulling, "Predicted extraction did not react immediately")
	check(player.matter == matter_before and wall.matter == wall_before, "Extraction preview changed authoritative matter")
	player._network_use_held = false
	player.extractor._process(0.016)
	check(not player.extractor.pulling, "Extraction visual remained after releasing input")
	player._network_ack_event = 7
	player._apply_replicated_values(snapshot)
	check(not player.extracting, "Acknowledged extraction state was not reconciled")
	player.network_role = "offline"
	player.network_active = false
	player.extractor.stop()
	results.predicted_extraction = "immediate visual, no client matter, release and acknowledgement reconciled"
	var report := {"results": results, "failures": failures}
	var file := FileAccess.open("C:/Tony/Projetos/lavoice-lab/analysis/reported-regressions.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("REPORTED_REGRESSIONS ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
