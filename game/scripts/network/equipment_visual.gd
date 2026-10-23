class_name EquipmentVisual
extends Node3D



var _geometry: Dictionary = {}
var _target: = Transform3D.IDENTITY


func apply_item(item: Dictionary, layers: int) -> void :
	var geometry: Dictionary = item.get("geometry", {})
	if geometry != _geometry:
		for child in get_children():
			remove_child(child)
			child.queue_free()
		_geometry = geometry.duplicate(true)
		if not geometry.is_empty():
			add_child(_build_model(geometry, layers, 0))
	_target = item.get("pose", Transform3D.IDENTITY)
	if not visible:
		transform = _target
	visible = not item.is_empty()


func _process(delta: float) -> void :
	transform = transform.interpolate_with(_target, 1.0 - exp( - Hands.POSE_SMOOTH * delta))


func _build_model(data: Dictionary, layers: int, depth: int) -> Node3D:
	var holder: = Node3D.new()
	holder.name = "EquipmentModel"
	holder.transform = data.get("at", Transform3D.IDENTITY)
	var built: = ModelBuilder.build(str(data.get("id", "")), data.get("mods", {}), Lexicon.data)
	var model: = built["root"] as Node3D
	model.transform = data.get("model", model.transform)
	holder.add_child(model)
	Hands._set_layers(model, layers)
	if depth < int(Lexicon.balf("caps.graft_depth")):
		var children: Array = data.get("children", [])
		for child: Dictionary in children.slice(0, int(Lexicon.balf("caps.grafts_per_recipe"))):
			holder.add_child(_build_model(child, layers, depth + 1))
	return holder
