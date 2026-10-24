class_name ActionShoot
extends ThingAction









func run(ctx: ActionContext) -> void :
	if not thing.has_simulation_authority():
		return
	var node: = _ammo(arg())
	if node.is_empty():
		return
	var carried: Dictionary = thing.mechanics.get("ammo_mods", {})
	if not carried.is_empty():
		node = node.duplicate(true)
		(node.get_or_add("mods", {}) as Dictionary).merge(carried, true)
	var target: Node3D = null
	if spec.get("aim") == "enemy" or (thing.auto_aim and not thing.is_held):
		target = ctx.target if is_instance_valid(ctx.target) and InnovationRules.allows_target(thing, ctx.target) else Combat.nearest_target(thing, thing.center(), get_tree())
		if target == null:
			return
		if not thing.is_held:

			thing.face(Combat.center_of(target) - thing.global_position, true)

	var barrels: = ctx.shots if ctx.shots >= 0 else thing.barrels
	var pellets: = maxi(1, int((node.get("mods", {}) as Dictionary).get("count", 1)))
	var original_pellets: = pellets
	pellets = maxi(pellets, thing.shot_pellets_min)
	var fan: = minf(Lexicon.balf("actions.shoot.fan_step_deg") * (barrels - 1), Lexicon.balf("actions.shoot.fan_max_deg"))
	var muzzles: = thing.muzzle_points()
	var drift: = _drift()



	var weapon_up: = thing.global_basis.y.normalized()
	var reach: = 0.0
	for point: Vector3 in muzzles:
		reach = maxf(reach, absf((thing.global_transform.affine_inverse() * point).x))
	for b in barrels:
		var origin: Vector3 = muzzles[(ctx.barrel if ctx.barrel >= 0 else b) % muzzles.size()]
		var base_dir: = ctx.direction
		if target != null:
			base_dir = (Combat.center_of(target) - origin).normalized()
		var yaw: = 0.0
		if barrels > 1:
			var across: = (thing.global_transform.affine_inverse() * origin).x / reach if reach > 0.0001 else -1.0 + 2.0 * float(b) / float(barrels - 1)
			yaw = deg_to_rad( - fan * 0.5 * across)
		base_dir = _deviate(base_dir.rotated(weapon_up, yaw), drift)
		if thing.muzzle_flash and thing.is_inside_tree():
			Fx.muzzle_flash(Forge.fx_root(thing), origin, base_dir, Lexicon.balf("attachments_fx.flash_size") * sqrt(thing.power), 
				thing.is_held)
		for p in pellets:
			if not await wait_for_production(node): return
			var child: = Forge.spawn_child(node, "projectile", origin, _cone(base_dir, p, pellets), thing, -1.0, 
				Vector3.ZERO, false, thing.shot_speed_mult)
			if child != null:
				if thing.shot_lifetime_s > 0.0:
					child.lifetime = minf(child.lifetime, thing.shot_lifetime_s)
				child.impact_damage *= thing.power * float(original_pellets) / float(pellets)
				child.explosion_damage *= thing.power * float(original_pellets) / float(pellets)



func _ammo(base: Dictionary) -> Dictionary:
	var special: = thing.ammo_override
	if special.is_empty() or base.is_empty():
		return base
	var node: Dictionary = base.duplicate(true) if not special.has("thing") else special.duplicate(true)
	node.erase("_mods")
	if not node.has("mods"):
		node["mods"] = {}
	if not node.has("behaviors"):
		node["behaviors"] = []
	if not node.has("control"):
		node["control"] = "none"
	if not node.has("movement"):
		node["movement"] = null
	var carried: Dictionary = special.get("_mods", {})
	for key: String in carried:
		if key == "_movement":
			node["movement"] = carried[key]
		elif key == "speed":
			(node["mods"] as Dictionary)["speed"] = float((node["mods"] as Dictionary).get("speed", 1.0)) * float(carried[key])
		else:
			(node["mods"] as Dictionary)[key] = carried[key]
	return node




func _drift() -> Vector2:
	if not thing.is_held or thing.inaccuracy_deg <= 0.0:
		return Vector2.ZERO
	var amount: = thing.inaccuracy_deg
	var holder: = thing.owner_player as Player
	if holder != null and holder.aiming:
		amount *= thing.ads_inaccuracy

	var k: = float(maxi(thing.shots_fired - 1, 0))
	var radius: = amount * sqrt(fposmod(k * 0.618034, 1.0))
	return Vector2(cos(k * 2.399963), sin(k * 2.399963)) * radius


func _deviate(direction: Vector3, drift: Vector2) -> Vector3:
	if drift == Vector2.ZERO:
		return direction
	var side: = direction.cross(thing.global_basis.y)
	side = side.normalized() if side.length_squared() > 0.0001 else thing.global_basis.x.normalized()
	var up: = side.cross(direction).normalized()
	return (direction + (side * tan(deg_to_rad(drift.x)) + up * tan(deg_to_rad(drift.y)))).normalized()




func _cone(direction: Vector3, index: int, count: int) -> Vector3:
	if count <= 1 or index == 0:
		return direction
	var side: = direction.cross(thing.global_basis.y)
	side = side.normalized() if side.length_squared() > 0.0001 else thing.global_basis.x.normalized()
	var up: = side.cross(direction).normalized()
	var around: = TAU * float(index - 1) / float(count - 1)
	var tilt: = deg_to_rad(thing.spread_deg * 0.5)
	var offset: = (side * cos(around) + up * sin(around)) * tan(tilt)
	return (direction + offset).normalized()
