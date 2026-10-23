class_name Tokenizer
extends RefCounted







const VOWELS: = "aeiou"
const CLOSEST_MEMO_MAX: = 4096

static var _closest_memo: Dictionary = {}




static func tokenize(text: String, lex: LexiconData) -> Dictionary:
	var notes: Array[String] = []
	var warnings: Array[String] = []
	var corrections: Array[Dictionary] = []

	var words: = _repair(Normalizer.normalize(text, {}), lex, corrections)
	words = _numbers(words, lex)
	words = _expand_macros(words, lex, [], int(lex.bal("parser.macro_depth", 4)), notes, warnings)

	var tokens: Array[Dictionary] = []
	var i: = 0
	while i < words.size():
		var span: = _longest_phrase(words, i, lex)

		if span > 1 and not tokens.is_empty():
			var after_part: = false
			var of_word: = false
			for sense: Dictionary in tokens[tokens.size() - 1]["senses"]:
				after_part = after_part or sense.get("cls") == "part"
			for sense: Dictionary in lex.phrases.get(words[i], []):
				of_word = of_word or (sense.get("cls") == "gram" and sense.get("id") == "of")
			if after_part and of_word:
				span = 0


		if span > 0 and not tokens.is_empty() and _is_relative(tokens[tokens.size() - 1])\
		and _verb_then_thing(words[i], " ".join(words.slice(i, i + span)), lex):
			span = 0
		if span > 0:
			var key: = " ".join(words.slice(i, i + span))
			tokens.append(_token(key, (lex.phrases[key] as Array).duplicate(true)))
			i += span
		else:
			tokens.append(_classify_word(words[i], lex))
			i += 1
	return {"tokens": tokens, "normalized": " ".join(words), "notes": notes, "warnings": warnings, 
		"corrections": corrections}



static func osa_distance(a: String, b: String) -> int:
	var n: = a.length()
	var m: = b.length()
	var width: = m + 1
	var d: = PackedInt32Array()
	d.resize((n + 1) * width)
	for i in n + 1:
		d[i * width] = i
	for j in m + 1:
		d[j] = j
	for i in range(1, n + 1):
		for j in range(1, m + 1):
			var cost: = 0 if a[i - 1] == b[j - 1] else 1
			var best: = mini(mini(d[(i - 1) * width + j] + 1, d[i * width + j - 1] + 1), d[(i - 1) * width + j - 1] + cost)
			if i > 1 and j > 1 and a[i - 1] == b[j - 2] and a[i - 2] == b[j - 1]:
				best = mini(best, d[(i - 2) * width + j - 2] + 1)
			d[i * width + j] = best
	return d[n * width + m]








static func _repair(words: PackedStringArray, lex: LexiconData, corrections: Array[Dictionary]) -> PackedStringArray:
	var out: = PackedStringArray()
	var max_join: = int(lex.bal("parser.join_max_words", 3))
	var i: = 0
	while i < words.size():
		var word: = words[i]


		var joined_fragment: = false
		if not out.is_empty() and out[out.size() - 1] in lex.lexicon["phonetics"].get("join_after", []) and not lex.phrases.has(word):
			for length in range(mini(max_join, words.size() - i), 1, -1):
				var joined: = "".join(words.slice(i, i + length))
				if lex.phrases.has(joined):
					corrections.append({"from": " ".join(words.slice(i, i + length)), "to": joined})
					out.append(joined)
					i += length
					joined_fragment = true
					break
		if joined_fragment:
			continue
		if _known(word, lex) or lex.common_words.has(word):
			out.append(word)
			i += 1
			continue
		var fixed: = ""
		var span: = 1
		var from: = word
		for length in range(mini(max_join, words.size() - i), 1, -1):
			var joined: = "".join(words.slice(i, i + length))
			if _known(joined, lex):
				fixed = joined
				span = length
				break
		if fixed.is_empty() and not out.is_empty() and _known(out[out.size() - 1] + word, lex):
			from = out[out.size() - 1] + " " + word
			fixed = out[out.size() - 1] + word
			out.remove_at(out.size() - 1)
		if fixed.is_empty():
			fixed = _closest(word, lex)
		if fixed.is_empty():
			for length in range(mini(max_join, words.size() - i), 1, -1):
				var joined: = "".join(words.slice(i, i + length))
				if joined.length() >= int(lex.bal("parser.join_fuzzy_min_len", 6)):
					fixed = _closest(joined, lex)
				if not fixed.is_empty():
					span = length
					break
		if fixed.is_empty():
			out.append(word)
			i += 1
			continue
		if span > 1:
			from = " ".join(words.slice(i, i + span))
		corrections.append({"from": from, "to": fixed})
		out.append(fixed)
		i += span
	return out








static func _closest(word: String, lex: LexiconData) -> String:

	var memo_key: = lex.version + ":" + word
	if not _closest_memo.has(memo_key):
		if _closest_memo.size() >= CLOSEST_MEMO_MAX:
			_closest_memo.clear()
		_closest_memo[memo_key] = _search_closest(word, lex)
	return _closest_memo[memo_key]


static func _search_closest(word: String, lex: LexiconData) -> String:
	var length: = word.length()
	if length < int(lex.bal("parser.fuzzy_min_len", 4)) or Normalizer.is_number(word):
		return ""
	var max_written: = int(lex.bal("parser.fuzzy_short_max_dist", 1))
	if length >= int(lex.bal("parser.fuzzy_long_len", 8)):
		max_written = int(lex.bal("parser.fuzzy_long_max_dist", 2))
	var key: = lex.phonetic(word)
	var max_sound: = int(lex.bal("parser.phonetic_short_max_dist", 1))
	if key.length() >= int(lex.bal("parser.phonetic_long_len", 7)):
		max_sound = int(lex.bal("parser.phonetic_long_max_dist", 2))
	var best: = ""
	var best_score: = Vector3i(max_sound + 1, 1 << 20, 1)
	for n in lex.hear_vocab.size():
		var candidate: = lex.hear_vocab[n]
		var candidate_key: = lex.hear_keys[n]
		if absi(candidate_key.length() - key.length()) > max_sound and absi(candidate.length() - length) > max_written:
			continue
		var sound: = osa_distance(key, candidate_key) + _initial_penalty(key, candidate_key, lex)
		var written: = osa_distance(word, candidate)
		if (sound > max_sound and written > max_written) or (lex.hear_filler[n] and sound > 0):
			continue
		var score: = Vector3i(sound, written, lex.hear_filler[n])
		if score < best_score:
			best_score = score
			best = candidate
	return best


static func _initial_penalty(a: String, b: String, lex: LexiconData) -> int:
	if a.is_empty() or b.is_empty() or a[0] == b[0] or VOWELS.contains(a[0]) or VOWELS.contains(b[0]):
		return 0
	if lex.initial_soft_pairs.has("%s|%s" % [a[0], b[0]]):
		return 0
	return int(lex.bal("parser.initial_consonant_penalty", 1))



static func _numbers(spoken: PackedStringArray, lex: LexiconData) -> PackedStringArray:
	var words: = PackedStringArray()
	for word in spoken:
		words.append(Normalizer.number_text(float(lex.number_words[word])) if lex.number_words.has(word) else word)
	var out: = PackedStringArray()
	var i: = 0
	while i < words.size():
		if i + 2 < words.size() and Normalizer.is_number(words[i]) and lex.number_joiners.has(words[i + 1]):
			var tens: = words[i].to_float()
			var unit: = _unit_value(words[i + 2], lex)
			if tens >= 20.0 and tens < 100.0 and fmod(tens, 10.0) == 0.0 and unit >= 1.0 and unit <= 9.0:
				out.append(Normalizer.number_text(tens + unit))
				i += 3
				continue
		out.append(words[i])
		i += 1
	return out


static func _unit_value(word: String, lex: LexiconData) -> float:
	if Normalizer.is_number(word):
		return word.to_float()
	for sense: Dictionary in lex.phrases.get(word, []):
		if sense["cls"] == "num":
			return float(sense["value"])
	return -1.0


static func _known(word: String, lex: LexiconData) -> bool:
	return lex.known_words.has(word) or Normalizer.is_number(word) or not _singular(word, lex).is_empty()



static func _expand_macros(words: PackedStringArray, lex: LexiconData, active: Array[String], max_depth: int, 
		notes: Array[String], warnings: Array[String]) -> PackedStringArray:
	var out: = PackedStringArray()
	var i: = 0
	while i < words.size():
		var key: = ""
		var span: = 0
		for length in range(mini(lex.max_macro_len, words.size() - i), 0, -1):
			var candidate: = " ".join(words.slice(i, i + length))
			if lex.macros.has(candidate):
				key = candidate
				span = length
				break

		var phrase_span: = _longest_phrase(words, i, lex)
		if span > 0 and phrase_span > span:
			var phrase: = " ".join(words.slice(i, i + phrase_span))
			var named_thing: = false
			for sense: Dictionary in lex.phrases[phrase]:
				named_thing = named_thing or sense.get("cls") == "thing"
			if named_thing:
				out.append_array(words.slice(i, i + phrase_span))
				i += phrase_span
				continue
		if span == 0:
			out.append(words[i])
			i += 1
			continue
		if active.has(key) or active.size() >= max_depth:
			warnings.append("atalho \"%s\" se repete dentro dele mesmo: ignorado" % key)
			out.append_array(words.slice(i, i + span))
			i += span
			continue
		var expansion: PackedStringArray = lex.macros[key]
		notes.append("%s → %s" % [key, " ".join(expansion)])
		var nested: Array[String] = []
		nested.assign(active)
		nested.append(key)
		out.append_array(_expand_macros(expansion, lex, nested, max_depth, notes, warnings))
		i += span
	return out



static func _longest_phrase(words: PackedStringArray, start: int, lex: LexiconData) -> int:
	for length in range(mini(lex.max_phrase_len, words.size() - start), 1, -1):
		if lex.phrases.has(" ".join(words.slice(start, start + length))):
			return length
	return 0


static func _is_relative(token: Dictionary) -> bool:
	for sense: Dictionary in token["senses"]:
		if sense.get("cls") == "gram" and sense.get("id") == "rel":
			return true
	return false



static func _verb_then_thing(first: String, phrase: String, lex: LexiconData) -> bool:
	for sense: Dictionary in lex.phrases[phrase]:
		if sense.get("cls") != "thing":
			return false
	for sense: Dictionary in lex.phrases.get(first, []):
		if sense.get("cls") == "action":
			return true
	return false



static func _classify_word(word: String, lex: LexiconData) -> Dictionary:
	var senses: Array = []
	if Normalizer.is_number(word):
		senses.append({"cls": "num", "value": word.to_float()})
	if lex.phrases.has(word):
		senses.append_array((lex.phrases[word] as Array).duplicate(true))
	if not senses.is_empty():
		return _token(word, senses)

	var singular: = _singular(word, lex)
	if not singular.is_empty():
		senses = (lex.phrases[singular] as Array).duplicate(true)
		for sense: Dictionary in senses:
			sense["plural"] = true
		return _token(word, senses)
	return _token(word, [])


static func _singular(word: String, lex: LexiconData) -> String:
	for rule: Array in lex.plural_rules:
		var suffix: String = rule[0]
		var replacement: String = rule[1]
		if word.length() > suffix.length() + 1 and word.ends_with(suffix):
			var candidate: = word.left(word.length() - suffix.length()) + replacement
			if lex.phrases.has(candidate):
				return candidate
	return ""


static func _token(text: String, senses: Array) -> Dictionary:
	return {"text": text, "senses": senses}
