class_name PhraseParser
extends RefCounted
















const CONTENT_CLASSES: PackedStringArray = ["thing", "action", "trigger", "movement", "ability", "command", "mod", "part", 
	"adjunct", "num", "mount"]

var _lex: LexiconData
var _tokens: Array[Dictionary] = []
var _used: Array[bool] = []
var _pos: int = 0
var _max_depth: int = 3
var _warnings: Array[String] = []
var _graft_depth: int = 0
var _graft_count: int = 0





static func parse(text: String, lex: LexiconData) -> Dictionary:
	var result := PhraseParser.new()._run(CreativeComposer.prepare(text), lex)
	result["text"] = text
	return result


func _run(text: String, lex: LexiconData) -> Dictionary:
	_lex = lex
	_max_depth = int(lex.bal("caps.tree_depth", 3))
	var lexed: = Tokenizer.tokenize(text, lex)
	_tokens.assign(lexed["tokens"])
	_used.resize(_tokens.size())
	_used.fill(false)
	_warnings.assign(lexed["warnings"])

	var recipe: Dictionary = {}
	_skip_to_head()
	if _starts_sn(_pos):
		recipe = _parse_sn(0, "head")
	elif _has(_peek(), "ability"):
		recipe = _parse_ability()
	elif _has(_peek(), "command"):
		recipe = {"command": _sense_id(_peek(), "command")}
		_use()

	var unknown: Array[String] = []
	var ignored: Array[String] = []
	var corrections: Array[Dictionary] = []
	corrections.assign(lexed["corrections"])
	for i in _tokens.size():
		var token: = _tokens[i]
		if _is_unknown(token):
			unknown.append(token["text"])
		elif not _used[i] and _is_content(token):
			ignored.append(token["text"])

	var ok: = not recipe.is_empty()
	return {
		"ok": ok, 
		"text": text, 
		"normalized": lexed["normalized"], 
		"recipe": recipe if ok else null, 
		"pretty": Recipe.pretty(recipe, lex), 
		"unknown_words": unknown, 
		"ignored_words": ignored, 
		"corrections": corrections, 
		"notes": lexed["notes"], 
		"warnings": _warnings, 
		"lexicon_version": lex.version, 
	}





func _skip_to_head() -> void :
	while _pos < _tokens.size():
		if _starts_sn(_pos) or _has(_peek(), "ability") or _has(_peek(), "command"):
			return
		_pos += 1


func _parse_ability() -> Dictionary:
	var id: = _sense_id(_peek(), "ability")
	_use()
	return {"ability": id, "duration": float(_lex.bal("abilities.%s.duration" % id, 0.0))}



func _parse_sn(depth: int, role: String, relative: bool = true) -> Dictionary:
	var count: = 0
	var mods_before: Array[String] = []
	while _pos < _tokens.size():
		var t: = _peek()

		if _has(t, "thing") and not (_has(t, "num") and _starts_sn(_pos + 1)):
			break
		if _has(t, "filler"):
			_pos += 1
		elif _has(t, "num"):
			count = int(_num(t))
			_use()
		elif _has(t, "mod"):
			mods_before.append(_sense_id(t, "mod"))
			_use()
		else:
			break
	var head: = _peek()
	if not _has(head, "thing"):
		return {}
	var node: = Recipe.new_node(_resolve_thing(_sense(head, "thing"), role))
	_use()


	var deferred: Array[String] = []
	var deferred_actions: Array[Dictionary] = []
	for mod_id in mods_before:
		_apply_mod(node, mod_id, deferred)
	_parse_complements(node, deferred, depth)
	if count > 1:
		(node["mods"] as Dictionary)["count"] = count
	if relative and _is_gram(_peek(), "rel"):
		_use()
		_parse_relative(node, depth, deferred_actions)
	_apply_deferred(node, depth, deferred, deferred_actions)
	return node


func _parse_complements(node: Dictionary, deferred: Array[String], depth: int) -> void :
	while _pos < _tokens.size():
		var t: = _peek()
		if _has(t, "mod"):
			_apply_mod(node, _sense_id(t, "mod"), deferred)
			_use()
		elif _is_gram(t, "and") and _has(_at(_pos + 1), "mod"):
			_use()
		elif _is_gram(t, "of"):
			if _try_part(node, _pos):
				continue

			if _lex.thing_def(String(node["thing"])).get("holds", false) and _starts_sn(_pos + 1):
				_use()
				if depth + 1 >= _max_depth:
					var start: = _pos
					_parse_sn(depth + 1, "projectile")
					for i in range(start, _pos):
						_used[i] = false
					_warnings.append("profundidade máxima (%d) atingida: ignorei \"%s\"" % [_max_depth, _span_text(start, _pos)])
				else:
					var contents: = _parse_sn(depth + 1, "projectile")

					if not _lex.category_of(String(contents.get("thing", ""))) in ["weapon", "melee"]:
						(node["mods"] as Dictionary)["ammo"] = contents
				continue
			if _try_rounds_count(node, _pos):
				continue
			var next: = _at(_pos + 1)
			if _has(next, "part") and _has(_at(_pos + 2), "mod"):

				_use()
				_use()
				continue
			if not _has(next, "mod"):
				break
			_use()
			_apply_mod(node, _sense_id(next, "mod"), deferred)
			_use()
		elif _is_gram(t, "with"):
			_use()
			while _pos < _tokens.size():
				var u: = _peek()
				if _try_part(node, _pos):
					continue


				var holds_count: bool = _has(_peek(), "num") and bool(_lex.thing_def(String(node["thing"])).get("holds", false))
				if holds_count and _starts_sn(_pos) and depth + 1 < _max_depth:
					(node["mods"] as Dictionary)["ammo"] = _parse_sn(depth + 1, "projectile")
					continue
				if _try_rounds_count(node, _pos - 1):
					continue
				if _try_loaded(node, depth):
					continue
				if _try_gear(node, depth):
					continue
				if _try_graft(node, depth):
					continue
				if _is_gram(u, "and") and (_part_ahead(_pos + 1) or _starts_sn(_pos + 1)):
					_use()
				elif _has(u, "mod"):
					_apply_mod(node, _sense_id(u, "mod"), deferred)
					_use()
				elif _has(u, "part"):
					_use()
				elif _has(u, "filler"):
					_pos += 1
				else:
					break
		elif _has(t, "filler") or _is_unknown(t):
			_pos += 1
		else:
			break





func _try_part(node: Dictionary, start: int) -> bool:
	var i: = start
	if _is_gram(_at(i), "of"):
		i += 1
	var number: = _at(i)
	var has_number: = _has(number, "num") and _has(_at(i + 1), "part")
	if has_number:
		i += 1
	var part: = _at(i)
	if not _has(part, "part"):
		return false
	var def: = _lex.part_def(_sense_id(part, "part"))
	var section: = String(def.get("section", ""))
	var end: = i + 1
	var source: = ""
	if not section.is_empty() and _is_gram(_at(i + 1), "of"):
		var donor_pos := i + 2
		while (_has(_at(donor_pos), "filler") or _has(_at(donor_pos), "num")) and not _has(_at(donor_pos), "thing"):
			donor_pos += 1
		if _has(_at(donor_pos), "thing"):
			source = _resolve_thing(_sense(_at(donor_pos), "thing"), "head")
			end = donor_pos + 1
	if not has_number and source.is_empty():
		return false
	var mods: Dictionary = node["mods"]
	if has_number and not String(def.get("feeds", "")).is_empty():
		mods[String(def["feeds"])] = int(_num(number))
	if not source.is_empty():
		if _lex.category_of(String(node["thing"])) == "creature" and _lex.category_of(source) == "creature" and def.has("anatomy"):
			var anatomy: Dictionary = mods.get_or_add("anatomy", {})
			anatomy[String(def.anatomy)] = source
		elif _lex.has_def("things", source) and _lex.is_weapon(String(node["thing"])):
			var parts: Dictionary = mods.get_or_add("parts", {})
			parts[section] = source
			var whole: Dictionary = mods.get("whole_parts", {})
			if bool(def.get("whole_melee", false)) and _lex.is_melee(source) and not _lex.is_melee(String(node["thing"])):
				whole[section] = true
			else:
				whole.erase(section)
			if whole.is_empty():
				mods.erase("whole_parts")
			else:
				mods["whole_parts"] = whole
		else:
			_warnings.append("a troca de seção precisa de uma arma: ignorei \"%s\"" % _span_text(i, end))
	for k in range(start, end):
		_used[k] = true
	_pos = end
	return true




func _try_gear(node: Dictionary, depth: int) -> bool:
	var i: = _pos
	var counted: = -1
	while (_has(_at(i), "filler") or _has(_at(i), "num")) and not _has(_at(i), "thing"):
		if _has(_at(i), "num") and counted < 0:
			counted = i
		i += 1
	if not _has(_at(i), "thing"):
		return false
	var id: = _resolve_thing(_sense(_at(i), "thing"), "head")
	var category: = _lex.category_of(id)
	if category != "attachment" and category != "ammo":
		return false

	_pos = counted if category == "ammo" and counted >= 0 else i
	var mods: Dictionary = node["mods"]
	if category == "attachment":
		var gear: Array = mods.get_or_add("attachments", [])
		var slot: = String(_lex.thing_def(id).get("slot", ""))
		for other: String in gear.duplicate():
			if String(_lex.thing_def(other).get("slot", "")) == slot:
				gear.erase(other)
		gear.append(id)
		_use()
	elif depth + 1 < _max_depth:
		mods["mag"] = _parse_sn(depth + 1, "head")
	else:
		var start: = _pos
		_parse_sn(depth + 1, "head")
		for k in range(start, _pos):
			_used[k] = false
		_warnings.append("profundidade máxima (%d) atingida: ignorei \"%s\"" % [_max_depth, _span_text(start, _pos)])
	return true




func _try_rounds_count(node: Dictionary, after: int) -> bool:
	if not _lex.thing_def(String(node["thing"])).get("holds", false):
		return false
	var i: = after + 1
	if not _has(_at(i), "num") or _starts_sn(i):
		return false
	while _pos <= i:
		_use()
	(node["mods"] as Dictionary)["count"] = int(_num(_at(i)))
	return true




func _try_loaded(node: Dictionary, depth: int) -> bool:
	var id: = String(node["thing"])
	if int(_lex.weapon_part(id, node["mods"], "rear").get("magazine", 0)) <= 0 or depth + 2 >= _max_depth:
		return false
	var i: = _pos
	while _has(_at(i), "filler") and not _has(_at(i), "num") and not _has(_at(i), "thing"):
		i += 1
	if not _has(_at(i), "num") or not _has(_at(i + 1), "thing"):
		return false
	if _lex.category_of(_resolve_thing(_sense(_at(i + 1), "thing"), "projectile")) != "projectile":
		return false
	_pos = i
	var contents: = _parse_sn(depth + 2, "projectile")
	(node["mods"] as Dictionary)["mag"] = {"thing": "magazine", "mods": {"ammo": contents}, "behaviors": [], 
		"control": "none", "movement": null}
	return true




func _try_graft(node: Dictionary, depth: int) -> bool:
	if not _starts_sn(_pos):
		return false
	if _graft_depth >= int(_lex.bal("caps.graft_depth", 2)) or _graft_count >= int(_lex.bal("caps.grafts_per_recipe", 8)):
		_warnings.append("limite de anexos atingido")
		return false
	_graft_depth += 1
	_graft_count += 1
	var head_pos: = _pos
	var counted: = false
	while head_pos < _tokens.size() and not _has(_at(head_pos), "thing"):
		counted = counted or _has(_at(head_pos), "num")
		head_pos += 1
	var plural: = bool(_sense(_at(head_pos), "thing").get("plural", false))
	var child: = _parse_sn(depth + 1, "head", true)
	_graft_depth -= 1
	if child.is_empty():
		return false
	var sockets: Array = ["mount_hand" if _lex.category_of(String(node["thing"])) == "creature" else "mount_top"]
	var located: = _has(_peek(), "mount")
	if _has(_peek(), "mount"):
		sockets = _sense(_peek(), "mount")["sockets"]
		_use()
	var copies: = maxi(1, int((child["mods"] as Dictionary).get("count", 1)))
	(child["mods"] as Dictionary).erase("count")


	if plural and not counted and not located:
		sockets = ["mount_left", "mount_right"]
	var footprint: = 1 + _graft_size(child)
	var first: = true
	var entries: Array = (node["mods"] as Dictionary).get_or_add("grafts", [])
	for socket: String in sockets:
		var available: = maxi(0, int(_lex.bal("caps.grafts_per_recipe", 8)) - _graft_count) / footprint
		var accepted: = mini(copies, available + (1 if first else 0))
		for i in accepted:
			if not first:
				_graft_count += footprint
			first = false
			var entry: = {"socket": socket, "node": child.duplicate(true)}
			if accepted > 1:
				entry["slot"] = i
				entry["slots"] = accepted
			entries.append(entry)
		if accepted < copies:
			_warnings.append("limite de anexos atingido")
	return true


func _graft_size(node: Dictionary) -> int:
	var count: = 0
	for entry: Dictionary in (node.get("mods", {}) as Dictionary).get("grafts", []):
		count += 1 + _graft_size(entry["node"])
	return count



func _part_ahead(i: int) -> bool:
	return _has(_at(i), "part") or (_has(_at(i), "num") and _has(_at(i + 1), "part"))


func _parse_relative(owner: Dictionary, depth: int, deferred_actions: Array[Dictionary]) -> void :
	var pending: Dictionary = {}
	while _pos < _tokens.size():
		var t: = _peek()
		if _is_gram(t, "and") or _is_gram(t, "rel"):
			_use()
		elif _has(t, "filler") or _is_unknown(t):
			_pos += 1
		elif _has(t, "trigger"):
			pending = _make_trigger(_sense_id(t, "trigger"), {})
			_use()
		elif _is_trigger_adjunct(t):
			pending = _parse_trigger_adjunct()
		elif _has(t, "action"):
			_parse_action(owner, depth, pending, deferred_actions)
			pending = {}
		elif _has(t, "movement"):
			_parse_movement(owner)
		elif _is_gram(t, "with"):
			_use()
			if not _try_graft(owner, depth):
				break
		else:
			break
	if not pending.is_empty():
		_warnings.append("gatilho sem ação depois dele: ignorado")


func _parse_action(owner: Dictionary, depth: int, pending: Dictionary, deferred_actions: Array[Dictionary]) -> void :
	var start: = _pos
	var action_id: = _lex.action_for(_sense_id(_peek(), "action"), _lex.category_of(String(owner["thing"])))
	_use()
	# In a grenade request, "explode formigas" means releasing that payload.
	if action_id == "explode" and _lex.category_of(String(owner["thing"])) == "projectile" and _starts_sn(_pos):
		action_id = "burst_into"
	var adef: = _lex.action_def(action_id)
	var takes_arg: bool = adef.get("takes_arg", false)
	var role: = String(adef.get("arg_role", "projectile"))
	var action: = {"type": action_id}
	if adef.get("takes_n", false):
		_parse_n(action)

	var args: Array[Dictionary] = []
	if takes_arg and _starts_sn(_pos):
		args.append(_parse_sn(depth + 1, role))
		while _is_gram(_peek(), "and") and _starts_sn(_pos + 1):
			_use()
			args.append(_parse_sn(depth + 1, role))


	if takes_arg and depth + 1 >= _max_depth:
		_parse_adjuncts(Recipe.new_node(""), action, args)
		for i in range(start, _pos):
			_used[i] = false
		_warnings.append("profundidade máxima (%d) atingida: ignorei \"%s\"" % [_max_depth, _span_text(start, _pos)])
		return

	if takes_arg and args.is_empty():
		args.append(_default_arg(owner, adef))
	var when : = _parse_adjuncts(owner, action, args)


	if not args.is_empty() and when .get("type") == "on_fire" and _is_gram(_peek(), "rel"):
		_use()
		var child_actions: Array[Dictionary] = []
		_parse_relative(args.back(), depth + 1, child_actions)
		_apply_deferred(args.back(), depth + 1, [], child_actions)

	if action_id == "shoot" and _is_gram(_peek(), "with"):
		_use()
		if _try_graft(owner, depth):
			return
	if when .is_empty():
		when = pending

	if when .is_empty() and not takes_arg and adef.get("descends", false) and _shoots_projectiles(owner):
		deferred_actions.append(action)
		return
	if when .is_empty():
		var rule: = _default_rule(action_id, owner)
		when = rule["when"]
		var extra: Dictionary = rule["do"]
		for key: String in extra:
			if not action.has(key):
				action[key] = extra[key]

	var behaviors: Array = owner["behaviors"]
	if not takes_arg:
		behaviors.append({"when": when , "do": action})
		return
	for arg in args:
		var act: = action.duplicate(true)
		act["arg"] = arg
		behaviors.append({"when": when .duplicate(true), "do": act})


func _parse_movement(owner: Dictionary) -> void :
	owner["movement"] = _sense_id(_peek(), "movement")
	_use()
	if not _parse_adjuncts(owner, {}, []).is_empty():
		_warnings.append("gatilho depois de um movimento: ignorado")



func _parse_n(action: Dictionary) -> void :
	if _is_gram(_peek(), "in"):
		_use()
	var n: = int(_lex.bal("actions.%s.n" % action["type"], 2))
	if _has(_peek(), "num"):
		n = int(_num(_peek()))
		_use()
	action["n"] = clampi(n, 2, int(_lex.bal("caps.split_max", 8)))



func _parse_adjuncts(owner: Dictionary, action: Dictionary, args: Array[Dictionary]) -> Dictionary:
	var when : Dictionary = {}
	while _pos < _tokens.size():
		var t: = _peek()
		if _is_trigger_adjunct(t):
			when = _parse_trigger_adjunct()
		elif _has(t, "adjunct"):
			var fields: Dictionary = _sense(t, "adjunct")["set"]
			for key: String in fields:
				action[key] = fields[key]
			_use()
		elif _has(t, "mod"):
			var mod_id: = _sense_id(t, "mod")
			var def: = _lex.modifier_def(mod_id)
			Recipe.set_mod(args[args.size() - 1] if not args.is_empty() else owner, def, _mod_value(mod_id, def))
			_use()
		elif _has(t, "filler") or _is_unknown(t):
			_pos += 1
		else:
			break
	return when 


func _parse_trigger_adjunct() -> Dictionary:
	var trigger_id: = String(_sense(_peek(), "adjunct")["trigger"])
	_use()
	var params: Array = _lex.trigger_def(trigger_id).get("params", [])
	var overrides: = {}
	if not params.is_empty():
		var amount: = _read_amount()
		if amount >= 0.0:
			overrides[params[0]] = amount
	return _make_trigger(trigger_id, overrides)



func _read_amount() -> float:
	var amount: = -1.0
	if _has(_peek(), "num"):
		amount = _num(_peek())
		_use()
	if _has(_peek(), "unit"):
		amount = (1.0 if amount < 0.0 else amount) * float(_sense(_peek(), "unit")["factor"])
		_use()
	return amount




func _make_trigger(id: String, overrides: Dictionary) -> Dictionary:
	var trigger: = {"type": id}
	for param: String in _lex.trigger_def(id).get("params", []):
		trigger[param] = float(overrides.get(param, _lex.bal("trigger_defaults.%s.%s" % [id, param], 1.0)))
	return trigger



func _default_rule(action_id: String, owner: Dictionary) -> Dictionary:
	var category: = _lex.category_of(String(owner["thing"]))
	for rule: Dictionary in _lex.default_trigger_rules:
		var rule_action: = String(rule.get("action", "*"))
		if rule_action != "*" and rule_action != action_id:
			continue
		if rule.has("control") and String(rule["control"]) != String(owner["control"]):
			continue
		if rule.has("category") and not (rule["category"] as Array).has(category):
			continue
		var when : Dictionary = rule["when"]
		return {"when": _make_trigger(String( when ["type"]), when ), "do": (rule.get("do", {}) as Dictionary).duplicate(true)}
	return {"when": _make_trigger("on_fire", {}), "do": {}}



func _default_arg(owner: Dictionary, adef: Dictionary) -> Dictionary:
	var id: = ""
	if adef.get("default_arg", "") == "owner_projectile":
		id = String(_lex.thing_def(_lex.behavior_source(owner)).get("projectile", ""))
	if id.is_empty():
		id = String(adef.get("fallback_arg", "bullet"))
	return Recipe.new_node(id)


func _apply_mod(node: Dictionary, mod_id: String, deferred: Array[String]) -> void :
	var def: = _lex.modifier_def(mod_id)
	if not String(def.get("descends", "")).is_empty() and _shoots_projectiles(node):
		deferred.append(mod_id)
	else:
		Recipe.set_mod(node, def, _mod_value(mod_id, def))




func _apply_deferred(node: Dictionary, depth: int, deferred: Array[String], deferred_actions: Array[Dictionary]) -> void :
	if deferred.is_empty() and deferred_actions.is_empty():
		return
	var targets: = _projectile_args(node)
	if targets.is_empty() and depth + 1 < _max_depth:
		for behavior: Dictionary in _lex.thing_def(_lex.behavior_source(node)).get("behaviors", []):
			if _lex.action_def(String(behavior["do"]["type"])).get("projectile", false):
				(node["behaviors"] as Array).append(Recipe.behavior_from_data(behavior))
		targets = _projectile_args(node)
	var holders: Array[Dictionary] = []
	holders.assign(targets)
	if holders.is_empty():
		holders.append(node)
	for action in deferred_actions:
		for holder in holders:
			var act: = action.duplicate(true)
			var rule: = _default_rule(String(act["type"]), holder)
			var extra: Dictionary = rule["do"]
			for key: String in extra:
				if not act.has(key):
					act[key] = extra[key]
			(holder["behaviors"] as Array).append({"when": rule["when"], "do": act})
	for mod_id in deferred:
		var def: = _lex.modifier_def(mod_id)
		var value: Variant = _mod_value(mod_id, def)
		for target in targets:
			Recipe.set_mod(target, def, value)
		if targets.is_empty() or def.get("descends") == "copy":
			Recipe.set_mod(node, def, value)


func _projectile_args(node: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for behavior: Dictionary in node["behaviors"]:
		var act: Dictionary = behavior["do"]
		if _lex.action_def(String(act["type"])).get("projectile", false) and act.get("arg") is Dictionary:
			out.append(act["arg"])
	return out


func _shoots_projectiles(node: Dictionary) -> bool:
	return not String(_lex.thing_def(_lex.behavior_source(node)).get("projectile", "")).is_empty()


func _mod_value(mod_id: String, def: Dictionary) -> Variant:
	return def["value"] if def.has("value") else _lex.bal("modifiers." + mod_id, 1.0)




func _peek() -> Dictionary:
	return _at(_pos)


func _at(index: int) -> Dictionary:
	if index < 0 or index >= _tokens.size():
		return {}
	return _tokens[index]


func _use() -> void :
	_used[_pos] = true
	_pos += 1



func _starts_sn(index: int) -> bool:
	var i: = index
	while i < _tokens.size():
		var t: = _tokens[i]
		if _has(t, "thing"):
			return true
		if not (_has(t, "filler") or _has(t, "num") or _has(t, "mod")):
			return false
		i += 1
	return false


func _is_trigger_adjunct(token: Dictionary) -> bool:
	var sense: = _sense(token, "adjunct")
	return not sense.is_empty() and not String(sense["trigger"]).is_empty()


func _num(token: Dictionary) -> float:
	return float(_sense(token, "num")["value"])


func _resolve_thing(sense: Dictionary, role: String) -> String:
	return String(sense["as_head"] if role == "head" else sense["as_arg"])


func _span_text(from: int, to: int) -> String:
	var words: = PackedStringArray()
	for i in range(from, to):
		words.append(String(_tokens[i]["text"]))
	return " ".join(words)


static func _has(token: Dictionary, cls: String) -> bool:
	return not _sense(token, cls).is_empty()


static func _sense(token: Dictionary, cls: String) -> Dictionary:
	for sense: Dictionary in token.get("senses", []):
		if sense["cls"] == cls:
			return sense
	return {}


static func _sense_id(token: Dictionary, cls: String) -> String:
	return String(_sense(token, cls).get("id", ""))


static func _is_gram(token: Dictionary, role: String) -> bool:
	for sense: Dictionary in token.get("senses", []):
		if sense["cls"] == "gram" and sense["id"] == role:
			return true
	return false


static func _is_unknown(token: Dictionary) -> bool:
	return not token.is_empty() and (token["senses"] as Array).is_empty()


static func _is_content(token: Dictionary) -> bool:
	if _has(token, "filler") or _has(token, "start_filler"):
		return false
	for sense: Dictionary in token["senses"]:
		if CONTENT_CLASSES.has(String(sense["cls"])):
			return true
	return false
