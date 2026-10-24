extends ThingAction

var started := false

func run(_ctx: ActionContext) -> void:
	if started or not thing.has_simulation_authority() or thing.is_dead or thing.is_held: return
	var species := String(thing.node_data.get("mods", {}).get("target_species", ""))
	if species.is_empty(): return
	started = true
	thing.explosion_spent = true
	var victims := []
	for candidate in Forge.world.get_node("Things").get_children():
		var animal := candidate as Thing
		if animal != null and not animal.is_dead and animal.category == "creature" and animal.thing_id == species:
			victims.append(weakref(animal))
	ExpansionFx.burst(Forge.fx_root(thing), thing.center(), 5.0, Color("b7e87e"), "species")
	# One global pulse, with bounded cleanup instead of hundreds of death explosions/rubble piles.
	for i in victims.size():
		var animal = victims[i].get_ref()
		if is_instance_valid(animal) and not animal.is_dead:
			animal.hp = 0.0
			animal.remove()
		if i % 3 == 2: await get_tree().process_frame
	if is_instance_valid(thing) and not thing.is_dead: thing.remove()
