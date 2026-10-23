class_name CreativeComposer
extends RefCounted

const SPOKEN_FORMS := ["faça", "faz", "construa", "fabrique", "produza", "use", "usa", "utilize", "utiliza", "carregue", "carrega", "empunhe", "empunha"]


static func prepare(text: String) -> String:
	var out := Normalizer.fold(text)
	var shield := RegEx.new()
	shield.compile("\\b(?:ante|ant)\\s+bomba")
	out = shield.sub(out, "anti bomba", true)
	var gear := RegEx.new()
	gear.compile("\\bque\\s+(?:use|usa|utilize|utiliza|carregue|carrega|empunhe|empunha)\\s+")
	out = gear.sub(out, "com ", true)
	var make := RegEx.new()
	make.compile("\\bque\\s+(?:faca|faz|construa|fabrique|produza)\\s+")
	out = make.sub(out, "que cria ", true)
	return out
