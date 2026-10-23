class_name TriggerOnDeath
extends ThingTrigger




func activate() -> void :
	thing.died.connect(_on_died)


func _on_died(ctx: ActionContext) -> void :
	if action != null and thing.has_simulation_authority():
		action.run(ctx)
