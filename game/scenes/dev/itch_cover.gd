extends Node3D








const FPS: = 50
const LOOP_S: = 11.6

const HOLD_S: = 2.2

const PACE: = 1.6

const PEAKS: = [0.355, 0.72, 1.035, 1.305, 1.545, 1.775, 1.985, 2.2, 2.29, 2.41, 2.52, 2.625]
const BLAST: = 2.76

const WEAPONS: = ["rifle", "shotgun", "pistol", "sniper", "rpg", "minigun", "uzi", "crossbow", "lmg", "desert_eagle", 
	"grenade_launcher", "tommy_gun", "m4"]
const LOGO_DONE_S: = 1.25
const RETURN_S: = 10.0
const ORANGE: = Color("#ff7700")
const DARK: = Color("#14171d")

const WEAPON_LEN: = 7.0
const WEAPON_HEIGHT: = 3.6
const LOGO_WIDTH: = 7.4
const CELLS_ALONG: = 52
const LOGO_BLOCKS: = 1500

const TINT: = 0.0
const CUBE_FILL: = 0.95
const CALM_FPS: = 12.5

var _formations: Array[Dictionary] = []
var _pool: = 0
var _mm: MultiMeshInstance3D
var _env: Environment
var _frame: = 0
var _events: Array[Dictionary] = []
var _rng: = RandomNumberGenerator.new()
var _scatter: = PackedVector3Array()
var _spin_axis: = PackedVector3Array()
var _jitter: = PackedFloat32Array()


func _ready() -> void :
	_rng.seed = 7
	_stage()
	for id: String in WEAPONS:
		_formations.append(_weapon_formation(id))
	_formations.append(_logo_formation())
	for f: Dictionary in _formations:
		_pool = maxi(_pool, (f["pos"] as PackedVector3Array).size())
	for i in _formations.size():
		_formations[i] = _spread(_formations[i])
	for i in _pool:
		var dir: = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1))
		_scatter.append(dir.normalized() * _rng.randf_range(0.4, 1.0))
		_spin_axis.append(Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized())
		_jitter.append(_rng.randf())
	_plan()
	var multimesh: = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	var cube: = BoxMesh.new()
	cube.size = Vector3.ONE
	multimesh.mesh = cube
	multimesh.instance_count = _pool
	_mm = MultiMeshInstance3D.new()
	_mm.multimesh = multimesh
	var material: = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.75
	_mm.material_override = material
	add_child(_mm)
	_draw(0.0)


func _process(_delta: float) -> void :
	_draw(float(_frame) / FPS)
	_frame += 1
	if _frame > roundi(LOOP_S * FPS):
		get_tree().quit()





func _plan() -> void :
	var times: Array[float] = []
	for p: float in PEAKS:
		times.append(HOLD_S + (p - PEAKS[0]) * PACE)
	var blast: = HOLD_S + (BLAST - PEAKS[0]) * PACE
	for i in times.size():
		var next: float = times[i + 1] if i + 1 < times.size() else blast
		_events.append({"from": i, "to": i + 1, "t0": times[i], "d": clampf((next - times[i]) * 0.9, 0.12, 0.62), 
			"amp": 0.9, "kind": "swap"})
	var logo: = _formations.size() - 1
	_events.append({"from": logo - 1, "to": logo, "t0": blast, "d": LOGO_DONE_S, "amp": 3.2, "kind": "blast"})
	_events.append({"from": logo, "to": 0, "t0": RETURN_S, "d": LOOP_S - RETURN_S, "amp": 1.4, "kind": "return"})


func _draw(t: float) -> void :
	_env.background_color = _background(t)
	var current: Dictionary = {}
	for e: Dictionary in _events:
		if t >= float(e["t0"]):
			current = e
	var buffer: = PackedFloat32Array()
	buffer.resize(_pool * 16)
	if current.is_empty() or t >= float(current["t0"]) + float(current["d"]):
		var index: = 0 if current.is_empty() else int(current["to"])


		var calm: = floorf(t * CALM_FPS + 0.0001) / CALM_FPS
		for i in _pool:
			_put(buffer, i, _place(index, i, calm))
	else:
		_morph(buffer, current, t)
	_mm.multimesh.buffer = buffer


func _background(t: float) -> Color:
	var blast: = HOLD_S + (BLAST - PEAKS[0]) * PACE
	var dark: = _smooth(clampf((t - blast - 0.05) / 0.75, 0.0, 1.0)) * (1.0 - _smooth(clampf((t - RETURN_S) / (LOOP_S - RETURN_S - 0.35), 0.0, 1.0)))
	return ORANGE.lerp(DARK, dark)



func _weapon_basis(t: float) -> Basis:
	var phase: = TAU * t / LOOP_S
	var yaw: = - PI * 0.5 + 0.42 * sin(phase * 2.0)
	var pitch: = 0.16 * sin(phase * 3.0 + 0.6)
	var roll: = 0.07 * sin(phase * 2.0 + 1.9)
	return Basis.from_euler(Vector3(pitch, yaw, roll))


func _bob(t: float) -> Vector3:
	return Vector3(0.0, 0.16 * sin(TAU * t / LOOP_S * 4.0), 0.0)



func _place(index: int, i: int, t: float) -> Dictionary:
	var f: Dictionary = _formations[index]
	var logo: = index == _formations.size() - 1
	var basis: = Basis.IDENTITY if logo else _weapon_basis(t)

	var origin: = Vector3(0.0, 0.25, 0.0) + (Vector3.ZERO if logo else _bob(t))
	return {"pos": origin + basis * (f["pos"] as PackedVector3Array)[i], "basis": basis, 
		"color": (f["color"] as PackedColorArray)[i], "size": float(f["size"]) * (f["vis"] as PackedFloat32Array)[i]}


func _morph(buffer: PackedFloat32Array, e: Dictionary, t: float) -> void :
	var span: = float(e["d"])
	var kind: = String(e["kind"])
	for i in _pool:
		var a: = _place(int(e["from"]), i, t)
		var b: = _place(int(e["to"]), i, t)

		var order: = float(i) / float(maxi(_pool - 1, 1))
		var stagger: = 0.32 if kind != "blast" else 0.18
		var start: = (order * 0.75 + _jitter[i] * 0.25) * stagger * span
		var u: = clampf((t - float(e["t0"]) - start) / (span * (1.0 - stagger)), 0.0, 1.0)
		var s: = _smooth(u)
		var amp: = float(e["amp"]) * (1.0 if kind != "blast" else 1.0 + _jitter[i])
		var from: Vector3 = a["pos"]
		var to: Vector3 = b["pos"]
		var out: = _scatter[i] * amp + ((from + to) * 0.5 - Vector3(0, 0.25, 0)).normalized() * amp * (0.6 if kind == "blast" else 0.25)
		var mid: = (from + to) * 0.5 + out
		var pos: = from.lerp(mid, s).lerp(mid.lerp(to, s), s)
		var size: = lerpf(float(a["size"]), float(b["size"]), s) * (1.0 - 0.35 * sin(PI * u))
		var spin: = Basis(_spin_axis[i], sin(PI * u) * (2.2 if kind == "blast" else 1.3))
		var basis: = (a["basis"] as Basis).slerp(b["basis"], s) * spin
		var color: = (a["color"] as Color).lerp(b["color"], s)
		_put(buffer, i, {"pos": pos, "basis": basis, "color": color, "size": size})


func _put(buffer: PackedFloat32Array, i: int, p: Dictionary) -> void :
	var basis: = (p["basis"] as Basis) * Basis.from_scale(Vector3.ONE * maxf(float(p["size"]), 0.0001))
	var pos: Vector3 = p["pos"]
	var c: Color = p["color"]
	var k: = i * 16
	buffer[k] = basis.x.x;buffer[k + 1] = basis.y.x;buffer[k + 2] = basis.z.x;buffer[k + 3] = pos.x
	buffer[k + 4] = basis.x.y;buffer[k + 5] = basis.y.y;buffer[k + 6] = basis.z.y;buffer[k + 7] = pos.y
	buffer[k + 8] = basis.x.z;buffer[k + 9] = basis.y.z;buffer[k + 10] = basis.z.z;buffer[k + 11] = pos.z
	buffer[k + 12] = c.r;buffer[k + 13] = c.g;buffer[k + 14] = c.b;buffer[k + 15] = c.a


static func _smooth(x: float) -> float:
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)





func _weapon_formation(id: String) -> Dictionary:
	var pieces: Array = Lexicon.data.models[id]["pieces"]
	var box: = AABB()
	var first: = true
	for piece: Dictionary in pieces:
		var piece_box: = ModelBuilder._piece_box(piece)
		box = piece_box if first else box.merge(piece_box)
		first = false
	var longest: = maxf(box.size.x, maxf(box.size.y, box.size.z))
	var cell: = longest / CELLS_ALONG
	var cells: = {}
	for piece: Dictionary in pieces:
		var extent: = ModelBuilder._shape_extent(piece)
		var xform: = Transform3D(Basis.from_euler(ModelBuilder._vec(piece.get("rot", [0, 0, 0])) * (PI / 180.0)), 
			ModelBuilder._vec(piece.get("pos", [0, 0, 0])))
		var steps: = Vector3i(maxi(1, ceili(extent.x / cell * 2.0)), maxi(1, ceili(extent.y / cell * 2.0)), maxi(1, ceili(extent.z / cell * 2.0)))
		for x in steps.x:
			for y in steps.y:
				for z in steps.z:
					var local: = - extent * 0.5 + Vector3((x + 0.5) / steps.x * extent.x, (y + 0.5) / steps.y * extent.y, (z + 0.5) / steps.z * extent.z)
					if not ModelBuilder._inside_shape(piece, local):
						continue
					var key: = Vector3i((xform * local / cell).floor())
					if not cells.has(key):
						cells[key] = _tint(Color(String(piece.get("color", "#555555"))), key)
	var scale: = minf(WEAPON_LEN / maxf(box.size.z, box.size.x), WEAPON_HEIGHT / box.size.y)
	var center: = box.get_center()
	var pos: = PackedVector3Array()
	var color: = PackedColorArray()
	for key: Vector3i in cells:
		pos.append(((Vector3(key) + Vector3.ONE * 0.5) * cell - center) * scale)
		color.append(cells[key])
	return {"pos": pos, "color": color, "size": cell * scale * CUBE_FILL}



func _logo_formation() -> Dictionary:
	var texture: = load("res://assets/intro/logos/lavoice.svg") as Texture2D
	var image: = texture.get_image()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var display: = Vector2(1000.0, 1000.0 * image.get_height() / image.get_width())
	var formation: = IntroBlocks.sample(image, display, LOGO_BLOCKS, 0.4, false)
	var scale: = LOGO_WIDTH / display.x
	var pos: = PackedVector3Array()
	var color: = PackedColorArray()
	for i in formation.points.size():
		var p: = formation.points[i]
		pos.append(Vector3(p.x, - p.y, 0.0) * scale)
		var c: = formation.colors[i]
		color.append(Color(c.r, c.g, c.b, 1.0))
	return {"pos": pos, "color": color, "size": formation.cell * scale * CUBE_FILL * 0.95}



func _tint(c: Color, key: Vector3i) -> Color:
	var wobble: = (fposmod(sin(Vector3(key).dot(Vector3(12.9898, 78.233, 37.719))) * 43758.5453, 1.0) - 0.5) * TINT
	return Color(c.r * (1.0 + wobble), c.g * (1.0 + wobble), c.b * (1.0 + wobble), 1.0)




func _spread(f: Dictionary) -> Dictionary:
	var pos: PackedVector3Array = f["pos"]
	var color: PackedColorArray = f["color"]
	var order: Array = range(pos.size())
	order.sort_custom( func(a: int, b: int) -> bool: return pos[a].x + pos[a].y * 0.37 < pos[b].x + pos[b].y * 0.37)
	var out_pos: = PackedVector3Array()
	var out_color: = PackedColorArray()
	var vis: = PackedFloat32Array()
	out_pos.resize(_pool)
	out_color.resize(_pool)
	vis.resize(_pool)
	var n: = pos.size()
	for slot in _pool:
		var rank: = float(slot) * float(n) / float(_pool)
		var source: int = order[mini(int(rank), n - 1)]
		out_pos[slot] = pos[source]
		out_color[slot] = color[source]
		var first_of_rank: = slot == 0 or int(float(slot - 1) * float(n) / float(_pool)) != int(rank)
		vis[slot] = 1.0 if first_of_rank else 0.0
	return {"pos": out_pos, "color": out_color, "vis": vis, "size": f["size"]}


func _stage() -> void :
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = ORANGE
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(1.0, 0.95, 0.9)
	_env.ambient_light_energy = 0.55
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world: = WorldEnvironment.new()
	world.environment = _env
	add_child(world)
	var key: = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38.0, 28.0, 0.0)
	key.light_energy = 1.15
	add_child(key)
	var fill: = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10.0, -150.0, 0.0)
	fill.light_energy = 0.35
	add_child(fill)
	var camera: = Camera3D.new()
	camera.fov = 30.0
	add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 0.6, 12.5), Vector3(0.0, 0.25, 0.0))
	camera.make_current()
