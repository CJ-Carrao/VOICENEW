class_name VoiceScore
extends RefCounted





static func score(results: Array, lex: LexiconData) -> Dictionary:
	var same_tree: = 0
	var understood: = 0
	var word_errors: = 0
	var word_total: = 0
	var total_ms: = 0
	var misses: Array[String] = []
	for r: Dictionary in results:
		var want: = PhraseParser.parse(String(r["ref"]), lex)
		var got: = PhraseParser.parse(String(r["hyp"]), lex)
		if got["ok"]:
			understood += 1
		if got["ok"] and Recipe.deep_equal(Recipe.compact(want["recipe"]), Recipe.compact(got["recipe"])):
			same_tree += 1
		else:
			misses.append("%s → %s" % [r["ref"], r["hyp"]])
		var ref_words: = Normalizer.normalize(String(r["ref"]), lex.number_words)
		word_errors += _edit_distance(ref_words, Normalizer.normalize(String(r["hyp"]), lex.number_words))
		word_total += ref_words.size()
		total_ms += int(r.get("ms", 0))
	var n: = maxi(results.size(), 1)
	return {
		"tree_accuracy": float(same_tree) / n, 
		"understood": float(understood) / n, 
		"wer": float(word_errors) / maxi(word_total, 1), 
		"ms_per_phrase": total_ms / n, 
		"misses": misses, 
	}



static func same_tree(ref: String, hyp: String, lex: LexiconData) -> bool:
	var want: = PhraseParser.parse(ref, lex)
	var got: = PhraseParser.parse(hyp, lex)
	return bool(got["ok"]) and Recipe.deep_equal(Recipe.compact(want["recipe"]), Recipe.compact(got["recipe"]))




static func align(ref: PackedStringArray, hyp: PackedStringArray) -> Array[Dictionary]:
	var rows: = ref.size() + 1
	var cols: = hyp.size() + 1
	var cost: = PackedInt32Array()
	cost.resize(rows * cols)
	for i in rows:
		cost[i * cols] = i
	for j in cols:
		cost[j] = j
	for i in range(1, rows):
		for j in range(1, cols):
			cost[i * cols + j] = mini(mini(cost[(i - 1) * cols + j] + 1, cost[i * cols + j - 1] + 1), 
				cost[(i - 1) * cols + j - 1] + (0 if ref[i - 1] == hyp[j - 1] else 1))
	var steps: Array[Dictionary] = []
	var i: = ref.size()
	var j: = hyp.size()
	while i > 0 or j > 0:
		if i > 0 and j > 0 and cost[i * cols + j] == cost[(i - 1) * cols + j - 1] + (0 if ref[i - 1] == hyp[j - 1] else 1):
			steps.push_front({"op": "ok" if ref[i - 1] == hyp[j - 1] else "sub", "ref": ref[i - 1], "hyp": hyp[j - 1]})
			i -= 1
			j -= 1
		elif i > 0 and cost[i * cols + j] == cost[(i - 1) * cols + j] + 1:
			steps.push_front({"op": "del", "ref": ref[i - 1], "hyp": ""})
			i -= 1
		else:
			steps.push_front({"op": "ins", "ref": "", "hyp": hyp[j - 1]})
			j -= 1
	return steps



static func align_text(ref: String, hyp: String, lex: LexiconData) -> Array[Dictionary]:
	return align(Normalizer.normalize(ref, lex.number_words), Normalizer.normalize(hyp, lex.number_words))


static func line(label: String, s: Dictionary) -> String:
	return "%-40s %7.0f%% %7.0f%% %7.1f%% %9d" % [label, 100.0 * float(s["tree_accuracy"]), 100.0 * float(s["understood"]), 
		100.0 * float(s["wer"]), int(s["ms_per_phrase"])]


static func header() -> String:
	return "%-40s %8s %8s %8s %9s" % ["reconhecedor", "árvore", "entendeu", "WER", "ms/frase"]



static func _edit_distance(a: PackedStringArray, b: PackedStringArray) -> int:
	var prev: = PackedInt32Array()
	prev.resize(b.size() + 1)
	for j in b.size() + 1:
		prev[j] = j
	for i in range(1, a.size() + 1):
		var cur: = PackedInt32Array()
		cur.resize(b.size() + 1)
		cur[0] = i
		for j in range(1, b.size() + 1):
			cur[j] = mini(mini(prev[j] + 1, cur[j - 1] + 1), prev[j - 1] + (0 if a[i - 1] == b[j - 1] else 1))
		prev = cur
	return prev[b.size()]
