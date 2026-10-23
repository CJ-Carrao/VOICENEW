class_name Terrain
extends BlockVolume









signal changed(center: Vector3, radius: float)

const FLOOR_GROUP: = "terrain"

const VOLUME_ID: = 1

var size_extent: float = 0.0
var _floor_cell: int = 0
var _tcfg: Dictionary


func build(arena_size: float, hills: Array, async: bool = false) -> void :
	_tcfg = Lexicon.bal("terrain", {})
	name = "Terrain"
	size_extent = arena_size
	var block: = float(Lexicon.bal("blocks.size_m", 0.25))
	var depth_cells: = ceili(float(_tcfg.get("max_depth_m", 2.5)) / block)
	var tallest: = 0.0
	for hill: Dictionary in hills:
		tallest = maxf(tallest, float(hill["height"]))
	var n: = ceili(arena_size / block)

	_floor_cell = 1 + depth_cells
	var dy: = _floor_cell + ceili(tallest / block) + 2
	setup(VOLUME_ID, Vector3i(n, dy, n), Vector3( - n * block * 0.5, - _floor_cell * block, - n * block * 0.5))
	collision_mask = 0
	add_to_group(FLOOR_GROUP)
	add_to_group("ground")
	var rock: = add_type("bedrock", Color(Lexicon.bal("materials.bedrock.color", "#2e2c31")), FLAG_ANCHOR | FLAG_FOREVER)
	var soil: = add_type("soil", Color(Lexicon.bal("materials.soil.color", "#6b5038")))
	var top: = add_type("soil", Color(String(_tcfg.get("ground_color", "#4d525c"))))

	var surface: = PackedInt32Array()
	surface.resize(n * n)
	surface.fill(_floor_cell)
	for hill: Dictionary in hills:
		var at: Array = hill["pos"]
		var r: = float(hill["radius"])
		var c0: = cell_of(Vector3(float(at[0]) - r, 0.0, float(at[1]) - r))
		var c1: = cell_of(Vector3(float(at[0]) + r, 0.0, float(at[1]) + r))
		for x in range(maxi(c0.x, 0), mini(c1.x + 1, n)):
			for z in range(maxi(c0.z, 0), mini(c1.z + 1, n)):
				var p: = Vector3(origin.x + (x + 0.5) * block, 0.0, origin.z + (z + 0.5) * block)
				surface[x * n + z] = _floor_cell + roundi(_hill_height(p, hills) / block)


	var columns: = {}
	var flat_row: = PackedByteArray()
	var flat: = _column(_floor_cell, rock, soil, top)
	for z in n:
		flat_row.append_array(flat)
	var out: = PackedByteArray()
	for x in n:
		var row: = surface.slice(x * n, x * n + n)
		if row.count(_floor_cell) == n:
			out.append_array(flat_row)
			continue
		for z in n:
			var h: = row[z]
			if not columns.has(h):
				columns[h] = _column(h, rock, soil, top)
			out.append_array(columns[h])
	blocks = out
	commit_base(async)
	cells_changed.connect(_on_cells_changed)



func _column(surface: int, rock: int, soil: int, top: int) -> PackedByteArray:
	var col: = PackedByteArray()
	col.resize(dims.y)
	for y in dims.y:
		col[y] = rock if y == 0 else (soil if y < surface - 1 else (top if y == surface - 1 else AIR))
	return col



func dug_at(x: float, z: float) -> float:
	var cell: = cell_of(to_local(Vector3(x, 0.0, z)))
	if cell.x < 0 or cell.z < 0 or cell.x >= dims.x or cell.z >= dims.z:
		return 0.0
	return (_column_top(_base, cell.x, cell.z) - _column_top(blocks, cell.x, cell.z)) * size_m



func max_dug() -> float:
	var deepest: = 0.0
	var seen: = {}
	for index: int in network_changes:
		var cell: = cell_of_index(index)
		var column: = cell.x * dims.z + cell.z
		if seen.has(column):
			continue
		seen[column] = true
		deepest = maxf(deepest, (_column_top(_base, cell.x, cell.z) - _column_top(blocks, cell.x, cell.z)) * size_m)
	return deepest




func crater(center: Vector3, radius: float, depth: float) -> float:
	if not Session.has_authority() or radius <= 0.0 or depth <= 0.0:
		return 0.0
	var local: = to_local(center)
	var c: = cell_of(local)
	var reach: = ceili(radius / size_m)
	var down: = ceili(depth / size_m)
	var hit: Array = []
	for dx in range( - reach, reach + 1):
		for dz in range( - reach, reach + 1):
			for dy in range( - down - 1, mini(reach, dims.y - c.y) + 1):
				var cell: = c + Vector3i(dx, dy, dz)
				if not inside(cell):
					continue
				var at: = cell_center(cell) - local
				var flat: = Vector2(at.x, at.z).length() / radius
				if flat >= 1.0:
					continue

				if at.y < 0.0 and - at.y > depth * (1.0 - flat * flat):
					continue
				if at.y > radius:
					continue
				hit.append(index_of(cell))
	var before: = network_changes.size()
	remove_cells(hit)
	return (network_changes.size() - before) * pow(size_m, 3.0)


func ground_below(point: Vector3) -> Vector3:
	return _ground_near(point)




func _ground_near(point: Vector3) -> Vector3:
	var cell: = cell_of(to_local(point))
	if cell.x < 0 or cell.z < 0 or cell.x >= dims.x or cell.z >= dims.z:
		return super._ground_near(point)
	var start: = (cell.x * dims.z + cell.z) * dims.y
	var y: = clampi(cell.y, 0, dims.y - 1)
	if blocks[start + y] != AIR:
		while y + 1 < dims.y and blocks[start + y + 1] != AIR:
			y += 1
	else:
		while y >= 0 and blocks[start + y] == AIR:
			y -= 1
	return Vector3(point.x, to_global(origin + Vector3(0, (y + 1) * size_m, 0)).y, point.z)



func _column_top(data: PackedByteArray, x: int, z: int) -> int:
	var start: = (x * dims.z + z) * dims.y
	for y in range(dims.y - 1, -1, -1):
		if data[start + y] != AIR:
			return y + 1
	return 0



func _on_cells_changed(changes: Dictionary) -> void :
	_announce(changes)


func apply_network_cells(changes: Dictionary) -> void :
	super.apply_network_cells(changes)
	_announce(changes)


func _announce(changes: Dictionary) -> void :
	if changes.is_empty():
		return
	var low: = Vector3i(dims)
	var high: = Vector3i(-1, -1, -1)
	for index: int in changes:
		var cell: = cell_of_index(index)
		low = low.min(cell)
		high = high.max(cell)
	var a: = to_global(cell_center(low))
	var b: = to_global(cell_center(high))
	changed.emit((a + b) * 0.5, a.distance_to(b) * 0.5 + size_m)



static func _hill_height(p: Vector3, hills: Array) -> float:
	var h: = 0.0
	for hill: Dictionary in hills:
		var at: Array = hill["pos"]
		var d: = Vector2(p.x - float(at[0]), p.z - float(at[1])).length() / float(hill["radius"])
		if d < 1.0:
			h += float(hill["height"]) * (0.5 + 0.5 * cos(PI * d))
	return h
