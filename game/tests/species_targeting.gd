extends SceneTree

var game
var lex
var parser
var assembler
var recipes
var combat
var rules
var failures := []
var evidence := {}

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

func clear() -> void:
	for item in game.get_node("Things").get_children(): item.remove()
	await process_frame

func _run() -> void:
	await process_frame
	load("res://scenes/main.gd").next_mode = "practice"
	game = load("res://scenes/main.tscn").instantiate()
	game.voice_enabled = false
	root.add_child(game)
	current_scene = game
	lex = root.get_node("Lexicon").data
	parser = load("res://scripts/language/phrase_parser.gd")
	assembler = load("res://scripts/things/assembler.gd")
	recipes = load("res://scripts/language/recipe.gd")
	combat = load("res://scripts/things/combat.gd")
	rules = load("res://scripts/things/innovation_rules.gd")
	await create_timer(0.7).timeout
	var species := []
	for id: String in lex.defs.things:
		if lex.thing_def(id).get("category", "") == "creature": species.append(id)
	var pairs := 0
	for hunter: String in species:
		for prey: String in species:
			for verb in ["ataque", "coma"]:
				var phrase: String = "quero " + lex.thing_name(hunter) + " que só " + verb + " " + lex.thing_name(prey)
				var parsed: Dictionary = parser.parse(phrase, lex)
				var expected: String = lex.defs.modifiers["diet_species_" + prey].value
				check(parsed.get("ok", false) and parsed.recipe.thing == hunter and parsed.recipe.mods.get("diet", "") == expected and parsed.get("unknown_words", []).is_empty() and parsed.get("ignored_words", []).is_empty(), "Species pair failed: " + phrase)
				pairs += 1
	evidence.parsed_pairs = pairs
	for phrase in ["quero um elefante que só ataque dragões", "quero um elefante que só coma dragoes", "quero uma galinha que só atacar elefantes", "quero uma abelha que só ataca capivaras", "quero um elefante que só ataque os dragões", "quero um pato que coma apenas as formigas"]:
		var parsed: Dictionary = parser.parse(phrase, lex)
		check(parsed.get("ok", false) and parsed.get("unknown_words", []).is_empty() and parsed.get("ignored_words", []).is_empty() and not parsed.recipe.mods.get("diet", "").is_empty(), "Colloquial target phrase failed: " + phrase)
	# All species execute the real damage path against their selected prey.
	for id: String in species:
		var recipe: Dictionary = recipes.new_node(id)
		recipe.mods.diet = "species:dragon"
		var hunter = spawn(recipe, Vector3(0, 10, 0))
		var prey = spawn(recipes.new_node("dragon"), Vector3(0, 10, 0.5))
		prey.hp = 1.0
		var ignored = spawn(recipes.new_node("chicken"), Vector3(0.2, 10, 0))
		var original_hp: float = ignored.hp
		check(combat.nearest_target(hunter, hunter.center(), self) == prey, "Wrong target selected by " + id)
		combat.apply_damage(ignored, 1000, "bite", hunter)
		check(ignored.hp == original_hp, "Hunter attacked unselected species: " + id)
		hunter.get_node("EcologyBehavior").clock = 1.0
		hunter.get_node("EcologyBehavior")._hunt()
		check(prey.is_dead, "Hunter cannot attack its selected species: " + id)
		await clear()
	evidence.species_attacking = species.size()
	# A grounded elephant must pursue and bite a dragon above the floor.
	var elephant_recipe: Dictionary = parser.parse("quero um elefante que só ataque dragões", lex).recipe
	var elephant = spawn(elephant_recipe, Vector3(0, 1, 8))
	var dragon = spawn(recipes.new_node("dragon"), Vector3(0, 2, 0))
	dragon.move.set_physics_process(false)
	var chicken = spawn(recipes.new_node("chicken"), Vector3(5, 1, 8))
	chicken.move.set_physics_process(false)
	var chicken_hp: float = chicken.hp
	var start: Vector3 = elephant.global_position
	await create_timer(5.0).timeout
	check(is_instance_valid(elephant) and not elephant.is_dead and elephant.global_position.distance_to(start) > 2.0, "Elephant failed to pursue dragons")
	check(not is_instance_valid(dragon) or dragon.is_dead, "Elephant cannot reach the flying dragon's body")
	check(is_instance_valid(chicken) and chicken.hp == chicken_hp, "Elephant harmed a nearby chicken")
	evidence.elephant_pursuit = "dragon killed, chicken spared"
	await clear()
	# Guns inherit the carrier's target; shots retain it after their carrier dies.
	var armed: Dictionary = parser.parse("quero um elefante que só ataque dragões com uma pistola", lex).recipe
	var carrier = spawn(armed, Vector3(0, 10, 0))
	var target = spawn(recipes.new_node("dragon"), Vector3(0, 10, -4))
	var bystander = spawn(recipes.new_node("chicken"), Vector3(0, 10, -1))
	check(carrier.grafts.size() == 1 and carrier.node_data.mods.get("diet", "") == "species:dragon", "Armed carrier lost target restriction")
	if carrier.grafts.size() == 1:
		var gun = carrier.grafts[0]
		check(combat.nearest_target(gun, gun.center(), self) == target, "Mounted gun ignored the carrier's target restriction")
		var bullet = root.get_node("Forge").spawn_child(recipes.new_node("bullet"), "projectile", Vector3(0, 15, 0), Vector3.FORWARD, gun, 0.0)
		check(bullet != null, "No projectile spawned")
		if bullet != null:
			carrier.remove()
			await process_frame
			var hp: float = bystander.hp
			combat.apply_damage(bystander, 100, "kinetic", bullet)
			check(bystander.hp == hp, "Projectile harmed another species after its carrier died")
			var target_hp: float = target.hp
			combat.apply_damage(target, 1, "kinetic", bullet)
			check(target.hp < target_hp, "Projectile cannot hit a matching creature of its own team")
	var report := {"evidence": evidence, "failures": failures}
	var path := ProjectSettings.globalize_path("res://").path_join("../analysis/species-targeting.json").simplify_path()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("SPECIES_TARGETING ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
