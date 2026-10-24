class_name GroundItems
extends RefCounted

static func target(player: Player) -> Thing:
	if player == null or not player.is_inside_tree(): return null
	var aim := player.aim()
	var query := PhysicsRayQueryParameters3D.create(aim.origin, aim.origin + aim.direction * 4.0, PhysicsLayers.SOLID | PhysicsLayers.PROJECTILES)
	var exclusions: Array[RID] = [player.get_rid()]
	for i in player.hands.slot_count():
		var held := player.hands.item_at(i)
		if held != null:
			exclusions.append(held.get_rid())
			for graft in held.grafts:
				if is_instance_valid(graft): exclusions.append(graft.get_rid())
	query.exclude = exclusions
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return null
	var item: Variant = hit.collider
	while is_instance_valid(item) and item is Thing and is_instance_valid(item.mount_host): item = item.mount_host
	return item as Thing if is_instance_valid(item) and item is Thing and can_pickup(player, item) else null

static func can_pickup(player: Player, item: Thing) -> bool:
	if not is_instance_valid(item) or item.is_dead or item.is_held or item.is_captured or item.is_building or not item.ground_item: return false
	if not is_instance_valid(player) or not player.can_act() or player.piloting != null or player.extracting or player.shaper.active: return false
	if item.velocity.length() > 2.0 or Time.get_ticks_msec() < item.pickup_after_ms: return false
	var at := item.center()
	if player.center().distance_to(at) > 4.0: return false
	var query := PhysicsRayQueryParameters3D.create(player.head.global_position, at, PhysicsLayers.WORLD)
	return player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

static func drop(item: Thing, at: Vector3, velocity: Vector3) -> void:
	Forge.world.add_thing(item)
	item.set_held(false)
	item.ground_item = true
	item.pickup_after_ms = Time.get_ticks_msec() + 500
	item.lifetime = 0.0
	item.age = 0.0
	item.is_anchored = false
	item.visible = true
	item.global_position = at
	item.velocity = velocity
	if item.move != null: item.move.landed = false
	Hands._set_layers(item, 1)
	if item.owner_player is PhysicsBody3D: item.add_collision_exception_with(item.owner_player)
	if item.get_node_or_null("GroundMotion") == null:
		var motion = load("res://scripts/things/ground_motion.gd").new()
		motion.name = "GroundMotion"
		motion.thing = item
		item.add_child(motion)
	Forge._register(item)
	if Session.is_online(): Session.creations.publish_creation(item, 0.0, false, item.matter)
