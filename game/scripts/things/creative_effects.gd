extends Node

var thing: Thing
var head_time = 0.0
var old_head = ""
var team_time = 0.0
var old_owner = 0
var old_team = 0
var old_source: WeakRef
var old_order = {}
var old_target: WeakRef
var old_house: WeakRef
var immunity = 0.0

func setup(owner_thing: Thing) -> void: thing = owner_thing
func available() -> bool:
	return not thing.is_dead and not thing.is_captured and not thing.is_held and not thing.is_building and thing.is_active and thing.get_node_or_null("CoopBoss") == null
func age(source: Thing) -> bool:
	if not available() or not _vulnerable(source): return false
	var state = Status.of(thing)
	if state != null and (state.remaining.has("aged") or state.remaining.has("age_immunity")): return false
	Status.apply(thing,"aged",source)
	Status.apply(thing,"age_immunity",source)
	return true
func _vulnerable(source: Thing) -> bool:
	return Combat.affects(source,thing) and JujutsuRules.field(thing,"infinity") == null and JujutsuRules.field(thing,"adaptation") == null
static func swap(a: Node, b: Node, source: Thing) -> bool:
	if a == null or b == null or a == b or not a.available() or not b.available() or a.head_time > 0 or b.head_time > 0 or a.immunity > 0 or b.immunity > 0 or not a._vulnerable(source) or not b._vulnerable(source): return false
	a.old_head = String(a.thing.node_data.get("mods",{}).get("anatomy",{}).get("head",""))
	b.old_head = String(b.thing.node_data.get("mods",{}).get("anatomy",{}).get("head",""))
	var head_a: String = a.old_head if not a.old_head.is_empty() else a.thing.thing_id
	var head_b: String = b.old_head if not b.old_head.is_empty() else b.thing.thing_id
	a._head(head_b)
	b._head(head_a)
	a.head_time = 8.0
	b.head_time = 8.0
	a.immunity = 16.0
	b.immunity = 16.0
	return true
func _head(id: String) -> void:
	var mods: Dictionary = thing.node_data.get_or_add("mods",{})
	var anatomy: Dictionary = mods.get_or_add("anatomy",{})
	if id.is_empty(): anatomy.erase("head")
	else: anatomy.head = id
	# Only appearance changes: identity, skills, HP, equipment and contents remain intact.
	thing.rebuild_equipment_model()
	var motion = thing.get_node_or_null("VoxelCreatureMotion")
	if motion != null:
		motion.parts.clear()
		motion.setup(thing,bool(thing._def.get("aerial",false)) or thing.node_data.get("mods",{}).get("anatomy",{}).has("wings"))
func charm(source: Thing) -> bool:
	if not available() or team_time > 0.0 or immunity > 0.0 or not _vulnerable(source) or not is_instance_valid(source.owner_player): return false
	old_owner = thing.owner_id
	old_team = thing.team
	old_source = weakref(thing.spawner) if is_instance_valid(thing.spawner) else null
	var orders = thing.get_node_or_null("AnimalOrders")
	old_order = orders.snapshot() if orders != null else {}
	old_target = orders.target_ref if orders != null else null
	old_house = orders.house_ref if orders != null else null
	Forge.transfer_owner(thing,source.owner_player,source)
	if orders != null: orders.set_order("retaliate",thing.global_position)
	team_time = 6.0
	immunity = 18.0
	return true
func restore(clear_age: bool = true) -> void:
	if head_time > 0.0:
		head_time = 0.0
		_head(old_head)
	if team_time > 0.0:
		team_time = 0.0
		var owner = Forge.world.get_player(old_owner) if Forge.world != null else null
		var source = old_source.get_ref() if old_source != null else null
		if is_instance_valid(owner): Forge.transfer_owner(thing,owner,source as Thing)
		else: thing.set_owner_info(old_owner,old_team,null,source)
		thing.team = old_team
		var orders = thing.get_node_or_null("AnimalOrders")
		if orders != null:
			orders.apply_snapshot(old_order)
			orders.target_ref = old_target
			orders.house_ref = old_house
			if orders.mode == "attack" and (old_target == null or not is_instance_valid(old_target.get_ref())): orders.set_order("stay",thing.global_position)
	if clear_age: Status.remove_effect(thing,"aged")
func _physics_process(delta: float) -> void:
	if not thing.has_simulation_authority(): return
	immunity = maxf(0.0,immunity-delta)
	if thing.is_dead: return
	if head_time > 0.0:
		head_time -= delta
		if head_time <= 0.0: head_time = .001; restore_head()
	if team_time > 0.0:
		team_time -= delta
		if team_time <= 0.0: team_time = .001; restore_team()
func restore_head() -> void:
	head_time = 0.0
	_head(old_head)
func restore_team() -> void:
	var keep = head_time
	head_time = 0.0
	restore(false)
	head_time = keep
func snapshot() -> Dictionary: return {"head_time":head_time,"team_time":team_time,"immunity":immunity}
func apply_snapshot(data: Dictionary) -> void:
	head_time = float(data.get("head_time",0.0))
	team_time = float(data.get("team_time",0.0))
	immunity = float(data.get("immunity",0.0))
