extends Node













signal request_processed(player_id: int, text: String, result: Dictionary)
signal exploded(player_id: int)
signal live_things_changed(player_id: int)

@warning_ignore("unused_signal")
signal explosion_at(at: Vector3, radius: float, damage: float)

@warning_ignore("unused_signal")
signal hit_landed(player_id: int, target: Node, amount: float, killed: bool)
signal build_started(player_id: int, thing: Thing)
signal build_finished(player_id: int, thing: Thing)


signal draft_changed(player_id: int)

signal draft_confirmed(player_id: int, result: Dictionary)

const UNKNOWN_WORDS_LOG: = "user://unknown_words.log"

const GROUP_GAP: = 0.5


var world: Match = null

var stats: = {"spawned": 0, "explosions": 0, "explosions_blocked": 0, "evicted": 0, "too_deep": 0, "production_paused": 0}
var production := preload("res://scripts/things/production_budget.gd").new()
var _last_anomaly_ms := -1000

var test_instant_builds: bool = false
var test_free_matter: bool = false

var _drafts: Dictionary = {}


var _live: Dictionary = {}

var _explosion_times: Dictionary = {}

var _builds: Dictionary = {}

var _usage: Dictionary = {}

var novelty_clock_offset_s: float = 0.0


func attach_world(match_node: Match) -> void :
	world = match_node
	production.reset()
	_last_anomaly_ms = -1000


func detach_world(match_node: Match) -> void :
	if world == match_node:
		world = null





func has_gameplay_authority() -> bool:
	return Session.has_authority() and ( not Session.is_online() or Session.creations.is_active())\
	and (world == null or world.gameplay_available())



func has_effect_authority() -> bool:
	return has_gameplay_authority()


func request(player_id: int, text: String, record_unknowns: bool = true, commands_only: bool = false) -> Dictionary:
	if Session.is_online() and not Session.has_authority():
		if player_id != Session.local_player_id or not Session.creations.is_active():
			return _blocked_request(player_id, text, "Aguarde a sessão ficar pronta para pedir.")
		return Session.creations.submit_request(text, record_unknowns, commands_only)
	var result: = PhraseParser.parse(text, Lexicon.data)
	result["unsupported"] = []
	result["cost"] = 0.0
	result["base_cost"] = 0.0
	result["novelty_uses"] = 0
	result["novelty_mult"] = 1.0
	result["build_s"] = 0.0
	if commands_only and (not result.get("ok", false) or not (result.get("recipe", {}) as Dictionary).has("command")):
		return _reject_result(player_id, text, result, "B aceita apenas comandos, como 'Squirtle, ataque'. Use V para criar coisas.")
	if not has_gameplay_authority() or (world != null and world.get_player(player_id) == null):
		result["blocked"] = true
		result["warnings"].append("Pedido indisponível enquanto a sessão está sendo preparada.")
		request_processed.emit(player_id, text, result)
		return result
	if world != null and Status.paralyzed(world.get_player(player_id)):
		return _reject_result(player_id, text, result, "Você está paralisado pelo Vazio Infinito.")
	if result["ok"] and (result["recipe"] as Dictionary).has("command"):
		if world != null:
			var warning: = _online_creation_warning(player_id, result["recipe"], 0.0)
			if not warning.is_empty():
				return _reject_result(player_id, text, result, warning)
			cancel_draft(player_id)
			result.merge(_command(player_id, String(result["recipe"]["command"])), true)
	elif result["ok"]:
		var novelty: = novelty_of(player_id, result["recipe"])
		result["base_cost"] = Cost.of(_priced(player_id, result["recipe"]), Lexicon.data)
		result["novelty_uses"] = novelty["uses"]
		result["novelty_mult"] = novelty["mult"]
		result["cost"] = float(result["base_cost"]) * float(result["novelty_mult"])
		result["build_s"] = Cost.build_seconds(result["cost"], Lexicon.data)
		if world != null:
			var warning: = _online_creation_warning(player_id, result["recipe"], float(result["cost"]), 
				not Shape.needs_shaping(result["recipe"], Lexicon.data))
			if not warning.is_empty():
				return _reject_result(player_id, text, result, warning)
			cancel_draft(player_id)
			if Shape.needs_shaping(result["recipe"], Lexicon.data):

				_drafts[player_id] = {"recipe": result["recipe"], "text": text, 
					"focus": Shape.focus(result["recipe"], Lexicon.data), "novelty_mult": float(novelty["mult"])}
				result["draft"] = true
			else:
				_note_use(player_id, result["recipe"])
				result.merge(_transmute_hand(player_id, result["recipe"], result["cost"]), true)
				result["unsupported"] = _materialize(player_id, result["recipe"], result["build_s"], result["cost"])
	elif world != null:
		_fail_in_front_of(player_id)
	_print_result(player_id, result)
	var unknown: Array = result["unknown_words"]
	if record_unknowns and not unknown.is_empty():
		_log_unknown_words(player_id, text, unknown)
	request_processed.emit(player_id, text, result)
	if result.get("draft", false):
		draft_changed.emit(player_id)
	return result


func _blocked_request(player_id: int, text: String, reason: String) -> Dictionary:
	return _reject_result(player_id, text, {"ok": false, "recipe": {}, "cost": 0.0, "build_s": 0.0, 
		"unknown_words": [], "unsupported": [], "warnings": []}, reason)


func _reject_result(player_id: int, text: String, result: Dictionary, reason: String) -> Dictionary:
	result["blocked"] = true
	var warnings: Array = result.get("warnings", [])
	warnings.append(reason)
	result["warnings"] = warnings
	request_processed.emit(player_id, text, result)
	return result



func _online_creation_warning(player_id: int, recipe: Dictionary, cost: float, check_economy: bool = true) -> String:
	if not Session.is_online() or world == null:
		return ""
	var player: = world.get_player(player_id)
	if player == null or not player.is_alive() or player.frozen or Status.paralyzed(player):
		return "Aguarde o jogador estar pronto para pedir."
	if not check_economy:
		return ""
	var replication_warning: = Session.creations.creation_warning(player_id, recipe, cost)
	if not replication_warning.is_empty():
		return replication_warning
	return ""



func receive_network_result(player_id: int, text: String, result: Dictionary, confirmed: bool = false) -> void :
	if not Session.is_online() or Session.has_authority():
		return
	if confirmed and not result.get("blocked", false):
		draft_confirmed.emit(player_id, result)
	else:
		request_processed.emit(player_id, text, result)
	if not result.get("ok", false) and not result.get("blocked", false) and world != null:
		_fail_in_front_of(player_id)


func receive_network_draft(player_id: int, draft: Dictionary) -> void :
	if not Session.is_online() or Session.has_authority():
		return
	if draft.is_empty():
		_drafts.erase(player_id)
	else:
		_drafts[player_id] = draft.duplicate(true)
	draft_changed.emit(player_id)



func track_network_replica(thing: Thing, building: bool) -> void :
	if not Session.is_online() or Session.has_authority() or not is_instance_valid(thing):
		return
	var pending: Array = _builds.get_or_add(thing.owner_id, [])
	if building and not pending.has(thing):
		pending.append(thing)
		if not thing.removed.is_connected(_on_build_removed):
			thing.removed.connect(_on_build_removed)
		build_started.emit(thing.owner_id, thing)
	elif not building and pending.has(thing):
		pending.erase(thing)
		build_finished.emit(thing.owner_id, thing)
	_track_network_live(thing)


func _track_network_live(thing: Thing) -> void :
	var live: Array = _live.get_or_add(thing.owner_id, [])
	if not thing.removed.is_connected(_on_thing_removed):
		thing.removed.connect(_on_thing_removed)
	if ( not thing.is_held or thing.mount_host != null) and not live.has(thing):
		live.append(thing)
		live_things_changed.emit(thing.owner_id)
	for graft: Thing in thing.grafts:
		if is_instance_valid(graft) and not graft.is_dead:
			_track_network_live(graft)


func clear_network_presentation() -> void :
	if Session.has_authority():
		return
	var previous: = _drafts.keys()
	_drafts.clear()
	_builds.clear()
	_live.clear()
	for player_id: int in previous:
		draft_changed.emit(player_id)





func draft_of(player_id: int) -> Dictionary:
	return _drafts.get(player_id, {})


func has_draft(player_id: int) -> bool:
	return _drafts.has(player_id)



func draft_cost(player_id: int, dims: Dictionary) -> float:
	var draft: Dictionary = draft_of(player_id)
	if draft.is_empty():
		return 0.0
	var mult: = float(draft.get("novelty_mult", 1.0)) if Session.is_online() and not Session.has_authority()\
	else float(novelty_of(player_id, draft["recipe"])["mult"])
	return Cost.of(Shape.apply(draft["recipe"], dims, Lexicon.data), Lexicon.data) * mult






func confirm_draft(player_id: int, dims: Dictionary = {}, at: Vector3 = Vector3.INF, forward: Vector3 = Vector3.ZERO) -> Dictionary:
	if Session.is_online() and not Session.has_authority():
		if player_id != Session.local_player_id or not Session.creations.is_active():
			return {}
		return Session.creations.submit_confirm(dims, at, forward)
	if not has_gameplay_authority():
		return {}
	var draft: Dictionary = draft_of(player_id)
	if draft.is_empty() or world == null:
		return {}
	var spoken: Dictionary = draft["recipe"]
	var recipe: = Shape.apply(spoken, dims, Lexicon.data)
	var novelty: = novelty_of(player_id, spoken)
	var result: = {"ok": true, "recipe": recipe, "pretty": Recipe.pretty(recipe, Lexicon.data), "text": draft["text"], 
		"base_cost": Cost.of(recipe, Lexicon.data), "novelty_uses": novelty["uses"], "novelty_mult": novelty["mult"]}
	result["cost"] = float(result["base_cost"]) * float(result["novelty_mult"])
	result["build_s"] = Cost.build_seconds(result["cost"], Lexicon.data)
	var warning: = _online_creation_warning(player_id, recipe, float(result["cost"]))
	if not warning.is_empty():
		return _reject_result(player_id, str(draft["text"]), result, warning)
	_drafts.erase(player_id)
	_note_use(player_id, spoken)
	result.merge(_transmute_hand(player_id, recipe, result["cost"]), true)
	result["unsupported"] = _materialize(player_id, recipe, result["build_s"], result["cost"], at, forward)
	draft_changed.emit(player_id)
	draft_confirmed.emit(player_id, result)
	return result



func cancel_draft(player_id: int) -> void :
	if Session.is_online() and not Session.has_authority():
		if player_id == Session.local_player_id and Session.creations.is_active():
			Session.creations.submit_cancel()
		return
	if _drafts.erase(player_id):
		draft_changed.emit(player_id)





func placement_spot(player: Player, placement: String) -> Dictionary:
	var aim: = player.aim()
	var player_up: = player.up()
	var forward: = Gravity.flat(aim["direction"], player_up)
	forward = forward.normalized() if forward.length_squared() > 0.0001 else - player.global_basis.z
	var base: Vector3
	if Gravity.active():
		base = _space_spot(player, aim, forward, placement)
	elif placement == "aim_ground":
		var target: Vector3 = aim["point"]
		var flat: = Gravity.flat(target - player.global_position, player_up)
		var max_range: = Lexicon.balf("placement.structure_max_range")
		if flat.length() > max_range:
			target = player.global_position + flat.normalized() * max_range
		base = ground_point(target, player_up)
	else:
		base = ground_point(player.global_position + forward * Lexicon.balf("placement.front_distance"), player_up)
	var up: = Gravity.up_at(base, player_up)
	var along: = Gravity.flat(forward, up)
	if along.length_squared() > 0.0001:
		forward = along.normalized()
	return {"base": base, "forward": forward, "up": up}





func _space_spot(player: Player, aim: Dictionary, forward: Vector3, placement: String) -> Vector3:
	var from: = player.global_position
	var up: = player.up()
	var source: = Gravity.source_index(from + up * 0.9)
	var distance: = Lexicon.balf("placement.front_distance")
	if placement == "aim_ground":
		var max_range: = Lexicon.balf("placement.structure_max_range")
		var point: Vector3 = aim["point"]
		if aim["collider"] != null and point.distance_to(from) <= max_range:
			return ground_point(point + Gravity.up_at(point, up) * 0.3, up)
		distance = minf(Gravity.flat(point - from, up).length(), max_range)
	var target: = Gravity.along_surface(from, up, forward * distance)
	var down: = Gravity.pull_of(source, target)
	if down == Vector3.ZERO:
		return ground_point(target, up)
	var query: = PhysicsRayQueryParameters3D.create(target - down * 2.0, target + down * 30.0, PhysicsLayers.WORLD)
	var hit: = world.get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else target



static func side_offsets(count: int, footprint: float) -> PackedFloat32Array:
	var out: = PackedFloat32Array()
	var spacing: = footprint + GROUP_GAP
	for i in count:
		out.append((i - (count - 1) * 0.5) * spacing)
	return out





func spawn_child(node: Dictionary, role: String, at: Vector3, direction: Vector3, spawner: Thing, 
		launch_speed: float = -1.0, inherit: Vector3 = Vector3.ZERO, same_generation: bool = false, 
		speed_mult: float = 1.0, replace_pair: bool = false) -> Thing:
	if not is_instance_valid(spawner) or spawner.is_captured: return null
	if not has_effect_authority() or world == null or node.is_empty() or ( not same_generation and not _depth_allows(spawner)):
		return null
	if Session.is_online() and not Session.creations.descendant_allowed(spawner.owner_id, node):
		return null
	var heavy := ProductionBudget.complex(node, Lexicon.data)
	if heavy and not replace_pair and not production.reserve(spawner.owner_id, live_things(spawner.owner_id).size()):
		stats.production_paused += 1
		return null
	if not InnovationRules.authorize_spawn(spawner, node):
		return null
	var started := Time.get_ticks_usec()
	var creature := String(Lexicon.data.thing_def(String(node.get("thing", ""))).get("category", "")) in ["creature", "vehicle"]
	var child_role := "spawned" if role == "projectile" and creature else role
	var child: = Assembler.build(node, child_role, Lexicon.data)
	if not creature: child.target_filter = InnovationRules.target_diet(spawner)
	child.set_owner_info(spawner.owner_id, spawner.team, spawner.owner_player, spawner)
	if same_generation:
		child.set_generation(spawner.generation)
	world.add_thing(child)


	var legal: = Lexicon.balf("arena.size") * 0.5 + Lexicon.balf("arena.out_of_bounds_margin") - 1.0
	child.global_position = clamp_to_world(at, legal)
	child.face(direction, child.upright)
	child.add_collision_exception_with(spawner)
	var mount := spawner.mount_host
	while is_instance_valid(mount):
		child.add_collision_exception_with(mount)
		mount = mount.mount_host
	if (spawner.is_held or role == "projectile") and spawner.owner_player is PhysicsBody3D:
		child.add_collision_exception_with(spawner.owner_player)
	child.move.launch(direction, (child.speed if launch_speed < 0.0 else launch_speed) * speed_mult)
	child.velocity += inherit
	_register(child)
	if Session.is_online():
		Session.creations.publish_creation(child, 0.0, true, 0.0)
	child.activate()
	_appear(child)
	if heavy: production.record_work(Time.get_ticks_usec() - started)
	return child



func summon_child(node: Dictionary, target: Vector3, heading: Vector3, spawner: Thing) -> Thing:
	if not is_instance_valid(spawner) or spawner.is_captured: return null
	if not has_effect_authority() or world == null or node.is_empty() or not _depth_allows(spawner):
		return null
	if Session.is_online() and not Session.creations.descendant_allowed(spawner.owner_id, node):
		return null
	if not production.reserve(spawner.owner_id, live_things(spawner.owner_id).size()):
		stats.production_paused += 1
		return null
	if not InnovationRules.authorize_spawn(spawner, node):
		return null
	var started := Time.get_ticks_usec()
	var child: = Assembler.build(node, "summoned", Lexicon.data)
	child.set_owner_info(spawner.owner_id, spawner.team, spawner.owner_player, spawner)
	world.add_thing(child)
	child.add_collision_exception_with(spawner)
	child.move.arrive(ground_point(clamp_to_arena(target)), heading)
	_register(child)
	if Session.is_online():
		Session.creations.publish_creation(child, 0.0, true, 0.0)
	child.activate()
	_appear(child)
	production.record_work(Time.get_ticks_usec() - started)
	return child


func production_available(source: Thing) -> bool:
	for component in source.get_children():
		if component is ThingAction and component.production_pending: return false
		if component is ThingAction and component.spec.get("type", "") in ["shoot", "drop", "spawn", "summon"]:
			var node: Dictionary = source.ammo_override if not source.ammo_override.is_empty() else component.arg()
			if not node.is_empty() and ProductionBudget.complex(node, Lexicon.data) and not production.available(source.owner_id, live_things(source.owner_id).size()): return false
	return true


func reserve_anomaly_effect() -> bool:
	var now := Time.get_ticks_msec()
	if now - _last_anomaly_ms < 170: return false
	_last_anomaly_ms = now
	return true



func allow_explosion(player_id: int) -> bool:
	if not has_effect_authority():
		return false
	var now: = Time.get_ticks_msec()
	var times: Array = _explosion_times.get_or_add(player_id, [])
	while not times.is_empty() and now - int(times[0]) > 1000:
		times.pop_front()
	if times.size() >= int(Lexicon.balf("caps.explosions_per_s")):
		stats["explosions_blocked"] += 1
		return false
	times.append(now)
	stats["explosions"] += 1
	exploded.emit(player_id)
	return true



func clamp_to_arena(point: Vector3) -> Vector3:
	return clamp_to_world(point, Lexicon.balf("arena.size") * 0.5)



func clamp_to_world(point: Vector3, half: float) -> Vector3:
	if Gravity.active() and world != null and world.arena.space != null:
		var box: = world.arena.space.box_half - 0.5
		return point.clamp( - Vector3.ONE * box, Vector3.ONE * box)
	return Vector3(clampf(point.x, - half, half), point.y, clampf(point.z, - half, half))




func ground_point(point: Vector3, fallback_up: Vector3 = Vector3.ZERO) -> Vector3:
	if world == null:
		return Vector3(point.x, 0.0, point.z)
	var up: = Gravity.up_at(point, fallback_up)
	if up == Vector3.ZERO:
		return point

	var reach: = 30.0 if Gravity.active() else 100.0
	var query: = PhysicsRayQueryParameters3D.create(point + up, point - up * reach, PhysicsLayers.WORLD)
	var hit: = world.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit["position"]
	return point if Gravity.active() else Vector3(point.x, 0.0, point.z)



func fx_root(fallback: Node) -> Node:
	if world != null:
		return world
	return fallback.get_tree().root


func live_things(player_id: int) -> Array:
	return (_live.get(player_id, []) as Array).duplicate()

func transfer_owner(thing: Thing, player: Player, source: Thing = null) -> void:
	if not is_instance_valid(thing) or not is_instance_valid(player) or not Session.has_authority(): return
	var previous := thing.owner_id
	var family := [thing]
	for item in family:
		family.append_array(item.grafts)
	for item in family:
		for list in _live.values(): list.erase(item)
	thing.set_owner_info(player.player_id, player.team, player, source)
	_register(thing)
	live_things_changed.emit(previous)
	live_things_changed.emit(player.player_id)




func materialize_for_test(player_id: int, recipe: Dictionary) -> Array[String]:
	if not has_gameplay_authority() or world == null or recipe.is_empty():
		return []
	var cost: = Cost.of(recipe, Lexicon.data)
	return _materialize(player_id, recipe, Cost.build_seconds(cost, Lexicon.data), cost)



func _depth_allows(spawner: Thing) -> bool:
	if spawner.generation + 1 < int(Lexicon.balf("caps.tree_depth")):
		return true
	stats["too_deep"] += 1
	return false




func novelty_of(player_id: int, recipe: Dictionary) -> Dictionary:
	var entry: Dictionary = (_usage.get(player_id, {}) as Dictionary).get(_usage_key(recipe), {})
	if entry.is_empty():
		return {"uses": 0, "mult": Lexicon.balf("novelty.first_mult")}
	var uses: = _uses_now(entry)
	return {"uses": uses, "mult": 1.0 + Lexicon.balf("novelty.repeat_add") * uses}



func _note_use(player_id: int, recipe: Dictionary) -> void :
	var table: = _usage.get_or_add(player_id, {}) as Dictionary
	var key: = _usage_key(recipe)
	var entry: Dictionary = table.get(key, {})
	table[key] = {"uses": (_uses_now(entry) if not entry.is_empty() else 0) + 1, "at": _now()}


func _uses_now(entry: Dictionary) -> int:
	var forget: = maxf(Lexicon.balf("novelty.forget_s"), 0.001)
	return maxi(int(entry["uses"]) - floori((_now() - float(entry["at"])) / forget), 0)


static func _usage_key(recipe: Dictionary) -> String:
	return JSON.stringify(Recipe.compact(recipe))



func _now() -> float:
	return Time.get_ticks_msec() * 0.001 + novelty_clock_offset_s



func reset_novelty(player_id: int = -1) -> void :
	if player_id < 0:
		_usage.clear()
	else:
		_usage.erase(player_id)



func build_waiting_matter(thing: Thing) -> bool:
	var animator: = thing.get_node_or_null("BuildAnimator") as BuildAnimator
	return animator != null and animator.waiting_matter



func build_stored(thing: Thing) -> bool:
	var animator: = thing.get_node_or_null("BuildAnimator") as BuildAnimator
	return animator != null and animator.stored



func debris_root() -> Node:
	if world == null:
		return null
	var arena: = world.get_node_or_null("Arena") as Arena
	return arena.destructibles if arena != null and arena.destructibles != null else world



func is_building(player_id: int) -> bool:
	return not (_builds.get(player_id, []) as Array).is_empty()




func is_assembling(player_id: int) -> bool:
	for thing: Thing in _builds.get(player_id, []):
		var animator: = thing.get_node_or_null("BuildAnimator") as BuildAnimator
		if animator != null and not animator.stored and not animator.waiting_matter:
			return true
	return false



func uses_of(player_id: int, recipe: Dictionary) -> int:
	return int(novelty_of(player_id, recipe)["uses"])




func _priced(player_id: int, recipe: Dictionary) -> Dictionary:
	if world == null or Lexicon.data.placement_for(String(recipe.get("thing", ""))) != "load":
		return recipe
	var player: = world.get_player(player_id)
	var weapon: Thing = player.hands.current_item() if player != null and player.hands != null else null
	return Cost.filled_magazine(recipe, weapon.node_data, Lexicon.data) if weapon != null else recipe


func cost_for(player_id: int, recipe: Dictionary) -> float:
	if recipe.is_empty():
		return 0.0
	return Cost.of(recipe, Lexicon.data) * float(novelty_of(player_id, recipe)["mult"])



func matter_for(player_id: int, recipe: Dictionary) -> float:
	var player: = world.get_player(player_id) if world != null else null
	if player == null:
		return 0.0
	var held: = player.hands.current_item()
	var from_hand: = held.matter if held != null and held.matter_returns and transmutes(recipe) else 0.0
	return player.matter_spendable() + from_hand






func transmutes(recipe: Dictionary) -> bool:
	if not recipe.has("thing"):
		return false
	return not Lexicon.data.placement_for(String(recipe["thing"])) in ["attach", "load"]




func _transmute_hand(player_id: int, recipe: Dictionary, cost: float) -> Dictionary:
	var player: = world.get_player(player_id) if world != null else null
	if player == null or not transmutes(recipe):
		return {}
	var held: = player.hands.current_item()
	if held == null:
		return {}
	var held_name: = Lexicon.data.thing_name(held.thing_id)
	var matter: = player.hands.dissolve_current()
	player.transmute(matter, cost)
	return {"transmuted": held_name, "transmuted_matter": matter}




func _command(player_id: int, command: String) -> Dictionary:
	var player: = world.get_player(player_id)
	if player == null:
		return {}
	var settings: Dictionary = Lexicon.data.defs.commands.get(command, {})
	if settings.has("animal_order"):
		return load("res://scripts/things/animal_orders.gd").request(player, settings)
	if settings.has("pokemon"):
		return load("res://scripts/things/pokemon_companion.gd").order(player, settings)
	match command:
		"expand_domain":
			var held := player.hands.current_item()
			var user = held.get_node_or_null("Jujutsu") if is_instance_valid(held) else null
			if user == null or not (user.powers.has("shrine") or user.powers.has("void")):
				return {"blocked": true, "warnings": ["Equipe o domínio do Gojo ou do Sukuna antes de expandir."]}
			if not player.can_act() or held.is_building or not user.expand_domain():
				return {"blocked": true, "warnings": ["Domínio indisponível: aguarde a montagem, a recarga ou o fim da amplificação."]}
			return {"domain_expanded": user.domain_mode}
		"recycle":
			var held: = player.hands.current_item()
			if held == null:
				return {"warnings": ["nada na mão pra reciclar"]}
			var held_name: = Lexicon.data.thing_name(held.thing_id)
			var matter: = player.hands.dissolve_current()
			var stored: = player.store_or_spill(matter)
			return {"recycled": held_name, "recycled_matter": matter, "spilled_matter": matter - stored}
	return {}



func builds(player_id: int) -> Array:
	return (_builds.get(player_id, []) as Array).duplicate()



func build_progress(thing: Thing) -> float:
	var animator: = thing.get_node_or_null("BuildAnimator") as BuildAnimator
	return animator.progress if animator != null else 1.0



func clear_player(player_id: int) -> void :
	cancel_draft(player_id)
	for thing: Thing in live_things(player_id):
		thing.remove()
	_explosion_times.erase(player_id)





func _materialize(player_id: int, recipe: Dictionary, build_s: float, cost: float, at: Vector3 = Vector3.INF, 
		forward: Vector3 = Vector3.ZERO) -> Array[String]:
	var player: = world.get_player(player_id)
	if player == null:
		return []
	if recipe.has("ability"):
		if player.queue_ability(String(recipe["ability"]), float(recipe["duration"]), cost):
			return []
		return ["habilidade '%s'" % recipe["ability"]]
	var notes: = Assembler.unsupported_in(recipe)
	var thing_id: = String(recipe["thing"])
	var placement: = Lexicon.data.placement_for(thing_id)
	match placement:
		"hand", "throwable":
			var item: = _build_for(player, recipe)
			player.hands.give(item, placement == "throwable")

			_start_build(item, build_s, placement != "throwable", cost)
		"aim_ground", "front", "flyover":
			_place_group(player, recipe, placement, build_s, cost, at, forward)
		"attach":
			if not _attach_to_hand(player, recipe, build_s, cost):
				notes.append("nada na mão pra prender o acessório: ele vai pra mão")
				var loose: = _build_for(player, recipe)
				player.hands.give(loose, true)
				_start_build(loose, build_s, false, cost)
		"load":
			if not _load_into_hand(player, recipe, build_s, cost):
				notes.append("sem arma de pente na mão: o pente vai pra mão")
				var spare: = _build_for(player, recipe)
				player.hands.give(spare, true)
				_start_build(spare, build_s, false, cost)
		_:
			notes.append("chegada '%s'" % placement)
			_place_group(player, recipe, "front", build_s, cost)
	return notes




func _load_into_hand(player: Player, recipe: Dictionary, build_s: float, cost: float) -> bool:
	var weapon: = player.hands.current_item()
	if weapon == null or weapon.magazine <= 0 or weapon.is_building or weapon.loading:
		return false
	var magazine: = _build_for(player, recipe)
	weapon.add_child(magazine)
	magazine.position = _magazine_spot(weapon)
	magazine.set_held(true)
	if player.is_local:
		Hands._set_layers(magazine, 1 << (Hands.OWN_WEAPON_LAYER - 1))
	weapon.loading = true
	weapon.ammo_changed.emit()
	_start_build(magazine, build_s, false, cost)
	var on_done: = _on_magazine_built.bind(magazine, weapon)
	build_finished.connect(on_done)
	magazine.removed.connect( func(_t: Thing) -> void :
		if build_finished.is_connected(on_done):
			build_finished.disconnect(on_done)
		if is_instance_valid(weapon) and weapon.loading:
			weapon.loading = false
			weapon.ammo_changed.emit())
	return true




func _attach_to_hand(player: Player, recipe: Dictionary, build_s: float, cost: float) -> bool:
	var target: = player.hands.current_item()
	if target == null or target.is_building:
		return false
	var gear: = _build_for(player, recipe)
	target.add_child(gear)
	var slot: = Lexicon.data.attachment_slot(String(recipe["thing"]))
	gear.position = (target.mounts.get(slot, Vector3.ZERO) as Vector3) * target.scale_factor
	gear.set_held(true)
	if player.is_local:
		Hands._set_layers(gear, 1 << (Hands.OWN_WEAPON_LAYER - 1))
	_start_build(gear, build_s, false, cost)
	var on_done: = _on_gear_built.bind(gear, target)
	build_finished.connect(on_done)
	gear.removed.connect( func(_t: Thing) -> void :
		if build_finished.is_connected(on_done):
			build_finished.disconnect(on_done))
	return true


func _on_gear_built(_player_id: int, built: Thing, gear: Thing, target: Thing) -> void :
	if built != gear or not is_instance_valid(gear) or gear.is_dead or gear.is_building:
		return
	if is_instance_valid(target) and not target.is_dead:
		target.add_attachment(gear.thing_id)
	gear.matter = 0.0
	gear.remove()


func _on_magazine_built(_player_id: int, built: Thing, magazine: Thing, weapon: Thing) -> void :
	if built != magazine or not is_instance_valid(magazine) or magazine.is_dead or magazine.is_building:
		return
	if is_instance_valid(weapon) and not weapon.is_dead:
		weapon.load_magazine(magazine.node_data)
	magazine.matter = 0.0
	magazine.remove()



func _magazine_spot(weapon: Thing) -> Vector3:
	for piece: MeshInstance3D in weapon.model_pieces:
		if String(piece.get_meta("tag", "")) == "magazine":
			return piece.position * weapon.scale_factor
	return Vector3(0.0, - weapon.bounds.size.y * 0.5, 0.0)


func _build_for(player: Player, recipe: Dictionary) -> Thing:
	var thing: = Assembler.build(recipe, "head", Lexicon.data)
	thing.set_owner_info(player.player_id, player.team, player, null)
	return thing




func _place_group(player: Player, recipe: Dictionary, placement: String, build_s: float, cost: float, 
		at: Vector3 = Vector3.INF, chosen_forward: Vector3 = Vector3.ZERO) -> void :
	var aim: = player.aim()
	var spot: Dictionary = placement_spot(player, placement)
	var forward: Vector3 = spot["forward"]
	var base: Vector3 = spot["base"]
	if at != Vector3.INF:

		base = at
		if chosen_forward.length_squared() > 0.0001:
			forward = chosen_forward.normalized()
	var up: Vector3 = spot["up"]
	if at != Vector3.INF:
		up = Gravity.up_at(base, up)
		forward = Gravity.flat(forward, up).normalized() if Gravity.flat(forward, up).length_squared() > 0.0001 else forward
	if placement == "flyover":
		var across: = forward.cross(up)
		var target: = ground_point(clamp_to_arena(aim["point"]))
		var count_over: = maxi(1, int((recipe.get("mods", {}) as Dictionary).get("count", 1)))
		for i in count_over:
			var plane: = _build_for(player, recipe)
			world.add_thing(plane)
			plane.move.arrive(target + forward * (i - (count_over - 1) * 0.5) * Lexicon.balf("actions.spawn.side_spacing") * 2.0, across)
			_register(plane)
			_start_build(plane, build_s, true, cost / count_over)
		return

	var count: = maxi(1, int((recipe.get("mods", {}) as Dictionary).get("count", 1)))
	var side: = forward.cross(up)
	for i in count:
		var thing: = _build_for(player, recipe)
		world.add_thing(thing)
		var offset: float = side_offsets(count, maxf(thing.bounds.size.x, thing.bounds.size.z))[i]
		var at_spot: = base + side * offset
		if thing.move.hovers():
			at_spot += up * Lexicon.balf("placement.hover_height")
		thing.global_position = at_spot
		thing.face(forward, true)
		_register(thing)
		_start_build(thing, build_s, true, cost / count)



func _start_build(thing: Thing, seconds: float, activate_after: bool, cost: float) -> void :
	if Session.is_online():
		Session.creations.prepare_creation(thing)
	for graft in thing.grafts:
		_register(graft)
	var player_id: = thing.owner_id
	(_builds.get_or_add(player_id, []) as Array).append(thing)
	thing.set_building(true)
	thing.removed.connect(_on_build_removed)
	var animator: = BuildAnimator.new()
	animator.name = "BuildAnimator"
	thing.add_child(animator)
	animator.finished.connect(_on_build_finished.bind(thing, activate_after))
	animator.payer = null if test_free_matter else thing.owner_player as Player
	animator.matter_cost = cost
	animator.seed = thing.build_seed


	thing.matter = cost if animator.payer == null else 0.0
	thing.matter_returns = true
	animator.start(thing, Lexicon.balf("build.micro_time") if test_instant_builds else seconds)
	build_started.emit(player_id, thing)
	if Session.is_online():
		Session.creations.publish_creation(thing, Lexicon.balf("build.micro_time") if test_instant_builds else seconds, activate_after, cost)


func _on_build_finished(thing: Thing, activate_after: bool) -> void :
	if not is_instance_valid(thing) or thing.is_dead:
		return
	(_builds.get(thing.owner_id, []) as Array).erase(thing)
	thing.set_building(false)
	if activate_after:
		thing.activate()
	build_finished.emit(thing.owner_id, thing)


func _on_build_removed(thing: Thing) -> void :
	var list: Array = _builds.get(thing.owner_id, [])
	if list.has(thing):
		list.erase(thing)
		build_finished.emit(thing.owner_id, thing)



func _appear(child: Thing) -> void :
	if String(Lexicon.bal("build.child_roles." + child.role, "instant")) == "micro":
		BuildAnimator.pop(child)



func _fail_in_front_of(player_id: int) -> void :
	var player: = world.get_player(player_id)
	if player == null:
		return
	var aim: = player.aim()
	var at: Vector3 = aim["origin"] + (aim["direction"] as Vector3) * Lexicon.balf("build.fail_distance")
	FailedBuild.spawn(world, at, Lexicon.data)


func _register(thing: Thing) -> void :
	var list: Array = _live.get_or_add(thing.owner_id, [])
	if list.has(thing):
		return


	if thing.role == "projectile" and not bool(Lexicon.bal("combat.projectiles_hit_own", false)):
		if thing.owner_player is PhysicsBody3D:
			thing.add_collision_exception_with(thing.owner_player)
		for other: Thing in list:
			if is_instance_valid(other) and not other.is_dead:
				thing.add_collision_exception_with(other)

	if not bool(Lexicon.bal("combat.projectiles_hit_own", false)):
		for other: Thing in list:
			if is_instance_valid(other) and not other.is_dead and other.role == "projectile":
				other.add_collision_exception_with(thing)
	if thing.mount_host != null:
		if thing.owner_player is PhysicsBody3D:
			thing.add_collision_exception_with(thing.owner_player)
		var host: = thing.mount_host
		while host != null:
			host.add_collision_exception_with(thing)
			thing.add_collision_exception_with(host)
			host = host.mount_host
	list.append(thing)
	if not thing.removed.is_connected(_on_thing_removed): thing.removed.connect(_on_thing_removed)
	stats["spawned"] += 1
	for graft in thing.grafts:
		_register(graft)
	var cap: = int(Lexicon.balf("caps.live_entities_per_player"))
	while cap > 0 and list.size() > cap:
		stats["evicted"] += 1
		(list[0] as Thing).remove()
	live_things_changed.emit(thing.owner_id)


func _on_thing_removed(thing: Thing) -> void :
	var list: Array = _live.get(thing.owner_id, [])
	list.erase(thing)
	if thing.network_replica:
		for graft: Thing in thing.grafts:
			if is_instance_valid(graft):
				_on_thing_removed(graft)
	live_things_changed.emit(thing.owner_id)




func _print_result(player_id: int, result: Dictionary) -> void :
	if result["ok"]:
		print("[Forge] p%d \"%s\" → %s" % [player_id, result["text"], result["pretty"]])
	else:
		print("[Forge] p%d \"%s\" → não entendi" % [player_id, result["text"]])
	if not (result["unknown_words"] as Array).is_empty():
		print("        desconhecidas: ", result["unknown_words"])
	if not (result["corrections"] as Array).is_empty():
		print("        correções: ", result["corrections"])
	if result["ok"]:
		print("        custo %.1f (base %.1f × novidade %.2f) · montagem %.2f s" % [result["cost"], result["base_cost"], result["novelty_mult"], result["build_s"]])
	if result.has("transmuted"):
		print("        transmutou %s: %.1f de matéria" % [result["transmuted"], result["transmuted_matter"]])
	if result.has("recycled"):
		print("        reciclou %s: %.1f de matéria" % [result["recycled"], result["recycled_matter"]])
	if not (result["unsupported"] as Array).is_empty():
		print("        ainda não funciona: ", result["unsupported"])



func _log_unknown_words(player_id: int, text: String, words: Array) -> void :
	var file: FileAccess
	if FileAccess.file_exists(UNKNOWN_WORDS_LOG):
		file = FileAccess.open(UNKNOWN_WORDS_LOG, FileAccess.READ_WRITE)
		if file != null:
			file.seek_end()
	else:
		file = FileAccess.open(UNKNOWN_WORDS_LOG, FileAccess.WRITE)
	if file == null:
		push_warning("[Forge] não consegui abrir %s" % UNKNOWN_WORDS_LOG)
		return
	var stamp: = Time.get_datetime_string_from_system()
	for word: String in words:
		file.store_line("%s\tp%d\t%s\t%s" % [stamp, player_id, word, text])
	file.close()
