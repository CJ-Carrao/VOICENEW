class_name HudBar
extends Control



@export var fill: Color = Color("#f5f1e8")
@export var low_fill: Color = Color("#ff4b3a")

@export var low_below: float = 0.0
@export var back: Color = Color(1, 1, 1, 0.1)
@export var chamfer: float = 5.0
@export var segments: int = 0

var max_value: float = 100.0:
	set(v):
		if not is_equal_approx(v, max_value):

			max_value = maxf(v, 0.001)
			value = minf(value, max_value)
			_trail = value
			_hold = 0.0
		queue_redraw()
var value: float = 100.0:
	set(v):
		var gained: = v > value + 0.001
		value = clampf(v, 0.0, max_value)
		if gained:
			_flash = 1.0
		else:
			_hold = 0.35
		queue_redraw()

var _trail: float = 100.0
var _hold: float = 0.0
var _flash: float = 0.0
var _clock: float = 0.0


func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trail = value


func _process(delta: float) -> void :
	_clock += delta
	if _hold > 0.0:
		_hold -= delta
	elif _trail > value:
		_trail = maxf(value, _trail - max_value * 0.9 * delta)
	if _trail < value:
		_trail = value
	_flash = maxf(0.0, _flash - delta * 3.0)
	if _trail > value or _flash > 0.0 or _is_low():
		queue_redraw()


func _is_low() -> bool:
	return low_below > 0.0 and value / max_value < low_below and value > 0.0


func _draw() -> void :
	draw_colored_polygon(_shape(size.x), back)
	var trail: = size.x * minf(_trail, max_value) / max_value
	if trail > 1.0:
		draw_colored_polygon(_shape(trail), Color(1, 1, 1, 0.55))
	var width: = size.x * value / max_value
	if width > 1.0:
		var color: = fill
		if _is_low():
			color = low_fill.lerp(Color.WHITE, 0.25 * (0.5 + 0.5 * sin(_clock * 9.0)))
		draw_colored_polygon(_shape(width), color.lerp(Color.WHITE, _flash * 0.6))
	if segments > 1:
		for i in range(1, segments):
			var x: = size.x * float(i) / segments
			draw_line(Vector2(x, 0), Vector2(x - chamfer * 0.6, size.y), Color(0, 0, 0, 0.45), 2.0)



func _shape(width: float) -> PackedVector2Array:
	var c: = minf(chamfer, size.y)
	var w: = maxf(width, c + 1.0)
	return PackedVector2Array([Vector2(c, 0), Vector2(w, 0), Vector2(w - c, size.y), Vector2(0, size.y)])
