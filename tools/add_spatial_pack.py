"""Create block-style spatial orbs, vocabulary, prices and catalog entries."""
import json
import math
from pathlib import Path

DATA = Path(__file__).resolve().parent.parent / "game/data"

def read(name):
    return json.loads((DATA / name).read_text(encoding="utf-8"))

def write(name, value):
    (DATA / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

def main():
    things = read("defs/things.json")
    words = read("lexicon/pt_br/things.json")
    balance = read("balance.json")
    catalog = read("chaos_catalog.json")
    macros = read("lexicon/pt_br/macros.json")
    macros.pop("buraco negro", None)
    specs = [
        ("black_hole", "buraco negro", "black", 150, "#171321", "#9b83c9", 20, 6, 7, ["buraco negro", "esfera negra"], "Atrai e comprime. Ao tocar um buraco branco, ambos se anulam numa explosao."),
        ("white_hole", "buraco branco", "white", 150, "#f7f3dc", "#ffd37b", 24, 7, 7, ["buraco branco", "esfera branca"], "Repele. Ao tocar um buraco negro, ambos se anulam numa explosao."),
        ("cursed_blue", "Azul", "blue", 100, "#428aff", "#80c8ff", 18, 5, 6, ["azul", "tecnica azul", "técnica azul", "lapso azul", "lapso da tecnica amaldicoada azul", "lapso da técnica amaldiçoada azul", "azul do gojo"], "Atrai e esmaga. Ao colidir com Vermelho, forma Vazio Roxo."),
        ("reversal_red", "Vermelho", "red", 160, "#ef443e", "#ffb388", 36, 10, 6, ["vermelho", "vermelhor", "tecnica vermelho", "técnica vermelho", "reversao vermelho", "reversão da técnica amaldiçoada vermelho", "vermelho do gojo"], "Repele com o dobro da forca e dano por pulso do Azul. Colisao com Azul cria Vazio Roxo."),
        ("hollow_purple", "Vazio Roxo", "purple", 290, "#9e55ff", "#e3b6ff", 0, 220, 4, ["vazio roxo", "fazio roxo", "vásio roxo", "roxo do gojo", "tecnica roxa", "técnica roxa", "hollow purple"], "Projétil que atravessa alvos e abre um caminho nos blocos. Pedido direto ou fusao de Azul com Vermelho."),
    ]
    ids = {row[0] for row in specs}
    catalog["creations"] = [entry for entry in catalog["creations"] if entry["id"] not in ids]
    for ident, name, mode, cost, core, ring, force, damage, life, aliases, effect in specs:
        pieces = [{"shape": "box", "size": [.42, .42, .42], "pos": [0, 0, 0], "color": core, "tag": "core"}]
        for plane in ["xy", "xz"]:
            for i in range(12):
                a = i * math.tau / 12
                x, side = round(math.cos(a) * .55, 4), round(math.sin(a) * .55, 4)
                pieces.append({"shape": "box", "size": [.11, .11, .11], "pos": [x, side if plane == "xy" else 0, side if plane == "xz" else 0], "color": ring, "tag": "orbit"})
        model = {"_comment": "Original spatial power: cubic core with two voxel rings.", "units": "meters", "anchor": [0, 0, 0], "pieces": pieces}
        write("models/" + ident + ".json", model)
        things[ident] = {"category": "projectile", "movement": "straight", "impact": "stop", "threat_type": "spatial" if mode == "purple" else "gravity", "spatial_orb": {"mode": mode, "life": life, "radius": 7, "force": force, "damage": damage, "color": ring}}
        words[ident] = {"name": name, "words": aliases, "forms": []}
        balance["things"][ident] = {"cost": cost, "weight_kg": 2, "hp": 70, "speed": 20 if mode == "purple" else 12, "lifetime": life, "impact_damage": 0}
        catalog["creations"].append({"id": ident, "name": name, "phrase": "quero " + name.lower(), "group": "Espaço", "effect": effect, "pieces": len(pieces), "base_cost": cost})
    write("defs/things.json", things)
    write("lexicon/pt_br/things.json", words)
    write("balance.json", balance)
    write("chaos_catalog.json", catalog)
    write("lexicon/pt_br/macros.json", macros)
    print("Five spatial powers generated; Blue/Red force and damage ratio = 1:2.")

if __name__ == "__main__":
    main()
