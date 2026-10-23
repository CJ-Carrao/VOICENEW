class_name CustomizeMenu
extends Control





signal closed

const BUTTON = preload("res://scenes/menu/menu_chamfer_button.gd")
const COLOR_BUTTON = preload("res://scenes/menu/lobby_color_button.gd")
const ROBOT = preload("res://scenes/menu/lobby_robot_display.gd")
const SKIN = preload("res://scenes/ui/options_skin.gd")
const PAPER: = Vector2(1920, 1080)
const ACCENT: = Color("#f2601a")
const INK: = Color("#f5f1e8")
const MUTED: = Color("#aaa69f")
const VIEW: = Rect2(600, 150, 1300, 720)
const SAVE_DELAY_S: = 0.6

var is_open: = false
var tool: = "brush"
var color: = Color("#ff791c")
var radius: = 0.03
var hardness: = 0.7
var mirror: = false
var open_arms: = false


var sticker_id: = ""
var sticker_armed: = false
var selected_sticker: = -1
var sticker_size: = 0.14
var sticker_turn: = 0.0
var slots: PaintSlots

var slots_path: = PaintSlots.PATH
var paint: = RobotPaint.new()
var canvas: RobotPaintCanvas
var display: Node3D

var _cfg: Dictionary
var _canvas_root: Control
var _font: Font
var _bold: Font
var _scale: = 1.0
var _origin: = Vector2.ZERO
var _container: SubViewportContainer
var _viewport: SubViewport
var _camera: Camera3D
var _cursor: MeshInstance3D
var _cursor_material: StandardMaterial3D
var _yaw: = 0.0
var _pitch: = 0.12
var _distance: = 2.4
var _orbiting: = false
var _stroke: Dictionary = {}
var _applied: = 0
var _undo: Array = []
var _redo: Array = []
var _save_left: = -1.0
var _tool_buttons: Dictionary = {}
var _slot_buttons: Array[Button] = []
var _color_buttons: Array[Button] = []
var _custom_color: ColorPickerButton
var _name_field: LineEdit
var _preview: OptionButton
var _size_slider: HSlider
var _hard_slider: HSlider
var _ink: Label
var _notice: Label
var _notice_left: = 0.0
var _ui_sound: AudioStreamPlayer
var _faces: Dictionary = {}
var _palette_nodes: Array[Control] = []
var _drawer: Control
var _drawer_button: Button
var _sticker_buttons: Dictionary = {}
var _sticker_count: Label
var _placed_buttons: Array[Button] = []
var _delete_button: Button
var _mirror_check: CheckButton
var _hint: Label
var _outline: MeshInstance3D
var _outline_mesh: ImmediateMesh
var _dragging: = false
var _drag_moved: = false
var _drag_mirrored: = false
var _drag_before: Dictionary = {}
var _slider_before: Dictionary = {}
var _base_up: = Vector3.UP
var _size_label: Label
var _hard_label: Label


func _ready() -> void :
	name = "CustomizeMenu"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_cfg = RobotPaint.config()
	var intro: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/intro.json"))
	var source_font: = load(str(intro.font)) as Font
	_font = MainMenu._variation(source_font, 500, 0)
	_bold = MainMenu._variation(source_font, 800, 0)
	radius = float(_cfg.get("radius_default_m", 0.03))
	hardness = float(_cfg.get("hardness_default", 0.7))
	sticker_size = float(_cfg.get("sticker_size_default_m", 0.14))
	var cam: Dictionary = _cfg.get("camera", {})
	_distance = float(cam.get("distance_m", 2.4))
	_canvas_root = Control.new()
	_canvas_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas_root.size = PAPER
	_canvas_root.theme = SKIN.create_theme(_font)
	add_child(_canvas_root)
	_build_studio()
	_build_panel(intro)
	_build_slots()
	_ui_sound = AudioStreamPlayer.new()
	_ui_sound.bus = AudioMix.bus(AudioMix.INTERFACE)
	_ui_sound.volume_db = -22.0
	add_child(_ui_sound)
	resized.connect(_fit)
	_fit()
	visible = false
	set_process(false)
	set_process_unhandled_input(false)


func open() -> void :
	is_open = true
	visible = true
	set_process(true)
	set_process_unhandled_input(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if canvas == null:
		canvas = RobotPaintCanvas.new()
		(display as Object).call("set_paint", canvas)
	slots = PaintSlots.load_from(slots_path)
	_select_slot(slots.selected, false)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)


func close() -> void :
	if not is_open:
		return
	_finish_stroke()
	_save_now()
	is_open = false
	set_process(false)
	set_process_unhandled_input(false)
	var tween: = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.16)
	tween.tween_callback( func() -> void :
		visible = false
		closed.emit())




func _build_studio() -> void :
	_container = SubViewportContainer.new()
	_container.name = "PaintView"
	_container.position = VIEW.position
	_container.size = VIEW.size
	_container.stretch = true
	_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_container.gui_input.connect(_on_view_input)
	_canvas_root.add_child(_container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.gui_disable_input = true
	_container.add_child(_viewport)
	var world: = Node3D.new()
	_viewport.add_child(world)
	var env: = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c7c9cf")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment: = WorldEnvironment.new()
	world_environment.environment = env
	world.add_child(world_environment)
	for spec: Array in [[Vector3(-32, 155, 0), Color("fff1dc"), 1.35], [Vector3(-18, -28, 0), Color("b9c9e3"), 0.65], [Vector3(-10, 20, 0), Color("d8dde6"), 0.35]]:
		var light: = DirectionalLight3D.new()
		light.rotation_degrees = spec[0]
		light.light_color = spec[1]
		light.light_energy = spec[2]
		light.shadow_enabled = spec[2] > 1.0
		world.add_child(light)
	var rim: = OmniLight3D.new()
	rim.position = Vector3(0, 2.6, 1.3)
	rim.light_color = Color("ff791c")
	rim.light_energy = 1.1
	rim.omni_range = 7.0
	world.add_child(rim)
	var floor_mesh: = CylinderMesh.new()
	floor_mesh.top_radius = 1.25
	floor_mesh.bottom_radius = 1.3
	floor_mesh.height = 0.06
	var floor_material: = StandardMaterial3D.new()
	floor_material.albedo_color = Color("2a2a2e")
	floor_material.roughness = 0.6
	floor_mesh.material = floor_material
	var floor_disc: = MeshInstance3D.new()
	floor_disc.mesh = floor_mesh
	floor_disc.position.y = -0.03
	world.add_child(floor_disc)
	var config: = RobotBody.config()
	var clips: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(String(config["clips_meta"])))
	var face_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(String(config["face_data"])))
	display = ROBOT.new()
	display.name = "PaintRobot"
	world.add_child(display)
	display.call("setup", config, clips["clips"], face_data, 0)
	display.call("set_weapon", "")
	_cursor_material = StandardMaterial3D.new()
	_cursor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cursor_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cursor_material.no_depth_test = true
	var sphere: = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	sphere.material = _cursor_material
	_cursor = MeshInstance3D.new()
	_cursor.mesh = sphere
	_cursor.visible = false
	world.add_child(_cursor)
	_outline_mesh = ImmediateMesh.new()
	var outline_material: = StandardMaterial3D.new()
	outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline_material.no_depth_test = true
	outline_material.albedo_color = ACCENT
	_outline = MeshInstance3D.new()
	_outline.mesh = _outline_mesh
	_outline.material_override = outline_material
	world.add_child(_outline)
	_camera = Camera3D.new()
	_camera.fov = 40.0
	_camera.near = 0.05
	_camera.far = 20.0
	_camera.current = true
	world.add_child(_camera)
	_place_camera()


func _place_camera() -> void :
	var cam: Dictionary = _cfg.get("camera", {})
	var target: = Vector3(0, float(cam.get("height_m", 1.0)), 0)
	var offset: = Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), - cos(_yaw) * cos(_pitch)) * _distance
	_camera.position = target + offset
	_camera.look_at(target)


func _process(delta: float) -> void :
	if open_arms:
		display.call("show_rest")
	else:
		display.call("animate", delta, 0.0, 1.0, "Idle")
	if _save_left > 0.0:
		_save_left -= delta
		if _save_left <= 0.0:
			_save_now()
	if _notice_left > 0.0:
		_notice_left -= delta
		_notice.modulate.a = clampf(_notice_left * 3.0, 0.0, 1.0)
	if canvas != null:
		canvas.commit()
	_draw_outline()




func _on_view_input(event: InputEvent) -> void :
	var button: = event as InputEventMouseButton
	if button != null:
		if button.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = button.pressed
		elif button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_zoom(1.0 / float(_cfg.camera.get("zoom_step", 0.88)))
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_zoom(float(_cfg.camera.get("zoom_step", 0.88)))
		elif button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_begin_stroke(button.position)
			else:
				_finish_stroke()
		accept_event()
		return
	var motion: = event as InputEventMouseMotion
	if motion == null:
		return
	if _orbiting:
		var speed: = deg_to_rad(float(_cfg.camera.get("orbit_deg_per_px", 0.35)))
		_yaw -= motion.relative.x * speed
		_pitch = clampf(_pitch + motion.relative.y * speed, -0.5, 1.1)
		_place_camera()
	var hit: = pick(motion.position)
	_show_cursor(hit)
	if _dragging and not hit.is_empty() and RobotPaint.is_paintable(String(hit["part"])):
		_drag_sticker(hit)
	if not _stroke.is_empty() and not hit.is_empty() and _stroke.tool in ["brush", "erase"]:
		_extend_stroke(hit)
	accept_event()


func _zoom(factor: float) -> void :
	var cam: Dictionary = _cfg.get("camera", {})
	_distance = clampf(_distance * factor, float(cam.get("min_m", 0.9)), float(cam.get("max_m", 3.6)))
	_place_camera()



func pick(view_position: Vector2) -> Dictionary:
	var origin: = _camera.project_ray_origin(view_position)
	var direction: = _camera.project_ray_normal(view_position)
	var best: = {}
	var best_distance: = INF
	for part: Dictionary in display.get("parts"):
		var shape: = part["shape"] as MeshInstance3D
		if not shape.is_visible_in_tree():
			continue
		var xf: = shape.global_transform
		var inverse: = xf.affine_inverse()
		var local_origin: = inverse * origin
		var local_direction: = inverse.basis * direction
		var faces: = _faces_of(shape.mesh)
		for i in range(0, faces.size(), 3):
			var hit: Variant = Geometry3D.ray_intersects_triangle(local_origin, local_direction, faces[i], faces[i + 1], faces[i + 2])
			if hit == null:
				continue
			var world: Vector3 = xf * (hit as Vector3)
			var distance: = origin.distance_to(world)
			if distance < best_distance:
				best_distance = distance
				var normal: = (faces[i + 1] - faces[i]).cross(faces[i + 2] - faces[i]).normalized()
				if normal.dot(local_direction) > 0.0:
					normal = - normal
				best = {"part": String(part["name"]), "local": hit, "world": world, "normal": normal, 
					"up": (inverse.basis * _camera.global_basis.y).normalized()}
	return best


func _faces_of(mesh: Mesh) -> PackedVector3Array:
	if not _faces.has(mesh):
		_faces[mesh] = mesh.get_faces()
	return _faces[mesh]


func _show_cursor(hit: Dictionary) -> void :
	_cursor.visible = not hit.is_empty() and RobotPaint.is_paintable(String(hit.get("part", "")))\
	and (tool != "sticker" or sticker_armed)
	if not _cursor.visible:
		return
	_cursor.global_position = hit["world"]
	var size: = radius if tool in ["brush", "erase"] else (sticker_size * 0.5 if tool == "sticker" else 0.015)
	_cursor.scale = Vector3.ONE * size
	var tint: = Color("#ffffff") if tool == "erase" else color
	_cursor_material.albedo_color = Color(tint, 0.35)


func _begin_stroke(view_position: Vector2) -> void :
	_finish_stroke()
	var hit: = pick(view_position)
	if tool == "sticker":
		_sticker_press(hit)
		return
	if hit.is_empty() or not RobotPaint.is_paintable(String(hit["part"])):
		return
	var rgb: = RobotColor.to_rgb24(color)
	if tool == "fill":
		var stroke: = RobotPaint.fill(String(hit["part"]), rgb, mirror)
		_commit_stroke(stroke)
		return
	_stroke = RobotPaint.brush(tool, rgb, radius, hardness, mirror)
	_applied = 0
	_extend_stroke(hit)


func _extend_stroke(hit: Dictionary) -> void :
	if not RobotPaint.is_paintable(String(hit["part"])):
		return
	var points: = (_stroke["p"] as PackedInt32Array).size() / 3
	if points > 0:
		var last: = RobotPaint.point(_stroke, points - 1)
		if last.distance_to(hit["local"]) < radius * float(_cfg.get("point_spacing", 0.35)):
			return
	if points >= int(_cfg.get("max_stroke_points", 600)):
		var kept: = _stroke.duplicate(true)
		_finish_stroke()
		_stroke = RobotPaint.brush(String(kept["tool"]), int(kept["color"]), float(kept["r"]) / 1000.0, float(kept["h"]) / 100.0, bool(kept["mirror"]))
		_applied = 0
	RobotPaint.append_point(_stroke, hit["local"])
	canvas.apply_stroke(_stroke, _applied)
	_applied = (_stroke["p"] as PackedInt32Array).size() / 3


func _finish_stroke() -> void :
	if _dragging:
		_dragging = false
		if _drag_moved:
			_push_undo(_drag_before)
			_changed()
	if _stroke.is_empty():
		return
	var stroke: = _stroke
	_stroke = {}
	_commit_stroke(stroke, true)



func _commit_stroke(stroke: Dictionary, already_drawn: bool = false) -> void :
	var before: = _snapshot()
	if not paint.add(stroke):
		if already_drawn:
			canvas.apply(paint)
		_notify("LIMITE DE TINTA: APAGUE OU LIMPE PARA CONTINUAR")
		return
	if not already_drawn:
		canvas.apply_stroke(stroke)
	_push_undo(before)
	_changed()




func _sticker_press(hit: Dictionary) -> void :
	var on: = [] if hit.is_empty() else StickerDecals.hit(paint, hit["local"])
	if not on.is_empty():
		select_sticker(int(on[0]))
		_dragging = true
		_drag_moved = false
		_drag_mirrored = bool(on[1])
		_drag_before = _snapshot()
		return
	if sticker_armed and not hit.is_empty() and RobotPaint.is_paintable(String(hit["part"])):
		_place_sticker(hit)
		return
	select_sticker(-1)



func _place_sticker(hit: Dictionary) -> void :
	var normal: Vector3 = hit["normal"]
	var up: Vector3 = hit["up"]
	up = (up - normal * up.dot(normal))
	if up.length() < 0.1:
		up = Vector3.UP - normal * normal.y
	up = up.normalized().rotated(normal, deg_to_rad( - sticker_turn))
	var before: = _snapshot()
	if not paint.add_sticker(RobotPaint.sticker(sticker_id, hit["local"], normal, up, sticker_size, mirror)):
		_notify("NO MÁXIMO %d FIGURINHAS: APAGUE UMA PARA COLAR OUTRA" % int(_cfg.get("max_stickers", 5)))
		return
	_push_undo(before)
	_arm("")
	_changed()
	select_sticker(paint.stickers.size() - 1)



func _drag_sticker(hit: Dictionary) -> void :
	if selected_sticker < 0 or selected_sticker >= paint.stickers.size():
		return
	var flip: = Vector3(-1, 1, 1) if _drag_mirrored else Vector3.ONE
	var current: = paint.stickers[selected_sticker]
	var normal: Vector3 = (hit["normal"] as Vector3) * flip
	var up: = RobotPaint.vec(current["u"])
	up = up - normal * up.dot(normal)
	if up.length() < 0.1:
		up = Vector3.UP - normal * normal.y
	_base_up = up.normalized().rotated(normal, deg_to_rad(sticker_turn))
	_replace_selected(RobotPaint.sticker(String(current["id"]), (hit["local"] as Vector3) * flip, normal, up, 
		float(current["s"]) / 1000.0, bool(current["mirror"])))
	_drag_moved = true



func _adjust_selected() -> void :
	if selected_sticker < 0 or selected_sticker >= paint.stickers.size():
		return
	var current: = paint.stickers[selected_sticker]
	var normal: = RobotPaint.vec(current["n"]).normalized()
	var up: = _base_up.rotated(normal, deg_to_rad( - sticker_turn))
	_replace_selected(RobotPaint.sticker(String(current["id"]), RobotPaint.vec(current["c"]), normal, up, sticker_size, mirror))


func _replace_selected(sticker: Dictionary) -> void :
	if not RobotPaint.valid_sticker(sticker):
		return
	paint.stickers[selected_sticker] = sticker
	display.call("set_stickers", paint)


func select_sticker(index: int) -> void :
	selected_sticker = index if index >= 0 and index < paint.stickers.size() else -1
	if selected_sticker >= 0:
		var current: = paint.stickers[selected_sticker]
		var normal: = RobotPaint.vec(current["n"]).normalized()
		var up: = RobotPaint.vec(current["u"])
		_base_up = (up - normal * up.dot(normal)).normalized()
		sticker_turn = 0.0
		sticker_size = float(current["s"]) / 1000.0
		mirror = bool(current["mirror"])
		_mirror_check.set_pressed_no_signal(mirror)
		_arm("")
	if tool == "sticker":
		_size_slider.set_value_no_signal(sticker_size)
		_hard_slider.set_value_no_signal(sticker_turn)
	_refresh_stickers()


func delete_sticker() -> void :
	_finish_stroke()
	if selected_sticker < 0 or selected_sticker >= paint.stickers.size():
		return
	var before: = _snapshot()
	paint.stickers.remove_at(selected_sticker)
	selected_sticker = -1
	_push_undo(before)
	_changed()



func _arm(id: String) -> void :
	sticker_id = id if not id.is_empty() else sticker_id
	sticker_armed = not id.is_empty()
	for key: String in _sticker_buttons:
		(_sticker_buttons[key] as Button).set_pressed_no_signal(sticker_armed and key == id)
	if sticker_armed:
		selected_sticker = -1
		sticker_turn = 0.0
		_hard_slider.set_value_no_signal(0.0)
		_notify("CLIQUE NO ROBÔ PARA COLAR")
		_refresh_stickers()


func _draw_outline() -> void :
	_outline_mesh.clear_surfaces()
	if tool != "sticker" or selected_sticker < 0 or selected_sticker >= paint.stickers.size():
		return
	var shapes: = {}
	for part: Dictionary in display.get("parts"):
		shapes[String(part["name"])] = part["shape"]
	_outline_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for frame in StickerDecals.frames(paint.stickers[selected_sticker]):
		var shape: = shapes.get(frame["part"]) as Node3D
		if shape == null:
			continue
		var half: Vector2 = frame["half"]
		var lift: Vector3 = (frame["normal"] as Vector3) * 0.004
		var corners: Array[Vector3] = []
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var local: Vector3 = frame["center"] + (frame["right"] as Vector3) * corner.x * half.x + (frame["up"] as Vector3) * corner.y * half.y + lift
			corners.append(shape.global_transform * local)
		for i in 4:
			_outline_mesh.surface_add_vertex(corners[i])
			_outline_mesh.surface_add_vertex(corners[(i + 1) % 4])
	_outline_mesh.surface_end()


func _snapshot() -> Dictionary:
	return {"s": paint.to_data(), "k": paint.stickers_data()}


func _push_undo(before: Dictionary) -> void :
	_undo.append(before)
	while _undo.size() > int(_cfg.get("undo_steps", 60)):
		_undo.pop_front()
	_redo.clear()


func undo() -> void :
	_finish_stroke()
	if _undo.is_empty():
		return
	_redo.append(_snapshot())
	_restore(_undo.pop_back())


func redo() -> void :
	_finish_stroke()
	if _redo.is_empty():
		return
	_undo.append(_snapshot())
	_restore(_redo.pop_back())


func clear_paint() -> void :
	_finish_stroke()
	if paint.is_empty():
		return
	_push_undo(_snapshot())
	_restore({"s": [], "k": []})


func _restore(data: Dictionary) -> void :
	selected_sticker = -1
	paint = RobotPaint.from_data(data["s"], data["k"])
	canvas.apply(paint)
	_changed()


func _changed() -> void :
	if slots != null:
		slots.paints[slots.selected] = paint
	_save_left = SAVE_DELAY_S
	_refresh_ink()
	_refresh_stickers()
	display.call("set_stickers", paint)


func _save_now() -> void :
	_save_left = -1.0
	if slots != null and not slots.save():
		_notify("NÃO FOI POSSÍVEL SALVAR")




func _build_panel(intro: Dictionary) -> void :
	var chrome: = Control.new()
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chrome.size = PAPER
	_canvas_root.add_child(chrome)
	_canvas_root.move_child(chrome, 0)
	chrome.draw.connect(_draw_panel.bind(chrome))
	var logo_path: = str(intro.get("lavoice", {}).get("logo", ""))
	if not logo_path.is_empty() and ResourceLoader.exists(logo_path):
		var logo: = TextureRect.new()
		logo.texture = load(logo_path)
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.position = Vector2(78, 60)
		logo.size = Vector2(390, 78)
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas_root.add_child(logo)
	_label("PERSONALIZAÇÃO / LATARIA", Rect2(80, 168, 480, 30), 18, ACCENT, true)
	_label("PINTURA", Rect2(76, 196, 490, 70), 52, INK, true)
	_label("Idealizado por SOMYST", Rect2(760, 85, 1090, 30), 20, MUTED, true, HORIZONTAL_ALIGNMENT_RIGHT)
	_label("PINTURA LIVRE / %d SLOTS" % PaintSlots.count(), Rect2(1380, 115, 470, 34), 24, INK, true, HORIZONTAL_ALIGNMENT_RIGHT)
	_label("FERRAMENTA", Rect2(80, 288, 300, 26), 17, MUTED, true)
	for spec: Array in [["brush", "PINCEL", 80, 145], ["erase", "BORRACHA", 233, 167], ["fill", "BALDE", 408, 132]]:
		var tool_id: = String(spec[0])
		_tool_buttons[tool_id] = _button(String(spec[1]), Rect2(spec[2], 318, spec[3], 54), func() -> void : _set_tool(tool_id), false, 17)
	_size_label = _label("TAMANHO", Rect2(80, 392, 300, 26), 17, MUTED, true)
	_size_slider = _slider(Rect2(80, 420, 460, 30), float(_cfg.get("radius_min_m", 0.006)), float(_cfg.get("radius_max_m", 0.12)), radius)
	_size_slider.value_changed.connect( func(value: float) -> void :
		if tool != "sticker":
			radius = value
			return
		sticker_size = value
		_slider_step())
	_hard_label = _label("DUREZA", Rect2(80, 460, 300, 26), 17, MUTED, true)
	_hard_slider = _slider(Rect2(80, 488, 460, 30), 0.0, 1.0, hardness)
	_hard_slider.value_changed.connect( func(value: float) -> void :
		if tool != "sticker":
			hardness = value
			return
		sticker_turn = value
		_slider_step())
	for slider: HSlider in [_size_slider, _hard_slider]:
		slider.drag_started.connect( func() -> void : _slider_before = _snapshot())
		slider.drag_ended.connect( func(changed: bool) -> void :
			if changed and not _slider_before.is_empty() and _slider_before != _snapshot():
				_push_undo(_slider_before)
				_changed()
			_slider_before = {})
	_mirror_check = _toggle("ESPELHAR", Rect2(72, 534, 200, 44), func(on: bool) -> void :
		mirror = on
		if tool == "sticker" and selected_sticker >= 0:
			var before: = _snapshot()
			_adjust_selected()
			_push_undo(before)
			_changed())
	_toggle("BRAÇOS ABERTOS", Rect2(282, 534, 266, 44), func(on: bool) -> void : open_arms = on)
	_palette_nodes.append(_label("COR", Rect2(80, 594, 200, 26), 17, MUTED, true))
	var config: = RobotBody.config()
	var palette: Array = config["player_colors"]
	var names: Array = config["player_color_names"]
	for index in palette.size():
		var swatch: = COLOR_BUTTON.new() as Button
		swatch.position = Vector2(80 + (index % 8) * 58.0, 624 + (index / 8) * 56.0)
		swatch.size = Vector2(52, 50)
		swatch.set("swatch", Color(String(palette[index])))
		swatch.set("color_name", String(names[index]))
		swatch.set("ui_font", _bold)
		swatch.set("compact", true)
		_canvas_root.add_child(swatch)
		_palette_nodes.append(swatch)
		var value: = Color(String(palette[index]))
		swatch.pressed.connect( func() -> void : _set_color(value))
		swatch.mouse_entered.connect(swatch.queue_redraw)
		swatch.mouse_exited.connect(swatch.queue_redraw)
		_color_buttons.append(swatch)
	_palette_nodes.append(_label("OUTRA COR", Rect2(80, 754, 150, 26), 17, MUTED, true))
	_custom_color = ColorPickerButton.new()
	_custom_color.position = Vector2(220, 742)
	_custom_color.size = Vector2(320, 48)
	_custom_color.edit_alpha = false
	_custom_color.color = color
	_custom_color.color_changed.connect( func(value: Color) -> void : _set_color(value, false))
	_canvas_root.add_child(_custom_color)
	_palette_nodes.append(_custom_color)
	_build_sticker_drawer()
	_drawer_button = _button("FIGURINHAS", Rect2(80, 878, 460, 54), toggle_stickers, false, 18)
	_button("DESFAZER", Rect2(80, 812, 168, 52), undo, false, 16)
	_button("REFAZER", Rect2(256, 812, 152, 52), redo, false, 16)
	_button("LIMPAR", Rect2(416, 812, 124, 52), clear_paint, false, 16)
	_button("VOLTAR", Rect2(80, 976, 210, 58), close, false, 22)
	_hint = _label("", Rect2(620, 878, 1260, 26), 16, MUTED, false, HORIZONTAL_ALIGNMENT_RIGHT)
	_notice = _label("", Rect2(620, 160, 1260, 30), 20, ACCENT, true, HORIZONTAL_ALIGNMENT_CENTER)
	_notice.modulate.a = 0.0
	_set_tool("brush")
	_set_color(color)




func _build_sticker_drawer() -> void :
	_drawer = Control.new()
	_drawer.position = Vector2(80, 594)
	_drawer.size = Vector2(460, 210)
	_drawer.visible = false
	_canvas_root.add_child(_drawer)
	_drawer.add_child(_small_label("FIGURINHAS DO JOGO", Vector2(0, 0), MUTED))
	var scroll: = ScrollContainer.new()
	scroll.position = Vector2(0, 26)
	scroll.size = Vector2(460, 92)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_drawer.add_child(scroll)
	var grid: = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	var ids: = StickerCatalog.ids()
	for id: String in ids:
		var item: = Button.new()
		item.custom_minimum_size = Vector2(84, 84)
		item.icon = StickerCatalog.texture(id)
		item.expand_icon = true
		item.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.toggle_mode = true
		item.tooltip_text = id
		item.pressed.connect( func() -> void :
			_sound(true)
			_arm(id))
		grid.add_child(item)
		_sticker_buttons[id] = item
	if ids.is_empty():
		var empty: = Label.new()
		empty.text = "Pasta assets/stickers vazia."
		empty.add_theme_color_override("font_color", MUTED)
		grid.add_child(empty)
	_sticker_count = _small_label("", Vector2(0, 124), MUTED)
	_drawer.add_child(_sticker_count)
	for i in int(_cfg.get("max_stickers", 5)):
		var index: = i
		var placed: = Button.new()
		placed.position = Vector2(i * 58, 150)
		placed.size = Vector2(52, 52)
		placed.expand_icon = true
		placed.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placed.toggle_mode = true
		placed.pressed.connect( func() -> void :
			_sound(true)
			select_sticker(index))
		_drawer.add_child(placed)
		_placed_buttons.append(placed)
	_delete_button = BUTTON.new() as Button
	_delete_button.text = "APAGAR"
	_delete_button.position = Vector2(296, 150)
	_delete_button.size = Vector2(164, 52)
	_delete_button.set("ui_font", _bold)
	_delete_button.set("text_size", 16)
	_delete_button.pressed.connect( func() -> void :
		_sound(true)
		delete_sticker())
	_drawer.add_child(_delete_button)


func _small_label(value: String, at: Vector2, ink: Color) -> Label:
	var label: = Label.new()
	label.text = value
	label.position = at
	label.add_theme_font_override("font", _bold)
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", ink)
	return label


func toggle_stickers() -> void :
	var open: = not _drawer.visible
	_drawer.visible = open
	for node: Control in _palette_nodes: node.visible = not open
	_drawer_button.set("primary", open)
	_drawer_button.queue_redraw()
	if open:
		_set_tool("sticker")
		if paint.stickers.is_empty(): _notify("ESCOLHA UMA FIGURINHA E CLIQUE NO ROBÔ")
	else:
		_arm("")
		selected_sticker = -1
		if tool == "sticker": _set_tool("brush")
	_refresh_stickers()


func _refresh_stickers() -> void :
	if _sticker_count == null:
		return
	var limit: = int(_cfg.get("max_stickers", 5))
	_sticker_count.text = "COLADAS %d / %d%s" % [paint.stickers.size(), limit, "   ·   CLIQUE PARA ESCOLHER" if not paint.stickers.is_empty() else ""]
	for i in _placed_buttons.size():
		var button: = _placed_buttons[i]
		var exists: = i < paint.stickers.size()
		button.disabled = not exists
		button.icon = StickerCatalog.texture(String(paint.stickers[i]["id"])) if exists else null
		button.tooltip_text = String(paint.stickers[i]["id"]) if exists else ""
		button.set_pressed_no_signal(exists and i == selected_sticker)
	_delete_button.disabled = selected_sticker < 0


func _build_slots() -> void :
	_label("SLOTS", Rect2(640, 920, 120, 26), 17, MUTED, true)
	for i in PaintSlots.count():
		var index: = i
		var slot: = _button("%d" % (i + 1), Rect2(640 + i * 96, 948, 86, 56), func() -> void : _select_slot(index), false, 22)
		_slot_buttons.append(slot)
	_label("NOME", Rect2(1130, 920, 120, 26), 17, MUTED, true)
	_name_field = LineEdit.new()
	_name_field.position = Vector2(1130, 952)
	_name_field.size = Vector2(320, 50)
	_name_field.max_length = int(_cfg.get("slot_name_max", 18))
	_name_field.text_changed.connect( func(value: String) -> void :
		if slots == null: return
		slots.names[slots.selected] = PaintSlots.clean_name(value, slots.selected)
		_refresh_slots()
		_save_left = SAVE_DELAY_S)
	_canvas_root.add_child(_name_field)
	_label("PRÉVIA DA COR DO LOBBY", Rect2(1470, 920, 300, 26), 17, MUTED, true)
	_preview = OptionButton.new()
	_preview.position = Vector2(1470, 952)
	_preview.size = Vector2(250, 50)
	_preview.add_item("SEM COR")
	var config: = RobotBody.config()
	for color_name: String in config["player_color_names"]:
		_preview.add_item(color_name)
	_preview.item_selected.connect( func(index: int) -> void :
		var rgb: = -1 if index == 0 else RobotColor.to_rgb24(Color(String(config["player_colors"][index - 1])))
		display.call("set_color_rgb24", rgb))
	_canvas_root.add_child(_preview)
	_ink = _label("", Rect2(1730, 962, 150, 30), 18, INK, true, HORIZONTAL_ALIGNMENT_RIGHT)


func _select_slot(index: int, save_first: bool = true) -> void :
	_finish_stroke()
	if save_first:
		_save_now()
	slots.selected = clampi(index, 0, PaintSlots.count() - 1)
	paint = slots.paints[slots.selected]
	selected_sticker = -1
	_undo.clear()
	_redo.clear()
	canvas.apply(paint)
	display.call("set_stickers", paint)
	_name_field.text = slots.names[slots.selected]
	_refresh_slots()
	_refresh_ink()
	_refresh_stickers()
	if save_first:
		_save_left = SAVE_DELAY_S


func _refresh_slots() -> void :
	for i in _slot_buttons.size():
		_slot_buttons[i].set("primary", slots != null and i == slots.selected)
		_slot_buttons[i].tooltip_text = slots.names[i] if slots != null else ""
		_slot_buttons[i].queue_redraw()


func _refresh_ink() -> void :
	_ink.text = "TINTA %d%%" % roundi(100.0 * paint.point_count() / maxf(float(_cfg.get("max_points", 8000)), 1.0))



func _slider_step() -> void :
	if selected_sticker < 0:
		return
	var before: = _snapshot()
	_adjust_selected()
	if _slider_before.is_empty():
		_push_undo(before)
		_changed()


func _set_tool(value: String) -> void :
	tool = value
	if _hint != null:
		_hint.text = ("ESQUERDO COLA, ESCOLHE E ARRASTA   DIREITO GIRA   RODA APROXIMA   DEL APAGA   ESC SOLTA" if value == "sticker"
			else "ESQUERDO PINTA   DIREITO GIRA   RODA APROXIMA   CTRL+Z DESFAZ   ESC VOLTA")
	for id: String in _tool_buttons:
		(_tool_buttons[id] as Button).set("primary", id == value)
		(_tool_buttons[id] as Button).queue_redraw()
	if _drawer != null and value != "sticker" and _drawer.visible:
		toggle_stickers()

	var sticking: = value == "sticker"
	_size_label.text = "TAMANHO DA FIGURINHA" if sticking else "TAMANHO"
	_hard_label.text = "GIRO" if sticking else "DUREZA"
	_size_slider.min_value = float(_cfg.get("sticker_size_min_m", 0.04)) if sticking else float(_cfg.get("radius_min_m", 0.006))
	_size_slider.max_value = float(_cfg.get("sticker_size_max_m", 0.4)) if sticking else float(_cfg.get("radius_max_m", 0.12))
	_size_slider.step = (_size_slider.max_value - _size_slider.min_value) / 100.0
	_size_slider.set_value_no_signal(sticker_size if sticking else radius)
	_hard_slider.min_value = -180.0 if sticking else 0.0
	_hard_slider.max_value = 180.0 if sticking else 1.0
	_hard_slider.step = 1.0 if sticking else 0.01
	_hard_slider.set_value_no_signal(sticker_turn if sticking else hardness)


func _set_color(value: Color, sync_picker: bool = true) -> void :
	color = Color(value, 1.0)
	if sync_picker and _custom_color != null:
		_custom_color.color = color
	var rgb: = RobotColor.to_rgb24(color)
	for swatch: Button in _color_buttons:
		swatch.set("owner_id", 1 if RobotColor.to_rgb24(swatch.get("swatch")) == rgb else 0)
		swatch.set("local_id", 1)
		swatch.queue_redraw()
	if tool == "erase":
		_set_tool("brush")


func _notify(text: String) -> void :
	_notice.text = text
	_notice_left = 2.4


func _unhandled_input(event: InputEvent) -> void :
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if tool == "sticker" and (selected_sticker >= 0 or sticker_armed):
			_arm("")
			select_sticker(-1)
		else:
			close()
		return
	var key: = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode in [KEY_DELETE, KEY_BACKSPACE] and tool == "sticker"\
	and not _name_field.has_focus():
		delete_sticker()
		get_viewport().set_input_as_handled()
		return
	if key != null and key.pressed and not key.echo and key.ctrl_pressed:
		if key.keycode == KEY_Z:
			if key.shift_pressed: redo()
			else: undo()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_Y:
			redo()
			get_viewport().set_input_as_handled()




func _draw_panel(chrome: Control) -> void :
	var panel: = PackedVector2Array([Vector2(0, 0), Vector2(660, 0), Vector2(606, 54), Vector2(606, 330), Vector2(578, 358), Vector2(578, 940), Vector2(540, 978), Vector2(540, 1080), Vector2(0, 1080)])
	var colors: = PackedColorArray()
	for p in panel: colors.append(Color("#2a2a2d").lerp(Color("#19191b"), p.y / 1080.0))
	chrome.draw_polygon(panel, colors)
	chrome.draw_rect(Rect2(578, 912, 1342, 168), Color(0.075, 0.075, 0.085, 0.96))
	chrome.draw_line(Vector2(620, 911), Vector2(1860, 911), Color("#555057"), 1.0)
	chrome.draw_line(Vector2(620, 910), Vector2(880, 910), ACCENT, 3.0)
	chrome.draw_polyline(PackedVector2Array([Vector2(666, 0), Vector2(620, 49), Vector2(620, 183)]), ACCENT, 6, true)
	chrome.draw_polyline(PackedVector2Array([Vector2(592, 366), Vector2(592, 555), Vector2(582, 565)]), ACCENT, 4, true)
	chrome.draw_line(Vector2(80, 954), Vector2(520, 954), Color(0.27, 0.26, 0.28), 1.0)


func _draw() -> void :
	if not visible: return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.028, 0.029, 0.035, 0.8))


func _fit() -> void :
	_scale = minf(size.x / PAPER.x, size.y / PAPER.y)
	_origin = (size - PAPER * _scale) * 0.5
	if _canvas_root != null:
		_canvas_root.scale = Vector2.ONE * _scale
		_canvas_root.position = _origin
	queue_redraw()


func _label(value: String, rect: Rect2, fs: int, ink: Color, bold: = false, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label: = Label.new()
	label.text = value
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_override("font", _bold if bold else _font)
	label.add_theme_font_size_override("font_size", fs)
	label.add_theme_color_override("font_color", ink)
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas_root.add_child(label)
	return label


func _button(value: String, rect: Rect2, action: Callable, primary: = false, fs: = 28) -> Button:
	var button: = BUTTON.new() as Button
	button.text = value
	button.position = rect.position
	button.size = rect.size
	button.set("primary", primary)
	button.set("ui_font", _bold)
	button.set("text_size", fs)
	_canvas_root.add_child(button)
	button.pressed.connect( func() -> void :
		if not is_open: return
		_sound(true)
		action.call())
	button.focus_entered.connect( func() -> void : _sound(false))
	return button


func _toggle(value: String, rect: Rect2, action: Callable) -> CheckButton:
	var check: = CheckButton.new()
	check.text = value
	check.position = rect.position
	check.size = rect.size
	check.add_theme_font_override("font", _bold)
	check.add_theme_font_size_override("font_size", 17)
	check.toggled.connect(action)
	_canvas_root.add_child(check)
	return check


func _slider(rect: Rect2, low: float, high: float, value: float) -> HSlider:
	var slider: = HSlider.new()
	slider.position = rect.position
	slider.size = rect.size
	slider.min_value = low
	slider.max_value = high
	slider.step = (high - low) / 100.0
	slider.value = value
	_canvas_root.add_child(slider)
	return slider


func _sound(pressed: bool) -> void :
	if _ui_sound == null or not is_open: return
	UiSound.play(_ui_sound, "confirm" if pressed else "navigate")
