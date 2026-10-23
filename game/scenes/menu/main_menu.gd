class_name MainMenu
extends Control










signal chosen(id: String)

signal landed(at: Vector2, strength: float, note: int)

signal moved

const ORDER: Array[String] = ["create", "customize", "practice", "settings", "quit", "voice"]
const REBUILD_SECONDS: = 0.52
const DISMISS_SECONDS: = 0.22

var cfg: Dictionary = {}

var ready_for_input: bool = false

var music_time: float = 0.0

var _font_big: FontVariation
var _font: FontVariation
var _font_small: FontVariation
var _selected: int = -1
var _items: Dictionary = {}
var _t: float = -1.0
var _last_t: float = -1.0
var _k: float = 1.0
var _colors: Dictionary = {}
var _layout: Dictionary = {}
var _times: Dictionary = {}
var _press: Dictionary = {}
var _polish: Dictionary = {}
var _interactive: bool = false
var _hover_at: float = -100.0

var _motion: = ""
var _motion_age: = 0.0
var _motion_start: Dictionary = {}


func setup(config: Dictionary, colors: Dictionary, font_path: String) -> void :
	cfg = config
	_colors = colors
	_layout = cfg["layout"]
	_times = cfg["times"]
	_polish = cfg["polish"]
	var base: = load(font_path) as Font
	_font_big = _variation(base, 800, 0)
	_font = _variation(base, 700, 0)
	_font_small = _variation(base, 700, 2)
	var labels: Dictionary = cfg["labels"]
	for id in ORDER:

		_items[id] = {"label": String(labels[id]), "sel": 0.0, "vel": 0.0, "rect": Rect2()}
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func _variation(base: Font, weight: int, spacing: int) -> FontVariation:
	var font: = FontVariation.new()
	font.base_font = base
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	font.spacing_glyph = spacing
	return font



func logo_slot() -> Dictionary:
	var slot: Array = _layout["logo"]
	var rect: = Rect2(float(slot[0]), float(slot[1]), float(slot[2]) - float(slot[0]), float(slot[3]) - float(slot[1]))
	var center: = rect.get_center() * _k
	if not _motion.is_empty():
		center.x -= float(_layout["panel_edge_x"]) * _k * 1.25 * (1.0 - minf(_arrive("logo"), 1.0))
	return {"center": center, "width": rect.size.x * _k}




func rebuild() -> void :
	if cfg.is_empty() or (_motion == "rebuild" and visible): return
	var from_outro: = _motion == "dismiss" and visible
	var starts: = _capture_arrivals() if from_outro else {}
	_motion_start = starts
	_motion = "rebuild"
	_motion_age = 0.0
	ready_for_input = false
	_interactive = true
	_press.clear()
	show()
	queue_redraw()




func dismiss() -> void :
	if cfg.is_empty() or _motion in ["dismiss", "dismissed"]: return
	_motion_start = _capture_arrivals()
	_motion = "dismiss" if visible else "dismissed"
	_motion_age = 0.0
	ready_for_input = false
	queue_redraw()


func _capture_arrivals() -> Dictionary:
	var starts: = {}
	for key: String in ["panel", "logo", "ignite"] + ORDER:
		starts[key] = clampf(_arrive(key), 0.0, 1.0)
	return starts


func _update_motion(delta: float) -> void :
	if _motion not in ["rebuild", "dismiss"]: return
	_motion_age += maxf(0.0, delta)
	var duration: = REBUILD_SECONDS if _motion == "rebuild" else DISMISS_SECONDS
	if _motion_age >= duration:
		if _motion == "dismiss":
			_motion = "dismissed"
			hide()
		else:
			_motion = ""
		_motion_start.clear()



func update(t: float, delta: float) -> void :
	_t = t
	_k = get_viewport_rect().size.y / float(_layout["height"])
	var lock: = float(_times["lock_s"])
	if _last_t >= 0.0 and _motion.is_empty():
		_emit_landings(_last_t, t)
	_last_t = t
	_update_motion(delta)
	if t >= lock and _selected < 0:
		_selected = 0
	ready_for_input = t >= lock + 0.05 and _motion.is_empty() and visible
	for i in ORDER.size():
		var item: Dictionary = _items[ORDER[i]]


		var goal: = 1.0 if i == _selected else 0.0
		if not _interactive:

			var age: = clampf(t - lock, 0.0, float(_polish["auto_settle_s"]))
			var omega: = TAU * float(_polish["selection_hz"])
			var zeta: = float(_polish["selection_damping"])
			var damped: = omega * sqrt(1.0 - zeta * zeta)
			var fall: = exp( - zeta * omega * age)
			item["sel"] = goal * (1.0 - fall * (cos(damped * age) + zeta * omega / damped * sin(damped * age)))
			item["vel"] = goal * fall * omega * omega / damped * sin(damped * age)
		else:
			var spring: = RobotSpring.bouncy(Vector2(float(item["sel"]), float(item["vel"])), goal, float(_polish["selection_hz"]), float(_polish["selection_damping"]), minf(delta, 0.25))
			item["sel"] = spring.x
			item["vel"] = spring.y
	queue_redraw()


func _emit_landings(from: float, to: float) -> void :
	var lands: Dictionary = _times["lands"]
	var note: = 0
	for key: String in lands:
		var at: = float(lands[key])
		if at > from and at <= to:
			landed.emit(_land_point(key), 1.0 if key == "ignite" else (0.55 if key in ["logo", "quit"] else 0.3), note)
		note += 1


func _land_point(key: String) -> Vector2:
	if _items.has(key):
		var rect: Rect2 = _items[key]["rect"]
		return Vector2(rect.end.x, rect.get_center().y)
	if key == "ignite":
		var rect: Rect2 = _items["create"]["rect"]
		return rect.get_center()
	if key == "panel":
		return Vector2(float(_layout["panel_edge_x"]) * _k, get_viewport_rect().size.y * 0.5)
	return logo_slot()["center"]



func _arrive(key: String) -> float:
	if _motion == "dismissed": return 0.0
	if _motion == "rebuild":
		var rebuild_delay: = 0.0
		var rebuild_duration: = 0.3
		if key == "logo": rebuild_delay = 0.025
		elif key == "ignite":
			rebuild_delay = 0.22
			rebuild_duration = 0.28
		elif ORDER.has(key):
			rebuild_delay = 0.07 + float(ORDER.find(key)) * 0.035
			rebuild_duration = 0.23
		var rebuild_u: = clampf((_motion_age - rebuild_delay) / rebuild_duration, 0.0, 1.0)
		var arrival: = 1.0 - pow(1.0 - rebuild_u, 3.0) + 0.045 * sin(PI * rebuild_u)
		return lerpf(float(_motion_start.get(key, 0.0)), 1.0, arrival)
	if _motion == "dismiss":
		var dismiss_delay: = 0.045 if key in ["panel", "logo", "ignite"] else float(maxi(0, ORDER.find(key))) * 0.007
		var dismiss_duration: = DISMISS_SECONDS - dismiss_delay
		var dismiss_u: = clampf((_motion_age - dismiss_delay) / dismiss_duration, 0.0, 1.0)
		return float(_motion_start.get(key, 1.0)) * (1.0 - dismiss_u * dismiss_u * (3.0 - 2.0 * dismiss_u))
	var land: = float(_times["lands"].get(key, 0.0))
	var fly: = float(_times.get("fly_s", 0.24))
	var u: = clampf((_t - (land - fly)) / fly, 0.0, 1.0)
	if u >= 1.0:
		var since: = _t - land
		return 1.0 + 0.06 * exp(-10.0 * since) * sin(since * 30.0)
	return 1.0 - pow(1.0 - u, 3.0)




func _draw() -> void :
	if cfg.is_empty() or _t < float(_times["lands"]["panel"]) - float(_times.get("fly_s", 0.24)) - 0.2:
		return
	var k: = _k
	var panel_in: = _arrive("panel")
	var shift: = - float(_layout["panel_edge_x"]) * k * 1.25 * (1.0 - minf(panel_in, 1.0))
	draw_set_transform(Vector2(shift, 0.0))
	_draw_panel(k)
	draw_set_transform(Vector2.ZERO)
	_draw_buttons(k)
	_draw_voice(k)
	_draw_build_label(k)


func _draw_build_label(k: float) -> void :
	var label: = String(cfg.get("build_label", "Build H-1"))
	var font_size: = maxi(12, roundi(15.0 * k))
	var width: = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var view: = get_viewport_rect().size
	var color: = Color(String(_colors["text_dim"]))
	color.a *= clampf(_arrive("voice"), 0.0, 1.0)
	draw_string(_font, Vector2(view.x - 61.0 * k - width, view.y - 14.0 * k), label, 
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _pts(points: Array, k: float, dx: float = 0.0) -> PackedVector2Array:
	var out: = PackedVector2Array()
	for p: Array in points:
		out.append(Vector2(float(p[0]) * k + dx, float(p[1]) * k))
	return out


func _draw_panel(k: float) -> void :
	var outline: = _pts(_layout["panel"], k)
	var top: = Color(String(_colors["panel_top"]))
	var bottom: = Color(String(_colors["panel_bottom"]))
	var h: = float(_layout["height"]) * k
	var colors: = PackedColorArray()
	for p in outline:
		colors.append(top.lerp(bottom, clampf(p.y / h, 0.0, 1.0)))
	draw_polygon(outline, colors)

	var scan_step: = float(_polish["scan_gap_px"]) * k
	var scan_y: = scan_step
	while scan_y < h:
		var edge_x: = 0.0
		for j in range(1, outline.size() - 1):
			var a: = outline[j]
			var b: = outline[j + 1]
			if b.y > a.y and scan_y >= a.y and scan_y < b.y:
				edge_x = lerpf(a.x, b.x, (scan_y - a.y) / (b.y - a.y))
		if edge_x > 0.0:
			draw_line(Vector2(0, scan_y), Vector2(edge_x, scan_y), Color(1, 1, 1, float(_polish["grain_alpha"])), 1.0)
		scan_y += scan_step

	for plate: Array in _layout.get("plates", []):
		draw_colored_polygon(_pts(plate, k), Color(String(_colors["plate"])))
	var edge: = outline.slice(1, outline.size() - 1)
	draw_polyline(edge, Color(String(_colors["panel_edge"])), maxf(2.0, 3.0 * k), true)

	var ignite: = float(_times["lands"]["ignite"])
	var grow: = clampf((_t - ignite + 0.05) / 0.35, 0.0, 1.0)
	if _motion == "rebuild": grow = clampf(_arrive("ignite"), 0.0, 1.0)
	if grow > 0.0:
		var accent: = Color(String(_colors["accent"]))
		var breathe: = 1.0 - float(_polish["breath_depth"]) * (0.5 - 0.5 * cos((music_time - ignite) * TAU / (float(_times["beat_s"]) * float(_polish["breath_beats"]))))
		accent *= Color(breathe, breathe, breathe, 1.0)
		for strip: Array in _layout["accents"]:
			var line: = _pts(strip, k)
			var lit_line: = _partial(line, 1.0 - pow(1.0 - grow, 3.0))
			draw_polyline(lit_line, Color(accent, float(_polish["rim_alpha"])), float(_layout["accent_w"]) * k * 3.0, true)
			draw_polyline(lit_line, accent, maxf(2.0, float(_layout["accent_w"]) * k), true)


static func _partial(line: PackedVector2Array, f: float) -> PackedVector2Array:
	var total: = 0.0
	for i in range(1, line.size()):
		total += line[i - 1].distance_to(line[i])
	var left: = total * f
	var out: = PackedVector2Array([line[0]])
	for i in range(1, line.size()):
		var seg: = line[i - 1].distance_to(line[i])
		if left >= seg:
			out.append(line[i])
			left -= seg
		else:
			out.append(line[i - 1].lerp(line[i], left / maxf(seg, 0.001)))
			break
	return out



func _chamfered(rect: Rect2, cut_wanted: float) -> PackedVector2Array:
	var cut: = minf(cut_wanted, minf(rect.size.x, rect.size.y) * 0.45)
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.end.y - cut), 
		Vector2(rect.end.x - cut, rect.end.y), Vector2(rect.position.x, rect.end.y)])


func _draw_buttons(k: float) -> void :
	var main: Dictionary = _layout["main"]
	var small: Dictionary = _layout["small"]
	var x: = float(_layout["x"]) * k
	var y: = float(main["y"]) * k
	var accent: = Color(String(_colors["accent"]))
	var accent_top: = Color(String(_colors["accent_top"]))
	var dark: = Color(String(_colors["button"]))
	var ignite: = float(_times["lands"]["ignite"])
	for id in ORDER:
		if id == "voice":
			continue
		var item: Dictionary = _items[id]
		var spec: = small if id == "quit" else main
		if id == "quit":

			var sep_in: = _arrive("quit")
			var sep_y: = y + float(small["sep_gap"]) * k
			var sep_a: = clampf(sep_in, 0.0, 1.0)
			draw_line(Vector2(x + float(small["sep_x"][0]) * k, sep_y), Vector2(x + (float(small["sep_x"][0])\
			+ (float(small["sep_x"][1]) - float(small["sep_x"][0])) * sep_a) * k, sep_y), Color(String(_colors["separator"])), maxf(1.0, 2.0 * k))
			y = sep_y + float(small["sep_after"]) * k
		var sel: = float(item["sel"])
		var height: = lerpf(float(spec["h"]), float(spec["h_sel"]), sel) * k
		var width: = lerpf(float(spec["w"]), float(spec["w_sel"]), sel) * k
		var arrive: = _arrive(id)
		var dx: = - (x + width + 60.0 * k) * (1.0 - minf(arrive, 1.0))
		var press: = _press_amount(id)

		var squash: = (arrive - 1.0) * 1.5 if arrive > 1.0 else 0.0
		var rect: = Rect2(x + dx, y, maxf(width * (1.0 + squash - 0.04 * press), 4.0 * k), height * (1.0 - 0.06 * press))
		rect.position.y += height * 0.03 * press
		item["rect"] = Rect2(x, y, width, height)
		if arrive > 0.0:
			var cut: = float(spec["cut"]) * k
			var outline: = _chamfered(rect, cut)
			var fill: = dark.lerp(accent, clampf(sel, 0.0, 1.0))
			var fill_top: = Color(String(_colors["button_top"])).lerp(accent_top, clampf(sel, 0.0, 1.0))
			var colors: = PackedColorArray()
			for p in outline:
				colors.append(fill_top.lerp(fill, clampf((p.y - rect.position.y) / maxf(rect.size.y, 1.0), 0.0, 1.0)))
			draw_polygon(outline, colors)
			_draw_button_light(outline, id, sel, k)

			var flash: = 0.0
			if id == "create":
				flash = clampf(1.0 - (_t - ignite) / 0.35, 0.0, 1.0) if _t >= ignite else 0.0
			flash = maxf(flash, press * 0.5)
			if flash > 0.0:
				draw_colored_polygon(outline, Color(1, 1, 1, flash * 0.75))
			var text_size: = lerpf(float(spec["text"]), float(spec["text_sel"]), sel) * k
			var font: = _font_big if id != "quit" else _font
			var text_color: = Color(String(_colors["text"])).lerp(Color(String(_colors["text_dim"])), 0.0 if id != "quit" else 1.0 - clampf(sel, 0.0, 1.0))
			var baseline: = rect.position.y + rect.size.y * 0.5 + text_size * 0.36
			draw_string(font, Vector2(rect.position.x + float(spec["pad"]) * k, baseline), String(item["label"]), 
				HORIZONTAL_ALIGNMENT_LEFT, -1, int(text_size), Color(text_color, clampf(arrive * 1.5, 0.0, 1.0)))
		y += height + float(spec["gap"]) * k


func _draw_voice(k: float) -> void :
	var spec: Dictionary = _layout["voice"]
	var item: Dictionary = _items["voice"]
	var arrive: = _arrive("voice")
	if arrive <= 0.0:
		return
	var r: Array = spec["rect"]
	var rect: = Rect2(float(r[0]) * k, float(r[1]) * k, (float(r[2]) - float(r[0])) * k, (float(r[3]) - float(r[1])) * k)
	item["rect"] = rect
	var sel: = clampf(float(item["sel"]), 0.0, 1.2)
	var press: = _press_amount("voice")
	var draw_rect_at: = rect
	draw_rect_at.position.x -= (rect.end.x + 40.0 * k) * (1.0 - minf(arrive, 1.0))
	draw_rect_at = draw_rect_at.grow(sel * 3.0 * k - press * 3.0 * k)
	var cut: = float(spec["cut"]) * k
	var p: = draw_rect_at
	var outline: = PackedVector2Array([p.position + Vector2(cut, 0), Vector2(p.end.x, p.position.y), Vector2(p.end.x, p.end.y - cut), 
		Vector2(p.end.x - cut, p.end.y), Vector2(p.position.x, p.end.y), Vector2(p.position.x, p.position.y + cut)])
	var accent: = Color(String(_colors["accent"]))
	draw_colored_polygon(outline, Color(accent, 0.12 * sel + 0.25 * press))
	var closed: = outline.duplicate()
	closed.append(outline[0])
	draw_polyline(closed, accent, maxf(1.5, 2.2 * k), true)

	var beat: = 0.5 + 0.5 * cos((music_time - float(_times["lands"]["ignite"])) * TAU / float(_times.get("beat_s", 0.594)))
	var dot_r: = float(spec["dot_r"]) * k * (1.0 + 0.18 * beat * clampf(_t - float(_times["lands"]["ignite"]), 0.0, 1.0))
	var dot_at: = Vector2(draw_rect_at.position.x + float(spec["dot_x"]) * k, draw_rect_at.get_center().y)
	draw_circle(dot_at, dot_r * 1.9, Color(accent, 0.18 * beat))
	draw_circle(dot_at, dot_r, accent)
	var text_size: = float(spec["text"]) * k
	draw_string(_font_small, Vector2(draw_rect_at.position.x + float(spec["text_x"]) * k, draw_rect_at.get_center().y + text_size * 0.36), 
		String(item["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(text_size), Color(String(_colors["text"]), clampf(arrive * 1.5, 0.0, 1.0)))


func _press_amount(id: String) -> float:
	if _press.get("id", "") != id:
		return 0.0
	var age: = _t - float(_press["at"])
	return clampf(1.0 - age / 0.18, 0.0, 1.0)




func _unhandled_input(event: InputEvent) -> void :
	if not ready_for_input or not visible:
		return
	if event is InputEventMouseMotion:
		var hit: = _hit((event as InputEventMouseMotion).position)
		if hit >= 0 and hit != _selected:
			_select(hit)
			moved.emit()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed\
	and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var hit: = _hit((event as InputEventMouseButton).position)
		if hit >= 0:
			_select(hit)
			_activate()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_back"):
		_select((_selected + 1) % ORDER.size())
		moved.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
		_select((_selected - 1 + ORDER.size()) % ORDER.size())
		moved.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_activate()
		get_viewport().set_input_as_handled()


func _hit(point: Vector2) -> int:
	for i in ORDER.size():
		var rect: Rect2 = _items[ORDER[i]]["rect"]
		if rect.grow(4.0).has_point(point):
			return i
	return -1


func _activate() -> void :
	if _selected < 0 or not ready_for_input or not visible or not _motion.is_empty():
		return
	var id: = ORDER[_selected]
	_press = {"id": id, "at": _t}
	chosen.emit(id)


func _select(index: int) -> void :
	_interactive = true
	_selected = index
	_hover_at = _t



func timeline_land_point(key: String) -> Vector2:
	var k: = get_viewport_rect().size.y / float(_layout["height"])
	if key == "logo":
		var bounds: Array = _layout["logo"]
		return Vector2((float(bounds[0]) + float(bounds[2])) * 0.5, (float(bounds[1]) + float(bounds[3])) * 0.5) * k
	if key == "panel":
		return Vector2(float(_layout["panel_edge_x"]) * k, get_viewport_rect().size.y * 0.5)
	if key == "voice":
		var bounds: Array = _layout["voice"]["rect"]
		return Vector2(float(bounds[2]), (float(bounds[1]) + float(bounds[3])) * 0.5) * k
	var main: Dictionary = _layout["main"]
	var x: = float(_layout["x"])
	var y: = float(main["y"])
	if key == "ignite":
		return Vector2(x + float(main["w"]) * 0.5, y + float(main["h"]) * 0.5) * k
	if key == "quit":
		y += 4.0 * (float(main["h"]) + float(main["gap"])) + float(_layout["small"]["sep_gap"]) + float(_layout["small"]["sep_after"])
		return Vector2(x + float(_layout["small"]["w"]), y + float(_layout["small"]["h"]) * 0.5) * k
	var index: = ORDER.find(key)
	return Vector2(x + float(main["w"]), y + index * (float(main["h"]) + float(main["gap"])) + float(main["h"]) * 0.5) * k


func _draw_button_light(outline: PackedVector2Array, id: String, selection: float, k: float) -> void :
	var closed: = outline.duplicate()
	closed.append(outline[0])
	var accent: = Color(String(_colors["accent_top"]))
	var amount: = clampf(selection, 0.0, 1.0)
	if amount > 0.001:
		draw_polyline(closed, Color(accent, float(_polish["rim_alpha"]) * amount), 5.0 * k, true)
		var phase: = (_t - _hover_at) / float(_polish["hover_glint_s"])
		if phase >= 0.0 and phase <= 1.0:
			var end: = clampf(phase + float(_polish["glint_width"]), 0.0, 1.0)
			var segment: = _partial(closed, end)
			var head: = _partial(closed, phase)
			var start_index: = maxi(head.size() - 1, 0)
			segment = segment.slice(start_index)
			if segment.size() > 1:
				segment[0] = head[head.size() - 1]
				draw_polyline(segment, Color(1, 1, 1, float(_polish["glint_alpha"]) * sin(PI * phase)), 1.3 * k, true)
	if _press.get("id", "") == id:
		var age: = (_t - float(_press["at"])) / float(_polish["press_spark_s"])
		if age >= 0.0 and age <= 1.0:
			var point: = (outline[1] + outline[2]) * 0.5
			for i in int(_polish["press_spark_count"]):
				var angle: = TAU * float(i) / float(_polish["press_spark_count"])
				var at: = point + Vector2(cos(angle), sin(angle)) * float(_polish["press_spark_distance"]) * k * age
				draw_rect(Rect2(at, Vector2.ONE * float(_polish["press_spark_px"]) * k), Color(accent, 1.0 - age))
