extends SceneTree

var failures := []
var evidence := {}
var game
var lex
var assembler
var parser
var combat
var recipe
var ctx

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func spawn(phrase: String, at: Vector3, team: int = 1):
	var parsed: Dictionary = parser.parse(phrase, lex)
	check(parsed.get("ok", false) and parsed.unknown_words.is_empty() and parsed.ignored_words.is_empty(), "Bad phrase: " + phrase + " " + str(parsed))
	var item = assembler.build(parsed.recipe, "head", lex)
	check(item.unsupported.is_empty(), "Unsupported: " + phrase)
	item.set_owner_info(team, team, game.player if team == 1 else game.opponent, game.player)
	game.add_thing(item)
	item.global_position = at
	item.activate()
	return item

func clear() -> void:
	for item in game.get_node("Things").get_children(): item.remove()
	await process_frame
	root.get_node("Forge").production.reset()

func _run() -> void:
	await process_frame
	load("res://scenes/main.gd").next_mode = "practice"
	game = load("res://scenes/main.tscn").instantiate()
	game.voice_enabled = false
	root.add_child(game)
	current_scene = game
	lex = root.get_node("Lexicon").data
	assembler = load("res://scripts/things/assembler.gd")
	parser = load("res://scripts/language/phrase_parser.gd")
	combat = load("res://scripts/things/combat.gd")
	recipe = load("res://scripts/language/recipe.gd")
	ctx = load("res://scripts/things/action_context.gd")
	await create_timer(.5).timeout
	var keys := ["mahoraga", "infinito", "corte do sukuna", "corte do mundo", "fuga", "flash negro", "cura reversa", "santuario malevolente", "vazio infinito", "dominio simples", "amplificacao de dominio"]
	for name in keys:
		var parsed: Dictionary = parser.parse("quero " + name, lex)
		check(parsed.get("ok", false) and parsed.unknown_words.is_empty() and parsed.ignored_words.is_empty(), "Technique not recognized: " + name)
	var species := 0
	for id in lex.defs.things:
		if lex.category_of(id) != "creature": continue
		var node: Dictionary = recipe.new_node(id)
		node.mods.jj_adaptation = true
		node.mods.jj_infinity = true
		var animal = assembler.build(node, "head", lex)
		check(animal.get_node_or_null("Jujutsu") != null, "Animal lacks composable powers: " + id)
		animal.free()
		species += 1
	evidence.species = species
	for phrase in ["quero um cachorro com a habilidade do mahoraga", "quero um pato com infinito", "quero um elefante com corte do sukuna", "quero uma galinha com a habilidade do vazio roxo", "quero um cachorro com a habilidade do mahoraga com infinito"]:
		var item = spawn(phrase, Vector3(0,40,0))
		check(item.get_node_or_null("Jujutsu") != null, "Composition lost powers: " + phrase)
		await clear()
	# The same real player is protected from ordinary damage and hit by a spatial world cut.
	game.player.set_physics_process(false)
	game.opponent.set_physics_process(false)
	game.opponent.global_position = Vector3(0,40,0)
	game.opponent.add_to_group("combatants")
	var shield = spawn("quero infinito", Vector3(0,40,0), 2)
	shield.set_held(true)
	var dog = spawn("quero um cachorro", Vector3(0,40,3))
	dog.move.set_physics_process(false)
	var hp: float = game.opponent.health
	combat.apply_damage(game.opponent, 25.0, "melee", dog)
	check(game.opponent.health == hp, "Ordinary dog bypassed Infinity")
	combat.apply_damage(game.opponent, 10.0, "world_cut", dog)
	check(game.opponent.health < hp, "World cut did not bypass Infinity")
	game.opponent.health = hp
	dog.remove()
	await process_frame
	dog = spawn("quero um cachorro com a habilidade do mahoraga", Vector3(0,40,3))
	dog.move.set_physics_process(false)
	var user = dog.get_node("Jujutsu")
	for attempt in 4:
		user.clock = attempt * 1.1
		user.cast(ctx.make(dog.center(), game.opponent.center() - dog.center(), game.opponent))
		for step in 3: await process_frame
	check(user.adapted("infinity") and game.opponent.health < hp, "Adapted dog could not hit protected player")
	evidence.adapted_dog_damage = hp - game.opponent.health
	# Adaptation belongs to the attack type and is not instantaneous invulnerability.
	var maho = spawn("quero mahoraga", Vector3(8,40,0), 2)
	maho.move.set_physics_process(false)
	var defender = maho.get_node("Jujutsu")
	for i in 3:
		defender.clock = i * 1.0
		combat.apply_damage(maho, 10.0, "slash", dog)
	var before: float = maho.hp
	combat.apply_damage(maho, 10.0, "slash", dog)
	check(is_equal_approx(before - maho.hp, 2.0), "Repeated slash adaptation did not reduce damage")
	before = maho.hp
	combat.apply_damage(maho, 10.0, "fire", dog)
	check(is_equal_approx(before - maho.hp, 10.0), "Slash adaptation incorrectly made fire harmless")
	await clear()
	# Domain protection, normal Infinity bypass, and temporary defensive windows.
	game.opponent.health = hp
	shield = spawn("quero infinito", Vector3(0,40,0), 2)
	shield.set_held(true)
	var source = spawn("quero corte do sukuna", Vector3(0,40,4))
	combat.apply_damage(game.opponent, 20.0, "domain_slash", source)
	check(is_equal_approx(hp - game.opponent.health, 20.0), "Domain sure hit did not bypass Infinity")
	var simple = spawn("quero dominio simples", Vector3(0,40,0), 2)
	simple.set_held(true)
	before = game.opponent.health
	combat.apply_damage(game.opponent, 20.0, "domain_slash", source)
	check(is_equal_approx(before - game.opponent.health, 3.0), "Simple Domain did not reduce sure-hit damage")
	shield.get_node("Jujutsu").clock = 17.0
	before = game.opponent.health
	combat.apply_damage(game.opponent, 10.0, "slash", source)
	check(game.opponent.health < before, "Infinity has no recharge window")
	await clear()
	# Healing caps at maximum and cannot revive a dead creature.
	var healer = spawn("quero um cachorro com cura reversa", Vector3(0,40,0))
	healer.move.set_physics_process(false)
	healer.hp -= 10
	healer.get_node("Jujutsu")._heal()
	check(is_equal_approx(healer.hp, healer.max_hp - 4), "Reverse technique did not heal")
	healer.get_node("Jujutsu")._heal()
	check(healer.hp == healer.max_hp, "Reverse technique exceeded max HP")
	await clear()
	# Purple must remove strong blocks continuously even between fast physics steps.
	var volume = load("res://scripts/world/block_volume.gd").new()
	volume.setup(99998, Vector3i(24,24,48), Vector3.ZERO)
	var metal: int = volume.add_type("steel", Color.GRAY)
	volume.blocks.fill(metal)
	var permanent: int = volume.add_type("steel", Color.BLACK, 2)
	var permanent_index: int = volume.index_of(Vector3i(12,12,12))
	volume.blocks[permanent_index] = permanent
	game.add_child(volume)
	volume.global_position = Vector3(-3,37,-12)
	volume.commit_base()
	var purple = spawn("quero vazio roxo", Vector3(0,40,2))
	purple.velocity = Vector3.FORWARD * 80
	for step in 40: await physics_frame
	for step in 30: await process_frame
	var erased := 0
	for cell in volume.blocks:
		if cell == 0: erased += 1
	check(erased > 2000, "Purple did not erase a wide path through strong blocks")
	var gaps := 0
	for z in 48:
		if z == 12: continue
		if volume.blocks[volume.index_of(Vector3i(12,12,z))] != 0: gaps += 1
	check(gaps == 0, "Fast Purple left gaps in its swept tunnel")
	check(volume.blocks[permanent_index] == permanent, "Purple erased permanent arena cells")
	evidence.purple_erased_cells = erased
	evidence.purple_tunnel_gaps = gaps
	volume.queue_free()
	await clear()
	var report := {"failures": failures, "evidence": evidence}
	var file := FileAccess.open(ProjectSettings.globalize_path("res://").path_join("../analysis/jujutsu-powers.json").simplify_path(), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("JUJUTSU_POWERS ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
