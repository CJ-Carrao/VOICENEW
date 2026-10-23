class_name Structure
extends BlockVolume










const STRUCTURES: = "structures"

const STRUCTURE_ID_BASE: = 100

const FACING_HEIGHT: = 1.25

var network_id: = 0
var blueprint_id: String = ""
var _born: = 0

var _bounds_center: Vector3 = Vector3.ZERO
var _bounds_radius: float = 0.0
var _anchors: = PackedByteArray()
var _anchors_dirty: = true




func build(chunks: Array, id: String = "") -> void :
	blueprint_id = id
	var s: = float(Lexicon.bal("blocks.size_m", 0.25))
	var lo: = Vector3.INF
	var hi: = - Vector3.INF
	for chunk: Dictionary in chunks:
		var half: Vector3 = (chunk["size"] as Vector3) * 0.5
		lo = lo.min((chunk["pos"] as Vector3) - half)
		hi = hi.max((chunk["pos"] as Vector3) + half)
	if chunks.is_empty():
		lo = Vector3.ZERO
		hi = Vector3.ONE * s

	var corner: = Vector3(floorf(lo.x / s + 0.001) * s, 0.0, floorf(lo.z / s + 0.001) * s)
	var n: = Vector3i(maxi(ceili((hi.x - corner.x) / s - 0.001), 1), maxi(ceili(hi.y / s - 0.001), 1), 
		maxi(ceili((hi.z - corner.z) / s - 0.001), 1))
	setup(STRUCTURE_ID_BASE + network_id, n, corner)
	collision_mask = 0
	add_to_group(STRUCTURES)
	explosion_mult = Lexicon.balf("combat.structure_explosion_mult")
	var types: = {}
	for chunk: Dictionary in chunks:
		var material: = String(chunk["material"])
		if not types.has(material):
			types[material] = add_type(material, Color(String(Lexicon.bal("materials.%s.color" % material, "#999999"))))
		_fill(chunk, int(types[material]))
	commit_base()
	_born = alive_count()
	var box: = AABB(corner, Vector3(n) * s)
	_bounds_center = box.get_center()
	_bounds_radius = box.size.length() * 0.5




func _fill(chunk: Dictionary, type: int) -> void :
	var pos: Vector3 = chunk["pos"]
	var half: Vector3 = (chunk["size"] as Vector3) * 0.5
	var a: = (pos - half - origin) / size_m
	var b: = (pos + half - origin) / size_m
	var c0: = Vector3i(roundi(a.x), roundi(a.y), roundi(a.z))
	var c1: = Vector3i(roundi(b.x), roundi(b.y), roundi(b.z))
	for axis in 3:
		if c1[axis] <= c0[axis]:
			c0[axis] = floori((a[axis] + b[axis]) * 0.5)
			c1[axis] = c0[axis] + 1
	c0 = c0.clamp(Vector3i.ZERO, dims - Vector3i.ONE)
	c1 = c1.clamp(Vector3i.ONE, dims)
	var ellipsoid: = String(chunk.get("shape", "")) == "ellipsoid"
	for x in range(c0.x, c1.x):
		for z in range(c0.z, c1.z):
			for y in range(c0.y, c1.y):
				var cell: = Vector3i(x, y, z)
				if ellipsoid and ((cell_center(cell) - pos) / half).length_squared() > 1.0:
					continue
				blocks[index_of(cell)] = type



func chunk_count() -> int:
	return _born



func alive_count() -> int:
	return blocks.size() - blocks.count(AIR)



func matter_left() -> float:
	var total: = 0.0
	for type in range(1, _pal_matter.size()):
		total += blocks.count(type) * _pal_matter[type]

	return total + _bank




func nearest_chunk_point(from: Vector3) -> Vector3:
	var local: = to_local(from)
	var best: = -1
	var best_d: = INF
	for x in dims.x:
		var px: = origin.x + (x + 0.5) * size_m - local.x
		for z in dims.z:
			var pz: = origin.z + (z + 0.5) * size_m - local.z
			var flat: = px * px + pz * pz
			if flat >= best_d:
				continue
			var start: = (x * dims.z + z) * dims.y
			for y in dims.y:
				if blocks[start + y] == AIR:
					continue
				var py: = origin.y + (y + 0.5) * size_m - local.y
				var d: = flat + py * py
				if d < best_d:
					best_d = d
					best = start + y
	return to_global(cell_center(cell_of_index(best))) if best >= 0 else Vector3.INF



func distance_hint(from: Vector3) -> float:
	return maxf(to_local(from).distance_to(_bounds_center) - _bounds_radius, 0.0)





func facing_chunk_point(from: Vector3) -> Vector3:
	var local_from: = to_local(from)
	var flat: = Vector3(local_from.x - _bounds_center.x, 0.0, local_from.z - _bounds_center.z)
	var dir: = flat.normalized() if flat.length_squared() > 0.0001 else Vector3.BACK
	var probe: = _bounds_center + dir * _bounds_radius
	probe.y = minf(FACING_HEIGHT, _bounds_center.y * 2.0)
	return nearest_chunk_point(to_global(probe))



func damage_sphere(center: Vector3, radius: float, amount: float) -> void :
	explode(center, radius, amount)



func recheck_support() -> void :
	if not Session.has_authority():
		return
	_anchors_dirty = true
	for x in dims.x:
		for z in dims.z:
			var index: = (x * dims.z + z) * dims.y
			if blocks[index] != AIR:
				_settle_seeds.append(index)



func is_near(center: Vector3, radius: float) -> bool:
	return to_local(center).distance_to(_bounds_center) <= radius + _bounds_radius




func _anchor_columns() -> PackedByteArray:
	if not _anchors_dirty and not _anchors.is_empty():
		return _anchors
	_anchors_dirty = false
	_anchors = PackedByteArray()
	_anchors.resize(dims.x * dims.z)
	var terrain: = get_tree().get_first_node_in_group(Terrain.FLOOR_GROUP) as Terrain if is_inside_tree() else null
	var tolerance: = Lexicon.balf("terrain.support_tolerance_m")
	for x in dims.x:
		for z in dims.z:
			var column: = x * dims.z + z
			if terrain == null:
				_anchors[column] = 1
				continue
			var base: = to_global(origin + Vector3((x + 0.5) * size_m, 0.0, (z + 0.5) * size_m))
			_anchors[column] = 1 if terrain.height_at(base.x, base.z) >= base.y - tolerance else 0
	return _anchors
