extends SceneTree

var failures := []
var game
var lex
var parser
var assembler
var forge
var combat
var wire

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func spawn(phrase: String, team: int = 1):
	var parsed: Dictionary = parser.parse(phrase, lex)
	check(parsed.get("ok", false) and parsed.unknown_words.is_empty(), "Invalid fixture: " + phrase)
	var item = assembler.build(parsed.recipe, "head", lex)
	item.set_owner_info(team, team, game.player if team == 1 else game.opponent, null)
	game.add_thing(item)
	item.global_position = Vector3(0 if team == 1 else 5, 20, 0)
	item.activate()
	item.move.set_physics_process(false)
	item.set_physics_process(false)
	return item

func _run() -> void:
	await process_frame
	lex = root.get_node("Lexicon").data
	parser = load("res://scripts/language/phrase_parser.gd")
	assembler = load("res://scripts/things/assembler.gd")
	forge = root.get_node("Forge")
	combat = load("res://scripts/things/combat.gd")
	wire = load("res://scripts/network/thing_network_state.gd")
	load("res://scenes/main.gd").next_mode = "practice"
	game = load("res://scenes/main.tscn").instantiate()
	game.voice_enabled = false
	root.add_child(game)
	current_scene = game
	await create_timer(.6).timeout
	game.player.frozen = false
	game.player.set_physics_process(false)
	game.player.global_position = Vector3(0, 20, 4)
	check(lex.errors.is_empty(), "Lexicon errors")
	var actor = spawn("quero um pikachu")
	var power = actor.get_node("PokemonCompanion")
	var ally = spawn("quero um squirtle")
	combat.apply_damage(ally, 10.0, "normal", actor)
	check(power.experience == 0.0, "Friendly damage granted XP")
	var own_enemy = spawn("quero um squirtle", 2)
	own_enemy.owner_id = 1
	combat.apply_damage(own_enemy, 10.0, "normal", actor)
	check(power.experience == 0.0, "Own creation granted XP")
	var victim = spawn("quero um squirtle", 2)
	combat.apply_damage(victim, 20.0, "normal", actor)
	check(is_equal_approx(power.experience, 5.0), "Combat participation did not grant XP")
	victim.hp = 1000.0
	victim.max_hp = 1000.0
	combat.apply_damage(victim, 400.0, "normal", actor)
	check(is_equal_approx(power.experience, 60.0), "Per-victim XP cap failed")
	combat.apply_damage(victim, 20.0, "normal", actor)
	check(is_equal_approx(power.experience, 60.0), "XP farming exceeded victim cap")
	var shielded = spawn("quero um cachorro com infinito", 2)
	combat.apply_damage(shielded, 20.0, "normal", actor)
	check(is_equal_approx(power.experience, 60.0), "Blocked damage granted XP")
	var fragile = spawn("quero um squirtle", 2)
	fragile.hp = 4.0
	combat.apply_damage(fragile, 1000.0, "normal", actor)
	check(is_equal_approx(power.experience, 61.0), "Overkill granted unearned XP")
	actor.remove()
	for item in [ally, own_enemy, victim, shielded, fragile]: item.remove()
	await process_frame
	var lines := {"pikachu": ["raichu"], "charmander": ["charmeleon", "charizard"], "squirtle": ["wartortle", "blastoise"], "bulbasaur": ["ivysaur", "venusaur"]}
	var evolutions := 0
	for base in lines:
		actor = spawn("quero um " + base + " com a habilidade do mahoraga com uma pistola")
		power = actor.get_node("PokemonCompanion")
		var weapon = actor.grafts[0]
		weapon.ammo = 5
		weapon.reload_left = 1.7
		for component in weapon.get_children():
			if component.has_meta("thing_gameplay_component"): component.set_physics_process(false)
		var identity: int = actor.get_instance_id()
		var cursed = actor.get_node("Jujutsu")
		cursed.exposure.infinity = 3
		actor.hp = actor.max_hp * .4
		power.remaining = 2.0
		game.player.matter = 300.0
		check(forge.request(1, base + " evolua", false, true).get("blocked", false), "Evolution bypassed XP requirement")
		check(game.player.matter == 300.0, "Rejected evolution spent matter")
		for next in lines[base]:
			var current: String = power.pokemon_id
			var required: float = power.evolution.xp
			power.experience = required + 7.0
			game.player.matter = 0.0
			check(forge.request(1, current + " evolua", false, true).get("blocked", false) and actor.thing_id == current, "Evolution bypassed matter requirement")
			game.player.matter = 300.0
			var price: float = power.evolution.cost
			var result: Dictionary = forge.request(1, current + " evolua", false, true)
			check(result.get("pokemon_evolved") == next and actor.thing_id == next, "Evolution failed: " + current)
			check(is_equal_approx(game.player.matter, 300.0 - price) and power.experience == 7.0, "Evolution charged incorrectly")
			check(actor.get_instance_id() == identity and actor.owner_id == 1 and actor.team == 1, "Evolution replaced identity or owner")
			check(is_equal_approx(actor.hp / actor.max_hp, .4), "Evolution healed creature")
			check(actor.grafts[0] == weapon and weapon.ammo == 5 and is_equal_approx(weapon.reload_left, 1.7), "Evolution lost weapon state")
			check(actor.get_node("Jujutsu") == cursed and cursed.exposure.infinity == 3 and power.remaining == 2.0, "Evolution reset powers or cooldown")
			check(not forge.request(1, next + " progresso", false, true).get("warnings", []).is_empty(), "Missing progress command")
			evolutions += 1
		check(forge.request(1, power.pokemon_id + " evolua", false, true).get("blocked", false), "Final form evolved again")
		if base == "charmander": check(actor.move.hovers(), "Charizard cannot fly")
		var ball = spawn("quero uma pokebola")
		var catcher = ball.get_node("CaptureBall")
		check(catcher._attempt(weakref(actor), 0.0), "Evolved creature could not be captured")
		check(power.experience == 7.0 and power.remaining == 2.0, "Capture reset progression")
		check(forge.request(1, power.pokemon_id + " evolua", false, true).get("blocked", false), "Stored Pokemon evolved")
		check(catcher.release() == actor and actor.get_instance_id() == identity, "Capture duplicated evolution")
		actor.remove()
		ball.remove()
		await process_frame
	var hybrid = spawn("quero um cachorro com cara de charmander com a habilidade do mahoraga")
	power = hybrid.get_node("PokemonCompanion")
	power.experience = 200.0
	game.player.matter = 300.0
	check(power.evolve(game.player).get("pokemon_evolved") == "charmeleon" and hybrid.thing_id == "dog" and hybrid.node_data.mods.anatomy.head == "charmeleon", "Evolution lost hybrid body")
	var replica = assembler.build_replica(parser.parse("quero um cachorro com cara de charmander com a habilidade do mahoraga", lex).recipe, "head", lex, 9001, 1)
	game.add_thing(replica)
	replica.global_position = Vector3(30, 20, 0)
	wire.apply(replica, wire.capture(hybrid))
	check(replica.get_node("PokemonCompanion").pokemon_id == "charmeleon" and replica.node_data.mods.anatomy.head == "charmeleon" and replica.thing_id == "dog", "Evolution snapshot lost mixed anatomy")
	check(replica.get_node("PokemonCompanion").experience == power.experience and is_equal_approx(replica.hp, hybrid.hp), "Progression did not synchronize")
	hybrid.remove()
	replica.remove()
	print("POKEMON_EVOLUTIONS ", JSON.stringify({"failures": failures, "evolutions": evolutions}))
	quit(0 if failures.is_empty() else 1)
