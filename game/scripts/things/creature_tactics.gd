extends Node

var thing: Thing
var rule = ""
var friend_ref: WeakRef
var passenger_ref: WeakRef
var carrier_ref: WeakRef
var passenger_id = 0
var carrier_id = 0
var friend_id = 0
var tick = 0.0
var carried_mask = 0
var label = ""
var rescued = false
var armored_model = 0

func setup(owner_thing: Thing) -> void: thing = owner_thing
func _ready() -> void: process_physics_priority = 50
func passenger(): return passenger_ref.get_ref() if passenger_ref != null else null
func carrier(): return carrier_ref.get_ref() if carrier_ref != null else null
func friend(): return friend_ref.get_ref() if friend_ref != null else null
func being_carried() -> bool: return is_instance_valid(carrier()) or (thing.network_replica and carrier_id > 0)
static func speed_factor(source: Thing) -> float:
	var rig = source.get_node_or_null("CreatureTactics")
	return .75 if rig != null and is_instance_valid(rig.passenger()) else 1.0
func usable(target: Thing) -> bool:
	return is_instance_valid(target) and target != thing and not target.is_dead and not target.is_captured and not target.is_held and not target.is_building and target.owner_id == thing.owner_id and target.team == thing.team and target.mount_host == null and target.get_node_or_null("CoopBoss") == null
func can_carry(target: Thing) -> bool:
	if not usable(target) or being_carried() or is_instance_valid(passenger()): return false
	var other = target.get_node_or_null("CreatureTactics")
	if other == null or other.being_carried() or is_instance_valid(other.passenger()): return false
	var changing = target.get_node_or_null("CreatureTransform")
	if changing != null and changing.active: return false
	var flying = thing.move.hovers()
	var capacity = maxf(35.0,thing.weight*1.5) if flying else minf(2500.0,maxf(12.0,thing.weight*.65))
	return (flying and thing.weight >= 2.0 or not flying and thing.weight >= 12.0) and target.weight <= capacity and target.bounds.size.length() <= 8.0
func load_passenger(target: Thing) -> bool:
	if not can_carry(target) or thing.center().distance_to(target.center()) > 4.5: return false
	var other = target.get_node("CreatureTactics")
	passenger_ref = weakref(target)
	passenger_id = target.network_id
	other.carrier_ref = weakref(thing)
	other.carrier_id = thing.network_id
	other.carried_mask = target.collision_mask
	target.collision_mask = 0
	_exceptions(target,true)
	label = "Transportando "+Lexicon.data.thing_name(target.thing_id)
	return true
func _exceptions(target: Thing, add: bool) -> void:
	for a in [thing]+thing.grafts:
		for b in [target]+target.grafts:
			if not is_instance_valid(a) or not is_instance_valid(b): continue
			if add: a.add_collision_exception_with(b); b.add_collision_exception_with(a)
			else: a.remove_collision_exception_with(b); b.remove_collision_exception_with(a)
func unload() -> void:
	var target = passenger()
	passenger_ref = null
	passenger_id = 0
	if not is_instance_valid(target): return
	var other = target.get_node("CreatureTactics")
	other.carrier_ref = null
	other.carrier_id = 0
	_exceptions(target,false)
	if target.is_dead: return
	target.collision_mask = other.carried_mask
	target.velocity = Vector3.ZERO
	# A low, nearby clear point avoids teleporting through walls or dropping from flight altitude.
	var origin: Vector3 = thing.center()+thing.global_basis.x*(thing.bounds.size.x*.5+target.bounds.size.x*.5+.6)
	var spot = Forge.ground_point(origin,thing.up())
	var destination: Vector3 = spot+thing.up()*maxf(.15,-target.bounds.position.y+.1)
	var ray = PhysicsRayQueryParameters3D.create(thing.center(),destination,PhysicsLayers.WORLD)
	if origin.distance_to(destination) < 4.0 and thing.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): target.global_position = destination
	else: target.global_position = origin
	if target.move != null: target.move.landed = false
func detach() -> void:
	if thing.network_replica: return
	var parent = carrier()
	if is_instance_valid(parent): parent.get_node("CreatureTactics").unload()
	unload()
func cancel_rule() -> void:
	if rule == "rescue" and not thing.network_replica: unload()
	rule = ""
	friend_ref = null
	friend_id = 0
	rescued = false
func assign(action: String, target: Thing = null) -> void:
	if not thing.network_replica and is_instance_valid(passenger()): unload()
	thing.get_node("AnimalOrders").set_order("tactical",thing.global_position)
	rule = action
	friend_ref = weakref(target) if target != null else null
	friend_id = target.network_id if target != null else 0
	label = action
	rescued = false
static func choose(player: Player, species_id: String, exclude: Thing = null) -> Thing:
	var selected: Thing
	var best = INF
	for candidate in Forge.world.get_node("Things").get_children():
		if not candidate is Thing or candidate == exclude or candidate.thing_id != species_id or candidate.owner_id != player.player_id or candidate.team != player.team or candidate.is_dead or candidate.is_captured or candidate.is_held or candidate.is_building: continue
		var distance: float = candidate.center().distance_to(player.center())
		if distance > 60.0 or distance >= best: continue
		var ray = PhysicsRayQueryParameters3D.create(player.head.global_position,candidate.center(),PhysicsLayers.WORLD)
		if not player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
		best = distance
		selected = candidate
	return selected
static func request(player: Player, settings: Dictionary) -> Dictionary:
	if not player.can_act(): return {"blocked":true,"warnings":["Você não pode dar ordens agora."]}
	var actor = choose(player,String(settings.get("actor","")))
	if actor == null: return {"blocked":true,"warnings":["A criatura precisa ser sua, estar visível e a até 60 m."]}
	var rig = actor.get_node("CreatureTactics")
	var action = String(settings.get("action",""))
	if action in ["transform","revert"]:
		var power = actor.get_node_or_null("CreatureTransform")
		if power == null: return {"blocked":true,"warnings":["Crie a criatura com uma transformação primeiro."]}
		if action == "revert": power.revert(); return {"warnings":["Voltou à forma original."]}
		return power.trigger()
	if action in ["release","cancel"]:
		rig.detach()
		rig.cancel_rule()
		actor.get_node("AnimalOrders").set_order("follow",actor.global_position)
		return {"warnings":["Carga liberada e regra cancelada."]}
	var target = choose(player,String(settings.get("target","")),actor) if settings.has("target") else null
	if settings.has("target") and target == null: return {"blocked":true,"warnings":["Invoque o companheiro ou a torre perto do animal primeiro."]}
	if action == "carry" and not rig.can_carry(target): return {"blocked":true,"warnings":["Carga grande demais, criatura sem capacidade ou transporte já ocupado."]}
	if action == "repair" and (actor.thing_id != "ant" or not rig.repairable(target)): return {"blocked":true,"warnings":["Use formigas para reparar uma estrutura, veículo ou criatura com armadura."]}
	if action in ["guard_friend","rescue"] and target.category != "creature": return {"blocked":true,"warnings":["Escolha uma criatura companheira para proteger."]}
	if action == "rescue" and not rig.can_carry(target): return {"blocked":true,"warnings":["Esse animal não tem capacidade para resgatar o companheiro."]}
	rig.assign(action,target)
	var count = 1
	if settings.get("all",false) and action in ["repair","guard_friend","defend_owner","retreat"]:
		for candidate in Forge.world.get_node("Things").get_children():
			if count >= 8: break
			if not candidate is Thing or candidate == actor or candidate.thing_id != actor.thing_id or candidate.owner_id != actor.owner_id or candidate.team != actor.team or not candidate.can_act() or candidate.is_captured or candidate.is_held or candidate.center().distance_to(player.center()) > 60.0: continue
			var sight = PhysicsRayQueryParameters3D.create(player.head.global_position,candidate.center(),PhysicsLayers.WORLD)
			if not player.get_world_3d().direct_space_state.intersect_ray(sight).is_empty(): continue
			candidate.get_node("CreatureTactics").assign(action,target)
			count += 1
	return {"creature_rule":action,"creature_count":count,"warnings":["Ordem salva para %d criatura(s). Ordens comuns cancelam a regra; diga 'solte a carga' para desembarcar." % count]}
func repairable(target: Thing) -> bool:
	return usable(target) and (target.category in ["structure","vehicle"] or bool(target.node_data.get("mods",{}).get("armored",false)) or target.get_node_or_null("ProtectionEmitter") != null)
func recent(victim: Node) -> Node3D:
	var record: Dictionary = victim.get_meta("animal_last_attacker",{})
	if not record.has("source") or Time.get_ticks_msec()-int(record.get("at",0)) > 6000: return null
	var attacker = record.source.get_ref()
	return attacker if is_instance_valid(attacker) else null
func _physics_process(delta: float) -> void:
	if not thing.has_simulation_authority() or not thing.is_active or thing.is_dead: return
	var rider = passenger()
	if is_instance_valid(rider):
		if not usable(rider): unload()
		else:
			var offset = -thing.up()*(thing.bounds.size.y*.5+rider.bounds.size.y*.55+.3) if thing.move.hovers() else thing.up()*(thing.bounds.size.y*.5+rider.bounds.size.y*.5+.2)
			rider.global_position += thing.center()+offset-rider.center()
			rider.velocity = Vector3.ZERO
	elif passenger_ref != null: unload()
	if being_carried() or not thing.can_act() or thing.category != "creature": return
	tick -= delta
	if tick > 0.0: return
	tick = .2
	if rule.is_empty(): return
	var owner = thing.owner_player
	if not is_instance_valid(owner) or not owner.is_alive(): detach(); cancel_rule(); return
	var orders = thing.get_node("AnimalOrders")
	if orders.mode != "tactical": cancel_rule(); return
	orders.target_ref = null
	orders.goal = owner.global_position
	var target = friend()
	if rule in ["guard_friend","rescue","repair","carry"] and not usable(target): detach(); cancel_rule(); orders.set_order("follow",thing.global_position); return
	match rule:
		"defend_owner":
			var attacker = recent(owner)
			if orders._enemy(attacker) and thing.center().distance_to(Combat.center_of(attacker)) < 20.0: orders.target_ref = weakref(attacker)
		"retreat":
			if thing.hp <= thing.max_hp*.35: orders.goal = owner.global_position
			else: orders.goal = thing.global_position
		"guard_friend", "rescue":
			orders.goal = target.global_position if not is_instance_valid(passenger()) else owner.global_position
			if rule == "rescue" and target.hp <= target.max_hp*.4 and not rescued:
				if load_passenger(target): rescued = true
			if rescued and thing.center().distance_to(owner.center()) < 4.0:
				unload(); label = "Companheiro entregue ao treinador"; rule = "guard_friend"; rescued = false
			var attacker = recent(target)
			if not is_instance_valid(passenger()) and orders._enemy(attacker) and thing.center().distance_to(Combat.center_of(attacker)) < 18.0: orders.target_ref = weakref(attacker)
		"carry":
			if not is_instance_valid(passenger()):
				orders.goal = target.global_position
				load_passenger(target)
			else: orders.goal = owner.global_position
		"repair":
			orders.goal = target.global_position
			if thing.center().distance_to(target.center()) <= 3.5 and target.hp < target.max_hp and int(target.get_meta("repair_after",0)) <= Time.get_ticks_msec():
				var amount = minf(4.0,target.max_hp-target.hp)
				if owner.try_spend(amount*.6):
					target.hp += amount
					target.set_meta("repair_after",Time.get_ticks_msec()+800)
					ExpansionFx.burst(Forge.fx_root(thing),target.center(),.4,Color("afc8a5"),"repair")
				else: label = "Reparo pausado: falta matéria"
func snapshot() -> Dictionary: return {"rule":rule,"friend":friend_id,"passenger":passenger_id,"carrier":carrier_id,"label":label,"rescued":rescued}
func apply_snapshot(data: Dictionary) -> void:
	rule = String(data.get("rule",""))
	friend_id = int(data.get("friend",0))
	passenger_id = int(data.get("passenger",0))
	carrier_id = int(data.get("carrier",0))
	label = String(data.get("label",""))
	rescued = bool(data.get("rescued",false))
func _process(_delta: float) -> void:
	if not bool(thing.node_data.get("mods",{}).get("armored",false)) or not is_instance_valid(thing.model): return
	if armored_model == thing.model.get_instance_id(): return
	armored_model = thing.model.get_instance_id()
	var material = StandardMaterial3D.new()
	material.albedo_color = Color("747d85")
	for side in [-1,1]:
		var plate = MeshInstance3D.new()
		var mesh = BoxMesh.new()
		mesh.size = Vector3(.08,clampf(thing.bounds.size.y*.45,.2,1.4),clampf(thing.bounds.size.z*.55,.2,2.0))
		plate.mesh = mesh
		plate.material_override = material
		plate.position = thing.bounds.get_center()+Vector3(side*(thing.bounds.size.x*.5+.04),0,0)
		thing.model.add_child(plate)
