extends Node

var thing: Thing
var remaining = 0.0
var companions: Array[Node] = []
var cursor = 0

func setup(owner_thing: Thing, primary: String, lex: LexiconData) -> void:
	thing = owner_thing
	for donor in load("res://scripts/things/fusion_rules.gd").donors(thing.node_data, lex):
		var settings: Dictionary = lex.thing_def(donor).get("pokemon", {})
		if settings.is_empty() or donor == primary: continue
		var companion = load("res://scripts/things/pokemon_companion.gd").new()
		companion.name = "Fusion_" + donor
		companion.setup(thing,settings)
		# Inherited skills cannot evolve a part for free or earn duplicate combat XP.
		companion.evolution = {}
		add_child(companion)
		companions.append(companion)

func _physics_process(delta: float) -> void:
	if thing.has_simulation_authority() and thing.is_active: remaining = maxf(0.0,remaining-delta)

func auto_attack() -> void:
	if remaining > 0.0 or companions.is_empty(): return
	var choices: Array = companions.duplicate()
	var primary = thing.get_node_or_null("PokemonCompanion")
	if primary != null: choices.push_front(primary)
	for step in choices.size():
		var index: int = (cursor+step)%choices.size()
		var companion = choices[index]
		if companion.remaining <= 0.0:
			var reply: Dictionary = companion.cast(String(companion.moves.keys()[0]))
			if not reply.get("blocked",false): cursor = (index+1)%choices.size(); return

func snapshot() -> Dictionary:
	var values = {}
	for companion in companions: values[companion.name] = companion.snapshot()
	return {"remaining":remaining,"skills":values}

func apply_snapshot(values: Dictionary) -> void:
	remaining = float(values.get("remaining",0.0))
	for companion in companions:
		if values.get("skills",{}).has(companion.name): companion.apply_snapshot(values.skills[companion.name])
