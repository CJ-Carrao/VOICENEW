extends Node

var thing: Thing
var config: Dictionary = {}
var diet := ""
var clock := 0.0
var next_production := 2.0
var next_bite := 0.0
var queen_ref: WeakRef


func setup(owner_thing: Thing, settings: Dictionary, diet_id: String) -> void:
	thing = owner_thing
	config = settings
	diet = diet_id
	process_physics_priority = -20


func _physics_process(delta: float) -> void:
	if not is_instance_valid(thing) or not thing.can_act():
		return
	clock += delta
	if not diet.is_empty():
		_hunt()
	if not config.is_empty() and clock >= next_production:
		next_production = clock + maxf(float(config.get("interval", 5.0)), 2.5)
		_produce()


func _living_queen() -> bool:
	if not bool(config.get("needs_queen", false)):
		return true
	if queen_ref != null:
		var queen = queen_ref.get_ref()
		return is_instance_valid(queen) and not queen.is_dead and not queen.is_captured and queen.team == thing.team
	if is_instance_valid(thing.spawner) and thing.spawner is Thing and InnovationRules.tags(thing.spawner).has("queen"):
		queen_ref = weakref(thing.spawner)
		return not thing.spawner.is_dead and not thing.spawner.is_captured and thing.spawner.team == thing.team
	if Forge.world != null:
		for candidate in Forge.world.get_node("Things").get_children():
			var queen := candidate as Thing
			if queen != null and not queen.is_dead and not queen.is_captured and queen.team == thing.team and InnovationRules.tags(queen).has(String(config.get("queen_tag", "ant_queen"))) and queen.center().distance_to(thing.center()) < 12.0:
				queen_ref = weakref(queen)
				return true
	return false


func _produce() -> void:
	if not _living_queen():
		return
	var child_id := String(config.get("produces", ""))
	if child_id.is_empty():
		return
	var ahead := Gravity.flat(-thing.global_basis.z, thing.up()).normalized()
	var spot := Forge.ground_point(thing.global_position + ahead * (maxf(thing.bounds.size.x, thing.bounds.size.z) * 0.5 + 1.0), thing.up())
	var child := Forge.spawn_child(Recipe.new_node(child_id), "spawned", spot, ahead, thing, 0.0)
	if child != null:
		child.lifetime = 0.0


func _hunt() -> void:
	var orders := thing.get_node_or_null("AnimalOrders")
	if orders != null and orders.active(): return
	if Forge.world == null or thing.move == null:
		return
	thing.move.steering = true
	var prey := Combat.nearest_target(thing, thing.center(), get_tree()) as Thing
	var up := thing.up()
	var airborne := thing.move.hovers()
	if prey == null:
		thing.velocity = Vector3.ZERO if airborne else up * thing.velocity.dot(up)
		return
	var direction := prey.center() - thing.center()
	if airborne:
		thing.velocity = direction.normalized() * maxf(thing.speed, 0.6) if direction.length() > 0.65 else Vector3.ZERO
	else:
		direction = Gravity.flat(direction, up)
		thing.velocity = direction.normalized() * maxf(thing.speed, 0.6) + up * thing.velocity.dot(up) if direction.length() > 0.65 else up * thing.velocity.dot(up)
	if direction.length_squared() > 0.01: thing.face(direction, true)
	var own_box: AABB = thing.global_transform * thing.bounds
	var prey_box: AABB = prey.global_transform * prey.bounds
	var gap := (prey_box.position - own_box.end).max(own_box.position - prey_box.end).max(Vector3.ZERO).length()
	var reach := clampf(thing.scale_factor * 0.65, 0.4, 2.0)
	if gap <= reach and clock >= next_bite:
		var query := PhysicsRayQueryParameters3D.create(thing.center(), prey.center(), PhysicsLayers.WORLD)
		if not thing.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): return
		next_bite = clock + 0.7
		# Diet is an explicit ecological relationship, including prey of the same team.
		Combat.apply_damage(prey, maxf(7.0, thing.impact_damage * 2.0), "bite", thing)
		ExpansionFx.burst(Forge.fx_root(thing), prey.center(), 0.25, Color("d6b982"), "bite")
