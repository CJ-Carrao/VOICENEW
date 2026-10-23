extends RefCounted



const TEXT: = Color("#f5f1e8")
const MUTED: = Color("#b0aca4")
const ACCENT: = Color("#f2601a")
const DARK: = Color("#242427")
const RAISED: = Color("#303034")


static func create_theme(font: Font) -> Theme:
	var theme: = Theme.new()
	theme.default_font_size = 24
	if font != null: theme.default_font = font
	for type in ["Label", "Button", "OptionButton", "CheckButton", "PopupMenu", "LineEdit", "RichTextLabel"]:
		if font != null: theme.set_font("font", type, font)
		theme.set_font_size("font_size", type, 24)
		theme.set_color("font_color", type, TEXT)
		theme.set_color("font_shadow_color", type, Color.TRANSPARENT)
		theme.set_constant("shadow_offset_x", type, 0)
		theme.set_constant("shadow_offset_y", type, 0)
		theme.set_constant("outline_size", type, 0)
	theme.set_color("default_color", "RichTextLabel", TEXT)
	theme.set_type_variation("DimLabel", "Label")
	theme.set_font_size("font_size", "DimLabel", 21)
	theme.set_color("font_color", "DimLabel", MUTED)
	var divider: = StyleBoxLine.new()
	divider.color = Color("#55514c")
	divider.thickness = 1
	theme.set_stylebox("separator", "HSeparator", divider)
	theme.set_constant("separation", "HSeparator", 12)
	for type in ["Button", "OptionButton", "CheckButton", "LineEdit"]:
		theme.set_color("font_hover_color", type, TEXT)
		theme.set_color("font_focus_color", type, TEXT)
		theme.set_color("font_pressed_color", type, TEXT)
		theme.set_color("font_hover_pressed_color", type, TEXT)
		theme.set_color("font_disabled_color", type, MUTED)
		theme.set_color("icon_normal_color", type, TEXT)
		theme.set_color("icon_hover_color", type, TEXT)
		theme.set_color("icon_pressed_color", type, TEXT)
		theme.set_color("icon_disabled_color", type, MUTED)
		theme.set_constant("h_separation", type, 16)
		theme.set_stylebox("normal", type, _chamfer("#242427", "#55514c"))
		theme.set_stylebox("hover", type, _chamfer("#303034", "#c08361"))
		theme.set_stylebox("pressed", type, _chamfer("#302720", "#f2601a"))
		theme.set_stylebox("hover_pressed", type, _chamfer("#3b2c24", "#f2601a"))
		theme.set_stylebox("disabled", type, _chamfer("#242427", "#444145"))
		theme.set_stylebox("focus", type, _chamfer("none", "#f2601a", 2.0))
	_option_button(theme)
	_toggle(theme)
	_slider(theme)
	_scroll(theme)
	theme.set_stylebox("panel", "PanelContainer", _flat(DARK, Color("#494549"), 1, 20, 16))
	theme.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	theme.set_stylebox("focus", "RichTextLabel", _chamfer("none", "#f2601a", 2.0))
	theme.set_color("caret_color", "LineEdit", TEXT)
	theme.set_color("selection_color", "LineEdit", Color("#794226"))
	theme.set_color("font_selected_color", "LineEdit", TEXT)
	theme.set_constant("separation", "VBoxContainer", 14)
	theme.set_constant("separation", "HBoxContainer", 16)
	return theme


static func _option_button(theme: Theme) -> void :
	theme.set_icon("arrow", "OptionButton", _svg(20, 14, "<path d=\"M2 3L10 11L18 3\" fill=\"none\" stroke=\"#f5f1e8\" stroke-width=\"2.5\"/>"))
	theme.set_constant("arrow_margin", "OptionButton", 18)
	theme.set_constant("modulate_arrow", "OptionButton", 1)
	theme.set_stylebox("panel", "PopupMenu", _chamfer("#242427", "#777068"))
	theme.set_stylebox("hover", "PopupMenu", _chamfer("#4a3023", "#f2601a"))
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", TEXT)
	theme.set_color("font_disabled_color", "PopupMenu", MUTED)
	theme.set_color("font_accelerator_color", "PopupMenu", MUTED)
	theme.set_color("font_separator_color", "PopupMenu", MUTED)
	theme.set_constant("v_separation", "PopupMenu", 16)
	theme.set_constant("h_separation", "PopupMenu", 16)
	theme.set_constant("item_start_padding", "PopupMenu", 12)
	theme.set_constant("item_end_padding", "PopupMenu", 12)
	var separator: = StyleBoxLine.new()
	separator.color = Color("#57514d")
	separator.thickness = 1
	theme.set_stylebox("separator", "PopupMenu", separator)
	var checked: = _svg(20, 20, "<path d=\"M3 10L8 15L17 5\" fill=\"none\" stroke=\"#f2601a\" stroke-width=\"3\"/>")
	var unchecked: = _svg(20, 20, "<path d=\"M4 4H16V16H4Z\" fill=\"none\" stroke=\"#b0aca4\" stroke-width=\"1.5\"/>")
	for key in ["checked", "radio_checked"]: theme.set_icon(key, "PopupMenu", checked)
	for key in ["unchecked", "radio_unchecked"]: theme.set_icon(key, "PopupMenu", unchecked)


static func _toggle(theme: Theme) -> void :
	for state in ["normal", "pressed", "disabled"]:
		theme.set_stylebox(state, "CheckButton", _flat(Color.TRANSPARENT, Color.TRANSPARENT, 0, 18, 10))
	for state in ["hover", "hover_pressed"]:
		theme.set_stylebox(state, "CheckButton", _chamfer("#303034", "#55514c"))
	theme.set_color("button_checked_color", "CheckButton", Color.WHITE)
	theme.set_color("button_unchecked_color", "CheckButton", Color.WHITE)
	for disabled in [false, true]:
		for checked in [false, true]:
			var name: = "checked" if checked else "unchecked"
			if disabled: name += "_disabled"
			for mirrored in [false, true]:
				var key: = name + ("_mirrored" if mirrored else "")
				theme.set_icon(key, "CheckButton", _toggle_icon(checked, disabled, mirrored))


static func _toggle_icon(checked: bool, disabled: bool, mirrored: bool) -> Texture2D:
	var on_right: = checked != mirrored
	var x: = 39 if on_right else 5
	var track: = "#f2601a" if checked else "#242427"
	var border: = "#f5a171" if checked else "#8b857d"
	var knob: = "#f5f1e8" if checked else "#b0aca4"
	if disabled:
		track = "#65554a" if checked else "#303034"
		border = "#81756b"
		knob = "#b0aca4"
	var body: = "<path d=\"M7 1H63L69 7V29L63 35H7L1 29V7Z\" fill=\"%s\" stroke=\"%s\" stroke-width=\"1.5\"/>" % [track, border]
	body += "<path d=\"M%d 6H%dL%d 10V26L%d 30H%dL%d 26V10Z\" fill=\"%s\"/>" % [x + 4, x + 20, x + 24, x + 20, x + 4, x, knob]
	return _svg(70, 36, body)


static func _slider(theme: Theme) -> void :
	theme.set_stylebox("slider", "HSlider", _flat(Color("#171719"), Color("#58524b"), 1, 0, 4))
	theme.set_stylebox("grabber_area", "HSlider", _flat(ACCENT, Color.TRANSPARENT, 0, 0, 3))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _flat(Color("#ff9358"), Color.TRANSPARENT, 0, 0, 3))
	theme.set_stylebox("focus", "HSlider", _chamfer("none", "#f2601a", 2.0))
	var shape: = "<path d=\"M5 1H17L21 5V25L17 29H5L1 25V5Z\" fill=\"%s\" stroke=\"%s\" stroke-width=\"1.5\"/>"
	theme.set_icon("grabber", "HSlider", _svg(22, 30, shape % ["#f2601a", "#f5f1e8"]))
	theme.set_icon("grabber_highlight", "HSlider", _svg(22, 30, shape % ["#f5f1e8", "#f2601a"]))
	theme.set_icon("grabber_disabled", "HSlider", _svg(22, 30, shape % ["#77716b", "#b0aca4"]))
	theme.set_constant("grabber_offset", "HSlider", 0)
	theme.set_constant("center_grabber", "HSlider", 0)


static func _scroll(theme: Theme) -> void :
	theme.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	theme.set_stylebox("focus", "ScrollContainer", _chamfer("none", "#f2601a", 2.0))
	theme.set_stylebox("scroll", "VScrollBar", _flat(Color("#19191c"), Color.TRANSPARENT, 0, 7, 4))
	theme.set_stylebox("scroll_focus", "VScrollBar", _flat(Color("#19191c"), ACCENT, 1, 7, 4))
	theme.set_stylebox("grabber", "VScrollBar", _flat(Color("#77716b"), Color.TRANSPARENT, 0, 7, 12))
	theme.set_stylebox("grabber_highlight", "VScrollBar", _flat(MUTED, Color.TRANSPARENT, 0, 7, 12))
	theme.set_stylebox("grabber_pressed", "VScrollBar", _flat(ACCENT, Color.TRANSPARENT, 0, 7, 12))
	for suffix in ["", "_highlight", "_pressed"]:
		var color: = "#f2601a" if suffix == "_pressed" else "#b0aca4"
		theme.set_icon("increment" + suffix, "VScrollBar", _svg(16, 16, "<path d=\"M4 6L8 10L12 6\" fill=\"none\" stroke=\"%s\" stroke-width=\"2\"/>" % color))
		theme.set_icon("decrement" + suffix, "VScrollBar", _svg(16, 16, "<path d=\"M4 10L8 6L12 10\" fill=\"none\" stroke=\"%s\" stroke-width=\"2\"/>" % color))


static func _flat(background: Color, border: Color, width: int, horizontal: float, vertical: float) -> StyleBoxFlat:
	var box: = StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(width)
	box.content_margin_left = horizontal
	box.content_margin_right = horizontal
	box.content_margin_top = vertical
	box.content_margin_bottom = vertical
	return box


static func _chamfer(fill: String, stroke: String, width: float = 1.0) -> StyleBoxTexture:
	var box: = StyleBoxTexture.new()
	box.texture = _svg(100, 56, "<path d=\"M11 2H89L98 11V45L89 54H11L2 45V11Z\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%s\"/>" % [fill, stroke, width])
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: box.set_texture_margin(side, 12)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box


static func _svg(width: int, height: int, body: String) -> Texture2D:
	var image: = Image.new()
	var svg: = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\">%s</svg>" % [width, height, width, height, body]
	if image.load_svg_from_string(svg) != OK: return null
	return ImageTexture.create_from_image(image)
