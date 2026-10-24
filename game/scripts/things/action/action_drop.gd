class_name ActionDrop
extends ThingAction




func run(_ctx: ActionContext) -> void :
	if not thing.has_simulation_authority():
		return
	var node: = arg()
	if node.is_empty():
		return
	var below: = thing.bounds.size.y * 0.5 + Lexicon.balf("actions.drop.below_offset")
	var up: = thing.up()
	var origin: = thing.center() - up * below
	var inherit: = thing.velocity * Lexicon.balf("actions.drop.inherit_velocity")
	var count: = arg_count()
	var spacing: = Lexicon.balf("actions.drop.side_spacing")
	for i in count:
		if not await wait_for_production(node): return
		var side: = Gravity.frame_for(up).x * (i - (count - 1) * 0.5) * spacing
		Forge.spawn_child(node, "projectile", origin + side, - up, thing, 0.0, inherit)
