extends SceneTree

var failures := []
var game
var lex
var parser
var assembler
var clash
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func spawn(phrase: String, at: Vector3, team: int = 1):
	var parsed: Dictionary = parser.parse(phrase, lex)
	check(parsed.get("ok", false) and parsed.unknown_words.is_empty() and parsed.ignored_words.is_empty(), "Invalid domain/sword phrase: " + phrase)
	var item = assembler.build(parsed.recipe, "head", lex)
	item.set_owner_info(team, team, game.player if team == 1 else game.opponent, null)
	game.add_thing(item)
	item.global_position = at
	item.activate()
	item.move.set_physics_process(false)
	item.set_physics_process(false)
	return item
func clear() -> void:
	for item in game.get_node("Things").get_children(): item.remove()
	await create_timer(.4).timeout
	root.get_node("Forge").production.reset()
func pair() -> Array:
	var a = spawn("quero vazio infinito", Vector3(-3,40,0))
	var b = spawn("quero santuario malevolente", Vector3(3,40,0), 2)
	var x = a.get_node("Jujutsu")
	var y = b.get_node("Jujutsu")
	check(x.expand_domain() and y.expand_domain(), "Domain pair failed to open")
	return [x,y]
func _run() -> void:
	await process_frame
	lex = root.get_node("Lexicon").data
	parser = load("res://scripts/language/phrase_parser.gd")
	assembler = load("res://scripts/things/assembler.gd")
	clash = load("res://scripts/things/domain_clash.gd")
	load("res://scenes/main.gd").next_mode = "practice"
	game = load("res://scenes/main.tscn").instantiate()
	game.voice_enabled = false
	root.add_child(game)
	current_scene = game
	await create_timer(.6).timeout
	for player in [game.player, game.opponent]:
		player.set_physics_process(false)
		player.global_position = Vector3(30,40,30)
	var middle = spawn("quero um cachorro", Vector3(0,40,0), 2)
	var outside = spawn("quero um cachorro", Vector3(-10,40,0), 2)
	var users := pair()
	await create_timer(.95).timeout
	var status = load("res://scripts/things/status.gd")
	check(users[0].domain_clashing and users[1].domain_clashing, "Domains did not begin a mutual clash")
	check(not status.paralyzed(middle), "Sure-hit paralysis continued in the overlap")
	check(status.paralyzed(outside), "Clash incorrectly disabled sure-hit outside the overlap")
	var seam = users[0].domain_visual.get_node("DomainClashSeam")
	check(seam.visible and seam.multimesh.instance_count == 64, "Clash has no persistent barrier seam")
	var network = load("res://scripts/network/thing_network_state.gd")
	var state: Dictionary = network.capture(users[0].thing)
	check(state.jujutsu.has("clash_pressure") and state.jujutsu.has("clash_point"), "Clash state missing from network snapshots")
	var replica = assembler.build_replica({"thing":"unlimited_void"}, "head", lex, 9300, 1)
	game.add_thing(replica)
	replica.activate()
	network.apply(replica, state)
	check(replica.get_node("Jujutsu").domain_clashing, "Remote domain lost clash presentation")
	replica.remove()
	await create_timer(2.6).timeout
	check(users[0].domain_outcome == "tie" and users[1].domain_outcome == "tie" and users[0].domain_until == 0 and users[1].domain_until == 0, "Equal domains did not collapse after their contest")
	await clear()
	users = pair()
	users[0].thing.power = 1.5
	await create_timer(3.5).timeout
	check(users[0].domain_outcome == "won" and users[0].domain_until > users[0].clock and users[1].domain_outcome == "lost", "Stronger domain did not overpower weaker barrier")
	await clear()
	users = pair()
	await create_timer(.4).timeout
	users[1].thing.take_damage(65.0,"melee",users[0].thing)
	await create_timer(.35).timeout
	check(users[1].domain_outcome == "lost" and not users[0].domain_clashing, "Hurting caster did not break its domain")
	await clear()
	# A blade opens one short curved tear, rather than duplicating a normal strike and a laser.
	var sword = spawn("quero uma espada que corta o espaço",Vector3(0,40,0))
	check(sword.melee and sword.get_node_or_null("Do_strike") == null,"Sword still has duplicate strike damage")
	var target = spawn("quero uma vaca com infinito",Vector3(0,40,-3),2)
	target.global_position += sword.center() - target.center() + Vector3.FORWARD * 3.0
	var far = spawn("quero uma vaca",Vector3(0,40,-9),2)
	var behind = spawn("quero uma vaca",Vector3(0,40,3),2)
	for animal in [target,far,behind]: animal.hp = 1000; animal.max_hp = 1000
	var hp: float = target.hp
	var far_hp: float = far.hp
	var behind_hp: float = behind.hp
	var rifts: int = load("res://scripts/fx/expansion_fx.gd").rift_count
	var volume = load("res://scripts/world/block_volume.gd").new()
	volume.setup(932,Vector3i(24,8,8),Vector3.ZERO)
	var metal: int = volume.add_type("steel",Color.GRAY)
	var permanent: int = volume.add_type("steel",Color.BLACK,2)
	volume.blocks.fill(metal)
	volume.blocks[0] = permanent
	game.add_child(volume)
	volume.global_position = sword.center() + Vector3(-3,-1,-3.5)
	volume.commit_base()
	var ctx = load("res://scripts/things/action_context.gd").make(sword.center(),Vector3.FORWARD)
	sword.get_node("Do_anomaly").run(ctx)
	await create_timer(.5).timeout
	check(is_equal_approx(hp-target.hp,48.0*sword.power),"Spatial blade did not cut a nearby protected target once: damage=%s power=%s" % [hp-target.hp,sword.power])
	check(far.hp == far_hp and behind.hp == behind_hp,"Sword became a long laser or hit behind its swing")
	check(load("res://scripts/fx/expansion_fx.gd").rift_count == rifts and load("res://scripts/fx/space_sword.gd").casts > 0,"Sword still emits the old laser")
	check(volume.blocks.count(0)>0 and volume.blocks[0]==permanent,"Sword did not cut actual blocks while preserving permanent cells")
	volume.queue_free()
	await clear()
	print("DOMAIN_CLASH_SPACE_SWORD ",JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)
