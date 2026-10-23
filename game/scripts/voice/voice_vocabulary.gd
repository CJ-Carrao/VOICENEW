class_name VoiceVocabulary
extends RefCounted







static func words(lex: LexiconData) -> PackedStringArray:
	var found: = {}
	for raw in _all_phrases(lex):
		for word in _split(raw):
			found[word] = true
	var result: = PackedStringArray(found.keys())
	result.sort()
	return result



static func _function_words(lex: LexiconData) -> Dictionary:
	var out: = {}
	for raw: String in (lex.lexicon["fillers"] as Dictionary).get("always", []):
		out[Normalizer.fold(raw)] = true
	var grammar: Dictionary = lex.lexicon["grammar"]
	for role in LexiconData.GRAMMAR_ROLES:
		for raw: String in grammar.get(role, []):
			for word in Normalizer.fold(raw).split(" ", false):
				out[word] = true
	return out




static func hotwords(lex: LexiconData) -> PackedStringArray:
	var skip: = _function_words(lex)
	var out: = PackedStringArray()
	for word in words(lex):
		if not skip.has(Normalizer.fold(word)) and word.length() >= 2 and not word.is_valid_float():
			out.append(word)
	return out



static func _all_phrases(lex: LexiconData) -> PackedStringArray:
	var out: = PackedStringArray()
	for phrase in CreativeComposer.SPOKEN_FORMS:
		out.append(phrase)
	for table in ["things", "verbs", "modifiers", "parts", "abilities", "commands", "macros"]:
		for key: String in lex.lexicon[table]:
			if key.begins_with("_"):
				continue
			var entry: Variant = (lex.lexicon[table] as Dictionary)[key]
			if table == "macros":
				out.append(key)
			if entry is Dictionary:
				for field in ["words", "forms"]:
					for raw: String in (entry as Dictionary).get(field, []):
						out.append(raw)
	var grammar: Dictionary = lex.lexicon["grammar"]
	for role in LexiconData.GRAMMAR_ROLES:
		for raw: String in grammar.get(role, []):
			out.append(raw)
	for raw: String in (grammar.get("units", {}) as Dictionary):
		out.append(raw)
	for id: String in (grammar.get("adjuncts", {}) as Dictionary):
		for raw: String in (grammar["adjuncts"][id] as Dictionary).get("words", []):
			out.append(raw)
	var fillers: Dictionary = lex.lexicon["fillers"]
	for field in ["always", "start_only"]:
		for raw: String in fillers.get(field, []):
			out.append(raw)
	var numbers: Dictionary = lex.lexicon["numbers"]
	for field in ["words", "articles"]:
		for raw: String in (numbers.get(field, {}) as Dictionary):
			out.append(raw)
	return out


static func _split(raw: String) -> PackedStringArray:
	var out: = PackedStringArray()
	for word in raw.to_lower().replace("-", " ").split(" ", false):
		var clean: = word.strip_edges().trim_suffix(",").trim_suffix(".")
		if not clean.is_empty():
			out.append(clean)
	return out
