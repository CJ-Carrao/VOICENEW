class_name HowToPlay
extends Control







signal closed

const DATA_PATH: = "res://scenes/menu/how_to_play.json"
const PAPER: = Vector2(1920, 1080)
const FONT_PATH: = "res://assets/fonts/oxanium/Oxanium-Variable.ttf"
const ACCENT: = Color("#f2601a")
const GOLD: = Color("#ffc65c")
const INK: = Color("#f5f1e8")
const MUTED: = Color("#aaa69f")
const PLATE: = Color("#121318")
const CARD: = Color("#1d1e23")

const POINTER_HOLD_S: = 2.6

var _data: Dictionary = {}
var _steps: Array = []
var _root: Control
var _board: Control
var _video: VideoStreamPlayer
var _streams: Array[VideoStream] = []
var _title: Label
var _body: Label
var _font: FontVariation
var _font_bold: FontVariation
var _paper: = PAPER
var _tab: = 0
var _tab_glow: Array[float] = []
var _tab_rects: Array[Rect2] = []
var _back: MenuChamferButton
var _next: MenuChamferButton
var _clock: = 0.0



static func seen() -> bool:
	return bool(UserSettings.get_value("tutorial", "seen", false))


func _ready() -> void :
	_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	_steps = _data["steps"]
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var base: = load(FONT_PATH) as Font
	_font = MainMenu._variation(base, 500, 0)
	_font_bold = MainMenu._variation(base, 800, 0)
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_board = Control.new()
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.draw.connect(_draw_board)
	_root.add_child(_board)
	_video = VideoStreamPlayer.new()
	_video.expand = true
	_video.loop = true
	_video.bus = AudioMix.bus(AudioMix.EFFECTS)
	_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_video)
	for step: Dictionary in _steps:

		var path: = String(step.get("video_" + Lexicon.language(), step["video"]))
		_streams.append(load(path) as VideoStream if ResourceLoader.exists(path) else null)
		_tab_glow.append(0.0)
		_tab_rects.append(Rect2())
	_title = _label(_font_bold, 54, INK)
	_body = _label(_font, 30, INK)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_constant_override("line_spacing", 6)
	_back = _button(String(_data["back"]), false)
	_back.pressed.connect( func() -> void : _show_tab(_tab - 1))
	_next = _button("", true)
	_next.pressed.connect( func() -> void :
		if _tab >= _steps.size() - 1: close()
		else: _show_tab(_tab + 1))
	_overlay_draw.call_deferred()
	resized.connect(_layout)
	_layout()


func _label(font: Font, size_px: int, color: Color) -> Label:
	var label: = Label.new()
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(label)
	return label


func _button(text: String, primary: bool) -> MenuChamferButton:
	var button: = MenuChamferButton.new()
	button.primary = primary
	button.ui_font = _font_bold
	button.text = text
	button.text_size = 30
	button.show_arrow = false
	_root.add_child(button)
	return button



func _overlay_draw() -> void :
	var overlay: = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect( func() -> void : _draw_pointer(overlay))
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_video.add_child(overlay)
	set_meta("overlay", overlay)


func open() -> void :
	UserSettings.set_value("tutorial", "seen", true)
	visible = true
	var first: = 0
	for argument: String in MobileDev.args():
		if argument.begins_with("--como-jogar="):
			first = argument.trim_prefix("--como-jogar=").to_int() - 1
	_show_tab(first)
	_next.grab_focus.call_deferred()


func close() -> void :
	if not visible:
		return
	UiSound.play_at(self, "back")
	_video.stop()
	visible = false
	closed.emit()


func _show_tab(index: int) -> void :
	_tab = clampi(index, 0, _steps.size() - 1)
	var step: Dictionary = _steps[_tab]
	_title.text = String(step["title"])
	_body.text = String(step["text"])
	_back.visible = _tab > 0
	_next.text = String(_data["ok"]) if _tab == _steps.size() - 1 else String(_data["next"])
	_video.stop()
	_video.stream = _streams[_tab]
	if _video.stream != null:
		_video.play()
	_clock = 0.0
	UiSound.play_at(self, "hover")
	_layout()




func _layout() -> void :
	if size.y <= 0.0:
		return
	_paper = Vector2(maxf(PAPER.x, PAPER.y * size.x / size.y), PAPER.y)
	var s: = minf(size.x / _paper.x, size.y / _paper.y)
	_root.scale = Vector2.ONE * s
	_root.size = _paper
	_root.position = (size - _paper * s) * 0.5
	_board.size = _paper
	var left: = _left()
	var tab_w: = 300.0
	for i in _tab_rects.size():
		_tab_rects[i] = Rect2(left + 40 + i * (tab_w + 14), 190, tab_w, 74)
	_video.position = Vector2(left + 40, 300)
	_video.size = Vector2(1088, 612)
	var column: = left + 1170
	_title.position = Vector2(column, 300)
	_body.position = Vector2(column, 380)
	_body.size = Vector2(500, 300)
	_back.position = Vector2(column, 900)
	_back.size = Vector2(200, 84)
	_next.position = Vector2(column + 216, 900)
	_next.size = Vector2(284, 84)
	_board.queue_redraw()


func _left() -> float:
	return 110.0 + (_paper.x - PAPER.x) * 0.5




func _process(delta: float) -> void :
	if not visible:
		return
	_clock += delta
	for i in _tab_glow.size():
		_tab_glow[i] = move_toward(_tab_glow[i], 1.0 if i == _tab else 0.0, delta * 7.0)
	_board.queue_redraw()
	var overlay: = get_meta("overlay", null) as Control
	if overlay != null:
		overlay.queue_redraw()


func _gui_input(event: InputEvent) -> void :
	var point: = Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		point = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed\
	and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		point = (event as InputEventMouseButton).position
	if point == Vector2.INF:
		return
	var local: = (point - _root.position) / _root.scale.x
	for i in _tab_rects.size():
		if _tab_rects[i].has_point(local) and i != _tab:
			_show_tab(i)
			accept_event()
			return


func _unhandled_input(event: InputEvent) -> void :
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("ui_right"):
		_show_tab(_tab + 1)
	elif event.is_action_pressed("ui_left"):
		_show_tab(_tab - 1)
	else:
		return
	get_viewport().set_input_as_handled()




func _draw() -> void :
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.04, 0.02, 0.62))


func _draw_board() -> void :
	var left: = _left()
	var panel: = Rect2(left, 60, 1700, 960)
	_board.draw_colored_polygon(_chamfer(panel, 34), Color(PLATE, 0.97))
	_board.draw_rect(Rect2(left + 34, 60, 260, 6), ACCENT)
	_board.draw_string(_font_bold, Vector2(left + 40, 150), tr(String(_data["title"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 60, INK)
	var subtitle: = tr(String(_data["subtitle"]))
	_board.draw_string(_font, Vector2(left + 1660 - _font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x, 146), 
		subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, MUTED)
	for i in _tab_rects.size():
		_draw_tab(i)

	var frame: = Rect2(_video.position - Vector2(6, 6), _video.size + Vector2(12, 12))
	_board.draw_colored_polygon(_chamfer(frame, 20), Color("#08080a"))
	var bar: = Rect2(_video.position.x, _video.position.y + _video.size.y + 20, _video.size.x, 6)
	_board.draw_rect(bar, Color("#2a2b31"))
	var length: = _video.get_stream_length() if _video.stream != null else 0.0
	if length > 0.0:
		_board.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(_video.stream_position / length, 0.0, 1.0), bar.size.y)), ACCENT)
	if bool(_steps[_tab].get("voice_note", false)):
		_draw_voice_note(Rect2(_body.position.x, 600, 500, 280))


func _draw_tab(i: int) -> void :
	var rect: = _tab_rects[i]
	var glow: = _tab_glow[i]
	_board.draw_colored_polygon(_chamfer(rect, 16), CARD.lerp(Color("#2a241f"), glow))
	if glow > 0.01:
		_board.draw_rect(Rect2(rect.position.x + 16, rect.end.y - 5, (rect.size.x - 32) * glow, 5), ACCENT)
	var center: = rect.position + Vector2(44, rect.size.y * 0.5)
	_board.draw_colored_polygon(_octagon(center, 24), ACCENT.lerp(Color("#3a3b42"), 1.0 - glow))
	_board.draw_string(_font_bold, center + Vector2(-9, 11), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, INK)
	_board.draw_string(_font_bold, Vector2(rect.position.x + 84, rect.position.y + 48), tr(String(_steps[i]["title"])), 
		HORIZONTAL_ALIGNMENT_LEFT, -1, 32, MUTED.lerp(INK, glow))



func _draw_pointer(overlay: Control) -> void :
	if _video.stream == null:
		return
	var at: = _video.stream_position
	var pointers: Array = _steps[_tab].get("pointers_" + Lexicon.language(), _steps[_tab].get("pointers", []))
	for index in pointers.size():
		var pointer: Dictionary = pointers[index]

		var hold: = POINTER_HOLD_S
		if index + 1 < pointers.size():
			hold = minf(hold, float(pointers[index + 1]["at"]) - float(pointer["at"]))
		var age: = at - float(pointer["at"])
		if age < -0.15 or age > hold:
			continue
		var r: Array = pointer["rect"]
		var rect: = Rect2(float(r[0]) * overlay.size.x, float(r[1]) * overlay.size.y, float(r[2]) * overlay.size.x, 
			float(r[3]) * overlay.size.y)
		var fade: = clampf((age + 0.15) / 0.2, 0.0, 1.0) * clampf((hold - age) / 0.3, 0.0, 1.0)
		var pulse: = 0.5 + 0.5 * sin(_clock * 7.0)
		var center: = rect.get_center()
		var radius: = rect.size.length() * 0.5
		overlay.draw_circle(center, radius * (1.35 + 0.12 * pulse), Color(GOLD, 0.16 * fade))
		var ring: = _octagon(center, radius * (1.18 + 0.08 * pulse))
		ring.append(ring[0])
		overlay.draw_polyline(ring, Color(GOLD, fade), 5.0, true)

		var tip: = center + Vector2(0, - radius * 1.4 - 8.0 - 10.0 * pulse)
		overlay.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-20, -28), tip + Vector2(20, -28)]), Color(GOLD, fade))
		overlay.draw_rect(Rect2(tip + Vector2(-6, -62), Vector2(12, 36)), Color(GOLD, fade))


func _draw_voice_note(rect: Rect2) -> void :
	var note: = _voice_note()
	_board.draw_colored_polygon(_chamfer(rect, 16), CARD)
	_board.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3)), Color(ACCENT, 0.8))
	_board.draw_string(_font_bold, rect.position + Vector2(24, 42), tr(String(note["title"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ACCENT)
	var y: = rect.position.y + 78
	for line in _wrap(tr(String(note["text"])), 21, rect.size.x - 48):
		_board.draw_string(_font, Vector2(rect.position.x + 24, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, INK)
		y += 28



func _voice_note() -> Dictionary:
	var notes: Dictionary = _data["voice"]
	if OS.has_feature("android"):
		return notes["android_online"] if AndroidSpeechEngine.android_api() < 31 else notes["android_offline"]
	return notes["pc"]


func _wrap(text: String, size_px: int, width: float) -> PackedStringArray:
	var lines: = PackedStringArray()
	var line: = ""
	for word in text.split(" "):
		var attempt: = word if line.is_empty() else line + " " + word
		if _font.get_string_size(attempt, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x > width and not line.is_empty():
			lines.append(line)
			line = word
		else:
			line = attempt
	if not line.is_empty():
		lines.append(line)
	return lines


static func _chamfer(rect: Rect2, cut: float) -> PackedVector2Array:
	return PackedVector2Array([rect.position + Vector2(cut, 0), Vector2(rect.end.x, rect.position.y), 
		Vector2(rect.end.x, rect.end.y - cut), Vector2(rect.end.x - cut, rect.end.y), Vector2(rect.position.x, rect.end.y), 
		Vector2(rect.position.x, rect.position.y + cut)])


static func _octagon(center: Vector2, radius: float) -> PackedVector2Array:
	var points: = PackedVector2Array()
	for i in 8:
		points.append(center + Vector2.from_angle(TAU * (i + 0.5) / 8.0) * radius)
	return points
