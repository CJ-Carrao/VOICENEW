class_name ThingAction
extends Node




var thing: Thing

var spec: Dictionary = {}
var production_pending := false


func setup(owner_thing: Thing, action_spec: Dictionary) -> void :
	thing = owner_thing
	spec = action_spec


func run(_ctx: ActionContext) -> void :
	pass


func wait_for_production(node: Dictionary) -> bool:
	if not is_instance_valid(thing) or Status.paralyzed(thing): return false
	if not ProductionBudget.complex(node, Lexicon.data): return true
	while not Forge.production.available(thing.owner_id, Forge.live_things(thing.owner_id).size()):
		if not production_pending: Forge.stats.production_paused += 1
		production_pending = true
		await get_tree().process_frame
		if not is_instance_valid(thing) or thing.is_dead or not thing.has_simulation_authority(): return false
		if Status.paralyzed(thing):
			production_pending = false
			return false
	production_pending = false
	return true



func arg() -> Dictionary:
	var value: Variant = spec.get("arg")
	return value if value is Dictionary else {}



func arg_count() -> int:
	return maxi(1, int((arg().get("mods", {}) as Dictionary).get("count", 1)))
