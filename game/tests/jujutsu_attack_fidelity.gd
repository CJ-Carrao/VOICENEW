extends SceneTree

var failures := []
var game
var lex
var parser
var assembler
var ctx
var fx
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func spawn(phrase: String, at: Vector3, team: int = 1):
	var parsed: Dictionary = parser.parse(phrase, lex)
	check(parsed.get("ok", false) and parsed.unknown_words.is_empty() and parsed.ignored_words.is_empty(), "Bad refined attack phrase: " + phrase)
	var item = assembler.build(parsed.recipe, "head", lex)
	item.set_owner_info(team, team, game.player if team == 1 else game.opponent, null)
	game.add_thing(item)
	item.global_position = at
	item.activate()
	item.move.set_physics_process(false)
	item.set_physics_process(false)
	return item
func strike(source, direction: Vector3, charge: float = 0.0) -> void:
	var action = ctx.make(source.center(), direction)
	action.charge = charge
	source.get_node("Jujutsu").cast(action)
func clear() -> void:
	for item in game.get_node("Things").get_children(): item.remove()
	await create_timer(.2).timeout
	root.get_node("Forge").production.reset()
func _run() -> void:
	await process_frame
	lex = root.get_node("Lexicon").data
	parser = load("res://scripts/language/phrase_parser.gd")
	assembler = load("res://scripts/things/assembler.gd")
	ctx = load("res://scripts/things/action_context.gd")
	fx = load("res://scripts/fx/jujutsu_impact.gd")
	load("res://scenes/main.gd").next_mode = "practice"
	game = load("res://scenes/main.tscn").instantiate()
	game.voice_enabled = false
	root.add_child(game)
	current_scene = game
	await create_timer(.6).timeout
	for player in [game.player, game.opponent]:
		player.set_physics_process(false)
		player.global_position = Vector3(30,30,30)
	var fist = spawn("quero raio negro", Vector3(0,30,0))
	check(fist.melee and fist.strike_style == "thrust", "Black Flash is not a physical punch weapon")
	var victim = spawn("quero um elefante", Vector3(0,30,-2), 2)
	var bystander = spawn("quero um elefante", Vector3(.7,30,-2), 2)
	var hp: float = victim.hp
	var other_hp: float = bystander.hp
	strike(fist, Vector3.FORWARD)
	check(victim.hp == hp, "Punch hit before physical windup")
	await create_timer(.25).timeout
	check(is_equal_approx(hp - victim.hp, 18.0) and bystander.hp == other_hp, "Ordinary punch was not single-target physical damage")
	check(fx.last_style == "punch", "Unfocused punch incorrectly produced Black Flash")
	var power = fist.get_node("Jujutsu")
	power.next_cast = 0
	# Reset target after knockback so the second punch is still at contact range.
	victim.global_position = Vector3(0,30,-2)
	strike(fist, Vector3.FORWARD, .5)
	await create_timer(.25).timeout
	check(is_equal_approx(hp - victim.hp, 63.0) and power.black_flashes == 1 and power.zone_until > power.clock, "Precise punch did not produce Black Flash and a temporary zone")
	check(fx.last_style == "black_flash", "Black Flash lacks its impact-specific black/red effect")
	power.next_cast = 0
	victim.global_position = Vector3(0,30,-8)
	bystander.global_position = Vector3(.7,30,-8)
	var before: float = victim.hp
	strike(fist, Vector3.FORWARD, .5)
	await create_timer(.25).timeout
	check(victim.hp == before and power.black_flashes == 1, "Black Flash became a ranged lightning attack or triggered on a miss")
	await clear()
	var cleave = spawn("quero cleave", Vector3(0,30,0))
	victim = spawn("quero um elefante", Vector3(0,30,-9), 2)
	hp = victim.hp
	strike(cleave, Vector3.FORWARD)
	await create_timer(.25).timeout
	check(victim.hp == hp, "Cleave hit a distant target")
	cleave.get_node("Jujutsu").next_cast = 0
	victim.global_position = Vector3(0,30,-2)
	strike(cleave, Vector3.FORWARD)
	await create_timer(.25).timeout
	check(hp - victim.hp >= 32 and hp - victim.hp <= 70, "Contact Cleave did not use bounded durability scaling")
	await clear()
	var dismantle = spawn("quero desmantelar", Vector3(0,30,0))
	victim = spawn("quero um elefante", Vector3(0,30,-12), 2)
	hp = victim.hp
	strike(dismantle, Vector3.FORWARD)
	await create_timer(.2).timeout
	check(victim.hp == hp and not get_nodes_in_group("cursed_projectiles").is_empty(), "Dismantle was an instantaneous line hit")
	await create_timer(.45).timeout
	check(victim.hp < hp, "Travelling Dismantle never reached target")
	await clear()
	var fuga = spawn("quero fuga", Vector3(0,30,0))
	victim = spawn("quero um elefante", Vector3(0,30,-10), 2)
	hp = victim.hp
	strike(fuga, Vector3.FORWARD)
	await create_timer(.25).timeout
	check(victim.hp == hp and get_nodes_in_group("cursed_projectiles").is_empty(), "Fuga skipped preparation")
	await create_timer(.4).timeout
	check(victim.hp == hp and not get_nodes_in_group("cursed_projectiles").is_empty(), "Fuga was not a travelling fire arrow")
	await create_timer(.4).timeout
	check(victim.hp < hp and load("res://scripts/things/status.gd").of(victim) != null, "Fuga did not detonate and ignite on impact")
	await clear()
	# Infinity blocks both direct impact and the secondary fire status.
	fuga = spawn("quero fuga", Vector3(0,30,0))
	victim = spawn("quero um elefante com infinito", Vector3(0,30,-10), 2)
	hp = victim.hp
	strike(fuga, Vector3.FORWARD)
	await create_timer(1.1).timeout
	check(victim.hp == hp and load("res://scripts/things/status.gd").of(victim) == null, "Fuga burning bypassed Infinity")
	await clear()
	var cutter = spawn("quero corte do mundo", Vector3(0,30,0))
	victim = spawn("quero um elefante com infinito", Vector3(0,30,-8), 2)
	hp = victim.hp
	strike(cutter, Vector3.FORWARD)
	await create_timer(.3).timeout
	check(victim.hp == hp, "World cut skipped its telegraph")
	await create_timer(.4).timeout
	check(hp - victim.hp == 100.0, "Prepared world cut did not bypass Infinity")
	await clear()
	var red = spawn("quero vermelho", Vector3(0,30,0))
	victim = spawn("quero um elefante", Vector3(0,30,-4), 2)
	red.move.set_physics_process(true)
	red.move.launch(Vector3.FORWARD, 12.0)
	var red_ref: WeakRef = weakref(red)
	await create_timer(.8).timeout
	red = red_ref.get_ref()
	check(not is_instance_valid(red) or red.is_dead, "Red remained as a repeatedly pulsing field after impact")
	await clear()
	# Capturing a caster cancels a prepared attack rather than saving it for release.
	fuga = spawn("quero um cachorro com fuga", Vector3(0,30,0))
	strike(fuga, Vector3.FORWARD)
	fuga.set_captured(true)
	check(fuga.get_node("Jujutsu").pending_attack.is_empty(), "Capture preserved a pending attack")
	fuga.set_captured(false)
	await clear()
	var wire = load("res://scripts/network/forge_replication.gd")
	check(wire._valid_fx("jujutsu_impact", [Vector3.ZERO, Vector3.FORWARD, "black_flash"]), "Black Flash FX cannot replicate")
	check(not wire._valid_fx("jujutsu_impact", [Vector3.ZERO, Vector3.FORWARD, "invalid"]), "Invalid Jujutsu effect accepted")
	print("JUJUTSU_ATTACK_FIDELITY ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)
