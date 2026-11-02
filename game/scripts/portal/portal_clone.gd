class_name PortalClone
extends Node3D







var body: Node3D
var portal: Portal

var _pieces: Array = []


func setup(source: Node3D, through: Portal) -> void :
	body = source
	portal = through
	name = "Clone_%s" % source.name
	top_level = true
	for node in source.find_children("*", "MeshInstance3D", true, false):
		var original: = node as MeshInstance3D
		if original.mesh == null:
			continue
		var copy: = MeshInstance3D.new()
		copy.mesh = original.mesh
		copy.skin = original.skin
		copy.material_override = original.material_override
		copy.material_overlay = original.material_overlay
		for i in original.get_surface_override_material_count():
			copy.set_surface_override_material(i, original.get_surface_override_material(i))
		copy.layers = original.layers
		copy.cast_shadow = original.cast_shadow
		add_child(copy)
		_pieces.append([original, copy])

	for pair: Array in _pieces:
		var original: = pair[0] as MeshInstance3D
		if original.skin != null and not original.skeleton.is_empty():
			var skeleton: = original.get_node_or_null(original.skeleton)
			if skeleton != null:
				(pair[1] as MeshInstance3D).skeleton = (pair[1] as MeshInstance3D).get_path_to(skeleton)



func follow() -> void :
	if not is_instance_valid(body) or not is_instance_valid(portal) or not portal.is_linked():
		return
	var through: = portal.transfer()
	for pair: Array in _pieces:
		var copy: = pair[1] as MeshInstance3D


		if not is_instance_valid(pair[0]):
			copy.visible = false
			continue
		var original: = pair[0] as MeshInstance3D
		copy.visible = original.is_visible_in_tree()
		if copy.visible:
			copy.global_transform = through * original.global_transform
			copy.layers = original.layers
