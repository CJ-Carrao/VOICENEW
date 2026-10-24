class_name CreativeComposer
extends RefCounted

const SPOKEN_FORMS := ["faça", "faz", "crie", "gere", "construa", "fabrique", "produza", "use", "usa", "utilize", "utiliza", "carregue", "carrega", "empunhe", "empunha"]


static func prepare(text: String) -> String:
	var out := Normalizer.fold(text)
	var prey_article := RegEx.new()
	prey_article.compile("\\b(que\\s+(?:(?:so|apenas|somente)\\s+)?(?:come|coma|comer|caca|cace|cacar|ataca|ataque|atacar)(?:\\s+(?:apenas|somente))?)\\s+(?:um|uma|uns|umas|o|a|os|as)\\s+")
	out = prey_article.sub(out, "$1 ", true)
	out = out.replace("misturado com", "com corpo de").replace("misturada com", "com corpo de")
	var shield := RegEx.new()
	shield.compile("\\b(?:ante|ant)\\s+bomba")
	out = shield.sub(out, "anti bomba", true)
	var gear := RegEx.new()
	gear.compile("\\bque\\s+(?:use|usa|utilize|utiliza|carregue|carrega|empunhe|empunha)\\s+")
	out = gear.sub(out, "com ", true)
	# The offline recognizer can hear "faça um ninho/escudo" as "fala um ninho/escudo".
	# Repair only this creation context, preserving unrelated uses of "fala".
	var speech := RegEx.new()
	speech.compile("\\bque\\s+fala(?=\\s+(?:(?:um|uma|o|a)\\s+)?(?:escudo|ninho|colmeia)\\b)")
	out = speech.sub(out, "que cria", true)
	var make := RegEx.new()
	make.compile("\\bque\\s+(?:faca|faz|crie|gere|construa|fabrique|produza)\\s+")
	out = make.sub(out, "que cria ", true)
	return out
