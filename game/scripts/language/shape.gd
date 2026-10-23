class_name Shape
extends RefCounted










static func dims_of(recipe: Dictionary, lex: LexiconData) -> Dictionary:
	var mods: Dictionary = recipe.get("mods", {})
	var out: = {}
	for dim: String in dim_ids(lex):
		out[dim] = float(mods.get(dim, 1.0))
	return out


static func dim_ids(lex: LexiconData) -> PackedStringArray:
	return PackedStringArray(lex.shaping_rules.get("dims", ["scale", "width", "height", "length"]))





static func focus(recipe: Dictionary, lex: LexiconData) -> String:
	var dims: = dims_of(recipe, lex)
	var ids: = dim_ids(lex)
	for i in range(ids.size() - 1, -1, -1):
		if not is_equal_approx(float(dims[ids[i]]), 1.0):
			return ids[i]
	return ids[0] if not ids.is_empty() else "scale"




static func needs_shaping(recipe: Dictionary, lex: LexiconData) -> bool:
	if recipe.is_empty() or not recipe.has("thing"):
		return false
	var placement: = lex.placement_for(String(recipe["thing"]))
	if (lex.shaping_rules.get("always", []) as Array).has(placement):
		return true
	if not (lex.shaping_rules.get("when_sized", []) as Array).has(placement):
		return false
	var dims: = dims_of(recipe, lex)
	for dim: String in dims:
		if not is_equal_approx(float(dims[dim]), 1.0):
			return true
	return false



static func clamp_dim(dim: String, value: float, lex: LexiconData) -> float:
	var snap: = lex.balf("shaping.snap")
	var low: = float(lex.bal("shaping.min." + dim, 0.1))
	var high: = float(lex.bal("shaping.max." + dim, 10.0))
	var clamped: = clampf(value, low, high)
	return clampf(snappedf(clamped, snap), low, high) if snap > 0.0 else clamped




static func apply(recipe: Dictionary, dims: Dictionary, lex: LexiconData) -> Dictionary:
	var out: Dictionary = recipe.duplicate(true)
	if not out.has("thing"):
		return out
	var mods: Dictionary = out.get_or_add("mods", {})
	var old_scale: = float(mods.get("scale", 1.0))
	for dim: String in dim_ids(lex):
		if not dims.has(dim):
			continue
		var value: = clamp_dim(dim, float(dims[dim]), lex)
		if is_equal_approx(value, 1.0):
			mods.erase(dim)
		else:
			mods[dim] = value
	var ratio: = float(mods.get("scale", 1.0)) / maxf(old_scale, 0.0001)
	if not is_equal_approx(ratio, 1.0):
		for behavior: Dictionary in out.get("behaviors", []):
			var act: Dictionary = behavior.get("do", {})
			if lex.action_def(String(act.get("type", ""))).get("projectile", false) and act.get("arg") is Dictionary:
				var arg_mods: Dictionary = (act["arg"] as Dictionary).get_or_add("mods", {})
				arg_mods["scale"] = float(arg_mods.get("scale", 1.0)) * ratio
	return out



static func volume_factor(mods: Dictionary, exponent: float) -> float:
	return pow(float(mods.get("scale", 1.0)), exponent) * float(mods.get("width", 1.0))\
	* float(mods.get("height", 1.0)) * float(mods.get("length", 1.0))
