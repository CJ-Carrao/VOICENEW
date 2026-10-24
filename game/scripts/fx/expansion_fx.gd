class_name ExpansionFx
extends RefCounted

static var burst_count := 0
static var rift_count := 0

# All extra effects use a small, fixed number of cubes, matching the creation style.
static func burst(parent: Node, at: Vector3, radius: float, color: Color, kind: String) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	burst_count += 1
	if Session.is_online() and Session.has_authority():
		Session.creations.notify_fx("voxel_burst", [at, radius, color, kind])
	var root := Node3D.new()
	root.name = "VoxelBurst"
	parent.add_child(root)
	root.global_position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.8
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var count := 36 if kind == "nuclear" else 24
	for i in count:
		var bit := MeshInstance3D.new()
		bit.mesh = cube
		bit.material_override = material
		bit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(bit)
		var angle := TAU * float(i) / float(count)
		var destination := Vector3(cos(angle), sin(float(i) * 2.4) * 0.4, sin(angle)) * radius
		if kind == "nuclear":
			if i < 12:
				destination = Vector3(sin(angle) * radius * 0.1, float(i) / 12.0 * radius, cos(angle) * radius * 0.1)
			else:
				destination = Vector3(cos(angle) * radius * 0.55, radius * (0.85 + float(i % 3) * 0.07), sin(angle) * radius * 0.55)
		var side := clampf(radius * 0.10, 0.05, 1.0)
		if kind in ["blue", "black"]:
			bit.position = destination
			destination = Vector3.ZERO
		bit.scale = Vector3.ONE * side * 0.25
		var tween := root.create_tween().set_parallel(true)
		tween.tween_property(bit, "position", destination, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(bit, "scale", Vector3.ONE * side, 0.4)
		tween.chain().tween_property(bit, "scale", Vector3.ONE * 0.001, 0.6)
	var fade := root.create_tween()
	fade.tween_interval(1.25)
	fade.tween_callback(root.queue_free)


static func rift(parent: Node, at: Vector3, direction: Vector3, length: float, color: Color) -> void:
	rift_count += 1
	if Session.is_online() and Session.has_authority():
		Session.creations.notify_fx("voxel_rift", [at, direction, length, color])
	var root := Node3D.new()
	root.name = "SpaceCut"
	parent.add_child(root)
	root.global_position = at
	root.look_at(at + direction.normalized(), Gravity.up_at(at, Vector3.UP))
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.5
	var mesh := BoxMesh.new()
	for i in 20:
		var shard := MeshInstance3D.new()
		shard.mesh = mesh
		shard.material_override = material
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shard.position = Vector3(sin(float(i) * 1.7) * 0.09, cos(float(i) * 1.1) * 0.11, - float(i + 1) * length / 20.0)
		shard.scale = Vector3(0.045, 0.15 + float(i % 4) * 0.1, length / 24.0)
		root.add_child(shard)
	var tween := root.create_tween()
	tween.tween_interval(0.24)
	tween.tween_property(root, "scale", Vector3(0.001, 0.001, 1.0), 0.32)
	tween.tween_callback(root.queue_free)
