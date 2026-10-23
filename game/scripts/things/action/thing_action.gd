class_name ThingAction
extends Node




var thing: Thing

var spec: Dictionary = {}


func setup(owner_thing: Thing, action_spec: Dictionary) -> void :
	thing = owner_thing
	spec = action_spec


func run(_ctx: ActionContext) -> void :
	pass



func arg() -> Dictionary:
	var value: Variant = spec.get("arg")
	return value if value is Dictionary else {}



func arg_count() -> int:
	return maxi(1, int((arg().get("mods", {}) as Dictionary).get("count", 1)))
