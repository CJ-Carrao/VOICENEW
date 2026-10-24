"""Apply the persistent-creature and composition rules after content generation."""
import json
import unicodedata
from pathlib import Path

DATA = Path(__file__).resolve().parent.parent / "game/data"

def read(path):
    return json.loads((DATA / path).read_text(encoding="utf-8"))

def write(path, data):
    (DATA / path).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

def main():
    defs = read("defs/things.json")
    words = read("lexicon/pt_br/things.json")
    mods = read("defs/modifiers.json")
    mod_words = read("lexicon/pt_br/modifiers.json")
    for key in list(mods):
        if key.startswith("diet_species_"):
            mods.pop(key, None)
            mod_words.pop(key, None)
    def fold(text):
        return " ".join("".join(c for c in unicodedata.normalize("NFD", text.lower()) if unicodedata.category(c) != "Mn").split())
    seen = {fold(word) for entry in mod_words.values() if isinstance(entry, dict) for word in entry.get("words", [])}
    display = read("lexicon/pt_br/display.json")
    balance = read("balance.json")
    for ident, definition in defs.items():
        if not isinstance(definition, dict) or definition.get("category") != "creature":
            continue
        if definition.get("impact") == "destroy":
            definition["impact"] = "stop"
        aliases = words.get(ident, {}).get("words", []) + words.get(ident, {}).get("forms", [])
        diet = {"ant": "ant", "chicken": "chicken", "rat": "rodent", "bee": "bee"}.get(ident, "species:" + ident)
        variants = []
        for noun in aliases:
            for verb in ["come", "coma", "comer", "cace", "caça", "caçar", "ataque", "ataca", "atacar", "coma apenas", "come apenas", "ataque apenas", "ataca apenas", "coma somente", "ataque somente"]:
                variants.extend([f"que só {verb} {noun}", f"que {verb} {noun}"])
        key = "diet_species_" + ident
        mods[key] = {"key": "diet", "value": diet}
        accepted = []
        for variant in sorted(set(variants)):
            if fold(variant) not in seen:
                accepted.append(variant)
                seen.add(fold(variant))
        mod_words[key] = {"words": accepted}
        display["mods"]["diet"][diet] = "caça só " + words.get(ident, {}).get("name", ident)
    balance["caps"].update(live_entities_per_player=0, tree_depth=8, graft_depth=4, grafts_per_recipe=16)
    balance["combat"]["projectiles_hit_own"] = True
    balance["things"]["elephant"]["hp"] = 220
    balance["player"]["hold"]["classes"]["shield"] = {"hip": [.46, -.40, -.55], "ads": [.46, -.40, -.55], "carry": [.45, -.45, -.40], "carry_yaw_deg": 12, "carry_pitch_deg": -5}
    balance["innovation"]["resistance"]["kinetic"] = {"kinetic": .15}
    balance["innovation"]["protection_costs"]["kinetic"] = 14
    for definition in defs.values():
        if not isinstance(definition, dict):
            continue
        ecology = definition.get("ecology", {})
        child = defs.get(ecology.get("produces", ""), {})
        if child.get("category") == "creature":
            ecology["local_cap"] = 0
    mods["resist_rifle"] = {"key": "shield_profile", "value": "kinetic"}
    mod_words["resist_rifle"] = {"words": ["anti rifle", "anti fuzil", "antirifle", "à prova de balas", "antibalas", "anti balas"]}
    display["mods"]["shield_profile"]["kinetic"] = "proteção balística"
    parts = read("defs/parts.json")
    part_words = read("lexicon/pt_br/parts.json")
    # Existing body/blade words remain valid for weapons; anatomy is selected by the recipient category.
    parts["blade"]["anatomy"] = "head"
    parts["body"]["anatomy"] = "body"
    for section, names in {"legs": ["pernas", "patas", "pés"], "wings": ["asas"], "tail": ["cauda", "rabo"]}.items():
        parts["animal_" + section] = {"section": section, "anatomy": section}
        part_words["animal_" + section] = {"words": names}
    network = read("network.json")
    network["creations"]["max_entities"] = 0
    network["world"]["state_hz"] = 30.0
    write("network.json", network)
    write("defs/things.json", defs)
    write("defs/modifiers.json", mods)
    write("lexicon/pt_br/modifiers.json", mod_words)
    write("lexicon/pt_br/display.json", display)
    write("defs/parts.json", parts)
    write("lexicon/pt_br/parts.json", part_words)
    write("balance.json", balance)
    catalog = read("chaos_catalog.json")
    for entry in catalog["creations"]:
        if entry["id"] in ["ant_nest", "beehive"]:
            entry["effect"] = "Gera uma criatura a cada 5 s, pagando materia. Precisa de rainha viva; sem limite de animais ou prazo para sumir."
        elif entry["id"] == "chicken_coop":
            entry["effect"] = "Produz galinhas pagando materia por cada uma, sem limite de animais ou prazo para sumir."
    write("chaos_catalog.json", catalog)
    print("Persistent creatures, generic diets, anatomy, shield posture and world updates configured.")

if __name__ == "__main__":
    main()
