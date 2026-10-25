extends Node

var thing: Thing
var form = ""
var active = false
var remaining = 0.0
var cooldown = 0.0
var shot_left = 0.0
var weapon: Node

func setup(owner_thing: Thing) -> void:
	thing = owner_thing
	form = String(thing.node_data.get("mods",{}).get("transform_to",""))
static func price(node: Dictionary, lex: LexiconData) -> float:
	var id = String(node.get("mods",{}).get("transform_to",""))
	if lex.category_of(String(node.get("thing",""))) != "creature" or not load("res://scripts/language/tactical_language.gd").valid_form(id,lex): return 0.0
	return maxf(65.0,lex.thing_statf(id,"cost")*.8)*maxf(1.0,float(node.get("mods",{}).get("count",1)))
func trigger() -> Dictionary:
	var rig = thing.get_node_or_null("CreatureTactics")
	if not thing.can_act() or thing.is_captured or thing.is_held or active or cooldown > 0.0 or (rig != null and (rig.being_carried() or is_instance_valid(rig.passenger()))): return {"blocked":true,"warnings":["Transformação indisponível: recarga, transporte ou criatura paralisada."]}
	active = true
	remaining = 12.0
	cooldown = 30.0
	shot_left = 1.0
	change_model()
	ExpansionFx.burst(Forge.fx_root(thing),thing.center(),1.6,Color("acb8cd"),"transformation")
	return {"transformed":form,"warnings":["Forma de "+Lexicon.data.thing_name(form)+" por 12 s. Vida e equipamentos preservados."]}
func revert() -> void:
	if not active: return
	active = false
	remaining = 0.0
	change_model()
func model_id() -> String: return form if active else thing.thing_id
func apply_stats() -> void:
	if not active: return
	thing.speed = Lexicon.data.thing_statf(form,"speed")*float(thing.node_data.get("mods",{}).get("speed",1.0))
	thing.weight = Lexicon.data.thing_statf(form,"weight_kg")
	for graft in thing.grafts:
		if is_instance_valid(graft): thing.weight += graft.weight
	thing.impact_damage = minf(32.0,maxf(thing.impact_damage,Lexicon.data.thing_statf(form,"impact_damage")))
func damage_multiplier() -> float: return .65 if active and Lexicon.data.category_of(form) == "vehicle" else .9 if active else 1.0
func change_model() -> void:
	var hp = thing.hp
	thing.rebuild_equipment_model()
	thing.hp = minf(hp,thing.max_hp)
	var definition: Dictionary = Lexicon.data.thing_def(form if active else thing.thing_id)
	var move_id = String(definition.get("movement","chase_enemy"))
	if not Assembler.MOVES.has(move_id): move_id = "chase_enemy"
	var old = thing.move
	thing.remove_child(old)
	old.queue_free()
	var next_move = Assembler.MOVES[move_id].new()
	next_move.name = "Move"
	next_move.setup(thing,Lexicon.data)
	thing.attach_move(next_move)
	if thing.network_replica: next_move.set_physics_process(false)
	var orders = thing.get_node_or_null("AnimalOrders")
	if orders != null: next_move.steering = orders.active()
	var motion = thing.get_node_or_null("VoxelCreatureMotion")
	if motion != null:
		motion.parts.clear()
		motion.setup(thing,next_move.hovers())
func _physics_process(delta: float) -> void:
	if not thing.has_simulation_authority() or not thing.is_active or thing.is_dead or thing.is_building or thing.is_held: return
	cooldown = maxf(0.0,cooldown-delta)
	if active:
		remaining -= delta
		if remaining <= 0.0: revert(); return
		shot_left -= delta
		if not thing.can_act() or shot_left > 0.0: return
		var target = Combat.nearest_target(thing,thing.center(),get_tree())
		if target == null or thing.center().distance_to(Combat.center_of(target)) > 24.0: return
		var ray = PhysicsRayQueryParameters3D.create(thing.center(),Combat.center_of(target),PhysicsLayers.WORLD)
		if not thing.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): return
		if weapon == null:
			for behavior in Lexicon.data.thing_def(form).get("behaviors",[]):
				if behavior.get("do",{}).get("type","") == "shoot":
					weapon = load("res://scripts/things/action/action_shoot.gd").new()
					weapon.name = "TransformWeapon"
					weapon.setup(thing,behavior["do"].duplicate(true))
					add_child(weapon)
					break
		if weapon != null:
			shot_left = 2.5
			weapon.run(ActionContext.make(thing.center(),Combat.center_of(target)-thing.center(),target))
	elif cooldown <= 0.0 and thing.hp <= thing.max_hp*.35:
		var rig = thing.get_node_or_null("CreatureTactics")
		if thing.can_act() and (rig == null or not rig.being_carried() and not is_instance_valid(rig.passenger())): trigger()
func snapshot() -> Dictionary: return {"active":active,"remaining":remaining,"cooldown":cooldown}
func apply_snapshot(data: Dictionary) -> void:
	var changed = active != bool(data.get("active",false))
	active = bool(data.get("active",false))
	remaining = float(data.get("remaining",0.0))
	cooldown = float(data.get("cooldown",0.0))
	if changed: change_model()
