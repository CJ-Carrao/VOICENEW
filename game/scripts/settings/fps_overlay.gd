class_name FpsOverlay
extends CanvasLayer


var _label: Label
var _clock: = 0.0


func _ready() -> void :
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.position = Vector2(10, 6)
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color("#f5f1e8"))
	_label.add_theme_color_override("font_outline_color", Color("#161619"))
	_label.add_theme_constant_override("outline_size", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_refresh()


func _process(delta: float) -> void :
	_clock += delta
	if _clock >= 0.25:
		_clock = 0.0
		_refresh()


func _refresh() -> void :
	var frame_ms: = 1000.0 / maxf(Engine.get_frames_per_second(), 1.0)
	_label.text = "%d FPS  ·  %.1f ms" % [Engine.get_frames_per_second(), frame_ms]
