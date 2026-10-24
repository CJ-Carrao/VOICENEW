extends ThingAction

func run(ctx: ActionContext) -> void:
	var user = thing.get_node_or_null("Jujutsu")
	if user != null and thing.has_simulation_authority(): user.cast(ctx)
