extends Node3D

var user_ref: WeakRef
var mode := ""
var closing := false
var age := 0.0
var ring: Node3D
var slashes: Node3D
var light: OmniLight3D
var start_clock := 0.0
var barrier_shape: CollisionShape3D
var shell_shader: ShaderMaterial
var clash_seam: MultiMeshInstance3D

func setup(user: Node) -> void:
	user_ref = weakref(user)
	mode = user.domain_mode
	start_clock = user.domain_until - 6.0
	name = "DomainEnvironment_" + mode
	top_level = true
	global_position = user.domain_origin
	basis = Gravity.frame_for(user.domain_up)
	_build()
	scale = Vector3.ONE * .02
	add_to_group("domain_environments")

func _material(hex: String, glow: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.roughness = .88
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = glow
	return mat

func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material, turn: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var bit := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	bit.mesh = mesh
	bit.material_override = mat
	bit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(bit)
	bit.position = at
	bit.rotation = turn
	return bit

func _build() -> void:
	var color := "dd635e" if mode == "shrine" else "819fdc"
	var energy := _material(color, 1.7)
	var query := PhysicsRayQueryParameters3D.create(global_position + basis.y * .15, global_position - basis.y * 20.0, PhysicsLayers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var floor_y := -1.0
	if not hit.is_empty(): floor_y = (hit.position - global_position).dot(basis.y) + .045
	floor_y = clampf(floor_y, -8.0, -.1)
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 8.8
	floor_mesh.bottom_radius = 8.8
	floor_mesh.height = .035
	floor_mesh.radial_segments = 64
	var floor_bit := MeshInstance3D.new()
	floor_bit.name = "DomainFloor"
	floor_bit.mesh = floor_mesh
	floor_bit.material_override = _material("25202a" if mode == "shrine" else "101a2e", .2)
	add_child(floor_bit)
	floor_bit.position.y = floor_y
	ring = Node3D.new()
	ring.name = "DomainBoundary"
	add_child(ring)
	for i in 48:
		var a := TAU * i / 48.0
		_box(ring, Vector3(.08, .07, 1.13), Vector3(cos(a) * 8.9, floor_y + .06, sin(a) * 8.9), energy, Vector3(0, -a, 0))
	var sphere := SphereMesh.new()
	sphere.radius = 9.0
	sphere.height = 18.0
	sphere.radial_segments = 48
	sphere.rings = 24
	var shell := MeshInstance3D.new()
	shell.name = "ClosedVoidBarrier" if mode == "void" else "ClosedShrineBarrier"
	shell.mesh = sphere
	var shader := ShaderMaterial.new()
	shell_shader = shader
	shader.shader = load("res://shaders/domain_void.gdshader")
	shader.set_shader_parameter("shrine_interior", mode == "shrine")
	shell.material_override = shader
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shell)
	var barrier := StaticBody3D.new()
	barrier.name = "VoidBarrierBody" if mode == "void" else "ShrineBarrierBody"
	barrier.collision_layer = PhysicsLayers.WORLD
	barrier.collision_mask = 0
	barrier_shape = CollisionShape3D.new()
	barrier_shape.shape = sphere.create_trimesh_shape()
	barrier_shape.shape.backface_collision = true
	barrier_shape.disabled = true
	barrier.add_child(barrier_shape)
	add_child(barrier)
	if mode == "void":
		var stars := MultiMeshInstance3D.new()
		stars.name = "InformationStreams"
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = BoxMesh.new()
		instances.instance_count = 96
		for i in 96:
			var a := i * 2.399963
			var y := -0.7 + 1.4 * float(i % 17) / 16.0
			var point := Vector3(cos(a), y, sin(a)).normalized() * 8.25
			instances.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(.045, .045, .15 + (i % 4) * .08)), point))
		stars.multimesh = instances
		stars.material_override = energy
		add_child(stars)
	else: _shrine(floor_y)
	slashes = Node3D.new()
	slashes.name = "SureHitStreaks"
	add_child(slashes)
	for i in 12:
		var a := TAU * i / 12.0
		var at := Vector3(cos(a) * 5.5, .3 + (i % 3) * .9, sin(a) * 5.5)
		_box(slashes, Vector3(.035, .035, 2.2 if mode == "shrine" else .7), at, energy, Vector3(.6, a, .4))
	light = OmniLight3D.new()
	light.light_color = Color(color)
	light.light_energy = 1.8
	light.omni_range = 12.0
	light.position.y = 3.0
	add_child(light)
	clash_seam = MultiMeshInstance3D.new()
	clash_seam.name = "DomainClashSeam"
	var seam := MultiMesh.new()
	seam.transform_format = MultiMesh.TRANSFORM_3D
	seam.use_colors = true
	seam.mesh = BoxMesh.new()
	seam.instance_count = 64
	for i in 64:
		var angle := i * TAU / 64.0
		var point := Vector3(cos(angle), sin(angle), sin(i * 1.7) * .025) * 7.8
		seam.set_instance_transform(i, Transform3D(Basis(Vector3.FORWARD, angle).scaled(Vector3(.09, .5, .10)), point))
		seam.set_instance_color(i, Color("8db7ff") if i % 2 == 0 else Color("f6a18b"))
	clash_seam.multimesh = seam
	var seam_mat := StandardMaterial3D.new()
	seam_mat.vertex_color_use_as_albedo = true
	seam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	clash_seam.material_override = seam_mat
	add_child(clash_seam)
	clash_seam.hide()

func _shrine(floor_y: float) -> void:
	var altar := Node3D.new()
	altar.name = "MalevolentShrineAltar"
	add_child(altar)
	altar.position = Vector3(0, floor_y, -4.7)
	var wood := _material("51413c")
	var roof := _material("363b3c")
	var bone := _material("d2c9ac")
	var red := _material("913d3b", .25)
	var black := _material("17181c")
	_box(altar, Vector3(5.3, .35, 3.6), Vector3(0, .18, 0), wood)
	_box(altar, Vector3(4.5, .3, 3.1), Vector3(0, .5, 0), red)
	for x in [-1.8, 1.8]:
		for z in [-1.15, 1.15]:
			_box(altar, Vector3(.34, 3.2, .34), Vector3(x, 2.1, z), bone)
			_box(altar, Vector3(.58, .23, .58), Vector3(x, 3.48, z), red)
	_box(altar, Vector3(3.3, 2.3, .3), Vector3(0, 1.9, -.8), black)
	_box(altar, Vector3(4.5, .36, 3.5), Vector3(0, 3.62, 0), roof)
	_box(altar, Vector3(3.7, .38, 2.7), Vector3(0, 3.94, 0), roof)
	_box(altar, Vector3(2.9, .34, 2.0), Vector3(0, 4.26, 0), roof)
	for side in [-1, 1]:
		_box(altar, Vector3(1.1, .23, 3.7), Vector3(side*2.35, 3.85, 0), roof, Vector3(0, 0, side*.28))
		_box(altar, Vector3(.24, 1.2, .3), Vector3(side*2.56, 4.45, .1), bone, Vector3(0, 0, -side*.35))
		_box(altar, Vector3(.50, .75, .42), Vector3(side*1.44, 3.28, 1.23), bone)
		for eye in [-1,1]: _box(altar, Vector3(.12, .15, .08), Vector3(side*1.44+eye*.13, 3.34, 1.48), black)
		_box(altar, Vector3(.34, .22, .07), Vector3(side*1.44, 3.04, 1.48), black)
	for i in 9:
		var x := -1.2 + i*.3
		_box(altar, Vector3(.17, .46, .23), Vector3(x, 3.05, 1.16), bone, Vector3(0, 0, x*.14))
		_box(altar, Vector3(.17, .32, .23), Vector3(x, .89, 1.16), bone, Vector3(0, 0, -x*.14))

func close() -> void:
	if closing: return
	closing = true
	if is_instance_valid(barrier_shape): barrier_shape.set_deferred("disabled", true)
	if not is_inside_tree() or is_queued_for_deletion(): return
	var fade := create_tween()
	fade.tween_property(self, "scale", Vector3.ONE * .001, .35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fade.tween_callback(queue_free)

func _process(delta: float) -> void:
	if closing: return
	var user = user_ref.get_ref() if user_ref != null else null
	if not is_instance_valid(user) or not is_instance_valid(user.thing) or user.thing.is_dead or user.thing.is_captured or not user.thing.is_active or user.domain_until <= user.clock:
		if is_instance_valid(user) and is_instance_valid(user.thing) and user.thing.is_captured and not user.thing.network_replica: user.cancel_domain()
		close()
		return
	age = maxf(age + delta, user.clock - start_clock)
	var opening := clampf(age / .65, .02, 1.0)
	scale = Vector3.ONE * (1.0 - pow(1.0 - opening, 3.0))
	if is_instance_valid(barrier_shape) and barrier_shape.disabled and opening >= 1.0: barrier_shape.set_deferred("disabled", false)
	slashes.rotation.y += delta * (.45 if mode == "void" else 1.1)
	for i in slashes.get_child_count():
		var bit := slashes.get_child(i) as Node3D
		bit.visible = fmod(age * 2.5 + i * .31, 1.0) < .28
	light.light_energy = 1.1 if user.domain_clashing else 1.8 + sin(age * 2.0) * .15
	shell_shader.set_shader_parameter("clash_amount", 1.0 if user.domain_clashing else 0.0)
	shell_shader.set_shader_parameter("clash_point", user.clash_point)
	shell_shader.set_shader_parameter("clash_axis", user.clash_axis)
	shell_shader.set_shader_parameter("clash_pressure", user.clash_pressure)
	clash_seam.visible = user.domain_clashing
	if user.domain_clashing:
		clash_seam.global_position = user.clash_point + user.clash_axis * user.clash_pressure * 2.0
		var up: Vector3 = user.domain_up
		if absf(up.dot(user.clash_axis)) > .95: up = Vector3.RIGHT
		clash_seam.global_basis = Basis.looking_at(user.clash_axis, up) * Basis(Vector3.FORWARD, sin(age * 8.0) * .025)
