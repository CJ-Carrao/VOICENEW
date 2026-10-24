class_name InnovationRules
extends RefCounted


static func profile(node: Dictionary, lex: LexiconData) -> String:
	return String(node.get("mods", {}).get("shield_profile", lex.thing_def(String(node.get("thing", ""))).get("shield_profile", "")))


static func authorize_spawn(source: Thing, node: Dictionary) -> bool:
	if not is_instance_valid(source):
		return false
	var lex := Lexicon.data
	var id := String(node.get("thing", ""))
	var def := lex.thing_def(id)
	var owner_def := lex.thing_def(source.thing_id)
	var ecology: Dictionary = owner_def.get("ecology", {})
	var protected := not profile(node, lex).is_empty()
	var managed := protected or def.has("ecology") or not ecology.is_empty()
	if not managed:
		return true
	var count := 0
	if Forge.world != null:
		for candidate in Forge.world.get_node("Things").get_children():
			var item := candidate as Thing
			if item == null or item.is_dead or item.is_held:
				continue
			if protected and item.team == source.team and not profile(item.node_data, lex).is_empty():
				count += 1
			elif not protected and item.thing_id == id and item.spawner == source:
				count += 1
	var cap := 3 if protected else int(ecology.get("local_cap", 1 if id.ends_with("nest") else 8))
	if not protected and String(def.get("category", "")) == "creature":
		cap = 0
	if cap > 0 and count >= cap:
		return false
	var player := source.owner_player as Player
	if player == null or not player.is_alive():
		return false
	var cost := Cost.of(node, lex)
	if player.matter_spendable() + 0.0001 < cost:
		return false
	player.take_matter(cost)
	return true


static func tags(thing: Thing) -> Array:
	return Lexicon.data.thing_def(thing.thing_id).get("ecology_tags", [])

static func matches_diet(thing: Thing, diet: String) -> bool:
	if diet == "creature":
		return thing.category == "creature"
	if diet.begins_with("species:"):
		return thing.thing_id == diet.trim_prefix("species:")
	return tags(thing).has(diet)


static func target_diet(source: Thing) -> String:
	# Mounted weapons and their projectiles obey the carrier's species restriction.
	var cursor := source
	var seen := {}
	while is_instance_valid(cursor) and not seen.has(cursor.get_instance_id()):
		seen[cursor.get_instance_id()] = true
		if not cursor.target_filter.is_empty(): return cursor.target_filter
		var diet := String(cursor.node_data.get("mods", {}).get("diet", Lexicon.data.thing_def(cursor.thing_id).get("diet", "")))
		if not diet.is_empty() or cursor.category == "creature": return diet
		cursor = cursor.mount_host if is_instance_valid(cursor.mount_host) else cursor.spawner as Thing
	return ""


static func allows_target(source: Thing, target: Object) -> bool:
	var diet := target_diet(source)
	return diet.is_empty() or (target is Thing and target != source and matches_diet(target, diet))


static func threat(source: Thing, damage_type: String) -> String:
	if damage_type in ["neutron", "gravity", "spatial"]:
		return damage_type
	if is_instance_valid(source):
		var specific := String(Lexicon.data.thing_def(source.thing_id).get("threat_type", ""))
		if not specific.is_empty():
			return specific
	return "blast" if damage_type == "explosive" else damage_type


static func multiplier(shield_profile: String, kind: String) -> float:
	var table: Dictionary = Lexicon.bal("innovation.resistance." + shield_profile, {})
	return clampf(float(table.get(kind, 1.0)), 0.10, 1.0)


static func _best(target: Node3D, kind: String):
	var best
	var value := 1.0
	var team: Variant = target.get("team")
	if team == null:
		return null
	for node in target.get_tree().get_nodes_in_group("protective_fields"):
		var shield := node.get_parent() as Thing
		if shield == null or shield.is_dead or shield.is_building or not shield.is_active or shield.team != int(team):
			continue
		var current := multiplier(String(node.profile_id), kind)
		if current < value and shield.center().distance_to(Combat.center_of(target)) <= float(node.radius):
			value = current
			best = node
	return best


static func protected_damage(target: Object, amount: float, kind: String, source: Thing) -> float:
	if not target is Node3D or kind == "shield_strain":
		return amount
	var field = _best(target as Node3D, threat(source, kind))
	if field == null:
		return amount
	var factor := multiplier(String(field.profile_id), threat(source, kind))
	var shield := field.get_parent() as Thing
	var saved := amount * (1.0 - factor)
	if shield != target:
		# Held shields have real durability too; normal held-item immunity must not bypass wear.
		shield.hp -= saved * float(Lexicon.bal("innovation.shield_wear", 0.70))
		if shield.hp <= 0.0:
			shield.die()
	field.feedback()
	return amount * factor


static func force_multiplier(target: Node3D, source: Thing) -> float:
	var kind := String(Lexicon.data.thing_def(source.thing_id).get("threat_type", "gravity")) if is_instance_valid(source) else "gravity"
	var field = _best(target, kind)
	return multiplier(String(field.profile_id), kind) if field != null else 1.0
