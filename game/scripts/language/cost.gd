class_name Cost
extends RefCounted











static func of(tree: Dictionary, lex: LexiconData) -> float:
	if tree.is_empty():
		return 0.0
	if tree.has("ability"):
		return float(lex.bal("abilities.%s.cost" % tree["ability"], 0.0))
	if tree.has("command"):
		return 0.0
	return _node(tree, lex)



static func build_seconds(cost: float, lex: LexiconData) -> float:
	return minf(lex.balf("cost.build_base_s") + cost * lex.balf("cost.build_s_per_cost"), lex.balf("cost.build_max_s"))


static func _node(node: Dictionary, lex: LexiconData) -> float:
	var id: = String(node.get("thing", ""))
	var mods: Dictionary = node.get("mods", {})

	var stock_barrels: = maxi(1, int(lex.weapon_part(id, mods, "muzzle").get("barrels", 1)))

	var holds: = bool(lex.thing_def(id).get("holds", false))
	var size: = pow(float(mods.get("scale", 1.0)), lex.balf("cost.scale_exponent")) * float(mods.get("width", 1.0))\
	* float(mods.get("height", 1.0)) * float(mods.get("length", 1.0)) * float(mods.get("speed", 1.0))\
	* float(lex.barrels_of(id, mods)) / float(stock_barrels) * (1.0 if holds else maxf(1.0, float(mods.get("count", 1))))
	var total: = _base(id, mods, lex) * size
	if node.get("movement") != null:
		total += float(lex.bal("cost.movement." + String(node["movement"]), 0.0))
	total += float(lex.bal("cost.control." + String(node.get("control", "none")), 0.0))
	for key: String in mods:
		if key == "shield_profile":
			total += float(lex.bal("innovation.protection_costs." + String(mods[key]), 25.0)) * maxf(1.0, float(mods.get("count", 1)))
			continue
		if mods[key] is Dictionary or mods[key] is Array:
			continue
		total += float(lex.bal("cost.mods." + key, 0.0)) * (maxf(1.0, float(mods.get("count", 1))) if key == "diet" else 1.0)

	for gear: Variant in mods.get("attachments", []):
		total += lex.thing_statf(String(gear), "cost")
	for graft: Dictionary in mods.get("grafts", []):
		total += _node(graft["node"], lex) * maxf(1.0, float(mods.get("count", 1)))
	for behavior: Dictionary in node.get("behaviors", []):
		# Naming a queen's built-in nest production must not charge twelve nests upfront.
		# Its offspring are paid individually when the ecological component produces them.
		var ecology: Dictionary = lex.thing_def(id).get("ecology", {})
		var action: Dictionary = behavior.get("do", {})
		var child: Dictionary = action.get("arg", {}) if action.get("arg") is Dictionary else {}
		if action.get("type") == "spawn" and not child.is_empty() and child.get("thing") == ecology.get("produces") and child.get("mods", {}).is_empty() and child.get("behaviors", []).is_empty():
			continue
		total += _behavior(behavior, id, lex)
	total = minf(total, lex.balf("cost.max_node_cost"))

	if mods.get("mag") is Dictionary:
		total += _node(filled_magazine(mods["mag"], node, lex), lex)



	if mods.get("ammo") is Dictionary:
		var contents: Dictionary = (mods["ammo"] as Dictionary).duplicate(true)
		var rounds: = float((contents.get("mods", {}) as Dictionary).get("count", 0))
		(contents.get("mods", {}) as Dictionary).erase("count")
		total += _node(contents, lex) * (lex.balf("cost.magazine_rounds") + rounds * lex.balf("cost.magazine_round_share"))
	elif holds and mods.has("count"):
		total += float(mods["count"]) * lex.balf("cost.magazine_round_share") * lex.balf("cost.magazine_round_cost")
	return total




static func filled_magazine(mag: Dictionary, weapon: Dictionary, lex: LexiconData) -> Dictionary:
	var mods: Dictionary = mag.get("mods", {})
	if not mods.has("count") or mods.get("ammo") is Dictionary:
		return mag
	var projectile: = default_projectile(weapon, lex)
	if projectile.is_empty():
		return mag
	var out: Dictionary = mag.duplicate(true)
	(out["mods"] as Dictionary)["ammo"] = {"thing": projectile, "mods": {"count": mods["count"]}, "behaviors": [], 
		"control": "none", "movement": null}
	(out["mods"] as Dictionary).erase("count")
	return out



static func default_projectile(weapon: Dictionary, lex: LexiconData) -> String:
	if weapon.is_empty():
		return ""
	var source: = lex.behavior_source(weapon)
	for behavior: Dictionary in Assembler.merged_behaviors(weapon, lex.thing_def(source), {}):
		var act: Dictionary = behavior.get("do", {})
		if String((behavior.get("when", {}) as Dictionary).get("type", "")) == "on_fire" and act.get("arg") is Dictionary:
			return String((act["arg"] as Dictionary).get("thing", ""))
	return ""




static func _base(id: String, mods: Dictionary, lex: LexiconData) -> float:
	if not lex.is_weapon(id) or not mods.has("parts"):
		return lex.thing_statf(id, "cost")
	var total: = 0.0
	for section: String in LexiconData.WEAPON_SECTIONS:
		var source: = lex.part_source(id, mods, section)
		var share: = float(lex.bal("weapons._cost_share." + section, 1.0 / 3.0)) if lex.uses_weapon_section(source, mods, section) else 1.0
		total += share * lex.thing_statf(source, "cost")
	return total


static func _behavior(behavior: Dictionary, owner_id: String, lex: LexiconData) -> float:
	var when : Dictionary = behavior.get("when", {})
	var act: Dictionary = behavior.get("do", {})
	var trigger: = String( when .get("type", ""))
	var total: = float(lex.bal("cost.action_weight." + String(act.get("type", "")), 1.0))\
	* float(lex.bal("cost.trigger_factor." + trigger, 1.0))
	if act.get("arg") is Dictionary:
		total += _node(act["arg"], lex) * _expected_creations( when , owner_id, lex)
	return total



static func _expected_creations( when : Dictionary, owner_id: String, lex: LexiconData) -> float:
	var trigger: = String( when .get("type", ""))
	var count: = float(lex.bal("cost.expected_creations." + trigger, 1.0))
	if trigger == "every":
		count = lex.thing_statf(owner_id, "lifetime") / maxf(float( when .get("s", 1.0)), 0.05)
	return clampf(count, 1.0, lex.balf("cost.max_creations"))
