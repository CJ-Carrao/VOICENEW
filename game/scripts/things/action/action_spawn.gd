class_name ActionSpawn
extends ThingAction



func run(ctx: ActionContext) -> void :
	if not thing.has_simulation_authority():
		return
	var node: = arg()
	if node.is_empty():
		return
	var up: = Gravity.up_at(ctx.point, thing.up())
	var ahead: = Gravity.flat(ctx.direction, up)
	ahead = ahead.normalized() if ahead.length_squared() > 0.0001 else - thing.global_basis.z
	var distance: = maxf(thing.bounds.size.x, thing.bounds.size.z) * 0.5 + Lexicon.balf("actions.spawn.ahead_gap")
	var spacing: = Lexicon.balf("actions.spawn.side_spacing")
	var count: = arg_count()
	for i in count:
		if not await wait_for_production(node): return
		var side: = ahead.cross(up) * (i - (count - 1) * 0.5) * spacing
		var spot: = Forge.ground_point(ctx.point + ahead * distance + side)
		var child: = Forge.spawn_child(node, "spawned", spot, ahead, thing, 0.0)
		if child != null:
			child.face(ahead, true)
