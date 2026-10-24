extends SceneTree

var failures := []
var evidence := {}
var game
var lex
var assembler
var parser
var forge

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func spawn(phrase: String, at: Vector3, team: int = 1):
	var parsed: Dictionary = parser.parse(phrase, lex)
	check(parsed.get("ok", false) and parsed.unknown_words.is_empty(), "Bad phrase: " + phrase)
	var item = assembler.build(parsed.recipe, "head", lex)
	item.set_owner_info(team, team, game.player if team == 1 else game.opponent, null)
	game.add_thing(item)
	item.global_position = at
	forge._register(item)
	item.activate()
	return item

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
	forge = root.get_node("Forge")
	var ground = load("res://scripts/things/ground_items.gd")
	var frame_type = load("res://scripts/input/player_input_frame.gd")
	var input_frame = frame_type.new()
	input_frame.pickup = true
	input_frame.drop_item = true
	input_frame.event_seq = 1
	check(input_frame.copy().pickup and input_frame.copy().drop_item and input_frame.has_events(), "Pickup/drop commands lost on network wire")
	check(not input_frame.without_events().pickup and not input_frame.without_events().drop_item, "Repeated movement replays item exchange")
	check(InputMap.has_action("pickup") and InputMap.has_action("drop_item"), "Ground item keys missing")
	await create_timer(.6).timeout
	game.player.set_physics_process(false)
	game.player.global_position = Vector3(0,1,0)
	game.player.frozen = false
	game.opponent.set_physics_process(false)
	var gun = spawn("quero uma pistola", Vector3(0,1,0))
	gun.ammo = 7
	game.player.hands.give(gun, false)
	var ball = spawn("quero uma pokebola", Vector3(0,1,-2))
	ground.drop(ball, ball.global_position, Vector3.ZERO)
	ball.get_node("GroundMotion").set_physics_process(false)
	var catcher = ball.get_node("CaptureBall")
	var animal = spawn("quero um cachorro com cara de tiranossauro rex com a habilidade do mahoraga com uma pistola", Vector3(3,1,-2), 2)
	animal.move.set_physics_process(false)
	var identity: int = animal.get_instance_id()
	animal.hp = animal.max_hp * .6
	var hp: float = animal.hp
	var weapon = animal.grafts[0]
	weapon.ammo = 5
	for component in weapon.get_children():
		if component.has_meta("thing_gameplay_component"): component.set_physics_process(false)
	animal.get_node("Jujutsu").exposure.infinity = 3
	check(catcher._attempt(weakref(animal), 0.0), "Capture failed on successful roll")
	check(animal.is_captured and not animal.visible and not animal.is_active and animal.collision_layer == 0, "Captured animal remains active/visible/collidable")
	var clock: float = animal.get_node("Jujutsu").clock
	for step in 10: await physics_frame
	check(animal.get_node("Jujutsu").clock == clock and weapon.ammo == 5, "Captured abilities or guns kept running")
	check(forge.spawn_child(animal.node_data,"spawned",animal.center(),Vector3.FORWARD,animal,0.0,Vector3.ZERO,true) == null, "Captured producer continued spawning creatures")
	ball.pickup_after_ms = 0
	check(game.player.hands.pickup(ball), "Cannot pick up full ball")
	check(game.player.hands.current_item() == ball and gun.ground_item and not gun.is_held and not gun.is_dead and gun.ammo == 7, "Pickup failed to drop original weapon with ammunition")
	var second = spawn("quero uma pokebola", Vector3(0,1,-2))
	check(not second.get_node("CaptureBall")._attempt(weakref(animal), 0.0), "Two balls duplicated one captured creature")
	second.remove()
	# Throwing the occupied ball moves the original ball, not a recipe clone.
	game.player.hands._throw(ball, Vector3(0,3,-1), Vector3.FORWARD)
	check(game.player.hands.current_item() == null and ball.ground_item and not ball.is_dead, "Throw consumed or duplicated reusable ball")
	for step in 55: await physics_frame
	check(not animal.is_captured and animal.visible and animal.is_active and animal.get_instance_id() == identity, "Release did not restore original living creature")
	check(animal.hp == hp and animal.owner_id == 1 and animal.team == 1 and weapon.team == 1 and weapon.ammo == 5, "Release lost health/ammunition or failed to change team")
	check(animal.node_data.mods.anatomy.head == "trex" and animal.get_node("Jujutsu").adapted("infinity"), "Capture lost hybrid or adaptation progress")
	check(catcher.occupant() == null, "Released animal remains duplicated inside ball")
	evidence.original_creature_preserved = animal.get_instance_id() == identity
	evidence.captured_health = hp
	evidence.released_team = animal.team
	evidence.weapon_ammo_preserved = gun.ammo
	# Rejection leaves the animal unchanged; an active Infinity also rejects the ball.
	var reject_ball = spawn("quero bola de captura", Vector3(4,2,-2))
	var prey = spawn("quero um triceratops", Vector3(4,1,-2), 2)
	prey.move.set_physics_process(false)
	check(not reject_ball.get_node("CaptureBall")._attempt(weakref(prey), .999) and not prey.is_captured and prey.visible, "Rejected creature was deleted or captured")
	check(not reject_ball.get_node("CaptureBall")._attempt(weakref(gun), 0.0), "Ball captured a weapon")
	var protected = spawn("quero um pato com infinito", Vector3(6,1,-2), 2)
	protected.move.set_physics_process(false)
	check(not reject_ball.get_node("CaptureBall")._attempt(weakref(protected), 0.0), "Ball ignored active Infinity")
	# Destroying a full ball must release its occupant instead of silently deleting it.
	check(reject_ball.get_node("CaptureBall")._attempt(weakref(prey), 0.0), "Second successful capture failed")
	reject_ball.remove()
	check(not prey.is_dead and not prey.is_captured and prey.visible, "Destroying ball deleted its occupant")
	# Ground objects keep their instance and magazine when exchanged again.
	gun.global_position = Vector3(0,1,-1)
	gun.velocity = Vector3.ZERO
	gun.pickup_after_ms = 0
	check(game.player.hands.pickup(gun) and game.player.hands.current_item() == gun and gun.ammo == 7, "Dropped weapon cannot be recovered intact")
	evidence.rejection_preserves_creature = not protected.is_captured
	# Real thrown-ball collision must run a capture attempt without calling the helper directly.
	var cow = spawn("quero uma vaca", Vector3(10,2,-2), 2)
	cow.move.set_physics_process(false)
	cow.set_physics_process(false)
	var thrown_ball = spawn("quero uma pokebola", cow.center() + Vector3.BACK * 2.0)
	game.player.hands.give(thrown_ball, true)
	game.player.hands._throw(thrown_ball, cow.center() + Vector3.BACK * 2.0, Vector3.FORWARD)
	for step in 24: await physics_frame
	check(thrown_ball.get_node("CaptureBall").result in ["captured", "rejected"], "Actual thrown collision never attempted capture")
	evidence.thrown_collision_result = thrown_ball.get_node("CaptureBall").result
	var queen = spawn("quero uma formiga rainha", Vector3(14,1,-2))
	var nest = spawn("quero um ninho de formigas", Vector3(14,1,-3))
	nest.get_node("EcologyBehavior").queen_ref = weakref(queen)
	var queen_ball = spawn("quero uma pokebola", Vector3(14,2,-2))
	queen_ball.get_node("CaptureBall")._attempt(weakref(queen), 0.0)
	check(not nest.get_node("EcologyBehavior")._living_queen(), "Nest kept using its captured queen")
	queen_ball.get_node("CaptureBall").release()
	check(nest.get_node("EcologyBehavior")._living_queen(), "Released allied queen did not resume nest support")
	game.player.hands.clear()
	for item in game.get_node("Things").get_children(): item.remove()
	for step in 3: await process_frame
	await create_timer(.4).timeout
	var report := {"failures": failures, "evidence": evidence}
	var file := FileAccess.open(ProjectSettings.globalize_path("res://").path_join("../analysis/capture-items.json").simplify_path(), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("CAPTURE_ITEMS ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
