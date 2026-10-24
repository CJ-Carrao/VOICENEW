class_name BlockVolume
extends StaticBody3D















signal cells_changed(changes: Dictionary)

const GROUP: = "block_volumes"
const AIR: = 0

var volume_id: int = 0
var size_m: float = 0.25
var dims: = Vector3i.ONE

var origin: = Vector3.ZERO
var blocks: = PackedByteArray()

var network_changes: Dictionary = {}

var last_extracted: Dictionary = {}


var extract_origin: Variant = null

var gravity_center: Variant = null

var explosion_mult: float = 1.0

var last_process_ms: float = 0.0

var _base: = PackedByteArray()
var _pal_material: = PackedStringArray([""])
var _pal_color: = PackedColorArray([Color.TRANSPARENT])
var _pal_hp: = PackedFloat32Array([0.0])
var _pal_matter: = PackedFloat32Array([0.0])
var _pal_flags: = PackedByteArray([0])
var _pal_glass: = PackedByteArray([0])
var _pal_glow: = PackedFloat32Array([0.0])

var _has_glass: = false
var _hp: Dictionary = {}
var _chunk_cells: int = 16
var _chunks: = Vector3i.ONE
var _parts: Dictionary = {}
var _dirty: Dictionary = {}


var _job: = -1
var _job_list: Array[Vector3i] = []
var _job_results: Array = []
var _ready_chunks: Array = []

var _settle_seeds: Array[int] = []
var _settle_job: = -1
var _settle_result: Array = []
var _material: ShaderMaterial
var _glass_material: ShaderMaterial
var _cfg: Dictionary
var _bank: float = 0.0
var _bank_cell: int = -1
var _sy: int = 1
var _sz: int = 1
var _sx: int = 1


var _queue: = PackedInt64Array()
var _queue_head: = 0
var _queue_point: = Vector3.INF
var _pending_total: = 0

static var loading: = false

const FLAG_ANCHOR: = 1
const FLAG_FOREVER: = 2

const SHADER: = "\nshader_type spatial;\nrender_mode %s;\nuniform float block = 0.25;\nuniform vec3 grid_origin;\nuniform float edge_dark = 0.8;\nuniform float alpha = 1.0;\n// Revelação (intro do mapa): só aparece o bloco cujo centro está até reveal_radius de reveal_center (espaço do\n// volume); a borda da frente brilha quente.\nuniform vec3 reveal_center = vec3(0.0);\nuniform float reveal_radius = 1e9;\nuniform vec3 reveal_hot : source_color = vec3(1.0, 0.55, 0.15);\nvarying vec3 lp;\nvarying vec3 ln;\nvarying float glow;\nvoid vertex() { lp = VERTEX; ln = NORMAL; glow = UV.x; }\nfloat hash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }\nvoid fragment() {\n\tvec3 g = (lp - grid_origin) / block;\n\tvec3 cell = floor(g - ln * 0.5 + 0.0001);\n\tfloat reach = reveal_radius - length(grid_origin + (cell + 0.5) * block - reveal_center);\n\tif (reach < 0.0) { discard; }\n\tfloat h = hash(cell + vec3(0.31, 0.17, 0.53));\n\tvec3 base = pow(COLOR.rgb, vec3(2.2));\n\tvec3 col = base * (1.0 + (h - 0.5) * 2.0 * COLOR.a);\n\tvec3 f = fract(g);\n\tvec3 e = min(f, 1.0 - f) + abs(ln) * 10.0;\n\tfloat edge = min(min(e.x, e.y), e.z);\n\tcol *= mix(edge_dark, 1.0, smoothstep(0.0, 0.07, edge));\n\tALBEDO = col;\n\tROUGHNESS = 0.85;\n\tEMISSION = col * glow + reveal_hot * 1.8 * (1.0 - smoothstep(0.0, 0.4, reach));\n\t%s\n}\n"





































func setup(id: int, size: Vector3i, origin_local: Vector3) -> void :
	volume_id = id
	_cfg = Lexicon.bal("blocks", {})
	size_m = float(_cfg.get("size_m", 0.25))
	_chunk_cells = int(_cfg.get("chunk_cells", 16))
	dims = size
	origin = origin_local
	_sy = 1
	_sz = dims.y
	_sx = dims.z * dims.y
	_chunks = Vector3i(ceili(float(dims.x) / _chunk_cells), ceili(float(dims.y) / _chunk_cells), ceili(float(dims.z) / _chunk_cells))
	blocks.resize(dims.x * dims.y * dims.z)
	collision_layer = PhysicsLayers.WORLD
	add_to_group(GROUP)
	_material = _make_material("cull_back", "")
	_glass_material = _make_material("cull_back, blend_mix, depth_draw_opaque", "ALPHA = alpha;")
	_glass_material.set_shader_parameter("alpha", 0.45)



func set_reveal(radius: float, center: Vector3 = Vector3.ZERO) -> void :
	for material: ShaderMaterial in [_material, _glass_material]:
		material.set_shader_parameter("reveal_center", center)
		material.set_shader_parameter("reveal_radius", minf(radius, 1000000000.0))


func _make_material(mode: String, extra: String) -> ShaderMaterial:
	var shader: = Shader.new()
	shader.code = SHADER % [mode, extra]
	var material: = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("block", size_m)
	material.set_shader_parameter("grid_origin", origin)
	return material




func add_type(material: String, color: Color, flags: int = 0, glow: float = 0.0) -> int:
	var data: Dictionary = Lexicon.bal("materials." + material, {})
	var volume: = size_m * size_m * size_m
	_pal_material.append(material)
	_pal_color.append(Color(color, float(data.get("variation", 0.08))))
	_pal_hp.append(float(data.get("hp_per_m3", 0.0)) * volume)
	_pal_matter.append(float(data.get("matter_per_m3", 0.0)) * volume)
	_pal_flags.append(flags)
	_pal_glass.append(1 if data.has("alpha") else 0)
	_has_glass = _has_glass or data.has("alpha")
	_pal_glow.append(glow)
	return _pal_material.size() - 1


func type_material(type: int) -> String:
	return _pal_material[type]


func type_color(type: int) -> Color:
	return Color(_pal_color[type], 1.0)






func build_columns(spans_for: Callable) -> void :
	var runs: Array[PackedByteArray] = []
	for type in _pal_material.size():
		var run: = PackedByteArray()
		run.resize(dims.y)
		run.fill(type)
		runs.append(run)
	var out: = PackedByteArray()
	for x in dims.x:
		for z in dims.z:
			var y: = 0
			for span: Array in spans_for.call(x, z):
				var y0: = clampi(int(span[0]), y, dims.y)
				var y1: = clampi(int(span[1]), y0, dims.y)
				if y0 > y:
					out.append_array(runs[AIR].slice(0, y0 - y))
				if y1 > y0:
					out.append_array(runs[int(span[2])].slice(0, y1 - y0))
				y = y1
			if y < dims.y:
				out.append_array(runs[AIR].slice(0, dims.y - y))
	blocks = out





func commit_base(async: bool = false) -> void :
	_base = blocks.duplicate()
	network_changes.clear()
	_hp.clear()
	if not async:
		_rebuild_all()
		return
	_pending_total = _chunks.x * _chunks.y * _chunks.z
	for cx in _chunks.x:
		for cy in _chunks.y:
			for cz in _chunks.z:
				_dirty[Vector3i(cx, cy, cz)] = true



func is_settled() -> bool:
	return _dirty.is_empty() and _job < 0 and _ready_chunks.is_empty()



func build_progress() -> float:
	if _pending_total <= 0:
		return 1.0
	return 1.0 - float(_dirty.size() + _ready_chunks.size() + (_job_list.size() if _job >= 0 else 0)) / float(_pending_total)



func restore() -> void :
	if _settle_job >= 0:
		WorkerThreadPool.wait_for_task_completion(_settle_job)
		_settle_job = -1
	_settle_seeds.clear()
	_queue = PackedInt64Array()
	_queue_point = Vector3.INF
	if network_changes.is_empty():
		return
	for index: int in network_changes:
		_mark_dirty(cell_of_index(index))
	blocks = _base.duplicate()
	network_changes.clear()
	_hp.clear()
	_bank = 0.0
	flush()




func index_of(cell: Vector3i) -> int:
	return (cell.x * dims.z + cell.z) * dims.y + cell.y


func cell_of_index(index: int) -> Vector3i:
	var y: = index % dims.y
	var rest: = index / dims.y
	return Vector3i(rest / dims.z, y, rest % dims.z)


func inside(cell: Vector3i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.z >= 0 and cell.x < dims.x and cell.y < dims.y and cell.z < dims.z



func cell_of(local: Vector3) -> Vector3i:
	var g: = (local - origin) / size_m
	return Vector3i(floori(g.x), floori(g.y), floori(g.z))


func cell_center(cell: Vector3i) -> Vector3:
	return origin + (Vector3(cell) + Vector3.ONE * 0.5) * size_m



func height_at(x: float, z: float) -> float:
	var cell: = cell_of(to_local(Vector3(x, 0.0, z)))
	if cell.x < 0 or cell.z < 0 or cell.x >= dims.x or cell.z >= dims.z:
		return global_position.y + origin.y
	var start: = (cell.x * dims.z + cell.z) * dims.y
	for y in range(dims.y - 1, -1, -1):
		if blocks[start + y] != AIR:
			return to_global(origin + Vector3(0, (y + 1) * size_m, 0)).y
	return to_global(origin).y



func nearest_solid(point: Vector3, reach: int = 2) -> int:
	var local: = to_local(point)
	var center: = cell_of(local)
	var best: = -1
	var best_d: = INF
	for dx in range( - reach, reach + 1):
		for dy in range( - reach, reach + 1):
			for dz in range( - reach, reach + 1):
				var cell: = center + Vector3i(dx, dy, dz)
				if not inside(cell):
					continue
				var index: = index_of(cell)
				var type: = blocks[index]
				if type == AIR or (_pal_flags[type] & FLAG_FOREVER) != 0:
					continue
				var d: = cell_center(cell).distance_squared_to(local)
				if d < best_d:
					best_d = d
					best = index
	return best





func set_cells(changes: Dictionary) -> void :
	if changes.is_empty():
		return
	apply_cells(changes)
	for index: int in changes:
		network_changes[index] = changes[index]
	cells_changed.emit(changes)



func apply_cells(changes: Dictionary) -> void :
	for index: int in changes:
		blocks[index] = int(changes[index])
		_hp.erase(index)
		_mark_dirty(cell_of_index(index))



func apply_network_cells(changes: Dictionary) -> void :
	for index: int in changes:
		network_changes[index] = changes[index]
	apply_cells(changes)



func remove_cells(indices: Array, settle: bool = true) -> Dictionary:
	var changes: = {}
	var matter: = {}
	for index: int in indices:
		var type: = blocks[index]
		if type == AIR or (_pal_flags[type] & FLAG_FOREVER) != 0:
			continue
		changes[index] = AIR
		matter[_pal_material[type]] = float(matter.get(_pal_material[type], 0.0)) + _pal_matter[type]
	set_cells(changes)
	if settle and not changes.is_empty() and Session.has_authority():
		for index: int in changes:
			_settle_seeds.append(index)
	return matter




func damage_at(point: Vector3, amount: float, _shape_index: int = -1) -> void :
	if not Session.has_authority() or amount <= 0.0:
		return
	var index: = nearest_solid(point, 1)
	if index < 0:
		return
	var type: = blocks[index]
	var left: = float(_hp.get(index, _pal_hp[type])) - amount
	if left > 0.0:
		_hp[index] = left
		return
	var at: = to_global(cell_center(cell_of_index(index)))
	_deposit(remove_cells([index]), at)
	if is_inside_tree():
		Fx.debris(Forge.fx_root(self), at, Vector3.ONE * size_m, type_color(type))




func erase_sphere(center: Vector3, radius: float) -> void:
	if not Session.has_authority(): return
	var local := to_local(center)
	var reach := ceili(clampf(radius, .1, 4.0) / size_m)
	var c := cell_of(local)
	var hit := []
	for x in range(maxi(0, c.x - reach), mini(dims.x, c.x + reach + 1)):
		for y in range(maxi(0, c.y - reach), mini(dims.y, c.y + reach + 1)):
			for z in range(maxi(0, c.z - reach), mini(dims.z, c.z + reach + 1)):
				var cell := Vector3i(x, y, z)
				if cell_center(cell).distance_squared_to(local) <= radius * radius:
					var index := index_of(cell)
					if blocks[index] != AIR: hit.append(index)
	# Erasure is spatial, independent of explosion resistance; permanent map cells remain protected.
	if not hit.is_empty(): _deposit(remove_cells(hit), center)

func explode(center: Vector3, radius: float, damage: float) -> float:
	if not Session.has_authority():
		return 0.0
	var local: = to_local(center)
	var r: = radius * float(_cfg.get("explosion_radius_mult", 0.6))
	var reach: = ceili(r / size_m)
	var c: = cell_of(local)

	if c.x + reach < 0 or c.y + reach < 0 or c.z + reach < 0 or c.x - reach >= dims.x or c.y - reach >= dims.y or c.z - reach >= dims.z:
		return 0.0
	var hit: Array = []
	for dx in range( - reach, reach + 1):
		for dz in range( - reach, reach + 1):
			for dy in range( - reach, reach + 1):
				var cell: = c + Vector3i(dx, dy, dz)
				if not inside(cell):
					continue
				var d: = cell_center(cell).distance_to(local)
				if d > r:
					continue
				var index: = index_of(cell)
				var type: = blocks[index]
				if type == AIR:
					continue
				if _pal_hp[type] <= damage * float(_cfg.get("explosion_damage_mult", 2.0)) * (1.0 - d / maxf(r, 0.01)):
					hit.append(index)
	if hit.is_empty():
		return 0.0
	var matter: = remove_cells(hit)
	return _deposit(matter, center)






func extract_from(_shape_index: int, point: Vector3, amount: float) -> float:
	if not Session.has_authority() or amount <= 0.0:
		return 0.0
	var taken: = 0.0
	var guard: = 0
	while taken < amount and guard < 8:
		guard += 1
		if _bank <= 0.0:
			var index: = _extract_target(point)
			if index < 0:
				break
			var type: = blocks[index]
			var cell: = cell_of_index(index)
			remove_cells([index])
			_bank = _pal_matter[type]
			last_extracted = {"center": to_global(cell_center(cell)), "color": type_color(type), "size": size_m, 
				"tick": Engine.get_physics_frames()}
			if _bank <= 0.0:
				continue
		var part: = minf(amount - taken, _bank)
		_bank -= part
		taken += part
	return taken






func _extract_target(point: Vector3) -> int:
	var keep: = float(_cfg.get("extract_radius_m", 0.6))
	if _queue_point.distance_to(point) <= keep:
		var found: = _queue_front()
		if found >= 0:
			return found
	_queue_point = point
	var bowl: = ceili(keep / size_m)
	var eye: Vector3 = extract_origin if extract_origin is Vector3 else point
	_fill_queue(point, bowl, keep + size_m * 0.5, eye)
	if _queue.is_empty() and extract_origin is Vector3:
		var dir: = (point - eye).normalized()
		var k: = 1
		while _queue.is_empty() and k * size_m * 2.0 <= 1.5:
			_fill_queue(point + dir * k * size_m * 2.0, bowl, keep + size_m * 0.5, eye)
			k += 1
	if _queue.is_empty():
		var stick: = Lexicon.balf("extraction.stick_m")
		for reach: int in [3, ceili(stick / size_m)]:
			_fill_queue(point, reach, stick, point)
			if not _queue.is_empty():
				break
	return _queue_front()


func _queue_front() -> int:
	while _queue_head < _queue.size():
		var index: = int(_queue[_queue_head] & 4294967295)
		var type: = blocks[index]
		if type != AIR and (_pal_flags[type] & FLAG_FOREVER) == 0:
			return index
		_queue_head += 1
	return -1




func _fill_queue(center: Vector3, reach: int, limit: float, rank: Vector3) -> void :
	_queue = PackedInt64Array()
	_queue_head = 0
	var local: = to_local(center)
	var from: = to_local(rank)
	var c: = cell_of(local)
	if c.x + reach < 0 or c.y + reach < 0 or c.z + reach < 0 or c.x - reach >= dims.x or c.y - reach >= dims.y\
	or c.z - reach >= dims.z:
		return
	var x0: = maxi(c.x - reach, 0)
	var x1: = mini(c.x + reach, dims.x - 1)
	var y0: = maxi(c.y - reach, 0)
	var y1: = mini(c.y + reach, dims.y - 1)
	var z0: = maxi(c.z - reach, 0)
	var z1: = mini(c.z + reach, dims.z - 1)
	var limit2: = limit * limit
	for x in range(x0, x1 + 1):
		var px: = origin.x + (x + 0.5) * size_m
		for z in range(z0, z1 + 1):
			var pz: = origin.z + (z + 0.5) * size_m
			var flat: = (px - local.x) * (px - local.x) + (pz - local.z) * (pz - local.z)
			if flat > limit2:
				continue
			var start: = (x * dims.z + z) * dims.y
			for y in range(y0, y1 + 1):
				var type: = blocks[start + y]
				if type == AIR or (_pal_flags[type] & FLAG_FOREVER) != 0:
					continue
				var py: = origin.y + (y + 0.5) * size_m
				if flat + (py - local.y) * (py - local.y) > limit2:
					continue
				var d: = Vector3(px, py, pz).distance_squared_to(from)
				_queue.append((int(d * 10000.0) << 32) | (start + y))
	_queue.sort()



func can_extract_at(point: Vector3) -> bool:
	return _extract_target(point) >= 0


func extract_point(_shape_index: int, point: Vector3) -> Vector3:
	var index: = _extract_target(point)
	return to_global(cell_center(cell_of_index(index))) if index >= 0 else point


func extract_color(_shape_index: int, point: Vector3) -> Color:
	var index: = _extract_target(point)
	return type_color(blocks[index]) if index >= 0 else Color.GRAY



func _deposit(matter: Dictionary, near: Vector3) -> float:
	var total: = 0.0
	var fraction: = Lexicon.balf("matter.debris_fraction")
	for material: String in matter:
		var amount: = float(matter[material]) * fraction
		if amount > 0.0:
			Rubble.deposit(Forge.debris_root(), _ground_near(near), amount, material)
			total += amount
	return total




func _ground_near(point: Vector3) -> Vector3:
	var down: = Vector3.DOWN
	if gravity_center is Vector3:
		down = ((gravity_center as Vector3) - point).normalized()
	if not is_inside_tree():
		return point
	var step: = size_m * 0.5
	var at: = point - down * size_m
	for i in int(60.0 / step):
		var cell: = cell_of(to_local(at))
		if inside(cell) and blocks[index_of(cell)] != AIR:
			return at - down * step
		at += down * step

	var floor_volume: = get_tree().get_first_node_in_group("terrain")
	if gravity_center == null and floor_volume != null and floor_volume != self and floor_volume.has_method("ground_below"):
		return floor_volume.call("ground_below", point)
	var query: = PhysicsRayQueryParameters3D.create(point - down * 0.5, point + down * 30.0, PhysicsLayers.WORLD)
	var hit: = get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if not hit.is_empty() else point







func _find_islands(removed: Array, data: PackedByteArray, anchors: PackedByteArray) -> Array:
	var islands: Array = []
	var limit: = int(_cfg.get("island_limit", 6000))
	var checked: = {}
	for index: int in removed:
		var cell: = cell_of_index(index)

		for offset: Vector3i in [Vector3i.ZERO] + NEIGHBORS:
			var next: = cell + offset
			if not inside(next):
				continue
			var start: = index_of(next)
			if checked.has(start) or data[start] == AIR:
				continue
			var island: = _island(start, limit, data, anchors)
			for member: int in island.cells:
				checked[member] = true
			if not island.anchored:
				islands.append(island.cells)
	return islands




func _island(start: int, limit: int, data: PackedByteArray, anchors: PackedByteArray) -> Dictionary:
	var seen: = {start: true}
	var cells: Array[int] = [start]
	var stack: Array[int] = [start]
	while not stack.is_empty():
		var index: int = stack.pop_back()
		var type: = data[index]
		if (_pal_flags[type] & FLAG_ANCHOR) != 0 or cells.size() > limit:
			return {"anchored": true, "cells": cells}

		if not anchors.is_empty() and index % dims.y == 0 and anchors[index / dims.y] == 1:
			return {"anchored": true, "cells": cells}
		var cell: = cell_of_index(index)
		var first: = _anchor_step(cell)

		for offset: Vector3i in NEIGHBORS:
			if offset != first:
				_visit(cell + offset, data, seen, cells, stack)
		_visit(cell + first, data, seen, cells, stack)
	return {"anchored": false, "cells": cells}


func _visit(next: Vector3i, data: PackedByteArray, seen: Dictionary, cells: Array[int], stack: Array[int]) -> void :
	if not inside(next):
		return
	var n: = index_of(next)
	if seen.has(n) or data[n] == AIR:
		return
	seen[n] = true
	cells.append(n)
	stack.append(n)




func _anchor_columns() -> PackedByteArray:
	return PackedByteArray()



func _anchor_step(_cell: Vector3i) -> Vector3i:
	return Vector3i(0, -1, 0)



func _drop_islands(islands: Array) -> void :
	for cells: Array in islands:
		var still: Array = []
		for index: int in cells:
			if blocks[index] != AIR:
				still.append(index)
		if still.is_empty():
			continue
		var fallen: = remove_cells(still, false)
		_present_fall(still, fallen)



func _present_fall(cells: Array, matter: Dictionary) -> void :
	if cells.is_empty():
		return
	var centers: = PackedVector3Array()
	var colors: = PackedColorArray()
	var centroid: = Vector3.ZERO
	var step: = maxi(1, cells.size() / int(_cfg.get("fall_max_visual", 400)))
	for i in range(0, cells.size(), step):
		var p: = to_global(cell_center(cell_of_index(int(cells[i]))))
		centers.append(p)
		centroid += p
	centroid /= maxf(centers.size(), 1.0)
	for material: String in matter:
		colors.append(Color(Lexicon.bal("materials.%s.color" % material, "#888888")))
	var down: = Vector3.DOWN
	if gravity_center is Vector3:
		down = ((gravity_center as Vector3) - centroid).normalized()
	Fx.falling_blocks(Forge.fx_root(self), centers, size_m, colors[0] if not colors.is_empty() else Color.GRAY, down)
	_deposit(matter, centroid)


const NEIGHBORS: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), 
	Vector3i(0, 0, 1), Vector3i(0, 0, -1)]




func _mark_dirty(cell: Vector3i) -> void :
	var C: = _chunk_cells
	var chunk: = Vector3i(cell.x / C, cell.y / C, cell.z / C)
	_dirty[chunk] = true

	for axis in 3:
		var local: = cell[axis] - chunk[axis] * C
		if local == 0 and chunk[axis] > 0:
			var other: = chunk
			other[axis] -= 1
			_dirty[other] = true
		elif local == C - 1 and chunk[axis] < _chunks[axis] - 1:
			var other: = chunk
			other[axis] += 1
			_dirty[other] = true



func flush() -> void :
	if _settle_job >= 0:
		WorkerThreadPool.wait_for_task_completion(_settle_job)
		_settle_job = -1
		_drop_islands(_settle_result)
	if not _settle_seeds.is_empty():
		var seeds: = _settle_seeds.duplicate()
		_settle_seeds.clear()
		_drop_islands(_find_islands(seeds, blocks, _anchor_columns()))
	if _job >= 0:
		WorkerThreadPool.wait_for_group_task_completion(_job)
		_job = -1
		for chunk: Vector3i in _job_list:
			_dirty[chunk] = true
	_ready_chunks.clear()
	for chunk: Vector3i in _dirty.keys():
		_apply_chunk(chunk, _mesh_chunk(chunk, blocks))
	_dirty.clear()


func _process(_delta: float) -> void :
	var started: = Time.get_ticks_usec()
	_pump_settle()
	_pump_mesh()
	last_process_ms = (Time.get_ticks_usec() - started) / 1000.0




func _exit_tree() -> void :
	if _job >= 0:
		WorkerThreadPool.wait_for_group_task_completion(_job)
		_job = -1
		for chunk: Vector3i in _job_list:
			_dirty[chunk] = true
	if _settle_job >= 0:
		WorkerThreadPool.wait_for_task_completion(_settle_job)
		_settle_job = -1



func _pump_settle() -> void :
	if _settle_job >= 0:
		if not WorkerThreadPool.is_task_completed(_settle_job):
			return
		WorkerThreadPool.wait_for_task_completion(_settle_job)
		_settle_job = -1
		_drop_islands(_settle_result)
	if _settle_seeds.is_empty():
		return
	var seeds: = _settle_seeds.duplicate()
	_settle_seeds.clear()
	var snapshot: = blocks.duplicate()
	var anchors: = _anchor_columns()
	_settle_result = []
	_settle_job = WorkerThreadPool.add_task( func() -> void : _settle_result = _find_islands(seeds, snapshot, anchors))




func _pump_mesh() -> void :
	var budget: = float(_cfg.get("load_budget_ms" if loading else "rebuild_budget_ms", 3.0)) * 1000.0
	var started: = Time.get_ticks_usec()
	if _job >= 0 and WorkerThreadPool.is_group_task_completed(_job):
		WorkerThreadPool.wait_for_group_task_completion(_job)
		_job = -1
		for i in _job_list.size():
			_ready_chunks.append([_job_list[i], _job_results[i]])


	while not _ready_chunks.is_empty() and Time.get_ticks_usec() - started < budget:
		var entry: Array = _ready_chunks.pop_front()
		_apply_chunk(entry[0], entry[1])
	if _job < 0 and not _dirty.is_empty():
		_job_list.clear()
		for chunk: Vector3i in _dirty.keys():
			_job_list.append(chunk)
			_dirty.erase(chunk)
			if _job_list.size() >= 64:
				break
		_job_results.clear()
		_job_results.resize(_job_list.size())
		var snapshot: = blocks.duplicate()
		_job = WorkerThreadPool.add_group_task( func(i: int) -> void : _job_results[i] = _mesh_chunk(_job_list[i], snapshot), 
			_job_list.size())



func _rebuild_all() -> void :
	var list: Array[Vector3i] = []
	for cx in _chunks.x:
		for cy in _chunks.y:
			for cz in _chunks.z:
				list.append(Vector3i(cx, cy, cz))
	var results: Array = []
	results.resize(list.size())
	var snapshot: = blocks
	var task: = WorkerThreadPool.add_group_task( func(i: int) -> void : results[i] = _mesh_chunk(list[i], snapshot), list.size())
	WorkerThreadPool.wait_for_group_task_completion(task)
	for i in list.size():
		_apply_chunk(list[i], results[i])
	_dirty.clear()




func _uniform_hidden(base: Vector3i, b: PackedByteArray) -> bool:
	var C: = _chunk_cells
	var x1: = mini(base.x + C, dims.x)
	var y1: = mini(base.y + C, dims.y)
	var z1: = mini(base.z + C, dims.z)
	var height: = y1 - base.y
	var first: = b[index_of(base)]
	if first != AIR and _pal_glass[first] == 1:
		return false
	var run: = PackedByteArray()
	run.resize(height)
	run.fill(first)
	for x in range(base.x, x1):
		for z in range(base.z, z1):
			var start: = (x * dims.z + z) * dims.y + base.y
			if b.slice(start, start + height) != run:
				return false
	if first == AIR:
		return true

	if base.y > 0 or y1 < dims.y:
		for x in range(base.x, x1):
			for z in range(base.z, z1):
				var column: = (x * dims.z + z) * dims.y
				if (base.y > 0 and b[column + base.y - 1] == AIR) or (y1 < dims.y and b[column + y1] == AIR):
					return false
	if base.y == 0 or y1 == dims.y:
		return false
	for side: int in [base.x - 1, x1]:
		if side < 0 or side >= dims.x:
			return false
		for z in range(base.z, z1):
			var start: = (side * dims.z + z) * dims.y + base.y
			if b.slice(start, start + height).has(AIR):
				return false
	for side: int in [base.z - 1, z1]:
		if side < 0 or side >= dims.z:
			return false
		for x in range(base.x, x1):
			var start: = (x * dims.z + side) * dims.y + base.y
			if b.slice(start, start + height).has(AIR):
				return false
	return true


func _apply_chunk(chunk: Vector3i, data: Dictionary) -> void :
	var part: Dictionary = _parts.get(chunk, {})
	if data.is_empty():
		if not part.is_empty():
			(part.mesh as MeshInstance3D).mesh = null
			(part.shape as CollisionShape3D).disabled = true
		return
	if part.is_empty():
		var mesh_node: = MeshInstance3D.new()
		add_child(mesh_node)
		var shape_node: = CollisionShape3D.new()
		var shape: = ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape_node.shape = shape
		add_child(shape_node)
		part = {"mesh": mesh_node, "shape": shape_node}
		_parts[chunk] = part
	var mesh: = ArrayMesh.new()
	for key: String in ["opaque", "glass"]:
		var arrays: Array = data.get(key, [])
		if arrays.is_empty():
			continue
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material if key == "opaque" else _glass_material)
	(part.mesh as MeshInstance3D).mesh = mesh
	((part.shape as CollisionShape3D).shape as ConcavePolygonShape3D).set_faces(data.faces)
	(part.shape as CollisionShape3D).disabled = (data.faces as PackedVector3Array).is_empty()






func _mesh_chunk(chunk: Vector3i, b: PackedByteArray) -> Dictionary:
	var C: = _chunk_cells
	var base: = chunk * C
	if _uniform_hidden(base, b):
		return {}
	var x1: = mini(base.x + C, dims.x)
	var y1: = mini(base.y + C, dims.y)
	var z1: = mini(base.z + C, dims.z)
	var H: = y1 - base.y
	var air_run: = PackedByteArray()
	air_run.resize(H)

	var cube: = C * C * C
	var masks: = PackedInt32Array()
	masks.resize(6 * cube)
	var used: = PackedByteArray()
	used.resize(6)



	var last_col: = PackedByteArray()
	var reach_lo: = 1 if base.y > 0 else 0
	var reach_hi: = 1 if y1 < dims.y else 0
	var hits_down: = PackedInt32Array()
	var hits_up: = PackedInt32Array()
	for x in range(base.x, x1):
		var lx: = x - base.x
		for z in range(base.z, z1):
			var lz: = z - base.z
			var start: = (x * dims.z + z) * dims.y + base.y
			var col: = b.slice(start, start + H)
			if col == air_run:
				continue
			var col_has_air: = col.has(AIR)
			var around: = b.slice(start - reach_lo, start + H + reach_hi)
			var same_col: = around == last_col
			if not same_col:
				last_col = around
				hits_down = PackedInt32Array()
				hits_up = PackedInt32Array()
			for d in 6:
				var axis: = d >> 1
				var sgn: = 1 if (d & 1) == 1 else -1
				if axis == 1 and same_col:
					var hits: = hits_up if (d & 1) == 1 else hits_down
					for h in range(0, hits.size(), 2):
						masks[d * cube + (hits[h] * C + lx) * C + lz] = hits[h + 1]
						used[d] = 1
					continue
				var nb: PackedByteArray
				if axis == 0:
					var nx: = x + sgn
					nb = air_run if nx < 0 or nx >= dims.x else b.slice(start + sgn * _sx, start + sgn * _sx + H)
				elif axis == 2:
					var nz: = z + sgn
					nb = air_run if nz < 0 or nz >= dims.z else b.slice(start + sgn * _sz, start + sgn * _sz + H)
				else:

					var lo: = start + sgn
					if sgn < 0 and base.y == 0:
						nb = PackedByteArray([AIR]) + b.slice(start, start + H - 1)
					elif sgn > 0 and y1 == dims.y:
						nb = b.slice(start + 1, start + H) + PackedByteArray([AIR])
					else:
						nb = b.slice(lo, lo + H)
				if nb == col and not _has_glass:
					continue
				if not col_has_air and not nb.has(AIR) and not _has_glass:
					continue
				var offset: = d * cube
				for k in H:
					var type: = col[k]
					if type == AIR:
						continue
					var other: = nb[k]
					if other == AIR or (_pal_glass[other] == 1 and _pal_glass[type] == 0):
						var slice: int
						var i: int
						var j: int
						if axis == 0:
							slice = lx;i = k;j = lz
						elif axis == 1:
							slice = k;i = lz;j = lx
						else:
							slice = lz;i = lx;j = k
						masks[offset + (slice * C + j) * C + i] = type
						used[d] = 1
						if axis == 1 and sgn > 0:
							hits_up.append(k)
							hits_up.append(type)
						elif axis == 1:
							hits_down.append(k)
							hits_down.append(type)
	var opaque: = Acc.new()
	var glass: = Acc.new()
	var mask: = PackedInt32Array()
	for d in 6:
		if used[d] == 0:
			continue
		var axis: = d >> 1
		var sgn: = 1 if (d & 1) == 1 else -1
		var u: = (axis + 1) % 3
		var v: = (axis + 2) % 3
		for s in C:
			var from: = d * cube + s * C * C
			mask = masks.slice(from, from + C * C)
			if mask.count(0) == C * C:
				continue
			var a: = base[axis] + s
			for j in C:
				var i: = 0
				while i < C:
					var type: = mask[j * C + i]
					if type == 0:
						i += 1
						continue
					var w: = 1
					while i + w < C and mask[j * C + i + w] == type:
						w += 1
					var h: = 1
					var grow: = true
					while j + h < C and grow:
						for k in w:
							if mask[(j + h) * C + i + k] != type:
								grow = false
								break
						if grow:
							h += 1
					for jj in h:
						for k in w:
							mask[(j + jj) * C + i + k] = 0
					_emit_quad(glass if _pal_glass[type] == 1 else opaque, opaque, axis, u, v, sgn, 
						a, base[u] + i, base[v] + j, w, h, type)
					i += w
	if opaque.faces.is_empty():
		return {}
	var out: = {"faces": opaque.faces}
	if not opaque.verts.is_empty():
		out["opaque"] = opaque.arrays()
	if not glass.verts.is_empty():
		out["glass"] = glass.arrays()
	return out




func _emit_quad(acc: Acc, solid: Acc, axis: int, u: int, v: int, sgn: int, a: int, i: int, j: int, w: int, h: int, 
		type: int) -> void :
	var plane: = float(a + (1 if sgn > 0 else 0))
	var p: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	var cu: Array[int] = [i, i + w, i + w, i]
	var cv: Array[int] = [j, j, j + h, j + h]
	for k in 4:
		var c: = Vector3.ZERO
		c[axis] = plane
		c[u] = float(cu[k])
		c[v] = float(cv[k])
		p[k] = origin + c * size_m
	var n: = Vector3.ZERO
	n[axis] = float(sgn)
	var first: = acc.verts.size()
	for k in 4:
		acc.verts.append(p[k])
		acc.normals.append(n)
		acc.colors.append(_pal_color[type])
		acc.uvs.append(Vector2(_pal_glow[type], 0.0))

	var order: Array = [0, 1, 2, 0, 2, 3] if (p[1] - p[0]).cross(p[2] - p[0]).dot(n) < 0.0 else [0, 2, 1, 0, 3, 2]
	for k: int in order:
		acc.indices.append(first + k)
		solid.faces.append(p[k])



class Acc:
	var verts: = PackedVector3Array()
	var normals: = PackedVector3Array()
	var colors: = PackedColorArray()
	var uvs: = PackedVector2Array()
	var indices: = PackedInt32Array()
	var faces: = PackedVector3Array()

	func arrays() -> Array:
		var out: = []
		out.resize(Mesh.ARRAY_MAX)
		out[Mesh.ARRAY_VERTEX] = verts
		out[Mesh.ARRAY_NORMAL] = normals
		out[Mesh.ARRAY_COLOR] = colors
		out[Mesh.ARRAY_TEX_UV] = uvs
		out[Mesh.ARRAY_INDEX] = indices
		return out
