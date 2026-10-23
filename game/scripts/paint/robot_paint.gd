class_name RobotPaint
extends RefCounted









const TOOLS: = ["brush", "erase", "fill"]

var strokes: Array[Dictionary] = []
var stickers: Array[Dictionary] = []


static func config() -> Dictionary:
	return RobotBody.config().get("paint", {})


static func is_paintable(part: String) -> bool:
	for prefix: String in config().get("part_prefixes", []):
		if part.begins_with(prefix):
			return true
	return false


func is_empty() -> bool:
	return strokes.is_empty() and stickers.is_empty()


func point_count() -> int:
	var total: = 0
	for stroke in strokes:
		total += (stroke["p"] as PackedInt32Array).size() / 3
	return total



func add(stroke: Dictionary) -> bool:
	var cfg: = config()
	if not valid_stroke(stroke) or strokes.size() >= int(cfg.get("max_strokes", 400))\
	or point_count() + (stroke["p"] as PackedInt32Array).size() / 3 > int(cfg.get("max_points", 8000)):
		return false
	strokes.append(stroke)
	return true


func add_sticker(sticker: Dictionary) -> bool:
	if not valid_sticker(sticker) or stickers.size() >= int(config().get("max_stickers", 5)):
		return false
	stickers.append(sticker)
	return true


static func sticker(id: String, center: Vector3, normal: Vector3, up: Vector3, size_m: float, mirror: bool) -> Dictionary:
	return {"id": id, "c": _mm(center, 1000.0), "n": _mm(normal.normalized(), 1000.0), "u": _mm(up.normalized(), 1000.0), 
		"s": roundi(size_m * 1000.0), "mirror": mirror}


static func _mm(value: Vector3, scale: float) -> PackedInt32Array:
	return PackedInt32Array([roundi(value.x * scale), roundi(value.y * scale), roundi(value.z * scale)])


static func vec(values: PackedInt32Array, scale: float = 1000.0) -> Vector3:
	return Vector3(values[0], values[1], values[2]) / scale


static func valid_sticker(sticker: Variant) -> bool:
	if not sticker is Dictionary:
		return false
	var s: = sticker as Dictionary
	if s.size() != 6 or not s.get("id") is String or (s.id as String).length() > 64 or (s.id as String).is_empty() or not s.get("mirror") is bool or not s.get("s") is int:
		return false
	for key in ["c", "n", "u"]:
		if not s.get(key) is PackedInt32Array or (s[key] as PackedInt32Array).size() != 3:
			return false
		for value in s[key]:
			if absi(value) > 3000:
				return false
	var size: = float(s.s) / 1000.0
	var cfg: = config()
	return size >= float(cfg.get("sticker_size_min_m", 0.04)) - 0.0005 and size <= float(cfg.get("sticker_size_max_m", 0.4)) + 0.0005 and vec(s.n).length() > 0.9 and vec(s.u).length() > 0.9


static func brush(tool: String, color: int, radius_m: float, hardness: float, mirror: bool) -> Dictionary:
	return {"tool": tool, "color": color, "r": roundi(radius_m * 1000.0), "h": roundi(hardness * 100.0), 
		"mirror": mirror, "part": "", "p": PackedInt32Array()}


static func fill(part: String, color: int, mirror: bool) -> Dictionary:
	return {"tool": "fill", "color": color, "r": 0, "h": 100, "mirror": mirror, "part": part, "p": PackedInt32Array()}


static func append_point(stroke: Dictionary, point: Vector3) -> void :
	var points: = stroke["p"] as PackedInt32Array
	points.append_array(PackedInt32Array([roundi(point.x * 1000.0), roundi(point.y * 1000.0), roundi(point.z * 1000.0)]))
	stroke["p"] = points


static func point(stroke: Dictionary, index: int) -> Vector3:
	var p: = stroke["p"] as PackedInt32Array
	return Vector3(p[index * 3], p[index * 3 + 1], p[index * 3 + 2]) / 1000.0



static func valid_stroke(stroke: Variant) -> bool:
	if not stroke is Dictionary:
		return false
	var cfg: = config()
	var s: = stroke as Dictionary
	if s.size() != 7 or not s.get("tool") is String or not TOOLS.has(s.tool) or not s.get("color") is int\
	or not s.get("r") is int or not s.get("h") is int or not s.get("mirror") is bool\
	or not s.get("part") is String or not s.get("p") is PackedInt32Array:
		return false
	if int(s.color) < 0 or int(s.color) > 16777215 or int(s.h) < 0 or int(s.h) > 100:
		return false
	var points: = s.p as PackedInt32Array
	if s.tool == "fill":
		return is_paintable(s.part) and points.is_empty()
	var radius: = float(s.r) / 1000.0
	if radius < float(cfg.get("radius_min_m", 0.006)) - 0.0005 or radius > float(cfg.get("radius_max_m", 0.12)) + 0.0005:
		return false
	if not (s.part as String).is_empty() or points.is_empty() or points.size() % 3 != 0\
	or points.size() / 3 > int(cfg.get("max_stroke_points", 600)):
		return false
	for value in points:
		if absi(value) > 3000:
			return false
	return true


func stickers_data() -> Array:
	var out: Array = []
	for s in stickers:
		out.append({"id": s.id, "c": Array(s.c), "n": Array(s.n), "u": Array(s.u), "s": s.s, "mirror": s.mirror})
	return out



func to_data() -> Array:
	var out: Array = []
	for s in strokes:
		out.append({"tool": s.tool, "color": s.color, "r": s.r, "h": s.h, "mirror": s.mirror, "part": s.part, 
			"p": Array(s.p as PackedInt32Array)})
	return out


static func from_data(data: Variant, sticker_data: Variant = []) -> RobotPaint:
	var paint: = RobotPaint.new()
	if sticker_data is Array:
		for item: Variant in sticker_data:
			if not item is Dictionary:
				continue
			var raw: = item as Dictionary
			var parsed: = {"id": raw.get("id"), "s": _int(raw.get("s")), "mirror": raw.get("mirror")}
			for key in ["c", "n", "u"]:
				var values: = PackedInt32Array()
				if raw.get(key) is Array:
					for value: Variant in raw[key]:
						if (value is int or value is float) and is_finite(float(value)): values.append(int(value))
				parsed[key] = values
			paint.add_sticker(parsed)
	if not data is Array:
		return paint
	for item: Variant in data:
		if not item is Dictionary:
			continue
		var raw: = item as Dictionary
		var points: = PackedInt32Array()
		var ok: = raw.get("p") is Array
		if ok:
			for value: Variant in raw.p:
				if not (value is int or value is float) or not is_finite(float(value)):
					ok = false
					break
				points.append(int(value))
		if not ok:
			continue
		var stroke: = {"tool": raw.get("tool"), "color": _int(raw.get("color")), "r": _int(raw.get("r")), 
			"h": _int(raw.get("h")), "mirror": raw.get("mirror"), "part": raw.get("part"), "p": points}
		paint.add(stroke)
	return paint



func encode() -> PackedByteArray:
	var raw: = var_to_bytes({"s": to_data(), "k": stickers_data()})
	var packed: = raw.compress(FileAccess.COMPRESSION_ZSTD)
	var out: = PackedByteArray()
	out.resize(4)
	out.encode_u32(0, raw.size())
	out.append_array(packed)
	return out


static func decode(bytes: PackedByteArray, max_bytes: int = 262144) -> RobotPaint:
	if bytes.size() < 4:
		return RobotPaint.new()
	var size: = bytes.decode_u32(0)
	if size == 0 or size > max_bytes:
		return RobotPaint.new()
	var raw: = bytes.slice(4).decompress(size, FileAccess.COMPRESSION_ZSTD)
	if raw.size() != size:
		return RobotPaint.new()
	var data: Variant = bytes_to_var(raw)
	if data is Dictionary:
		return from_data(data.get("s"), data.get("k", []))
	return from_data(data)


static func _int(value: Variant) -> Variant:
	return int(value) if (value is float and is_finite(value) and floorf(value) == value) else value
