class_name ActionPortal
extends ThingAction






func reset_for(weapon: Thing) -> void :
	var system: = PortalSystem.find(weapon.get_tree())
	if system != null:
		system.close_owner(weapon.owner_id)


func run(ctx: ActionContext) -> void :
	if not thing.has_simulation_authority():
		return
	var system: = PortalSystem.of(thing.get_tree())
	if system == null:
		return
	var direction: = ctx.direction.normalized()

	var up: = Gravity.up_at(ctx.point)
	if absf(up.dot(ctx.normal)) > 0.9:
		up = direction
	system.open_next(thing.owner_id, ctx.point, ctx.normal, up, thing.scale_factor, ctx.point - direction * 2.0)
