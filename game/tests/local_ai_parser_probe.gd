extends SceneTree

# Batch parser probe only: does not instantiate a match, microphone or game window.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args = OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(2)
		return
	var phrases = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not phrases is Array:
		quit(2)
		return
	var lex = root.get_node("Lexicon").data
	var rows = []
	for phrase in phrases:
		var started = Time.get_ticks_usec()
		var result = PhraseParser.parse(String(phrase), lex)
		rows.append({"phrase": phrase, "ok": result.get("ok", false),
			"recipe": Recipe.compact(result.get("recipe", {})),
			"unknown": result.get("unknown_words", []), "ignored": result.get("ignored_words", []),
			"ms": (Time.get_ticks_usec() - started) / 1000.0})
	var output = FileAccess.open(args[1], FileAccess.WRITE)
	output.store_string(JSON.stringify(rows, "\t"))
	output.close()
	quit()
