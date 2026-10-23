class_name ThingTrigger
extends Node



var thing: Thing
var params: Dictionary = {}
var action: ThingAction


func setup(owner_thing: Thing, trigger_params: Dictionary, linked_action: ThingAction) -> void :
	thing = owner_thing
	params = trigger_params
	action = linked_action



func activate() -> void :
	pass


func fire(ctx: ActionContext) -> void :
	if action != null and is_instance_valid(thing) and thing.can_act():
		action.run(ctx)


func param(key: String, fallback: float) -> float:
	return float(params.get(key, fallback))
