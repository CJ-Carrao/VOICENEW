extends Control





const ROBOT: = preload("res://scenes/menu/lobby_robot_display.gd")
const HEAD_PARTS: = ["Body_Head", "Face_Panel", "Face_Screen"]

var _cfg: Dictionary = {}
var _age: = -1.0
var _view: SubViewport
var _container: SubViewportContainer
var _holder: Node3D
var _display: Node3D
var _expressions: PackedStringArray = []
var _next_change: = 0.0
var _rng: = RandomNumberGenerator.new()
var _built: = false


func setup(config: Dictionary) -> void :
	_cfg = config
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_expressions = PackedStringArray(config.get("expressions", ["Happy", "VeryHappy", "Confused", "Sleepy", "Bored", 
		"Surprised", "Dizzy", "Thinking", "WinkLeft", "WinkRight", "Sad", "Determined", "Neutral"]))
	_rng.seed = int(config.get("seed", 41))
	_container = SubViewportContainer.new()
	_container.stretch = true
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_container.visible = false
	add_child(_container)
	_view = SubViewport.new()
	_view.own_world_3d = true
	_view.transparent_bg = true
	_view.msaa_3d = Viewport.MSAA_2X
	_container.add_child(_view)



func _build() -> void :
	_built = true
	var world: = Node3D.new()
	_view.add_child(world)
	var env: = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff0c8")
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env: = WorldEnvironment.new()
	world_env.environment = env
	world.add_child(world_env)
	var key: = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, 150, 0)
	key.light_energy = 1.25
	key.light_color = Color("fff3dc")
	world.add_child(key)
	var rim: = OmniLight3D.new()
	rim.position = Vector3(0.0, 0.5, 0.6)
	rim.light_color = Color("ff791c")
	rim.light_energy = 0.9
	rim.omni_range = 2.5
	world.add_child(rim)
	var config: = RobotBody.config()
	var clips: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(String(config["clips_meta"])))
	var face_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(String(config["face_data"])))
	_holder = Node3D.new()
	world.add_child(_holder)
	_display = ROBOT.new()
	_holder.add_child(_display)
	_display.call("setup", config, clips["clips"], face_data, 3)
	_display.call("show_rest")
	var center: = Vector3.ZERO
	for part: Dictionary in _display.get("parts"):
		var keep: = HEAD_PARTS.has(String(part["name"]))
		(part["node"] as Node3D).visible = keep
		if String(part["name"]) == "Body_Head":
			center = (part["node"] as Node3D).position
	var weapon: = _display.get("weapon") as Node3D
	if weapon != null: weapon.visible = false
	_display.position = - center
	var camera: = Camera3D.new()
	camera.fov = float(_cfg.get("fov", 34.0))
	camera.position = Vector3(0.18, 0.16, -1.15)
	camera.current = true
	world.add_child(camera)
	camera.look_at(Vector3(0, -0.02, 0))
	_container.visible = true



func react(expression: String) -> void :
	if not _built:
		return
	var face: = _display.get("face") as RobotFace
	if face != null:
		face.set_expression(expression)
		_next_change = _age + 1.6



func update_age(age: float) -> void :
	if age >= 0.0 and not _built:
		_build()
	_age = age


func _process(delta: float) -> void :
	if not _built or _age < 0.0:
		return
	var face: = _display.get("face") as RobotFace
	if face != null:
		face.advance(delta)
		if _age > 0.9 and _age >= _next_change:
			var choice: = _expressions[_rng.randi_range(0, _expressions.size() - 1)]
			if choice == face.current: choice = "Neutral" if face.current != "Neutral" else "Happy"
			face.set_expression(choice)
			_next_change = _age + _rng.randf_range(float(_cfg.get("change_min_s", 2.5)), float(_cfg.get("change_max_s", 5.0)))

	var fall: = clampf(_age / 0.55, 0.0, 1.0)
	var height: = 0.0
	if fall < 1.0:
		height = (1.0 - fall * fall) * 1.4
	else:
		var bounce: = _age - 0.55
		height = absf(sin(bounce * 9.0)) * 0.12 * exp( - bounce * 5.5)
	var tilt: = deg_to_rad(float(_cfg.get("rest_tilt_deg", 14.0))) + (face.head_tilt() if face != null else 0.0)
	_holder.position = Vector3(0, height, 0)
	_holder.rotation = Vector3(deg_to_rad(-6.0), deg_to_rad(-18.0) + sin(_age * 0.7) * 0.03, tilt * minf(_age / 0.8, 1.0))
	queue_redraw()


func _draw() -> void :
	if not _built or _age < 0.0:
		return

	var height: = _holder.position.y if _holder != null else 0.0
	var strength: = clampf(1.0 - height / 1.4, 0.0, 1.0)
	var center: = Vector2(size.x * 0.5, size.y * 0.8)
	var radius: = Vector2(size.x * 0.3, size.y * 0.06) * (0.7 + 0.3 * strength)
	for i in 6:
		var k: = 1.0 - float(i) / 6.0
		draw_set_transform(center, 0.0, Vector2(radius.x, radius.y) * (0.55 + 0.45 * (1.0 - k)))
		draw_circle(Vector2.ZERO, 1.0, Color(0.35, 0.22, 0.0, 0.09 * strength))
	draw_set_transform(Vector2.ZERO)
