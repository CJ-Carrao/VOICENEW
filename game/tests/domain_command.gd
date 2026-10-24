extends SceneTree

var failures := []
var game
var forge
var lex
var assembler
var recipe

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func equip(id: String):
	var item = assembler.build(recipe.new_node(id), "head", lex)
	item.set_owner_info(1, 1, game.player, null)
	game.player.hands.give(item, false)
	item.activate()
	return item

func _run() -> void:
	await process_frame
	load("res://scenes/main.gd").next_mode = "practice"
	game = load("res://scenes/main.tscn").instantiate()
	game.voice_enabled = false
	root.add_child(game)
	current_scene = game
	forge = root.get_node("Forge")
	lex = root.get_node("Lexicon").data
	assembler = load("res://scripts/things/assembler.gd")
	recipe = load("res://scripts/language/recipe.gd")
	var parser = load("res://scripts/language/phrase_parser.gd")
	var callout = load("res://scripts/fx/domain_callout.gd")
	await create_timer(.6).timeout
	game.player.frozen = false
	for phrase in ["expansão de domínio", "expansao de dominio", "expandir domínio", "expanda o dominio"]:
		var parsed: Dictionary = parser.parse(phrase, lex)
		check(parsed.get("ok", false) and parsed.recipe.get("command") == "expand_domain" and parsed.unknown_words.is_empty() and parsed.ignored_words.is_empty(), "Expansion command not recognized: " + phrase)
	var no_item: Dictionary = forge.request(1, "expansão de domínio")
	check(no_item.get("blocked", false) and callout.count == 0, "Command granted free domain without equipment")
	var gojo = equip("unlimited_void")
	var before: int = callout.count
	var response: Dictionary = forge.request(1, "expansão de domínio")
	check(response.get("domain_expanded") == "void" and gojo.get_node("Jujutsu").domain_until > 0, "Command did not activate equipped Gojo domain")
	check(callout.count == before and callout.last_text.is_empty(), "Gojo domain should not announce dialogue")
	check(root.find_children("DomainWords", "", true, false).is_empty() and root.find_children("DomainSubtitle", "", true, false).is_empty(), "Gojo domain should not create captions")
	response = forge.request(1, "expansão de domínio")
	check(response.get("blocked", false) and callout.count == before, "Repeated voice command bypassed cooldown or spammed dialogue")
	var sukuna = equip("malevolent_shrine")
	response = forge.request(1, "expansao de dominio")
	check(response.get("domain_expanded") == "shrine" and sukuna.get_node("Jujutsu").domain_until > 0, "Command did not choose equipped Sukuna domain")
	check(callout.count == before and callout.last_text.is_empty(), "Sukuna domain should not announce dialogue")
	check(root.find_children("DomainWords", "", true, false).is_empty() and root.find_children("DomainSubtitle", "", true, false).is_empty(), "Domains should not create captions")
	var result := {"failures": failures, "announcements": callout.count, "last_line": callout.last_text}
	var file := FileAccess.open(ProjectSettings.globalize_path("res://").path_join("../analysis/domain-command.json").simplify_path(), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	print("DOMAIN_COMMAND ", JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
