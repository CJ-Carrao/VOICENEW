class_name LanguageToggle
extends Control




const PAPER_HEIGHT: = 941.0
const PLATE: = Color("#121318")
const EDGE: = Color("#3a3b42")
const ACCENT: = Color("#f2601a")
const INK: = Color("#f5f1e8")
const MUTED: = Color("#aaa69f")

var _font: Font
var _rects: Dictionary = {}
var _press: = ""
var _press_age: = 1.0
var _shown: = 0.0
var _target_shown: = 0.0


func setup(font: Font) -> void :
	_font = font
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	mouse_filter = Control.MOUSE_FILTER_IGNORE



func set_shown(on: bool) -> void :
	_target_shown = 1.0 if on else 0.0


func _process(delta: float) -> void :
	_shown = move_toward(_shown, _target_shown, delta * 4.0)
	_press_age += delta
	queue_redraw()


func _k() -> float:
	return get_viewport_rect().size.y / PAPER_HEIGHT


func _plate_rect() -> Rect2:
	var k: = _k()
	var view: = get_viewport_rect().size
	var plate_size: = Vector2(236.0, 54.0) * k

	var above: = 54.0 if OS.has_feature("mobile") or MobileDev.args().has("--mobile") else 46.0
	return Rect2(Vector2(view.x - 61.0 * k - plate_size.x, view.y - above * k - plate_size.y), plate_size)


func _draw() -> void :
	if _shown <= 0.01 or _font == null:
		return
	var k: = _k()
	var plate: = _plate_rect()
	plate.position.y += (1.0 - _shown) * 24.0 * k
	var cut: = 12.0 * k
	draw_colored_polygon(_chamfer(plate, cut), Color(PLATE, 0.92 * _shown))
	var outline: = _chamfer(plate, cut)
	outline.append(outline[0])
	draw_polyline(outline, Color(EDGE, _shown), maxf(1.0, 1.5 * k), true)
	var langs: Array = Lexicon.LANGUAGES.keys()
	var half: = (plate.size.x - 8.0 * k) / float(langs.size())
	_rects.clear()
	for i in langs.size():
		var lang: = String(langs[i])
		var rect: = Rect2(plate.position + Vector2(4.0 * k + half * i, 4.0 * k), Vector2(half, plate.size.y - 8.0 * k))
		_rects[lang] = rect
		var active: = lang == Lexicon.language()
		var squeeze: = 1.0 - (0.06 * clampf(1.0 - _press_age / 0.15, 0.0, 1.0) if _press == lang else 0.0)
		var face: = Rect2(rect.get_center() - rect.size * squeeze * 0.5, rect.size * squeeze)
		if active:
			draw_colored_polygon(_chamfer(face, 8.0 * k), Color(ACCENT, _shown))
		var label: = String(Lexicon.LANGUAGES[lang]["label"])
		var font_size: = roundi(19.0 * k)
		var width: = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(_font, Vector2(face.get_center().x - width * 0.5, face.get_center().y + font_size * 0.36), label, 
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(PLATE if active else MUTED, _shown))


func _input(event: InputEvent) -> void :
	if _shown < 0.9 or not is_visible_in_tree():
		return
	var point: = Vector2.INF
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed\
	and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		point = (event as InputEventMouseButton).position
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		point = (event as InputEventScreenTouch).position
	if point == Vector2.INF:
		return
	for lang: String in _rects:
		if (_rects[lang] as Rect2).has_point(point):
			get_viewport().set_input_as_handled()
			_press = lang
			_press_age = 0.0
			if lang != Lexicon.language():
				UiSound.play_at(self, "confirm")
				Lexicon.set_language(lang)
			return


static func _chamfer(rect: Rect2, cut: float) -> PackedVector2Array:
	return PackedVector2Array([rect.position + Vector2(cut, 0), Vector2(rect.end.x, rect.position.y), 
		Vector2(rect.end.x, rect.end.y - cut), Vector2(rect.end.x - cut, rect.end.y), Vector2(rect.position.x, rect.end.y), 
		Vector2(rect.position.x, rect.position.y + cut)])
