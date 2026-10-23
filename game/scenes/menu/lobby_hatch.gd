class_name LobbyHatch
extends Node3D




const RADIUS: = 0.755
const FLOOR_Y: = -0.105
const LIFT_DEPTH: = 0.6
const ACCENT: = Color("ff791c")

var accent: Color = ACCENT
var lift_offset: float = - LIFT_DEPTH
var _lift: Node3D
var _blades: Array[MeshInstance3D] = []
var _blade_materials: Array[ShaderMaterial] = []
var _platform_light: StandardMaterial3D
var _well_light: StandardMaterial3D


func _ready() -> void :
	var dark: = _metal(Color("11151b"), 0.28, 0.48)

	var shaft: = CylinderMesh.new()
	shaft.top_radius = RADIUS
	shaft.bottom_radius = RADIUS
	shaft.height = 0.11
	shaft.radial_segments = 64


	shaft.cap_top = false
	shaft.cap_bottom = false
	shaft.flip_faces = true
	_mesh("ShaftWall", shaft, dark).position.y = -0.175
	var bottom: = CylinderMesh.new()
	bottom.top_radius = RADIUS - 0.01
	bottom.bottom_radius = bottom.top_radius
	bottom.height = 0.018
	bottom.radial_segments = 48
	_well_light = _metal(Color("2d1c14"), 0.0, 0.7)
	_well_light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh("WellBottom", bottom, _well_light).position.y = -0.228
	_build_iris()
	_lift = Node3D.new()
	_lift.name = "Lift"
	add_child(_lift)
	var platform: = CylinderMesh.new()
	platform.top_radius = 0.655
	platform.bottom_radius = 0.7
	platform.height = 0.145
	platform.radial_segments = 12
	var base: = MeshInstance3D.new()
	base.name = "Platform"
	base.mesh = platform
	var platform_shader: = Shader.new()
	platform_shader.code = "shader_type spatial;\nvarying float floor_height;\nvoid vertex() { floor_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y; }\nvoid fragment() {\n\tif (floor_height < -0.106) { discard; }\n\tALBEDO = vec3(0.035, 0.038, 0.044);\n\tMETALLIC = 0.46;\n\tROUGHNESS = 0.52;\n}\n"









	var platform_material: = ShaderMaterial.new()
	platform_material.shader = platform_shader
	base.material_override = platform_material
	base.position.y = -0.0575
	_lift.add_child(base)
	_platform_light = _metal(accent, 0.0, 0.5)
	_platform_light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var top_ring: = _ring("LiftRing", 0.645, 0.01, 0.016, _platform_light)
	top_ring.reparent(_lift, false)
	for side in [-1.0, 1.0]:
		var strip: = BoxMesh.new()
		strip.size = Vector3(0.17, 0.025, 0.012)
		var lamp: = MeshInstance3D.new()
		lamp.mesh = strip
		lamp.material_override = _platform_light
		lamp.position = Vector3(side * 0.17, -0.069, -0.665)
		_lift.add_child(lamp)
	pose(0.0, false)



func pose(phase: float, ready: bool) -> void :
	if _lift == null:
		return
	var aperture: = smoothstep(0.0, 0.3, phase)
	var rise: = smoothstep(0.28, 0.72, phase)
	lift_offset = - LIFT_DEPTH * (1.0 - rise)
	_lift.position.y = lift_offset
	_lift.visible = rise > 0.82
	for i in _blades.size():
		_blades[i].visible = aperture < 0.997
		_blade_materials[i].set_shader_parameter("aperture", aperture)
	var color: = accent.lightened(0.3) if ready else accent
	_platform_light.albedo_color = color
	_well_light.albedo_color = Color("140e0b").lerp(Color("7c3814"), aperture)


func _build_iris() -> void :
	var shader: = Shader.new()
	shader.code = "shader_type spatial;\nrender_mode cull_disabled;\nuniform float aperture = 0.0;\nuniform vec3 steel_color : source_color = vec3(0.19, 0.20, 0.22);\nvoid vertex() {\n\tfloat radius = length(VERTEX.xz);\n\tfloat angle = atan(VERTEX.z, VERTEX.x) + aperture * 0.80;\n\tfloat r = mix(radius, 0.767, aperture);\n\tVERTEX.xz = vec2(cos(angle), sin(angle)) * r;\n}\nvoid fragment() {\n\tALBEDO = steel_color;\n\tMETALLIC = 0.46;\n\tROUGHNESS = 0.31;\n}\n"















	var blade_mesh: = _blade_mesh()
	for i in 3:
		var material: = ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("steel_color", Color("383c42").lightened(float(i) * 0.025))
		var blade: = _mesh("IrisBlade_%d" % i, blade_mesh, material)
		blade.rotation.y = TAU * float(i) / 3.0
		blade.position.y = FLOOR_Y - 0.004

		blade.custom_aabb = AABB(Vector3(-0.78, -0.04, -0.78), Vector3(1.56, 0.08, 1.56))
		_blades.append(blade)
		_blade_materials.append(material)


func _blade_mesh() -> ArrayMesh:
	var vertices: = PackedVector3Array()
	var normals: = PackedVector3Array()
	var indices: = PackedInt32Array()
	const RINGS: = 8
	const SEGMENTS: = 20
	for radial in RINGS + 1:
		var unit_r: = float(radial) / RINGS
		var radius: = maxf(unit_r * (RADIUS - 0.004), 0.002)
		var gap: = minf(0.16, 0.0018 / radius)
		for step in SEGMENTS + 1:

			var angle: = lerpf(gap, TAU / 3.0 - gap, float(step) / SEGMENTS) + pow(unit_r, 1.25) * 0.68
			vertices.append(Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
			normals.append(Vector3.UP)
	for radial in RINGS:
		for step in SEGMENTS:
			var a: = radial * (SEGMENTS + 1) + step
			var b: = a + SEGMENTS + 1
			indices.append_array(PackedInt32Array([a, b, a + 1, a + 1, b, b + 1]))
	return _arrays(vertices, normals, indices)


func _arrays(vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _metal(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material: = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _mesh(label: String, geometry: Mesh, material: Material) -> MeshInstance3D:
	var instance: = MeshInstance3D.new()
	instance.name = label
	instance.mesh = geometry
	instance.material_override = material
	add_child(instance)
	return instance


func _ring(label: String, radius: float, thickness: float, y: float, material: Material) -> MeshInstance3D:
	var torus: = TorusMesh.new()
	torus.inner_radius = radius - thickness
	torus.outer_radius = radius + thickness
	torus.rings = 48
	torus.ring_segments = 5
	var ring: = _mesh(label, torus, material)
	ring.position.y = y
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ring
