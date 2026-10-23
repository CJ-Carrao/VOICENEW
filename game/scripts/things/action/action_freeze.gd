class_name ActionFreeze
extends ThingAction



const STATUS: = "frozen"


func run(ctx: ActionContext) -> void :
	if not thing.has_simulation_authority():
		return
	if spec.get("contact", false):
		if ctx.target != null and ctx.target.has_method("take_damage") and Combat.affects(thing, ctx.target):
			Status.apply(ctx.target, status_id(), thing)
		return
	Combat.area_status(thing, ctx.point, Lexicon.balf("actions.%s.radius" % type_id()) * thing.scale_factor, status_id())


func type_id() -> String:
	return "freeze"


func status_id() -> String:
	return STATUS
