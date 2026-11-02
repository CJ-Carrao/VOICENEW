extends Control







const GLYPHS: = {
	"T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"], 
	"E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"], 
	"S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"], 
	"F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"], 
	"C": ["01111", "10000", "10000", "10000", "10000", "10000", "01111"], 
	"H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"], 
	"A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"], 
	"D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"], 
	"O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"], 
	"L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"], 
}
const PAD: = 3
const LINE_GAP: = 2

var _cfg: Dictionary = {}
var _lines: Array = []
var _cells: Array[Dictionary] = []
var _cols: = 0
var _rows: = 0
var _age: = -1.0

var _cells_age: = -1.0
var _cells_shift: = 0.0

var _leaving: Array[Dictionary] = []
var _leaving_age: = -1.0
var _leaving_cols: = 0
var _leaving_rows: = 0
var _clock: = 0.0
var _glow: GradientTexture2D
var _plate_box: StyleBoxFlat


func setup(config: Dictionary) -> void :
	_cfg = config
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_cells()
	_build_style()



func _build_cells() -> void :
	var config: = _cfg
	_lines = []
	for line: Dictionary in config.get("lines", [{"text": "TESTE", "color": "#fff1dc"}, {"text": "FECHADO", "color": "#ff6a1a"}]):
		var translated: = line.duplicate()
		translated["text"] = tr(String(line["text"])).to_upper()
		_lines.append(translated)
	_cells.clear()
	var rng: = RandomNumberGenerator.new()
	rng.seed = int(config.get("seed", 7))
	var widest: = 0
	for line: Dictionary in _lines:
		widest = maxi(widest, String(line["text"]).length() * 6 - 1)
	_cols = widest + PAD * 2
	_rows = _lines.size() * 7 + (_lines.size() - 1) * LINE_GAP + PAD * 2

	var flicker: = {}
	for item: Array in config.get("flicker", [[1, 2]]):
		flicker["%d:%d" % [int(item[0]), int(item[1])]] = true
	var dead: = {}
	for item: Array in config.get("dead", [[0, 3, 5], [0, 3, 6], [1, 5, 4], [1, 0, 9]]):
		dead["%d:%d:%d" % [int(item[0]), int(item[1]), int(item[2])]] = true
	var letter_order: = 0
	for li in _lines.size():
		var text: = String(_lines[li]["text"])
		var width: = text.length() * 6 - 1
		var x0: = PAD + (widest - width) / 2
		var y0: = PAD + li * (7 + LINE_GAP)
		for ci in text.length():
			var glyph: Array = GLYPHS.get(text[ci], [])
			var index: = 0
			for row in glyph.size():
				for col in 5:
					if String(glyph[row])[col] != "1":
						continue
					var cell: = Vector2i(x0 + ci * 6 + col, y0 + row)
					var state: = 0
					if flicker.has("%d:%d" % [li, ci]):
						state = 1
					if dead.has("%d:%d:%d" % [li, ci, index]):
						state = 2
					_cells.append({"cell": cell, "line": li, "letter": letter_order, "state": state, 
						"from": Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(0.6, 1.4)).normalized() * rng.randf_range(6.0, 14.0), 
						"delay": float(cell.x) * 0.012 + rng.randf_range(0.0, 0.16), "spin": rng.randf_range(-3.0, 3.0)})
					index += 1
			letter_order += 1


func _build_style() -> void :
	var config: = _cfg
	var gradient: = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.35, Color(1, 1, 1, 0.35))
	_glow = GradientTexture2D.new()
	_glow.gradient = gradient
	_glow.fill = GradientTexture2D.FILL_RADIAL
	_glow.fill_from = Vector2(0.5, 0.5)
	_glow.fill_to = Vector2(1.0, 0.5)
	_glow.width = 64
	_glow.height = 64
	_plate_box = StyleBoxFlat.new()
	_plate_box.bg_color = Color(String(config.get("plate", "#16171b")))
	_plate_box.border_color = Color(String(config.get("plate_edge", "#30313a")))
	_plate_box.set_border_width_all(2)
	_plate_box.set_corner_radius_all(10)
	_plate_box.shadow_color = Color(0.35, 0.22, 0.0, 0.35)
	_plate_box.shadow_size = 18
	_plate_box.shadow_offset = Vector2(0, 10)



func update_age(age: float) -> void :
	_age = age
	_cells_age = age - _cells_shift




func reassemble() -> void :
	if _age < 0.0:
		_build_cells()
		return
	_leaving = _cells.duplicate()
	_leaving_cols = _cols
	_leaving_rows = _rows
	_leaving_age = 0.0
	_build_cells()

	_cells_shift = _age + 0.1
	_cells_age = -0.1


func _process(delta: float) -> void :
	_clock += delta
	if _leaving_age >= 0.0:
		_leaving_age += delta
		if _leaving_age > 0.6:
			_leaving_age = -1.0
			_leaving.clear()
	if _age >= 0.0:
		queue_redraw()


func _draw() -> void :
	if _age < 0.0 or _cols == 0:
		return
	var cell: = minf(size.x / _cols, size.y / _rows)
	var board: = Vector2(_cols, _rows) * cell

	var old_cell: = cell
	var old_board: = board
	if _leaving_age >= 0.0:
		old_cell = minf(size.x / _leaving_cols, size.y / _leaving_rows)
		old_board = Vector2(_leaving_cols, _leaving_rows) * old_cell
		board = old_board.lerp(board, _ease_out(clampf((_leaving_age - 0.15) / 0.35, 0.0, 1.0)))
	var origin: = (size - board) * 0.5

	var settle: = _ease_out_back(clampf(_age / 0.45, 0.0, 1.0))
	var plate_at: = origin + Vector2(0, - board.y * 0.25 * (1.0 - settle))
	var plate_alpha: = clampf(_age / 0.2, 0.0, 1.0)
	for side: float in [0.18, 0.82]:
		var x: = plate_at.x + board.x * side
		draw_line(Vector2(x, - get_global_rect().position.y), Vector2(x, plate_at.y + cell), Color(0.08, 0.08, 0.1, 0.85 * plate_alpha), maxf(cell * 0.18, 1.5))
	draw_set_transform(Vector2.ZERO)
	_plate_box.bg_color.a = plate_alpha
	_plate_box.border_color.a = plate_alpha
	draw_style_box(_plate_box, Rect2(plate_at, board))
	for corner: Vector2 in [Vector2(1.2, 1.2), Vector2(_cols - 1.2, 1.2), Vector2(1.2, _rows - 1.2), Vector2(_cols - 1.2, _rows - 1.2)]:
		draw_circle(plate_at + corner * cell, cell * 0.28, Color(0.45, 0.45, 0.5, plate_alpha))
		draw_circle(plate_at + corner * cell, cell * 0.14, Color(0.2, 0.2, 0.24, plate_alpha))
	var surge: = _surge()
	if _leaving_age >= 0.0:
		var old_at: = (size - old_board) * 0.5
		for entry: Dictionary in _leaving:
			_draw_leaving(entry, old_at, old_cell)
	var cells_at: = (size - Vector2(_cols, _rows) * cell) * 0.5 + Vector2(0, plate_at.y - origin.y)
	for entry: Dictionary in _cells:
		_draw_cell(entry, cells_at, cell, surge)



func _draw_leaving(entry: Dictionary, plate_at: Vector2, cell: float) -> void :
	var k: = clampf((_leaving_age - float(entry["delay"]) * 0.4) / 0.35, 0.0, 1.0)
	if k >= 1.0:
		return
	var home: = plate_at + (Vector2(entry["cell"]) + Vector2(0.5, 0.5)) * cell
	var at: = home + (entry["from"] as Vector2) * cell * k * k
	var side: = cell * 0.82 * (1.0 - k)
	var neon: = Color(String(_lines[mini(int(entry["line"]), _lines.size() - 1)].get("color", "#ff6a1a")))
	draw_set_transform(at, float(entry["spin"]) * k, Vector2.ONE)
	draw_rect(Rect2( - Vector2.ONE * side * 0.5, Vector2.ONE * side), neon.darkened(0.6 * k))
	draw_set_transform(Vector2.ZERO)


func _draw_cell(entry: Dictionary, plate_at: Vector2, cell: float, surge: float) -> void :
	var t: = _cells_age - float(entry["delay"]) - 0.25
	if t < 0.0:
		return
	var fly: = clampf(t / 0.38, 0.0, 1.0)
	var pop: = _ease_out_back(fly)
	var home: = plate_at + (Vector2(entry["cell"]) + Vector2(0.5, 0.5)) * cell
	var at: = home + (entry["from"] as Vector2) * cell * (1.0 - _ease_out(fly))
	var side: = cell * 0.82 * clampf(pop, 0.0, 1.25)
	var neon: = Color(String(_lines[int(entry["line"])].get("color", "#ff6a1a")))
	var glass: = neon.darkened(0.78)
	glass.a = 0.95
	var light: = _brightness(entry) * surge

	var core: = glass.lerp(neon.lerp(Color.WHITE, float(_cfg.get("core_white", 0.3))), light)
	if light > 0.02:
		var glow_size: = cell * float(_cfg.get("glow_cells", 4.0)) * (0.85 + 0.15 * light)
		draw_texture_rect(_glow, Rect2(at - Vector2.ONE * glow_size * 0.5, Vector2.ONE * glow_size), false, Color(neon, float(_cfg.get("glow_alpha", 0.42)) * light))
	var spin: = float(entry["spin"]) * (1.0 - fly)
	draw_set_transform(at, spin, Vector2.ONE)
	draw_rect(Rect2( - Vector2.ONE * side * 0.5, Vector2.ONE * side), core)
	if light > 0.4:
		draw_rect(Rect2( - Vector2.ONE * side * 0.32, Vector2.ONE * side * 0.64), Color(1, 1, 1, 0.35 * light))
	draw_set_transform(Vector2.ZERO)



func _brightness(entry: Dictionary) -> float:
	var on_at: = float(_cfg.get("power_on_s", 1.15)) + float(entry["letter"]) * 0.07
	var t: = _cells_age - on_at
	if t < 0.0 or int(entry["state"]) == 2:
		return 0.0

	if t < 0.45:
		return 1.0 if fmod(t, 0.15) < (0.05 if t < 0.3 else 0.12) else 0.15
	var hum: = 0.94 + 0.06 * sin(_clock * 37.0 + float(entry["letter"]) * 1.7)
	if int(entry["state"]) != 1:
		return hum

	var period: = float(_cfg.get("flicker_period_s", 4.3))
	var phase: = fmod(_clock + float(entry["letter"]) * 0.61, period)
	if phase < 0.9:
		var stutter: = sin(phase * 71.0) + sin(phase * 23.0 + 1.3)
		return 0.95 if stutter > 0.6 else (0.05 if stutter < -0.2 else 0.35)
	return 0.72 * hum



func _surge() -> float:
	var period: = float(_cfg.get("surge_period_s", 11.0))
	var phase: = fmod(_clock, period)
	if _age < 2.5 or phase > 0.22:
		return 1.0
	return 0.25 if fmod(phase, 0.1) < 0.05 else 0.7


static func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


static func _ease_out_back(x: float) -> float:
	var c: = 1.70158
	return 1.0 + (c + 1.0) * pow(x - 1.0, 3.0) + c * pow(x - 1.0, 2.0)
