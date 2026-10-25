extends SceneTree

var game
var lex
var parser
var assembler
var failures = []
var serial = 12000
func _initialize() -> void:
	run.call_deferred()
	watchdog.call_deferred()
func watchdog() -> void:
	await create_timer(35).timeout
	push_error("Tactical test timed out")
	quit(2)
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func spawn(phrase: String, at: Vector3, team: int = 1, role: String = "head"):
	var parsed: Dictionary = parser.parse(phrase,lex)
	check(parsed.ok and parsed.unknown_words.is_empty() and parsed.ignored_words.is_empty(),"Bad phrase: "+phrase+" "+str(parsed))
	var actor = assembler.build(parsed.recipe,role,lex)
	serial += 1
	actor.network_id = serial
	actor.set_owner_info(team,team,game.player if team == 1 else game.opponent,null)
	game.add_thing(actor)
	actor.global_position = at
	actor.activate()
	actor.set_physics_process(false)
	actor.move.set_physics_process(false)
	return actor
func clear() -> void:
	for actor in game.get_node("Things").get_children(): actor.remove()
	await create_timer(.2).timeout
	root.get_node("Forge").production.reset()
	game.player.remove_meta("animal_last_attacker")
func command(text: String) -> Dictionary: return root.get_node("Forge").request(1,text,false,true)
func run() -> void:
	await process_frame
	lex = root.get_node("Lexicon").data
	parser = load("res://scripts/language/phrase_parser.gd")
	assembler = load("res://scripts/things/assembler.gd")
	load("res://scenes/main.gd").next_mode = "practice"
	game = load("res://scenes/main.tscn").instantiate()
	game.voice_enabled = false
	root.add_child(game)
	current_scene = game
	await create_timer(.6).timeout
	for player in [game.player,game.opponent]: player.set_physics_process(false); player.frozen = false
	game.player.global_position = Vector3(0,40,8)
	game.opponent.global_position = Vector3(30,40,30)
	var combat = load("res://scripts/things/combat.gd")
	var actor = spawn("quero um cachorro",Vector3(0,40,0))
	var enemy = spawn("quero um elefante",Vector3(0,40,-8),2)
	var orders = actor.get_node("AnimalOrders")
	combat.apply_damage(actor,1.0,"bite",enemy)
	await create_timer(.3).timeout
	check(orders.automatic_active and orders.combat_target() == enemy,"Animal did not retaliate against its actual attacker")
	orders.set_order("stay",actor.global_position)
	await create_timer(.25).timeout
	check(not orders.automatic_active and orders.combat_target() == null,"Automatic defense overrode stay")
	actor.remove_meta("animal_last_attacker")
	orders.set_order("follow",actor.global_position)
	combat.apply_damage(game.player,1.0,"bite",enemy)
	await create_timer(.25).timeout
	check(orders.combat_target() == enemy and "treinador" in orders.last_label,"Nearby creature did not protect its attacked owner")
	game.player.global_position = Vector3(40,40,40)
	await create_timer(.25).timeout
	check(not orders.automatic_active,"Creature defended a distant owner across the map")
	await clear()
	game.player.global_position = Vector3(0,40,8)
	# Living passengers keep their identity, weapons and gameplay while attached.
	var eagle = spawn("quero uma aguia",Vector3(0,40,0))
	var dog = spawn("quero um cachorro com rifle",Vector3(0,40,2))
	var rifle = dog.grafts[0]
	check(not command("aguia carregue um cachorro").get("blocked",false),"Carry voice command failed")
	await create_timer(.25).timeout
	var rig = eagle.get_node("CreatureTactics")
	check(rig.passenger() == dog and dog.get_node("CreatureTactics").being_carried(),"Eagle did not carry dog")
	var old: Vector3 = dog.center()
	eagle.global_position += Vector3(2,0,0)
	await physics_frame; await physics_frame
	check(dog.center().distance_to(old+Vector3(2,0,0)) < .1 and dog.grafts[0] == rifle and dog.can_act(),"Passenger moved incorrectly or lost its weapon")
	var ball = spawn("quero uma pokebola",Vector3(0,40,5))
	check(ball.get_node("CaptureBall")._attempt(weakref(dog),0.0),"Carried creature could not be captured")
	check(rig.passenger() == null and not dog.get_node("CreatureTactics").being_carried(),"Capture left a dangling passenger")
	var elephant = spawn("quero um elefante com armadura",Vector3(12,40,0))
	var tower = spawn("quero uma torre com rifle",Vector3(12,40,2))
	check(elephant.get_node("CreatureTactics").can_carry(tower),"Elephant could not carry a tower")
	check(not rig.can_carry(elephant),"Eagle could carry an elephant")
	check(not command("elefante carregue uma torre").get("blocked",false),"Tower transport command failed")
	await create_timer(.25).timeout
	check(elephant.get_node("CreatureTactics").passenger() == tower,"Tower did not board elephant")
	command("elefante solte a carga")
	check(not tower.get_node("CreatureTactics").being_carried(),"Tower could not disembark")
	var ant = spawn("quero uma formiga",Vector3(12,40,1))
	var ant_two = spawn("quero uma formiga",Vector3(13,40,1))
	elephant.hp -= 20.0
	game.player.add_matter(200)
	var hp: float = elephant.hp
	var matter: float = game.player.matter_spendable()
	var repair_reply: Dictionary = command("formigas consertem a armadura do elefante")
	check(not repair_reply.get("blocked",false) and repair_reply.get("creature_count") == 2,"Repair command failed to address both ants")
	await create_timer(.3).timeout
	check(is_equal_approx(elephant.hp,hp+4.0) and is_equal_approx(game.player.matter_spendable(),matter-2.4),"Repair was free, stacked or did not heal armor")
	await clear()
	# Conditional guard/rescue and explicit cancellation.
	actor = spawn("quero um cachorro",Vector3(0,40,0))
	var friend = spawn("quero um pikachu",Vector3(0,40,2))
	check(not command("cachorro proteja o pikachu se ele ficar ferido leve ele ate mim").get("blocked",false),"Conditional rescue sentence failed")
	await create_timer(.2).timeout
	check(actor.get_node("CreatureTactics").passenger() == null,"Healthy companion was kidnapped")
	friend.hp = friend.max_hp*.3
	await create_timer(.25).timeout
	check(actor.get_node("CreatureTactics").passenger() == friend,"Wounded companion was not rescued")
	actor.global_position = game.player.global_position-Vector3(0,0,2)
	await create_timer(.25).timeout
	check(actor.get_node("CreatureTactics").rule == "guard_friend" and not friend.get_node("CreatureTactics").being_carried(),"Rescue did not deliver companion to trainer")
	orders = actor.get_node("AnimalOrders")
	orders.set_order("stay",actor.global_position)
	check(actor.get_node("CreatureTactics").rule.is_empty(),"Normal order failed to cancel conditional rule")
	await clear()
	# Same individual transforms, keeps gear/skills and never gets a free heal.
	actor = spawn("quero um cachorro com habilidade do squirtle com rifle que vire tanque quando estiver com pouca vida",Vector3(0,40,0))
	var power = actor.get_node("CreatureTransform")
	var cost = load("res://scripts/language/cost.gd")
	check(cost.of(actor.node_data,lex) >= 80,"Transformation had no extra cost")
	rifle = actor.grafts[0]
	rifle.ammo = 3
	actor.hp = actor.max_hp*.3
	hp = actor.hp
	await create_timer(.15).timeout
	check(power.active and actor.thing_id == "dog" and actor.hp == hp and actor.grafts[0] == rifle and rifle.ammo == 3,"Transformation duplicated gear, changed identity or healed")
	check(actor.get_node("FusionPowers").companions.size() == 1 and power.damage_multiplier() == .65,"Transformation lost inherited powers or armor")
	var net = load("res://scripts/network/thing_network_state.gd")
	var replica = assembler.build_replica(actor.node_data,"head",lex,22001,1)
	game.add_thing(replica); replica.activate()
	net.apply(replica,net.capture(actor))
	check(replica.get_node("CreatureTransform").active and replica.bounds.size.is_equal_approx(actor.bounds.size),"Transformed body did not replicate")
	replica.remove()
	var foe = spawn("quero uma vaca",Vector3(0,40,-9),2)
	foe.hp = 10000; foe.max_hp = 10000
	actor.move.set_physics_process(false)
	actor.get_node("AnimalOrders").set_order("attack",actor.global_position,foe)
	power.shot_left = .01
	await create_timer(.18).timeout
	var missiles = 0
	for candidate in game.get_node("Things").get_children():
		if candidate.thing_id == "missile": missiles += 1
	check(missiles > 0 and power.weapon != null,"Tank form had no working cannon")
	power.revert()
	check(not power.active and actor.hp == hp and actor.grafts[0] == rifle and power.cooldown > 0,"Reverting reset health, gear or cooldown")
	await clear()
	# Actual swept movement catches a fast projectile, without converting bombs.
	var shield = spawn("quero escudo que transforma balas em borboletas",Vector3(0,40,0))
	var converter = shield.get_node("ButterflyShield")
	var bullet = spawn("quero uma bala",Vector3(2.5,40,8),2,"projectile")
	await physics_frame; await physics_frame
	bullet.move.travel(Vector3(0,0,-16))
	check(bullet.is_dead and converter.converted == 1 and converter.energy < 20,"Fast bullet crossed converter without being stopped: %s/%s/%s/%s/%s/%s" % [bullet.thing_id,bullet.category,bullet.role,bullet.explosion_radius,converter.usable(),converter.accepts(bullet)])
	var bomb = spawn("quero uma bomba nuclear",Vector3(15,40,8),2,"projectile")
	check(not converter.accepts(bomb),"Converter accepted a nuclear bomb")
	var heavy = spawn("quero uma bala",Vector3(15,40,10),2,"projectile")
	heavy.impact_damage = 40
	check(not converter.accepts(heavy),"Basic converter accepted heavy ammunition")
	var improved = spawn("quero escudo de borboletas avancado",Vector3(15,40,0))
	check(improved.get_node("ButterflyShield").accepts(heavy),"Advanced converter did not improve its power limit: %s/%s/%s/%s" % [heavy.thing_id,heavy.explosion_radius,improved.get_node("ButterflyShield").advanced,improved.get_node("ButterflyShield").usable()])
	converter.energy = 0.0
	heavy.impact_damage = 10
	check(not converter.accepts(heavy),"Exhausted shield kept converting")
	for decorative in get_nodes_in_group("shield_butterflies"): check(decorative.matter == 0.0 and decorative.category != "creature","Converted butterfly became a free combat creature")
	print("TACTICAL_CREATIVITY ",JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)
