extends ThingAction


func run(ctx: ActionContext) -> void :
	if not thing.has_simulation_authority():
		return
	if thing.explosion_spent or arg().is_empty():
		return
	thing.explosion_spent = true
	var at: = thing.center()
	Combat.explode(thing, at, thing.explosion_radius, thing.explosion_damage)
	var spacing: = Lexicon.balf("actions.spawn.side_spacing")
	var up: = thing.up()
	var ahead: = Gravity.flat(ctx.direction, up).normalized()
	if ahead.length_squared() < 0.001:
		ahead = Gravity.frame_for(up) * Vector3.FORWARD
	for i in arg_count():
		var spot: = at + ahead.cross(up) * (i - (arg_count() - 1) * 0.5) * spacing
		Forge.spawn_child(arg(), "spawned", spot, ahead, thing, 0.0)
	thing.die()
