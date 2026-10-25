extends Node

var thing: Thing
var pokemon_id := ""
var element := ""
var moves := {}
var remaining := 0.0
var last_move := ""
var casts := 0
var dash_left := 0.0
var dash_direction := Vector3.ZERO
var experience := 0.0
var evolution := {}

func setup(owner_thing: Thing, settings: Dictionary) -> void:
	thing = owner_thing
	pokemon_id = settings.id
	element = settings.element
	moves = settings.moves
	evolution = settings.get("evolution", {})

func _ready() -> void: add_to_group("pokemon_companions")

func _physics_process(delta: float) -> void:
	if thing.is_active and not thing.is_captured: remaining = maxf(0.0, remaining - delta)
	if dash_left > 0.0 and available():
		dash_left = maxf(0.0, dash_left - delta)
		thing.move.travel(dash_direction * minf(delta, .05) * 14.0)

func available() -> bool:
	return is_instance_valid(thing) and thing.is_active and not thing.is_building and not thing.is_held and not thing.is_captured and not thing.is_dead and thing.can_act()

func _visible_target(target: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(thing.center(), Combat.center_of(target), PhysicsLayers.WORLD, [thing.get_rid()])
	return thing.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _target(reach: float) -> Node3D:
	var best: Node3D
	var score := INF
	var ray: Dictionary = thing.owner_player.look_ray() if is_instance_valid(thing.owner_player) and thing.owner_player.has_method("look_ray") else {}
	for target in Combat.in_radius(thing, thing.center(), reach):
		if not is_instance_valid(target) or not target.has_method("take_damage") or not Combat.affects(thing, target): continue
		if target.has_method("is_alive") and not target.is_alive(): continue
		if target is Thing and (target.is_dead or target.is_captured or target.category not in ["creature", "vehicle"]): continue
		var at := Combat.center_of(target)
		var distance := thing.center().distance_to(at)
		if distance > reach or not _visible_target(target): continue
		var value := distance
		if not ray.is_empty():
			var alignment := (at - (ray.origin as Vector3)).normalized().dot(ray.direction)
			value += (1.0 - alignment) * 8.0
		if value < score:
			score = value
			best = target
	return best

func cast(move: String) -> Dictionary:
	if not available() or not moves.has(move): return {"blocked": true, "warnings": ["Pokémon indisponível para atacar."]}
	if remaining > 0.0: return {"blocked": true, "warnings": ["Aguarde %.1f s para outro golpe." % remaining]}
	var fusion = thing.get_node_or_null("FusionPowers")
	if fusion != null and fusion.companions.is_empty(): fusion = null
	if fusion != null and fusion.remaining > 0.0: return {"blocked":true,"warnings":["A fusão está recarregando seus poderes."]}
	var skill: Dictionary = moves[move]
	var target := _target(float(skill.range) * clampf(thing.scale_factor, .6, 1.5))
	if target == null: return {"blocked": true, "warnings": ["Nenhum alvo válido à vista e ao alcance de " + String(skill.name) + "."]}
	remaining = float(skill.cooldown)
	if fusion != null: fusion.remaining = maxf(2.5,remaining)
	last_move = move
	casts += 1
	var at := Combat.center_of(target)
	var origin := thing.center()
	if skill.style == "quick":
		dash_direction = Gravity.flat(at - origin, thing.up()).normalized()
		dash_left = minf(.18, maxf(0.0, origin.distance_to(at) - 1.0) / 14.0)
	var target_power := target.get_node_or_null("PokemonCompanion")
	var multiplier := 1.0
	if target_power != null:
		var advantage := {"electric": "water", "fire": "grass", "water": "fire", "grass": "water"}
		if advantage.get(skill.element, "") == target_power.element: multiplier = 1.5
		elif skill.element == target_power.element and skill.element != "normal": multiplier = .65
		elif advantage.get(target_power.element, "") == skill.element: multiplier = .7
	var previous: Variant = target.get("health")
	if previous == null: previous = target.get("hp")
	Combat.apply_damage(target, float(skill.damage) * clampf(thing.power, .25, 2.0) * multiplier, String(skill.element), thing, String(skill.style))
	if is_instance_valid(target):
		var current: Variant = target.get("health")
		if current == null: current = target.get("hp")
		if previous != null and current != null and float(current) < float(previous) and skill.element == "fire": Status.apply(target, "burning", thing, .35)
	load("res://scripts/fx/pokemon_fx.gd").play(Forge.fx_root(thing), origin, at, String(skill.style), String(skill.name))
	return {"pokemon_order": pokemon_id, "pokemon_move": move, "pokemon_network_id": thing.network_id}

static func order(player: Node3D, settings: Dictionary) -> Dictionary:
	if not player.can_act(): return {"blocked": true, "warnings": ["Você não pode comandar agora."]}
	var selected: Node
	var distance := INF
	for companion in player.get_tree().get_nodes_in_group("pokemon_companions"):
		if not companion.available() or companion.pokemon_id != settings.pokemon or companion.thing.owner_id != player.player_id or companion.thing.team != player.team: continue
		var d: float = companion.thing.global_position.distance_to(player.global_position)
		if d > 60.0: continue
		# Prefer a ready companion, then the nearest one; a single order never fires a whole swarm.
		var rank: float = d + (1000.0 if not settings.has("pokemon_action") and companion.remaining > 0.0 else 0.0)
		if rank < distance:
			distance = rank
			selected = companion
	if selected == null: return {"blocked": true, "warnings": ["Invoque ou solte da Pokébola um " + String(settings.pokemon).capitalize() + " seu por perto antes de comandar."]}
	if settings.get("pokemon_action") == "progress": return {"warnings": [selected.progress_text()]}
	if settings.get("pokemon_action") == "evolve": return selected.evolve(player)
	return selected.cast(String(settings.move))

func progress_text() -> String:
	var title := Lexicon.data.thing_name(pokemon_id)
	if String(evolution.get("next", "")).is_empty(): return "%s: forma final · %.0f XP." % [title, experience]
	return "%s: %.0f/%.0f XP · evolução para %s custa %.0f de matéria. Diga: %s, evolua." % [title, experience, float(evolution.xp), Lexicon.data.thing_name(evolution.next), float(evolution.cost), title]

func evolve(player: Node3D) -> Dictionary:
	var temporary = thing.get_node_or_null("CreativeEffects")
	if temporary != null and (temporary.head_time > 0.0 or temporary.team_time > 0.0): return {"blocked":true,"warnings":["Aguarde o fim da troca temporária antes de evoluir."]}
	if not available() or not thing.has_simulation_authority() or player.player_id != thing.owner_id or player.team != thing.team:
		return {"blocked": true, "warnings": ["Pokémon indisponível para evoluir."]}
	var next := String(evolution.get("next", ""))
	if next.is_empty() or experience < float(evolution.xp): return {"blocked": true, "warnings": [progress_text()]}
	var price := float(evolution.cost)
	if not player.try_spend(price): return {"blocked": true, "warnings": [progress_text() + " Matéria insuficiente."]}
	experience -= float(evolution.xp)
	change_form(next)
	# Paid matter stays with this same individual; no free healing or duplicate creature.
	thing.matter += price
	ExpansionFx.burst(Forge.fx_root(thing), thing.center(), 1.8, Color("f5e2a0"), "evolution")
	return {"pokemon_evolved": next, "evolution_cost": price, "warnings": ["Evoluiu para " + Lexicon.data.thing_name(next) + ". " + progress_text()]}

func change_form(next: String) -> void:
	var settings: Dictionary = Lexicon.data.thing_def(next).get("pokemon", {})
	if settings.is_empty() or next == pokemon_id: return
	var ratio := clampf(thing.hp / maxf(thing.max_hp, .001), 0.0, 1.0)
	var original := thing.thing_id
	var mods: Dictionary = thing.node_data.get_or_add("mods", {})
	var anatomy: Dictionary = mods.get("anatomy", {})
	if anatomy.get("head") == pokemon_id:
		anatomy.head = next
	elif original == pokemon_id:
		thing.node_data.thing = next
		thing._def = Lexicon.data.thing_def(next)
	else: return
	var was_automatic := thing.automatic
	thing.rebuild_equipment_model()
	thing.hp = thing.max_hp * ratio
	thing.automatic = was_automatic
	if anatomy.has("legs"): thing.speed = Lexicon.data.thing_statf(String(anatomy.legs), "speed") * float(mods.get("speed", 1.0))
	# Existing grafts and gameplay components remain the same objects, keeping their timers.
	var motion = thing.get_node_or_null("VoxelCreatureMotion")
	if motion != null:
		motion.parts.clear()
		motion.setup(thing, bool(thing._def.get("aerial", false)) or anatomy.has("wings"))
	var role_def: Dictionary = thing._def.get("roles", {}).get(thing.role, {})
	var movement := Assembler.movement_id(thing.node_data, thing._def, role_def, thing.role, Lexicon.data)
	if original == pokemon_id and movement == "fly" and not thing.move.hovers():
		var old_move := thing.move
		thing.remove_child(old_move)
		old_move.queue_free()
		var new_move: ThingMove = Assembler.MOVES.fly.new()
		new_move.name = "Move"
		new_move.setup(thing, Lexicon.data)
		thing.attach_move(new_move)
		if thing.network_replica: new_move.set_physics_process(false)
	setup(thing, settings)

func snapshot() -> Dictionary:
	return {"id": pokemon_id, "xp": experience, "remaining": remaining, "last_move": last_move, "casts": casts}

func apply_snapshot(values: Dictionary) -> void:
	var next := String(values.get("id", pokemon_id))
	# Only forward steps in this family are accepted, including a skipped intermediate snapshot.
	var cursor := pokemon_id
	for step in 3:
		if cursor == next: break
		cursor = String(Lexicon.data.thing_def(cursor).get("pokemon", {}).get("evolution", {}).get("next", ""))
	if cursor != next: return
	change_form(next)
	experience = clampf(float(values.get("xp", 0.0)), 0.0, 1000.0)
	remaining = maxf(0.0, float(values.get("remaining", 0.0)))
	last_move = String(values.get("last_move", ""))
	casts = int(values.get("casts", 0))

static func record_damage(source: Thing, target: Object, damage: float) -> void:
	if not is_instance_valid(source) or not is_instance_valid(target) or damage <= 0.0 or not (target is Thing or target is Player): return
	if target is Thing and (target.category != "creature" or target.is_held or target.is_captured): return
	var cursor := source
	var seen := {}
	for step in 8:
		if not is_instance_valid(cursor) or seen.has(cursor.get_instance_id()): return
		seen[cursor.get_instance_id()] = true
		var companion = cursor.get_node_or_null("PokemonCompanion")
		if companion != null:
			if cursor.is_dead or cursor.is_captured or cursor.is_building or not cursor.is_active or cursor.owner_id <= 0: return
			if target == cursor or target.get("team") == cursor.team or target.get("owner_id") == cursor.owner_id or target == cursor.owner_player: return
			var paid: Dictionary = target.get_meta("pokemon_xp_paid", {})
			var key := cursor.get_instance_id()
			if not paid.has(key) and paid.size() >= 64: return
			var earned := minf(damage * .25, maxf(0.0, 60.0 - float(paid.get(key, 0.0))))
			paid[key] = float(paid.get(key, 0.0)) + earned
			target.set_meta("pokemon_xp_paid", paid)
			companion.experience = minf(1000.0, companion.experience + earned)
			return
		cursor = cursor.mount_host if is_instance_valid(cursor.mount_host) else cursor.spawner as Thing
