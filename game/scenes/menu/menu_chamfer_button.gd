class_name MenuChamferButton
extends Button


var primary: = false
var ui_font: Font
var text_size: = 28
var accent: = Color("#f2601a")
var _hover: = 0.0
var _press: = 0.0
var _sweep: = 1.0
var _was_engaged: = false


func _ready() -> void :
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color"]:
		add_theme_color_override(state, Color.TRANSPARENT)
	add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	add_theme_constant_override("outline_size", 0)
	add_theme_constant_override("h_separation", 0)
	button_down.connect(_on_button_down)
	set_process(true)


func _process(delta: float) -> void :
	var engaged: = not disabled and (is_hovered() or has_focus())
	if engaged and not _was_engaged:
		_sweep = 0.0
		if is_hovered() and is_visible_in_tree(): UiSound.play_at(self, "hover")
	_was_engaged = engaged
	_hover = move_toward(_hover, 1.0 if engaged else 0.0, delta * 9.0)
	_press = move_toward(_press, 1.0 if not disabled and is_pressed() else 0.0, delta * 9.0)
	_sweep = minf(1.0, _sweep + delta / 0.3) if not disabled else 1.0
	queue_redraw()


func _on_button_down() -> void :


	if disabled: return
	_press = 1.0
	queue_redraw()


func _draw() -> void :
	if size.x <= 0.0 or size.y <= 0.0: return
	var outer: = Rect2(Vector2.ZERO, size)
	var compression: = _press if not disabled else 0.0
	var inset: = minf(compression * 1.5, minf(size.x, size.y) * 0.25)
	var r: = Rect2(Vector2(inset, inset * 2.0), size - Vector2(inset * 2.0, inset * 3.0))
	var pts: = _plate_points(r)
	var cut: = minf(18.0, minf(r.size.x, r.size.y) * 0.24)
	if compression > 0.001: draw_colored_polygon(_plate_points(outer), Color("#17171a"))
	var base: = accent if primary and not disabled else Color("#29292d")
	base = base.lerp(Color("#4d4b49"), _hover * 0.3) if not primary else base.lightened(_hover * 0.12)
	base = base.darkened(compression * 0.18)
	if disabled: base = Color("#222225")
	var colors: = PackedColorArray()
	for p in pts: colors.append(base.lightened(0.045 * (1.0 - (p.y - r.position.y) / maxf(r.size.y, 1.0))))
	draw_polygon(pts, colors)
	var outline: = pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color("#5b5148") if primary else Color("#454449"), 1.0, true)
	if has_focus() and not disabled:
		var focus_outline: = _plate_points(outer.grow(-1.0))
		focus_outline.append(focus_outline[0])
		draw_polyline(focus_outline, Color("#fff0d9"), 2.0, true)
	elif _hover > 0.01 and not primary and not disabled:
		draw_line(r.position + Vector2(1, cut), Vector2(r.position.x + 1, r.end.y - 1), Color(accent, _hover), 3.0)

	if not disabled and _sweep < 1.0:
		var left: = r.position.x + cut + 5.0
		var right: = r.end.x - cut - 5.0
		if right > left:
			var span: = minf(52.0, (right - left) * 0.24)
			var x: = lerpf(left - span, right + span, _sweep)
			var edge_color: = Color("#fff0d9") if primary else accent
			edge_color.a = sin(_sweep * PI) * 0.68 * _hover
			draw_line(Vector2(clampf(x - span, left, right), r.position.y + 3), Vector2(clampf(x, left, right), r.position.y + 3), edge_color, 2.0, true)
	var font: = ui_font if ui_font != null else ThemeDB.fallback_font
	var color: = Color("#f5f1e8") if not disabled else Color("#77757a")
	var fs: = text_size
	while font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 64.0 and fs > 18: fs -= 1
	var baseline: = r.position.y + (r.size.y - font.get_height(fs)) * 0.5 + font.get_ascent(fs)
	draw_string(font, Vector2(r.position.x + 24, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 64, fs, color)
	if primary and not disabled:
		var x: = r.end.x - 25.0 + _hover * 2.0
		var y: = r.get_center().y
		draw_polyline(PackedVector2Array([Vector2(x - 5, y - 6), Vector2(x + 1, y), Vector2(x - 5, y + 6)]), color, 2.0, true)


func _plate_points(rect: Rect2) -> PackedVector2Array:


	var cut: = minf(18.0, minf(rect.size.x, rect.size.y) * 0.24)
	var points: = PackedVector2Array([Vector2(cut, 0), Vector2(rect.size.x - cut, 0), Vector2(rect.size.x, cut), Vector2(rect.size.x, rect.size.y - cut), Vector2(rect.size.x - cut, rect.size.y), Vector2(0, rect.size.y), Vector2(0, cut)])
	for i in points.size(): points[i] += rect.position
	return points
