extends SceneTree

var failures := []
var game
var lex
var assembler
var parser

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func equip(id: String, player):
	var item = assembler.build(load("res://scripts/language/recipe.gd").new_node(id), "head", lex)
	item.set_owner_info(player.player_id, player.team, player, null)
	player.hands.give(item, false)
	item.activate()
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
	for player in [game.player, game.opponent]:
		player.set_physics_process(false)
		player.frozen = false
		player.input_enabled = true
		player.add_to_group("combatants")
	game.player.global_position = Vector3(0, 20, 7)
	game.opponent.global_position = Vector3(0, 20, -7)
	var status = load("res://scripts/things/status.gd")
	var tool = equip("unlimited_void", game.player)
	var gun = equip("pistol", game.opponent)
	var user = tool.get_node("Jujutsu")
	check(user.expand_domain(), "Void failed to open")
	check(user.domain_origin.distance_to(game.player.center()) < 9.0 and user.domain_origin.distance_to(game.opponent.center()) < 9.0, "Sphere did not enclose both players 14 m apart")
	check(user.domain_origin.distance_to(game.player.center()) > 5.0, "Sphere was not centered on the duel")
	user.clock = .8
	user._domain()
	check(status.paralyzed(game.opponent) and not game.opponent.can_act(), "Enemy player was only slowed")
	check(not status.paralyzed(game.player) and game.player.can_act(), "Caster was paralyzed by own domain")
	var before: Vector3 = game.opponent.global_position
	game.opponent.velocity = Vector3(10, 10, 10)
	game.opponent.move.step(.1, {"wish": Vector2(1, -1), "jump_pressed": true, "jump_held": true, "sprint": true, "climb": 1.0})
	check(game.opponent.global_position == before and game.opponent.velocity == Vector3.ZERO, "Paralyzed player could run, jump or keep momentum")
	var ammo: int = gun.ammo
	check(not gun.fire(gun.context_here()) and gun.ammo == ammo, "Paralyzed player fired a held weapon")
	var drop := InputEventAction.new()
	drop.action = "drop_item"
	drop.pressed = true
	game.opponent._unhandled_input(drop)
	check(game.opponent.hands.current_item() == gun, "Offline input dropped equipment during paralysis")
	check(root.get_node("Forge").request(2, "quero uma pistola").get("blocked", false), "Text request bypassed paralysis")
	var frame = load("res://scripts/input/player_input_frame.gd").new()
	frame.wish = Vector2(1, -1)
	frame.jump_pressed = true
	frame.use_pressed = true
	frame.use_held = true
	frame.drop_item = true
	game.opponent._apply_network_frame(frame, .016, false)
	check(game.opponent.global_position == before and gun.ammo == ammo and game.opponent.hands.current_item() == gun, "Network input bypassed paralysis")
	var simple = equip("simple_domain", game.opponent)
	status.of(game.opponent)._refresh_void()
	check(not status.paralyzed(game.opponent), "Simple domain did not release paralysis")
	simple.remove()
	await process_frame
	user._domain()
	check(status.paralyzed(game.opponent), "Void did not resume after protection ended")
	# Multiple same-team domains must not remove one another's valid lock.
	var second = assembler.build(load("res://scripts/language/recipe.gd").new_node("unlimited_void"), "head", lex)
	second.set_owner_info(1, 1, game.player, null)
	game.add_thing(second)
	second.set_held(true)
	second.activate()
	var other = second.get_node("Jujutsu")
	check(other.expand_domain(), "Second allied domain failed")
	other.clock = .8
	other._domain()
	user.cancel_domain()
	status.of(game.opponent)._refresh_void()
	check(status.paralyzed(game.opponent), "Cancelling one domain erased another active lock")
	other.clock = other.domain_until + .1
	status.of(game.opponent)._refresh_void()
	check(not status.paralyzed(game.opponent) and game.opponent.can_act(), "Paralysis persisted after domain expired")
	# Ordinary ice keeps its existing slow instead of becoming this stun.
	status.apply(game.opponent, "frozen", tool)
	check(game.opponent.can_act() and is_equal_approx(status.speed_mult(game.opponent), .3), "Void changed ordinary ice balance")
	tool.remove()
	second.remove()
	gun.remove()
	print("VOID_DUEL ", JSON.stringify({"failures": failures, "enclosed_distance_m": 14, "full_paralysis": true}))
	quit(0 if failures.is_empty() else 1)
