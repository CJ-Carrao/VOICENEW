class_name ActionStrike
extends ThingAction









const TARGET_RADIUS: = 0.45

const POINT_BLANK: = 0.6
const TRAIL_COLOR: = Color(0.92, 0.95, 1.0)

const PROJECTILE_VERTICAL_DEG: = 85.0


func run(ctx: ActionContext) -> void :
	if not thing.has_simulation_authority():
		return
	var cfg: = "actions.strike."
	if thing.is_held and not thing.automatic:
		await get_tree().create_timer(Lexicon.balf(cfg + "windup_s"), false).timeout
		var holder: = thing.owner_player as Player if is_instance_valid(thing) else null
		if not is_instance_valid(thing) or thing.is_dead or not thing.is_held or not thing.has_simulation_authority()\
		or (holder != null and ( not holder.can_act() or holder.hands.current_item() != thing)):
			return
	if not thing.is_inside_tree():
		return
	var origin: = _origin()
	var direction: = _direction(ctx, origin)
	var reach: = thing.strike_reach()
	if not thing.is_held:
		reach = maxf(reach, Lexicon.balf(cfg + "reach_free") * thing.scale_factor)
	var heavy: = clampf(ctx.charge, 0.0, 1.0)
	var blades: = ctx.shots if ctx.shots > 0 else thing.barrels
	var damage: = Lexicon.balf(cfg + "damage") * thing.power * maxi(blades, 1) * lerpf(1.0, Lexicon.balf(cfg + "heavy_mult"), heavy)
	var push: = Lexicon.balf(cfg + "knockback") * thing.knockback\
	* lerpf(1.0, Lexicon.balf(cfg + "heavy_knockback_mult"), heavy)
	var fx_root: = Forge.fx_root(thing)
	Fx.slash(fx_root, origin, direction, reach, thing.strike_arc, thing.strike_style, _trail_color(), thing.is_held)
	var cuts: = bool(Lexicon.bal(cfg + "cuts_projectiles", true))
	for target in Combat.in_radius(thing, origin, reach + TARGET_RADIUS):
		if target == thing.owner_player or not Combat.affects(thing, target):
			continue
		var to: = Combat.center_of(target) - origin
		var projectile: = target as Thing
		var is_projectile: = projectile != null and projectile.role == "projectile"
		if not _in_arc(direction, to, reach, PROJECTILE_VERTICAL_DEG if is_projectile else Lexicon.balf(cfg + "vertical_deg")):
			continue
		if is_projectile:
			if cuts:
				Fx.muzzle_flash(fx_root, projectile.global_position, - to.normalized(), 0.25, false)
				projectile.remove()
			continue
		if _blocked(origin, target):
			continue
		var at: = Combat.center_of(target)
		Combat.apply_damage(target, damage, "melee", thing)
		thing.impact_feedback(at)
		thing.hit.emit(ActionContext.make(at, to.normalized(), target))
		Fx.muzzle_flash(fx_root, at - to.normalized() * TARGET_RADIUS, - to.normalized(), 0.3, false)
		_knock(target, to, push)
	_strike_world(origin, direction, reach, damage)



func _strike_world(origin: Vector3, direction: Vector3, reach: float, damage: float) -> void :
	var exclude: Array[RID] = [thing.get_rid()]
	if thing.owner_player is CollisionObject3D:
		exclude.append((thing.owner_player as CollisionObject3D).get_rid())
	var query: = PhysicsRayQueryParameters3D.create(origin, origin + direction * reach, PhysicsLayers.WORLD, exclude)
	var hit: = thing.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		Combat.hit_structure(hit["collider"], hit["position"], int(hit["shape"]), damage, "strike")
		thing.impact_feedback(hit["position"])



func _origin() -> Vector3:
	var holder: = thing.owner_player as Player
	if thing.is_held and holder != null:

		return holder.head.global_position
	return thing.center()


func _direction(ctx: ActionContext, origin: Vector3) -> Vector3:
	var holder: = thing.owner_player as Player
	if thing.is_held and holder != null:
		return - holder.camera.global_basis.z
	var target: = ctx.target if ctx.target != null else Combat.nearest_enemy(origin, thing.team, get_tree())
	if target != null:
		var to: = Combat.center_of(target) - origin
		if to.length_squared() > 0.0001:
			thing.face(to, true)
			return to.normalized()
	return ctx.direction if ctx.direction.length_squared() > 0.0 else - thing.global_basis.z



func _in_arc(direction: Vector3, to: Vector3, reach: float, vertical_deg: float) -> bool:
	var distance: = to.length()
	if distance > reach + TARGET_RADIUS:
		return false
	if distance < POINT_BLANK:
		return true
	var flat_dir: = Vector2(direction.x, direction.z)
	var flat_to: = Vector2(to.x, to.z)
	if flat_to.length() > 0.2 and flat_dir.length() > 0.01:
		if rad_to_deg(absf(flat_dir.angle_to(flat_to))) > thing.strike_arc * 0.5:
			return false
	var pitch_dir: = atan2(direction.y, Vector2(direction.x, direction.z).length())
	var pitch_to: = atan2(to.y, flat_to.length())
	return rad_to_deg(absf(pitch_to - pitch_dir)) <= vertical_deg



func _blocked(origin: Vector3, target: Node3D) -> bool:
	var exclude: Array[RID] = [thing.get_rid()]
	if thing.owner_player is CollisionObject3D:
		exclude.append((thing.owner_player as CollisionObject3D).get_rid())
	if target is CollisionObject3D:
		exclude.append((target as CollisionObject3D).get_rid())
	var query: = PhysicsRayQueryParameters3D.create(origin, Combat.center_of(target), PhysicsLayers.WORLD | PhysicsLayers.THINGS, 
		exclude)
	return not thing.get_world_3d().direct_space_state.intersect_ray(query).is_empty()



func _trail_color() -> Color:
	if thing.element.is_empty():
		return TRAIL_COLOR
	var entry: Dictionary = Lexicon.data.elements.get(thing.element, {})
	return Color.from_string(String(entry.get("tint", entry.get("explosion", "#ffffff"))), TRAIL_COLOR)


func _knock(target: Node3D, to: Vector3, strength: float) -> void :
	var up: = Gravity.up_at(target.global_position, thing.up())
	var flat: = Gravity.flat(to, up)
	var dir: = flat.normalized() if flat.length_squared() > 0.0001 else - thing.global_basis.z
	var impulse: = (dir + up * Lexicon.balf("actions.strike.lift")).normalized() * strength
	if target.has_method("apply_knockback"):
		target.call("apply_knockback", impulse)
	elif target is Thing:
		(target as Thing).nudge(impulse)
