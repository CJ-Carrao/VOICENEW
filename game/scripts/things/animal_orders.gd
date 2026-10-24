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
static var bomb_cache := []
static var bomb_cache_until := 0
static var bomb_world := 0

func setup(owner_thing: Thing) -> void: thing = owner_thing
func _ready() -> void:
	add_to_group("ordered_animals")
	process_physics_priority = -35
	tick_left = float(thing.get_instance_id() % 11) * .018
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

func active() -> bool: return mode != "free"
func available() -> bool:
	return is_instance_valid(thing) and thing.can_act() and not thing.is_captured and not thing.is_held
func combat_target() -> Node3D:
	var target = target_ref.get_ref() if target_ref != null else null
	return target if _enemy(target) else null
func _enemy(target: Object) -> bool:
	if not is_instance_valid(target) or target == thing or target == thing.owner_player or not target.has_method("take_damage"): return false
	if target.has_method("is_alive") and not target.is_alive(): return false
	if target is Thing and (target.is_dead or target.is_captured or target.is_held): return false
	return (mode == "aggressive" or target.get("team") != thing.team) and InnovationRules.allows_target(thing, target)
func allows(target: Object) -> bool:
	return mode == "free" or (mode in ["attack", "guard", "retaliate", "aggressive"] and target == combat_target())

static func request(player: Node3D, settings: Dictionary) -> Dictionary:
	if not player.can_act(): return {"blocked": true, "warnings": ["Você não pode dar ordens agora."]}
	var ray: Dictionary = player.look_ray()
	var selected: Node
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
		if species.is_empty() and (along < 0 or miss > maxf(1.2, orders.thing.bounds.size.length() * .5)): continue
		var query := PhysicsRayQueryParameters3D.create(ray.origin, at, PhysicsLayers.WORLD)
		if not player.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		var score := miss * 8.0 + distance
		if score < best:
			best = score
			selected = orders
	if selected == null: return {"blocked": true, "warnings": ["Aponte para um animal seu ou diga o nome dele. Ele precisa estar visível e a até 60 m."]}
	var action := String(settings.animal_order)
	var target: Node3D
	if action == "attack":
		var alignment := .45
		for candidate in player.get_tree().get_nodes_in_group(Combat.COMBATANTS_GROUP):
			if not selected._enemy(candidate): continue
			var direction: Vector3 = Combat.center_of(candidate) - ray.origin
			if direction.length() > 60.0: continue
			var value: float = direction.normalized().dot(ray.direction)
			if value > alignment:
				alignment = value
				target = candidate
		if target == null: return {"blocked": true, "warnings": ["Mire em um jogador inimigo que esse animal possa atacar. A dieta continua valendo."]}
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
	var names := {"follow": "me siga", "stay": "fique aqui", "guard": "proteja a casa", "attack": "ataque o jogador", "evade": "fuja das bombas", "retaliate": "ataque só quem me atacar", "free": "volte ao normal", "build": "construa aqui", "aggressive": "agressivo · poupa você"}
	selected.last_label = Lexicon.data.thing_name(selected.thing.thing_id) + ": " + String(names.get(action, action))
	if action == "build": selected.last_label += " · " + selected.thing.get_node("CreatureBuilder").requirements()
	ExpansionFx.burst(Forge.fx_root(player), selected.thing.center(), .5, Color("9dcdb4"), "animal_order")
	return {"animal_order": action, "animal_network_id": selected.thing.network_id, "warnings": [selected.last_label]}

func set_order(action: String, at: Vector3, target: Node3D = null) -> void:
	if action != "guard": house_ref = null
	if action != "build":
		var builder := thing.get_node_or_null("CreatureBuilder")
		if builder != null: builder.cancel()
	mode = action
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
	if not active() or not available(): return
	bite_left = maxf(0.0, bite_left - delta)
	tick_left -= delta
	if tick_left > 0: return
	tick_left = Lexicon.balf("animal_orders.tick_s")
	var owner := thing.owner_player
	if not is_instance_valid(owner) or not owner.is_alive():
		goal = thing.global_position
		return
	match mode:
		"follow": goal = owner.global_position
		"stay", "guard": goal = point
		"retaliate":
			goal = owner.global_position
			var recent: Dictionary = owner.get_meta("animal_last_attacker", {})
			var attacker = recent.source.get_ref() if recent.has("source") and Time.get_ticks_msec() - int(recent.get("at", 0)) < int(Lexicon.balf("animal_orders.retaliation_s") * 1000) else null
			target_ref = weakref(attacker) if _enemy(attacker) and thing.global_position.distance_to(Combat.center_of(attacker)) < 30.0 else null
		"evade": goal = _escape_point()
		"aggressive":
			goal = thing.global_position
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
	var stopping := 2.5 if mode in ["follow", "retaliate", "evade"] and combat_target() == null else .4
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
	thing.velocity = direction * maxf(thing.speed, 0.0) + (thing.up() * thing.velocity.dot(thing.up()) if not airborne else Vector3.ZERO)
	thing.move.steering = true
	thing.move.step(delta)
	if direction.length_squared() > .001: thing.face(direction, thing.upright or not airborne)

func _attack(target: Node3D) -> void:
	if not available(): return
	var query := PhysicsRayQueryParameters3D.create(thing.center(), Combat.center_of(target), PhysicsLayers.WORLD)
	if not thing.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): return
	var pokemon := thing.get_node_or_null("PokemonCompanion")
	if pokemon != null and pokemon.remaining <= 0.0: pokemon.cast(String(pokemon.moves.keys()[0]))
	var reach := maxf(1.2, thing.bounds.size.length() * .45)
	if thing.center().distance_to(Combat.center_of(target)) <= reach and bite_left <= 0:
		bite_left = .8
		Combat.apply_damage(target, maxf(4.0, thing.impact_damage), "bite", thing)

func on_capture() -> void:
	if mode == "build": set_order("stay", thing.global_position)
func on_release() -> void:
	if mode == "stay": point = thing.global_position; goal = point
func snapshot() -> Dictionary: return {"mode": mode, "point": point, "goal": goal, "label": last_label}
func apply_snapshot(values: Dictionary) -> void:
	mode = String(values.get("mode", "free"))
	point = values.get("point", Vector3.ZERO)
	goal = values.get("goal", point)
	last_label = String(values.get("label", ""))
