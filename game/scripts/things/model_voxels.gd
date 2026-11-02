class_name ModelVoxels
extends RefCounted




















class Buffers extends RefCounted:
	var verts: = PackedVector3Array()
	var normals: = PackedVector3Array()
	var colors: = PackedColorArray()
	var uv: = PackedVector2Array()
	var uv2: = PackedVector2Array()
	var indices: = PackedInt32Array()




class PieceShape extends RefCounted:
	const BOX: = 0
	const CYLINDER: = 1
	const SPHERE: = 2
	const TORUS: = 3
	const CAPSULE: = 4
	const WEDGE: = 5
	var kind: = BOX
	var radius: = 0.1
	var height: = 0.2
	var top: = 0.1
	var ring: = 0.0
	var tube2: = 0.0
	var reach: = 0.0
	var half: = Vector3.ONE
	var tip_y: = 0.0

	func _init(piece: Dictionary) -> void :
		radius = float(piece.get("radius", 0.1))
		height = float(piece.get("height", 0.2))
		match String(piece.get("shape", "box")):
			"cylinder", "cone":
				kind = CYLINDER
				top = 0.0 if String(piece.get("shape")) == "cone" else float(piece.get("top_radius", radius))
			"sphere":
				kind = SPHERE
			"torus":
				kind = TORUS
				var inner: = float(piece.get("inner_radius", radius * 0.7))
				ring = (radius + inner) * 0.5
				tube2 = pow((radius - inner) * 0.5, 2.0)
			"capsule":
				kind = CAPSULE
				reach = maxf(maxf(height, radius * 2.0) * 0.5 - radius, 0.0)
			"wedge":
				kind = WEDGE
				half = ModelBuilder._vec(piece.get("size", [0.02, 0.05, 0.1])) * 0.5
				tip_y = lerpf( - half.y, half.y, clampf(float(piece.get("point", 0.5)), 0.0, 1.0))
			_:
				half = ModelBuilder._vec(piece.get("size", [0.5, 0.5, 0.5])) * 0.5

	func inside(p: Vector3) -> bool:
		match kind:
			CYLINDER:
				if absf(p.y) > height * 0.5:
					return false
				var r: = lerpf(radius, top, (p.y + height * 0.5) / maxf(height, 0.0001))
				return p.x * p.x + p.z * p.z <= r * r
			SPHERE:
				return p.length_squared() <= radius * radius
			TORUS:
				var d: = sqrt(p.x * p.x + p.z * p.z) - ring
				return d * d + p.y * p.y <= tube2
			CAPSULE:
				var y: = p.y - clampf(p.y, - reach, reach)
				return p.x * p.x + y * y + p.z * p.z <= radius * radius
			WEDGE:
				if absf(p.x) > half.x or absf(p.z) > half.z:
					return false
				var t: = (half.z - p.z) / maxf(half.z * 2.0, 0.0001)
				return p.y >= lerpf( - half.y, tip_y, t) and p.y <= lerpf(half.y, tip_y, t)
		return absf(p.x) <= half.x and absf(p.y) <= half.y and absf(p.z) <= half.z



	func row_span(start: Vector3, step: Vector3, count: int) -> Vector2i:
		var lo: = 0.0
		var hi: = float(count - 1)
		if kind == BOX:
			for axis in 3:
				var s: = step[axis]
				var p: = start[axis]
				var h: = half[axis]
				if absf(s) < 1e-09:
					if absf(p) > h:
						return Vector2i(-2, -2)
					continue
				var a: = ( - h - p) / s
				var b: = (h - p) / s
				lo = maxf(lo, minf(a, b))
				hi = minf(hi, maxf(a, b))
		elif kind == SPHERE:

			var a: = step.length_squared()
			var b: = start.dot(step)
			var c: = start.length_squared() - radius * radius
			var disc: = b * b - a * c
			if disc < 0.0 or a < 1e-12:
				return Vector2i(-2, -2) if c > 0.0 else Vector2i(0, count - 1)
			var root: = sqrt(disc)
			lo = maxf(lo, ( - b - root) / a)
			hi = minf(hi, ( - b + root) / a)
		else:
			return Vector2i(-1, -1)
		var first: = ceili(lo - 1e-06)
		var last: = floori(hi + 1e-06)
		if first > last:
			return Vector2i(-2, -2)
		return Vector2i(maxi(first, 0), mini(last, count - 1))



const AO_LEVELS: = [0.68, 0.8, 0.9, 1.0]




static func build(entries: Array[Dictionary], grain: float, min_cell: float, max_cell: float, max_cells: int, 
		slender_max: float = 1.0, slender_min_m: float = 0.0) -> Dictionary:
	var meshes: Array = []
	meshes.resize(entries.size())
	if entries.is_empty():
		return {"meshes": meshes, "cell": 0.0}

	var boxes: Array[AABB] = []
	var whole: = AABB()
	var has_whole: = false
	for i in entries.size():
		var extent: = ModelBuilder._shape_extent(entries[i]["piece"])
		var box: AABB = (entries[i]["xform"] as Transform3D) * AABB( - extent * 0.5, extent)
		boxes.append(box)
		if not bool((entries[i]["piece"] as Dictionary).get("decal", false)):
			whole = whole.merge(box) if has_whole else box
			has_whole = true
	var sides: = [whole.size.x, whole.size.y, whole.size.z]
	sides.sort()
	var longest: float = sides[2]



	var slender: = 1.0
	if longest >= slender_min_m:
		slender = clampf(sqrt(longest / maxf(float(sides[1]), 0.0001)), 1.0, maxf(slender_max, 1.0))
	var cell: = clampf(longest / maxf(grain * slender, 1.0), min_cell, max_cell)
	var volume: = maxf(whole.size.x, cell) * maxf(whole.size.y, cell) * maxf(whole.size.z, cell)
	cell = maxf(cell, pow(volume / float(max_cells), 1.0 / 3.0))
	var origin: = (whole.position / cell).floor() * cell
	var dims: = Vector3i(((whole.end - origin) / cell).ceil()) + Vector3i.ONE
	var owners: Dictionary = {}
	var inverses: Array[Transform3D] = []
	for i in entries.size():
		var piece: Dictionary = entries[i]["piece"]
		var bone: = String(piece.get("bone", ""))
		if not owners.has(bone):
			var fresh: = PackedInt32Array()
			fresh.resize(dims.x * dims.y * dims.z)
			fresh.fill(-1)
			owners[bone] = fresh
		var owner: PackedInt32Array = owners[bone]
		var xform: Transform3D = entries[i]["xform"]
		var inverse: = xform.affine_inverse()
		inverses.append(inverse)
		var decal: = bool(piece.get("decal", false))
		var lo: = Vector3i(((boxes[i].position - origin) / cell).floor()).clamp(Vector3i.ZERO, dims - Vector3i.ONE)
		var hi: = Vector3i(((boxes[i].end - origin) / cell).floor()).clamp(Vector3i.ZERO, dims - Vector3i.ONE)
		var claimed: = 0
		var shape: PieceShape = null
		if String(piece.get("shape", "box")) == "box" and _axis_aligned(xform.basis):

			var a: = Vector3i(((boxes[i].position - origin) / cell - Vector3(0.5, 0.5, 0.5)).ceil()).clamp(Vector3i.ZERO, dims)
			var b: = Vector3i(((boxes[i].end - origin) / cell - Vector3(0.5, 0.5, 0.5)).floor()).clamp( - Vector3i.ONE, dims - Vector3i.ONE)
			for x in range(a.x, b.x + 1):
				for y in range(a.y, b.y + 1):
					var row: = (x * dims.y + y) * dims.z
					for z in range(a.z, b.z + 1):
						if decal and owner[row + z] < 0:
							continue
						owner[row + z] = i
						claimed += 1
		elif not _thin(piece, xform, cell):
			shape = PieceShape.new(piece)

			var step_z: = inverse.basis * Vector3(0.0, 0.0, cell)
			for x in range(lo.x, hi.x + 1):
				for y in range(lo.y, hi.y + 1):
					var row: = (x * dims.y + y) * dims.z
					var local: = inverse * (origin + (Vector3(x, y, lo.z) + Vector3(0.5, 0.5, 0.5)) * cell)
					var span_z: = shape.row_span(local, step_z, hi.z - lo.z + 1)
					if span_z.x >= 0:

						for z in range(lo.z + span_z.x, lo.z + span_z.y + 1):
							if not decal or owner[row + z] >= 0:
								owner[row + z] = i
								claimed += 1
						continue
					if span_z.x == -2:
						continue
					for z in range(lo.z, hi.z + 1):
						if ( not decal or owner[row + z] >= 0) and shape.inside(local):
							owner[row + z] = i
							claimed += 1
						local += step_z



		var extent: = ModelBuilder._shape_extent(piece)
		if (claimed == 0 and not decal) or _thin(piece, xform, cell):
			_trace(shape if shape != null else PieceShape.new(piece), xform, extent, cell, origin, dims, owner, i, decal)
		owners[bone] = owner

	var pd: = dims + Vector3i(2, 2, 2)
	for bone: String in owners:
		var owner: PackedInt32Array = owners[bone]
		var solid: = PackedByteArray()
		solid.resize(pd.x * pd.y * pd.z)
		var cells: Array[PackedInt32Array] = []
		cells.resize(entries.size())
		for x in dims.x:
			for y in dims.y:
				var row: = (x * dims.y + y) * dims.z
				var padded: = ((x + 1) * pd.y + y + 1) * pd.z + 1
				for z in dims.z:
					var who: = owner[row + z]
					if who >= 0:
						solid[padded + z] = 1
						cells[who].append(padded + z)
		for i in entries.size():
			if String((entries[i]["piece"] as Dictionary).get("bone", "")) == bone:
				meshes[i] = _piece_mesh(cells[i], inverses[i], cell, origin, dims, solid)
	return {"meshes": meshes, "cell": cell}



static func _thin(piece: Dictionary, xform: Transform3D, cell: float) -> bool:
	var size: = ModelBuilder._shape_extent(piece) * xform.basis.get_scale().abs()
	return minf(size.x, minf(size.y, size.z)) < cell * 1.5


static func _axis_aligned(basis: Basis) -> bool:
	for axis in 3:
		var column: = basis[axis].normalized()
		if maxf(absf(column.x), maxf(absf(column.y), absf(column.z))) < 0.9999:
			return false
	return true



static func _trace(shape: PieceShape, xform: Transform3D, extent: Vector3, cell: float, origin: Vector3, dims: Vector3i, 
		owner: PackedInt32Array, index: int, decal: bool) -> void :
	var step: = cell * 0.5



	var size: = extent * xform.basis.get_scale().abs()
	var counts: = Vector3i(ceili(size.x / step) | 1, ceili(size.y / step) | 1, ceili(size.z / step) | 1)
	if counts.x * counts.y * counts.z > 200000:
		return
	for a in counts.x:
		for b in counts.y:
			for c in counts.z:
				var local: = (Vector3(a + 0.5, b + 0.5, c + 0.5) / Vector3(counts) - Vector3(0.5, 0.5, 0.5)) * extent
				if not shape.inside(local):
					continue
				var at: = Vector3i(((xform * local - origin) / cell).floor())
				if at.x < 0 or at.y < 0 or at.z < 0 or at.x >= dims.x or at.y >= dims.y or at.z >= dims.z:
					continue
				var slot: = (at.x * dims.y + at.y) * dims.z + at.z
				if decal and owner[slot] < 0:
					continue
				owner[slot] = index





static func _piece_mesh(cells: PackedInt32Array, inverse: Transform3D, cell: float, origin: Vector3, dims: Vector3i, 
		solid: PackedByteArray) -> Mesh:
	if cells.is_empty():
		return null
	var pd: = dims + Vector3i(2, 2, 2)
	var strides: = Vector3i(pd.y * pd.z, pd.z, 1)

	var faces: = {}
	for p in cells:
		var at: = Vector3i(p / strides.x, (p / strides.y) % pd.y, p % pd.z)
		for axis in 3:
			var u: = (axis + 1) % 3
			var v: = (axis + 2) % 3
			var su: = strides[u]
			var sv: = strides[v]
			for side in 2:
				var n: = p + (strides[axis] if side == 1 else - strides[axis])
				if solid[n] != 0:
					continue
				var code: = 0
				for k in 4:
					var du: = - su if k == 0 or k == 3 else su
					var dv: = - sv if k < 2 else sv
					var a_side: = solid[n + du]
					var b_side: = solid[n + dv]
					var level: = 0 if a_side != 0 and b_side != 0 else 3 - a_side - b_side - solid[n + du + dv]
					code |= level << (k * 2)
				var key: = (axis * 2 + side) * 65536 + at[axis]
				if not faces.has(key):
					faces[key] = {}
				(faces[key] as Dictionary)[Vector2i(at[u], at[v])] = code
	var out: = Buffers.new()
	for key: int in faces:
		var axis: = (key / 65536) / 2
		var sgn: = 1 if (key / 65536) % 2 == 1 else -1
		var layer: = key % 65536
		var u: = (axis + 1) % 3
		var v: = (axis + 2) % 3
		var normal: = Vector3.ZERO
		normal[axis] = float(sgn)
		var local_normal: = (inverse.basis * normal).normalized()
		var layer_id: = float(key / 65536) * 4096.0 + float(layer)
		var mask: Dictionary = faces[key]
		var spots: = mask.keys()
		spots.sort()
		for spot: Vector2i in spots:
			if not mask.has(spot):
				continue
			var code: int = mask[spot]
			if code != 255:
				mask.erase(spot)
				_quad(out, axis, sgn, u, v, layer, spot.x, spot.y, 1, 1, code, cell, origin, inverse, local_normal, layer_id)
				continue

			var span_b: = 1
			while mask.get(spot + Vector2i(0, span_b), -1) == 255:
				span_b += 1
			var span_a: = 1
			var grow: = true
			while grow:
				for k in span_b:
					if mask.get(spot + Vector2i(span_a, k), -1) != 255:
						grow = false
						break
				if grow:
					span_a += 1
			for da in span_a:
				for db in span_b:
					mask.erase(spot + Vector2i(da, db))
			_quad(out, axis, sgn, u, v, layer, spot.x, spot.y, span_a, span_b, 255, cell, origin, inverse, local_normal, layer_id)
	if out.verts.is_empty():
		return null
	var arrays: = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out.verts
	arrays[Mesh.ARRAY_NORMAL] = out.normals
	arrays[Mesh.ARRAY_COLOR] = out.colors
	arrays[Mesh.ARRAY_TEX_UV] = out.uv
	arrays[Mesh.ARRAY_TEX_UV2] = out.uv2
	arrays[Mesh.ARRAY_INDEX] = out.indices
	var mesh: = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh




static func _quad(out: Buffers, axis: int, sgn: int, u: int, v: int, layer: int, a: int, b: int, span_a: int, 
		span_b: int, code: int, cell: float, origin: Vector3, inverse: Transform3D, local_normal: Vector3, 
		layer_id: float) -> void :
	var ao: = PackedInt32Array([code & 3, (code >> 2) & 3, (code >> 4) & 3, (code >> 6) & 3])

	var base: = Vector3.ONE * -1.0
	base[axis] = float(layer - 1 + (1 if sgn > 0 else 0))
	base[u] = float(a - 1)
	base[v] = float(b - 1)
	var du: = Vector3.ZERO
	du[u] = float(span_a)
	var dv: = Vector3.ZERO
	dv[v] = float(span_b)
	var normal: = Vector3.ZERO
	normal[axis] = float(sgn)
	var first: = out.verts.size()
	var corners: = [base, base + du, base + du + dv, base + dv]
	for k in 4:
		var grid: Vector3 = corners[k]
		out.verts.append(inverse * (origin + grid * cell))
		out.normals.append(local_normal)
		var light: float = AO_LEVELS[ao[k]]
		out.colors.append(Color(light, light, light))
		out.uv.append(Vector2(grid[u], grid[v]))
		out.uv2.append(Vector2(layer_id, 1.0))


	var outward: = du.cross(dv).dot(normal) < 0.0
	var flip: = ao[0] + ao[2] < ao[1] + ao[3]
	var order: Array
	if not flip:
		order = [0, 1, 2, 0, 2, 3] if outward else [0, 2, 1, 0, 3, 2]
	else:
		order = [1, 2, 3, 1, 3, 0] if outward else [1, 3, 2, 1, 0, 3]
	for k: int in order:
		out.indices.append(first + k)
