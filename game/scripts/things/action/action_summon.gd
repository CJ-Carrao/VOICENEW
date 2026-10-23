class_name ActionSummon
extends ThingAction





func run(ctx: ActionContext) -> void :
	if not thing.has_simulation_authority():
		return
	var node: = arg()
	if node.is_empty():
		return
	var up: = Gravity.up_at(ctx.point, thing.up())
	var forward: = Gravity.flat(ctx.direction, up)
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Gravity.frame_for(up) * Vector3.FORWARD
	var across: = forward.cross(up)
	var spacing: = Lexicon.balf("actions.spawn.side_spacing") * 2.0
	var count: = arg_count()
	for i in count:
		var target: = Forge.ground_point(ctx.point + forward * (i - (count - 1) * 0.5) * spacing)
		Forge.summon_child(node, target, across, thing)
