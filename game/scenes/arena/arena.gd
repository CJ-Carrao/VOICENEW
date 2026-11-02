class_name Arena
extends Node3D





signal world_reset

const WORLD_LAYER: = 1

var size: float = 0.0

var map_id: String = "original"

static var active_size: float = 96.0
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
	_layout = _read_layout()
	size = float(_layout.get("size", Lexicon.balf("arena.size")))
	active_size = size
	terrain = Terrain.new()
	terrain.chunk_cells_override = int(_layout.get("terrain_chunk_cells", 0))
	add_child(terrain)
	terrain.build(size, _layout.get("hills", []), build_async, _layout.get("ground", {}), float(_layout.get("ground_depth_m", 0.0)))
	terrain.changed.connect(_on_terrain_changed)
	if map_id == "tokyo3":
		_build_city_light()
	_build_bounds(float(_layout.get("wall_height", Lexicon.balf("arena.wall_height"))), Lexicon.balf("arena.wall_thickness"))
	if _layout.has("spawns"):
		_build_layout_spawns(_layout["spawns"])
	else:
		_build_spawns(Lexicon.balf("arena.spawn_distance"))


static func chosen_map() -> String:
	if not next_map.is_empty():
		return next_map
	for arg in MobileDev.args():
		if arg.begins_with("--mapa="):
			var requested: = arg.trim_prefix("--mapa=")
			if requested in ["espaco", "espaço", "space"]: return "space"
			if requested in ["toquio3", "tokyo3"]: return "tokyo3"
			return "original"
	return "original"



func is_world_ready() -> bool:
	if space != null:
		return space.is_ready()
	if terrain != null and not terrain.is_settled():
		return false
	for structure: Structure in structures():
		if not structure.is_settled():
			return false
	return true



func world_progress() -> float:
	if space != null:
		return space.build_progress()
	var list: = structures()
	var total: = (1 if terrain != null else 0) + list.size()
	if total <= 0:
		return 1.0
	var sum: = terrain.build_progress() if terrain != null else 0.0
	for structure: Structure in list:
		sum += structure.build_progress()
	return sum / float(total)



static func take_intro() -> bool:
	var wanted: = play_intro or MobileDev.args().has("--mapa-intro")
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


func _build_city_light() -> void :
	var world: = get_node_or_null("WorldEnvironment") as WorldEnvironment
	var sun: = get_node_or_null("Sun") as DirectionalLight3D
	if world != null:
		var env: = world.environment.duplicate(true) as Environment
		var sky: = env.sky.duplicate(true) as Sky
		var paint: = sky.sky_material.duplicate(true) as ProceduralSkyMaterial
		paint.sky_top_color = Color("#55a6d7")
		paint.sky_horizon_color = Color("#c4e9f3")
		paint.ground_horizon_color = Color("#a6d4de")
		paint.ground_bottom_color = Color("#6eacc6")
		sky.sky_material = paint
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("#c9dce9")
		env.ambient_light_energy = 0.8
		env.tonemap_exposure = 1.0
		world.environment = env
	if sun != null:
		sun.rotation = Vector3(deg_to_rad(-38.0), deg_to_rad(225.0), 0.0)
		sun.light_color = Color("#fff1d5")
		sun.light_energy = 1.45
	var ocean: = preload("res://scripts/world/city_ocean.gd").new() as MeshInstance3D
	ocean.set("island_half_size", size * 0.5)
	add_child(ocean)



func reset_world() -> void :

	var portals: = PortalSystem.find(get_tree())
	if portals != null:
		portals.close_all()
	if terrain != null:
		terrain.restore()
	if space != null:
		space.restore()
	var entries: Array = _layout.get("structures", [])
	var existing: = structures()
	var can_reuse: = destructibles != null and existing.size() == entries.size()
	if can_reuse:
		for i in entries.size():
			if existing[i].blueprint_id != String(entries[i]["blueprint"]):
				can_reuse = false
				break
	if can_reuse:
		for child in destructibles.get_children():
			if not (child is Structure):
				destructibles.remove_child(child)
				child.queue_free()
		for structure: Structure in existing:
			structure.restore()
		world_reset.emit()
		return
	if destructibles != null:
		remove_child(destructibles)
		destructibles.queue_free()
	destructibles = Node3D.new()
	destructibles.name = "Destructibles"
	add_child(destructibles)
	var async_structures: = build_async and not Session.is_online()
	var serial: = 0
	for entry: Dictionary in entries:
		serial += 1
		var id: = String(entry["blueprint"])
		var at: Array = entry.get("pos", [0.0, 0.0, 0.0])
		var structure: = Structure.new()
		structure.chunk_cells_override = int(_layout.get("structure_chunk_cells", 0))
		structure.network_id = serial
		structure.name = "Structure%d" % serial
		structure.position = Vector3(float(at[0]), float(at[1]), float(at[2]))
		structure.rotation.y = deg_to_rad(float(entry.get("rot", 0.0)))
		destructibles.add_child(structure)
		structure.build(StructureBlueprints.chunks(id), id, async_structures)
	world_reset.emit()


func _read_layout() -> Dictionary:
	var path: = "res://data/world/tokyo3.json" if map_id == "tokyo3" else String(Lexicon.bal("world.layout", ""))
	var layout: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not layout is Dictionary:
		push_warning("[Mundo] mapa não encontrado: %s" % path)
		return {}
	if String(layout.get("ground_depth_from", "")) == "original":
		var original_path: = String(Lexicon.bal("world.layout", ""))
		var original: Variant = JSON.parse_string(FileAccess.get_file_as_string(original_path))
		if original is Dictionary:
			layout["ground_depth_m"] = float(original.get("ground_depth_m", 0.0))
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

	var below: = (terrain.dig_depth_m if terrain != null else Lexicon.balf("terrain.max_depth_m")) + 1.0
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

		wall.add_to_group(PortalSystem.NO_PORTAL_GROUP)

		wall.position = center - Vector3(0.0, below, 0.0)
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
		panel.visible = map_id != "tokyo3"
		wall.add_child(panel)


		for y in [ - height * 0.5, height * 0.5]:
			var strip: = MeshInstance3D.new()
			var strip_mesh: = BoxMesh.new()
			strip_mesh.size = Vector3(extent.x + 0.02, 0.08, extent.z + 0.02)
			strip_mesh.material = edge
			strip.mesh = strip_mesh
			strip.position.y = y
			strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			strip.visible = map_id != "tokyo3"
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



func _build_layout_spawns(entries: Array) -> void :
	_spawns.clear()
	for i in entries.size():
		var entry: Array = entries[i]
		var at: = Vector3(float(entry[0]), 0.05, float(entry[1]))
		var transform: = Transform3D(Basis(Vector3.UP, deg_to_rad(float(entry[2]))), at)
		_spawns.append(transform)
		var marker: = Marker3D.new()
		marker.name = "Spawn%s" % ["A", "B", "C", "D"][i]
		marker.transform = transform
		add_child(marker)
