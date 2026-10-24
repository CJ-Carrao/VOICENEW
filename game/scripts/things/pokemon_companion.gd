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

func setup(owner_thing: Thing, settings: Dictionary) -> void:
	thing = owner_thing
	pokemon_id = settings.id
	element = settings.element
	moves = settings.moves

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
	var skill: Dictionary = moves[move]
	var target := _target(float(skill.range) * clampf(thing.scale_factor, .6, 1.5))
	if target == null: return {"blocked": true, "warnings": ["Nenhum alvo válido à vista e ao alcance de " + String(skill.name) + "."]}
	remaining = float(skill.cooldown)
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
	Combat.apply_damage(target, float(skill.damage) * clampf(thing.power, .25, 2.0) * multiplier, String(skill.element), thing)
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
		var rank: float = d + (1000.0 if companion.remaining > 0.0 else 0.0)
		if rank < distance:
			distance = rank
			selected = companion
	if selected == null: return {"blocked": true, "warnings": ["Invoque ou solte da Pokébola um " + String(settings.pokemon).capitalize() + " seu por perto antes de comandar."]}
	return selected.cast(String(settings.move))
