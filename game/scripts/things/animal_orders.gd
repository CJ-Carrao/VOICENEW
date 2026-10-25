extends Node

var thing: Thing
var mode := "free"
var point := Vector3.ZERO
var goal := Vector3.ZERO
var target_ref: WeakRef
var house_ref: WeakRef
var tick_left := 0.0
var bite_left := 0.0
var last_label := ""
var automatic_ref: WeakRef
var automatic_active := false
static var bomb_cache := []
static var bomb_cache_until := 0
static var bomb_world := 0

func setup(owner_thing: Thing) -> void: thing = owner_thing
func _ready() -> void:
	add_to_group("ordered_animals")
	process_physics_priority = -35
	tick_left = float(thing.get_instance_id() % 11) * .018
	if thing._def.get("default_order", "") == "follow":
		mode = "follow"
		tick_left = 0.0
	if bool(thing.node_data.get("mods", {}).get("aggressive", false)):
		mode = "aggressive"
		tick_left = 0.0

static func of(source: Thing) -> Node:
	var cursor := source
	var seen := {}
	for step in 8:
		if not is_instance_valid(cursor) or seen.has(cursor.get_instance_id()): return null
		seen[cursor.get_instance_id()] = true
		if cursor.category == "structure": return null
		var orders := cursor.get_node_or_null("AnimalOrders")
		if orders != null: return orders
		cursor = cursor.mount_host if is_instance_valid(cursor.mount_host) else cursor.spawner as Thing
	return null

func active() -> bool: return mode != "free" or automatic_active
func available() -> bool:
	return is_instance_valid(thing) and thing.can_act() and not thing.is_captured and not thing.is_held
func combat_target() -> Node3D:
	var target = target_ref.get_ref() if target_ref != null else null
	if target == null and automatic_ref != null: target = automatic_ref.get_ref()
	return target if _enemy(target) else null
func _enemy(target: Object) -> bool:
	if not is_instance_valid(target) or target == thing or target == thing.owner_player or not target.has_method("take_damage"): return false
	if target.has_method("is_alive") and not target.is_alive(): return false
	if target is Thing and (target.is_dead or target.is_captured or target.is_held): return false
	if target.get("team") != null and load("res://scripts/things/coop_encounter.gd").allied(thing.team,int(target.get("team"))): return false
	return (mode == "aggressive" or target.get("team") != thing.team) and InnovationRules.allows_target(thing, target)
func allows(target: Object) -> bool:
	if automatic_active: return target == combat_target()
	return mode == "free" or (mode in ["attack", "guard", "guard_pack", "retaliate", "aggressive", "tactical"] and target == combat_target())

static func request(player: Node3D, settings: Dictionary) -> Dictionary:
	if not player.can_act(): return {"blocked": true, "warnings": ["Você não pode dar ordens agora."]}
	var ray: Dictionary = player.look_ray()
	var selected: Node
	var recipients: Array[Node] = []
	var group := bool(settings.get("all", false))
	var best := INF
	var species := String(settings.get("species", ""))
	for orders in player.get_tree().get_nodes_in_group("ordered_animals"):
		if not orders.available() or orders.thing.owner_id != player.player_id or orders.thing.team != player.team: continue
		if not species.is_empty() and orders.thing.thing_id != species: continue
		var at: Vector3 = orders.thing.center()
		var distance := player.global_position.distance_to(at)
		if distance > Lexicon.balf("animal_orders.range_m"): continue
		var offset: Vector3 = at - ray.origin
		var along: float = offset.dot(ray.direction)
		var miss: float = (offset - ray.direction * along).length()
		if not group and species.is_empty() and (along < 0 or miss > maxf(1.2, orders.thing.bounds.size.length() * .5)): continue
		var query := PhysicsRayQueryParameters3D.create(ray.origin, at, PhysicsLayers.WORLD)
		if not player.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		recipients.append(orders)
		var score := miss * 8.0 + distance
		if score < best:
			best = score
			selected = orders
	if selected == null: return {"blocked": true, "warnings": ["Aponte para um animal seu ou diga o nome dele. Ele precisa estar visível e a até 60 m."]}
	if group:
		var changed := 0
		var ids := []
		var warning := ""
		for orders in recipients:
			var reply := _apply_order(player, settings, orders, ray)
			if not reply.get("blocked", false):
				changed += 1
				ids.append(orders.thing.network_id)
			elif not reply.get("warnings", []).is_empty(): warning = reply.warnings[0]
		if changed == 0: return {"blocked": true, "warnings": [warning]}
		return {"animal_order": settings.animal_order, "animal_count": changed, "animal_network_ids": ids, "warnings": ["Ordem recebida por %d criaturas suas." % changed]}
	return _apply_order(player, settings, selected, ray)

static func _apply_order(player: Node3D, settings: Dictionary, selected: Node, ray: Dictionary) -> Dictionary:
	var action := String(settings.animal_order)
	var bond = selected.thing.get_node_or_null("CreatureBond")
	if action in ["attack","aggressive"] and bond != null and bond.refuses_danger():
		return {"blocked":true,"warnings":["Muito ferido e assustado para atacar. Cuide da criatura ou mande recuar."]}
	var target: Node3D
	if action == "attack":
		var alignment := .45
		var candidates := player.get_tree().get_nodes_in_group(Combat.COMBATANTS_GROUP)
		if Forge.world != null: candidates.append_array(Forge.world.get_node("Things").get_children())
		for candidate in candidates:
			if not selected._enemy(candidate) or candidate.get("team") == selected.thing.team: continue
			if candidate is Thing and candidate.category not in ["creature", "vehicle"]: continue
			var direction: Vector3 = Combat.center_of(candidate) - ray.origin
			if direction.length() > 60.0: continue
			var value: float = direction.normalized().dot(ray.direction)
			if value > alignment:
				var query := PhysicsRayQueryParameters3D.create(ray.origin, Combat.center_of(candidate), PhysicsLayers.WORLD)
				if not player.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
				alignment = value
				target = candidate
		if target == null: return {"blocked": true, "warnings": ["Mire num jogador ou criatura inimiga que esse animal possa atacar. A dieta continua valendo."]}
	var aim: Dictionary = player.aim()
	var at: Vector3 = aim.point if aim.get("collider") != null else player.global_position + ray.direction * 5.0
	if action in ["follow", "stay", "retaliate", "evade", "free", "aggressive"]: at = selected.thing.global_position
	if action == "guard": at = selected._house_point(player, at)
	if action == "build":
		var builder = selected.thing.get_node_or_null("CreatureBuilder")
		if builder == null: return {"blocked": true, "warnings": ["Esse animal não constrói. Use formiga, castor ou aranha."]}
		if selected.thing.global_position.distance_to(at) > 20.0: return {"blocked": true, "warnings": ["Escolha um local de trabalho a até 20 m do animal."]}
		var reply: Dictionary = builder.begin(at, ray.direction)
		if reply.get("blocked", false): return reply
		at = builder.work_point
	selected.set_order(action, at, target)
	var names := {"follow": "me siga", "stay": "fique aqui", "guard": "proteja a casa", "attack": "ataque o alvo", "evade": "fuja das bombas", "retaliate": "ataque só quem me atacar", "free": "volte ao normal", "build": "construa aqui", "aggressive": "agressivo · poupa você"}
	selected.last_label = Lexicon.data.thing_name(selected.thing.thing_id) + ": " + String(names.get(action, action))
	if action == "build": selected.last_label += " · " + selected.thing.get_node("CreatureBuilder").requirements()
	ExpansionFx.burst(Forge.fx_root(player), selected.thing.center(), .5, Color("9dcdb4"), "animal_order")
	return {"animal_order": action, "animal_network_id": selected.thing.network_id, "warnings": [selected.last_label]}

func set_order(action: String, at: Vector3, target: Node3D = null) -> void:
	automatic_ref = null
	automatic_active = false
	var tactics := thing.get_node_or_null("CreatureTactics")
	if tactics != null and action != "tactical": tactics.cancel_rule()
	if action != "guard": house_ref = null
	if action != "build":
		var builder := thing.get_node_or_null("CreatureBuilder")
		if builder != null: builder.cancel()
	mode = String(thing._def.get("default_order", "free")) if action == "free" else action
	point = at
	goal = at
	target_ref = weakref(target) if target != null else null
	tick_left = 0.0
	thing.move.steering = active()

func _house_point(player: Node3D, aim: Vector3) -> Vector3:
	house_ref = null
	var best := 25.0
	var result := thing.global_position
	for candidate in Forge.world.get_node("Things").get_children():
		if not candidate is Thing or candidate.is_dead or candidate.owner_id != thing.owner_id or not ("house" in candidate.thing_id): continue
		var distance: float = candidate.global_position.distance_to(aim)
		if distance < best:
			best = distance
			result = candidate.global_position
			house_ref = weakref(candidate)
	for structure in get_tree().get_nodes_in_group(Structure.STRUCTURES):
		if "house" not in structure.blueprint_id or structure.global_position.distance_to(player.global_position) > 25.0: continue
		var distance: float = structure.global_position.distance_to(aim)
		if distance < best:
			best = distance
			result = structure.global_position
			house_ref = weakref(structure)
	return result

func _physics_process(delta: float) -> void:
	if not available(): return
	bite_left = maxf(0.0, bite_left - delta)
	tick_left -= delta
	if tick_left > 0: return
	tick_left = Lexicon.balf("animal_orders.tick_s")
	var owner := thing.owner_player
	if not is_instance_valid(owner) or not owner.is_alive():
		automatic_ref = null
		automatic_active = false
		goal = thing.global_position
		return
	_automatic_reaction(owner)
	if not active(): return
	match mode:
		"follow":
			goal = owner.global_position
			if bool(thing._def.get("verity_companion", false)):
				goal += owner.global_basis.x * 1.7 + thing.up() * 1.6
		"stay", "guard": goal = point
		"retaliate":
			goal = owner.global_position
			var recent: Dictionary = owner.get_meta("animal_last_attacker", {})
			var attacker = recent.source.get_ref() if recent.has("source") and Time.get_ticks_msec() - int(recent.get("at", 0)) < int(Lexicon.balf("animal_orders.retaliation_s") * 1000) else null
			target_ref = weakref(attacker) if _enemy(attacker) and thing.global_position.distance_to(Combat.center_of(attacker)) < 30.0 else null
		"evade": goal = _escape_point()
		"guard_pack":
			goal = owner.global_position
			target_ref = null
			var nearest := 18.0
			for ally in Combat.in_radius(thing,thing.center(),18.0):
				if not ally is Thing or ally.owner_id != thing.owner_id or ally.category != "creature": continue
				var recent: Dictionary = ally.get_meta("animal_last_attacker",{})
				var attacker = recent.source.get_ref() if recent.has("source") and Time.get_ticks_msec()-int(recent.get("at",0)) < 6000 else null
				if not _enemy(attacker): continue
				var distance: float = thing.center().distance_to(Combat.center_of(attacker))
				if distance < nearest: nearest = distance; target_ref = weakref(attacker)
		"aggressive":
			# Keep searching ahead instead of freezing when the front cone is empty.
			goal = thing.global_position - thing.global_basis.z * maxf(3.0, thing.speed)
			target_ref = null
			var best := 18.0
			for candidate in Combat.in_radius(thing, thing.center(), best):
				if not _enemy(candidate) or (candidate is Thing and candidate.category not in ["creature", "vehicle", "structure"]): continue
				var offset := Combat.center_of(candidate) - thing.center()
				if offset.normalized().dot(-thing.global_basis.z) < .2: continue
				if offset.length() < best:
					best = offset.length()
					target_ref = weakref(candidate)
	if mode == "guard":
		var house = house_ref.get_ref() if house_ref != null else null
		if is_instance_valid(house): point = house.global_position; goal = point
		target_ref = null
		var best := Lexicon.balf("animal_orders.guard_radius_m")
		for candidate in Combat.in_radius(thing, point, best):
			if not _enemy(candidate): continue
			var distance := point.distance_to(Combat.center_of(candidate))
			if distance < best:
				best = distance
				target_ref = weakref(candidate)
	var target := combat_target()
	if target != null:
		goal = Combat.center_of(target)
		_attack(target)
	elif mode == "attack":
		mode = "stay"
		point = thing.global_position
		goal = point

func _automatic_reaction(owner: Node3D) -> void:
	automatic_ref = null
	automatic_active = false
	if mode not in ["free","follow"] or thing.get_node_or_null("CoopBoss") != null: return
	var victims: Array = [thing]
	if thing.center().distance_to(Combat.center_of(owner)) <= 10.0: victims.append(owner)
	for victim in victims:
		var record: Dictionary = victim.get_meta("animal_last_attacker",{})
		if not record.has("source") or Time.get_ticks_msec()-int(record.get("at",0)) > 6000: continue
		var attacker = record.source.get_ref()
		if not _enemy(attacker) or thing.center().distance_to(Combat.center_of(attacker)) > 18.0: continue
		var ray := PhysicsRayQueryParameters3D.create(thing.center(),Combat.center_of(attacker),PhysicsLayers.WORLD)
		if not thing.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
		automatic_ref = weakref(attacker)
		automatic_active = true
		last_label = "Reagindo ao agressor" if victim == thing else "Protegendo o treinador"
		return

func _escape_point() -> Vector3:
	var now := Time.get_ticks_msec()
	var world_id := Forge.world.get_instance_id()
	if now >= bomb_cache_until or bomb_world != world_id:
		bomb_cache_until = now + 300
		bomb_world = world_id
		bomb_cache.clear()
		for candidate in Forge.world.get_node("Things").get_children():
			if not candidate is Thing or candidate.is_dead or candidate.is_captured or candidate.is_held: continue
			if not candidate.explosion_spent and (candidate.get_node_or_null("Do_explode") != null or "bomb" in candidate.thing_id or "grenade" in candidate.thing_id):
				bomb_cache.append({"point": candidate.center(), "radius": maxf(7.0, candidate.explosion_radius + 3.0)})
			if bomb_cache.size() >= 64: break
	var away := Vector3.ZERO
	for bomb in bomb_cache:
		var offset: Vector3 = thing.global_position - bomb.point
		var distance := offset.length()
		if distance < minf(float(bomb.radius), 22.0): away += offset.normalized() * (1.0 - distance / float(bomb.radius)) if distance > .01 else thing.global_basis.x
	return thing.global_position + Gravity.flat(away, thing.up()).normalized() * 8.0 if away.length_squared() > .001 else thing.owner_player.global_position

func drive(delta: float) -> void:
	var offset := goal - thing.global_position
	var airborne := thing.move.hovers()
	if not airborne: offset = Gravity.flat(offset, thing.up())
	var distance := offset.length()
	var stopping := 2.5 if mode in ["follow", "retaliate", "evade", "tactical"] and combat_target() == null else .4
	if mode == "follow" and bool(thing._def.get("verity_companion", false)): stopping = .45
	if combat_target() != null: stopping = maxf(1.1, thing.bounds.size.length() * .3)
	if distance <= stopping:
		thing.velocity = Vector3.ZERO if airborne else thing.up() * thing.velocity.dot(thing.up())
		if not airborne:
			thing.move.steering = true
			thing.move.step(delta)
		return
	var direction := offset.normalized()
	# A short feeler steers around walls without teleporting or adding speed.
	var query := PhysicsRayQueryParameters3D.create(thing.center(), thing.center() + direction * 1.2, PhysicsLayers.WORLD)
	var hit := thing.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): direction = Gravity.flat(direction.rotated(thing.up(), .85), thing.up()).normalized()
	thing.velocity = direction * maxf(thing.speed, 0.0) * load("res://scripts/things/creature_tactics.gd").speed_factor(thing) + (thing.up() * thing.velocity.dot(thing.up()) if not airborne else Vector3.ZERO)
	thing.move.steering = true
	thing.move.step(delta)
	if direction.length_squared() > .001: thing.face(direction, thing.upright or not airborne)

func _attack(target: Node3D) -> void:
	if not available(): return
	var query := PhysicsRayQueryParameters3D.create(thing.center(), Combat.center_of(target), PhysicsLayers.WORLD)
	if not thing.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): return
	var pokemon := thing.get_node_or_null("PokemonCompanion")
	var fusion := thing.get_node_or_null("FusionPowers")
	if fusion != null: fusion.auto_attack()
	if pokemon != null and pokemon.remaining <= 0.0: pokemon.cast(String(pokemon.moves.keys()[0]))
	var reach := maxf(1.2, thing.bounds.size.length() * .45)
	if thing.center().distance_to(Combat.center_of(target)) <= reach and bite_left <= 0:
		bite_left = .8
		Combat.apply_damage(target, maxf(4.0, thing.impact_damage), "bite", thing)

func on_capture() -> void:
	if mode == "build": set_order("stay", thing.global_position)
func on_release() -> void:
	if mode == "stay": point = thing.global_position; goal = point
func snapshot() -> Dictionary: return {"mode": mode, "point": point, "goal": goal, "label": last_label,"automatic":automatic_active}
func apply_snapshot(values: Dictionary) -> void:
	mode = String(values.get("mode", "free"))
	point = values.get("point", Vector3.ZERO)
	goal = values.get("goal", point)
	last_label = String(values.get("label", ""))
	automatic_active = bool(values.get("automatic",false))
