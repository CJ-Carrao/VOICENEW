class_name Assembler
extends RefCounted






const MOVES: = {
	"walking_house": preload("res://scripts/things/move/move_walking_house.gd"),
	"static": preload("res://scripts/things/move/move_static.gd"), 
	"straight": preload("res://scripts/things/move/move_straight.gd"), 
	"ballistic": preload("res://scripts/things/move/move_ballistic.gd"), 
	"fly": preload("res://scripts/things/move/move_fly.gd"), 
	"follow_aim": preload("res://scripts/things/move/move_follow_aim.gd"), 
	"flyover": preload("res://scripts/things/move/move_flyover.gd"), 
	"bounce": preload("res://scripts/things/move/move_bounce.gd"), 
	"chase_enemy": preload("res://scripts/things/move/move_chase_enemy.gd"), 
	"orbit_owner": preload("res://scripts/things/move/move_orbit_owner.gd"), 
}
const TRIGGERS: = {
	"on_fire": preload("res://scripts/things/trigger/trigger_on_fire.gd"), 
	"on_hit": preload("res://scripts/things/trigger/trigger_on_hit.gd"), 
	"every": preload("res://scripts/things/trigger/trigger_every.gd"), 
	"after": preload("res://scripts/things/trigger/trigger_after.gd"), 
	"on_death": preload("res://scripts/things/trigger/trigger_on_death.gd"), 
	"near_enemy": preload("res://scripts/things/trigger/trigger_near_enemy.gd"), 
	"on_aim_hold": preload("res://scripts/things/trigger/trigger_on_aim_hold.gd"), 
	"on_command": preload("res://scripts/things/trigger/trigger_on_command.gd"), 
}
const ACTIONS: = {
	"jujutsu": preload("res://scripts/things/action/action_jujutsu.gd"),
	"purge_species": preload("res://scripts/things/action/action_species_bomb.gd"),
	"burst_into": preload("res://scripts/things/action/action_burst_into.gd"), 
	"anomaly": preload("res://scripts/things/action/action_anomaly.gd"),
	"shoot": preload("res://scripts/things/action/action_shoot.gd"), 
	"drop": preload("res://scripts/things/action/action_drop.gd"), 
	"spawn": preload("res://scripts/things/action/action_spawn.gd"), 
	"explode": preload("res://scripts/things/action/action_explode.gd"), 
	"anchor": preload("res://scripts/things/action/action_anchor.gd"), 
	"summon": preload("res://scripts/things/action/action_summon.gd"), 
	"push": preload("res://scripts/things/action/action_push.gd"), 
	"pull": preload("res://scripts/things/action/action_pull.gd"), 
	"freeze": preload("res://scripts/things/action/action_freeze.gd"), 
	"ignite": preload("res://scripts/things/action/action_ignite.gd"), 
	"split": preload("res://scripts/things/action/action_split.gd"), 
	"strike": preload("res://scripts/things/action/action_strike.gd"), 
}

const CONTROLS: = {
	"none": null, 
	"player": preload("res://scripts/things/control/control_player.gd"), 
	"auto": preload("res://scripts/things/control/control_auto.gd"), 
}


static func build(node: Dictionary, role: String, lex: LexiconData, mount_depth: int = 0, budget: Dictionary = {}) -> Thing:
	if budget.is_empty():
		budget["left"] = int(lex.bal("caps.grafts_per_recipe", 8))
	var thing_id: = String(node.get("thing", ""))
	var def: = lex.thing_def(thing_id)
	var role_def: Dictionary = (def.get("roles", {}) as Dictionary).get(role, {})

	var thing: = Thing.new()
	thing.name = thing_id
	thing.configure(node, role, def, lex)
	var anatomy: Dictionary = node.get("mods", {}).get("anatomy", {})
	if anatomy.has("legs"):
		thing.speed = lex.thing_statf(String(anatomy.legs), "speed") * float(node.get("mods", {}).get("speed", 1.0))
	thing.attach_model(ModelBuilder.build(thing_id, node.get("mods", {}), lex))
	var protection := InnovationRules.profile(node, lex)
	if not protection.is_empty():
		var emitter = load("res://scripts/things/protection_emitter.gd").new()
		emitter.name = "ProtectionEmitter"
		emitter.profile_id = protection
		emitter.radius = clampf(float(def.get("shield_radius", 3.5)) * thing.scale_factor, 2.0, 6.0)
		thing.add_child(emitter)
	var ecosystem: Dictionary = def.get("ecology", {})
	var diet := String(node.get("mods", {}).get("diet", def.get("diet", "")))
	if not ecosystem.is_empty() or not diet.is_empty():
		var ecology = load("res://scripts/things/ecology_behavior.gd").new()
		ecology.name = "EcologyBehavior"
		ecology.setup(thing, ecosystem, diet)
		thing.add_child(ecology)
	if bool(def.get("voxel_motion", false)):
		var motion = load("res://scripts/things/voxel_creature_motion.gd").new()
		motion.name = "VoxelCreatureMotion"
		motion.setup(thing, bool(def.get("aerial", false)) or anatomy.has("wings"))
		thing.add_child(motion)

	var move_id: = movement_id(node, def, role_def, role, lex)
	if not MOVES.has(move_id):
		thing.unsupported.append("movimento '%s'" % move_id)
		move_id = movement_id({}, def, role_def, role, lex)
		if not MOVES.has(move_id):
			move_id = "static"
	var move: ThingMove = (MOVES[move_id] as GDScript).new()
	move.name = "Move"
	move.setup(thing, lex)
	thing.attach_move(move)
	var cursed := JujutsuRules.powers(node, lex)
	if not cursed.is_empty():
		var user = load("res://scripts/things/jujutsu_user.gd").new()
		user.name = "Jujutsu"
		user.setup(thing, cursed)
		thing.add_child(user)
	if def.get("spatial_orb") is Dictionary:
		var orb = load("res://scripts/things/spatial_orb.gd").new()
		orb.name = "SpatialOrb"
		orb.setup(thing, def.spatial_orb)
		thing.add_child(orb)

	var control: = String(node.get("control", "none"))
	if not CONTROLS.has(control):
		thing.unsupported.append("controle '%s'" % control)
	elif CONTROLS[control] != null:
		var component: Node = (CONTROLS[control] as GDScript).new()
		component.name = "Control"
		component.call("setup", thing, lex)
		thing.control = component
		thing.add_child(component)


	for behavior in merged_behaviors(node, lex.thing_def(lex.behavior_source(node)), role_def, lex):
		_add_behavior(thing, behavior)


		if (behavior.get("when", {}) as Dictionary).get("type") == "on_fire"\
		and (behavior.get("do", {}) as Dictionary).get("type") == "strike":
			thing.melee = true
	if mount_depth < int(lex.bal("caps.graft_depth", 2)):
		for graft: Dictionary in (node.get("mods", {}) as Dictionary).get("grafts", []):
			if int(budget["left"]) <= 0:
				break
			budget["left"] = int(budget["left"]) - 1
			var child: = build(Recipe.from_data(graft["node"]), "mounted", lex, mount_depth + 1, budget)
			var longest: = thing.bounds.size[thing.bounds.size.max_axis_index()]
			var child_longest: = child.bounds.size[child.bounds.size.max_axis_index()]
			var fit: = minf(1.0, maxf(lex.balf("grafts.min_limit_m"), longest * lex.balf("grafts.max_size_ratio")) / maxf(child_longest, 0.01))

			child.fit_geometry(fit)
			child.mount_host = thing
			child.mount_socket = String(graft.get("socket", "mount_top"))
			thing.add_child(child)
			thing.grafts.append(child)
			thing.weight += child.weight
			thing.model_pieces.append_array(child.model_pieces)
			child.move.set_physics_process(false)
			if child.control != null:
				child.control.set_physics_process(false)
			child.control = null
			var equipment: = preload("res://scripts/things/control/mounted_equipment.gd").new()
			equipment.set_meta("thing_gameplay_component", true)
			equipment.setup(child, lex, int(graft.get("slot", 0)), int(graft.get("slots", 1)))
			child.add_child(equipment)
	return thing



static func build_replica(node: Dictionary, role: String, lex: LexiconData, network_id: int, seed: int) -> Thing:
	var thing: = build(node.duplicate(true), role, lex)
	thing.configure_network_replica(network_id, seed)
	return thing




static func merged_behaviors(node: Dictionary, def: Dictionary, role_def: Dictionary, lex: LexiconData = null) -> Array[Dictionary]:
	var explicit: Array = node.get("behaviors", [])
	var taken: = {}
	for behavior: Dictionary in explicit:
		taken[_key(behavior)] = true
	var role_defaults: Array = role_def.get("behaviors", [])
	var role_keys: = {}
	for behavior: Dictionary in role_defaults:
		role_keys[_key(behavior)] = true

	var result: Array[Dictionary] = []
	for behavior: Dictionary in def.get("behaviors", []):
		if not taken.has(_key(behavior)) and not role_keys.has(_key(behavior)):
			result.append(Recipe.behavior_from_data(behavior))
	for behavior: Dictionary in role_defaults:
		if not taken.has(_key(behavior)):
			result.append(Recipe.behavior_from_data(behavior))
	for behavior: Dictionary in explicit:
		result.append(behavior)
	var anatomy: Dictionary = node.get("mods", {}).get("anatomy", {})
	if lex != null and anatomy.has("head"):
		for behavior: Dictionary in lex.thing_def(String(anatomy.head)).get("behaviors", []):
			var duplicate := false
			for existing in result:
				duplicate = duplicate or _key(existing) == _key(behavior)
			if not duplicate: result.append(Recipe.behavior_from_data(behavior))
	if lex != null:
		var keys: = {}
		for behavior in result:
			keys[_key(behavior)] = true
		for behavior: Dictionary in lex.material_pack(node)["behaviors"]:
			if not keys.has(_key(behavior)):
				result.append(Recipe.behavior_from_data(behavior))
				keys[_key(behavior)] = true

	var mods: Dictionary = node.get("mods", {})
	if mods.get("explosive", false):
		var explode: = {"when": {"type": "on_hit"}, "do": {"type": "explode"}}
		var has_it: = false
		for behavior in result:
			has_it = has_it or _key(behavior) == _key(explode)
		if not has_it:
			result.append(explode)
	return result



static func unsupported_in(node: Dictionary) -> Array[String]:
	var found: Array[String] = []
	_collect_unsupported(node, found)
	return found


static func _collect_unsupported(node: Dictionary, found: Array[String]) -> void :
	var notes: Array[String] = []
	for graft: Dictionary in (node.get("mods", {}) as Dictionary).get("grafts", []):
		_collect_unsupported(graft["node"], found)
	if node.get("movement") != null and not MOVES.has(String(node["movement"])):
		notes.append("movimento '%s'" % node["movement"])
	if not CONTROLS.has(String(node.get("control", "none"))):
		notes.append("controle '%s'" % node["control"])
	for behavior: Dictionary in node.get("behaviors", []):
		var when_type: = String((behavior.get("when", {}) as Dictionary).get("type", ""))
		var act: Dictionary = behavior.get("do", {})
		if not TRIGGERS.has(when_type):
			notes.append("gatilho '%s'" % when_type)
		if not ACTIONS.has(String(act.get("type", ""))):
			notes.append("ação '%s'" % act.get("type", ""))
		if act.get("arg") is Dictionary:
			_collect_unsupported(act["arg"], found)
	for note in notes:
		if not found.has(note):
			found.append(note)




static func movement_id(node: Dictionary, def: Dictionary, role_def: Dictionary, role: String, lex: LexiconData) -> String:
	if node.get("movement") != null:
		return String(node["movement"])
	if node.get("mods", {}).get("anatomy", {}).has("wings"):
		return "fly"
	var pack: = lex.material_pack(node)
	if pack.has("movement"):
		return String(pack["movement"])
	var move_id: = String(role_def.get("movement", def.get("movement", "static")))
	return String((lex.role_movement_rules.get(role, {}) as Dictionary).get(move_id, move_id))


static func _add_behavior(thing: Thing, behavior: Dictionary) -> void :
	var when : Dictionary = behavior.get("when", {})
	var act: Dictionary = behavior.get("do", {})
	var when_type: = String( when .get("type", ""))
	var act_type: = String(act.get("type", ""))
	if not TRIGGERS.has(when_type):
		thing.unsupported.append("gatilho '%s'" % when_type)
		return
	if not ACTIONS.has(act_type):
		thing.unsupported.append("ação '%s'" % act_type)
		return
	var action: ThingAction = (ACTIONS[act_type] as GDScript).new()
	action.name = "Do_" + act_type
	action.setup(thing, act)
	var trigger: ThingTrigger = (TRIGGERS[when_type] as GDScript).new()
	trigger.name = "When_" + when_type
	trigger.setup(thing, when , action)
	thing.add_child(action)
	thing.add_child(trigger)


static func _key(behavior: Dictionary) -> String:
	return "%s|%s" % [(behavior.get("when", {}) as Dictionary).get("type", ""), (behavior.get("do", {}) as Dictionary).get("type", "")]
