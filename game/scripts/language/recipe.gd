class_name Recipe
extends RefCounted









static func new_node(thing: String) -> Dictionary:
	return {"thing": thing, "mods": {}, "control": "none", "movement": null, "behaviors": []}



static func from_data(data: Dictionary) -> Dictionary:
	var node: = new_node(String(data.get("thing", "")))
	node["mods"] = (data.get("mods", {}) as Dictionary).duplicate(true)
	for graft: Dictionary in (node["mods"] as Dictionary).get("grafts", []):
		graft["node"] = from_data(graft["node"])
	node["control"] = data.get("control", "none")
	node["movement"] = data.get("movement", null)
	for behavior: Dictionary in data.get("behaviors", []):
		(node["behaviors"] as Array).append(behavior_from_data(behavior))
	return node


static func behavior_from_data(data: Dictionary) -> Dictionary:
	var act: = (data.get("do", {}) as Dictionary).duplicate(true)
	if act.get("arg") is Dictionary:
		act["arg"] = from_data(act["arg"])
	return {"when": (data.get("when", {}) as Dictionary).duplicate(true), "do": act}



static func set_mod(node: Dictionary, def: Dictionary, value: Variant) -> void :
	var key: = String(def.get("key", ""))
	if key == "movement" or key == "control":
		node[key] = value
		return
	var mods: Dictionary = node["mods"]
	if def.get("mode", "set") == "mul":
		mods[key] = float(mods.get(key, 1.0)) * float(value)
	else:
		mods[key] = value




static func compact(value: Variant) -> Variant:
	if value is Dictionary:
		var out: = {}
		for key: Variant in value:
			var item: Variant = value[key]
			if key == "control" and item == "none":
				continue
			if key == "movement" and item == null:
				continue
			if (key == "mods" or key == "behaviors") and item is Dictionary and (item as Dictionary).is_empty():
				continue
			if key == "behaviors" and item is Array and (item as Array).is_empty():
				continue
			out[key] = compact(item)
		return out
	if value is Array:
		var items: Array = []
		for item: Variant in value:
			items.append(compact(item))
		return items
	return value



static func deep_equal(a: Variant, b: Variant) -> bool:
	var a_is_num: = typeof(a) == TYPE_INT or typeof(a) == TYPE_FLOAT
	var b_is_num: = typeof(b) == TYPE_INT or typeof(b) == TYPE_FLOAT
	if a_is_num or b_is_num:
		return a_is_num and b_is_num and is_equal_approx(float(a), float(b))
	if (a is String or a is StringName) and (b is String or b is StringName):
		return String(a) == String(b)
	if a is Dictionary and b is Dictionary:
		var da: Dictionary = a
		var db: Dictionary = b
		if da.size() != db.size():
			return false
		for key: Variant in da:
			if not db.has(key) or not deep_equal(da[key], db[key]):
				return false
		return true
	if a is Array and b is Array:
		var aa: Array = a
		var ab: Array = b
		if aa.size() != ab.size():
			return false
		for i in aa.size():
			if not deep_equal(aa[i], ab[i]):
				return false
		return true
	return typeof(a) == typeof(b) and a == b



static func pretty(tree: Dictionary, lex: LexiconData) -> String:
	if tree.is_empty():
		return ""
	if tree.has("ability"):
		return lex.label("formats", "ability")\
		.replace("{name}", lex.label("abilities", String(tree["ability"])).to_upper())\
		.replace("{d}", lex.format_number(float(tree["duration"])))
	if tree.has("command"):
		return lex.label("formats", "command").replace("{name}", lex.label("commands", String(tree["command"])).to_upper())
	return _pretty_node(tree, lex)


static func _pretty_node(node: Dictionary, lex: LexiconData) -> String:
	var mods: Dictionary = node["mods"]
	var text: = lex.thing_name(String(node["thing"])).to_upper()
	if mods.has("count"):
		text = "%d× %s" % [int(mods["count"]), text]
	if mods.get("ammo") is Dictionary:
		text += " de " + _pretty_node(mods["ammo"], lex)
	var tags: = PackedStringArray()
	for key: String in mods:
		if key == "grafts":
			for graft: Dictionary in mods[key]:
				tags.append("com %s %s" % [_pretty_node(graft["node"], lex), lex.label("mounts", String(graft["socket"]))])
		elif key == "mag" and mods[key] is Dictionary:
			tags.append(_pretty_node(mods[key], lex))
		elif key != "count" and key != "ammo" and key != "whole_parts":
			tags.append(lex.mod_label(key, mods[key], String(node["thing"])))
	if String(node["control"]) != "none":
		tags.append(lex.label("control", String(node["control"])))
	if node["movement"] != null:
		tags.append(lex.label("movement", String(node["movement"])))
	if not tags.is_empty():
		text += " [%s]" % ", ".join(tags)

	var parts: = PackedStringArray()
	for behavior: Dictionary in node["behaviors"]:
		parts.append(_pretty_behavior(behavior, lex))
	if parts.size() == 1:
		text += " → " + parts[0]
	elif parts.size() > 1:
		text += " → { %s }" % "; ".join(parts)
	return text


static func _pretty_behavior(behavior: Dictionary, lex: LexiconData) -> String:
	var act: Dictionary = behavior["do"]
	var words: = PackedStringArray()
	var when_text: = lex.trigger_label(behavior["when"])
	if not when_text.is_empty():
		words.append(when_text)
	words.append(lex.action_label(act))
	if act.get("arg") is Dictionary:
		var arg: Dictionary = act["arg"]
		var arg_text: = _pretty_node(arg, lex)
		if act.has("aim") and not (arg["behaviors"] as Array).is_empty():
			arg_text = "(%s)" % arg_text
		words.append(arg_text)
	if act.has("aim"):
		words.append(lex.label("aim", String(act["aim"])))
	return " ".join(words)
