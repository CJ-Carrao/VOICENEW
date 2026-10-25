class_name ThingNetworkState
extends RefCounted


const VALUES: = ["hp", "ammo", "capacity", "magazine", "charges", "reload_left", "loading", 
	"shots_fired", "mechanical_failures", "explosion_spent", "spin_speed", "is_active", "is_anchored"]


static func capture(thing: Thing) -> Dictionary:
	var state: = {}
	for key: String in VALUES:
		state[key] = thing.get(key)
	state["attachments"] = (thing.node_data.get("mods", {}) as Dictionary).get("attachments", []).duplicate()
	state["ammo_override"] = thing.ammo_override.duplicate(true)
	state["status"] = Status.snapshot(thing)
	state["owner_id"] = thing.owner_id
	state["team"] = thing.team
	state["captured"] = thing.is_captured
	state["ground_item"] = thing.ground_item
	state["anatomy"] = thing.node_data.get("mods",{}).get("anatomy",{}).duplicate()
	state["max_hp"] = thing.max_hp
	for pair in [["tactics","CreatureTactics"],["transformation","CreatureTransform"],["butterfly_shield","ButterflyShield"]]:
		var component = thing.get_node_or_null(pair[1])
		if component != null: state[pair[0]] = component.snapshot()
	for pair in [["fusion","FusionPowers"],["creative","CreativeEffects"],["bond","CreatureBond"],["coop_boss","CoopBoss"]]:
		var component = thing.get_node_or_null(pair[1])
		if component != null: state[pair[0]] = component.snapshot()
	var orders = thing.get_node_or_null("AnimalOrders")
	if orders != null: state["animal_orders"] = orders.snapshot()
	var builder = thing.get_node_or_null("CreatureBuilder")
	if builder != null: state["builder"] = builder.snapshot()
	var pokemon = thing.get_node_or_null("PokemonCompanion")
	if pokemon != null: state["pokemon"] = pokemon.snapshot()
	var ball = thing.get_node_or_null("CaptureBall")
	if ball != null:
		state["capture_ball"] = {"occupant_id": ball.occupant_id, "occupant_name": ball.occupant_name, "result": ball.result, "shake_left": ball.shake_left}
	var cursed = thing.get_node_or_null("Jujutsu")
	var beam = thing.get_node_or_null("CursedBeam")
	if beam != null: state["cursed_beam"] = beam.snapshot()
	if cursed != null:
		state["jujutsu"] = {"clock": cursed.clock, "exposure": cursed.exposure.duplicate(), "domain_until": cursed.domain_until, "domain_mode": cursed.domain_mode, "domain_origin": cursed.domain_origin, "domain_up": cursed.domain_up, "domain_clashing": cursed.domain_clashing}
		state.jujutsu.merge({"clash_elapsed": cursed.clash_elapsed, "clash_pressure": cursed.clash_pressure, "clash_point": cursed.clash_point, "clash_axis": cursed.clash_axis, "domain_outcome": cursed.domain_outcome})
	state["layer"] = thing.collision_layer
	state["mask"] = thing.collision_mask
	state["shapes"] = thing.collisions.map( func(shape: CollisionShape3D): return not shape.disabled)
	var grafts: Array = []
	for graft: Thing in thing.grafts:
		if not is_instance_valid(graft) or graft.is_dead:
			grafts.append({"dead": true})
		else:
			grafts.append({"dead": false, "pose": graft.transform, "state": capture(graft)})
	state["grafts"] = grafts
	var marks: Array = []
	for child in thing.get_children():
		if child is TriggerOnAimHold:
			marks.append(child.network_presentation())
	state["marks"] = marks
	return state


static func apply(thing: Thing, state: Dictionary) -> void :
	if not thing.network_replica or state.is_empty():
		return
	for pair in [["tactics","CreatureTactics"],["transformation","CreatureTransform"],["butterfly_shield","ButterflyShield"]]:
		var component = thing.get_node_or_null(pair[1])
		if component != null and state.get(pair[0]) is Dictionary: component.apply_snapshot(state[pair[0]])
	var pokemon = thing.get_node_or_null("PokemonCompanion")
	if pokemon != null and state.get("pokemon") is Dictionary: pokemon.apply_snapshot(state.pokemon)
	var anatomy: Dictionary = state.get("anatomy",{})
	var anatomy_mods: Dictionary = thing.node_data.get_or_add("mods",{})
	if anatomy != anatomy_mods.get("anatomy",{}):
		anatomy_mods.anatomy = anatomy.duplicate()
		thing.rebuild_equipment_model()
	thing.max_hp = float(state.get("max_hp",thing.max_hp))
	for pair in [["fusion","FusionPowers"],["creative","CreativeEffects"],["bond","CreatureBond"],["coop_boss","CoopBoss"]]:
		var component = thing.get_node_or_null(pair[1])
		if component != null and state.get(pair[0]) is Dictionary: component.apply_snapshot(state[pair[0]])
	var owner_id := int(state.get("owner_id", thing.owner_id))
	var team := int(state.get("team", thing.team))
	if owner_id != thing.owner_id or team != thing.team:
		thing.set_owner_info(owner_id, team, Forge.world.get_player(owner_id) if Forge.world != null else null, null)
	var orders = thing.get_node_or_null("AnimalOrders")
	if orders != null and state.get("animal_orders") is Dictionary: orders.apply_snapshot(state.animal_orders)
	var beam = thing.get_node_or_null("CursedBeam")
	if beam != null and state.get("cursed_beam") is Dictionary: beam.apply_snapshot(state.cursed_beam)
	var builder = thing.get_node_or_null("CreatureBuilder")
	if builder != null and state.get("builder") is Dictionary: builder.apply_snapshot(state.builder)
	var attachments: Array = state.get("attachments", [])
	var mods: Dictionary = thing.node_data.get_or_add("mods", {})
	if attachments != mods.get("attachments", []):
		mods["attachments"] = attachments.duplicate()
		thing.rebuild_equipment_model()
	for key: String in VALUES:
		if state.has(key):
			thing.set(key, state[key])
	thing.ammo_override = (state.get("ammo_override", {}) as Dictionary).duplicate(true)
	Status.apply_snapshot(thing, state.get("status", {}))
	thing.set_captured(bool(state.get("captured", false)))
	thing.ground_item = bool(state.get("ground_item", false))
	var ball = thing.get_node_or_null("CaptureBall")
	if ball != null and state.get("capture_ball") is Dictionary:
		ball.occupant_id = int(state.capture_ball.get("occupant_id", 0))
		ball.occupant_name = String(state.capture_ball.get("occupant_name", ""))
		ball.result = String(state.capture_ball.get("result", "empty"))
		ball.shake_left = float(state.capture_ball.get("shake_left", 0.0))
	var cursed = thing.get_node_or_null("Jujutsu")
	if cursed != null and state.get("jujutsu") is Dictionary:
		var data: Dictionary = state.jujutsu
		cursed.clock = float(data.get("clock", 0.0))
		cursed.exposure = data.get("exposure", {}).duplicate()
		cursed.domain_until = float(data.get("domain_until", 0.0))
		cursed.domain_mode = String(data.get("domain_mode", ""))
		cursed.domain_origin = data.get("domain_origin", thing.center())
		cursed.domain_up = data.get("domain_up", Vector3.UP)
		cursed.domain_clashing = bool(data.get("domain_clashing", false))
		cursed.clash_elapsed = float(data.get("clash_elapsed", 0.0))
		cursed.clash_pressure = float(data.get("clash_pressure", 0.0))
		cursed.clash_point = data.get("clash_point", cursed.domain_origin)
		cursed.clash_axis = data.get("clash_axis", Vector3.RIGHT)
		cursed.domain_outcome = String(data.get("domain_outcome", ""))
	thing.collision_layer = int(state.get("layer", 0))
	thing.collision_mask = int(state.get("mask", 0))
	var shapes: Array = state.get("shapes", [])
	for index in mini(shapes.size(), thing.collisions.size()):
		thing.collisions[index].set_deferred("disabled", not bool(shapes[index]))
	var grafts: Array = state.get("grafts", [])
	for index in mini(grafts.size(), thing.grafts.size()):
		var graft: = thing.grafts[index]
		if not is_instance_valid(graft) or graft.is_dead:
			continue
		var row: Dictionary = grafts[index]
		if row.get("dead", false):
			graft.remove()
		else:
			graft.transform = row.get("pose", graft.transform)
			apply(graft, row.get("state", {}))
	var marks: Array = state.get("marks", [])
	var mark_index: = 0
	for child in thing.get_children():
		if child is TriggerOnAimHold and mark_index < marks.size():
			child.apply_network_presentation(marks[mark_index])
			mark_index += 1
	thing.ammo_changed.emit()
