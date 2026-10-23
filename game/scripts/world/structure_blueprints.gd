class_name StructureBlueprints
extends RefCounted









const PATH: = "res://data/world/blueprints.json"

static var _data: Dictionary = {}


static func ids() -> PackedStringArray:
	_load()
	var out: = PackedStringArray()
	for id: String in _data:
		if not id.begins_with("_"):
			out.append(id)
	return out


static func chunks(id: String) -> Array:
	_load()
	var bp: Dictionary = _data.get(id, {})
	match String(bp.get("type", "")):
		"house":
			return _house(bp)
		"wall":
			return _wall(bp)
		"box":
			return _box(bp)
		"rock":
			return _rock(bp)
	push_warning("[Mundo] planta desconhecida: %s" % id)
	return []


static func _load() -> void :
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(PATH))




static func _house(bp: Dictionary) -> Array:
	var size: Array = bp["size"]
	var w: = float(size[0])
	var d: = float(size[1])
	var h: = float(bp.get("height", 3.0))
	var t: = float(bp.get("thickness", 0.25))
	var block: Array = bp.get("block", [1.0, 0.5])
	var material: = String(bp.get("wall", "brick"))
	var out: Array = []
	var openings: Array = bp.get("openings", [])

	var sides: = {
		"front": {"origin": Vector3(0, 0, d * 0.5 - t * 0.5), "axis": Vector3.RIGHT, "length": w}, 
		"back": {"origin": Vector3(0, 0, - d * 0.5 + t * 0.5), "axis": Vector3.RIGHT, "length": w}, 
		"left": {"origin": Vector3( - w * 0.5 + t * 0.5, 0, 0), "axis": Vector3.BACK, "length": d - 2.0 * t}, 
		"right": {"origin": Vector3(w * 0.5 - t * 0.5, 0, 0), "axis": Vector3.BACK, "length": d - 2.0 * t}, 
	}
	for side: String in sides:
		var info: Dictionary = sides[side]
		var holes: Array = openings.filter( func(o: Dictionary) -> bool: return String(o.get("side", "")) == side)
		out.append_array(_run(info["origin"], info["axis"], float(info["length"]), h, float(block[0]), float(block[1]), t, 
			material, holes))
	var roof: = String(bp.get("roof", ""))
	if not roof.is_empty():
		var tile: = float(bp.get("roof_block", 1.0))
		var rt: = float(bp.get("roof_thickness", 0.2))
		var nx: = maxi(1, roundi(w / tile))
		var nz: = maxi(1, roundi(d / tile))
		for ix in nx:
			for iz in nz:
				var cx: = - w * 0.5 + (ix + 0.5) * w / nx
				var cz: = - d * 0.5 + (iz + 0.5) * d / nz
				out.append({"pos": Vector3(cx, h + rt * 0.5, cz), "size": Vector3(w / nx, rt, d / nz), "material": roof})
	return out





static func _run(origin: Vector3, axis: Vector3, length: float, height: float, bx: float, by: float, thickness: float, 
		material: String, holes: Array) -> Array:
	var out: Array = []
	var rows: = maxi(1, roundi(height / by))
	var row_h: = height / rows
	var half: = length * 0.5
	for r in rows:
		var y0: = r * row_h
		var y1: = y0 + row_h
		var u: = - half
		var first: = bx * 0.5 if r % 2 == 1 else bx
		while u < half - 0.001:
			var u1: = minf(u + first, half)
			first = bx
			for piece: Vector2 in _cut(u, u1, y0, y1, holes):
				out.append(_on_axis(origin, axis, piece, y0, y1, thickness, material))
			u = u1
	for hole: Dictionary in holes:
		if hole.has("fill"):
			var at: = float(hole.get("at", 0.0))
			var hw: = float(hole["width"]) * 0.5
			var b0: = float(hole.get("bottom", 0.0))
			out.append(_on_axis(origin, axis, Vector2(at - hw, at + hw), b0, b0 + float(hole["height"]), 
				float(hole.get("fill_thickness", 0.04)), String(hole["fill"])))
	return out




static func _cut(u0: float, u1: float, y0: float, y1: float, holes: Array) -> Array[Vector2]:
	var pieces: Array[Vector2] = [Vector2(u0, u1)]
	for hole: Dictionary in holes:
		var b0: = float(hole.get("bottom", 0.0))
		var b1: = b0 + float(hole["height"])
		var overlap: = minf(y1, b1) - maxf(y0, b0)
		if overlap < (y1 - y0) * 0.5:
			continue
		var at: = float(hole.get("at", 0.0))
		var h0: = at - float(hole["width"]) * 0.5
		var h1: = at + float(hole["width"]) * 0.5
		var next: Array[Vector2] = []
		for p in pieces:
			if p.y <= h0 or p.x >= h1:
				next.append(p)
				continue
			if p.x < h0 - 0.02:
				next.append(Vector2(p.x, h0))
			if p.y > h1 + 0.02:
				next.append(Vector2(h1, p.y))
		pieces = next
	return pieces


static func _on_axis(origin: Vector3, axis: Vector3, span: Vector2, y0: float, y1: float, thickness: float, 
		material: String) -> Dictionary:
	var center_u: = (span.x + span.y) * 0.5
	var along: = span.y - span.x
	var pos: = origin + axis * center_u + Vector3.UP * ((y0 + y1) * 0.5)
	var size: = Vector3(along, y1 - y0, thickness) if absf(axis.x) > 0.5 else Vector3(thickness, y1 - y0, along)
	return {"pos": pos, "size": size, "material": material}




static func _wall(bp: Dictionary) -> Array:
	var block: Array = bp.get("block", [1.0, 0.5])
	var length: = float(bp.get("length", 4.0))
	var height: = float(bp.get("height", 2.0))
	var chunks: = _run(Vector3.ZERO, Vector3.RIGHT, length, height, float(block[0]), float(block[1]), 
		float(bp.get("thickness", 0.3)), String(bp.get("material", "concrete")), [])
	if not bp.get("broken", false):
		return chunks

	var kept: Array = []
	for chunk: Dictionary in chunks:
		var pos: Vector3 = chunk["pos"]
		var top: = height * (0.45 + 0.55 * absf(sin(pos.x * 1.37 + 0.6)))
		if pos.y - (chunk["size"] as Vector3).y * 0.5 < top:
			kept.append(chunk)
	return kept


static func _box(bp: Dictionary) -> Array:
	var size: Array = bp.get("size", [1.0, 1.0, 1.0])
	var cells: Array = bp.get("cells", [2, 2, 2])
	var full: = Vector3(float(size[0]), float(size[1]), float(size[2]))
	var n: = Vector3i(int(cells[0]), int(cells[1]), int(cells[2]))
	var cell: = Vector3(full.x / n.x, full.y / n.y, full.z / n.z)
	var out: Array = []
	for x in n.x:
		for y in n.y:
			for z in n.z:
				var pos: = Vector3( - full.x * 0.5 + (x + 0.5) * cell.x, (y + 0.5) * cell.y, - full.z * 0.5 + (z + 0.5) * cell.z)
				out.append({"pos": pos, "size": cell, "material": String(bp.get("material", "wood"))})
	return out


static func _rock(bp: Dictionary) -> Array:
	var size: Array = bp.get("size", [2.0, 1.4, 1.6])
	var s: = Vector3(float(size[0]), float(size[1]), float(size[2]))
	var material: = String(bp.get("material", "stone"))
	var out: Array = []


	var heights: = [1.0, 0.8, 0.65, 0.9]
	for i in 4:
		var cx: = (-0.22 if i % 2 == 0 else 0.22) * s.x
		var cz: = (-0.22 if i < 2 else 0.22) * s.z
		var hy: = s.y * float(heights[i])
		out.append({"pos": Vector3(cx, 0.0, cz), "size": Vector3(s.x * 0.62, hy * 2.0, s.z * 0.62), "material": material, 
			"shape": "ellipsoid"})
	for j in 4:
		var angle: = j * PI * 0.5 + 0.4
		var chip: = Vector3(s.x * 0.36, s.y * 0.7, s.z * 0.36)
		var pos: = Vector3(cos(angle) * s.x * 0.42, 0.0, sin(angle) * s.z * 0.42)
		out.append({"pos": pos, "size": chip, "material": material, "shape": "ellipsoid"})
	return out
