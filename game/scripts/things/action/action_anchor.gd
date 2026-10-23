class_name ActionAnchor
extends ThingAction




func run(ctx: ActionContext) -> void :
	if not thing.has_simulation_authority():
		return
	if thing.is_anchored:
		return
	var facing: = thing.velocity if thing.velocity.length_squared() > 0.01 else - thing.global_basis.z
	thing.anchor_at(Forge.ground_point(ctx.point, thing.up()), facing)
