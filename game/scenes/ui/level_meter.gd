class_name LevelMeter
extends Control



const MIN_DB: = -60.0
const MAX_DB: = 0.0

const PEAK_FALL: = 0.6
const COLOR_BACK: = Color(1, 1, 1, 0.1)
const COLOR_QUIET: = Color(0.6, 0.64, 0.72, 0.9)
const COLOR_LOUD: = Color(0.35, 0.9, 0.5, 1)
const COLOR_MARK: = Color(1, 0.8, 0.3, 1)


var level: float = 0.0

var threshold: float = 0.0
var _shown: float = 0.0


func _ready() -> void :
	custom_minimum_size = Vector2(0, 18)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func to_fraction(rms: float) -> float:
	if rms <= 0.0:
		return 0.0
	return clampf((linear_to_db(rms) - MIN_DB) / (MAX_DB - MIN_DB), 0.0, 1.0)


func _process(delta: float) -> void :
	_shown = maxf(to_fraction(level), _shown - PEAK_FALL * delta)
	queue_redraw()


func _draw() -> void :
	var rect: = Rect2(Vector2.ZERO, size)
	draw_rect(rect, COLOR_BACK)
	var mark: = to_fraction(threshold)
	var fill: = Rect2(Vector2.ZERO, Vector2(size.x * _shown, size.y))
	draw_rect(fill, COLOR_LOUD if _shown >= mark else COLOR_QUIET)
	var x: = size.x * mark
	draw_line(Vector2(x, -3), Vector2(x, size.y + 3), COLOR_MARK, 2.0)
