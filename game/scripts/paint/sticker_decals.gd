class_name StickerDecals
extends RefCounted




const META: = "lavoice_sticker_decal"




static func rebuild(paint: RobotPaint, holder_for_part: Callable, holders: Array) -> void :
	for holder: Variant in holders:
		if not is_instance_valid(holder):
			continue
		for child in (holder as Node).get_children():
			if child.has_meta(META):
				(holder as Node).remove_child(child)
				child.queue_free()
	if paint == null:
		return
	for sticker in paint.stickers:
		for frame in frames(sticker):
			_add(frame, holder_for_part)




static func frames(sticker: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var texture: = StickerCatalog.texture(String(sticker["id"]))
	if texture == null:
		return out
	var size: = float(sticker["s"]) / 1000.0
	var longest: = float(maxi(texture.get_width(), texture.get_height()))
	var half: = Vector2(size * texture.get_width() / longest, size * texture.get_height() / longest) * 0.5
	var depth: = minf(float(RobotPaint.config().get("sticker_depth_m", 0.05)), size)
	var center: = RobotPaint.vec(sticker["c"])
	var normal: = RobotPaint.vec(sticker["n"]).normalized()
	var up: = RobotPaint.vec(sticker["u"]).normalized()
	out.append(_frame(texture, center, normal, up, half, depth, false))
	if bool(sticker["mirror"]) and absf(center.x) > 0.0005:
		var flip: = Vector3(-1, 1, 1)
		out.append(_frame(texture, center * flip, normal * flip, up * flip, half, depth, true))
	return out


static func _frame(texture: Texture2D, center: Vector3, normal: Vector3, up: Vector3, half: Vector2, depth: float, mirrored: bool) -> Dictionary:
	up = (up - normal * up.dot(normal)).normalized()
	return {"texture": texture, "center": center, "normal": normal, "up": up, "right": up.cross(normal), "half": half, 
		"depth": depth, "mirrored": mirrored, "part": part_at(center)}



static func hit(paint: RobotPaint, point: Vector3) -> Array:
	for i in range(paint.stickers.size() - 1, -1, -1):
		for frame in frames(paint.stickers[i]):
			var d: Vector3 = point - frame["center"]
			var half: Vector2 = frame["half"]
			if absf(d.dot(frame["normal"])) <= float(frame["depth"]) + 0.02 and absf(d.dot(frame["right"])) <= half.x and absf(d.dot(frame["up"])) <= half.y:
				return [i, bool(frame["mirrored"])]
	return []



static func part_at(point: Vector3) -> String:
	var best: = ""
	var best_volume: = INF
	var meshes: = RobotPaintCanvas.paintable_meshes()
	for part: String in meshes:
		var box: AABB = (meshes[part] as Mesh).get_aabb().grow(0.01)
		if box.has_point(point) and box.get_volume() < best_volume:
			best = part
			best_volume = box.get_volume()
	return best


static func _add(frame: Dictionary, holder_for_part: Callable) -> void :
	if String(frame["part"]).is_empty():
		return
	var holder: Node3D = holder_for_part.call(frame["part"])
	if holder == null:
		return
	var half: Vector2 = frame["half"]
	var decal: = Decal.new()
	decal.set_meta(META, true)
	decal.texture_albedo = frame["texture"]

	decal.transform = Transform3D(Basis(frame["right"], frame["normal"], - (frame["up"] as Vector3)), frame["center"])
	decal.size = Vector3(half.x * 2.0, float(frame["depth"]) * 2.0, half.y * 2.0)
	decal.upper_fade = 0.05
	decal.lower_fade = 0.05
	decal.normal_fade = 0.4
	holder.add_child(decal)
