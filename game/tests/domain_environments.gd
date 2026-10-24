extends SceneTree

var failures := []
var evidence := {}
var game
var assembler
var parser
var lex

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func spawn(phrase: String, at: Vector3, team: int = 1):
	var item = assembler.build(parser.parse(phrase, lex).recipe, "head", lex)
	item.set_owner_info(team, team, game.player if team == 1 else game.opponent, null)
	game.add_thing(item)
	item.global_position = at
	item.activate()
	item.move.set_physics_process(false)
	item.set_physics_process(false)
	return item

func _run() -> void:
	await process_frame
	lex = root.get_node("Lexicon").data
	assembler = load("res://scripts/things/assembler.gd")
	parser = load("res://scripts/language/phrase_parser.gd")
	load("res://scenes/main.gd").next_mode = "practice"
	game = load("res://scenes/main.tscn").instantiate()
	game.voice_enabled = false
	root.add_child(game)
	current_scene = game
	await create_timer(.6).timeout
	game.player.frozen = false
	game.player.set_physics_process(false)
	game.player.global_position = Vector3(0, 20, 0)
	var maho = spawn("quero mahoraga", Vector3(14, 20, 0))
	var dog = assembler.build(parser.parse("quero um cachorro com a habilidade do mahoraga", lex).recipe, "head", lex)
	check(maho.bounds.size.y > 3.5 and maho.model_pieces.size() >= 65, "Mahoraga still has the old small body")
	check(maho.get_node("Jujutsu").wheel.get_node("EightSpokedWheel").multimesh.instance_count == 40, "Eight-spoke adaptation wheel missing")
	# The headless renderer returns identity for GPU instance readback; check the submitted frames.
	for i in 8:
		var spoke: Transform3D = maho.get_node("Jujutsu")._wheel_frame(i * TAU / 8.0, Vector3(1.12, .08, .08), .58)
		check(spoke.basis.x.normalized().dot(spoke.origin.normalized()) > .99, "Adaptation wheel spoke is not radial")
	check(dog.bounds.size.y < maho.bounds.size.y and dog.get_node("Jujutsu") != null, "Adaptation changed a dog's body")
	dog.free()
	evidence.mahoraga_height = maho.bounds.size.y
	evidence.mahoraga_pieces = maho.model_pieces.size()
	maho.remove()
	var void_item = spawn("quero vazio infinito", Vector3(0, 20, 0))
	game.player.hands.give(void_item, false)
	var victim = spawn("quero um cachorro", Vector3(3, 20, 0), 2)
	var user = void_item.get_node("Jujutsu")
	check(user.expand_domain(), "Void expansion failed")
	var origin: Vector3 = user.domain_origin
	for frame in 3: await process_frame
	check(is_instance_valid(user.domain_visual) and user.domain_visual.get_node_or_null("ClosedVoidBarrier") != null and user.domain_visual.get_node_or_null("InformationStreams") != null, "Cosmic closed environment missing")
	var first = user.domain_visual
	game.player.global_position += Vector3(2, 0, 0)
	for frame in 5: await process_frame
	check(user.domain_visual == first and first.global_position.is_equal_approx(origin), "Domain follows caster or respawns each frame")
	user.clock = .8
	for frame in 3: await physics_frame
	var query := PhysicsRayQueryParameters3D.create(origin + Vector3(12, 0, 0), origin, 1)
	var wall: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
	check(not wall.is_empty() and wall.collider.name == "VoidBarrierBody", "Void exterior did not block incoming shots")
	query.from = origin
	query.to = origin + Vector3(12, 0, 0)
	wall = game.get_world_3d().direct_space_state.intersect_ray(query)
	check(not wall.is_empty() and wall.collider.name == "VoidBarrierBody", "Void interior is not a closed barrier")
	user.domain_next_pulse = 0.0
	victim.global_position = origin + Vector3(13, 0, 0)
	user._domain()
	check(victim.center().distance_to(origin) <= 8.5, "Closed Void did not retain its captured participant")
	var status = load("res://scripts/things/status.gd").of(victim)
	check(status != null and status.remaining.has("void_overload") and not victim.can_act(), "Void lost its paralysis effect")
	var state = load("res://scripts/network/thing_network_state.gd").capture(void_item)
	check(state.jujutsu.domain_origin == origin and state.jujutsu.domain_up.is_finite(), "Fixed origin missing from network state")
	var shrine = spawn("quero santuario malevolente", origin + Vector3(0, 0, 4), 2)
	var enemy = shrine.get_node("Jujutsu")
	check(enemy.expand_domain(), "Shrine expansion failed")
	for frame in 3: await process_frame
	check(enemy.domain_visual.get_node_or_null("MalevolentShrineAltar") != null and enemy.domain_visual.get_node_or_null("ClosedVoidBarrier") == null, "Shrine did not create its open altar")
	user._domain()
	check(user.domain_clashing, "Overlapping domains lost their clash")
	enemy.cancel_domain()
	await create_timer(.45).timeout
	check(not is_instance_valid(enemy.domain_visual), "Cancelled shrine environment leaked")
	user.clock = user.domain_until + .1
	await create_timer(.45).timeout
	check(not is_instance_valid(user.domain_visual), "Expired Void environment leaked")
	# Destroying the caster must dismiss its world-parented environment.
	enemy.next_cast = 0.0
	check(enemy.expand_domain(), "Shrine could not be recast in fixture")
	for frame in 2: await process_frame
	var visual = enemy.domain_visual
	shrine.remove()
	await create_timer(.45).timeout
	check(not is_instance_valid(visual), "Environment survived removal of its caster")
	void_item.remove()
	victim.remove()
	evidence.environments_remaining = get_nodes_in_group("domain_environments").size()
	print("DOMAIN_ENVIRONMENTS ", JSON.stringify({"failures": failures, "evidence": evidence}))
	quit(0 if failures.is_empty() else 1)
