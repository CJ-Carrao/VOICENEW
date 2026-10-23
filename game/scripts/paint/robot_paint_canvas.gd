class_name RobotPaintCanvas
extends RefCounted




static var _meshes: Dictionary = {}
static var _maps: Dictionary = {}

static var _arrays: Dictionary = {}

static var _maps_lock: = Mutex.new()

var surfaces: Dictionary = {}


func _init() -> void :
	var meshes: = paintable_meshes()
	for part: String in meshes:
		surfaces[part] = PaintSurface.new(part, _map(part, meshes[part]))





static func prepare() -> void :
	var meshes: = paintable_meshes()
	for part: String in meshes:
		if not _arrays.has(part):
			_arrays[part] = (meshes[part] as Mesh).surface_get_arrays(0)



static func paintable_meshes() -> Dictionary:
	if _meshes.is_empty():
		var model: = (load(String(RobotBody.config()["model"])) as PackedScene).instantiate()
		for node in model.find_children("*", "MeshInstance3D", true, false):
			var mesh: = node as MeshInstance3D
			if RobotPaint.is_paintable(String(mesh.name)):
				_meshes[String(mesh.name)] = mesh.mesh
		model.free()
	return _meshes


static func texture_px(part: String) -> int:
	var sizes: Dictionary = RobotPaint.config().get("texture_px", {})
	for prefix: String in sizes:
		if part.begins_with(prefix):
			return int(sizes[prefix])
	return 128



static func mirror_part(part: String) -> String:
	if part.ends_with("_L"):
		return part.trim_suffix("_L") + "_R"
	if part.ends_with("_R"):
		return part.trim_suffix("_R") + "_L"
	return part


static func mirror_point(point: Vector3) -> Vector3:
	return Vector3( - point.x, point.y, point.z)


static func _map(part: String, mesh: Mesh) -> Dictionary:
	_maps_lock.lock()
	if not _maps.has(part):
		var arrays: Array = _arrays[part] if _arrays.has(part) else mesh.surface_get_arrays(0)
		_maps[part] = PaintSurface.bake_arrays(arrays, texture_px(part))
	var map: Dictionary = _maps[part]
	_maps_lock.unlock()
	return map


func texture(part: String) -> Texture2D:
	return (surfaces[part] as PaintSurface).texture if surfaces.has(part) else null


func clear() -> void :
	for surface: PaintSurface in surfaces.values():
		surface.clear()



func apply(paint: RobotPaint) -> void :
	paint_strokes(paint)
	commit()



func paint_strokes(paint: RobotPaint) -> void :
	clear()
	for stroke in paint.strokes:
		apply_stroke(stroke)



func apply_stroke(stroke: Dictionary, from_point: int = 0) -> void :
	var color: = RobotColor.from_rgb24(int(stroke["color"]))
	var mirror: = bool(stroke["mirror"])
	if stroke["tool"] == "fill":
		var parts: = [String(stroke["part"])]
		if mirror and not parts.has(mirror_part(parts[0])):
			parts.append(mirror_part(parts[0]))
		for part: String in parts:
			if surfaces.has(part):
				(surfaces[part] as PaintSurface).fill(color)
		return
	var erase: bool = stroke["tool"] == "erase"
	var radius: = float(stroke["r"]) / 1000.0
	var hardness: = float(stroke["h"]) / 100.0
	var count: = (stroke["p"] as PackedInt32Array).size() / 3
	for i in range(from_point, count):
		var center: = RobotPaint.point(stroke, i)
		_stamp(center, radius, hardness, color, erase)
		if mirror and absf(center.x) > 0.0005:
			_stamp(mirror_point(center), radius, hardness, color, erase)


func commit() -> void :
	for surface: PaintSurface in surfaces.values():
		surface.commit()


func _stamp(center: Vector3, radius: float, hardness: float, color: Color, erase: bool) -> void :
	for surface: PaintSurface in surfaces.values():
		surface.stamp(center, radius, hardness, color, erase)
