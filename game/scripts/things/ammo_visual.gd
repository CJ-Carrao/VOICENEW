class_name AmmoVisual
extends Node3D









const MAG_TAG: = "magazine"

var thing: Thing
var _key: Array = []
var _reserve_id: = ""
var _reserve_template: Node3D = null
var _reserves: Array[Node3D] = []


func setup(owner_thing: Thing) -> void :
	thing = owner_thing
	name = "AmmoVisual"


func _process(_delta: float) -> void :
	if thing == null or thing.model == null or thing.is_dead:
		return
	var override: = String(thing.ammo_override.get("thing", ""))
	var key: = [thing.capacity, thing.ammo, thing.magazine, thing.model.get_instance_id(), thing.is_building, override]
	if key == _key:
		return
	_key = key
	if thing.is_building:
		return
	var pieces: = _magazine_pieces()
	if not pieces.is_empty():
		_scale_magazine(pieces)
		_show_reserves(0, "")
	else:
		var extra: = thing.ammo - thing.magazine
		_show_reserves(extra, override if not override.is_empty() else Cost.default_projectile(thing.node_data, Lexicon.data))


func _magazine_pieces() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for piece: MeshInstance3D in thing.model_pieces:
		if is_instance_valid(piece) and String(piece.get_meta("tag", "")) == MAG_TAG and piece.get_parent() == thing.model:
			out.append(piece)
	return out



func _scale_magazine(pieces: Array[MeshInstance3D]) -> void :
	var cfg: Dictionary = Lexicon.bal("weapons._ammo_visual", {})
	var ratio: = maxf(float(thing.capacity) / float(maxi(thing.magazine, 1)), 0.01)
	var length: = clampf(ratio, float(cfg.get("min_scale", 0.6)), float(cfg.get("max_length", 3.0)))
	var cross: = clampf(sqrt(ratio / length), 1.0, float(cfg.get("max_scale", 6.0)))
	var grow: = Basis.from_scale(Vector3(cross, length, cross))
	var box: = AABB()
	var first: = true
	for piece in pieces:
		if not piece.has_meta("ammo_rest"):
			piece.set_meta("ammo_rest", piece.transform)
		var rest: Transform3D = piece.get_meta("ammo_rest")
		var piece_box: = rest * piece.mesh.get_aabb()
		box = piece_box if first else box.merge(piece_box)
		first = false
	if pieces.size() == 1:
		_extend_single(pieces[0], length, cross)
		return
	var pivot: = Vector3(box.get_center().x, box.end.y, box.get_center().z)
	for piece in pieces:
		var rest: Transform3D = piece.get_meta("ammo_rest")
		piece.transform = Transform3D(grow * rest.basis, pivot + grow * (rest.origin - pivot))




func _extend_single(piece: MeshInstance3D, length: float, cross: float) -> void :
	var rest: Transform3D = piece.get_meta("ammo_rest")
	var local: = piece.mesh.get_aabb()
	var reference: = _tag_height("grip")
	if reference <= 0.0:
		reference = local.size.y
	var stretch: = length if length < 1.0 else 1.0 + (length - 1.0) * reference / maxf(local.size.y, 0.001)
	var top: = Vector3(local.get_center().x, local.end.y, local.get_center().z)
	var grow: = Transform3D(Basis.from_scale(Vector3(cross, stretch, cross)), Vector3.ZERO)
	piece.transform = rest * Transform3D(Basis.IDENTITY, top) * grow * Transform3D(Basis.IDENTITY, - top)



func _tag_height(tag: String) -> float:
	var box: = AABB()
	var first: = true
	for piece: MeshInstance3D in thing.model_pieces:
		if is_instance_valid(piece) and String(piece.get_meta("tag", "")) == tag and piece.get_parent() == thing.model:
			var piece_box: = piece.transform * piece.mesh.get_aabb()
			box = piece_box if first else box.merge(piece_box)
			first = false
	return 0.0 if first else box.size.y



func _show_reserves(count: int, id: String) -> void :
	var cfg: Dictionary = Lexicon.bal("weapons._ammo_visual", {})
	count = clampi(count, 0, int(cfg.get("reserve_max", 24)))
	if id != _reserve_id or count == 0:
		for node in _reserves:
			node.queue_free()
		_reserves.clear()
		if id != _reserve_id and _reserve_template != null:
			_reserve_template.free()
			_reserve_template = null
		_reserve_id = id
	if count == 0 or id.is_empty() or not Lexicon.data.models.has(id):
		return
	if _reserve_template == null:
		_reserve_template = ModelBuilder.build(id, {}, Lexicon.data)["root"]
	var size: = _template_size()
	var per_row: = maxi(1, ceili(sqrt(float(count))))
	var gap: = float(cfg.get("reserve_gap", 1.15))
	var top: = thing.bounds.end.y
	var center: = thing.bounds.get_center()
	var layers: = thing.model_pieces[0].layers if not thing.model_pieces.is_empty() else 1
	while _reserves.size() < count:
		var copy: = _reserve_template.duplicate() as Node3D
		add_child(copy)
		Hands._set_layers(copy, layers)
		_reserves.append(copy)
	while _reserves.size() > count:
		_reserves.pop_back().queue_free()
	for i in _reserves.size():
		@warning_ignore("integer_division")
		var layer: = i / per_row
		var column: = i % per_row
		var row_size: = mini(per_row, count - layer * per_row)
		var x: = center.x + (column - (row_size - 1) * 0.5) * size.x * gap
		_reserves[i].position = Vector3(x, top + size.y * (0.5 + layer) * gap, center.z)


func _template_size() -> Vector3:
	var box: = AABB()
	var first: = true
	for node in _reserve_template.find_children("*", "MeshInstance3D", true, false):
		var mesh: = node as MeshInstance3D
		var piece_box: = _reserve_template.transform * mesh.transform * mesh.mesh.get_aabb()
		box = piece_box if first else box.merge(piece_box)
		first = false
	return box.size if not first else Vector3.ONE * 0.1


func _exit_tree() -> void :
	if _reserve_template != null:
		_reserve_template.free()
		_reserve_template = null
