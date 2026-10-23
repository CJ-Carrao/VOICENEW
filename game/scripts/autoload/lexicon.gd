extends Node



const DATA_ROOT: = "res://data"
const DEFAULT_LANG: = "pt_br"

var data: LexiconData


func _ready() -> void :
	reload(DEFAULT_LANG)


func reload(lang: String) -> void :
	data = LexiconData.load_from(DATA_ROOT, lang)
	for message in data.errors:
		push_error("[Lexicon] " + message)
	for message in data.warnings:
		push_warning("[Lexicon] " + message)
	print("[Lexicon] '%s' carregado · versão %s · %d expressões" % [lang, data.version, data.phrases.size()])


func bal(path: String, fallback: Variant = null) -> Variant:
	return data.bal(path, fallback)


func balf(path: String) -> float:
	return data.balf(path)
