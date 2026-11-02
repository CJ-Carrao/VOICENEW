extends Node







const OUT: = "res://export/playstore/brutos/"

const PHRASES: = {
	"pt_br": {"hero": "quero uma torre gigante que atira pombos explosivos", "pistol": "quero uma pistola que atira um pombo que caga granadas", 
		"orbit": "quero tres pombos que orbitam", "bazooka": "quero uma bazuca gigante", "minigun": "quero uma minigun de fogo"}, 
	"en_us": {"hero": "i want a giant tower that shoots explosive pigeons", "pistol": "i want a pistol that shoots a pigeon that poops grenades", 
		"orbit": "i want three pigeons that orbit", "bazooka": "i want a giant bazooka", "minigun": "i want a fire minigun"}, 
}

var _game: Match
var _p: Player
var _house: Structure
var _lang: = "pt_br"
var _out: = ""
var _cine: Camera3D
var _expression: = "Happy"


func _ready() -> void :
	_lang = Lexicon.language()
	_out = OUT + _lang + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_run.call_deferred()


func _run() -> void :
	await _open("")
	await _hero()
	await _pistol()
	await _extraction()
	await _pigeons()
	await _destruction()
	await _open("space")
	await _space()
	Forge.test_free_matter = false
	get_tree().quit()


func _say(key: String) -> String:
	return String(PHRASES[_lang][key])


func _open(map: String) -> void :
	if _game != null:
		_game.queue_free()
		await _frames(3)
	Arena.next_map = map
	Arena.play_intro = false
	Session.start_offline("practice")
	_game = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Match
	_game.mode = "practice"
	_game.configure_session = false
	_game.voice_enabled = false
	get_tree().root.add_child(_game)
	get_tree().current_scene = _game
	for i in 600:
		await get_tree().process_frame
		if _game.arena.is_world_ready() and i > 90:
			break
	await _seconds(1.5)
	_p = _game.player
	_p.input_provider = ControlFieldsInput.new()
	_game._hud.visible = false
	_game.dummy.set("moving", false)
	Forge.test_free_matter = true

	var view: = get_viewport()
	view.scaling_3d_scale = 1.0
	view.msaa_3d = Viewport.MSAA_4X
	view.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	_cine = Camera3D.new()
	_cine.name = "StoreCinema"
	_game.add_child(_cine)
	var dof: = CameraAttributesPractical.new()
	dof.dof_blur_far_enabled = true
	dof.dof_blur_amount = 0.09
	_cine.attributes = dof



func _frame() -> Basis:
	return _p.gravity_frame * Basis(Vector3.UP, _p.yaw)


func _at(local: Vector3) -> Vector3:
	return _p.global_position + _frame() * local



func _cinema(from_local: Vector3, look_local: Vector3, fov: float, focus_extra: float = 2.5) -> void :
	_cine.global_position = _at(from_local)
	_cine.look_at(_at(look_local), _frame().y)
	_cine.fov = fov
	var dof: = _cine.attributes as CameraAttributesPractical
	dof.dof_blur_far_distance = _cine.global_position.distance_to(_at(Vector3(0, 1.2, 0))) + focus_extra
	dof.dof_blur_far_transition = 8.0
	_cine.make_current()


func _face(target: Vector3) -> void :
	_p.look_at_point(target)



func _hero() -> void :
	var spawn: = _game.arena.get_spawn(0)
	_p.place_at(spawn)
	await _seconds(0.5)

	var spot: = _at(Vector3(2.6, 0, -3.4))
	_face(spot)
	await _frames(2)
	Forge.request(1, _say("hero"), false)
	if Forge.has_draft(1):
		Forge.confirm_draft(1)
	_face(spot + _frame().y * 2.0)
	_expression = "VeryHappy"
	for i in 12:
		_cinema(Vector3(-1.7, 0.55, -3.6), Vector3(0.9, 1.6, -1.4), 42.0, 4.0)
		await _seconds(0.18)
		await _shot("1_frase_%02d.png" % i)
	await _seconds(3.0)



func _pistol() -> void :
	_p.hands.clear()
	var spawn: = _game.arena.get_spawn(0)
	_p.place_at(spawn)
	_face(_at(Vector3(0.3, 1.2, -8.0)))
	await _seconds(0.4)
	Forge.request(1, _say("pistol"), false)
	_expression = "Focused"
	for i in 12:
		_cinema(Vector3(-0.55, 1.15, -1.85), Vector3(0.05, 1.25, 0.0), 38.0, 1.5)
		await _seconds(0.11)
		await _shot("2_pistola_%02d.png" % i)
	await _seconds(2.0)



func _extraction() -> void :
	_p.hands.clear()
	var best_count: = 0
	for structure: Structure in _game.arena.structures():
		var near: = structure.facing_chunk_point(_p.global_position).distance_to(_p.global_position) < 40.0
		if near and structure.chunk_count() > best_count:
			best_count = structure.chunk_count()
			_house = structure
	var target: = _house.facing_chunk_point(_p.global_position)
	var away: = _p.global_position - target
	away.y = 0.0
	var spot: = target + away.normalized() * 3.0
	_p.global_position = Vector3(spot.x, _p.global_position.y, spot.z)
	_p.velocity = Vector3.ZERO
	_face(target)
	await _seconds(0.6)
	_p.set_extracting(true)
	_p.hands.use_pressed()
	_expression = "Straining"
	var held: = 0.0
	var shot: = 0
	while held < 5.0:
		if _p.extractor.problem == "nothing":
			var next: = _house.facing_chunk_point(_p.global_position)
			if next.is_finite() and next.distance_to(_p.global_position) > 0.8:
				target = target.lerp(next, 0.1)
		_face(target)

		_cinema(Vector3(1.9, 0.75, -1.6), Vector3(-0.2, 1.3, -0.9), 46.0, 3.0)
		_p.robot.face.set_expression(_expression)
		await get_tree().process_frame
		held += get_process_delta_time()
		if held > 1.2 and int(held / 0.3) > shot:
			shot = int(held / 0.3)
			await _shot("3_extracao_%02d.png" % shot)
	_p.hands.use_released()
	_p.set_extracting(false)
	await _seconds(0.5)



func _pigeons() -> void :
	var spawn: = _game.arena.get_spawn(0)
	_p.place_at(spawn)
	await _seconds(0.5)
	_p.hands.clear()
	Forge.request(1, _say("orbit"), false)
	await _seconds(3.5)
	Forge.request(1, _say("pistol"), false)
	await _seconds(3.5)
	var dummy: = _game.dummy.global_position
	_expression = "VeryHappy"
	for k in 2:
		_face(dummy + Vector3.UP * 3.0)
		await _frames(2)
		_p.hands.use_pressed()
		await _frames(1)
		_p.hands.use_released()
		await _seconds(0.35)

	for i in 14:
		_face(dummy + Vector3.UP * 3.0)
		_cinema(Vector3(-1.6, 0.35, -3.0), Vector3(-0.2, 2.0, 0.0), 50.0, 4.0)
		await _seconds(0.2)
		await _shot("4_combinacoes_%02d.png" % i)



func _destruction() -> void :
	var at: = _house.global_position
	var away: = (_p.global_position - at)
	away.y = 0.0
	_p.place_at(Transform3D(Basis.IDENTITY, at + away.normalized() * 9.0 + Vector3.UP * 0.2))
	await _seconds(0.6)
	_p.hands.clear()
	Forge.request(1, _say("bazooka"), false)
	if Forge.has_draft(1):
		Forge.confirm_draft(1)
	await _seconds(4.5)
	_face(at + Vector3.UP * 1.5)
	_p.view.distance = 3.0
	_p.view.current_distance = 3.0
	await _seconds(0.4)
	var boom: = [false]
	Forge.explosion_at.connect( func(_a: Vector3, _r: float, _d: float) -> void : boom[0] = true, CONNECT_ONE_SHOT)
	_p.hands.use_pressed()
	await _frames(1)
	_p.hands.use_released()

	_expression = "Determined"
	var house_local: = _frame().inverse() * (at - _p.global_position)
	for i in 200:
		_cinema(Vector3(0.9, 0.9, -3.4), Vector3(house_local.x * 0.25, 1.6, house_local.z * 0.25), 45.0, 9.0)
		await get_tree().process_frame
		if boom[0]:
			break
	for i in 10:
		await _shot("5_destruicao_%02d.png" % i)
		await _seconds(0.07)
	await _seconds(2.0)



func _space() -> void :
	_p.place_at(_game.arena.get_spawn(0))
	await _seconds(1.0)
	Forge.request(1, _say("minigun"), false)
	await _seconds(3.5)
	_face(Vector3.ZERO)
	_expression = "Happy"
	for i in 6:
		_cinema(Vector3(-1.4, 0.4, -2.6), Vector3(0.0, 1.9, 0.0), 55.0, 30.0)
		await _seconds(0.35)
		await _shot("6_espaco_%02d.png" % i)
	for i in 6:
		_cinema(Vector3(1.8, 0.2, -1.8), Vector3(-0.4, 2.2, 1.0), 60.0, 30.0)
		await _seconds(0.35)
		await _shot("6b_espaco_%02d.png" % i)


func _shot(file: String) -> void :
	for node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if node is FpsOverlay:
			(node as CanvasLayer).visible = false
	_game._hud.visible = false
	if _p.robot != null and _p.robot.face != null:
		_p.robot.face.set_expression(_expression)
	await _frames(1)
	await RenderingServer.frame_post_draw
	var image: = get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(_out + file))
	print("[Loja] ", file)


func _frames(n: int) -> void :
	for i in n:
		await get_tree().process_frame


func _seconds(s: float) -> void :
	await get_tree().create_timer(s).timeout
