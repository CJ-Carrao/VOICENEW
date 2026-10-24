"""Register the expensive, global species-selective bomb and its spoken targets."""
import json
from pathlib import Path

DATA = Path(__file__).resolve().parent.parent / "game/data"

def read(name):
    return json.loads((DATA / name).read_text(encoding="utf-8"))

def write(name, value):
    (DATA / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

def main():
    things = read("defs/things.json")
    words = read("lexicon/pt_br/things.json")
    mods = read("defs/modifiers.json")
    mod_words = read("lexicon/pt_br/modifiers.json")
    display = read("lexicon/pt_br/display.json")
    display["mods"]["target_species"] = {}
    for ident, definition in list(things.items()):
        if not isinstance(definition, dict) or definition.get("category") != "creature":
            continue
        key = "purge_species_" + ident
        mods[key] = {"key": "target_species", "value": ident}
        phrases = set()
        for alias in words[ident].get("words", []) + words[ident].get("forms", []):
            for verb in ["mate", "mata", "elimine", "elimina", "extermine", "extermina"]:
                for quantifier in ["", "todas as ", "todos os ", "todas ", "todos ", "todos os animais da espécie "]:
                    phrases.add(f"que {verb} {quantifier}{alias}")
        mod_words[key] = {"words": sorted(phrases)}
        display["mods"]["target_species"][ident] = "elimina todos: " + words[ident]["name"]
    things["species_bomb"] = {"category": "projectile", "movement": "ballistic", "impact": "stop", "behaviors": [{"when": {"type": "after", "s": 3.0}, "do": {"type": "purge_species"}}]}
    words["species_bomb"] = {"name": "bomba seletiva", "words": ["bomba seletiva", "bomba de espécie", "bomba de especie"], "forms": []}
    balance = read("balance.json")
    balance["things"]["species_bomb"] = {"cost": 290, "weight_kg": 4, "hp": 40}
    balance["cost"]["action_weight"]["purge_species"] = 0
    actions = read("defs/actions.json")
    actions["purge_species"] = {"takes_arg": False}
    model = read("models/neutron_bomb.json")
    for piece in model["pieces"]:
        if piece.get("color") in ["#bce8ef", "#86c3d1"]:
            piece["color"] = "#b7e87e"
    write("models/species_bomb.json", model)
    for name, value in [("defs/things.json", things), ("lexicon/pt_br/things.json", words), ("defs/modifiers.json", mods), ("lexicon/pt_br/modifiers.json", mod_words), ("lexicon/pt_br/display.json", display), ("balance.json", balance), ("defs/actions.json", actions)]:
        write(name, value)
    print("Species bomb registered: 290 matter, all creature species, global selective pulse.")

if __name__ == "__main__":
    main()
