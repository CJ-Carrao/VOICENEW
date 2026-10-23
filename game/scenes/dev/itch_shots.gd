extends Node





const OUT: = "res://export/itch/fotos/"

var _game: Match
var _p: Player

var _house: Structure


func _ready() -> void :
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _run() -> void :
	await _open("")
	await _assembly()
	await _extraction()
	await _destruction()
	await _nested()
	await _open("space")
	await _space()
	Forge.test_free_matter = false
	get_tree().quit()


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
	Forge.test_free_matter = true



func _camera(distance: float, side: float, pitch: float) -> void :
	_p.view.distance = distance
	_p.view.current_distance = distance
	_p.view_yaw = _p.yaw + side
	_p.head.rotation.x = pitch


func _structure_near(point: Vector3) -> Structure:
	var best: Structure = null
	for s: Structure in _game.arena.structures():
		if best == null or s.global_position.distance_to(point) < best.global_position.distance_to(point):
			best = s
	return best


func _face(target: Vector3) -> void :
	_p.look_at_point(target)



func _assembly() -> void :
	var spawn: = _game.arena.get_spawn(0)
	_p.place_at(spawn)
	await _seconds(0.5)
	var ground: = spawn.origin - spawn.basis.z * 4.5
	_face(ground)
	_camera(0.0, 0.0, _p.head.rotation.x)
	await _seconds(0.4)
	Forge.request(1, "quero uma torre que atira pombos explosivos", false)
	if Forge.has_draft(1):
		Forge.confirm_draft(1)
	_face(ground + Vector3.UP * 1.6)
	_camera(3.3, 1.25, 0.1)
	await _seconds(1.35)
	await _shot("1_a_frase_vira_arma.png")
	await _seconds(3.0)



func _destruction() -> void :
	var target: = _house
	var at: = target.global_position
	var away: = (_p.global_position - at)
	away.y = 0.0
	_p.place_at(Transform3D(Basis.IDENTITY, at + away.normalized() * 10.0 + Vector3.UP * 0.2))
	await _seconds(0.6)
	_p.hands.clear()
	Forge.request(1, "quero uma bazuca gigante", false)
	if Forge.has_draft(1):
		Forge.confirm_draft(1)
	await _seconds(4.5)
	_face(at + Vector3.UP * 1.5)
	_camera(3.0, 0.0, _p.head.rotation.x)
	await _seconds(0.4)
	var boom: = [false]
	Forge.explosion_at.connect( func(_a: Vector3, _r: float, _d: float) -> void : boom[0] = true, CONNECT_ONE_SHOT)
	_p.hands.use_pressed()
	await _frames(1)
	_p.hands.use_released()
	await _frames(2)

	_camera(3.4, 0.6, _p.head.rotation.x + 0.05)
	for i in 180:
		await get_tree().process_frame
		if boom[0]:
			break

	await _seconds(0.55)
	await _shot("2_tudo_se_quebra.png")
	await _seconds(2.0)



func _extraction() -> void :
	_p.hands.clear()
	_house = _largest_near(_p.global_position, 30.0)
	var target: = _house
	var point: = target.nearest_chunk_point(_p.global_position)
	var flat: = _p.global_position - point
	flat.y = 0.0
	_p.place_at(Transform3D(Basis.IDENTITY, Vector3(point.x, 0.0, point.z) + flat.normalized() * 2.4 + Vector3.UP * 0.1))
	await _seconds(0.5)
	_face(point + Vector3.UP * 0.6)
	_camera(2.0, 0.0, _p.head.rotation.x)
	_p.set_extracting(true)
	_p.hands.use_pressed()
	await _seconds(1.6)
	await _shot("3_nada_se_cria.png")
	_p.hands.use_released()
	_p.set_extracting(false)
	await _seconds(0.5)



func _nested() -> void :
	var spawn: = _game.arena.get_spawn(0)
	_p.place_at(spawn)
	await _seconds(0.5)
	_p.hands.clear()
	Forge.request(1, "quero tres pombos que orbitam", false)
	await _seconds(3.5)
	Forge.request(1, "quero uma pistola que atira um pombo que caga granadas", false)
	await _seconds(3.5)
	_face(_game.dummy.global_position + Vector3.UP * 4.0)
	_camera(3.0, 0.0, _p.head.rotation.x)
	for k in 3:
		_p.hands.use_pressed()
		await _frames(1)
		_p.hands.use_released()
		await _seconds(0.45)
	_camera(3.0, 0.65, _p.head.rotation.x)
	await _seconds(0.9)
	await _shot("4_qualquer_coisa_funciona.png")



func _space() -> void :
	_p.place_at(_game.arena.get_spawn(0))
	await _seconds(1.0)
	Forge.request(1, "quero uma minigun", false)
	await _seconds(3.5)
	var sun: = Vector3.ZERO
	_face(sun)
	_camera(2.4, 0.5, _p.head.rotation.x - 0.05)
	await _seconds(0.8)
	await _shot("5_sem_lado_certo.png")


func _largest_near(point: Vector3, radius: float) -> Structure:
	var best: Structure = null
	for s: Structure in _game.arena.structures():
		if s.global_position.distance_to(point) > radius:
			continue
		if best == null or s.alive_count() > best.alive_count():
			best = s
	return best if best != null else _structure_near(point)


func _shot(file: String) -> void :
	for node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if node is FpsOverlay:
			(node as CanvasLayer).visible = false
	await _frames(1)
	await RenderingServer.frame_post_draw
	var image: = get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT + file))
	print("[Fotos] ", file)


func _frames(n: int) -> void :
	for i in n:
		await get_tree().process_frame


func _seconds(s: float) -> void :
	await get_tree().create_timer(s).timeout
