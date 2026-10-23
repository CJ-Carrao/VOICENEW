class_name LexiconData
extends RefCounted




const DEF_FILES: PackedStringArray = ["things", "actions", "triggers", "movements", "modifiers", "parts", "abilities", 
	"commands"]

const LEXICON_FILES: PackedStringArray = [
	"numbers", "fillers", "grammar", "things", "verbs", "modifiers", "parts", "abilities", "commands", "macros", "display", "bot", 
	"phonetics", "common_words", 
]
const GRAMMAR_ROLES: PackedStringArray = ["rel", "and", "of", "with", "in"]

const WEAPON_SECTIONS: PackedStringArray = ["rear", "front", "muzzle"]

var lang: String = ""

var version: String = ""
var balance: Dictionary = {}

var defs: Dictionary = {}

var lexicon: Dictionary = {}
var default_trigger_rules: Array = []

var action_rules: Array = []

var placement_rules: Dictionary = {}

var elements: Dictionary = {}
var material_rules: Array = []
var mechanical_rules: Array = []

var colors: Dictionary = {}

var shaping_rules: Dictionary = {}

var role_movement_rules: Dictionary = {}

var grip_rules: Dictionary = {}

var weapon_section_tags: Dictionary = {}

var models: Dictionary = {}

var phrases: Dictionary = {}
var max_phrase_len: int = 1

var known_words: Dictionary = {}

var common_words: Dictionary = {}


var hear_vocab: PackedStringArray = []
var hear_keys: PackedStringArray = []
var hear_filler: PackedByteArray = []

var number_joiners: PackedStringArray = []

var phonetic_rules: Array = []


var initial_soft_pairs: Dictionary = {}

var macros: Dictionary = {}
var max_macro_len: int = 1

var number_words: Dictionary = {}

var plural_rules: Array = []
var errors: PackedStringArray = []
var warnings: PackedStringArray = []

var _thing_names: Dictionary = {}
var _hash_source: String = ""


func material_pack(node: Dictionary) -> Dictionary:
	var mods: Dictionary = node.get("mods", {})
	var out: = {"behaviors": [], "visual": {}}
	for pack: Dictionary in material_rules:
		var matches: = true
		for key: String in pack["match"]:
			matches = matches and mods.get(key) == pack["match"][key]
		if matches:
			out.merge(pack.get("properties", {}), true)
			(out["behaviors"] as Array).append_array(pack.get("behaviors", []))
			(out["visual"] as Dictionary).merge(pack.get("visual", {}), true)
	return out


static func load_from(data_root: String, language: String) -> LexiconData:
	var data: = LexiconData.new()
	data.lang = language
	data.balance = data._read_json(data_root.path_join("balance.json"))
	for file in DEF_FILES:
		data.defs[file] = data._read_json(data_root.path_join("defs/%s.json" % file))
	data.default_trigger_rules = data._read_json(data_root.path_join("rules/default_triggers.json")).get("rules", [])
	data.action_rules = data._read_json(data_root.path_join("rules/action_by_category.json")).get("rules", [])
	data.placement_rules = data._read_json(data_root.path_join("rules/placement.json"))
	data.elements = data._read_json(data_root.path_join("rules/elements.json"))
	data.material_rules = data._read_json(data_root.path_join("rules/materials.json")).get("packs", [])
	data.mechanical_rules = data._read_json(data_root.path_join("rules/weapon_mechanics.json")).get("rules", [])
	data.colors = data._read_json(data_root.path_join("rules/colors.json"))
	data.shaping_rules = data._read_json(data_root.path_join("rules/shaping.json"))
	data.role_movement_rules = data._read_json(data_root.path_join("rules/role_movement.json"))
	data.grip_rules = data._read_json(data_root.path_join("rules/grips.json"))
	var sections: Dictionary = data._read_json(data_root.path_join("rules/weapon_sections.json")).get("tags", {})
	for section: String in sections:
		for tag: String in sections[section]:
			data.weapon_section_tags[tag] = section
	var models_dir: = data_root.path_join("models")
	var model_files: = DirAccess.get_files_at(models_dir)
	model_files.sort()
	for file in model_files:
		if file.get_extension() == "json":
			data.models[file.get_basename()] = data._read_json(models_dir.path_join(file))
	var lexicon_dir: = data_root.path_join("lexicon").path_join(language)
	for file in LEXICON_FILES:
		data.lexicon[file] = data._read_json(lexicon_dir.path_join(file + ".json"))
	data._build_index()
	data._validate()
	data.version = data._hash_source.md5_text().substr(0, 8)
	return data





func bal(path: String, fallback: Variant = null) -> Variant:
	var node: Variant = balance
	for key in path.split("."):
		if not (node is Dictionary) or not (node as Dictionary).has(key):
			return fallback
		node = (node as Dictionary)[key]
	return node



func balf(path: String) -> float:
	var value: Variant = bal(path)
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		push_error("[Lexicon] balance.json não tem número em '%s'" % path)
		return 0.0
	return float(value)



func thing_stat(id: String, key: String) -> Variant:
	var own: Variant = bal("things.%s.%s" % [id, key])
	return own if own != null else bal("things._default.%s" % key)


func thing_statf(id: String, key: String) -> float:
	return float(thing_stat(id, key))



func placement_for(id: String) -> String:
	var key: = category_of(id)
	if thing_def(id).get("aerial", false):
		key += "_aerial"
	return String(placement_rules.get(key, placement_rules.get(category_of(id), "front")))


func thing_def(id: String) -> Dictionary:
	return _def("things", id)


func category_of(thing_id: String) -> String:
	return String(thing_def(thing_id).get("category", ""))





func is_weapon(id: String) -> bool:
	return not id.is_empty() and not id.begins_with("_") and bal("weapons." + id) is Dictionary



func is_melee(id: String) -> bool:
	return not id.is_empty() and bool(thing_def(id).get("melee", false))




func uses_weapon_section(source: String, mods: Dictionary = {}, section: String = "") -> bool:
	return is_weapon(source) and not bool(mods.get("whole_parts", {}).get(section, false))



func part_source(thing_id: String, mods: Dictionary, section: String) -> String:
	var parts: Variant = mods.get("parts")
	if parts is Dictionary and has_def("things", String((parts as Dictionary).get(section, ""))):
		return String(parts[section])
	return thing_id



func weapon_part(thing_id: String, mods: Dictionary, section: String) -> Dictionary:
	if not is_weapon(thing_id):
		return {}
	var source: = part_source(thing_id, mods, section)
	var value: Variant = bal("weapons.%s.%s" % [source if uses_weapon_section(source, mods, section) else thing_id, section])
	return value if value is Dictionary else {}




func behavior_source(node: Dictionary) -> String:
	var thing_id: = String(node.get("thing", ""))
	var source: = part_source(thing_id, node.get("mods", {}), "front") if is_weapon(thing_id) else thing_id
	return source if uses_weapon_section(source, node.get("mods", {}), "front") else thing_id



func mechanics_of(thing_id: String, mods: Dictionary) -> Dictionary:
	var result: = {"outcome": "standard", "profiles": [], "ammo_mods": {}, "source": ""}
	if not is_weapon(thing_id):
		return result
	var priority: = {"standard": 0, "improvised_work": 1, "dud": 2, "backfire": 3}
	for section: String in WEAPON_SECTIONS:
		var source: = part_source(thing_id, mods, section)
		if uses_weapon_section(source, mods, section):
			continue
		var def: = thing_def(source)
		if int(priority[result["outcome"]]) < 1:
			result["outcome"] = "improvised_work"
		for rule: Dictionary in mechanical_rules:
			if not section in rule.get("sections", WEAPON_SECTIONS):
				continue
			var matches: bool = category_of(source) in rule.get("categories", [])
			for tag: String in def.get("mechanical_tags", []):
				matches = matches or tag in rule.get("tags", [])
			for behavior: Dictionary in def.get("behaviors", []):
				matches = matches or String(behavior.get("do", {}).get("type", "")) in rule.get("actions", [])
			if not matches:
				continue
			var outcome: = String(rule.get("outcome", "improvised_work"))
			if int(priority[outcome]) > int(priority[result["outcome"]]):
				result["outcome"] = outcome
				result["source"] = source
			var profile: = String(rule.get("profile", ""))
			if not profile.is_empty() and not profile in result["profiles"]:
				(result["profiles"] as Array).append(profile)
			(result["ammo_mods"] as Dictionary).merge(rule.get("ammo_mods", {}), true)
	return result



func barrels_of(thing_id: String, mods: Dictionary) -> int:
	if mods.has("barrels"):
		return maxi(1, int(mods["barrels"]))
	return maxi(1, int(weapon_part(thing_id, mods, "muzzle").get("barrels", 1)))



func attachment_slot(id: String) -> String:
	return String(thing_def(id).get("slot", "")) if category_of(id) == "attachment" else ""



func section_of(piece: Dictionary) -> String:
	if piece.has("section"):
		return String(piece["section"])
	return String(weapon_section_tags.get(String(piece.get("tag", "")), "front"))



func action_for(action_id: String, owner_category: String) -> String:
	for rule: Dictionary in action_rules:
		if String(rule.get("action", "")) == action_id and (rule.get("category", []) as Array).has(owner_category):
			return String(rule["becomes"])
	return action_id


func action_def(id: String) -> Dictionary:
	return _def("actions", id)


func trigger_def(id: String) -> Dictionary:
	return _def("triggers", id)


func modifier_def(id: String) -> Dictionary:
	return _def("modifiers", id)


func part_def(id: String) -> Dictionary:
	return _def("parts", id)




func thing_name(id: String) -> String:
	return String(_thing_names.get(id, id))


func label(section: String, key: String) -> String:
	var table: Variant = (lexicon.get("display", {}) as Dictionary).get(section, {})
	if table is Dictionary:
		return String((table as Dictionary).get(key, key))
	return key


func trigger_label( when : Dictionary) -> String:
	var text: = label("triggers", String( when .get("type", "")))
	for param: String in when :
		if param != "type":
			text = text.replace("{%s}" % param, format_number(float( when [param])))
	return text


func action_label(act: Dictionary) -> String:
	var text: = label("actions", String(act.get("type", "")))
	if act.has("n"):
		text = text.replace("{n}", str(int(act["n"])))
	return text




func mod_label(key: String, value: Variant, thing_id: String = "") -> String:
	var mods: Dictionary = (lexicon.get("display", {}) as Dictionary).get("mods", {})
	var entry: Variant = mods.get(key, key)
	if is_melee(thing_id) and mods.has(key + "_melee"):
		entry = mods[key + "_melee"]
	if key == "attachments" and value is Array:
		var names: = PackedStringArray()
		for id: Variant in value:
			names.append(thing_name(String(id)))
		return String(entry).replace("{names}", ", ".join(names))
	if key == "parts" and value is Dictionary:

		var pieces: = PackedStringArray()
		for section: String in WEAPON_SECTIONS:
			if (value as Dictionary).has(section):
				var names: = "sections_melee" if is_melee(thing_id) else "sections"
				pieces.append(String(entry).replace("{section}", label(names, section))
					.replace("{name}", thing_name(String(value[section])).to_upper()))
		return ", ".join(pieces)
	if entry is Dictionary:
		return String((entry as Dictionary).get(str(value), str(value)))
	var text: = String(entry)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		text = text.replace("{v}", format_number(float(value)))
	return text



func phonetic(word: String) -> String:
	var key: = word
	for rule: Array in phonetic_rules:
		key = (rule[0] as RegEx).sub(key, String(rule[1]), true)
	return key



func format_number(value: float) -> String:
	var text: = Normalizer.number_text(value) if is_equal_approx(value, roundf(value)) else String.num(value, 2)
	return text.replace(".", String((lexicon.get("display", {}) as Dictionary).get("decimal_separator", ".")))




func _build_index() -> void :
	var numbers: Dictionary = lexicon["numbers"]
	var number_table: Dictionary = numbers.get("words", {})
	for word: String in number_table:
		number_words[Normalizer.fold(word)] = float(number_table[word])
	for word: String in numbers.get("joiners", []):
		number_joiners.append(Normalizer.fold(word))
	var articles: Dictionary = numbers.get("articles", {})
	for word: String in articles:
		_add_phrase(word, {"cls": "filler"})
		_add_phrase(word, {"cls": "num", "value": float(articles[word])})

	var fillers: Dictionary = lexicon["fillers"]
	for word: String in fillers.get("always", []):
		_add_phrase(word, {"cls": "filler"})
	for word: String in fillers.get("start_only", []):
		_add_phrase(word, {"cls": "start_filler"})

	var grammar: Dictionary = lexicon["grammar"]
	for socket_id: String in grammar.get("mounts", {}):
		var entry: Dictionary = grammar["mounts"][socket_id]
		for word: String in entry["words"]:
			_add_phrase(word, {"cls": "mount", "id": socket_id, "sockets": entry["sockets"]})
	for role in GRAMMAR_ROLES:
		for word: String in grammar.get(role, []):
			_add_phrase(word, {"cls": "gram", "id": role})
	var units: Dictionary = grammar.get("units", {})
	for word: String in units:
		_add_phrase(word, {"cls": "unit", "factor": float(units[word])})
	var adjuncts: Dictionary = grammar.get("adjuncts", {})
	for id: String in adjuncts:
		var adjunct: Dictionary = adjuncts[id]
		for word: String in adjunct.get("words", []):
			_add_phrase(word, {"cls": "adjunct", "id": id, "trigger": String(adjunct.get("trigger", "")), 
				"set": (adjunct.get("set", {}) as Dictionary).duplicate(true)})
	for rule: Array in grammar.get("plural_rules", []):
		plural_rules.append([Normalizer.fold(String(rule[0])), Normalizer.fold(String(rule[1]))])

	var things: Dictionary = lexicon["things"]
	for entry: String in things:
		if entry.begins_with("_"):
			continue
		var data: Dictionary = things[entry]
		var id: = String(data.get("id", entry))
		var sense: = {"cls": "thing", "entry": entry, "id": id, 
			"as_head": String(data.get("as_head", id)), "as_arg": String(data.get("as_arg", id))}
		for word: String in data.get("words", []):
			_add_phrase(word, sense.duplicate())
		var plural: = sense.duplicate()
		plural["plural"] = true
		for word: String in data.get("forms", []):
			_add_phrase(word, plural.duplicate())
		if data.has("name"):
			_thing_names[id] = String(data["name"])

	var verbs: Dictionary = lexicon["verbs"]
	for entry: String in verbs:
		if entry.begins_with("_"):
			continue
		var data: Dictionary = verbs[entry]
		var sense: = {}
		for cls in ["action", "trigger", "movement"]:
			if data.has(cls):
				sense = {"cls": cls, "id": String(data[cls])}
		if sense.is_empty():
			errors.append("verbs.json: '%s' precisa de action, trigger ou movement" % entry)
			continue
		for word: String in data.get("words", []):
			_add_phrase(word, sense.duplicate())

	for pair in [["modifiers", "mod"], ["parts", "part"], ["abilities", "ability"], ["commands", "command"]]:
		var table: Dictionary = lexicon[pair[0]]
		for id: String in table:
			if id.begins_with("_"):
				continue
			for word: String in (table[id] as Dictionary).get("words", []):
				_add_phrase(word, {"cls": pair[1], "id": id})

	var macro_table: Dictionary = lexicon["macros"]
	for key: String in macro_table:
		if key.begins_with("_"):
			continue
		var value: Variant = macro_table[key]
		var target: = String(value) if value is String else String((value as Dictionary).get("to", ""))
		var forms: Array = [key] if value is String else (value as Dictionary).get("words", [key])
		var expansion: = Normalizer.normalize(target, number_words)
		for form: String in forms:
			var words: = Normalizer.normalize(form, number_words)
			macros[" ".join(words)] = expansion
			max_macro_len = maxi(max_macro_len, words.size())

	for rule: Array in (lexicon["phonetics"] as Dictionary).get("rules", []):
		var regex: = RegEx.create_from_string(String(rule[0]))
		if regex == null or not regex.is_valid():
			errors.append("phonetics.json: regra inválida %s" % JSON.stringify(rule))
			continue
		phonetic_rules.append([regex, String(rule[1])])
	for pair: Variant in (lexicon["phonetics"] as Dictionary).get("initial_soft_pairs", []):
		if pair is Array and (pair as Array).size() == 2:
			initial_soft_pairs["%s|%s" % [pair[0], pair[1]]] = true
			initial_soft_pairs["%s|%s" % [pair[1], pair[0]]] = true
	var meaningful: = {}
	for key: String in phrases:
		var has_meaning: = false
		for sense: Dictionary in phrases[key]:
			has_meaning = has_meaning or String(sense["cls"]) not in ["filler", "start_filler"]
		for word in key.split(" "):
			known_words[word] = true
			if has_meaning:
				meaningful[word] = true
	for key: String in macros:
		for word in key.split(" "):
			known_words[word] = true
			meaningful[word] = true
	for word: String in number_words:
		known_words[word] = true
		meaningful[word] = true
	for raw: String in (lexicon["common_words"] as Dictionary).get("words", []):
		var word: = Normalizer.fold(raw)
		if not known_words.has(word):
			common_words[word] = true
	var min_len: = int(bal("parser.hear_target_min_len", 3))
	var targets: = PackedStringArray()
	for word: String in known_words:
		if word.length() >= min_len and not Normalizer.is_number(word):
			targets.append(word)
	targets.sort()
	hear_vocab = targets
	for word in hear_vocab:
		hear_keys.append(phonetic(word))
		hear_filler.append(0 if meaningful.has(word) else 1)


func _add_phrase(raw: String, sense: Dictionary) -> void :
	var words: = Normalizer.normalize(raw, number_words)
	if words.is_empty():
		return
	var key: = " ".join(words)
	max_phrase_len = maxi(max_phrase_len, words.size())
	if not phrases.has(key):
		phrases[key] = []
	var senses: Array = phrases[key]
	for existing: Dictionary in senses:
		if existing["cls"] == sense["cls"]:
			if existing.get("id", "") != sense.get("id", "") or existing.get("entry", "") != sense.get("entry", ""):
				warnings.append("\"%s\" já é %s '%s'; ignorei '%s'" % [key, sense["cls"], existing.get("id", ""), sense.get("id", "")])
			return
	senses.append(sense)



func _validate() -> void :
	var where: = {"thing": "things", "action": "actions", "trigger": "triggers", "movement": "movements", 
		"mod": "modifiers", "part": "parts", "ability": "abilities", "command": "commands"}
	for key: String in phrases:
		for sense: Dictionary in phrases[key]:
			var cls: = String(sense["cls"])
			if cls == "thing":
				for field in ["as_head", "as_arg"]:
					if not has_def("things", sense[field]):
						errors.append("\"%s\" aponta pra coisa inexistente '%s'" % [key, sense[field]])
			elif where.has(cls) and not has_def(where[cls], String(sense["id"])):
				errors.append("\"%s\" aponta pra %s inexistente '%s'" % [key, cls, sense["id"]])
			elif cls == "adjunct" and String(sense["trigger"]) != "" and not has_def("triggers", sense["trigger"]):
				errors.append("\"%s\" aponta pra gatilho inexistente '%s'" % [key, sense["trigger"]])

	for rule: Dictionary in action_rules:
		for field in ["action", "becomes"]:
			if not has_def("actions", String(rule.get(field, ""))):
				errors.append("action_by_category: ação inexistente em %s" % JSON.stringify(rule))

	for rule: Dictionary in default_trigger_rules:
		var action: = String(rule.get("action", "*"))
		if action != "*" and not has_def("actions", action):
			errors.append("default_triggers: ação inexistente '%s'" % action)
		if not has_def("triggers", String((rule.get("when", {}) as Dictionary).get("type", ""))):
			errors.append("default_triggers: gatilho inexistente em %s" % JSON.stringify(rule))

	for id: String in defs["things"]:
		if id.begins_with("_"):
			continue
		if category_of(id).is_empty():
			errors.append("defs/things.json: '%s' sem category" % id)
		if not _thing_names.has(id):
			warnings.append("coisa '%s' sem nome de exibição no léxico" % id)
		var projectile: = String(thing_def(id).get("projectile", ""))
		if not projectile.is_empty() and not has_def("things", projectile):
			errors.append("defs/things.json: '%s' atira '%s', que não existe" % [id, projectile])

	for id: String in models:
		if not has_def("things", id):
			warnings.append("data/models/%s.json não corresponde a nenhuma coisa" % id)
	for id: String in defs["things"]:
		if not id.begins_with("_") and not models.has(id):
			warnings.append("coisa '%s' sem modelo em data/models (vai aparecer como caixa)" % id)
	if bal("things._default") == null:
		errors.append("balance.json precisa de things._default")

	for id: String in defs["modifiers"]:
		if not id.begins_with("_") and not modifier_def(id).has("value") and bal("modifiers." + id) == null:
			errors.append("modificador '%s' sem 'value' e sem balance.modifiers.%s" % [id, id])

	for id: String in defs["things"]:
		if category_of(id) == "weapon" and not is_weapon(id):
			errors.append("arma '%s' sem números em balance.weapons (rear, front, muzzle)" % id)
	for id: String in (balance.get("weapons", {}) as Dictionary):
		if not is_weapon(id):
			continue
		for section: String in WEAPON_SECTIONS:
			if not bal("weapons.%s.%s" % [id, section]) is Dictionary:
				errors.append("balance.weapons.%s sem a parte '%s'" % [id, section])
		var joints: Variant = (models.get(id, {}) as Dictionary).get("joints")
		if not joints is Dictionary or not (joints as Dictionary).has("trigger") or not (joints as Dictionary).has("muzzle"):
			warnings.append("modelo da arma '%s' sem joints trigger/muzzle (misturar partes vai desalinhar)" % id)



func has_def(file: String, id: String) -> bool:
	return not id.begins_with("_") and (defs.get(file, {}) as Dictionary).has(id)


func _def(file: String, id: String) -> Dictionary:
	if id.begins_with("_"):
		return {}
	var table: Dictionary = defs.get(file, {})
	return table.get(id, {})


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("arquivo não encontrado: " + path)
		return {}
	var text: = FileAccess.get_file_as_string(path)
	_hash_source += path + "\n" + text + "\n"
	var json: = JSON.new()
	if json.parse(text) != OK:
		errors.append("%s:%d %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		errors.append("%s: a raiz precisa ser um objeto" % path)
		return {}
	return json.data
