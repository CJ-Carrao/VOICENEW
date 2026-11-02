class_name PortalEnvironment
extends StaticBody3D











const FRONT: = 0.02


var portal: Portal

var bodies: Array[CollisionObject3D] = []

var _shape: ConcavePolygonShape3D

var _rim: Array[CollisionShape3D] = []
var _cfg: Dictionary = {}
var _queued: = false

var _task: = -1
var _dirty: = false
var _pending_bodies: Array[CollisionObject3D] = []
var _started: = 0


func setup(owner_portal: Portal) -> void :
	portal = owner_portal
	name = "Environment"
	collision_layer = PhysicsLayers.PORTAL_TUNNEL
	collision_mask = 0
	_cfg = Lexicon.bal("portal", {})
	var node: = CollisionShape3D.new()
	_shape = ConcavePolygonShape3D.new()
	_shape.backface_collision = true
	node.shape = _shape
	add_child(node)
	for i in 5:
		var rim: = CollisionShape3D.new()
		rim.shape = BoxShape3D.new()
		add_child(rim)
		_rim.append(rim)



func queue_rebuild() -> void :
	if not _queued:
		_queued = true
		rebuild.call_deferred()



func _on_world_changed(region: AABB) -> void :
	if not is_instance_valid(portal):
		return
	var reach: = maxf(portal.size.x, portal.size.y) + float(_cfg.get("collar_m", 1.5)) + float(_cfg.get("tunnel_depth_m", 2.5))
	var near: = AABB(portal.global_position - Vector3.ONE * reach, Vector3.ONE * reach * 2.0)
	var near_pair: = AABB(portal.pair.global_position - Vector3.ONE * reach, Vector3.ONE * reach * 2.0) if portal.is_linked() else near
	if not region.has_volume() or region.intersects(near) or region.intersects(near_pair):
		queue_rebuild()




func rebuild() -> void :
	_queued = false
	if not is_inside_tree() or portal == null:
		return
	if _task >= 0:

		_dirty = true
		return
	var half: = portal.size * 0.5
	var collar: = float(_cfg.get("collar_m", 1.5))
	var depth: = float(_cfg.get("tunnel_depth_m", 2.5))
	var rim: = float(_cfg.get("rim_m", 0.5))

	var behind: = rim + 0.5
	var to_local: = portal.global_transform.affine_inverse()
	var found: Array[CollisionObject3D] = []
	var local_pieces: Array = []

	var around: = Vector3(half.x + collar, half.y + collar, (collar + behind) * 0.5)
	var center: = portal.global_transform * Vector3(0.0, 0.0, (collar - behind) * 0.5)
	for piece in _gather(Transform3D(portal.global_basis, center), around):
		if not found.has(piece["body"]):
			found.append(piece["body"])
			_watch(piece["body"])
		local_pieces.append([to_local * (piece["transform"] as Transform3D), piece["faces"]])

	var specs: Array = [[Vector3(half.x + rim * 0.5, 0, - depth * 0.5), Vector3(rim, portal.size.y + rim * 2.0, depth)], 
		[Vector3( - half.x - rim * 0.5, 0, - depth * 0.5), Vector3(rim, portal.size.y + rim * 2.0, depth)], 
		[Vector3(0, half.y + rim * 0.5, - depth * 0.5), Vector3(portal.size.x, rim, depth)], 
		[Vector3(0, - half.y - rim * 0.5, - depth * 0.5), Vector3(portal.size.x, rim, depth)], 
		[Vector3(0, 0, - depth - rim * 0.5), Vector3(portal.size.x + rim * 2.0, portal.size.y + rim * 2.0, rim)]]
	for i in 5:
		_rim[i].position = specs[i][0]
		(_rim[i].shape as BoxShape3D).size = specs[i][1]

	var carried: Array = []
	if portal.is_linked():
		var exit: = portal.pair.global_transform
		var from_exit: = Transform3D(Portal.FLIP, Vector3.ZERO) * exit.affine_inverse()
		for piece in _gather(Transform3D(exit.basis, exit * Vector3(0.0, 0.0, depth * 0.5)), Vector3(half.x, half.y, depth * 0.5)):
			_watch(piece["body"])
			carried.append([from_exit * (piece["transform"] as Transform3D), piece["faces"]])
	global_transform = portal.global_transform
	_pending_bodies = found
	_started = Time.get_ticks_usec()
	var job: = {"local": local_pieces, "carried": carried, "half": half, "around": around, "collar": collar, 
		"behind": behind, "depth": depth}
	_task = WorkerThreadPool.add_task(_build.bind(job))



func _build(job: Dictionary) -> void :
	var faces: = PackedVector3Array()
	var half: Vector2 = job["half"]
	for piece: Array in job["local"]:
		var xf: Transform3D = piece[0]
		var tris: PackedVector3Array = piece[1]
		for i in range(0, tris.size() - 2, 3):
			_carve(xf * tris[i], xf * tris[i + 1], xf * tris[i + 2], half, job["around"], job["behind"], job["collar"], faces)
	for piece: Array in job["carried"]:
		var xf: Transform3D = piece[0]
		var tris: PackedVector3Array = piece[1]
		for i in range(0, tris.size() - 2, 3):
			_carry(xf * tris[i], xf * tris[i + 1], xf * tris[i + 2], half, job["depth"], faces)
	_apply.call_deferred(faces)


func _apply(faces: PackedVector3Array) -> void :
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	_shape.set_faces(faces)
	bodies = _pending_bodies
	if OS.has_environment("PORTAL_DEBUG"):
		print("[cópia] %s: %d faces em %.1f ms (thread)" % [portal.name, faces.size() / 3, (Time.get_ticks_usec() - _started) / 1000.0])
	if _dirty:
		_dirty = false
		queue_rebuild()


func _exit_tree() -> void :
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1



func _watch(body: Node) -> void :
	if body.has_signal("mesh_changed") and not body.is_connected("mesh_changed", _on_world_changed):
		body.connect("mesh_changed", _on_world_changed)



func _gather(box: Transform3D, extents: Vector3) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var query: = PhysicsShapeQueryParameters3D.new()
	var shape: = BoxShape3D.new()
	shape.size = extents * 2.0
	query.shape = shape
	query.transform = box
	query.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.THINGS
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, int(_cfg.get("gather_max", 256))):
		var body: = hit.get("collider") as CollisionObject3D

		if body == null or not (body is StaticBody3D or portal.walls.has(body)):
			continue
		var rid: = body.get_rid()
		var index: = int(hit.get("shape", 0))
		var faces: = _shape_faces(PhysicsServer3D.body_get_shape(rid, index))
		if faces.is_empty():
			continue
		out.append({"body": body, "faces": faces, 
			"transform": body.global_transform * PhysicsServer3D.body_get_shape_transform(rid, index)})
	return out



static func _shape_faces(shape: RID) -> PackedVector3Array:
	var data: Variant = PhysicsServer3D.shape_get_data(shape)
	match PhysicsServer3D.shape_get_type(shape):
		PhysicsServer3D.SHAPE_CONCAVE_POLYGON:
			return (data as Dictionary).get("faces", PackedVector3Array())
		PhysicsServer3D.SHAPE_BOX:
			var box: = BoxMesh.new()
			box.size = (data as Vector3) * 2.0
			return box.get_faces()
		PhysicsServer3D.SHAPE_SPHERE:
			var ball: = SphereMesh.new()
			ball.radius = float(data)
			ball.height = ball.radius * 2.0
			ball.radial_segments = 64
			ball.rings = 32
			return ball.get_faces()
		PhysicsServer3D.SHAPE_HEIGHTMAP:
			return _heightmap_faces(data as Dictionary)
	return PackedVector3Array()


static func _heightmap_faces(data: Dictionary) -> PackedVector3Array:
	var width: = int(data.get("width", 0))
	var depth: = int(data.get("depth", 0))
	var heights: PackedFloat32Array = data.get("heights", PackedFloat32Array())
	var out: = PackedVector3Array()
	if width < 2 or depth < 2 or heights.size() < width * depth:
		return out
	var offset: = Vector3((width - 1) * 0.5, 0.0, (depth - 1) * 0.5)
	for z in depth - 1:
		for x in width - 1:
			var p00: = Vector3(x, heights[z * width + x], z) - offset
			var p10: = Vector3(x + 1, heights[z * width + x + 1], z) - offset
			var p01: = Vector3(x, heights[(z + 1) * width + x], z + 1) - offset
			var p11: = Vector3(x + 1, heights[(z + 1) * width + x + 1], z + 1) - offset
			out.append_array([p00, p10, p01, p10, p11, p01])
	return out





static func _carve(a: Vector3, b: Vector3, c: Vector3, half: Vector2, around: Vector3, behind: float, collar: float, 
		out: PackedVector3Array) -> void :
	if (a.z > collar and b.z > collar and c.z > collar) or (a.z < - behind and b.z < - behind and c.z < - behind):
		return
	if (a.x > around.x and b.x > around.x and c.x > around.x) or (a.x < - around.x and b.x < - around.x and c.x < - around.x):
		return
	if (a.y > around.y and b.y > around.y and c.y > around.y) or (a.y < - around.y and b.y < - around.y and c.y < - around.y):
		return
	var outside_hole: = (a.x > half.x and b.x > half.x and c.x > half.x) or (a.x < - half.x and b.x < - half.x and c.x < - half.x)\
	or (a.y > half.y and b.y > half.y and c.y > half.y) or (a.y < - half.y and b.y < - half.y and c.y < - half.y)\
	or (a.z > FRONT and b.z > FRONT and c.z > FRONT)
	var polygon: Array[Vector3] = [a, b, c]
	if outside_hole:
		_emit(polygon, out)
		return

	for plane: Plane in [Plane(Vector3.LEFT, - half.x), Plane(Vector3.RIGHT, - half.x), Plane(Vector3.DOWN, - half.y), 
			Plane(Vector3.UP, - half.y)]:

		_emit(Portal._clip_polygon(polygon, plane), out)
		polygon = Portal._clip_polygon(polygon, Plane( - plane.normal, - plane.d))
		if polygon.size() < 3:
			return
	_emit(Portal._clip_polygon(polygon, Plane(Vector3.FORWARD, - FRONT)), out)




static func _carry(a: Vector3, b: Vector3, c: Vector3, half: Vector2, depth: float, out: PackedVector3Array) -> void :
	var polygon: Array[Vector3] = [a, b, c]
	for plane: Plane in [Plane(Vector3.RIGHT, half.x), Plane(Vector3.LEFT, half.x), Plane(Vector3.UP, half.y), 
			Plane(Vector3.DOWN, half.y), Plane(Vector3.FORWARD, depth), Plane(Vector3.BACK, - FRONT)]:
		polygon = Portal._clip_polygon(polygon, plane)
		if polygon.size() < 3:
			return
	_emit(polygon, out)


static func _emit(polygon: Array[Vector3], out: PackedVector3Array) -> void :
	for i in range(1, polygon.size() - 1):
		if (polygon[i] - polygon[0]).cross(polygon[i + 1] - polygon[0]).length_squared() < 1e-10:
			continue
		out.append(polygon[0])
		out.append(polygon[i])
		out.append(polygon[i + 1])
