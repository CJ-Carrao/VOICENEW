class_name Fx
extends RefCounted




const EXPLOSION_TIME: = 0.4
const NUMBER_TIME: = 0.8
const FLASH_TIME: = 0.06
const SLASH_TIME: = 0.16
const SLASH_SEGMENTS: = 14
const SLASH_ALPHA: = 0.6
const SLASH_TILT_DEG: = -30.0
const DEBRIS_AMOUNT: = 8
const DEBRIS_TIME: = 0.7
const EXTRACT_FX_TIME: = 0.08

const EXTRACT_BIT_SIZE: = 0.07
const EXTRACT_BIT_TIME: = 0.28
const EXTRACT_BIT_GLOW: = 1.6



static func explosion(parent: Node, center: Vector3, radius: float, color: Color) -> void :
	if Session.is_online():
		Session.creations.notify_fx("explosion", [center, radius, color])
	var root: = Node3D.new()
	root.name = "ExplosionFx"
	parent.add_child(root)
	root.global_position = center

	SoundBank.play_at(parent, "impacts/explosion", center, Lexicon.balf("feel.sound.explosion_db") + clampf(radius - 3.0, -6.0, 6.0), 
		FeelSounds.fallback("impacts/explosion"), clampf(1.25 - radius * 0.06, 0.7, 1.3))

	var ball: = MeshInstance3D.new()
	var sphere: = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	ball.mesh = sphere
	var material: = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ball.material_override = material
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball.scale = Vector3.ONE * radius * 0.2
	root.add_child(ball)

	var light: = OmniLight3D.new()
	light.light_color = color
	light.light_energy = 6.0
	light.omni_range = radius * 3.0
	light.set_meta(VideoSettings.FX_LIGHT, true)
	root.add_child(light)

	var tween: = root.create_tween().set_parallel(true)
	tween.tween_property(ball, "scale", Vector3.ONE * radius, EXPLOSION_TIME).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, EXPLOSION_TIME).set_ease(Tween.EASE_IN)
	tween.tween_property(light, "light_energy", 0.0, EXPLOSION_TIME)
	tween.chain().tween_callback(root.queue_free)



static func damage_number(parent: Node, at: Vector3, amount: float) -> void :
	if Session.is_online():
		Session.creations.notify_fx("number", [at, amount])
	var label: = Label3D.new()
	label.text = str(roundi(amount))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 48
	label.outline_size = 10
	label.modulate = Color(1.0, 0.85, 0.3)
	label.pixel_size = 0.006
	parent.add_child(label)
	label.global_position = at + Vector3(randf_range(-0.2, 0.2), 0.0, randf_range(-0.2, 0.2))
	var tween: = label.create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y", at.y + 0.9, NUMBER_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, NUMBER_TIME).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)



static func muzzle_flash(parent: Node, at: Vector3, direction: Vector3, size: float, with_light: bool = true) -> void :
	if Session.is_online():
		Session.creations.notify_fx("muzzle", [at, direction, size, with_light])
	if parent == null or size <= 0.0:
		return
	if with_light:

		var id: String = FeelSounds.FIRE_IDS[0 if size < Lexicon.balf("feel.sound.fire_medium_from") else (1 if size < Lexicon.balf("feel.sound.fire_heavy_from") else 2)]
		SoundBank.play_at(parent, id, at, Lexicon.balf("feel.sound.fire_db"), FeelSounds.fallback(id))
	else:
		SoundBank.play_at(parent, "weapons/parry", at, Lexicon.balf("feel.sound.fire_db"), FeelSounds.metal_hit(), 1.4)
	var flash: = MeshInstance3D.new()
	flash.name = "MuzzleFlash"
	var sphere: = SphereMesh.new()
	sphere.radius = size
	sphere.height = size * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	flash.mesh = sphere
	var material: = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.85, 0.45, 0.95)
	flash.material_override = material
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(flash)
	flash.global_position = at + direction.normalized() * size
	flash.scale = Vector3(1.0, 1.0, 1.8)
	if direction.length_squared() > 0.0001 and absf(direction.normalized().dot(Vector3.UP)) < 0.99:
		flash.look_at(flash.global_position + direction, Vector3.UP)
	var tween: = flash.create_tween().set_parallel(true)
	tween.tween_property(material, "albedo_color:a", 0.0, FLASH_TIME)
	if with_light:
		var light: = OmniLight3D.new()
		light.light_color = Color(1.0, 0.8, 0.45)
		light.light_energy = 2.5
		light.omni_range = size * 25.0
		light.set_meta(VideoSettings.FX_LIGHT, true)
		flash.add_child(light)
		tween.tween_property(light, "light_energy", 0.0, FLASH_TIME)
	tween.chain().tween_callback(flash.queue_free)




static func slash(parent: Node, origin: Vector3, direction: Vector3, reach: float, arc_deg: float, style: String, 
		color: Color, from_hand: bool) -> void :
	if Session.is_online():
		Session.creations.notify_fx("slash", [origin, direction, reach, arc_deg, style, color, from_hand])
	if parent == null or reach <= 0.0 or direction.length_squared() < 0.0001:
		return
	SoundBank.play_at(parent, "weapons/swing", origin, Lexicon.balf("feel.sound.swing_db"), FeelSounds.fallback("weapons/swing"), 
		clampf(1.3 - reach * 0.25, 0.75, 1.3))
	var half: = deg_to_rad(clampf(arc_deg, 6.0, 180.0) * 0.5)
	var inner: = reach * (0.25 if style in ["thrust", "saw"] else 0.55)
	var verts: = PackedVector3Array()
	var colors: = PackedColorArray()
	for i in SLASH_SEGMENTS + 1:
		var t: = float(i) / SLASH_SEGMENTS
		var angle: = lerpf( - half, half, t)
		var ray: = Vector3(sin(angle), 0.0, - cos(angle))

		var alpha: = SLASH_ALPHA * (0.25 + 0.75 * t)
		verts.append(ray * inner)
		verts.append(ray * reach)
		colors.append(Color(color, 0.0))
		colors.append(Color(color, alpha))
	var arrays: = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh: = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)
	var trail: = MeshInstance3D.new()
	trail.name = "SlashFx"
	trail.mesh = mesh
	var material: = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	trail.material_override = material
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(trail)
	trail.global_position = origin + (Vector3.DOWN * 0.15 if from_hand else Vector3.ZERO)
	var up: = Vector3.UP if absf(direction.normalized().dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	trail.look_at(trail.global_position + direction, up)
	if style == "overhead":
		trail.rotate_object_local(Vector3.FORWARD, PI * 0.5)
	elif style == "slash":

		trail.rotate_object_local(Vector3.FORWARD, deg_to_rad(SLASH_TILT_DEG))
	var tween: = trail.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, SLASH_TIME).set_ease(Tween.EASE_IN)
	tween.tween_callback(trail.queue_free)




static func falling_blocks(parent: Node, centers: PackedVector3Array, size: float, color: Color, down: Vector3) -> void :
	if parent == null or not parent.is_inside_tree() or centers.is_empty():
		return
	var node: = MultiMeshInstance3D.new()
	node.name = "FallingBlocks"
	var multimesh: = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var cube: = BoxMesh.new()
	cube.size = Vector3.ONE * size
	var material: = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	cube.material = material
	multimesh.mesh = cube
	multimesh.instance_count = centers.size()
	node.multimesh = multimesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	var middle: = Vector3.ZERO
	for c in centers:
		middle += c
	middle /= centers.size()
	var seeds: = PackedFloat32Array()
	for i in centers.size():
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, centers[i]))
		seeds.append(fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0))
	SoundBank.play_at(parent, "impacts/break", middle, Lexicon.balf("feel.sound.break_db"), FeelSounds.fallback("impacts/break"), 0.8)
	var g: = down.normalized() * 14.0
	var tween: = node.create_tween()
	tween.tween_method( func(t: float) -> void :
		for i in centers.size():
			var spread: = (centers[i] - middle) * 0.15 * t
			var at: = centers[i] + spread + g * 0.5 * t * t
			var spin: = Basis(Vector3(seeds[i], 1.0, 1.0 - seeds[i]).normalized(), t * (2.0 + seeds[i] * 4.0))
			var shrink: = clampf(1.0 - maxf(t - 0.45, 0.0) / 0.3, 0.05, 1.0)
			multimesh.set_instance_transform(i, Transform3D(spin.scaled(Vector3.ONE * shrink), at)), 
		0.0, 0.75, 0.75)
	tween.tween_callback(node.queue_free)



static func block_flight(parent: Node, from: Vector3, to_node: Node3D, size: float, color: Color) -> void :
	if parent == null or not parent.is_inside_tree() or to_node == null:
		return
	var cube: = MeshInstance3D.new()
	cube.name = "ExtractedBlock"
	var box: = BoxMesh.new()
	box.size = Vector3.ONE * size
	var material: = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.4
	box.material = material
	cube.mesh = box
	cube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(cube)
	cube.global_position = from
	var tween: = cube.create_tween()
	tween.tween_method( func(t: float) -> void :
		if not is_instance_valid(to_node):
			return
		var e: = t * t
		cube.global_position = from.lerp(to_node.global_position, e)
		cube.scale = Vector3.ONE * lerpf(1.0, 0.25, e)
		cube.rotation = Vector3(t * 6.0, t * 4.0, 0.0), 
		0.0, 1.0, 0.32)
	tween.tween_callback(cube.queue_free)



static func debris(parent: Node, at: Vector3, size: Vector3, color: Color) -> void :
	if parent == null:
		return
	var burst: = CPUParticles3D.new()
	burst.name = "DebrisFx"
	burst.one_shot = true
	burst.emitting = false
	burst.amount = DEBRIS_AMOUNT
	burst.lifetime = DEBRIS_TIME
	burst.explosiveness = 1.0
	burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	burst.emission_box_extents = size * 0.5
	burst.direction = Vector3.UP
	burst.spread = 70.0
	burst.initial_velocity_min = 1.5
	burst.initial_velocity_max = 4.0
	burst.gravity = Vector3(0, -12.0, 0)
	var chip: = BoxMesh.new()
	var side: = clampf(minf(size.x, minf(size.y, size.z)) * 0.5, 0.05, 0.25)
	chip.size = Vector3.ONE * side
	var surface: = StandardMaterial3D.new()
	surface.albedo_color = color
	chip.material = surface
	burst.mesh = chip
	parent.add_child(burst)
	burst.global_position = at
	burst.emitting = true
	SoundBank.play_at(parent, "impacts/break", at, Lexicon.balf("feel.sound.break_db"), FeelSounds.fallback("impacts/break"))
	burst.finished.connect(burst.queue_free)



static func extraction_beam(parent: Node, from: Vector3, to: Vector3, color: Color) -> void :
	if parent == null:
		return
	var trail: = MeshInstance3D.new()
	trail.name = "ExtractFx"
	var mesh: = ImmediateMesh.new()
	var surface: = StandardMaterial3D.new()
	surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	surface.vertex_color_use_as_albedo = true
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, surface)
	var steps: = 10
	for i in steps:

		var t0: = float(i) / steps
		var t1: = t0 + 0.5 / steps
		var wobble: = Vector3(sin(i * 2.3), cos(i * 1.7), sin(i * 3.1)) * 0.04
		mesh.surface_set_color(Color(color, 0.25 + 0.6 * t0))
		mesh.surface_add_vertex(from.lerp(to, t0) + wobble)
		mesh.surface_set_color(Color(color, 0.25 + 0.6 * t1))
		mesh.surface_add_vertex(from.lerp(to, t1) + wobble)
	mesh.surface_end()
	trail.mesh = mesh
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(trail)
	var tween: = trail.create_tween()
	tween.tween_interval(EXTRACT_FX_TIME)
	tween.tween_callback(trail.queue_free)

	var bit: = MeshInstance3D.new()
	bit.name = "ExtractBit"
	var cube: = BoxMesh.new()
	cube.size = Vector3.ONE * EXTRACT_BIT_SIZE
	var glow: = StandardMaterial3D.new()
	glow.albedo_color = color
	glow.emission_enabled = true
	glow.emission = color
	glow.emission_energy_multiplier = EXTRACT_BIT_GLOW
	cube.material = glow
	bit.mesh = cube
	bit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(bit)
	bit.global_position = from
	bit.rotation = Vector3(from.x * 3.1, from.y * 2.3, from.z * 1.7)
	var flight: = bit.create_tween().set_parallel()
	flight.tween_property(bit, "global_position", to, EXTRACT_BIT_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	flight.tween_property(bit, "scale", Vector3.ONE * 0.3, EXTRACT_BIT_TIME)
	flight.chain().tween_callback(bit.queue_free)



static func ring(parent: Node, center: Vector3, radius: float, color: Color, inward: bool, replicate: bool = true) -> void :
	if replicate and Session.is_online():
		Session.creations.notify_fx("ring", [center, radius, color, inward])
	if parent == null or radius <= 0.0:
		return
	var ring_mesh: = MeshInstance3D.new()
	ring_mesh.name = "RingFx"
	var torus: = TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 32
	ring_mesh.mesh = torus
	var material: = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color, 0.8)
	ring_mesh.material_override = material
	ring_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring_mesh)
	ring_mesh.global_position = center
	var small: = Vector3(radius * 0.1, 1.0, radius * 0.1)
	var big: = Vector3(radius, 1.0, radius)
	ring_mesh.scale = big if inward else small
	var tween: = ring_mesh.create_tween().set_parallel(true)
	tween.tween_property(ring_mesh, "scale", small if inward else big, EXPLOSION_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, EXPLOSION_TIME).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(ring_mesh.queue_free)
