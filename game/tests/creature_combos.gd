extends SceneTree

var failures := []
var game
var lex
var assembler
var parser
var combat
var status
var combos

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func spawn(phrase: String, team: int = 1):
	var parsed: Dictionary = parser.parse(phrase, lex)
	check(parsed.get("ok", false), "Bad fixture: " + phrase)
	var item = assembler.build(parsed.recipe, "head", lex)
	item.set_owner_info(team, team, game.player if team == 1 else game.opponent, null)
	game.add_thing(item)
	item.global_position = Vector3(0, 20, 0 if team == 1 else -5)
	item.activate()
	item.set_physics_process(false)
	item.move.set_physics_process(false)
	return item

func has_effect(target, kind: String) -> bool:
	return float(status.snapshot(target).get(kind, 0.0)) > 0.0

func _run() -> void:
	await process_frame
	lex = root.get_node("Lexicon").data
	parser = load("res://scripts/language/phrase_parser.gd")
	assembler = load("res://scripts/things/assembler.gd")
	combat = load("res://scripts/things/combat.gd")
	status = load("res://scripts/things/status.gd")
	combos = load("res://scripts/things/creature_combos.gd")
	load("res://scenes/main.gd").next_mode = "practice"
	game = load("res://scenes/main.tscn").instantiate()
	game.voice_enabled = false
	root.add_child(game)
	current_scene = game
	await create_timer(.6).timeout
	game.player.frozen = false
	game.player.set_physics_process(false)
	game.player.global_position = Vector3(0, 20, 4)
	var water = spawn("quero um squirtle")
	var electric = spawn("quero um pikachu")
	var grass = spawn("quero um bulbasaur")
	var fire = spawn("quero um charmander")
	var victim = spawn("quero um elefante", 2)
	victim.max_hp = 10000.0
	victim.hp = 10000.0
	await physics_frame
	await physics_frame
	check(not water.get_node("PokemonCompanion").cast("water_gun").get("blocked", false) and has_effect(victim, "wet"), "Water gun did not wet the target")
	check(status.of(victim).get_node_or_null("CreatureComboMarks") != null, "Wet visual missing")
	var before: float = victim.hp
	check(not electric.get_node("PokemonCompanion").cast("thunderbolt").get("blocked", false), "Electric command failed")
	check(is_equal_approx(before - victim.hp, 45.0) and not has_effect(victim, "wet") and has_effect(victim, "combo_shock_lock"), "Conductive damage or wet consumption incorrect")
	check(combos.count == 1 and combos.last_reaction == "conductive", "Conductive reaction FX missing")
	combat.apply_damage(victim, 1.0, "water", water)
	before = victim.hp
	combat.apply_damage(victim, 30.0, "electric", electric)
	check(is_equal_approx(before - victim.hp, 30.0) and has_effect(victim, "wet") and combos.count == 1, "Shock cooldown bypassed")
	status.of(victim)._count_down(4.1)
	check(not has_effect(victim, "wet"), "Wet state did not expire")
	combat.apply_damage(victim, 1.0, "water", water)
	before = victim.hp
	combat.apply_damage(victim, 200.0, "electric", electric)
	check(is_equal_approx(before - victim.hp, 218.0), "Conductive bonus exceeded 18 cap")
	check(not grass.get_node("PokemonCompanion").cast("vine_whip").get("blocked", false) and has_effect(victim, "entangled"), "Vine whip did not bind target")
	check(victim.can_act(), "Vines should permit attacks")
	var position: Vector3 = victim.global_position
	victim.velocity = Vector3(5, 2, 0)
	victim.move._physics_process(.2)
	victim.move.travel(Vector3(2, 0, 0))
	check(victim.global_position.is_equal_approx(position) and victim.velocity.is_zero_approx(), "Bound animal moved")
	status.of(victim)._count_down(.8)
	var root_left: float = status.snapshot(victim).entangled
	combat.apply_damage(victim, 1.0, "grass", grass, "vine")
	check(is_equal_approx(status.snapshot(victim).entangled, root_left), "Vines refreshed indefinitely")
	before = victim.hp
	check(not fire.get_node("PokemonCompanion").cast("ember").get("blocked", false), "Fire command failed")
	check(is_equal_approx(before - victim.hp, 31.05) and not has_effect(victim, "entangled") and combos.last_reaction == "vine_fire", "Fire did not consume vines with bounded bonus")
	combat.apply_damage(victim, 1.0, "grass", grass, "vine")
	check(not has_effect(victim, "entangled"), "Root immunity window failed")
	status.of(victim)._count_down(7.0)
	combat.apply_damage(victim, 1.0, "grass", grass, "vine")
	before = victim.hp
	combat.apply_damage(victim, 200.0, "fire", fire)
	check(is_equal_approx(before - victim.hp, 214.0), "Vine fire bonus exceeded 14 cap")
	status.of(victim)._count_down(7.0)
	combat.apply_damage(victim, 1.0, "grass", grass, "leaf")
	check(not has_effect(victim, "entangled"), "Razor leaf incorrectly roots")
	var ally = spawn("quero um elefante")
	combat.apply_damage(ally, 1.0, "water", water)
	combat.apply_damage(ally, 1.0, "grass", grass, "vine")
	check(status.snapshot(ally).is_empty(), "Combos affected an ally")
	var protected = spawn("quero um elefante com infinito", 2)
	var protected_hp: float = protected.hp
	var reactions: int = combos.count
	combat.apply_damage(protected, 1.0, "water", water)
	check(protected.hp == protected_hp and not has_effect(protected, "wet"), "Water bypassed Infinity")
	status.apply(protected, "wet", water)
	combat.apply_damage(protected, 100.0, "electric", electric)
	check(protected.hp == protected_hp and has_effect(protected, "wet") and combos.count == reactions, "Blocked shock consumed wet or triggered a combo")
	combat.apply_damage(protected, 1.0, "grass", grass, "vine")
	check(not has_effect(protected, "entangled"), "Vines bypassed Infinity")
	var adapted = spawn("quero um elefante com a habilidade do mahoraga", 2)
	adapted.get_node("Jujutsu").exposure.electric = 3
	status.apply(adapted, "wet", water)
	before = adapted.hp
	combat.apply_damage(adapted, 30.0, "electric", electric)
	check(is_equal_approx(before - adapted.hp, 9.0), "Combo bypassed adaptation")
	# A resistance profile fixture verifies that bonus and base go through the same shield.
	var shield = spawn("quero um escudo anti bomba", 2)
	shield.global_position = Vector3(25, 20, 0)
	var shielded = spawn("quero um elefante", 2)
	shielded.global_position = shield.global_position
	var field = shield.get_node("ProtectionEmitter")
	field.profile_id = "combo_test"
	lex.balance.innovation.resistance.combo_test = {"electric": .25}
	status.apply(shielded, "wet", water)
	before = shielded.hp
	combat.apply_damage(shielded, 30.0, "electric", electric)
	check(is_equal_approx(before - shielded.hp, 11.25), "Combo bypassed shield resistance")
	lex.balance.innovation.resistance.erase("combo_test")
	shield.remove()
	# Capture prevents damage/reactions; expiry restores autonomous walking and flight.
	var flyer = spawn("quero um pombo", 2)
	flyer.global_position = Vector3(40, 20, 0)
	combat.apply_damage(flyer, 1.0, "grass", grass, "vine")
	var origin: Vector3 = flyer.global_position
	flyer.move._physics_process(.1)
	check(flyer.global_position.is_equal_approx(origin), "Bound flyer kept flying")
	status.of(flyer)._count_down(1.7)
	check(not status.movement_locked(flyer), "Flyer remained rooted after expiry")
	var ball = spawn("quero uma pokebola")
	var catcher = ball.get_node("CaptureBall")
	check(catcher._attempt(weakref(victim), 0.0), "Cannot capture combo victim")
	before = victim.hp
	combat.apply_damage(victim, 100.0, "electric", electric)
	check(victim.hp == before, "Captured creature took combo damage")
	check(catcher.release() == victim, "Combo capture lost creature")
	var wire = load("res://scripts/network/forge_replication.gd")
	check(wire._valid_fx("pokemon_move", [Vector3.ZERO, Vector3.ONE, "conductive", "Água + eletricidade"]) and wire._valid_fx("pokemon_move", [Vector3.ZERO, Vector3.ONE, "vine_fire", "Cipós + fogo"]), "Combo FX rejected by network")
	for item in [water, electric, grass, fire, victim, ally, protected, adapted, shielded, flyer, ball]: item.remove()
	print("CREATURE_COMBOS ", JSON.stringify({"failures": failures, "reactions": combos.count}))
	quit(0 if failures.is_empty() else 1)
