class_name Terrain
extends BlockVolume









signal changed(center: Vector3, radius: float)

const FLOOR_GROUP: = "terrain"

const VOLUME_ID: = 1

var size_extent: float = 0.0

var dig_depth_m: float = 2.5
var _floor_cell: int = 0
var _tcfg: Dictionary




func build(arena_size: float, hills: Array, async: bool = false, ground: Dictionary = {}, depth_m: float = 0.0) -> void :
	_tcfg = Lexicon.bal("terrain", {})
	name = "Terrain"
	crater_cap_m = float(Lexicon.bal("blocks.explosion_max_crater_m", INF))
	size_extent = arena_size
	var block: = float(Lexicon.bal("blocks.size_m", 0.25))
	dig_depth_m = depth_m if depth_m > 0.0 else float(_tcfg.get("max_depth_m", 2.5))
	var depth_cells: = ceili(dig_depth_m / block)
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
	var road: = add_type("soil", Color(String(ground.get("road_color", "#353c45")))) if not ground.is_empty() else top
	var sidewalk: = add_type("soil", Color(String(ground.get("sidewalk_color", "#85847d")))) if not ground.is_empty() else top
	var lot: = add_type("soil", Color(String(ground.get("lot_color", "#626970")))) if not ground.is_empty() else top
	var plaza: = add_type("soil", Color(String(ground.get("plaza_color", "#a49b8c")))) if not ground.is_empty() else top
	var stripe: = add_type("soil", Color(String(ground.get("stripe_color", "#d5ac62")))) if not ground.is_empty() else top
	var coast: = add_type("soil", Color(String(ground.get("coast_color", "#748487")))) if ground.has("coast_width_m") else top

	var surface: = PackedInt32Array()
	surface.resize(n * n)
	surface.fill(_floor_cell)
	var surface_types: = PackedByteArray()
	surface_types.resize(n * n)
	surface_types.fill(top)
	if not ground.is_empty():
		var road_half: = float(ground.get("road_half_m", 6.0))
		var sidewalk_half: = float(ground.get("sidewalk_half_m", 10.0))
		var plaza_half: = float(ground.get("plaza_half_m", 11.0))
		var coast_width: = float(ground.get("coast_width_m", 0.0))
		var roads_x: Array = ground.get("roads_x", [[0.0, road_half, sidewalk_half]])
		var roads_z: Array = ground.get("roads_z", [[0.0, road_half, sidewalk_half]])
		var x_band: = PackedByteArray()
		var z_band: = PackedByteArray()
		x_band.resize(n)
		z_band.resize(n)
		for axis_cell in n:
			var axis_position: = origin.x + (axis_cell + 0.5) * block
			x_band[axis_cell] = _street_band(axis_position, roads_x)
			z_band[axis_cell] = _street_band(origin.z + (axis_cell + 0.5) * block, roads_z)
		for x in n:
			var px: = origin.x + (x + 0.5) * block
			for z in n:
				var pz: = origin.z + (z + 0.5) * block
				var ax: = absf(px)
				var az: = absf(pz)
				var type: = lot
				if coast_width > 0.0 and maxf(ax, az) >= arena_size * 0.5 - coast_width:
					type = coast
				elif ax < plaza_half and az < plaza_half:
					type = plaza
				elif x_band[x] == 2 or z_band[z] == 2:
					type = road
					if (ax < 0.15 and az > plaza_half and int(az / 4.0) % 2 == 0) or \
					(az < 0.15 and ax > plaza_half and int(ax / 4.0) % 2 == 0):
						type = stripe
				elif x_band[x] == 1 or z_band[z] == 1:
					type = sidewalk
				surface_types[x * n + z] = type
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
		if ground.is_empty() and row.count(_floor_cell) == n:
			out.append_array(flat_row)
			continue
		for z in n:
			var h: = row[z]
			var color_type: = int(surface_types[x * n + z])
			var key: = h * 256 + color_type
			if not columns.has(key):
				columns[key] = _column(h, rock, soil, color_type)
			out.append_array(columns[key])
	blocks = out
	commit_base(async)
	cells_changed.connect(_on_cells_changed)



func _street_band(point: float, roads: Array) -> int:
	var sidewalk: = false
	for road: Array in roads:
		var distance: = absf(point - float(road[0]))
		if distance < float(road[1]):
			return 2
		if distance < float(road[2]):
			sidewalk = true
	return 1 if sidewalk else 0



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
