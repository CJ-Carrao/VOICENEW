extends Button


var swatch: = Color.WHITE
var color_name: = ""
var owner_id: = 0
var local_id: = 1
var ui_font: Font
var compact: = false

func _ready() -> void :
	clip_text = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color"]:
		add_theme_color_override(state, Color.TRANSPARENT)
	add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	add_theme_constant_override("outline_size", 0)

func _draw() -> void :
	var selected: = owner_id == local_id
	var occupied: = owner_id > 0 and not selected
	var hovered: = not disabled and (is_hovered() or has_focus())
	var points: = PackedVector2Array([Vector2(9, 0), Vector2(size.x - 9, 0), Vector2(size.x, 9), Vector2(size.x, size.y - 9), Vector2(size.x - 9, size.y), Vector2(0, size.y), Vector2(0, 9)])
	var background: = Color("#222329")
	if selected: background = swatch.darkened(0.78)
	elif hovered: background = Color("#34353b")
	draw_colored_polygon(points, background)
	var outline: = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color("#fff0d9") if hovered or selected else Color("#57565d"), 2.0 if selected or hovered else 1.0, true)
	var swatch_rect: = Rect2(7, 7, size.x - 14, 22) if compact else Rect2(13, 13, size.x - 26, 20)
	draw_rect(swatch_rect, swatch)

	draw_rect(swatch_rect, Color("#85858b"), false, 1.0)
	var symbol_ink: = Color("#f5f1e8") if swatch.get_luminance() < 0.3 else Color("#17191e")
	if occupied:

		var center: = swatch_rect.get_center()
		draw_rect(Rect2(center + Vector2(-5, -2), Vector2(10, 8)), symbol_ink)
		draw_arc(center + Vector2(0, -2), 3.5, PI, TAU, 12, symbol_ink, 2.0, true)
	var font: = ui_font if ui_font != null else ThemeDB.fallback_font
	var ink: = Color("#f5f1e8") if not occupied else Color("#b8b5b0")
	if not compact: _center_text(font, color_name, 54, 17, ink)
	var status: = ("SUA" if compact else "SUA COR") if selected else ("P%d" % owner_id if occupied else ("·" if compact else "LIVRE"))
	_center_text(font, status, 44 if compact else 77, 13 if compact else 14, ink)
	if selected:
		var at: = swatch_rect.get_center()
		draw_polyline(PackedVector2Array([at + Vector2(-5, 0), at + Vector2(-1, 4), at + Vector2(6, -4)]), symbol_ink, 2.0, true)

func _center_text(font: Font, value: String, y: float, font_size: int, color: Color) -> void :
	var width: = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2((size.x - width) * 0.5, y), value, HORIZONTAL_ALIGNMENT_LEFT, size.x, font_size, color)
