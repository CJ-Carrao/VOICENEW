class_name SpectatorCamera
extends Camera3D





var _yaw: = 0.0
var _pitch: = 0.0
var _half: = 48.0
var _cfg: Dictionary



func start(from: Transform3D, half: float) -> void :
	_cfg = Lexicon.bal("spectator", {})
	_half = half
	var euler: = from.basis.get_euler(EULER_ORDER_YXZ)
	_yaw = euler.y
	_pitch = clampf(euler.x, -1.4, 1.4)
	global_position = from.origin + Vector3.UP * float(_cfg.get("start_lift_m", 2.0))
	_apply_rotation()
	make_current()


func _unhandled_input(event: InputEvent) -> void :
	var motion: = event as InputEventMouseMotion
	if motion == null or not current:
		return
	var sensitivity: = float(_cfg.get("look_sensitivity", 0.0025)) * float(UserSettings.get_value("controls", "mouse_scale", 1.0))
	_yaw -= motion.relative.x * sensitivity
	_pitch = clampf(_pitch - motion.relative.y * sensitivity, -1.4, 1.4)
	_apply_rotation()


func _process(delta: float) -> void :
	if not current:
		return
	var wish: = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var vertical: = Input.get_action_strength("jump") - Input.get_action_strength("crouch")
	var direction: = global_basis * Vector3(wish.x, 0.0, wish.y) + Vector3.UP * vertical
	var speed: = float(_cfg.get("speed_ms", 12.0)) * (float(_cfg.get("sprint_mult", 2.5)) if Input.is_action_pressed("sprint") else 1.0)
	var next: = global_position + direction.limit_length(1.0) * speed * delta

	next.x = clampf(next.x, - _half, _half)
	next.z = clampf(next.z, - _half, _half)
	next.y = clampf(next.y, float(_cfg.get("min_y_m", 0.5)), float(_cfg.get("max_y_m", 60.0)))
	global_position = next


func _apply_rotation() -> void :
	global_basis = Basis.from_euler(Vector3(_pitch, _yaw, 0.0), EULER_ORDER_YXZ)
