extends MeshInstance3D


const WATER_SHADER: = "\nshader_type spatial;\nrender_mode unshaded, cull_disabled;\nuniform float island_half_size = 80.0;\nvarying vec2 world_xz;\nvoid vertex() {\n\tworld_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;\n}\nvoid fragment() {\n\tfloat long_wave = sin(world_xz.x * 0.065 + TIME * 0.28);\n\tfloat cross_wave = sin(world_xz.y * 0.12 - world_xz.x * 0.025 + TIME * 0.19);\n\tfloat coast_distance = length(max(abs(world_xz) - vec2(island_half_size), vec2(0.0)));\n\tfloat shallow = 1.0 - smoothstep(8.0, 85.0, coast_distance);\n\tvec3 deep_blue = vec3(0.015, 0.17, 0.37);\n\tvec3 island_blue = vec3(0.04, 0.32, 0.52);\n\tvec3 water = mix(deep_blue, island_blue, shallow);\n\twater += vec3(0.01, 0.025, 0.04) * (0.5 + 0.5 * long_wave * cross_wave);\n\tfloat shore_foam = (1.0 - smoothstep(1.0, 7.0, coast_distance)) * (0.5 + 0.5 * long_wave);\n\tALBEDO = mix(water, vec3(0.22, 0.58, 0.66), shore_foam * 0.2);\n}\n"





















var island_half_size: = 80.0


func _ready() -> void :
	name = "CityOcean"
	var shader: = Shader.new()
	shader.code = WATER_SHADER
	var material: = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("island_half_size", island_half_size)

	var outer: = 900.0
	var half: = island_half_size
	var vertices: = PackedVector3Array()
	var indices: = PackedInt32Array()
	_add_quad(vertices, indices, - outer, outer, - outer, - half)
	_add_quad(vertices, indices, - outer, outer, half, outer)
	_add_quad(vertices, indices, - outer, - half, - half, half)
	_add_quad(vertices, indices, half, outer, - half, half)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var water_mesh: = ArrayMesh.new()
	water_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	water_mesh.surface_set_material(0, material)
	mesh = water_mesh
	position.y = -0.75
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _add_quad(vertices: PackedVector3Array, indices: PackedInt32Array, 
		x0: float, x1: float, z0: float, z1: float) -> void :
	var first: = vertices.size()
	vertices.append_array(PackedVector3Array([
		Vector3(x0, 0.0, z0), Vector3(x1, 0.0, z0), 
		Vector3(x0, 0.0, z1), Vector3(x1, 0.0, z1), 
	]))
	indices.append_array(PackedInt32Array([
		first, first + 2, first + 1, 
		first + 1, first + 2, first + 3, 
	]))
