extends SceneTree

var failures := []
var game
var lex
var parser
var assembler
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func spawn(phrase: String, at: Vector3, team: int = 1):
	var parsed: Dictionary = parser.parse(phrase,lex)
	check(parsed.ok and parsed.unknown_words.is_empty() and parsed.ignored_words.is_empty(),"Unrecognized phrase: "+phrase+" "+JSON.stringify(parsed))
	var animal = assembler.build(parsed.recipe,"head",lex)
	animal.set_owner_info(team,team,game.player if team == 1 else game.opponent,null)
	game.add_thing(animal)
	animal.global_position = at
	animal.activate()
	animal.set_physics_process(false)
	animal.move.set_physics_process(false)
	return animal
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
	for player in [game.player,game.opponent]:
		player.set_physics_process(false)
		player.frozen = false
		player.global_position = Vector3(25,40,25)
	var fusion = spawn("quero um pikachu com corpo de tiranossauro rex e habilidade do squirtle",Vector3(0,40,0))
	var extra = fusion.get_node("FusionPowers")
	check(extra.companions.size() == 1 and extra.companions[0].pokemon_id == "squirtle","Fusion did not inherit water skills")
	var rules = load("res://scripts/things/fusion_rules.gd")
	var cost = load("res://scripts/language/cost.gd")
	check(rules.price(fusion.node_data,lex) >= 35 and cost.of(fusion.node_data,lex) > cost.of({"thing":"pikachu"},lex),"Inherited powers were free")
	var duplicate: Dictionary = fusion.node_data.duplicate(true)
	duplicate.mods.anatomy.head = "squirtle"
	check(rules.donors(duplicate,lex).count("squirtle") == 1,"Repeated donor stacked its power")
	var foe = spawn("quero um elefante",Vector3(0,40,-5),2)
	foe.hp = 2000; foe.max_hp = 2000
	await create_timer(.12).timeout
	var inherited_reply: Dictionary = extra.companions[0].cast("water_gun")
	check(not inherited_reply.get("blocked",false),"Inherited move could not hit: "+str(inherited_reply))
	check(fusion.get_node("PokemonCompanion").cast("thunderbolt").get("blocked",false),"Fusion bypassed shared cooldown")
	var bond = fusion.get_node("CreatureBond")
	bond.trust = 75.0
	fusion.set_captured(true)
	fusion.set_captured(false)
	check(bond.trust == 75 and extra.companions.size() == 1,"Capture lost fusion/bond")
	# Evolution keeps inherited abilities and the same individual.
	fusion.get_node("PokemonCompanion").change_form("raichu")
	check(fusion.thing_id == "raichu" and extra.companions[0].pokemon_id == "squirtle" and bond.trust == 75,"Evolution lost fusion or bond")
	var adapted = spawn("quero um cachorro com cabeca de mahoraga",Vector3(8,40,0))
	check(adapted.get_node("Jujutsu").powers.has("adaptation"),"Part did not inherit Mahoraga adaptation")
	var fire_body = spawn("quero um cachorro com corpo de dragao",Vector3(15,40,8))
	check(fire_body.get_node_or_null("Do_shoot") != null,"Dragon body did not inherit breath")
	var aging = spawn("quero raio de envelhecimento",Vector3(15,40,3))
	var age_target = spawn("quero uma vaca",Vector3(15,40,-3),2)
	await create_timer(.12).timeout
	aging.get_node("Do_creative").run(load("res://scripts/things/action_context.gd").make(aging.center(),Vector3.FORWARD))
	check(load("res://scripts/things/status.gd").speed_mult(age_target) == .55 and aging.get_node("Do_creative").cooldown == 5.0,"Age weapon's real firing action failed")
	# Temporary effects preserve identities, equipment and HP.
	var source = spawn("quero raio de troca de cabecas",Vector3(0,40,4))
	var a = spawn("quero um cachorro com rifle",Vector3(0,40,0),2)
	var b = spawn("quero uma galinha",Vector3(.4,40,-2),2)
	var effects = load("res://scripts/things/creative_effects.gd")
	var a_effect = a.get_node("CreativeEffects")
	var b_effect = b.get_node("CreativeEffects")
	var hp: float = a.hp
	var weapon = a.grafts[0]
	check(effects.swap(a_effect,b_effect,source),"Head swap rejected valid pair")
	check(a.node_data.mods.anatomy.head == "chicken" and a.grafts[0] == weapon and a.hp == hp,"Swap lost weapon, HP or donor")
	a_effect.head_time = .04; b_effect.head_time = .04
	await create_timer(.12).timeout
	check(not a.node_data.mods.anatomy.has("head") and not b.node_data.mods.anatomy.has("head"),"Heads did not restore")
	check(a_effect.age(source) and load("res://scripts/things/status.gd").speed_mult(a) == .55,"Age ray did not slow")
	check(not a_effect.age(source),"Age ray ignored immunity")
	a_effect.immunity = 0
	check(a_effect.charm(source) and a.owner_id == 1 and a.team == 1,"Charm did not convert")
	a_effect.team_time = .04
	await create_timer(.12).timeout
	check(a.owner_id == 2 and a.team == 2,"Charm did not restore original team")
	a_effect.immunity = 0
	check(a_effect.charm(source),"Charm fixture failed")
	var ball = spawn("quero uma pokebola",Vector3(0,40,2))
	check(ball.get_node("CaptureBall")._attempt(weakref(a),0.0),"Temporary creature could not be captured")
	check(a.owner_id == 1 and a_effect.team_time == 0.0 and a.is_captured,"Charm restoration overwrote capture owner")
	# Care requires matter and cooldown, fear never overrides harmless explicit orders.
	game.player.add_matter(500.0)
	var before: float = game.player.matter_spendable()
	bond.trust = 35; bond.care_cooldown = 0
	check(not bond.care(game.player).get("blocked",false) and bond.trust == 45 and game.player.matter_spendable() == before-8,"Care did not apply cost/bond")
	check(bond.care(game.player).get("blocked",false),"Care spam bypassed cooldown")
	bond.trust = 35; bond.fear = 90; fusion.hp = fusion.max_hp*.1
	check(bond.refuses_danger(),"Wounded frightened creature did not refuse danger")
	fusion.get_node("AnimalOrders").set_order("follow",fusion.global_position)
	check(fusion.get_node("AnimalOrders").mode == "follow","Fear broke follow")
	var friend = spawn("quero uma galinha",Vector3(1,40,1))
	var attacker = spawn("quero um cachorro",Vector3(3,40,1),2)
	load("res://scripts/things/combat.gd").apply_damage(friend,1.0,"bite",attacker)
	fusion.get_node("AnimalOrders").set_order("guard_pack",fusion.global_position)
	await create_timer(.3).timeout
	check(fusion.get_node("AnimalOrders").combat_target() == attacker,"Companion protection did not retaliate")
	# Snapshot roundtrip covers fusion, bond, temporary head and team timers.
	var net = load("res://scripts/network/thing_network_state.gd")
	var replica = assembler.build_replica(fusion.node_data,"head",lex,9870,1)
	game.add_thing(replica); replica.activate()
	net.apply(replica,net.capture(fusion))
	check(replica.get_node("CreatureBond").fear == bond.fear and replica.get_node("FusionPowers").companions.size() == 1,"New creature states did not replicate")
	replica.remove()
	for item in game.get_node("Things").get_children(): item.remove()
	await create_timer(.2).timeout
	root.get_node("Forge").production.reset()
	# Paid solo practice challenge uses the same encounter as the online cooperative variant.
	game.player.global_position = Vector3(0,40,0)
	game.player.add_matter(1000)
	var coop = load("res://scripts/things/coop_encounter.gd")
	var result: Dictionary = coop.request(game.player,"invite")
	var encounter = coop.of(game)
	check(not result.get("blocked",false) and encounter.phase == "battle","Cooperative challenge did not start: "+str(result))
	var boss = encounter.boss_ref.get_ref()
	check(boss.max_hp == 600 and boss.team == 99 and boss.get_node("Jujutsu").powers.has("adaptation"),"Boss scale/team/adaptation incorrect")
	var brain = boss.get_node("CoopBoss")
	brain.deadline = brain.clock
	await physics_frame; await physics_frame
	check(brain.phase == "warning","Boss did not announce its attack")
	brain.deadline = brain.clock
	await physics_frame; await physics_frame
	check(brain.phase == "recover" and brain.damage_multiplier() == 1.5,"Boss has no counterattack window")
	before = game.player.matter_spendable()
	boss.take_damage(10000,"world_cut",null)
	await create_timer(.15).timeout
	check(encounter.phase == "victory" and game.player.matter_spendable() == before+120,"Boss victory/reward incorrect")
	encounter.finish("victory","done")
	check(game.player.matter_spendable() == before+120,"Boss reward duplicated")
	# Losing and disconnecting restore ordinary play, without rewards.
	encounter.cooldown = 0.0
	game.player.add_matter(1000)
	coop.request(game.player,"invite")
	encounter.members.append(2)
	await create_timer(.1).timeout
	check(encounter.phase == "cancelled" and not coop.allied(1,2),"Disconnect did not cancel alliance")
	encounter.cooldown = 0.0
	game.player.add_matter(1000)
	coop.request(game.player,"invite")
	before = game.player.matter_spendable()
	game.player.health = 0.0
	await create_timer(.1).timeout
	check(encounter.phase == "defeat" and game.player.matter_spendable() == before,"Defeat granted reward or failed cleanup")
	print("CREATIVE_PROGRESSION ",JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)
