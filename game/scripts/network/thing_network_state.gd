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
	var cursed = thing.get_node_or_null("Jujutsu")
	if cursed != null:
		state["jujutsu"] = {"clock": cursed.clock, "exposure": cursed.exposure.duplicate(), "domain_until": cursed.domain_until, "domain_mode": cursed.domain_mode}
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
	var cursed = thing.get_node_or_null("Jujutsu")
	if cursed != null and state.get("jujutsu") is Dictionary:
		var data: Dictionary = state.jujutsu
		cursed.clock = float(data.get("clock", 0.0))
		cursed.exposure = data.get("exposure", {}).duplicate()
		cursed.domain_until = float(data.get("domain_until", 0.0))
		cursed.domain_mode = String(data.get("domain_mode", ""))
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
