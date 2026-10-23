class_name PaintSurface
extends RefCounted





const GUTTER: = 2
const CELL_M: = 0.03

var part: String
var size: int
var texture: ImageTexture
var dirty: = false
var _map: Dictionary
var _rgba: = PackedByteArray()


func _init(part_name: String, map: Dictionary) -> void :
	part = part_name
	_map = map
	size = int(map["size"])
	_rgba.resize(size * size * 4)
	texture = ImageTexture.create_from_image(Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, _rgba))


func clear() -> void :
	_rgba.fill(0)
	dirty = true


func is_blank() -> bool:
	for i in range(3, _rgba.size(), 4):
		if _rgba[i] != 0:
			return false
	return true


func bounds() -> AABB:
	return _map["bounds"]



func stamp(center: Vector3, radius: float, hardness: float, color: Color, erase: bool) -> void :
	var box: AABB = _map["bounds"]
	if not box.grow(radius).has_point(center):
		return
	var cells: Dictionary = _map["cells"]
	var positions: PackedVector3Array = _map["positions"]
	var texels: PackedInt32Array = _map["texels"]
	var reach: = ceili(radius / CELL_M)
	var middle: = Vector3i((center / CELL_M).floor())
	var soft: = maxf(radius * (1.0 - hardness), 0.0005)
	var solid: = radius - soft
	var r: = roundi(color.r8)
	var g: = roundi(color.g8)
	var b: = roundi(color.b8)
	for x in range(middle.x - reach, middle.x + reach + 1):
		for y in range(middle.y - reach, middle.y + reach + 1):
			for z in range(middle.z - reach, middle.z + reach + 1):
				var cell: Variant = cells.get(Vector3i(x, y, z))
				if cell == null:
					continue
				for index: int in cell:
					var d: = positions[index].distance_to(center)
					if d >= radius:
						continue
					var a: = 1.0 if d <= solid else 1.0 - (d - solid) / soft
					_blend(texels[index] * 4, a, r, g, b, erase)
	dirty = true


func fill(color: Color) -> void :
	var texels: PackedInt32Array = _map["texels"]
	for texel in texels:
		var at: = texel * 4
		_rgba[at] = color.r8
		_rgba[at + 1] = color.g8
		_rgba[at + 2] = color.b8
		_rgba[at + 3] = 255
	dirty = true


func commit() -> void :
	if not dirty:
		return
	dirty = false
	texture.update(Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, _rgba))



func pixels() -> PackedByteArray:
	return _rgba


func _blend(at: int, a: float, r: int, g: int, b: int, erase: bool) -> void :
	var old_a: = _rgba[at + 3] / 255.0
	if erase:
		_rgba[at + 3] = roundi(old_a * (1.0 - a) * 255.0)
		return
	var out_a: = a + old_a * (1.0 - a)
	if out_a <= 0.0:
		return
	var keep: = old_a * (1.0 - a) / out_a
	var add: = a / out_a
	_rgba[at] = roundi(r * add + _rgba[at] * keep)
	_rgba[at + 1] = roundi(g * add + _rgba[at + 1] * keep)
	_rgba[at + 2] = roundi(b * add + _rgba[at + 2] * keep)
	_rgba[at + 3] = roundi(out_a * 255.0)



static func bake(mesh: Mesh, px: int) -> Dictionary:
	return bake_arrays(mesh.surface_get_arrays(0), px)



static func bake_arrays(arrays: Array, px: int) -> Dictionary:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for i in vertices.size(): indices.append(i)
	var points_at: = PackedVector3Array()
	points_at.resize(px * px)
	var used: = PackedByteArray()
	used.resize(px * px)
	for t in range(0, indices.size() - 2, 3):
		var ia: = indices[t]
		var ib: = indices[t + 1]
		var ic: = indices[t + 2]
		var a: = uvs[ia] * px
		var b: = uvs[ib] * px
		var c: = uvs[ic] * px
		var area: = (b - a).cross(c - a)
		if absf(area) < 1e-09:
			continue
		var x0: = clampi(floori(minf(a.x, minf(b.x, c.x))), 0, px - 1)
		var x1: = clampi(ceili(maxf(a.x, maxf(b.x, c.x))), 0, px - 1)
		var y0: = clampi(floori(minf(a.y, minf(b.y, c.y))), 0, px - 1)
		var y1: = clampi(ceili(maxf(a.y, maxf(b.y, c.y))), 0, px - 1)
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var p: = Vector2(x + 0.5, y + 0.5)
				var w0: = (c - b).cross(p - b) / area
				var w1: = (a - c).cross(p - c) / area
				var w2: = 1.0 - w0 - w1
				if w0 < -0.001 or w1 < -0.001 or w2 < -0.001:
					continue
				var at: = y * px + x
				if used[at] == 0:
					used[at] = 1
					points_at[at] = vertices[ia] * w0 + vertices[ib] * w1 + vertices[ic] * w2

	for _pass in GUTTER:
		var grown: = used.duplicate()
		for y in px:
			for x in px:
				var at: = y * px + x
				if used[at] != 0:
					continue
				for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: = x + offset.x
					var ny: = y + offset.y
					if nx < 0 or ny < 0 or nx >= px or ny >= px or used[ny * px + nx] == 0:
						continue
					points_at[at] = points_at[ny * px + nx]
					grown[at] = 1
					break
		used = grown
	var positions: = PackedVector3Array()
	var texels: = PackedInt32Array()
	var cells: = {}
	var box: = AABB()
	for at in px * px:
		if used[at] == 0:
			continue
		var point: = points_at[at]
		box = AABB(point, Vector3.ZERO) if positions.is_empty() else box.expand(point)
		var key: = Vector3i((point / CELL_M).floor())
		if not cells.has(key):
			cells[key] = PackedInt32Array()
		var list: PackedInt32Array = cells[key]
		list.append(positions.size())
		cells[key] = list
		positions.append(point)
		texels.append(at)
	return {"size": px, "positions": positions, "texels": texels, "cells": cells, "bounds": box}
