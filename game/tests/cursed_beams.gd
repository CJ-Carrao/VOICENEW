extends SceneTree

var failures := []
var game
var lex
var parser
var assembler
var ctx
var beam_script
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func spawn(phrase: String, at: Vector3, team: int = 1):
	var parsed: Dictionary = parser.parse(phrase, lex)
	check(parsed.get("ok", false) and parsed.unknown_words.is_empty() and parsed.ignored_words.is_empty(), "Unrecognized beam phrase: " + phrase)
	var item = assembler.build(parsed.recipe, "head", lex)
	item.set_owner_info(team, team, game.player if team == 1 else game.opponent, null)
	game.add_thing(item)
	item.global_position = at
	item.activate()
	item.move.set_physics_process(false)
	item.set_physics_process(false)
	var cursed = item.get_node_or_null("Jujutsu")
	if cursed != null: cursed.set_physics_process(false)
	return item
func fire(source, direction: Vector3):
	source.get_node("Jujutsu").cast(ctx.make(source.center(), direction))
	for beam in get_nodes_in_group("cursed_beams"):
		if beam.thing.spawner == source and beam.live: return beam
	return null
func clear() -> void:
	for item in game.get_node("Things").get_children(): item.remove()
	await create_timer(.25).timeout
	root.get_node("Forge").production.reset()
func _run() -> void:
	await process_frame
	lex = root.get_node("Lexicon").data
	parser = load("res://scripts/language/phrase_parser.gd")
	assembler = load("res://scripts/things/assembler.gd")
	ctx = load("res://scripts/things/action_context.gd")
	beam_script = load("res://scripts/things/cursed_beam.gd")
	load("res://scenes/main.gd").next_mode = "practice"
	game = load("res://scenes/main.tscn").instantiate()
	game.voice_enabled = false
	root.add_child(game)
	current_scene = game
	await create_timer(.6).timeout
	for player in [game.player, game.opponent]:
		player.set_physics_process(false)
		player.global_position = Vector3(30, 30, 30)
	for phrase in ["quero granite blast", "quero raio da rika", "quero raio do riu", "quero raio do iuta", "quero um cachorro com raio do yuta", "quero um dragão com raio do ryu"]:
		var item = spawn(phrase, Vector3(-20, 30, 15))
		check(item.get_node_or_null("Jujutsu") != null, "Composition lost beam power")
		item.remove()
	await clear()
	var ryu = spawn("quero raio do ryu", Vector3(-12, 30, 0))
	var victim = spawn("quero um elefante", Vector3(0, 30, 0), 2)
	var side = spawn("quero um cachorro", Vector3(0, 30, 6), 2)
	var protected = spawn("quero um cachorro com infinito", Vector3(8, 30, 0), 2)
	var hp: float = victim.hp
	var side_hp: float = side.hp
	var protected_hp: float = protected.hp
	var beam = fire(ryu, Vector3.RIGHT)
	check(beam != null, "Ryu did not fire")
	fire(ryu, Vector3.RIGHT)
	check(get_nodes_in_group("cursed_beams").size() == 1, "Cooldown allowed duplicate beams")
	await create_timer(.85).timeout
	check(victim.hp < hp and side.hp == side_hp, "Beam did not damage only targets in its path")
	check(protected.hp == protected_hp, "Ordinary energy beam bypassed Infinity")
	await clear()
	ryu = spawn("quero raio do ryu", Vector3(-12, 30, 0))
	var yuta = spawn("quero raio do yuta", Vector3(12, 30, 0), 2)
	var a = fire(ryu, Vector3.RIGHT)
	var b = fire(yuta, Vector3.LEFT)
	var weak_b = weakref(b)
	await create_timer(.9).timeout
	check(a.clashing and b.clashing and a.endpoint.distance_to(b.endpoint) < .1, "Opposing beams did not meet in a visible clash")
	var network = load("res://scripts/network/thing_network_state.gd")
	var replica = assembler.build_replica({"thing": "ryu_beam_stream"}, "projectile", lex, 9100, 1)
	game.add_thing(replica)
	replica.activate()
	network.apply(replica, network.capture(a.thing))
	var remote = replica.get_node("CursedBeam")
	check(remote.clashing and remote.endpoint.distance_to(a.endpoint) < .01 and remote.origin.distance_to(a.origin) < .01, "Clash visual state did not replicate")
	replica.remove()
	await create_timer(1.3).timeout
	var loser = weak_b.get_ref()
	check(a.live and (not is_instance_valid(loser) or not loser.live), "Ryu did not overpower Yuta at base output")
	await clear()
	ryu = spawn("quero raio do ryu", Vector3(-12, 30, 0))
	yuta = spawn("quero raio do ryu", Vector3(12, 30, 0), 2)
	a = fire(ryu, Vector3.RIGHT)
	b = fire(yuta, Vector3.LEFT)
	var weak_a = weakref(a)
	weak_b = weakref(b)
	await create_timer(2.3).timeout
	a = weak_a.get_ref()
	b = weak_b.get_ref()
	check((not is_instance_valid(a) or not a.live) and (not is_instance_valid(b) or not b.live), "Equal-output clash did not annihilate both beams")
	await clear()
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.5, 8, 8)
	shape.shape = box
	wall.add_child(shape)
	game.add_child(wall)
	wall.global_position = Vector3(0, 30, 0)
	await physics_frame
	ryu = spawn("quero raio do ryu", Vector3(-12, 30, 0))
	victim = spawn("quero um cachorro", Vector3(3, 30, 0), 2)
	hp = victim.hp
	beam = fire(ryu, Vector3.RIGHT)
	await create_timer(.9).timeout
	check(beam.endpoint.x <= -.24 and victim.hp == hp, "Beam damaged a target behind a solid wall")
	wall.queue_free()
	await clear()
	# Destructible blocks are drilled by bounded jobs; permanent cells survive.
	var volume = load("res://scripts/world/block_volume.gd").new()
	volume.setup(919, Vector3i(4, 8, 8), Vector3.ZERO)
	var soil: int = volume.add_type("soil", Color("72583d"))
	var permanent: int = volume.add_type("soil", Color.BLACK, 2)
	volume.blocks.fill(soil)
	volume.blocks[0] = permanent
	game.add_child(volume)
	volume.global_position = Vector3(0, 29, -1)
	volume.commit_base()
	ryu = spawn("quero raio do ryu", Vector3(-12, 30, 0))
	fire(ryu, Vector3.RIGHT)
	await create_timer(1.2).timeout
	check(volume.blocks.count(0) > 0, "Beam did not destroy destructible blocks")
	check(volume.blocks[0] == permanent, "Beam destroyed permanent terrain")
	volume.queue_free()
	await clear()
	# Parallel/friendly beams do not create a duel.
	var clash_count: int = beam_script.clashes
	ryu = spawn("quero raio do ryu", Vector3(-12, 30, 0))
	yuta = spawn("quero raio do yuta", Vector3(12, 30, 0))
	fire(ryu, Vector3.RIGHT)
	fire(yuta, Vector3.LEFT)
	await create_timer(.9).timeout
	check(beam_script.clashes == clash_count, "Friendly beams entered a hostile clash")
	await clear()
	# A held emitter stops as soon as it is dropped.
	ryu = spawn("quero raio do yuta", Vector3(0, 30, 0))
	ryu.set_held(true)
	beam = fire(ryu, Vector3.FORWARD)
	weak_a = weakref(beam)
	await create_timer(.1).timeout
	ryu.set_held(false)
	await create_timer(.2).timeout
	a = weak_a.get_ref()
	check(not is_instance_valid(a) or not a.live, "Dropped emitter left beam active")
	await clear()
	check(get_nodes_in_group("cursed_beams").is_empty(), "Beam actors leaked after cleanup")
	print("CURSED_BEAMS ", JSON.stringify({"failures": failures, "clashes": beam_script.clashes}))
	quit(0 if failures.is_empty() else 1)
