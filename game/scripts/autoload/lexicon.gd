extends Node







signal language_changed(lang: String)

const DATA_ROOT: = "res://data"
const DEFAULT_LANG: = "pt_br"

const LANGUAGES: = {
	"pt_br": {"locale": "pt_BR", "speech": "pt-BR", "label": "PT-BR"}, 
	"en_us": {"locale": "en_US", "speech": "en-US", "label": "EN-US"}, 
}
const I18N_DIR: = "res://data/i18n"



const I18N_EXTRA_DIR: = "res://assets/i18n"

var data: LexiconData
var _cache: Dictionary = {}


func _ready() -> void :
	_load_translations()
	var lang: = String(UserSettings.get_value("game", "language", _system_language()))

	var args: = OS.get_cmdline_args()
	if args.has("-s") or args.has("--script"):
		lang = DEFAULT_LANG
	if MobileDev.args().has("--ingles"):
		lang = "en_us"
	set_language(lang if LANGUAGES.has(lang) else DEFAULT_LANG, false)



static func _system_language() -> String:
	return "pt_br" if OS.get_locale_language() == "pt" else "en_us"


func reload(lang: String) -> void :
	_cache.erase(lang)
	data = for_lang(lang)



func for_lang(lang: String) -> LexiconData:
	if not LANGUAGES.has(lang):
		lang = DEFAULT_LANG
	if not _cache.has(lang):
		var loaded: = LexiconData.load_from(DATA_ROOT, lang)
		for message in loaded.errors:
			push_error("[Lexicon] " + message)
		for message in loaded.warnings:
			push_warning("[Lexicon] " + message)
		print("[Lexicon] '%s' carregado · versão %s · %d expressões" % [lang, loaded.version, loaded.phrases.size()])
		_cache[lang] = loaded
	return _cache[lang]



func set_language(lang: String, save: bool = true) -> void :
	if not LANGUAGES.has(lang):
		return
	var changed: = data == null or data.lang != lang
	data = for_lang(lang)
	TranslationServer.set_locale(String(LANGUAGES[lang]["locale"]))
	if save:
		UserSettings.set_value("game", "language", lang)
	if changed:
		language_changed.emit(lang)


func language() -> String:
	return data.lang if data != null else DEFAULT_LANG



func speech_tag() -> String:
	return String(LANGUAGES[language()]["speech"])





func _load_translations() -> void :
	var source: = Translation.new()
	source.locale = String(LANGUAGES[DEFAULT_LANG]["locale"])
	for lang: String in LANGUAGES:
		var translation: = Translation.new()
		translation.locale = String(LANGUAGES[lang]["locale"])
		var found: = false
		for dir in [I18N_DIR, I18N_EXTRA_DIR]:
			var path: = String(dir).path_join(lang + ".json")
			if not FileAccess.file_exists(path):
				continue
			var table: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if not table is Dictionary:
				push_error("[Lexicon] textos inválidos: " + path)
				continue
			found = true
			for text: String in table:
				if not text.begins_with("_"):
					translation.add_message(text, String(table[text]))
					source.add_message(text, text)
		if found:
			TranslationServer.add_translation(translation)
	TranslationServer.add_translation(source)


func bal(path: String, fallback: Variant = null) -> Variant:
	return data.bal(path, fallback)


func balf(path: String) -> float:
	return data.balf(path)
