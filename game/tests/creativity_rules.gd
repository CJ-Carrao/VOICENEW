extends SceneTree

var game
var lex
var assembler
var recipe_type
var parser
var combat
var rules
var cost_type
var ctx_type
var failures: Array[String] = []
var evidence := {}

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func spawn(id: String, at: Vector3, team: int = 1, recipe: Dictionary = {}):
	var item = assembler.build(recipe_type.new_node(id) if recipe.is_empty() else recipe, "head", lex)
	item.set_owner_info(team, team, game.player if team == 1 else game.opponent, game.player)
	game.add_thing(item)
	item.global_position = at
	item.activate()
	item.set_physics_process(false)
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
	recipe_type = load("res://scripts/language/recipe.gd")
	parser = load("res://scripts/language/phrase_parser.gd")
	combat = load("res://scripts/things/combat.gd")
	rules = load("res://scripts/things/innovation_rules.gd")
	cost_type = load("res://scripts/language/cost.gd")
	ctx_type = load("res://scripts/things/action_context.gd")
	await create_timer(0.5).timeout
	var phrases := []
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chaos_catalog.json"))
	for entry in catalog.combinations:
		var phrase := String(entry.phrase)
		var result: Dictionary = parser.parse(phrase, lex)
		check(result.get("ok", false) and result.get("unknown_words", []).is_empty(), "Composition failed: " + phrase + " " + str(result))
		phrases.append({"phrase": phrase, "result": result})
	evidence.phrases = phrases
	var duck_recipe: Dictionary = parser.parse("quero um pato que só coma formigas", lex).get("recipe", {})
	check(duck_recipe.get("mods", {}).get("diet") == "ant", "Duck lost its exclusive ant diet")
	var armed: Dictionary = parser.parse("quero um jacaré que use uma AK 47", lex).get("recipe", {})
	check(not armed.get("mods", {}).get("grafts", []).is_empty(), "Alligator lost its mounted weapon")
	var shield_gun: Dictionary = parser.parse("quero uma arma que faça um escudo anti bomba de neutrons", lex).get("recipe", {})
	check(not shield_gun.is_empty(), "Shield gun composition failed")
	var speech_repaired: Dictionary = parser.parse("quero uma arma que fala um escudo anti bomba de neutrons", lex).get("recipe", {})
	check(speech_repaired == shield_gun, "Offline speech confusion faça/fala lost the shield-production behavior")
	var queen_recipe: Dictionary = parser.parse("quero uma formiga rainha que faça um ninho", lex).get("recipe", {})
	check(is_equal_approx(cost_type.of(queen_recipe, lex), cost_type.of(recipe_type.new_node("queen_ant"), lex)), "Naming built-in nest production overcharged the queen")
	var origin := Vector3(12, 2, 12)
	var bomb = spawn("neutron_bomb", origin, 2)
	var victim = spawn("cow", origin)
	var shield = spawn("blast_shield", origin)
	await process_frame
	victim.hp = 1000
	combat.apply_damage(victim, 100, "explosive", bomb)
	var ordinary_loss: float = 1000 - victim.hp
	check(ordinary_loss > 95, "Ordinary blast shield incorrectly blocks neutrons")
	shield.remove()
	await process_frame
	shield = spawn("neutron_shield", origin)
	await process_frame
	victim.hp = 1000
	combat.apply_damage(victim, 100, "neutron", bomb)
	var special_loss: float = 1000 - victim.hp
	check(special_loss < 15 and shield.hp < shield.max_hp, "Specialized shield lacks protection or durability wear")
	evidence.defense = {"ordinary_damage": ordinary_loss, "special_damage": special_loss, "shield_hp": shield.hp}
	check(cost_type.of(recipe_type.new_node("neutron_shield"), lex) < cost_type.of(recipe_type.new_node("neutron_bomb"), lex), "Counter costs more than neutron bomb")
	check(cost_type.of(recipe_type.new_node("nuclear_bomb"), lex) >= 200, "Nuclear bomb too cheap")
	await clear()
	game.player.add_matter(1000)
	var queen = spawn("queen_ant", origin)
	var queen_ai = queen.get_node("EcologyBehavior")
	queen_ai.set_physics_process(false)
	var before: float = game.player.matter_spendable()
	queen_ai._produce()
	await process_frame
	var nests := []
	for item in game.get_node("Things").get_children():
		if item.thing_id == "ant_nest":
			nests.append(item)
	check(nests.size() == 1 and game.player.matter_spendable() < before, "Queen did not create a paid nest")
	if not nests.is_empty():
		var nest = nests[0]
		var ai = nest.get_node("EcologyBehavior")
		ai.set_physics_process(false)
		for i in 12:
			ai._produce()
		await process_frame
		var ants := 0
		for item in game.get_node("Things").get_children():
			if item.thing_id == "ant":
				ants += 1
		check(ants == 8, "Nest population cap failed: " + str(ants))
		queen.die()
		check(not ai._living_queen(), "Nest stays fertile after queen death")
		before = game.player.matter_spendable()
		ai._produce()
		check(is_equal_approx(before, game.player.matter_spendable()), "Dead colony continues spending and reproducing")
		evidence.colony = {"nests": nests.size(), "ants": ants, "queen_dead_stops": not ai._living_queen()}
	await clear()
	var duck = spawn("duck", origin, 1, duck_recipe)
	var diet_ai = duck.get_node_or_null("EcologyBehavior")
	check(diet_ai != null, "Duck diet has no live behavior")
	var prey = spawn("queen_ant", origin + Vector3(0.1, 0, 0), 1)
	prey.get_node("EcologyBehavior").set_physics_process(false)
	prey.hp = 7
	var chicken = spawn("chicken", origin + Vector3(0.05, 0, 0), 1)
	var chicken_hp: float = chicken.hp
	if diet_ai != null:
		diet_ai.set_physics_process(false)
		diet_ai._hunt()
		check(prey.is_dead and chicken.hp == chicken_hp, "Diet failed to kill own queen while sparing chicken")
		evidence.diet = {"queen_killed": prey.is_dead, "chicken_spared": chicken.hp == chicken_hp}
	await clear()
	var producer = spawn("shield_projector", origin)
	game.player.take_matter(game.player.matter_spendable())
	check(not rules.authorize_spawn(producer, recipe_type.new_node("neutron_shield")), "Shield producer bypassed insufficient matter")
	await clear()
	var house = spawn("walking_house", game.player.global_position + game.player.up() * 4.0)
	check(house.move.get_script().resource_path.ends_with("move_chase_enemy.gd") and house.speed > 0, "Walking house has no locomotion")
	var gator = spawn("crocodile", origin + Vector3(3, 0, 0), 1, armed)
	check(gator.grafts.size() > 0, "Armed alligator did not assemble a real weapon")
	if not gator.grafts.is_empty():
		var gun = gator.grafts[0]
		var ammo: int = gun.ammo
		var fired: bool = gun.fire(ctx_type.make(gun.center(), Vector3.FORWARD))
		check(fired and gun.ammo < ammo, "Mounted AK did not fire or consume ammunition")
		evidence.armed = {"weapon": gun.thing_id, "fired": fired, "ammo_before": ammo, "ammo_after": gun.ammo}
	var start: Vector3 = house.global_position
	await create_timer(0.6).timeout
	check(Vector2(house.global_position.x - start.x, house.global_position.z - start.z).length() > 0.1, "House did not actually walk")
	evidence.house_distance = house.global_position.distance_to(start)
	await clear()
	game.player.add_matter(1000)
	queen = spawn("queen_ant", origin)
	await create_timer(4.7).timeout
	var live_nests := 0
	var live_ants := 0
	for item in game.get_node("Things").get_children():
		if item.thing_id == "ant_nest":
			live_nests += 1
		elif item.thing_id == "ant":
			live_ants += 1
	check(live_nests == 1 and live_ants >= 1, "Timed ecological chain did not produce queen -> nest -> ant")
	evidence.timed_colony = {"nests": live_nests, "ants": live_ants}
	await clear()
	bomb = spawn("neutron_bomb", origin, 2)
	var volume = load("res://scripts/world/block_volume.gd").new()
	volume.setup(9999, Vector3i(8, 8, 8), Vector3.ZERO)
	var wood: int = volume.add_type("wood", Color.BROWN)
	volume.blocks.fill(wood)
	game.add_child(volume)
	volume.global_position = bomb.center() - Vector3.ONE
	volume.commit_base()
	await create_timer(0.1).timeout
	bomb.get_node("Do_anomaly").run(bomb.context_here())
	var remaining := 0
	for cell in volume.blocks:
		if cell != 0:
			remaining += 1
	check(remaining < 512, "Neutron explosion emitted effects but did not remove actual world blocks")
	evidence.neutron_blocks = {"before": 512, "after": remaining, "removed": 512 - remaining}
	volume.queue_free()
	var report := {"evidence": evidence, "failures": failures}
	var file := FileAccess.open(ProjectSettings.globalize_path("res://").path_join("../analysis/creativity-rules.json").simplify_path(), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("CREATIVITY_RULES ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
