class_name MenuBackground
extends Control






const NEON: = preload("res://scenes/menu/menu_neon_sign.gd")
const HEAD: = preload("res://scenes/menu/menu_robot_head.gd")

var _start_s: = 0.0
var _started: = false
var _config: Dictionary = {}
var _layout: Dictionary = {}
var _sign: Control
var _head: Control
var _overlay: = false
var _vignette: GradientTexture2D


func setup(config: Dictionary, start_s: float, layout: Dictionary = {}) -> void :
	name = "MenuBackground"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_start_s = start_s
	_config = config
	_layout = layout
	if OS.has_feature("mobile") or MobileDev.args().has("--mobile"):
		_sign = NEON.new()
		_sign.call("setup", config.get("sign", {}))
		add_child(_sign)
		_head = HEAD.new()
		_head.call("setup", config.get("head", {}))
		add_child(_head)
	resized.connect(_place)
	_place()



func update_clock(time_s: float) -> void :
	if time_s < _start_s:
		return
	if not _started:
		_started = true
		visible = true
	var age: = time_s - _start_s
	if _sign != null:
		_sign.call("update_age", age - float(_config.get("sign", {}).get("delay_s", 1.8)))
	if _head != null:
		_head.call("update_age", age - float(_config.get("head", {}).get("delay_s", 3.4)))



func relabel() -> void :
	if _sign != null:
		_sign.call("reassemble")
	if _head != null:
		_head.call("react", "Surprised")



func set_overlay(open: bool) -> void :
	_overlay = open
	for extra: Control in [_sign, _head]:
		if extra != null:
			extra.visible = not open
			extra.process_mode = Node.PROCESS_MODE_DISABLED if open else Node.PROCESS_MODE_INHERIT


func _place() -> void :
	if _sign == null:
		return

	var reference: = float(_layout.get("height", 941.0))
	var panel: = float(_layout.get("panel_edge_x", 628.0)) * size.y / reference
	var room: = Rect2(panel, 0, maxf(size.x - panel, 1.0), size.y)
	var sign_cfg: Dictionary = _config.get("sign", {})
	var width: = room.size.x * float(sign_cfg.get("width_frac", 0.78))
	var sign_size: = Vector2(width, width * float(sign_cfg.get("aspect", 0.42)))
	sign_size *= minf(1.0, size.y * 0.52 / sign_size.y)
	_sign.size = sign_size
	_sign.position = Vector2(room.get_center().x - sign_size.x * 0.5, size.y * float(sign_cfg.get("top_frac", 0.12)))
	var head_size: = Vector2(size.y * 0.42, size.y * 0.36)
	_head.size = head_size
	_head.position = Vector2(room.get_center().x - head_size.x * 0.5, _sign.position.y + sign_size.y + size.y * 0.02)


func _draw() -> void :
	var yellow: = Color(String(_config.get("color", "#ffc928")))
	draw_rect(Rect2(Vector2.ZERO, size), yellow)

	if _vignette == null:
		var gradient: = Gradient.new()
		var edge: = yellow.darkened(float(_config.get("edge_darken", 0.22)))
		gradient.set_color(0, Color(edge, 0.0))
		gradient.set_color(1, Color(edge, 0.85))
		gradient.add_point(0.55, Color(edge, 0.08))
		_vignette = GradientTexture2D.new()
		_vignette.gradient = gradient
		_vignette.fill = GradientTexture2D.FILL_RADIAL
		_vignette.fill_from = Vector2(0.5, 0.45)
		_vignette.fill_to = Vector2(1.15, 1.1)
		_vignette.width = 256
		_vignette.height = 256
	draw_texture_rect(_vignette, Rect2(Vector2.ZERO, size), false)
