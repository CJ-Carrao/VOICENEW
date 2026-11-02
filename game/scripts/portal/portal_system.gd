class_name PortalSystem
extends Node










const GROUP: = "portal_system"

const NO_PORTAL_GROUP: = "no_portal"
const LAYER_FIRST: = 11
const LAYER_LAST: = 20


var _pairs: Dictionary = {}

var _next_slot: Dictionary = {}

var _passing: Dictionary = {}
var _cfg: Dictionary = {}
var _base_near: Dictionary = {}

var _clones: Dictionary = {}

var _render_eye: Dictionary = {}

var last_reject: = ""



static func find(tree: SceneTree) -> PortalSystem:
	return tree.get_first_node_in_group(GROUP) as PortalSystem



static func of(tree: SceneTree) -> PortalSystem:
	var existing: = find(tree)
	if existing != null:
		return existing
	var host: Node = Forge.world if Forge.world != null and is_instance_valid(Forge.world) else tree.current_scene
	if host == null:
		return null
	var system: = PortalSystem.new()
	system.name = "PortalSystem"
	host.add_child(system)
	return system


func _ready() -> void :
	add_to_group(GROUP)
	_cfg = Lexicon.bal("portal", {})

	process_priority = 1000





func open(owner_id: int, slot: int, point: Vector3, normal: Vector3, up_hint: Vector3, scale: float = 1.0, 
		shot_from: Vector3 = Vector3.INF) -> Portal:
	scale = clampf(scale, float(_cfg.get("min_scale", 0.5)), float(_cfg.get("max_scale", 2.5)))
	var opening: = Vector2(float(_cfg.get("width_m", 1.1)), float(_cfg.get("height_m", 2.2))) * scale
	last_reject = ""
	var place: = _placement(point, normal.normalized(), up_hint, opening, shot_from)
	if place.is_empty():
		return null
	var pair: Array = _pairs.get(owner_id, [null, null])
	var old: = pair[slot] as Portal
	if _overlaps(place["transform"], opening, old):
		last_reject = "em cima de outro portal"
		return null
	var layer: = _free_layer(old)
	if layer < 0:
		return null
	if old != null and is_instance_valid(old):
		_close(old)
	var portal: = Portal.new()
	add_child(portal)
	portal.setup(owner_id, slot, place["transform"], opening, place["walls"], layer, place["depth"])
	pair[slot] = portal
	_pairs[owner_id] = pair
	var other: = pair[1 - slot] as Portal
	if other != null and is_instance_valid(other):
		portal.link(other)
		other.link(portal)
	return portal




func open_next(owner_id: int, point: Vector3, normal: Vector3, up_hint: Vector3, scale: float = 1.0, 
		shot_from: Vector3 = Vector3.INF) -> Portal:
	var slot: = int(_next_slot.get(owner_id, 0))
	var portal: = open(owner_id, slot, point, normal, up_hint, scale, shot_from)
	if portal != null:
		_next_slot[owner_id] = 1 - slot
	return portal


func portals_of(owner_id: int) -> Array:
	return _pairs.get(owner_id, [null, null])


func all_portals() -> Array[Portal]:
	var out: Array[Portal] = []
	for pair: Array in _pairs.values():
		for portal in pair:
			if portal != null and is_instance_valid(portal):
				out.append(portal)
	return out



func close_owner(owner_id: int) -> void :
	for portal in portals_of(owner_id):
		if portal != null and is_instance_valid(portal):
			_close(portal)
	_pairs.erase(owner_id)
	_next_slot.erase(owner_id)


func close_all() -> void :
	for owner_id in _pairs.keys():
		close_owner(int(owner_id))



func close(portal: Portal) -> void :
	if is_instance_valid(portal):
		_close(portal)


func _close(portal: Portal) -> void :
	for body_id in _passing.keys():
		var entry: Dictionary = _passing[body_id]
		var body: = instance_from_id(int(body_id)) as PhysicsBody3D
		if body == null:
			_passing.erase(body_id)
		elif entry["portal"] == portal:
			_rescue(body, portal)
			_set_owner(body, null, portal)
		else:

			_set_owner(body, entry["portal"], portal)
	if portal.is_linked():
		portal.pair.unlink()
	var pair: Array = _pairs.get(portal.owner_id, [null, null])
	if pair[portal.slot] == portal:
		pair[portal.slot] = null
	portal.burst(self)
	portal.queue_free()




func _rescue(body: PhysicsBody3D, portal: Portal) -> void :
	var center: Vector3 = body.call("center") if body.has_method("center") else body.global_position
	var deepest: = minf(portal.to_local_point(body.global_position).z, portal.to_local_point(center).z)
	if deepest >= 0.0 or not portal.rect_contains(portal.to_local_point(center), 0.6):
		return
	var out: = portal.global_basis.z
	body.global_position += out * ( - deepest + float(_cfg.get("rescue_clearance_m", 0.45)))
	if "velocity" in body:
		var velocity: Vector3 = body.get("velocity")
		if body is Player:
			var world: = (body as Player).gravity_frame * velocity
			world -= out * minf(world.dot(out), 0.0)
			body.set("velocity", (body as Player).gravity_frame.transposed() * world)
		else:
			body.set("velocity", velocity - out * minf(velocity.dot(out), 0.0))



func _overlaps(place: Transform3D, opening: Vector2, replacing: Portal) -> bool:
	for portal in all_portals():
		if portal == replacing or portal.global_basis.z.dot(place.basis.z) < 0.95:
			continue
		var local: = portal.to_local_point(place.origin)
		if absf(local.z) > 0.1:
			continue
		if absf(local.x) < (portal.size.x + opening.x) * 0.5 and absf(local.y) < (portal.size.y + opening.y) * 0.5:
			return true
	return false


func _free_layer(replacing: Portal) -> int:
	var used: = {}
	for portal in all_portals():
		if portal != replacing:
			used[portal.visual_layer] = true
	for layer in range(LAYER_FIRST, LAYER_LAST + 1):
		if not used.has(layer):
			return layer
	return -1








func _placement(point: Vector3, normal: Vector3, up_hint: Vector3, opening: Vector2, shot_from: Vector3) -> Dictionary:
	var space: = get_viewport().find_world_3d().direct_space_state
	var center: = space.intersect_ray(PhysicsRayQueryParameters3D.create(point + normal * 0.3, point - normal * 0.3, 
		PhysicsLayers.WORLD | PhysicsLayers.THINGS))
	if center.is_empty():
		last_reject = "sem superfície"
		return {}
	var center_body: = center["collider"] as CollisionObject3D
	if center_body != null and center_body.is_in_group(NO_PORTAL_GROUP):
		last_reject = "limite da arena"
		return {}
	var surface: = {"normal": normal, "points": [point], "walls": [] as Array[CollisionObject3D]}


	var look: = (shot_from - point).normalized() if shot_from.is_finite() and shot_from.distance_to(point) > 0.01 else normal
	for pass_index in 2:
		var found: = _sample_surface(space, point, surface["normal"], look if pass_index == 0 else surface["normal"], up_hint, opening)
		if (found["points"] as Array).size() >= 3:
			surface = found
	var n: Vector3 = surface["normal"]
	var lift: = 0.0
	var deepest: = 0.0
	for p: Vector3 in surface["points"]:
		lift = maxf(lift, (p - point).dot(n))
		deepest = minf(deepest, (p - point).dot(n))
	var walls: Array[CollisionObject3D] = surface["walls"]
	if center_body != null and not walls.has(center_body):
		walls.append(center_body)

	var depth: = lift - deepest + float(_cfg.get("film_depth_pad_m", 0.3))
	return {"transform": Transform3D(_basis_for(n, up_hint), point + n * lift), "walls": walls, "depth": depth}




func _sample_surface(space: PhysicsDirectSpaceState3D, point: Vector3, normal: Vector3, look: Vector3, up_hint: Vector3, 
		opening: Vector2) -> Dictionary:
	var basis: = _basis_for(normal, up_hint)
	var samples: = maxi(int(_cfg.get("place_samples", 4)), 2)
	var half: = opening * 0.5


	var origin: = point + look * (half.length() + 0.3)
	var normal_sum: = Vector3.ZERO
	var points: Array[Vector3] = []
	var walls: Array[CollisionObject3D] = []
	for i in samples:
		for j in samples:

			var local: = Vector2(lerpf( - half.x, half.x, (i + 0.5) / samples), lerpf( - half.y, half.y, (j + 0.5) / samples))
			var at: = point + basis.x * local.x + basis.y * local.y
			var hit: = space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + (at - origin) * 2.0, 
				PhysicsLayers.WORLD | PhysicsLayers.THINGS))
			if hit.is_empty():
				continue
			var body: = hit["collider"] as CollisionObject3D
			if body != null and body.is_in_group(NO_PORTAL_GROUP):
				continue
			var hit_normal: Vector3 = hit["normal"]
			if hit_normal.dot(origin - (hit["position"] as Vector3)) <= 0.0:
				continue
			normal_sum += hit_normal
			points.append(hit["position"])
			if body != null and not walls.has(body):
				walls.append(body)
	var mean: = normal_sum.normalized() if normal_sum.length() > 0.01 else normal
	return {"normal": mean, "points": points, "walls": walls}



static func _basis_for(normal: Vector3, up_hint: Vector3) -> Basis:
	var up: = up_hint - normal * up_hint.dot(normal)
	if up.length() < 0.05:

		up = Vector3.FORWARD - normal * Vector3.FORWARD.dot(normal)
		if up.length() < 0.05:
			up = Vector3.RIGHT - normal * Vector3.RIGHT.dot(normal)
	up = up.normalized()
	return Basis(up.cross(normal).normalized(), up, normal)







func update_passage(body: PhysicsBody3D, center: Vector3, reach: float = 0.0) -> void :
	var front: = float(_cfg.get("own_front_m", 1.5)) + reach
	var back: = float(_cfg.get("tunnel_depth_m", 2.5))
	var margin: = float(_cfg.get("own_margin_m", 1.0))
	var current: Variant = (_passing.get(body.get_instance_id(), {}) as Dictionary).get("portal")
	var best: Portal = null
	var best_score: = INF
	for portal in all_portals():
		if not portal.is_linked():
			continue
		var local: = portal.to_local_point(center)
		if local.z > front or local.z < - back or not portal.rect_contains(local, margin):
			continue

		if portal != current and local.z < -0.1:
			continue

		var score: = -1.0 if portal == current else absf(local.z)
		if score < best_score:
			best_score = score
			best = portal

	if best == null and current != null and is_instance_valid(current):
		_rescue(body, current)
	_set_owner(body, best)





func _set_owner(body: PhysicsBody3D, portal: Portal, closing: Portal = null) -> void :
	var key: = body.get_instance_id()
	var had: Array = (_passing.get(key, {}) as Dictionary).get("ignored", [])
	var want: Array = []
	if portal != null:
		for world_body in portal.environment.bodies:
			if is_instance_valid(world_body):
				want.append(world_body)
		for other in all_portals():
			if other != portal and other != closing:
				want.append(other.environment)
	for ignored in had:
		if is_instance_valid(ignored) and not want.has(ignored):
			body.remove_collision_exception_with(ignored)
	for ignored in want:
		if not had.has(ignored):
			body.add_collision_exception_with(ignored)
	if portal == null:
		body.collision_mask &= ~ PhysicsLayers.PORTAL_TUNNEL
		_passing.erase(key)
	else:
		body.collision_mask |= PhysicsLayers.PORTAL_TUNNEL
		_passing[key] = {"portal": portal, "ignored": want}
	_set_clone(body, portal)



func _set_clone(body: Node3D, portal: Portal) -> void :
	var key: = body.get_instance_id()
	var clone: = _clones.get(key) as PortalClone
	if clone != null and is_instance_valid(clone) and clone.portal == portal:
		return
	if clone != null and is_instance_valid(clone):
		clone.queue_free()
	_clones.erase(key)
	if portal == null or not portal.is_linked():
		return
	clone = PortalClone.new()
	add_child(clone)
	clone.setup(body, portal)
	_clones[key] = clone





func crossed(from: Vector3, to: Vector3) -> Portal:
	var margin: = float(_cfg.get("edge_margin_m", 0.02))
	var ahead: = float(_cfg.get("cross_ahead_m", 0.006))
	for portal in all_portals():
		if not portal.is_linked():
			continue
		var a: = portal.to_local_point(from) - Vector3(0, 0, ahead)
		var b: = portal.to_local_point(to) - Vector3(0, 0, ahead)
		if a.z < 0.0 or b.z >= 0.0:
			continue
		var t: = a.z / (a.z - b.z)
		if portal.opening_contains(a.lerp(b, t), margin):
			return portal
	return null




func through(from: Vector3, to: Vector3) -> Dictionary:
	for portal in all_portals():
		if not portal.is_linked():
			continue
		var a: = portal.to_local_point(from)
		var b: = portal.to_local_point(to)
		if a.z < 0.0 or b.z >= 0.0:
			continue
		var at: = a.lerp(b, a.z / (a.z - b.z))
		if portal.rect_contains(at):
			return {"portal": portal, "point": portal.global_transform * at}
	return {}




func traverse_player(player: Player, eye_before: Vector3) -> bool:
	var eye_after: = player.camera.global_position
	var portal: = crossed(eye_before, eye_after)
	if portal == null:
		return false
	var t: = portal.transfer()
	var eye_height: = (eye_after - player.global_position).dot(player.up())
	var look_world: = player.gravity_frame * (Basis(Vector3.UP, player.view_yaw) * Basis(Vector3.RIGHT, player.head.rotation.x) * Vector3.FORWARD)
	var velocity_world: = player.gravity_frame * player.velocity
	var new_eye: = t * eye_after


	if Gravity.active():
		player.gravity_frame = (t.basis * player.gravity_frame).orthonormalized()
		player.up_direction = player.gravity_frame.y
	player.global_position = new_eye - player.up() * eye_height
	player.velocity = player.gravity_frame.transposed() * (t.basis * velocity_world)
	player._aim_world(t.basis * look_world)


	var exit_normal: = portal.pair.global_basis.z
	if exit_normal.dot(player.up()) > float(_cfg.get("floor_exit_dot", 0.7071)):
		var world_velocity: = player.gravity_frame * player.velocity
		world_velocity += exit_normal * maxf(0.0, float(_cfg.get("floor_exit_min_ms", 5.5)) - world_velocity.dot(exit_normal))
		player.velocity = player.gravity_frame.transposed() * world_velocity


	_set_owner(player, portal.pair)
	_settle(player, exit_normal)
	SoundBank.play_at(self, "portal/pass", player.global_position)
	if player.robot != null:
		player.robot.ik.reset()
	_render_eye.erase(player.get_instance_id())
	return true






func _settle(player: Player, exit_normal: Vector3) -> void :
	if _fits(player, player.global_position):
		return
	var up: = player.up()
	var forward: = (exit_normal - up * exit_normal.dot(up))
	forward = forward.normalized() if forward.length() > 0.05 else Vector3.ZERO
	var step: = float(_cfg.get("settle_step_m", 0.08))
	var reach: = float(_cfg.get("settle_reach_m", 1.6))
	var away: = float(_cfg.get("settle_away_m", 0.6)) if forward != Vector3.ZERO else 0.0

	var offsets: Array[Vector2] = []
	var rise: = 0.0
	while rise <= reach + 0.001:
		var ahead: = 0.0
		while ahead <= away + 0.001:
			if rise > 0.0 or ahead > 0.0:
				offsets.append(Vector2(rise, ahead))
			ahead += 0.15
		rise += step
	offsets.sort_custom( func(a: Vector2, b: Vector2) -> bool: return a.length_squared() < b.length_squared())
	for offset in offsets:
		var at: = player.global_position + up * offset.x + forward * offset.y
		if _fits(player, at):
			at += up * 0.03
			var moved: = at - player.global_position
			player.global_position = at
			player.eye_offset -= player.head.global_basis.inverse() * moved
			return





func _fits(player: Player, feet: Vector3) -> bool:
	var holder: = player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if holder == null or holder.shape == null:
		return true
	var eye: = player.camera.global_position + (feet - player.global_position)
	var ray: = PhysicsRayQueryParameters3D.create(eye, feet + player.up() * 0.05, 
		player.collision_mask & (PhysicsLayers.WORLD | PhysicsLayers.THINGS | PhysicsLayers.PORTAL_TUNNEL))
	ray.hit_back_faces = true
	var query: = PhysicsShapeQueryParameters3D.new()
	query.shape = holder.shape

	query.transform = Transform3D(holder.global_basis, feet + player.up() * 0.03 + (holder.global_position - player.global_position))
	query.collision_mask = player.collision_mask & (PhysicsLayers.WORLD | PhysicsLayers.THINGS | PhysicsLayers.PORTAL_TUNNEL)
	var exclude: Array[RID] = [player.get_rid()]
	for ignored: Variant in (_passing.get(player.get_instance_id(), {}) as Dictionary).get("ignored", []):
		if is_instance_valid(ignored):
			exclude.append((ignored as CollisionObject3D).get_rid())
	query.exclude = exclude
	query.margin = 0.01
	ray.exclude = exclude
	var space: = player.get_world_3d().direct_space_state
	return space.intersect_ray(ray).is_empty() and space.intersect_shape(query, 1).is_empty()




func traverse_thing(thing: Thing, before: Vector3) -> bool:
	var portal: = crossed(before, thing.global_position)
	if portal == null:
		return false
	var t: = portal.transfer()
	thing.global_transform = Transform3D((t.basis * thing.global_basis).orthonormalized(), t * thing.global_position)
	thing.velocity = t.basis * thing.velocity
	if thing.move != null:
		thing.move.portal_turned(t.basis)
	_set_owner(thing, portal.pair)
	return true




func _traverse_rendered_eye(eye: Camera3D) -> void :
	var player: = eye.get_parent().get_parent() as Player if eye.get_parent() != null else null
	if player == null or player.camera != eye:
		return
	var key: = player.get_instance_id()
	var before: Variant = _render_eye.get(key)
	if before != null and _passing.has(key):
		traverse_player(player, before)
	_render_eye[key] = eye.global_position




func _process(_delta: float) -> void :
	var eye: = get_viewport().get_camera_3d()
	if eye == null:
		return
	_traverse_rendered_eye(eye)
	for portal in all_portals():
		portal.animate(_delta)
	for child in get_children():
		if child is PortalBlocks:
			(child as PortalBlocks).advance(_delta)
	for key: int in _clones.keys():
		var clone: = _clones[key] as PortalClone
		if clone == null or not is_instance_valid(clone) or not is_instance_valid(clone.body):
			if clone != null and is_instance_valid(clone):
				clone.queue_free()
			_clones.erase(key)
		else:
			clone.follow()
	var screen: = get_viewport().get_visible_rect().size
	var main: = get_viewport()
	var pixel_scale: = (Vector2(main.get_texture().get_size()).y / maxf(screen.y, 1.0)) if main.get_texture() != null else 1.0
	var near_zone: = float(_cfg.get("near_zone_m", 0.4))
	var want_near: = INF
	for portal in all_portals():
		portal.update_view(eye, screen, _cfg, pixel_scale)
		portal.match_quality(main)

		if portal.is_linked():
			var local: = portal.to_local_point(eye.global_position)
			if local.z > 0.0 and local.z < near_zone and portal.rect_contains(local, 0.1):
				want_near = minf(want_near, local.z * 0.5)
	var key: = eye.get_instance_id()
	if not _base_near.has(key):
		_base_near[key] = eye.near
	var base: = float(_base_near[key])
	eye.near = clampf(want_near, float(_cfg.get("near_min_m", 0.003)), base) if want_near < INF else base
