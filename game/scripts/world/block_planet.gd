class_name BlockPlanet
extends BlockVolume





var radius: float = 10.0
var core_radius: float = 3.0
var color: = Color("#777777")


func build_planet(id: int, def: Dictionary, async: bool = false) -> void :
	name = "Planet_" + String(def.get("name", str(id)))
	var cfg: Dictionary = Lexicon.bal("space.voxel", {})
	radius = float(def.radius)
	core_radius = radius * float(cfg.get("core_fraction", 0.3))
	color = Color(String(def.get("color", "#777777")))
	var relief_amp: = float(cfg.get("relief_m", 0.5))
	var size: = float(Lexicon.bal("blocks.size_m", 0.25))
	var n: = ceili((radius + relief_amp + size * 2.0) * 2.0 / size)
	setup(id, Vector3i(n, n, n), - Vector3.ONE * n * size * 0.5)
	gravity_center = global_position if is_inside_tree() else null
	var crust: = add_type(String(cfg.get("material", "stone")), color)
	var deep: = add_type(String(cfg.get("material", "stone")), color.darkened(0.45))
	var core: = add_type("core", Color(Lexicon.bal("materials.core.color", "#ff8a2a")), FLAG_ANCHOR | FLAG_FOREVER, 1.2)
	var relief: = FastNoiseLite.new()
	relief.seed = 9173 + id * 31
	relief.frequency = float(cfg.get("relief_frequency", 0.09))
	var deep_radius: = maxf(core_radius + size, radius - float(cfg.get("crust_m", 2.0)))
	build_columns( func(x: int, z: int) -> Array:
		var px: = origin.x + (x + 0.5) * size
		var pz: = origin.z + (z + 0.5) * size
		var d2: = px * px + pz * pz
		var spans: Array = []

		var flat: = sqrt(maxf(radius * radius - d2, 0.0))
		var top_r: = radius + relief.get_noise_3dv(Vector3(px, flat, pz).normalized() * radius) * relief_amp
		var bottom_r: = radius + relief.get_noise_3dv(Vector3(px, - flat, pz).normalized() * radius) * relief_amp
		if d2 >= maxf(top_r, bottom_r) * maxf(top_r, bottom_r):
			return spans
		var top: = sqrt(maxf(top_r * top_r - d2, 0.0)) if d2 < top_r * top_r else 0.0
		var bottom: = - sqrt(maxf(bottom_r * bottom_r - d2, 0.0)) if d2 < bottom_r * bottom_r else 0.0
		var deep_h: = sqrt(maxf(deep_radius * deep_radius - d2, 0.0)) if d2 < deep_radius * deep_radius else -1.0
		var core_h: = sqrt(maxf(core_radius * core_radius - d2, 0.0)) if d2 < core_radius * core_radius else -1.0
		var marks: Array = [[bottom, crust]]
		if deep_h >= 0.0:
			marks.append([ - deep_h, deep])
			if core_h >= 0.0:
				marks.append([ - core_h, core])
				marks.append([core_h, deep])
			marks.append([deep_h, crust])
		marks.append([top, AIR])
		for i in marks.size() - 1:
			var y0: = _cell_y(float(marks[i][0]))
			var y1: = _cell_y(float(marks[i + 1][0]))
			if y1 > y0 and int(marks[i][1]) != AIR:
				spans.append([y0, y1, int(marks[i][1])])
		return spans)
	commit_base(async)



func _cell_y(y: float) -> int:
	return ceili((y - origin.y) / size_m - 0.5)



func _anchor_step(cell: Vector3i) -> Vector3i:
	var to: = dims / 2 - cell
	var a: = absi(to.x)
	var b: = absi(to.y)
	var c: = absi(to.z)
	if a >= b and a >= c:
		return Vector3i(signi(to.x), 0, 0)
	if b >= c:
		return Vector3i(0, signi(to.y), 0)
	return Vector3i(0, 0, signi(to.z))


func _enter_tree() -> void :
	gravity_center = global_position
