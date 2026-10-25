extends RefCounted

static var active := 0
static var casts := 0
static func released() -> void: active = maxi(0, active - 1)
static func points(origin: Vector3, direction: Vector3, up: Vector3, reach: float) -> PackedVector3Array:
	var forward := direction.normalized()
	var side := forward.cross(up).normalized()
	if side.length_squared() < .01: side = forward.cross(Vector3.RIGHT if absf(forward.x) < .9 else Vector3.UP).normalized()
	var vertical := side.cross(forward).normalized()
	var result := PackedVector3Array()
	for i in 9:
		var t := i / 8.0
		result.append(origin + forward * reach * (.55 + sin(t * PI) * .2) + side * (t - .5) * reach * .95 + vertical * (.5 - t) * reach * .6)
	return result
static func play(parent: Node, origin: Vector3, direction: Vector3, up: Vector3, reach: float) -> void:
	if not is_instance_valid(parent) or active >= 24: return
	active += 1
	casts += 1
	if Session.is_online() and Session.has_authority(): Session.creations.notify_fx("space_sword", [origin, direction, up, reach])
	var effect := Node3D.new()
	effect.name = "SwordSpaceTear"
	effect.tree_exited.connect(released)
	parent.add_child(effect)
	var curve := points(origin, direction, up, reach)
	var mesh := BoxMesh.new()
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("080b16")
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var rim := StandardMaterial3D.new()
	rim.albedo_color = Color("c7c3ef")
	rim.emission_enabled = true
	rim.emission = Color("948ee1")
	rim.emission_energy_multiplier = 2.0
	for i in 8:
		var delta := curve[i+1] - curve[i]
		var frame := Basis.looking_at(delta.normalized(), direction.normalized())
		for edge in [-1, 0, 1]:
			var piece := MeshInstance3D.new()
			piece.mesh = mesh
			piece.material_override = dark if edge == 0 else rim
			piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			effect.add_child(piece)
			piece.global_position = (curve[i+1] + curve[i]) * .5 + frame.x * edge * .10
			piece.global_basis = frame
			piece.scale = Vector3(.18 if edge == 0 else .025, .025, delta.length() * 1.08)
	# Children use world coordinates, so fade their width rather than dragging the tear to world origin.
	for piece in effect.get_children():
		var fade := effect.create_tween()
		fade.tween_interval(.25)
		fade.tween_property(piece, "scale", Vector3(.001, .001, piece.scale.z), .3)
	var life := effect.create_tween()
	life.tween_interval(.6)
	life.tween_callback(effect.queue_free)
