class_name LobbyStage
extends SubViewportContainer

signal presentation_settled(mode: String)
const HATCH: = preload("res://scenes/menu/lobby_hatch.gd")
const ROBOT: = preload("res://scenes/menu/lobby_robot_display.gd")
const BOARD: = preload("res://scenes/menu/lobby_selection_board.gd")
const PODIUMS: = [Vector3(2.25, 0, 0.15), Vector3(-2.25, 0, 0.15), Vector3(3.85, 0, -0.55), Vector3(-3.85, 0, -0.55)]
const NEAR_PLACES: = [Vector3(1.22, 0, -1.0), Vector3(-1.22, 0, -1.0), Vector3(1.4, 0, -1.73), Vector3(-1.4, 0, -1.73)]
const WIDE_CAMERA: = Vector3(0, 2.55, -8.6)
const NEAR_CAMERA: = Vector3(0, 2.08, -4.43)
const ENTRANCE_TIME: = 1.6
const TRANSITION_S: = 2.15
const ARRIVAL_S: = 1.75
const ARRIVAL_RELEASE_S: = 0.3
var presentation: String = "waiting"
var weapon_loadouts: Array[String] = ["", "", "", ""]
var _presentation_seed: int = -1
var _viewport: SubViewport
var _world: Node3D
var _camera: Camera3D
var _board: Node3D
var _floor: MeshInstance3D
var _actors: Array[Dictionary] = []
var _occupied: Dictionary = {}
var _ready_players: Dictionary = {}
var _player_colors: Dictionary = {}
var _clock: float = 0.0
var _transition_age: float = TRANSITION_S
var _from_mode: String = "waiting"
var _desired_mode: String = "waiting"
var _moving: bool = false
var _rewinding: bool = false
var _rewind_from: float = 0.0
var _rewind_age: float = 0.0
var _rewind_duration: float = 0.0
var _rewind_mode: String = "arena"
var _camera_amount: float = 0.0
var _compact: bool = false
var _arrival_active: bool = false
var _arrival_age: float = ARRIVAL_S
var _arrival_view: = Vector4.ZERO
var _arrival_release_from: = Vector4.ZERO
var _arrival_release_age: float = ARRIVAL_RELEASE_S

func _ready() -> void :
	name = "LobbyStage"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	_viewport = SubViewport.new()
	_viewport.name = "StudioViewport"
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.handle_input_locally = false
	_viewport.gui_disable_input = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_viewport)
	_world = Node3D.new()
	_viewport.add_child(_world)
	var config: = RobotBody.config()
	_create_studio()
	var clips: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(String(config["clips_meta"])))
	var face_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(String(config["face_data"])))
	for slot in 4:
		var hatch: = HATCH.new()
		hatch.name = "Hatch_P%d" % (slot + 1)
		hatch.position = PODIUMS[slot]
		hatch.accent = Color("a7adb6")
		_world.add_child(hatch)
		var figures: Array[Node3D] = []
		for group: String in ["Podium", "Entourage"]:
			var figure: = ROBOT.new()
			figure.name = "%s_P%d" % [group, slot + 1]
			_world.add_child(figure)
			figure.setup(config, clips["clips"], face_data, slot)
			figures.append(figure)
		var mark: = Label3D.new()
		mark.text = "P%d" % (slot + 1)
		mark.font_size = 42
		mark.pixel_size = 0.004
		mark.modulate = Color("a7adb6")
		mark.position = PODIUMS[slot] + Vector3(0, 0.13, -0.72)
		mark.rotation.y = PI
		_world.add_child(mark)
		_actors.append({"podium": figures[0], "entourage": figures[1], "hatch": hatch, 
			"mark": mark, "phase": 0.0, "slot": slot})
	_board = BOARD.new()
	_board.position = Vector3(0, 1.62, 1.0)
	_world.add_child(_board)
	_apply_state()
	_apply_player_colors()
	_apply_weapon_loadouts()
	if _desired_mode != "waiting": _start_transition(_desired_mode)


func set_occupancy(_local_player_id: int, occupied: Dictionary) -> void :
	_occupied = occupied.duplicate()
	_apply_state()

func set_readiness(ready_players: Dictionary) -> void :
	_ready_players = ready_players.duplicate()
	_apply_state()


func play_arrival() -> void :
	_compact = false
	presentation = "waiting"
	_from_mode = "waiting"
	_desired_mode = "waiting"
	_moving = false
	_rewinding = false
	_transition_age = TRANSITION_S
	_arrival_age = 0.0
	_arrival_active = true
	_arrival_release_age = ARRIVAL_RELEASE_S
	_advance_arrival(0.0)
	for actor: Dictionary in _actors:
		actor["phase"] = 0.0
		_render_actor(actor, 0.0)
	if _camera != null: _update_camera_and_board()


func cancel_arrival() -> void :
	if not _arrival_active: return
	_arrival_active = false
	_arrival_release_from = _arrival_view
	_arrival_release_age = 0.0

func is_arriving() -> bool:
	return _arrival_active

func _advance_arrival(delta: float) -> void :
	if _arrival_active:
		_arrival_age = minf(_arrival_age + delta, ARRIVAL_S)
		var u: = _arrival_age / ARRIVAL_S
		var remaining: = 1.0 - smoothstep(0.0, 1.0, u)
		_arrival_view = Vector4(0.78 + sin(u * PI) * 0.1, 0.62, -1.15, 5.0) * remaining
		if _arrival_age >= ARRIVAL_S: _arrival_active = false
	elif _arrival_release_age < ARRIVAL_RELEASE_S:
		_arrival_release_age = minf(_arrival_release_age + delta, ARRIVAL_RELEASE_S)
		_arrival_view = _arrival_release_from * (1.0 - smoothstep(0.0, ARRIVAL_RELEASE_S, _arrival_release_age))
	else:
		_arrival_view = Vector4.ZERO


func set_player_colors(colors: Dictionary) -> void :
	_player_colors.clear()
	for player_id in range(1, 5):
		var rgb24: = int(colors.get(player_id, -1))
		_player_colors[player_id] = rgb24 if rgb24 >= 0 and rgb24 <= 16777215 else -1
	_apply_player_colors()
	_apply_state()

func _apply_player_colors() -> void :
	for i in _actors.size():
		var rgb24: = int(_player_colors.get(i + 1, -1))
		var actor: Dictionary = _actors[i]
		actor["podium"].set_color_rgb24(rgb24)
		actor["entourage"].set_color_rgb24(rgb24)
		var color: = RobotColor.from_rgb24(rgb24) if rgb24 >= 0 else Color("a7adb6")
		actor["hatch"].accent = color
		(actor["mark"] as Label3D).modulate = color.lightened(0.45) if color.get_luminance() < 0.15 else color


func set_player_paints(paints: Dictionary) -> void :
	for i in _actors.size():
		var bytes: PackedByteArray = paints.get(i + 1, PackedByteArray())
		var actor: Dictionary = _actors[i]
		if actor.get("paint_bytes", PackedByteArray()) == bytes and actor.has("paint_bytes"):
			continue
		actor["paint_bytes"] = bytes
		var canvas: RobotPaintCanvas = null
		var paint: RobotPaint = null
		if not bytes.is_empty():
			paint = RobotPaint.decode(bytes)
			canvas = RobotPaintCanvas.new()
			canvas.apply(paint)
		for figure: String in ["podium", "entourage"]:
			actor[figure].set_paint(canvas)
			actor[figure].set_stickers(paint)

func set_compact(compact: bool) -> void :
	if compact == _compact: return
	_compact = compact
	if compact:
		cancel_arrival()
		presentation = "waiting"
		_desired_mode = "waiting"
		_from_mode = "waiting"
		_moving = false
		_rewinding = false
		_transition_age = TRANSITION_S


func map_at(screen_point: Vector2) -> int:
	if _board == null or _camera == null or not _board.has_method("cell_at"):
		return -1
	var local: = get_global_transform_with_canvas().affine_inverse() * screen_point
	if size.x <= 0.0 or size.y <= 0.0:
		return -1
	var pixel: = local * Vector2(_viewport.size) / size
	return int(_board.call("cell_at", _camera, pixel))


func hover_map(index: int) -> void :
	if _board != null and _board.has_method("hover"): _board.call("hover", index)


func set_arena(title: String, texture_path: String = "") -> void :
	if _board != null: _board.set_arena(title, texture_path)



func set_presentation_seed(seed_value: int) -> void :
	var next: = maxi(seed_value, 0)
	if next == _presentation_seed: return
	_presentation_seed = next
	var selected: Array[String] = ["", "", "", ""]
	if next > 0:
		var pool: Array[String] = []
		for id: String in Lexicon.data.models:
			if Lexicon.data.is_weapon(id) and not (Lexicon.data.models[id].get("pieces", []) as Array).is_empty(): pool.append(id)
		pool.sort()
		var rng: = RandomNumberGenerator.new()
		rng.seed = next
		for i in mini(4, pool.size()):
			var choice: = rng.randi_range(0, pool.size() - 1)
			selected[i] = pool[choice]
			pool.remove_at(choice)
	set_weapon_loadouts(selected)

func set_weapon_loadouts(ids: Array[String]) -> void :
	for i in 4: weapon_loadouts[i] = ids[i] if i < ids.size() else ""
	_apply_weapon_loadouts()

func get_weapon_loadouts() -> Array[String]:
	return weapon_loadouts.duplicate()

func _apply_weapon_loadouts() -> void :
	for i in _actors.size():
		var near: Node3D = _actors[i]["entourage"]

		if not weapon_loadouts[i].is_empty() or not near.visible: near.set_weapon(weapon_loadouts[i])


func set_presentation(mode: String) -> void :
	var next: = "waiting" if mode == "characters" else mode
	if next not in ["waiting", "arena", "versus"]: next = "waiting"
	_desired_mode = next
	if _world == null: return
	if _moving:
		if next == "waiting" and presentation != "waiting":
			if _from_mode == "waiting":
				_rewind_mode = presentation
				_rewind_from = clampf(_transition_age, 0.0, TRANSITION_S)
				_rewind_age = 0.0
				_rewind_duration = clampf(_rewind_from, 0.18, TRANSITION_S)
				_rewinding = true
				presentation = "waiting"
			else:
				_start_transition("waiting")
		return
	if next == presentation: return
	_start_transition(next)

func get_slot_screen_position(player_id: int) -> Vector2:
	if _camera == null or player_id < 1 or player_id > 4: return Vector2.ZERO
	var i: = player_id - 1
	var point: Vector3 = PODIUMS[i] + Vector3(0, -0.14, -0.2)
	if presentation != "waiting": point = NEAR_PLACES[i] + Vector3(0, 1.88, 0)
	var screen: = _camera.unproject_position(point) * size / Vector2(_viewport.size)
	if presentation != "waiting":
		screen.y -= 140.0 if i < 2 else 88.0
	else:
		screen.y = minf(screen.y, 815.0)
	return screen

func _apply_state() -> void :
	if _board != null: _board.set_players(_occupied, _ready_players, _player_colors)

func _start_transition(mode: String) -> void :
	cancel_arrival()
	_from_mode = presentation
	presentation = mode
	_transition_age = 0.0
	_moving = true
	_rewinding = false

func _process(delta: float) -> void :
	if not is_visible_in_tree(): return
	_clock += delta
	if _rewinding:
		_rewind_age = minf(_rewind_age + delta, _rewind_duration)
		_transition_age = _rewind_from * (1.0 - smoothstep(0.0, _rewind_duration, _rewind_age))
	else:
		_transition_age += delta
	_advance_arrival(delta)
	_update_camera_and_board()
	for actor: Dictionary in _actors:
		var present: = bool(_occupied.get(int(actor["slot"]) + 1, false))
		actor["phase"] = move_toward(float(actor["phase"]), ENTRANCE_TIME if present else 0.0, delta)
		_render_actor(actor, delta)
	var finished: = _rewind_age >= _rewind_duration if _rewinding else _transition_age >= TRANSITION_S
	if _moving and finished:
		_moving = false
		_rewinding = false
		presentation_settled.emit(presentation)
		if _desired_mode != presentation: _start_transition(_desired_mode)

func _update_camera_and_board() -> void :
	var t: = _transition_age
	var angle: = 0.0 if presentation == "waiting" else - PI
	var anticipation: = 0.0
	_camera_amount = 0.0 if presentation == "waiting" else 1.0
	if _rewinding or (_moving and _from_mode == "waiting" and presentation != "waiting"):
		anticipation = sin(clampf(t / 0.11, 0, 1) * PI * 0.5) if t < 0.27 else 0.0
		angle = 0.28 * anticipation if t < 0.27 else lerpf(0.28, - PI, _spring(t - 0.27, 1.7, 0.58))
		_camera_amount = -0.12 * smoothstep(0.16, 0.28, t) if t < 0.28 else lerpf(-0.12, 1.0, _spring(t - 0.28, 1.5, 0.66))
	elif _moving and presentation == "waiting" and _from_mode != "waiting":
		anticipation = sin(clampf(t / 0.11, 0, 1) * PI * 0.5) if t < 0.93 else 0.0
		angle = - PI - 0.28 * anticipation if t < 0.93 else lerpf( - PI - 0.28, 0.0, _spring(t - 0.93, 1.7, 0.58))
		_camera_amount = 1.0 + 0.12 * smoothstep(0.82, 0.94, t) if t < 0.94 else lerpf(1.12, 0.0, _spring(t - 0.94, 1.5, 0.66))
	_camera.position = WIDE_CAMERA.lerp(NEAR_CAMERA, _camera_amount)
	var tilt: = lerpf(deg_to_rad(8.3), deg_to_rad(5.99), _camera_amount)
	var focus: = _camera.position + Vector3(0, - sin(tilt), cos(tilt)) * 9.5
	_camera.position += Vector3(_arrival_view.x, _arrival_view.y, _arrival_view.z)
	_camera.fov = 64.0 + _arrival_view.w
	_camera.look_at(focus)
	_board.pose(angle, anticipation)
	_board.set_phase(presentation)
	_board.visible = not _compact
	_floor.visible = not _compact
	if _compact:
		_camera.fov = 64.0
		_camera.position = Vector3(2.25, 1.55, -4.6)
		_camera.look_at(Vector3(2.25, 0.9, 0.15))

func _render_actor(actor: Dictionary, delta: float) -> void :
	var i: int = actor["slot"]
	var side: = 1.0 if i % 2 == 0 else -1.0
	var phase: = float(actor["phase"])
	var ready: = bool(_ready_players.get(i + 1, false))
	var podium: Node3D = actor["podium"]
	var near: Node3D = actor["entourage"]
	var hatch: Node3D = actor["hatch"]
	hatch.pose(phase, ready)
	hatch.visible = not _compact or i == 0
	(actor["mark"] as Node3D).visible = not _compact
	var base: Vector3 = PODIUMS[i]
	podium.position = base + Vector3(0, 0.03 + float(hatch.lift_offset), 0)
	podium.rotation = Vector3(0, side * (0.25 if i < 2 else 0.44), 0)
	var assembly: = clampf((phase - 0.65) / 0.95, 0, 1)
	podium.visible = assembly > 0.001 and ( not _compact or i == 0)
	near.visible = false
	var clip: = "Idle"
	var clip_time: = _clock + i * 1.71
	var t: = _transition_age
	var arriving: = _rewinding or (_moving and _from_mode == "waiting" and presentation != "waiting")
	var returning: = _moving and presentation == "waiting" and _from_mode != "waiting"
	if presentation != "waiting" or returning or _rewinding:
		podium.visible = false
		if arriving and t < 0.71:
			podium.visible = assembly > 0.001
			var direction: = Vector3(side * 0.7, 0, -1).normalized()
			if t < 0.07:
				clip = "Jump_Start"
				clip_time = t / 0.07 * 0.2
			elif t < 0.37:
				var u: = (t - 0.07) / 0.3
				podium.position += direction * u + Vector3.UP * sin(u * PI) * 0.45
				podium.rotation.y = - side * 0.61
				clip = "Jump_Rise"
				clip_time = u * 0.3
			else:
				var u: = (t - 0.37) / 0.34
				podium.position += direction + Vector3(side * 1.8 * u * u, absf(sin(u * TAU)) * 0.1, 0)
				podium.rotation.y = - side * PI * 0.5
				clip = "Jog_F"
				clip_time = u * 0.6
		elif returning and t >= 0.51:
			podium.visible = assembly > 0.001
			var u: = clampf((t - 0.51) / 0.26, 0, 1)
			podium.position += Vector3(side * 0.57, 0, -0.82) * (1.0 - u) + Vector3.UP * sin(u * PI) * 0.45
			clip = "Jump_Fall" if u < 1.0 else "Land_Light"
			clip_time = u * 0.2 if u < 1.0 else clampf(t - 0.77, 0, 0.5)
			if t > 1.3: clip = "Idle"
		var enter_u: = 1.0
		var exit_u: = 0.0
		if arriving: enter_u = clampf((t - 0.55 - i * 0.06) / 0.46, 0, 1)
		if returning: exit_u = clampf((t - i * 0.06) / 0.28, 0, 1)
		near.visible = assembly > 0.001 and enter_u > 0.0 and exit_u < 1.0
		near.position = NEAR_PLACES[i] + Vector3(side * 1.9 * ((1.0 - _back(enter_u)) + exit_u * exit_u), 0.03, 0)
		near.position.y += absf(sin(enter_u * TAU)) * 0.14 * (1.0 - enter_u) + absf(sin(exit_u * TAU)) * 0.12
		near.rotation = Vector3(0, side * (1.3 + sin(_clock * 0.9 + i) * 0.035), side * 0.12 * (1.0 - enter_u))
		var pose_mode: = _rewind_mode if _rewinding else presentation
		var near_clip: = "Jog_F" if enter_u < 0.92 or exit_u > 0.0 else ("Block" if pose_mode == "versus" else "Idle")
		near.animate(delta, _clock + i * 1.71, assembly, near_clip, "Determined" if pose_mode == "versus" else "Focused", 0.6 if near_clip == "Block" else 1.0, Vector2(side * 0.055, 0.005))
	if not near.visible and weapon_loadouts[i].is_empty(): near.set_weapon("")
	podium.animate(delta, clip_time, assembly, clip, "Happy" if ready else "Neutral")

func _create_studio() -> void :
	var world_environment: = WorldEnvironment.new()
	var env: = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c7c9cf")
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var studio_sky: = Sky.new()
	var studio_gradient: = ProceduralSkyMaterial.new()
	studio_gradient.sky_top_color = Color("29303e")
	studio_gradient.sky_horizon_color = Color("b1b9c6")
	studio_gradient.ground_bottom_color = Color("10141c")
	studio_gradient.ground_horizon_color = Color("b1b9c6")
	studio_sky.sky_material = studio_gradient
	env.sky = studio_sky
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = env
	_world.add_child(world_environment)
	for spec: Array in [[Vector3(-32, 155, 0), Color("fff1dc"), 1.4], [Vector3(-18, -28, 0), Color("b9c9e3"), 0.6]]:
		var light: = DirectionalLight3D.new()
		light.rotation_degrees = spec[0]
		light.light_color = spec[1]
		light.light_energy = spec[2]
		light.shadow_enabled = spec[2] > 1.0
		light.directional_shadow_max_distance = 18.0
		_world.add_child(light)
	var rim: = OmniLight3D.new()
	rim.position = Vector3(0, 3, 1.4)
	rim.light_color = Color("ff791c")
	rim.light_energy = 1.4
	rim.omni_range = 9.0
	_world.add_child(rim)
	_camera = Camera3D.new()
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.fov = 64.0
	_camera.near = 0.1
	_camera.far = 30.0
	_camera.current = true
	_world.add_child(_camera)
	_create_floor()

func _create_floor() -> void :


	var points: = PackedVector2Array()
	for i in 128:
		var angle: = TAU * i / 128.0
		points.append(Vector2(cos(angle) * 6.2, sin(angle) * 6.2 + 0.6))
	for site: Vector3 in PODIUMS:
		for i in 64:
			var angle: = TAU * i / 64.0
			points.append(Vector2(site.x, site.z) + Vector2(cos(angle), sin(angle)) * HATCH.RADIUS)
	var triangles: = Geometry2D.triangulate_delaunay(points)
	var vertices: = PackedVector3Array()
	var normals: = PackedVector3Array()
	for i in range(0, triangles.size(), 3):
		var center: = (points[triangles[i]] + points[triangles[i + 1]] + points[triangles[i + 2]]) / 3.0
		var in_hole: = false
		for site: Vector3 in PODIUMS:
			if center.distance_to(Vector2(site.x, site.z)) < HATCH.RADIUS: in_hole = true
		if in_hole: continue
		var face: = PackedInt32Array([triangles[i], triangles[i + 1], triangles[i + 2]])


		if (points[face[1]] - points[face[0]]).cross(points[face[2]] - points[face[0]]) < 0.0:
			var swap: = face[1]
			face[1] = face[2]
			face[2] = swap
		for corner in 3:
			var point: = points[face[corner]]
			vertices.append(Vector3(point.x, -0.12, point.y))
			normals.append(Vector3.UP)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh: = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_floor = MeshInstance3D.new()
	_floor.mesh = mesh
	var material: = StandardMaterial3D.new()
	material.albedo_color = Color("242930")
	material.metallic = 0.58
	material.roughness = 0.31
	material.cull_mode = BaseMaterial3D.CULL_BACK
	_floor.material_override = material
	_world.add_child(_floor)

static func _spring(time: float, frequency: float, damping: float) -> float:
	var omega: = TAU * frequency
	var damped: = omega * sqrt(1.0 - damping * damping)
	return 1.0 - exp( - damping * omega * time) * (cos(damped * time) + damping * omega / damped * sin(damped * time))

static func _back(u: float) -> float:
	return 1.0 + 2.70158 * pow(u - 1.0, 3.0) + 1.70158 * pow(u - 1.0, 2.0)
