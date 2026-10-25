extends RefCounted

static func match_text(pattern: String, text: String):
	var regex = RegEx.new()
	regex.compile(pattern)
	return regex.search(text)

static func species(text: String, lex: LexiconData) -> String:
	var clean = Normalizer.fold(text).strip_edges()
	clean = match_replace("^(?:o|a|os|as|um|uma|uns|umas|meu|minha|meus|minhas) +",clean,"")
	for id in lex.lexicon.things:
		if not lex.lexicon.things[id] is Dictionary: continue
		var names: Dictionary = lex.lexicon.things[id]
		for word in names.get("words",[])+names.get("forms",[]):
			if Normalizer.fold(String(word)) == clean: return String(id)
	return ""

static func match_replace(pattern: String, text: String, replacement: String) -> String:
	var regex = RegEx.new()
	regex.compile(pattern)
	return regex.sub(text,replacement)

static func command(text: String, lex: LexiconData) -> Dictionary:
	var found = match_text("^(.+?) (?:proteja|protejam|protege) (.+?)(?: (?:e )?se (?:ele|ela) (?:ficar|estiver) ferid[oa] (?:leve|traga) (?:ele|ela) (?:ate|para) mim)$",text)
	if found != null: return pair(found.get_string(1),found.get_string(2),"rescue",lex)
	found = match_text("^(.+?) (?:proteja|protejam|protege) (.+)$",text)
	if found != null:
		var result = pair(found.get_string(1),found.get_string(2),"guard_friend",lex)
		if not result.is_empty(): return result
	for entry in [["(?:carregue|carreguem|transporte|transportem|leve|levem)","carry"],["(?:conserte|consertem|repare|reparem)","repair"]]:
		found = match_text("^(.+?) "+entry[0]+" (.+)$",text)
		if found != null:
			var target = match_replace("^(?:a )?armadura d[oa] +",found.get_string(2),"")
			var result = pair(found.get_string(1),target,entry[1],lex)
			if not result.is_empty(): return result
	found = match_text("^(.+?) se (?:eu for|eu estiver sendo) atacado (?:me proteja|me defenda)$",text)
	if found != null: return single(found.get_string(1),"defend_owner",lex)
	found = match_text("^(.+?) se (?:ficar|estiver) com pouca vida (?:recue|fuja|volte ate mim)$",text)
	if found != null: return single(found.get_string(1),"retreat",lex)
	for entry in [["(?:solte|soltem|desembarque|desembarquem)(?: a carga)?","release"],["(?:cancele|cancelem|esqueca|esquecam) (?:a )?(?:regra|ordem condicional)","cancel"],["(?:transforme se|transforme agora|vire agora)","transform"],["volte a forma original","revert"]]:
		found = match_text("^(.+?) "+entry[0]+"$",text)
		if found != null: return single(found.get_string(1),entry[1],lex)
	return {}

static func single(actor_name: String, action: String, lex: LexiconData) -> Dictionary:
	var actor = species(actor_name,lex)
	if actor.is_empty() or lex.category_of(actor) != "creature": return {}
	var plural = false
	for word in lex.lexicon.things.get(actor,{}).get("forms",[]):
		if Normalizer.fold(String(word)) == Normalizer.fold(actor_name): plural = true
	return {"command":"creature_tactics","tactics":{"actor":actor,"action":action,"all":plural}}
static func pair(actor_name: String, target_name: String, action: String, lex: LexiconData) -> Dictionary:
	var result = single(actor_name,action,lex)
	var target = species(target_name,lex)
	if result.is_empty() or target.is_empty(): return {}
	if action in ["guard_friend","rescue"] and lex.category_of(target) != "creature": return {}
	result.tactics.target = target
	return result

static func creation(text: String, lex: LexiconData) -> Dictionary:
	var found = match_text("^(.+?) (?:que|q) (?:vire|vira|se transforme em|transforme em) (.+?) quando (?:(?:estiver|ficar|tiver|tem)(?: com)? pouca vida|(?:a )?vida (?:estiver|ficar) baixa)$",text)
	if found == null: return {}
	var form = species(found.get_string(2),lex)
	if not valid_form(form,lex): return {}
	return {"base":found.get_string(1),"form":form}
static func valid_form(id: String, lex: LexiconData) -> bool:
	return not id.is_empty() and lex.category_of(id) in ["creature","vehicle"] and not lex.thing_def(id).get("coop_boss",false) and not lex.lexicon.things.get(id,{}).get("words",[]).is_empty()
