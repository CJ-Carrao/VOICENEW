class_name HudSkin
extends RefCounted



const ACCENT: = Color("#f2601a")
const INK: = Color("#f5f1e8")
const MUTED: = Color("#aaa69f")
const GRAPHITE: = Color(0.094, 0.094, 0.106, 0.84)
const MATTER: = Color("#ffc65c")
const DANGER: = Color("#ff4b3a")

static var _fonts: Dictionary = {}



static func font(weight: int) -> Font:
	if not _fonts.has(weight):
		var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/intro.json"))
		_fonts[weight] = MainMenu._variation(load(str(config.font)) as Font, weight, 0)
	return _fonts[weight]


static func create_theme() -> Theme:
	var theme: = Theme.new()
	theme.default_font = font(600)
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.55))
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 2)
	theme.set_type_variation("DimLabel", "Label")
	theme.set_color("font_color", "DimLabel", MUTED)
	theme.set_font_size("font_size", "DimLabel", 12)
	theme.set_font("font", "DimLabel", font(700))
	theme.set_type_variation("TagLabel", "Label")
	theme.set_color("font_color", "TagLabel", ACCENT)
	theme.set_font_size("font_size", "TagLabel", 12)
	theme.set_font("font", "TagLabel", font(800))
	theme.set_type_variation("BigLabel", "Label")
	theme.set_font("font", "BigLabel", font(800))
	theme.set_font_size("font_size", "BigLabel", 24)
	theme.set_stylebox("panel", "PanelContainer", panel(GRAPHITE, Color(0, 0, 0, 0), 0))
	theme.set_type_variation("SlotPanel", "PanelContainer")
	theme.set_stylebox("panel", "SlotPanel", panel(Color(0.094, 0.094, 0.106, 0.74), Color(1, 1, 1, 0.14), 2, 8))
	theme.set_type_variation("SlotPanelActive", "PanelContainer")
	theme.set_stylebox("panel", "SlotPanelActive", panel(Color(0.36, 0.15, 0.05, 0.86), ACCENT, 2, 8))
	theme.set_type_variation("AccentPanel", "PanelContainer")
	var accent: = panel(GRAPHITE, ACCENT, 0)
	accent.border_width_left = 3
	theme.set_stylebox("panel", "AccentPanel", accent)
	theme.set_color("default_color", "RichTextLabel", INK)
	theme.set_font("normal_font", "RichTextLabel", font(600))
	theme.set_font("bold_font", "RichTextLabel", font(800))
	theme.set_font_size("normal_font_size", "RichTextLabel", 15)
	theme.set_font_size("bold_font_size", "RichTextLabel", 15)
	var line: = panel(GRAPHITE, ACCENT, 0, 8)
	line.border_width_bottom = 2
	theme.set_stylebox("normal", "LineEdit", line)
	theme.set_stylebox("focus", "LineEdit", StyleBoxEmpty.new())
	theme.set_font_size("font_size", "LineEdit", 18)
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("caret_color", "LineEdit", ACCENT)
	theme.set_stylebox("normal", "Button", panel(GRAPHITE, Color(1, 1, 1, 0.16), 1, 8))
	theme.set_stylebox("hover", "Button", panel(Color(0.2, 0.2, 0.22, 0.9), ACCENT, 1, 8))
	theme.set_stylebox("pressed", "Button", panel(Color(0.36, 0.15, 0.05, 0.9), ACCENT, 2, 8))
	theme.set_stylebox("disabled", "Button", panel(Color(0.094, 0.094, 0.106, 0.4), Color(1, 1, 1, 0.06), 1, 8))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	return theme



static func panel(bg: Color, border: Color, border_width: int, cut: int = 12) -> StyleBoxFlat:
	var box: = StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.corner_radius_top_right = cut
	box.corner_radius_bottom_left = cut
	box.corner_detail = 1
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	box.anti_aliasing = true
	return box
