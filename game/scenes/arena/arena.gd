class_name Arena
extends Node3D





signal world_reset

const WORLD_LAYER: = 1

var size: float = 0.0

var map_id: String = "original"
var space: SpaceMap = null

static var next_map: String = ""

static var play_intro: bool = false

static var build_async: bool = false

var destructibles: Node3D = null
var terrain: Terrain = null
var _spawns: Array[Transform3D] = []
var _layout: Dictionary = {}


func _ready() -> void :

	if Session.is_online():
		build_async = false
		BlockVolume.loading = false
	map_id = chosen_map()
	if map_id == "space":
		_build_space()
		return
	size = Lexicon.balf("arena.size")
	_layout = _read_layout()
	terrain = Terrain.new()
	add_child(terrain)
	terrain.build(size, _layout.get("hills", []), build_async)
	terrain.changed.connect(_on_terrain_changed)
	_build_bounds(Lexicon.balf("arena.wall_height"), Lexicon.balf("arena.wall_thickness"))
	_build_spawns(Lexicon.balf("arena.spawn_distance"))


static func chosen_map() -> String:
	if not next_map.is_empty():
		return next_map
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mapa="):
			return "space" if arg.trim_prefix("--mapa=") in ["espaco", "espaço", "space"] else "original"
	return "original"



func is_world_ready() -> bool:
	if space != null:
		return space.is_ready()
	return terrain == null or terrain.is_settled()



func world_progress() -> float:
	if space != null:
		return space.build_progress()
	return terrain.build_progress() if terrain != null else 1.0



static func take_intro() -> bool:
	var wanted: = play_intro or OS.get_cmdline_user_args().has("--mapa-intro")
	play_intro = false
	return wanted



func _build_space() -> void :
	for node_name in ["WorldEnvironment", "Sun"]:
		var node: = get_node_or_null(node_name)
		if node != null:
			remove_child(node)
			node.queue_free()
	space = SpaceMap.new()
	add_child(space)
	space.build(build_async)
	size = space.box_half * 2.0
	_spawns = space.spawns



func reset_world() -> void :
	if destructibles != null:
		remove_child(destructibles)
		destructibles.queue_free()
	destructibles = Node3D.new()
	destructibles.name = "Destructibles"
	add_child(destructibles)
	if terrain != null:
		terrain.restore()
	if space != null:
		space.restore()
	var serial: = 0
	for entry: Dictionary in _layout.get("structures", []):
		serial += 1
		var id: = String(entry["blueprint"])
		var at: Array = entry.get("pos", [0.0, 0.0, 0.0])
		var structure: = Structure.new()
		structure.network_id = serial
		structure.name = "Structure%d" % serial
		structure.position = Vector3(float(at[0]), float(at[1]), float(at[2]))
		structure.rotation.y = deg_to_rad(float(entry.get("rot", 0.0)))
		destructibles.add_child(structure)
		structure.build(StructureBlueprints.chunks(id), id)
	world_reset.emit()


func _read_layout() -> Dictionary:
	var layout: Variant = JSON.parse_string(FileAccess.get_file_as_string(String(Lexicon.bal("world.layout", ""))))
	if not layout is Dictionary:
		push_warning("[Mundo] mapa não encontrado: %s" % Lexicon.bal("world.layout", ""))
		return {}
	return layout



func _on_terrain_changed(center: Vector3, radius: float) -> void :
	if destructibles == null:
		return
	for structure: Structure in structures():
		if structure.is_near(center, radius):
			structure.recheck_support()

	if not Session.has_authority():
		return
	for node in get_tree().get_nodes_in_group(Rubble.GROUP):
		var pile: = node as Rubble
		if pile != null and Vector2(pile.global_position.x - center.x, pile.global_position.z - center.z).length() < radius + 1.5:
			pile.global_position.y = terrain.ground_below(pile.global_position + Vector3.UP * 0.1).y



func structures() -> Array[Structure]:
	var out: Array[Structure] = []
	if destructibles != null:
		for child in destructibles.get_children():
			if child is Structure and not child.is_queued_for_deletion():
				out.append(child)
	return out



func get_spawn(index: int) -> Transform3D:
	return _spawns[index % _spawns.size()]


func _build_bounds(height: float, thickness: float) -> void :
	var half: = size * 0.5
	var glass: = StandardMaterial3D.new()
	glass.albedo_color = Color(0.45, 0.75, 1.0, 0.1)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var edge: = StandardMaterial3D.new()
	edge.albedo_color = Color(0.55, 0.85, 1.0)
	edge.emission_enabled = true
	edge.emission = Color(0.45, 0.8, 1.0)
	edge.emission_energy_multiplier = 1.5

	var long_side: = size + thickness * 2.0

	var below: = Lexicon.balf("terrain.max_depth_m") + 1.0
	height += below

	var sides: Array[Array] = [
		[Vector3(0, height * 0.5, - half - thickness * 0.5), Vector3(long_side, height, thickness)], 
		[Vector3(0, height * 0.5, half + thickness * 0.5), Vector3(long_side, height, thickness)], 
		[Vector3(half + thickness * 0.5, height * 0.5, 0), Vector3(thickness, height, size)], 
		[Vector3( - half - thickness * 0.5, height * 0.5, 0), Vector3(thickness, height, size)], 
	]
	for i in sides.size():
		var center: Vector3 = sides[i][0]
		var extent: Vector3 = sides[i][1]
		var wall: = StaticBody3D.new()
		wall.name = "Bound%d" % i
		wall.collision_layer = WORLD_LAYER
		wall.position = center - Vector3(0.0, below * 0.5, 0.0)
		add_child(wall)

		var shape: = CollisionShape3D.new()
		var box: = BoxShape3D.new()
		box.size = extent
		shape.shape = box
		wall.add_child(shape)

		var panel: = MeshInstance3D.new()
		var panel_mesh: = BoxMesh.new()
		panel_mesh.size = extent
		panel_mesh.material = glass
		panel.mesh = panel_mesh
		panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wall.add_child(panel)


		for y in [ - height * 0.5, height * 0.5]:
			var strip: = MeshInstance3D.new()
			var strip_mesh: = BoxMesh.new()
			strip_mesh.size = Vector3(extent.x + 0.02, 0.08, extent.z + 0.02)
			strip_mesh.material = edge
			strip.mesh = strip_mesh
			strip.position.y = y
			strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			wall.add_child(strip)


func _build_spawns(distance: float) -> void :
	var half: = distance * 0.5

	_spawns = [
		Transform3D(Basis.IDENTITY, Vector3(0, 0.05, half)), 
		Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0.05, - half)), 
		Transform3D(Basis(Vector3.UP, - PI * 0.5), Vector3( - half, 0.05, 0)), 
		Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(half, 0.05, 0)), 
	]
	for i in _spawns.size():
		var marker: = Marker3D.new()
		marker.name = "Spawn%s" % ["A", "B", "C", "D"][i]
		marker.transform = _spawns[i]
		add_child(marker)
