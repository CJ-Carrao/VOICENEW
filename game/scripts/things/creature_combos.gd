extends RefCounted

static var count := 0
static var last_reaction := ""

static func _carrier(source: Thing) -> Thing:
	var cursor := source
	var seen := {}
	for step in 8:
		if not is_instance_valid(cursor) or seen.has(cursor.get_instance_id()): return null
		seen[cursor.get_instance_id()] = true
		if cursor.category == "creature": return cursor
		cursor = cursor.mount_host if is_instance_valid(cursor.mount_host) else cursor.spawner as Thing
	return null

static func prepare(target: Object, source: Thing, kind: String, delivery: String, amount: float) -> Dictionary:
	if not target is Thing or target.category != "creature" or target.is_dead or target.is_captured or target.is_held: return {}
	var carrier := _carrier(source)
	if carrier == null or carrier.is_captured or carrier.is_dead or carrier.team == target.team or target.owner_id == carrier.owner_id: return {}
	if not InnovationRules.allows_target(source, target): return {}
	var status := Status.of(target)
	var active: Dictionary = status.remaining if status != null else {}
	var plan := {"reaction": "", "bonus": 0.0, "seed": "", "consume": "", "lock": ""}
	if kind == "water": plan.seed = "wet"
	if delivery == "vine" and kind == "grass" and float(active.get("combo_vine_lock", 0.0)) <= 0.0: plan.seed = "entangled"
	if kind == "electric" and float(active.get("wet", 0.0)) > 0.0 and float(active.get("combo_shock_lock", 0.0)) <= 0.0:
		plan.merge({"reaction": "conductive", "consume": "wet", "lock": "combo_shock_lock", "bonus": minf(amount * Lexicon.balf("creature_combos.shock_mult"), Lexicon.balf("creature_combos.shock_bonus_cap"))}, true)
	elif kind == "fire" and float(active.get("entangled", 0.0)) > 0.0 and float(active.get("combo_fire_lock", 0.0)) <= 0.0:
		plan.merge({"reaction": "vine_fire", "consume": "entangled", "lock": "combo_fire_lock", "bonus": minf(amount * Lexicon.balf("creature_combos.fire_mult"), Lexicon.balf("creature_combos.fire_bonus_cap"))}, true)
	return plan

static func landed(target: Thing, source: Thing, plan: Dictionary) -> void:
	if plan.is_empty() or not is_instance_valid(target) or target.is_captured: return
	if not target.is_dead and not String(plan.seed).is_empty():
		Status.apply(target, String(plan.seed), source)
		if plan.seed == "entangled":
			Status.apply(target, "combo_vine_lock", source)
			target.velocity = Vector3.ZERO
	if String(plan.reaction).is_empty(): return
	Status.remove_effect(target, String(plan.consume))
	Status.apply(target, String(plan.lock), source)
	count += 1
	last_reaction = String(plan.reaction)
	load("res://scripts/fx/pokemon_fx.gd").play(Forge.fx_root(target), target.center(), target.center(), last_reaction, "Água + eletricidade" if last_reaction == "conductive" else "Cipós + fogo")
