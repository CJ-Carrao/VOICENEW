extends RefCounted

# At most three different donors can contribute skills; repeated parts never stack.
static func donors(node: Dictionary, lex: LexiconData) -> Array[String]:
	var result: Array[String] = []
	if lex.category_of(String(node.get("thing", ""))) != "creature": return result
	var mods: Dictionary = node.get("mods", {})
	var candidates: Array = []
	for part in ["head", "body", "wings", "tail", "legs"]:
		var donor = String(mods.get("anatomy", {}).get(part, ""))
		if not donor.is_empty(): candidates.append(donor)
	for key: String in mods:
		if key.begins_with("fusion_") and mods[key] == true: candidates.append(key.trim_prefix("fusion_"))
	for donor: String in candidates:
		var def: Dictionary = lex.thing_def(donor)
		if donor == node.thing or result.has(donor): continue
		if def.get("pokemon", {}).is_empty() and def.get("jujutsu", {}).is_empty() and not def.get("fusion_behaviors",false): continue
		result.append(donor)
		if result.size() == 3: break
	return result

static func price(node: Dictionary, lex: LexiconData) -> float:
	var total = 0.0
	for donor in donors(node, lex): total += maxf(35.0, lex.thing_statf(donor, "cost") * .6)
	return total * maxf(1.0, float(node.get("mods", {}).get("count", 1)))

static func describe(node: Dictionary, lex: LexiconData) -> String:
	var names = PackedStringArray()
	for donor in donors(node, lex): names.append(lex.thing_name(donor))
	return "" if names.is_empty() else "Poderes herdados: %s (+%.0f de matéria)." % [", ".join(names), price(node,lex)]
