extends SceneTree

var failures := []
var game
var lex
var parser
var assembler
var forge
var combat
var status

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func spawn(phrase: String, at: Vector3, team: int = 1):
	var parsed: Dictionary = parser.parse(phrase, lex)
	check(parsed.get("ok", false) and parsed.unknown_words.is_empty(), "Invalid phrase: " + phrase)
	var thing = assembler.build(parsed.recipe, "head", lex)
	thing.set_owner_info(team, team, game.player if team == 1 else game.opponent, null)
	game.add_thing(thing)
	thing.global_position = at
	thing.activate()
	thing.move.set_physics_process(false)
	thing.set_physics_process(false)
	return thing
func tick_builder(builder, ticks: int) -> void:
	for step in ticks:
		builder.work_frame = -1
		forge.production.reset()
		builder.tick_left = 0.0
		builder._physics_process(.25)

func _run() -> void:
	await process_frame
	lex = root.get_node("Lexicon").data
	parser = load("res://scripts/language/phrase_parser.gd")
	assembler = load("res://scripts/things/assembler.gd")
	forge = root.get_node("Forge")
	combat = load("res://scripts/things/combat.gd")
	status = load("res://scripts/things/status.gd")
	load("res://scenes/main.gd").next_mode = "practice"
	game = load("res://scenes/main.tscn").instantiate()
	game.voice_enabled = false
	root.add_child(game)
	current_scene = game
	await create_timer(.6).timeout
	game.player.frozen = false
	game.player.set_physics_process(false)
	game.player.global_position = Vector3(0, 20, 8)
	game.opponent.set_physics_process(false)
	game.opponent.global_position = Vector3(0, 20, -7)
	game.opponent.add_to_group("combatants")
	var species_checked := 0
	for id in lex.defs.things:
		if not lex.defs.things[id] is Dictionary or lex.defs.things[id].get("category") != "creature": continue
		if lex.defs.things[id].get("coop_boss",false): continue # Encounter boss is not a summonable companion.
		var item = assembler.build({"thing": id}, "head", lex)
		check(item.get_node_or_null("AnimalOrders") != null, "Missing orders: " + id)
		item.free()
		for action in ["follow", "stay", "guard", "attack", "evade", "retaliate", "free", "build", "aggressive"]:
			var key: String = "animal_order_" + id + "_" + action
			var parsed: Dictionary = parser.parse(lex.lexicon.commands[key].words[0], lex)
			check(parsed.get("ok", false) and parsed.recipe.get("command") == key, "Named order not parsed: " + key)
		var aggressive: Dictionary = parser.parse("quero um " + lex.lexicon.things[id].words[0] + " agressivo", lex)
		check(aggressive.get("ok", false) and aggressive.recipe.get("mods", {}).get("aggressive", false), "Aggression modifier missing: " + id)
		species_checked += 1
	var dog = spawn("quero um cachorro com uma pistola", Vector3(0, 20, 0))
	var orders = dog.get_node("AnimalOrders")
	game.player.look_at_point(dog.center())
	await physics_frame
	await physics_frame
	check(forge.request(1, "me siga", false, true).get("animal_order") == "follow", "Aim selection failed")
	orders._physics_process(1.0)
	check(orders.goal.distance_to(game.player.global_position) < .01, "Follow goal wrong")
	orders.drive(.1)
	check(dog.velocity.z > 0.0, "Follow did not steer toward trainer")
	check(forge.request(2, "cachorro fique aqui", false, true).get("blocked", false), "Enemy stole an animal order")
	check(forge.request(1, "cachorro fique aqui", false, true).get("animal_order") == "stay", "Stay command failed")
	check(combat.nearest_target(dog.grafts[0], dog.center(), self) == null, "Mounted gun ignored stay policy")
	game.player.look_at_point(game.opponent.center())
	await physics_frame
	var attack_reply: Dictionary = forge.request(1, "cachorro ataque aquele jogador", false, true)
	check(attack_reply.get("animal_order") == "attack" and orders.combat_target() == game.opponent, "Explicit player attack failed: " + str(attack_reply))
	check(combat.nearest_target(dog.grafts[0], dog.center(), self) == game.opponent, "Weapon ignored selected target")
	orders.set_order("retaliate", dog.global_position)
	orders._physics_process(1.0)
	check(orders.combat_target() == null, "Retaliation attacked without aggression")
	var enemy = spawn("quero uma pistola", Vector3(8, 20, 0), 2)
	combat.apply_damage(game.player, 1.0, "kinetic", enemy)
	orders._physics_process(1.0)
	check(orders.combat_target() == game.opponent, "Retaliation did not select trainer's attacker")
	var diet = spawn("quero um elefante que só coma dragões", Vector3(4, 20, 0))
	check(forge.request(1, "elefante ataque aquele jogador", false, true).get("blocked", false), "Order bypassed species diet")
	var bomb = spawn("quero uma bomba nuclear", Vector3(1, 20, 0), 2)
	orders.set_order("evade", dog.global_position)
	orders._physics_process(1.0)
	check((orders.goal - dog.global_position).dot(dog.global_position - bomb.global_position) > 0.0, "Animal did not flee bomb")
	check(orders.bomb_cache.size() == 1, "Ordinary animals or weapons were mistaken for bombs")
	var house = spawn("quero uma casa ambulante", Vector3(10, 20, 0))
	game.player.look_at_point(house.center())
	check(forge.request(1, "cachorro proteja minha casa", false, true).get("animal_order") == "guard" and orders.point.distance_to(house.global_position) < 1.0, "Guard did not select house")
	house.global_position += Vector3(2, 0, 0)
	orders._physics_process(1.0)
	check(orders.point.distance_to(house.global_position) < .01, "Guard did not track walking house")
	var aggressive = spawn("quero um mahoraga agressivo", Vector3(30, 20, 0))
	var innocent = spawn("quero um elefante", Vector3(30, 20, -2))
	var behind = spawn("quero um elefante", Vector3(30, 20, 3))
	var fury = aggressive.get_node("AnimalOrders")
	await physics_frame
	fury._physics_process(1.0)
	check(fury.mode == "aggressive" and fury.combat_target() == innocent and combat.affects(aggressive, innocent), "Aggressive creature did not attack friendly creature in front")
	check(not combat.affects(aggressive, behind) and not combat.affects(aggressive, game.player), "Aggressive creature targeted behind itself or its owner")
	var player_hp: float = game.player.health
	combat.apply_damage(game.player, 100.0, "explosive", aggressive)
	check(game.player.health == player_hp, "Aggressive power hurt trainer")
	enemy.spawner = aggressive
	combat.apply_damage(game.player, 100.0, "explosive", enemy)
	check(game.player.health == player_hp, "Aggressive descendant hurt trainer")
	enemy.spawner = null
	var ball = spawn("quero uma pokebola", Vector3(28, 20, 0))
	check(ball.get_node("CaptureBall")._attempt(weakref(aggressive), 0.0), "Cannot capture aggressive creature")
	check(not fury.available(), "Captured aggressive creature kept acting")
	check(ball.get_node("CaptureBall").release() == aggressive, "Aggression broke capture")
	var flyer = spawn("quero um pombo", Vector3(20, 20, 5))
	flyer.get_node("AnimalOrders").set_order("follow", flyer.global_position)
	flyer.get_node("AnimalOrders")._physics_process(1.0)
	flyer.get_node("AnimalOrders").drive(.1)
	check(flyer.velocity.length() > 0.0 and flyer.move.hovers(), "Orders broke flight")
	flyer.remove()
	var crowd := []
	var began := Time.get_ticks_msec()
	for i in 80:
		var pet = spawn("quero uma formiga", Vector3(-20, 20, i * .1))
		var command = pet.get_node("AnimalOrders")
		command.set_order("follow", pet.global_position)
		command._physics_process(.25)
		check(command.goal.distance_to(game.player.global_position) < .01, "Crowd order lost trainer")
		crowd.append(pet)
	print("ORDER_CROWD ", {"animals": crowd.size(), "setup_and_ticks_ms": Time.get_ticks_msec() - began})
	for pet in crowd: pet.remove()
	# An elevated soil fixture keeps construction tests separate from map geometry.
	var volume = load("res://scripts/world/block_volume.gd").new()
	volume.setup(777, Vector3i(32, 8, 24), Vector3(-4, 18, -3))
	var soil: int = volume.add_type("soil", Color("72583d"))
	var bedrock: int = volume.add_type("soil", Color("363636"), 2)
	volume.blocks.fill(soil)
	for x in 32:
		for z in 24: volume.blocks[volume.index_of(Vector3i(x, 0, z))] = bedrock
	game.add_child(volume)
	volume.add_to_group("terrain")
	volume.commit_base()
	var beaver = spawn("quero um castor", Vector3(2, 20, 2))
	var worker = beaver.get_node("CreatureBuilder")
	await physics_frame
	check(not worker.begin(Vector3(0, 20, -1.5), Vector3.FORWARD).get("blocked", false), "Cannot begin dam")
	beaver.get_node("AnimalOrders").set_order("build", worker.work_point)
	beaver.global_position = worker.work_point + Vector3(2, 0, 1)
	game.player.matter = 0.0
	tick_builder(worker, 17)
	check(worker.running and worker.state == "sem matéria", "Construction bypassed economy: " + str(worker.snapshot()) + " at=" + str(worker.work_point))
	game.player.matter = 200.0
	tick_builder(worker, 1)
	var dam = null
	for product in get_nodes_in_group("creature_builder_products"):
		if product.kind == "dam": dam = product.thing
	check(dam != null and not worker.running and worker.completed == 1 and is_equal_approx(game.player.matter, 168.0), "Dam construction or cost failed")
	if dam != null:
		combat.apply_damage(dam, 1000.0, "explosive", enemy)
		check(dam.is_dead, "Dam is not destructible")
	var caps := []
	for i in 2:
		var wall = spawn("quero uma barragem de castor", Vector3(-30, 20, i * 4))
		wall.spawner = beaver
		caps.append(wall)
	check(not worker._within_cap(), "Per-builder dam cap failed")
	for wall in caps: wall.remove()
	var spider = spawn("quero uma aranha", Vector3(-2, 20, 2))
	worker = spider.get_node("CreatureBuilder")
	check(not worker.begin(Vector3(-2, 20, 0), Vector3.FORWARD).get("blocked", false), "Cannot begin web")
	spider.get_node("AnimalOrders").set_order("build", worker.work_point)
	game.player.matter = 200.0
	tick_builder(worker, 11)
	var web = null
	for product in get_nodes_in_group("creature_builder_products"):
		if product.kind == "web": web = product
	check(web != null and is_equal_approx(game.player.matter, 184.0), "Web construction or cost failed")
	if web != null:
		check((innocent.collision_mask & web.thing.collision_layer) == 0 and (game.player.collision_mask & web.thing.collision_layer) == 0, "Web should slow bodies without acting as a solid wall")
		innocent.set_owner_info(2, 2, game.opponent, null)
		innocent.global_position = web.thing.global_position
		dog.global_position = web.thing.global_position
		for frame in 3: await physics_frame
		web.tick_left = 0.0
		web._physics_process(.3)
		check(status.snapshot(innocent).has("webbed") and not status.snapshot(dog).has("webbed"), "Web did not slow only enemies: " + str(status.snapshot(innocent)) + " / " + str(status.snapshot(dog)) + " targets=" + str(combat.in_radius(web.thing, web.thing.center(), 1.8)))
		combat.apply_damage(web.thing, 1000.0, "fire", enemy)
		check(web.thing.is_dead, "Web is not destructible")
	var ant = spawn("quero uma formiga", Vector3(2, 20, 2))
	worker = ant.get_node("CreatureBuilder")
	check(not worker.begin(Vector3(2, 20, 0), Vector3.FORWARD).get("blocked", false), "Cannot begin tunnel")
	ant.get_node("AnimalOrders").set_order("build", worker.work_point)
	var original_cells: int = volume.blocks.count(soil)
	var original_protected: int = volume.blocks.count(bedrock)
	game.player.matter = 200.0
	tick_builder(worker, 30)
	check(worker.dug_total > 0 and worker.dug_total <= 96 and volume.blocks.count(soil) < original_cells, "Tunnel did not remove bounded soil cells")
	check(volume.blocks.count(bedrock) == original_protected and is_equal_approx(200.0 - game.player.matter, worker.dug_total * .3), "Digging changed protected blocks or charged wrong cost")
	var original_dug: int = worker.dug_total
	worker.dug_total = 192
	check(not worker._within_cap(), "Per-ant excavation cap failed")
	worker.dug_total = original_dug
	worker.cooldown_until = 0
	check(not worker.begin(Vector3(1, 20, 0), Vector3.FORWARD).get("blocked", false), "Cannot begin cancellation fixture")
	ant.get_node("AnimalOrders").set_order("build", worker.work_point)
	check(ball.get_node("CaptureBall")._attempt(weakref(ant), 0.0) and not worker.running, "Capture did not cancel construction")
	ball.get_node("CaptureBall").release()
	worker.cooldown_until = 0
	worker.begin(Vector3(0, 20, 1), Vector3.FORWARD)
	ant.get_node("AnimalOrders").set_order("build", worker.work_point)
	ant.remove()
	check(not worker.running, "Death did not cancel construction")
	for item in [dog, enemy, diet, bomb, house, aggressive, innocent, behind, ball, beaver, spider]: item.remove()
	if web != null: web.thing.remove()
	volume.queue_free()
	print("ANIMAL_ORDERS_BUILDERS ", JSON.stringify({"failures": failures, "species": species_checked}))
	quit(0 if failures.is_empty() else 1)
