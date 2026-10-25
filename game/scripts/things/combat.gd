class_name Combat
extends RefCounted





const COMBATANTS_GROUP: = "combatants"


static func apply_damage(target: Object, amount: float, type: String, source: Thing, delivery: String = "") -> void :
	if target == null or not is_instance_valid(target) or amount <= 0.0 or not target.has_method("take_damage"):
		return
	if target is Thing and target.is_captured: return
	if not Forge.has_effect_authority() or (Session.is_online() and not (target is Thing or target is Player)):
		return
	if not InnovationRules.allows_target(source, target):
		return
	var order_owner = load("res://scripts/things/animal_orders.gd").of(source)
	if order_owner != null and order_owner.mode == "aggressive" and target == order_owner.thing.owner_player: return
	var final: = amount
	var combo := {}
	if type in ["water", "electric", "fire"] or delivery == "vine":
		combo = load("res://scripts/things/creature_combos.gd").prepare(target, source, type, delivery, amount)
		final += float(combo.get("bonus", 0.0))
	if source != null and target == source.owner_player:
		final *= Lexicon.balf("combat.self_damage_mult")
	final = JujutsuRules.damage(target, final, type, source)
	if final <= 0.0: return
	final = InnovationRules.protected_damage(target, final, type, source)
	var previous: Variant = target.get("health") if target is Player else target.get("hp") if target is Thing else null
	target.call("take_damage", final, type, source)
	if not is_instance_valid(target):
		return
	if source != null and previous != null:
		var current: Variant = target.get("health") if target is Player else target.get("hp")
		if current != null:
			var dealt := maxf(0.0, float(previous) - maxf(0.0, float(current)))
			if dealt > 0.0 and target is Player and source.owner_player != target and source.team != target.team:
				var attacker: Node3D = order_owner.thing if order_owner != null else source if source.category == "creature" else source.owner_player
				if is_instance_valid(attacker): target.set_meta("animal_last_attacker", {"source": weakref(attacker), "at": Time.get_ticks_msec()})
			load("res://scripts/things/pokemon_companion.gd").record_damage(source, target, dealt)
			if dealt > 0.0 and not combo.is_empty(): load("res://scripts/things/creature_combos.gd").landed(target, source, combo)
	_report_hit(target, final, source)
	if target is Node3D and (target as Node3D).is_in_group(COMBATANTS_GROUP):
		var node: = target as Node3D
		Fx.damage_number(Forge.fx_root(node), center_of(node) + Vector3.UP * 0.8, final)
	if source != null and not source.element.is_empty() and type != Status.BURN_DAMAGE and affects(source, target):
		var status: = String((Lexicon.data.elements.get(source.element, {}) as Dictionary).get("status", ""))
		if not status.is_empty():
			Status.apply(target, status, source, Lexicon.balf("status.element_hit_duration_mult"))



static func _report_hit(target: Object, amount: float, source: Thing) -> void :
	if source == null or not (target is Node3D) or not (target as Node3D).is_in_group(COMBATANTS_GROUP):
		return
	if target == source.owner_player or source.owner_id <= 0:
		return
	var left: Variant = target.get("health")
	if left == null:
		left = target.get("hp")
	Forge.hit_landed.emit(source.owner_id, target as Node, amount, left != null and float(left) <= 0.0)
	if Session.is_online():
		Session.creations.notify_fx("hit", [source.owner_id, amount, left != null and float(left) <= 0.0])




static func hit_structure(target: Object, point: Vector3, shape_index: int, amount: float, kind: String) -> bool:
	if target == null or not is_instance_valid(target) or not target.has_method("damage_at"):
		return false
	if not Forge.has_effect_authority():
		return true
	target.call("damage_at", point, amount * Lexicon.balf("combat.structure_%s_mult" % kind), shape_index)
	return true



static func affects(source: Thing, target: Object) -> bool:
	if not is_instance_valid(source) or target == source or not is_instance_valid(target):
		return false
	var orders = load("res://scripts/things/animal_orders.gd").of(source)
	if orders != null and orders.active() and not orders.allows(target): return false
	if orders != null and orders.mode == "aggressive": return InnovationRules.allows_target(source, target)
	if not InnovationRules.target_diet(source).is_empty():
		return InnovationRules.allows_target(source, target)
	if bool(Lexicon.bal("status.affects_own_team", false)):
		return true
	var team: Variant = target.get("team")
	return team == null or int(team) != source.team



static func in_radius(source: Thing, at: Vector3, radius: float) -> Array[Node3D]:
	var found: Array[Node3D] = []
	if radius <= 0.0 or not source.is_inside_tree():
		return found
	var shape: = SphereShape3D.new()
	shape.radius = radius
	var query: = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, at)
	query.collision_mask = PhysicsLayers.DAMAGEABLE
	query.exclude = [source.get_rid()]
	for hit: Dictionary in source.get_world_3d().direct_space_state.intersect_shape(query, 128):
		var node: = hit["collider"] as Node3D
		if node != null and not found.has(node):
			found.append(node)
	return found




static func floor_friction(body: CharacterBody3D) -> float:
	var friction: = 1.0
	for i in body.get_slide_collision_count():
		var contact: = body.get_slide_collision(i)
		var surface: = contact.get_collider() as Thing
		if surface != null and contact.get_normal().y > 0.6:
			friction = minf(friction, surface.surface_friction)
	return friction


static func surface_contacts(body: CharacterBody3D) -> void :
	for i in body.get_slide_collision_count():
		var contact: = body.get_slide_collision(i)
		var surface: = contact.get_collider() as Thing
		if surface != null:
			surface.surface_touch(body, contact.get_position(), - contact.get_normal())


static func impulse(source: Thing, at: Vector3, radius: float, strength: float, lift: float) -> void :
	Fx.ring(Forge.fx_root(source), at, radius, explosion_color(source.element), strength < 0.0)
	for target in in_radius(source, at, radius):
		if not affects(source, target):
			continue
		var offset: = center_of(target) - at
		var falloff: = 1.0 - clampf(offset.length() / radius, 0.0, 1.0)
		var up: = Gravity.up_at(center_of(target), source.up())
		var dir: = offset.normalized() if offset.length_squared() > 0.0001 else up
		var push: = (dir * signf(strength) + up * lift).normalized() * absf(strength) * falloff * InnovationRules.force_multiplier(target, source)
		if target.has_method("apply_knockback"):
			target.call("apply_knockback", push)
		elif target is Thing:
			(target as Thing).nudge(push)



static func area_status(source: Thing, at: Vector3, radius: float, kind: String) -> void :
	var element: = String(Lexicon.bal("status.%s.element" % kind, ""))
	var tint: = Color.from_string(String((Lexicon.data.elements.get(element, {}) as Dictionary).get("tint", "#ffffff")), Color.WHITE)
	Fx.ring(Forge.fx_root(source), at, radius, tint, false)
	for target in in_radius(source, at, radius):
		if affects(source, target):
			Status.apply(target, kind, source)




static func explode(source: Thing, at: Vector3, radius: float, damage: float, damage_type: String = "explosive") -> void :
	if radius <= 0.0 or not source.is_inside_tree():
		return
	var scene: = Forge.fx_root(source)
	if not Forge.allow_explosion(source.owner_id):
		Fx.explosion(scene, at, radius * 0.25, Color(0.6, 0.6, 0.6))
		return
	Fx.explosion(scene, at, radius, explosion_color(source.element))
	Forge.explosion_at.emit(at, radius, damage)
	if Session.is_online():
		Session.creations.notify_fx("blast", [at, radius, damage])

	var shape: = SphereShape3D.new()
	shape.radius = radius
	var query: = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, at)
	query.collision_mask = PhysicsLayers.DAMAGEABLE
	query.exclude = [source.get_rid()]
	var min_falloff: = Lexicon.balf("combat.explosion_min_falloff")
	var knockback: = Lexicon.balf("combat.explosion_knockback") * source.scale_factor
	var seen: = {}
	var hits := []
	for found: Dictionary in source.get_world_3d().direct_space_state.intersect_shape(query, 128):
		var target: Object = found["collider"]
		if target == null or seen.has(target):
			continue
		seen[target] = true
		var target_center: = center_of(target as Node3D)
		var falloff: = lerpf(1.0, min_falloff, clampf(target_center.distance_to(at) / radius, 0.0, 1.0))
		var push: = (target_center - at).normalized() + Gravity.up_at(target_center, source.up()) * 0.3
		hits.append({"target": weakref(target), "damage": damage * falloff, "push": push.normalized() * knockback * falloff})
	# Physics queries have a result cap; include every creation touched by a crowded blast.
	if Forge.world != null:
		for candidate in Forge.world.get_node("Things").get_children():
			var target := candidate as Thing
			if target == null or target == source or target.is_dead or seen.has(target): continue
			var box: AABB = target.global_transform * target.bounds
			if at.distance_to(at.clamp(box.position, box.end)) > radius: continue
			var center := target.center()
			var falloff := lerpf(1.0, min_falloff, clampf(center.distance_to(at) / radius, 0.0, 1.0))
			hits.append({"target": weakref(target), "damage": damage * falloff, "push": Vector3.ZERO})
	for row: Dictionary in hits: row["type"] = damage_type
	if hits.size() > 12:
		var work = load("res://scripts/things/blast_work.gd").new()
		work.setup(source, hits)
		source.get_tree().root.add_child(work)
	else:
		for row: Dictionary in hits:
			var target = row.target.get_ref()
			if not is_instance_valid(target): continue
			apply_damage(target, row.damage, damage_type, source)
			if is_instance_valid(target) and target.has_method("apply_knockback"): target.call("apply_knockback", row.push)
	_crater(source, at, radius, damage)




static func _crater(source: Thing, at: Vector3, radius: float, damage: float) -> void :
	for node in source.get_tree().get_nodes_in_group(BlockVolume.GROUP):
		var volume: = node as BlockVolume
		volume.explode(at, radius, damage * volume.explosion_mult)



static func nearest_target(source: Thing, from: Vector3, tree: SceneTree) -> Node3D:
	var orders = load("res://scripts/things/animal_orders.gd").of(source)
	if orders != null and orders.active(): return orders.combat_target()
	var diet := InnovationRules.target_diet(source)
	if diet.is_empty(): return nearest_enemy(from, source.team, tree)
	if Forge.world == null: return null
	var best: Thing
	var distance := INF
	for candidate in Forge.world.get_node("Things").get_children():
		var other := candidate as Thing
		if other == null or other == source or other.is_dead or other.is_held or not InnovationRules.matches_diet(other, diet): continue
		var current := center_of(other).distance_squared_to(from)
		if current < distance:
			best = other
			distance = current
	return best


static func nearest_enemy(from: Vector3, team: int, tree: SceneTree) -> Node3D:
	if tree == null:
		return null
	var best: Node3D = null
	var best_dist: = INF
	for node in tree.get_nodes_in_group(COMBATANTS_GROUP):
		var other: = node as Node3D
		if other == null or int(other.get("team")) == team or not other.call("is_alive"):
			continue
		var dist: = center_of(other).distance_squared_to(from)
		if dist < best_dist:
			best_dist = dist
			best = other
	return best


static func center_of(node: Node3D) -> Vector3:
	if node == null:
		return Vector3.ZERO
	if node.has_method("center"):
		return node.call("center")
	return node.global_position


static func explosion_color(element: String) -> Color:
	var table: Dictionary = Lexicon.data.elements
	var entry: Dictionary = table.get(element, table.get("_none", {}))
	return Color.from_string(String(entry.get("explosion", "#ffb347")), Color.ORANGE)
