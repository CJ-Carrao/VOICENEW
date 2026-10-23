class_name IntroBlocks
extends Node2D










class Formation:
	var points: = PackedVector2Array()
	var colors: = PackedColorArray()
	var coverage: = PackedFloat32Array()
	var groups: = PackedInt32Array()
	var cell: float = 6.0
	var size: = Vector2.ZERO


var count: int = 0

var gap: float = 0.16

var _mm: MultiMesh
var _buffer: = PackedFloat32Array()
var _from: = PackedVector2Array()
var _ctrl: = PackedVector2Array()
var _to: = PackedVector2Array()
var _t0: = PackedFloat32Array()
var _dur: = PackedFloat32Array()
var _size_from: = PackedFloat32Array()
var _size_to: = PackedFloat32Array()
var _color_from: = PackedColorArray()
var _color_to: = PackedColorArray()
var _spin: = PackedFloat32Array()
var _overshoot: = PackedFloat32Array()

var _vanish_at: = PackedFloat32Array()
var _rng: = RandomNumberGenerator.new()


var _finale: bool = false
var _home: = PackedVector2Array()
var _home_size: = PackedFloat32Array()
var _home_color: = PackedColorArray()
var _scatter_at: = PackedFloat32Array()
var _scatter_s: float = 0.7
var _depart: = PackedFloat32Array()
var _orbit_r: = PackedFloat32Array()
var _orbit_a: = PackedFloat32Array()
var _group: = PackedInt32Array()
var _orbit: Dictionary = {}
var _ball: Dictionary = {}
var _ball_center: = Vector2.ZERO
var _slam_s: float = 0.0
var _lav_cell: float = 6.0
var _surface: Dictionary = {}
var _anticipation_at: float = INF
var _sample_pos: = Vector2.ZERO
var _sample_size: float = 0.0
var _sample_color: = Color.WHITE
var _sample_rot: float = 0.0
var _orbit_speed: float = 2.1
var _orbit_squash: float = 0.36
var _rear_size: float = 0.64
var _front_size: float = 1.22
var _rear_light: float = 0.38
var _front_light: float = 1.0
var _quote_points: = PackedVector2Array()
var _quote_cfg: Dictionary = {}
var _quote_until_s: float = 0.0
var _quote_color: = Color.WHITE
var _matter_color: = Color.WHITE
var _source_start: float = 0.0
var _source_end: float = 0.0
var _source_fade: float = 0.0
var _source_piece: float = 0.0
var _source_sphere_piece: float = 0.0
var _quote_controls: = PackedVector2Array()
var _quote_delays: = PackedFloat32Array()
var _quote_inv_duration: = PackedFloat32Array()


const MOTION_FIELDS: Array[String] = ["_from", "_ctrl", "_to", "_t0", "_dur", "_size_from", "_size_to", 
	"_color_from", "_color_to", "_spin", "_overshoot", "_vanish_at", "_vanish_s", "_finale", "_home", 
	"_home_size", "_home_color", "_scatter_at", "_scatter_s", "_depart", "_orbit_r", "_orbit_a", "_group", 
	"_orbit", "_ball", "_ball_center", "_slam_s", "_lav_cell", "_orbit_speed", "_orbit_squash"]


func capture_plan() -> Dictionary:
	var plan: Dictionary = {}
	for field: String in MOTION_FIELDS:
		var value: Variant = get(field)

		if typeof(value) in [TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_INT32_ARRAY]:
			plan[field] = value.duplicate()
		else:
			plan[field] = value
	return plan


func use_plan(plan: Dictionary) -> void :
	for field: String in MOTION_FIELDS:
		set(field, plan[field])



func configure_quote_source(mask: Image, config: Dictionary, origin: Vector2, quote_scale: float, 
		accent: Color, matter: Color, until_s: float) -> void :
	if mask == null or mask.is_empty():
		push_error("Máscara da frase ausente. Execute generate_quote_mask.gd e reimporte o projeto.")
		return
	_quote_cfg = config
	_quote_until_s = until_s
	_quote_color = accent
	_matter_color = matter
	_source_start = float(config["start_s"])
	_source_end = _source_start + float(config["fly_s"])
	_source_fade = float(config["text_fade_s"])
	_source_piece = float(config["piece_px"])
	_source_sphere_piece = float(config["sphere_piece_px"])
	var pixels: = PackedVector2Array()
	var density: = float(config["mask_scale"])
	var padding: = Vector2.ONE * float(config["mask_padding_px"])
	for y in mask.get_height():
		for x in mask.get_width():
			if mask.get_pixel(x, y).a > float(config["mask_threshold"]):
				pixels.append((Vector2(x, y) / density - padding + origin) * quote_scale)
	if pixels.is_empty():
		_quote_cfg = {}
		push_error("A máscara da frase não contém letras visíveis.")
		return
	_quote_points.resize(count)
	_quote_controls.resize(count)
	_quote_delays.resize(count)
	_quote_inv_duration.resize(count)
	for i in count:
		_quote_points[i] = pixels[mini(int(float(i) * pixels.size() / count), pixels.size() - 1)]
		_quote_controls[i] = _quote_points[i].lerp(_from[i], 0.45) + Vector2(0.0, - float(config["lift_px"]))
		_quote_delays[i] = fposmod(float(i) * 0.61803398875, 1.0) * float(config["scatter_s"])
		_quote_inv_duration[i] = 1.0 / maxf(float(config["fly_s"]) - _quote_delays[i], 0.01)


func _sample_quote_source(i: int, t: float) -> void :
	if t >= _source_end:
		_set_sample(_from[i], _source_sphere_piece, _matter_color, _spin[i])
		return
	var u: = clampf((t - _source_start - _quote_delays[i]) * _quote_inv_duration[i], 0.0, 1.0)
	var color: = _quote_color.lerp(_matter_color, u)
	color.a = _smooth01((t - _source_start) / _source_fade)
	_set_sample(_bezier(_quote_points[i], _quote_controls[i], _from[i], _smooth01(u)), 
		lerpf(_source_piece, _source_sphere_piece, u), color, _spin[i] * u)


func _init(block_count: int) -> void :
	count = block_count
	_rng.seed = 1789
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_2D
	_mm.use_colors = true
	var quad: = QuadMesh.new()
	quad.size = Vector2.ONE
	_mm.mesh = quad
	_mm.instance_count = count
	var instance: = MultiMeshInstance2D.new()
	instance.multimesh = _mm
	add_child(instance)
	_buffer.resize(count * 12)

	_from.resize(count)
	_ctrl.resize(count)
	_to.resize(count)
	_t0.resize(count)
	_dur.resize(count)
	_size_from.resize(count)
	_size_to.resize(count)
	_spin.resize(count)
	_overshoot.resize(count)
	_vanish_at.resize(count)
	_color_from.resize(count)
	_color_to.resize(count)
	_vanish_at.fill(INF)







static func sample(image: Image, display: Vector2, target: int, threshold: float, tone: bool) -> Formation:
	var base: = image.duplicate() as Image
	base.convert(Image.FORMAT_RGBA8)

	var fit: = minf(1.0, display.x * 3.0 / float(base.get_width()))
	if fit < 1.0:
		base.resize(maxi(1, roundi(base.get_width() * fit)), maxi(1, roundi(base.get_height() * fit)), Image.INTERPOLATE_CUBIC)
	base.generate_mipmaps()
	var lo: = 1.5
	var hi: = 40.0
	var best: Formation = null
	for _i in 16:
		var cell: = (lo + hi) * 0.5
		var found: = _cells(base, display, cell, threshold, tone)
		if found.points.size() >= target:
			best = found
			lo = cell
		else:
			hi = cell
	if best == null:
		best = _cells(base, display, lo, threshold, tone)
	return _trim(best, target)


static func _cells(base: Image, display: Vector2, cell: float, threshold: float, tone: bool) -> Formation:
	var w: = maxi(1, ceili(display.x / cell))
	var h: = maxi(1, ceili(display.y / cell))
	var small: = base.duplicate() as Image
	small.resize(w, h, Image.INTERPOLATE_TRILINEAR)
	var cw: = display.x / float(w)
	var ch: = display.y / float(h)
	var out: = Formation.new()
	out.cell = minf(cw, ch)
	out.size = display
	for y in h:
		for x in w:
			var c: = small.get_pixel(x, y)
			if c.a < threshold:
				continue
			out.points.append(Vector2((x + 0.5) * cw - display.x * 0.5, (y + 0.5) * ch - display.y * 0.5))
			var v: = clampf(c.a * 1.08, 0.0, 1.0)
			out.colors.append(Color(v, v, v) if tone else Color(c.r, c.g, c.b))
			out.coverage.append(c.a)
	return out



static func _trim(found: Formation, target: int) -> Formation:
	var n: = found.points.size()
	if n <= target:
		return found
	var order: = range(n)
	order.sort_custom( func(a: int, b: int) -> bool: return found.coverage[a] > found.coverage[b])
	var keep: = order.slice(0, target)
	keep.sort()
	var out: = Formation.new()
	out.cell = found.cell
	out.size = found.size
	for i: int in keep:
		out.points.append(found.points[i])
		out.colors.append(found.colors[i])
		out.coverage.append(found.coverage[i])
	return out







func assemble(f: Formation, start: float, source: Vector2, cfg: Dictionary, matter: Color) -> Dictionary:
	_finale = false
	var anchor: = Vector2(0.0, f.size.y * 0.5)
	var order: = range(count)
	order.sort_custom( func(a: int, b: int) -> bool: return f.points[a].distance_to(anchor) < f.points[b].distance_to(anchor))
	var flight: Array = cfg.get("flight_s", [0.3, 0.55])
	var span: = float(cfg.get("launch_s", 0.8))
	var far: = f.size.length() * 0.5
	var launches: = PackedFloat32Array()
	var last_launch: = start
	for rank in count:
		var i: int = order[rank]
		var final: = rank == count - 1
		var to: = f.points[i]
		var from: = source + Vector2(_rng.randf_range(-12.0, 12.0), _rng.randf_range(-8.0, 8.0))
		var distance: = from.distance_to(to)
		var dur: = lerpf(float(flight[0]), float(flight[1]), clampf(distance / maxf(far * 2.0, 1.0), 0.0, 1.0))
		var t: = start + span * pow(float(rank) / float(maxi(count - 2, 1)), 0.6)
		var lift: = 50.0 + distance * 0.35
		var overshoot: = 1.3
		if final:
			t = last_launch + float(cfg.get("final_pause_s", 0.2))
			dur *= float(cfg.get("final_flight_mult", 1.5))
			lift *= 1.9
			overshoot = float(cfg.get("final_grow", 3.0))
		else:
			last_launch = maxf(last_launch, t)
		var side: = Vector2(_rng.randf_range(-0.35, 0.35) * distance, 0.0)
		_set_move(i, from, from.lerp(to, 0.5) + Vector2(0.0, - lift) + side, to, t, dur, 0.0, f.cell, matter, f.colors[i], 
			_rng.randf_range(-5.0, 5.0), overshoot)
		launches.append(t)
	var last: int = order[count - 1]
	return {"launches": launches, "final_land": _t0[last] + _dur[last], "final_at": f.points[last], "final": last, 
		"final_launch": _t0[last]}



func block_position(i: int, t: float) -> Vector2:
	var u: = clampf((t - _t0[i]) / _dur[i], 0.0, 1.0)
	return _bezier(_from[i], _ctrl[i], _to[i], 1.0 - pow(1.0 - u, 3.0))




func morph(f: Formation, start: float, cfg: Dictionary) -> float:
	_finale = false
	var old_order: = _row_major(_to)
	var new_order: = _row_major(f.points)
	var flight: Array = cfg.get("flight_s", [0.45, 0.75])
	var wave: = float(cfg.get("wave_s", 0.5))
	var end: = start
	for rank in count:
		var i: int = old_order[rank]
		var j: int = new_order[rank]
		var from: = _to[i]
		var to: = f.points[j]
		var row: = clampf(to.y / maxf(f.size.y, 1.0) + 0.5, 0.0, 1.0)
		var t: = start + wave * row + _rng.randf_range(0.0, 0.06)
		var dur: = _rng.randf_range(float(flight[0]), float(flight[1]))
		var swirl: = (to - from).orthogonal().normalized() * (40.0 + from.distance_to(to) * 0.25)
		_set_move(i, from, from.lerp(to, 0.5) + swirl, to, t, dur, _size_to[i], f.cell, _color_to[i], f.colors[j], 
			_rng.randf_range( - PI, PI), 1.12)
		end = maxf(end, t + dur)
	return end




func finale(f: Formation, start: float, cfg: Dictionary, letter_times: PackedFloat32Array) -> void :
	_finale = true
	_orbit = cfg.get("orbit", {})
	_orbit_speed = float(_orbit["speed"])
	_orbit_squash = float(_orbit["squash"])
	_ball = cfg.get("ball", {})
	_slam_s = float(cfg.get("slam_s", start + 4.0))
	_scatter_s = float(cfg.get("scatter_s", 0.7))
	_lav_cell = f.cell
	var dive: = float(cfg.get("dive_s", 0.42))

	var old_order: = range(count)
	old_order.sort_custom( func(a: int, b: int) -> bool: return _to[a].x < _to[b].x)
	var new_order: = range(count)
	new_order.sort_custom( func(a: int, b: int) -> bool:
		return f.groups[a] < f.groups[b] or (f.groups[a] == f.groups[b] and f.points[a].x < f.points[b].x))
	_home = _to.duplicate()
	_home_size = _size_to.duplicate()
	_home_color = _color_to.duplicate()
	_scatter_at.resize(count)
	_depart.resize(count)
	_orbit_r.resize(count)
	_orbit_a.resize(count)
	_group.resize(count)
	var rx: Array = _orbit.get("rx", [330.0, 560.0])
	var orange_points: = PackedVector2Array()
	for rank in count:
		var i: int = old_order[rank]
		var j: int = new_order[rank]
		var group: = f.groups[j]
		_group[i] = group
		_to[i] = f.points[j]
		_color_to[i] = f.colors[j]
		_size_to[i] = f.cell
		_scatter_at[i] = start + _rng.randf_range(0.0, 0.18)
		_orbit_r[i] = _rng.randf_range(float(rx[0]), float(rx[1]))
		_orbit_a[i] = _home[i].angle() if _home[i].length() > 1.0 else _rng.randf() * TAU
		_spin[i] = _rng.randf_range(-6.0, 6.0)
		_vanish_at[i] = INF
		if group < letter_times.size():
			var land: = letter_times[group] - _rng.randf_range(0.0, 0.035)
			_depart[i] = land - dive - _rng.randf_range(0.0, 0.1)
			_t0[i] = land
		else:
			orange_points.append(f.points[j])
			_depart[i] = _slam_s - float(_ball.get("drop_s", 0.17))
			_t0[i] = _slam_s

	var center: = Vector2.ZERO
	for p in orange_points:
		center += p
	center /= maxf(orange_points.size(), 1.0)
	_ball_center = center + Vector2(0.0, - float(_ball.get("above", 150.0)))



func ball_center(t: float) -> Vector2:
	var rise: = float(_ball.get("rise", 40.0)) * _smooth01((t - float(_ball.get("rise_at_s", _slam_s - 0.4))) / 0.3)
	return _ball_center + Vector2(0.0, - rise)



func vanish_group(group: int, at: float, fade_s: float) -> void :
	for i in count:
		if _group.size() == count and _group[i] == group:
			_vanish_at[i] = at
	_vanish_s = fade_s



func vanish_all(at: float, fade_s: float) -> void :
	_vanish_at.fill(at)
	_vanish_s = fade_s



func show_all() -> void :
	_vanish_at.fill(INF)


var _vanish_s: float = 0.3


func _set_move(i: int, from: Vector2, ctrl: Vector2, to: Vector2, t0: float, dur: float, size_from: float, 
		size_to: float, color_from: Color, color_to: Color, spin: float, overshoot: float) -> void :
	_from[i] = from
	_ctrl[i] = ctrl
	_to[i] = to
	_t0[i] = t0
	_dur[i] = maxf(dur, 0.01)
	_size_from[i] = size_from
	_size_to[i] = size_to
	_color_from[i] = color_from
	_color_to[i] = color_to
	_spin[i] = spin
	_overshoot[i] = overshoot
	_vanish_at[i] = INF


static func _row_major(points: PackedVector2Array) -> Array:
	var order: = range(points.size())
	order.sort_custom( func(a: int, b: int) -> bool:
		return points[a].y < points[b].y - 0.01 or (absf(points[a].y - points[b].y) <= 0.01 and points[a].x < points[b].x))
	return order





func update(t: float) -> void :
	var b: = 0
	var quote_active: = not _quote_cfg.is_empty() and t >= _source_start and t < _quote_until_s
	for i in count:
		var pos: Vector2
		var size: float
		var color: Color
		var rot: float
		if _finale:
			_sample_finale(i, t)
			pos = _sample_pos
			size = _sample_size
			color = _sample_color
			rot = _sample_rot
		elif quote_active and t < _t0[i]:
			_sample_quote_source(i, t)
			pos = _sample_pos
			size = _sample_size
			color = _sample_color
			rot = _sample_rot
		else:
			var u: = clampf((t - _t0[i]) / _dur[i], 0.0, 1.0)
			if t < _t0[i]:
				u = 0.0
			var e: = 1.0 - pow(1.0 - u, 3.0)
			pos = _bezier(_from[i], _ctrl[i], _to[i], e)
			var grow: = 1.0 + (_overshoot[i] - 1.0) * sin(PI * clampf(u * 1.12, 0.0, 1.0))
			var initial_size: = _size_from[i]
			if quote_active and t >= _t0[i]:
				initial_size = _source_sphere_piece
			size = lerpf(initial_size, _size_to[i], e) * grow
			color = _color_from[i].lerp(_color_to[i], _smooth01(u * 1.4 - 0.2))
			rot = _spin[i] * (1.0 - e)
		if not _finale and not _surface.is_empty():
			var anticipation: = _smooth01((t - _anticipation_at + float(_surface["anticipation_s"])) / float(_surface["anticipation_s"]))
			pos *= lerpf(1.0, float(_surface["anticipation_scale"]), anticipation)
			var landed_age: = t - _t0[i] - _dur[i]
			if landed_age >= 0.0 and landed_age < 0.5:
				pos += (_to[i] - _from[i]).normalized() * float(_surface["settle_px"]) * exp( - float(_surface["settle_decay"]) * landed_age) * sin(landed_age * TAU * float(_surface["settle_hz"]))
		size *= 1.0 - _smooth01((t - _vanish_at[i]) / maxf(_vanish_s, 0.001))
		var side: = maxf(size, 0.0) * (1.0 - gap)
		var c: = cos(rot) * side
		var s: = sin(rot) * side
		_buffer[b] = c
		_buffer[b + 1] = - s
		_buffer[b + 2] = 0.0
		_buffer[b + 3] = pos.x
		_buffer[b + 4] = s
		_buffer[b + 5] = c
		_buffer[b + 6] = 0.0
		_buffer[b + 7] = pos.y
		_buffer[b + 8] = color.r
		_buffer[b + 9] = color.g
		_buffer[b + 10] = color.b
		_buffer[b + 11] = color.a
		b += 12
	_mm.buffer = _buffer



func _sample_finale(i: int, t: float) -> void :
	var orange: = _group[i] >= 7
	var depth: = 0.5 + 0.5 * sin(_orbit_a[i] + _orbit_speed * t)
	var orbit_size: = _lav_cell * (1.25 if orange else lerpf(_rear_size, _front_size, depth))
	var orbit_pos: = _ball_point(i, t) if orange else _orbit_point(i, t)
	var orbit_color: = _color_to[i] if orange else _home_color[i].lerp(_color_to[i], 0.6) * lerpf(_rear_light, _front_light, depth)
	orbit_color.a = 1.0
	if orange:
		var charge: = _smooth01((t - float(_ball["rise_at_s"])) / maxf(_slam_s - float(_ball["rise_at_s"]), 0.01))
		orbit_color = orbit_color.lightened(float(_surface["ball_heat"]) * charge)
	if t < _scatter_at[i]:
		var release: = _smooth01((t - _anticipation_at) / maxf(_scatter_at[i] - _anticipation_at, 0.01))
		_set_sample(_home[i] * lerpf(float(_surface["anticipation_scale"]), 1.0, release), _home_size[i], _home_color[i], 0.0)
		return
	if t < _scatter_at[i] + _scatter_s:
		var e: = _smooth01((t - _scatter_at[i]) / _scatter_s)
		var burst: = _home[i] + _home[i].normalized() * 90.0 * sin(PI * e)
		_set_sample(burst.lerp(orbit_pos, e), lerpf(_home_size[i], orbit_size, e), _home_color[i].lerp(orbit_color, e), _spin[i] * e)
		return
	if t < _depart[i]:
		_set_sample(orbit_pos, orbit_size, orbit_color, _spin[i] + t * 2.0)
		return
	var start: = _ball_point(i, _depart[i]) if orange else _orbit_point(i, _depart[i])
	var to: = _to[i]
	var u: = clampf((t - _depart[i]) / maxf(_t0[i] - _depart[i], 0.01), 0.0, 1.0)
	var e2: = u * u
	var ctrl: = start.lerp(to, 0.35) + (Vector2(0.0, -60.0) if not orange else Vector2.ZERO)
	_set_sample(_bezier(start, ctrl, to, e2), lerpf(orbit_size, _size_to[i], e2), orbit_color.lerp(_color_to[i], u), (_spin[i] + _depart[i] * 2.0) * (1.0 - e2))


func _set_sample(at: Vector2, piece_size: float, color: Color, angle: float) -> void :
	_sample_pos = at
	_sample_size = piece_size
	_sample_color = color
	_sample_rot = angle


func _orbit_point(i: int, t: float) -> Vector2:
	var angle: = _orbit_a[i] + _orbit_speed * t
	var r: = _orbit_r[i]
	return Vector2(cos(angle) * r, sin(angle) * r * _orbit_squash)


func _ball_point(i: int, t: float) -> Vector2:
	var radius: = float(_ball.get("radius", 30.0)) * (0.35 + 0.65 * fposmod(_orbit_r[i] * 0.0137, 1.0))
	var angle: = _orbit_a[i] * 3.0 + float(_ball.get("speed", 3.0)) * t
	var tilt: = _orbit_r[i] * 0.071
	var charge: = _smooth01((t - float(_ball["rise_at_s"])) / maxf(_slam_s - float(_ball["rise_at_s"]), 0.01))
	radius *= 1.0 - float(_surface["ball_compress"]) * charge
	return ball_center(t) + Vector2(cos(angle) * radius, sin(angle + tilt) * radius * 0.85)


static func _bezier(a: Vector2, c: Vector2, b: Vector2, e: float) -> Vector2:
	return a.lerp(c, e).lerp(c.lerp(b, e), e)


static func _smooth01(x: float) -> float:
	var v: = clampf(x, 0.0, 1.0)
	return v * v * (3.0 - 2.0 * v)


func configure_surface(config: Dictionary, anticipation_at: float) -> void :
	_surface = config
	_anticipation_at = anticipation_at
	_rear_size = float(config["rear_size"])
	_front_size = float(config["front_size"])
	_rear_light = float(config["rear_light"])
	_front_light = float(config["front_light"])
	var surface: = ShaderMaterial.new()
	surface.shader = load("res://scenes/intro/block_surface.gdshader")
	for key: String in ["bevel", "highlight", "shade"]:
		surface.set_shader_parameter(key, float(config[key]))
	(get_child(0) as MultiMeshInstance2D).material = surface
