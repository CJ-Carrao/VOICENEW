class_name TutorialRecorder
extends Node









const MOVIE_FPS: = 30.0

const PHRASES: = {
	"pt_br": "quero uma pistola que atira um pombo que caga granada que explode depois de 1 segundo", 
	"en_us": "i want a pistol that shoots a pigeon that poops grenades that explode after 1 second", 
}

var _main: Node
var _player: Player
var _touch: TouchControls
var _voice: VoiceInput
var _scene: = ""
var _wav: = ""
var _structure: Structure


func setup(main: Node, player: Player, spec: String) -> void :
	_main = main
	_player = player
	var parts: = spec.split(",", true, 1)
	_scene = parts[0]
	_wav = parts[1] if parts.size() > 1 else ""


func run() -> void :
	_touch = get_tree().get_first_node_in_group(TouchControls.GROUP) as TouchControls
	_voice = _main.get("voice") as VoiceInput
	if _touch == null:
		push_error("--gravar-tutorial precisa de --mobile")
		get_tree().quit(1)
		return

	while _voice.state == "warming" or LoadingScreen.current != null:
		await get_tree().process_frame
	_voice.transcribed.connect( func(text: String, _s: float) -> void : print("[Tutorial] ouviu: ", text))
	_voice.ignored.connect( func(reason: String) -> void : print("[Tutorial] voz ignorou: ", reason))
	_voice.state_changed.connect( func(state: String) -> void : print("[Tutorial] voz: ", state))

	get_tree().process_frame.connect( func() -> void :
		_touch.set("_focused", true)

		for node in get_tree().root.get_children():
			if node is FpsOverlay: (node as FpsOverlay).visible = false)
	await _wait(0.6)
	_mark("inicio")
	match _scene:
		"extrair": await _extract()
		"falar": await _talk()
		"criar": await _create()
	_mark("fim")
	get_tree().quit()


func _extract() -> void :
	_camera(0.0)
	var target: = _big_structure_point()
	_player.look_at_point(target)
	await _wait(1.2)
	_mark("extract", "extract")
	_player.set_extracting(true)
	await _wait(0.9)
	_mark("use", "use")
	_player.hands.use_pressed()
	var held: = 0.0
	while held < 4.6:

		if _player.extractor.problem == "nothing" and is_instance_valid(_structure):
			var next: = _structure.facing_chunk_point(_player.global_position)
			if next.is_finite() and next.distance_to(_player.global_position) > 0.8:
				target = target.lerp(next, 0.08)
		_player.look_at_point(target)
		await get_tree().process_frame
		held += get_process_delta_time()
	_player.hands.use_released()
	print("[Tutorial] matéria extraída: %.0f (pode agir %s)" % [_player.matter, _player.can_act()])
	await _wait(1.0)


func _talk() -> void :
	_camera(0.0)
	await _wait(0.8)
	_mark("talk", "talk")
	_action("talk", true)
	await _wait(0.45)
	_play_voice()

	var samples: = WavReader.read_16k_mono(_wav)
	var mix: = AudioServer.get_mix_rate()
	var step: = float(SpeechEngine.SAMPLE_RATE) / mix
	var frames: = PackedVector2Array()
	var at: = 0.0
	while at < samples.size():
		var count: = int(mix * get_process_delta_time())
		frames.resize(count)
		for i in count:
			var value: = samples[mini(int(at), samples.size() - 1)]
			frames[i] = Vector2(value, value)
			at += step
		_voice.push_capture_frames(frames)
		await get_tree().process_frame
	await _wait(0.35)
	_action("talk", false)
	_mark("solta")
	while _voice.state != "idle":
		await get_tree().process_frame
	_mark("entendeu")
	await _wait(2.2)


func _create() -> void :
	_camera(0.0)
	var dummy: = _main.get("dummy") as Node3D
	if dummy != null:

		var away: = _player.global_position - dummy.global_position
		away.y = 0.0
		dummy.set("moving", false)
		var spot: = dummy.global_position + away.normalized() * 13.0
		_player.global_position = Vector3(spot.x, _player.global_position.y, spot.z)
		_player.look_at_point(dummy.global_position + Vector3.UP * 1.2)
	await _wait(0.6)
	_mark("pede")
	Forge.request(_player.player_id, String(PHRASES.get(Lexicon.language(), PHRASES["pt_br"])))
	await _wait(0.3)
	while Forge.is_building(_player.player_id):
		await get_tree().process_frame
	_mark("pronta")
	await _wait(1.0)

	var over: = dummy.global_position + Vector3.UP * 3.5 if dummy != null else Vector3.ZERO
	if dummy != null:
		_player.look_at_point(over)
	_mark("use", "use")
	for shot in 2:
		_player.hands.use_pressed()
		_player.hands.use_released()
		await _wait(0.9)
	var watched: = 0.0
	while watched < 6.0:
		if dummy != null:
			_player.look_at_point(dummy.global_position + Vector3.UP * 1.8)
		await get_tree().process_frame
		watched += get_process_delta_time()



func _camera(distance: float) -> void :
	_player.view.distance = distance
	_player.view.set("current_distance", distance)



func _big_structure_point() -> Vector3:
	var arena: = _main.get("arena") as Node
	var best_count: = 0
	for structure: Structure in arena.call("structures"):
		var near: = structure.facing_chunk_point(_player.global_position).distance_to(_player.global_position) < 40.0
		if near and structure.chunk_count() > best_count:
			best_count = structure.chunk_count()
			_structure = structure
	var best: = _structure.facing_chunk_point(_player.global_position)
	var away: = _player.global_position - best
	away.y = 0.0
	var spot: = best + away.normalized() * 3.2
	_player.global_position = Vector3(spot.x, _player.global_position.y, spot.z)
	_player.velocity = Vector3.ZERO
	return best



func _mark(name: String, button: String = "") -> void :
	var line: = "[Tutorial] marca %s %.3f" % [name, float(Engine.get_process_frames()) / MOVIE_FPS]
	if not button.is_empty():
		var screen: = get_viewport().get_visible_rect().size
		var local: = _touch.button_rect(button)
		var at: = (_touch.get_screen_transform() * local.position) / screen
		var size: = local.size * _touch.get_screen_transform().get_scale() / screen
		line += " %.4f %.4f %.4f %.4f" % [at.x, at.y, size.x, size.y]
	print(line)


func _play_voice() -> void :
	var stream: = AudioStreamWAV.load_from_file(_wav)
	if stream == null:
		return
	var speaker: = AudioStreamPlayer.new()
	speaker.stream = stream
	speaker.bus = AudioMix.bus(AudioMix.VOICES)
	add_child(speaker)
	speaker.play()



func _action(action: String, pressed: bool) -> void :
	var event: = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)


func _wait(seconds: float) -> void :
	await get_tree().create_timer(seconds).timeout
