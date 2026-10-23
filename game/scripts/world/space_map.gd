class_name SpaceMap
extends Node3D






const CONFIG: = "res://data/world/space.json"


const SUN_SHADER: = preload("res://scripts/world/sun_blocks.gdshader")
const SKY_SHADER: = "\nshader_type sky;\nuniform vec3 deep : source_color = vec3(0.012, 0.014, 0.03);\nuniform vec3 haze : source_color = vec3(0.05, 0.035, 0.09);\nfloat hash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }\nvoid sky() {\n\tvec3 d = EYEDIR;\n\tvec3 cell = floor(d * 220.0);\n\tfloat h = hash(cell);\n\tvec3 local = fract(d * 220.0) - 0.5;\n\tfloat star = step(0.985, h) * smoothstep(0.32, 0.0, length(local)) * (0.4 + 0.6 * hash(cell + 7.0));\n\tvec3 big_cell = floor(d * 60.0);\n\tfloat big = step(0.996, hash(big_cell)) * smoothstep(0.25, 0.0, length(fract(d * 60.0) - 0.5));\n\tfloat band = exp(-abs(d.y + 0.25 * d.x) * 6.0);\n\tCOLOR = mix(deep, haze, band * 0.6) + vec3(star * 0.9 + big * 1.6) * vec3(0.95, 0.97, 1.0);\n}\n"

















var config: Dictionary = {}

var planets: Array[BlockPlanet] = []
var spawns: Array[Transform3D] = []
var box_half: float = 64.0

var wall_meshes: Array[MeshInstance3D] = []

var sun_material: ShaderMaterial
var _wall_material: ShaderMaterial
var _wall_fade: float = 1.0
var _contact_strength: Dictionary = {}
var _contact_point: Dictionary = {}



var building: = false


func build(async: bool = false) -> void :
	name = "SpaceMap"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	config = parsed if parsed is Dictionary else {}
	box_half = float(config.get("box_half", 64.0))
	Gravity.clear()
	Gravity.add({"kind": "box_inside", "center": Vector3.ZERO, "half": Vector3.ONE * box_half, 
		"reach": float(config.get("wall_reach", 12.0))})
	var sun: Dictionary = config.get("sun", {})
	Gravity.add({"kind": "box_outside", "center": Vector3.ZERO, "half": Vector3.ONE * float(sun.get("half", 5.0)), 
		"round": float(sun.get("round", 1.5)), "reach": float(sun.get("reach", 9.0))})
	for planet: Dictionary in config.get("planets", []):
		Gravity.add({"kind": "planet", "center": _v(planet.center), "radius": float(planet.radius), 
			"reach": float(planet.reach)})
	_build_environment()
	_build_walls()
	_build_sun(float(sun.get("half", 5.0)), float(sun.get("round", 1.5)))
	_build_spawns()
	if not async:
		for planet: Dictionary in config.get("planets", []):
			_build_planet(planet)
		return
	_build_planets_async()



func _build_planets_async() -> void :
	building = true
	for planet: Dictionary in config.get("planets", []):
		await get_tree().process_frame
		if not is_inside_tree():
			return
		_build_planet(planet, true)
	building = false



func is_ready() -> bool:
	if building:
		return false
	for planet: BlockPlanet in planets:
		if not planet.is_settled():
			return false
	return true


func build_progress() -> float:
	var total: int = (config.get("planets", []) as Array).size()
	if total == 0:
		return 1.0
	var done: = 0.0
	for planet: BlockPlanet in planets:
		done += planet.build_progress()
	return done / float(total)


func _exit_tree() -> void :
	Gravity.clear()


func _build_environment() -> void :
	var env: = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky: = Sky.new()
	var material: = ShaderMaterial.new()
	var shader: = Shader.new()
	shader.code = SKY_SHADER
	material.shader = shader
	sky.sky_material = material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8a93b8")
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.15
	var world: = WorldEnvironment.new()
	world.name = "SpaceEnvironment"
	world.environment = env
	add_child(world)



func _build_walls() -> void :
	var body: = StaticBody3D.new()
	body.name = "Walls"
	body.collision_layer = PhysicsLayers.WORLD
	add_child(body)
	var material: = ShaderMaterial.new()
	var shader: = Shader.new()
	shader.code = "\nshader_type spatial;\nrender_mode cull_disabled, blend_mix, depth_draw_opaque, shadows_disabled;\nuniform vec3 base : source_color = vec3(0.05, 0.06, 0.1);\nuniform vec3 line : source_color = vec3(0.3, 0.5, 1.0);\nuniform float fade = 1.0;\n// Onde alguém pisa na parede (xyz) e quanto ela está acesa ali (w, 0..1).\nuniform vec4 contacts[4];\nuniform float reveal_m = 7.0;\nvarying vec3 world_pos;\nvarying vec3 world_normal;\nvoid vertex() {\n\tworld_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;\n\tworld_normal = abs((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);\n}\nvoid fragment() {\n\t// A parede é invisível (o espaço parece não ter fim); só se revela em volta de quem pisa nela, crescendo ao\n\t// encostar e sumindo devagar ao sair.\n\tfloat shown = 0.0;\n\tfor (int i = 0; i < 4; i++) {\n\t\tfloat w = contacts[i].w;\n\t\tfloat d = distance(world_pos, contacts[i].xyz);\n\t\tshown = max(shown, w * (1.0 - smoothstep(reveal_m * w * 0.45, reveal_m * w, d)));\n\t}\n\tshown *= fade;\n\tif (shown < 0.003) { discard; }\n\t// Grade de 8 m só nos dois eixos do plano da parede (o da normal fica de fora).\n\tvec3 dist = 0.5 - abs(fract(world_pos / 8.0) - 0.5);\n\tdist += step(0.5, world_normal) * 10.0;\n\tfloat lines = 1.0 - smoothstep(0.006, 0.016, min(min(dist.x, dist.y), dist.z));\n\t// A borda da parte acesa brilha mais (a parede \"acendendo\" em volta do pé).\n\tfloat rim = shown * (1.0 - shown) * 4.0;\n\tALBEDO = base;\n\tEMISSION = line * (lines * 0.8 + rim * 0.35) * (0.6 + shown * 0.6);\n\tROUGHNESS = 0.4;\n\tALPHA = (0.3 * shown + lines * 0.65) * shown;\n}\n"





































	material.shader = shader
	_wall_material = material
	var thickness: = 2.0
	for axis in 3:
		for side: float in [-1.0, 1.0]:
			var size: = Vector3.ONE * box_half * 2.0
			size[axis] = thickness
			var at: = Vector3.ZERO
			at[axis] = side * (box_half + thickness * 0.5)
			var shape: = CollisionShape3D.new()
			var box: = BoxShape3D.new()
			box.size = size + Vector3.ONE * thickness * 2.0
			box.size[axis] = thickness
			shape.shape = box
			shape.position = at
			body.add_child(shape)
			var mesh: = MeshInstance3D.new()
			var plane: = BoxMesh.new()
			plane.size = size
			mesh.mesh = plane
			mesh.position = at
			mesh.material_override = material
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mesh)
			wall_meshes.append(mesh)



func set_walls_fade(amount: float) -> void :
	_wall_fade = clampf(amount, 0.0, 1.0)
	_wall_material.set_shader_parameter("fade", _wall_fade)




func _process(delta: float) -> void :
	if _wall_material == null:
		return
	var cfg: Dictionary = config.get("walls", {})
	var near: = float(cfg.get("contact_m", 1.4))
	var contacts: Array[Vector4] = []
	var players: Array = []
	for node in get_tree().get_nodes_in_group(Combat.COMBATANTS_GROUP):
		if node is Player and (node as Player).visible:
			players.append(node)
	for i in 4:
		var strength: = float(_contact_strength.get(i, 0.0))
		var at: Vector3 = _contact_point.get(i, Vector3.ZERO)
		var touching: = false
		if i < players.size():
			var feet: = (players[i] as Player).global_position
			var gap: = box_half - maxf(absf(feet.x), maxf(absf(feet.y), absf(feet.z)))
			if gap < near:
				touching = true
				at = feet
		var rate: = 1.0 / maxf(float(cfg.get("in_s" if touching else "out_s", 0.3)), 0.01)
		strength = move_toward(strength, 1.0 if touching else 0.0, rate * delta)
		_contact_strength[i] = strength
		_contact_point[i] = at
		contacts.append(Vector4(at.x, at.y, at.z, strength * strength * (3.0 - 2.0 * strength)))
	_wall_material.set_shader_parameter("contacts", contacts)
	_wall_material.set_shader_parameter("reveal_m", float(cfg.get("reveal_m", 7.0)))
	var any: = _wall_fade > 0.0 and contacts.any( func(c: Vector4) -> bool: return c.w > 0.0)
	for mesh: MeshInstance3D in wall_meshes:
		mesh.visible = any






func _build_sun(half: float, round_m: float) -> void :
	var body: = StaticBody3D.new()
	body.name = "Sun"
	body.collision_layer = PhysicsLayers.WORLD
	var rounded: = rounded_box(half, round_m, 14)
	var shape: = CollisionShape3D.new()
	var hull: = ConvexPolygonShape3D.new()
	hull.points = rounded.get_faces()
	shape.shape = hull
	body.add_child(shape)
	var mesh: = MeshInstance3D.new()
	mesh.mesh = rounded
	var material: = ShaderMaterial.new()
	material.shader = SUN_SHADER
	mesh.material_override = material
	sun_material = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mesh)
	add_child(body)

	for axis in 3:
		for side: float in [-1.0, 1.0]:
			var light: = OmniLight3D.new()
			light.light_color = Color("ffe2a0")
			light.light_energy = 1.5
			light.omni_range = box_half * 2.4
			light.omni_attenuation = 0.6
			light.shadow_enabled = axis == 1 and side > 0.0
			var at: = Vector3.ZERO
			at[axis] = side * (half + 0.6)
			light.position = at
			add_child(light)


func _build_planet(planet: Dictionary, async: bool = false) -> void :
	var block_planet: = BlockPlanet.new()
	block_planet.position = _v(planet.center)
	add_child(block_planet)
	block_planet.build_planet(planets.size() + 1, planet, async)
	planets.append(block_planet)



func restore() -> void :
	for planet: BlockPlanet in planets:
		planet.restore()



func _build_spawns() -> void :
	var planets: Array = config.get("planets", [])
	for entry: Dictionary in config.get("spawns", []):
		var planet: Dictionary = planets[int(entry.planet)]
		var up: = _v(entry.dir).normalized()

		var origin: = _v(planet.center) + up * (float(planet.radius) + Lexicon.balf("space.voxel.relief_m") + 0.3)
		var side: = up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var forward: = side.cross(up).normalized()

		spawns.append(Transform3D(Basis(side, up, side.cross(up)), origin))




static func rounded_box(half: float, r: float, steps: int) -> ArrayMesh:
	var core: = half - r
	var tool: = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in 3:
		for side: float in [-1.0, 1.0]:
			var u_axis: = (axis + 1) % 3
			var v_axis: = (axis + 2) % 3
			for i in steps:
				for j in steps:
					var quad: Array[Vector3] = []
					for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
						var p: = Vector3.ZERO
						p[axis] = side * half
						p[u_axis] = lerpf( - half, half, float(i + corner.x) / steps)
						p[v_axis] = lerpf( - half, half, float(j + corner.y) / steps)
						quad.append(p)


					for tri: Array in [[0, 1, 2], [0, 2, 3]]:
						var verts: Array[Vector3] = []
						var normals: Array[Vector3] = []
						for k: int in tri:
							var inner: = quad[k].clamp( - Vector3.ONE * core, Vector3.ONE * core)
							var n: = (quad[k] - inner).normalized()
							normals.append(n)
							verts.append(inner + n * r)
						var face_n: = (normals[0] + normals[1] + normals[2]).normalized()
						var order: Array = [0, 1, 2] if (verts[1] - verts[0]).cross(verts[2] - verts[0]).dot(face_n) < 0.0 else [0, 2, 1]
						for k: int in order:
							tool.set_normal(normals[k])
							tool.add_vertex(verts[k])
	return tool.commit()


static func _v(values: Variant) -> Vector3:
	var a: Array = values
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
