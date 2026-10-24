extends SceneTree

var failures := []
var events := {"commands": 0, "creations": 0, "taps": 0}
var voice

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func key(code: int, pressed: bool):
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	return event

func _run() -> void:
	await process_frame
	check(InputMap.action_has_event("command_talk", key(KEY_B, true)), "B is not bound to command voice")
	check(InputMap.action_has_event("talk", key(KEY_V, true)), "V creation binding changed")
	var lex = root.get_node("Lexicon").data
	var parser = load("res://scripts/language/phrase_parser.gd")
	for phrase in ["Squirtle, ataque", "squitle atacar", "mande o squirtle atacar", "mandar o squirtle atacar"]:
		var parsed: Dictionary = parser.parse(phrase, lex)
		check(parsed.get("ok", false) and parsed.recipe.get("command") == "pokemon_squirtle_water_gun", "Missing generic attack order: " + phrase)
	load("res://scenes/main.gd").next_mode = "practice"
	var game = load("res://scenes/main.tscn").instantiate()
	game.voice_enabled = false
	root.add_child(game)
	current_scene = game
	await create_timer(.6).timeout
	game.player.frozen = false
	game.player.set_physics_process(false)
	game.player.global_position = Vector3(12, 6, 7)
	voice = game.voice
	voice.set_process(false)
	voice.player = game.player
	voice.state = "idle"
	voice.command_transcribed.connect(func(_text, _seconds): events.commands += 1)
	voice.transcribed.connect(func(_text, _seconds): events.creations += 1)
	voice.tapped.connect(func(): events.taps += 1)
	var assembler = load("res://scripts/things/assembler.gd")
	var actor = assembler.build(parser.parse("quero um squirtle", lex).recipe, "head", lex)
	actor.set_owner_info(1, 1, game.player, null)
	game.add_thing(actor)
	actor.global_position = Vector3(12, 6, 3)
	actor.activate()
	actor.move.set_physics_process(false)
	actor.set_physics_process(false)
	var enemy = assembler.build(parser.parse("quero um cachorro", lex).recipe, "head", lex)
	enemy.set_owner_info(2, 2, game.opponent, null)
	game.add_thing(enemy)
	enemy.global_position = Vector3(12, 6, -3)
	enemy.activate()
	enemy.move.set_physics_process(false)
	enemy.set_physics_process(false)
	game.player.look_at_point(enemy.center())
	await physics_frame
	await physics_frame
	voice._unhandled_input(key(KEY_B, true))
	check(voice.state == "listening" and voice.is_command_talk(), "B did not start command recording")
	voice._unhandled_input(key(KEY_V, true))
	voice._input(key(KEY_V, false))
	check(voice.state == "listening" and voice.is_command_talk(), "V interrupted or changed an ongoing B recording")
	voice._input(key(KEY_B, false))
	check(voice.state == "thinking" and events.taps == 0, "Short B press toggled extraction")
	voice._unhandled_input(key(KEY_V, true))
	check(voice.is_command_talk(), "V changed command mode while transcription was pending")
	voice._tail_until = 0
	voice.state = "idle"
	var hp: float = enemy.hp
	voice._done("Squirtle, ataque", .1, "")
	check(events.commands == 1 and events.creations == 0 and enemy.hp < hp, "B transcription did not execute the live Squirtle order")
	var forge = root.get_node("Forge")
	var count: int = game.get_node("Things").get_child_count()
	var matter: float = game.player.matter_spendable()
	for phrase in ["quero uma pistola", "quero uma bomba nuclear", "palavras sem comando"]:
		var result: Dictionary = forge.request(1, phrase, false, true)
		check(result.get("blocked", false) and game.get_node("Things").get_child_count() == count and game.player.matter_spendable() == matter, "B created or spent matter: " + phrase)
	voice._unhandled_input(key(KEY_V, true))
	check(not voice.is_command_talk() and voice.state == "listening", "V retained previous command-only mode")
	voice._input(key(KEY_V, false))
	check(events.taps == 1, "V tap no longer toggles extraction")
	voice.state = "idle"
	check(voice.begin_talk(true) and not voice.is_command_talk(), "Private microphone test was changed to a command")
	voice._discard_creation_recording()
	actor.remove()
	enemy.remove()
	print("COMMAND_VOICE_KEY ", JSON.stringify({"failures": failures, "events": events}))
	quit(0 if failures.is_empty() else 1)
