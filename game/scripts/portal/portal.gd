class_name Portal
extends Node3D














const SURFACE_SHADER: = preload("res://scripts/portal/portal_surface.gdshader")

const FLIP: = Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1))
const COLORS: Array[Color] = [Color("17c6ff"), Color("f2601a")]


var owner_id: int = 0
var slot: int = 0

var size: = Vector2(1.1, 2.2)
var pair: Portal

var walls: Array[CollisionObject3D] = []

var visual_layer: int = 11

var surface: MeshInstance3D
var viewport: SubViewport
var view_camera: Camera3D
var _material: ShaderMaterial

var environment: PortalEnvironment
var _environment_source: Environment

var _depth: float = 0.1

var _film_points: = PackedVector3Array()
var _rebuild_queued: = false


var blocks: PortalBlocks
var _age: = 0.0
var _wave_at: = 0.0
var _reveal_at: = -1.0
var _revealed: = false



func setup(id: int, which: int, place: Transform3D, opening: Vector2, wall_bodies: Array[CollisionObject3D], layer: int, 
		depth: float = 0.1) -> void :
	owner_id = id
	slot = which
	size = opening
	walls = wall_bodies
	visual_layer = layer
	_depth = maxf(depth, 0.02)
	name = "Portal_%d_%s" % [id, "AB"[which]]
	global_transform = place
	var cfg: Dictionary = Lexicon.bal("portal", {})
	surface = MeshInstance3D.new()
	surface.name = "Surface"
	surface.layers = 1 << (layer - 1)
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = SURFACE_SHADER
	_material.set_shader_parameter("tint", COLORS[which])
	_material.set_shader_parameter("depth_bias", float(cfg.get("depth_bias", 0.0002)))
	_material.set_shader_parameter("size", size)
	surface.material_override = _material
	add_child(surface)
	viewport = SubViewport.new()
	viewport.name = "View"
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.size = Vector2i(64, 128)

	viewport.use_hdr_2d = true
	add_child(viewport)
	view_camera = Camera3D.new()
	view_camera.projection = Camera3D.PROJECTION_FRUSTUM
	view_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	view_camera.current = true
	viewport.add_child(view_camera)
	environment = PortalEnvironment.new()
	add_child(environment)
	environment.setup(self)
	environment.rebuild()
	_build_film()
	blocks = PortalBlocks.new()
	add_child(blocks)
	blocks.setup(self)
	blocks.play("open")
	SoundBank.play_at(self, "portal/open", global_position)
	for wall in walls:
		if wall.has_signal("mesh_changed"):
			wall.connect("mesh_changed", _queue_rebuild)


func _queue_rebuild(region: AABB = AABB()) -> void :
	var reach: = maxf(size.x, size.y)
	if region.has_volume() and not region.intersects(AABB(global_position - Vector3.ONE * reach, Vector3.ONE * reach * 2.0)):
		return
	if not _rebuild_queued:
		_rebuild_queued = true
		_build_film.call_deferred()






func _build_film() -> void :
	_rebuild_queued = false
	var to_local: = global_transform.affine_inverse()
	var half: = size * 0.5
	var region: = global_transform * AABB(Vector3( - half.x, - half.y, - _depth), Vector3(size.x, size.y, _depth + 0.02))
	var out: = PackedVector3Array()
	for wall in walls:
		if not is_instance_valid(wall):
			continue
		for source in _wall_faces(wall, region):
			var xf: Transform3D = to_local * (source["transform"] as Transform3D)
			var faces: PackedVector3Array = source["faces"]
			for i in range(0, faces.size() - 2, 3):
				_clip_triangle(xf * faces[i], xf * faces[i + 1], xf * faces[i + 2], half, out)
	if out.is_empty() and surface.mesh != null:

		var system: = get_parent() as PortalSystem
		if system != null:
			system.close(self)
		return
	if out.is_empty():
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			out.append(Vector3(corner.x * half.x, corner.y * half.y, 0.0))
	var arrays: = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out
	var uv: = PackedVector2Array()
	uv.resize(out.size())
	for i in out.size():
		uv[i] = Vector2(out[i].x / size.x + 0.5, 0.5 - out[i].y / size.y)
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var mesh: = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	surface.mesh = mesh
	_film_points = out




func _wall_faces(wall: Node, region: AABB) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for node in wall.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: = node as MeshInstance3D
		if mesh_node.mesh == null or not mesh_node.is_visible_in_tree():
			continue
		if not (mesh_node.global_transform * mesh_node.get_aabb()).intersects(region):
			continue
		out.append({"transform": mesh_node.global_transform, "faces": mesh_node.mesh.get_faces()})
	if not out.is_empty():
		return out
	for node in wall.find_children("*", "CollisionShape3D", true, false):
		var shape_node: = node as CollisionShape3D
		if shape_node.disabled or shape_node.shape == null:
			continue
		var faces: = PackedVector3Array()
		if shape_node.shape is ConcavePolygonShape3D:
			faces = (shape_node.shape as ConcavePolygonShape3D).get_faces()
		elif shape_node.shape is BoxShape3D:
			var box: = BoxMesh.new()
			box.size = (shape_node.shape as BoxShape3D).size
			faces = box.get_faces()
		elif shape_node.shape is SphereShape3D:
			var ball: = SphereMesh.new()
			ball.radius = (shape_node.shape as SphereShape3D).radius
			ball.height = ball.radius * 2.0
			ball.radial_segments = 96
			ball.rings = 48
			faces = ball.get_faces()
		if not faces.is_empty():
			out.append({"transform": shape_node.global_transform, "faces": faces})
	return out



func _clip_triangle(a: Vector3, b: Vector3, c: Vector3, half: Vector2, out: PackedVector3Array) -> void :

	if (a.x > half.x and b.x > half.x and c.x > half.x) or (a.x < - half.x and b.x < - half.x and c.x < - half.x):
		return
	if (a.y > half.y and b.y > half.y and c.y > half.y) or (a.y < - half.y and b.y < - half.y and c.y < - half.y):
		return
	if (a.z < - _depth and b.z < - _depth and c.z < - _depth) or (a.z > 0.02 and b.z > 0.02 and c.z > 0.02):
		return
	var polygon: Array[Vector3] = [a, b, c]
	for plane: Plane in [Plane(Vector3.RIGHT, half.x), Plane(Vector3.LEFT, half.x), Plane(Vector3.UP, half.y), 
			Plane(Vector3.DOWN, half.y), Plane(Vector3.FORWARD, _depth), Plane(Vector3.BACK, 0.02)]:
		polygon = _clip_polygon(polygon, plane)
		if polygon.size() < 3:
			return
	for i in range(1, polygon.size() - 1):

		if (polygon[i] - polygon[0]).cross(polygon[i + 1] - polygon[0]).length_squared() < 1e-10:
			continue
		out.append(polygon[0])
		out.append(polygon[i])
		out.append(polygon[i + 1])



static func _clip_polygon(polygon: Array[Vector3], plane: Plane) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in polygon.size():
		var p: = polygon[i]
		var q: = polygon[(i + 1) % polygon.size()]
		var dp: = plane.distance_to(p)
		var dq: = plane.distance_to(q)
		if dp <= 0.0:
			out.append(p)
		if (dp <= 0.0) != (dq <= 0.0):
			out.append(p.lerp(q, dp / (dp - dq)))
	return out



func animate(delta: float) -> void :
	_age += delta
	_material.set_shader_parameter("time_open", _age - _wave_at)
	var reveal: = -1.0
	if _reveal_at >= 0.0 and _age >= _reveal_at:
		reveal = (_age - _reveal_at) * float(Lexicon.bal("portal.fx.reveal_ms", 3.5))
		if not _revealed:
			_revealed = true
			blocks.play("reveal")
			SoundBank.play_at(self, "portal/link", global_position)
	_material.set_shader_parameter("reveal_m", reveal)
	blocks.advance(delta)



func burst(into: Node) -> void :
	SoundBank.play_at(into, "portal/close", global_position)
	if blocks != null:
		blocks.burst(into)
		blocks = null


func is_linked() -> bool:
	return pair != null and is_instance_valid(pair)


func link(other: Portal) -> void :
	pair = other
	_material.set_shader_parameter("linked", is_linked())

	_reveal_at = maxf(_age, float(Lexicon.bal("portal.fx.reveal_delay_s", 0.25)))
	_revealed = false

	environment.queue_rebuild()


func unlink() -> void :
	pair = null
	_material.set_shader_parameter("linked", false)

	_reveal_at = -1.0
	_wave_at = _age
	if blocks != null:
		blocks.play("open")
	environment.queue_rebuild()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED



func transfer() -> Transform3D:
	return pair.global_transform * Transform3D(FLIP, Vector3.ZERO) * global_transform.affine_inverse()


func to_local_point(point: Vector3) -> Vector3:
	return global_transform.affine_inverse() * point



func opening_contains(local: Vector3, margin: float = 0.0) -> bool:
	return rect_contains(local, - margin)



func rect_contains(local: Vector3, margin: float = 0.0) -> bool:
	return absf(local.x) <= size.x * 0.5 + margin and absf(local.y) <= size.y * 0.5 + margin






func update_view(eye: Camera3D, viewport_size: Vector2, cfg: Dictionary, pixel_scale: float = 1.0) -> bool:
	if not is_linked() or eye == null:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return false
	var eye_local: = to_local_point(eye.global_position)

	if eye_local.z <= 0.0 or eye_local.length() > eye.far:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return false



	var window: = _film_window(eye_local)
	var crop: = _visible_crop(eye, eye_local, viewport_size, window)
	var screen: = viewport_size.y if crop != window else _screen_height(eye, viewport_size, window)
	if screen <= 0.0 or crop.size.x <= 0.0 or crop.size.y <= 0.0:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return false

	var exit: = pair.global_transform
	var virtual_eye: = exit * (FLIP * eye_local)
	var cam_basis: = exit.basis * Basis(Vector3.UP, PI)
	view_camera.global_transform = Transform3D(cam_basis, virtual_eye)


	view_camera.cull_mask = 1048575 & ~ (1 << (pair.visual_layer - 1))
	_sync_environment(eye)
	var step: = maxi(int(cfg.get("view_step_px", 48)), 8)
	var height: = clampi(int(ceil(screen * pixel_scale / step)) * step, int(cfg.get("view_height_px_min", 96)), 
		int(cfg.get("view_height_px_max", 2160)))
	var want: = Vector2i(clampi(int(round(height * crop.size.x / crop.size.y)), 8, height * 4), height)
	if viewport.size != want:
		viewport.size = want

	var center: = crop.get_center()
	var width: = crop.size.y * want.x / want.y
	crop = Rect2(center.x - width * 0.5, crop.position.y, width, crop.size.y)

	var crop_in_cam: = view_camera.global_transform.affine_inverse() * (exit * (FLIP * Vector3(center.x, center.y, 0.0)))
	var near: = maxf( - crop_in_cam.z, 0.0005)
	view_camera.set_frustum(crop.size.y, Vector2(crop_in_cam.x, crop_in_cam.y), near, eye.far)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	_material.set_shader_parameter("crop", Vector4(crop.position.x / size.x + 0.5, 0.5 - crop.end.y / size.y, 
		crop.size.x / size.x, crop.size.y / size.y))
	_material.set_shader_parameter("view", viewport.get_texture())
	return true




func match_quality(main: Viewport) -> void :
	if viewport.msaa_3d != main.msaa_3d:
		viewport.msaa_3d = main.msaa_3d
	if viewport.screen_space_aa != main.screen_space_aa:
		viewport.screen_space_aa = main.screen_space_aa
	if viewport.use_taa != main.use_taa:
		viewport.use_taa = main.use_taa




func _sync_environment(eye: Camera3D) -> void :
	var source: = eye.environment
	if source == null and eye.get_world_3d() != null:
		source = eye.get_world_3d().environment
	if source == _environment_source:
		return
	_environment_source = source
	if source == null:
		view_camera.environment = null
		return
	var env: = source.duplicate() as Environment
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.tonemap_white = 1.0
	env.glow_enabled = false
	env.adjustment_enabled = false
	view_camera.environment = env




func _film_window(eye_local: Vector3) -> Rect2:
	var full: = Rect2( - size * 0.5, size)
	var low: = full.position
	var high: = full.end
	for point in _film_points:
		if point.z > -0.001:
			continue
		var t: = eye_local.z / (eye_local.z - point.z)
		var at: = eye_local + (point - eye_local) * t
		low = low.min(Vector2(at.x, at.y))
		high = high.max(Vector2(at.x, at.y))
	return Rect2(low, high - low).intersection(full.grow_individual(size.x * 0.5, size.y * 0.5, size.x * 0.5, size.y * 0.5))





func _visible_crop(eye: Camera3D, eye_local: Vector3, viewport_size: Vector2, full: Rect2) -> Rect2:
	if eye_local.z > maxf(size.x, size.y):
		return full
	var to_local: = global_transform.basis.inverse()
	var low: = Vector2(INF, INF)
	var high: = Vector2( - INF, - INF)
	for corner: Vector2 in [Vector2.ZERO, Vector2(viewport_size.x, 0.0), Vector2(0.0, viewport_size.y), viewport_size]:
		var ray: = to_local * eye.project_ray_normal(corner)
		if ray.z > -0.05:
			return full
		var hit: = eye_local + ray * ( - eye_local.z / ray.z)
		low = low.min(Vector2(hit.x, hit.y))
		high = high.max(Vector2(hit.x, hit.y))
	var pad: = (high - low) * 0.1
	var seen: = Rect2(low - pad, high - low + pad * 2.0).intersection(full)
	if not seen.has_area() or seen.size.x * seen.size.y > full.size.x * full.size.y * 0.5:
		return full
	return seen



func _screen_height(eye: Camera3D, viewport_size: Vector2, rect: Rect2) -> float:
	var top: = INF
	var bottom: = - INF
	var visible_any: = false
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]:
		var world: = global_transform * Vector3(corner.x, corner.y, 0.0)
		if eye.is_position_behind(world):

			return viewport_size.y
		visible_any = visible_any or eye.is_position_in_frustum(world)
		var p: = eye.unproject_position(world)
		top = minf(top, p.y)
		bottom = maxf(bottom, p.y)
	if not visible_any and not _frustum_crosses(eye):
		return 0.0
	return clampf(bottom - top, 1.0, viewport_size.y * 2.0)



func _frustum_crosses(eye: Camera3D) -> bool:
	var forward: = - eye.global_basis.z
	var to_center: = global_position - eye.global_position
	return to_center.dot(forward) > 0.0 and to_center.length() < maxf(size.x, size.y) * 2.0
