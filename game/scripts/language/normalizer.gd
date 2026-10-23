class_name Normalizer
extends RefCounted




const ACCENTS: = {
	"á": "a", "à": "a", "â": "a", "ã": "a", "ä": "a", 
	"é": "e", "è": "e", "ê": "e", "ë": "e", 
	"í": "i", "ì": "i", "î": "i", "ï": "i", 
	"ó": "o", "ò": "o", "ô": "o", "õ": "o", "ö": "o", 
	"ú": "u", "ù": "u", "û": "u", "ü": "u", 
	"ç": "c", "ñ": "n", 
}

static var _regex_cache: Dictionary = {}



static func fold(text: String) -> String:
	var out: = ""
	for ch in text.to_lower():
		out += String(ACCENTS.get(ch, ch))
	out = _regex("(\\d),(\\d)").sub(out, "$1.$2", true)
	out = _regex("[^a-z0-9.]+").sub(out, " ", true)
	out = _regex("(?<![0-9])\\.|\\.(?![0-9])").sub(out, " ", true)
	return out.strip_edges()



static func normalize(text: String, number_words: Dictionary) -> PackedStringArray:
	var words: = fold(text).split(" ", false)
	for i in words.size():
		if number_words.has(words[i]):
			words[i] = number_text(float(number_words[words[i]]))
	return words


static func is_number(word: String) -> bool:
	return _regex("^[0-9]+(\\.[0-9]+)?$").search(word) != null


static func number_text(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return str(value)


static func _regex(pattern: String) -> RegEx:
	if not _regex_cache.has(pattern):
		var regex: = RegEx.new()
		regex.compile(pattern)
		_regex_cache[pattern] = regex
	return _regex_cache[pattern]
