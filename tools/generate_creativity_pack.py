"""Extend the grammar, ecological relationships and counter-play economy."""
import copy
from generate_chaos_pack import ROOT, DATA, read, write, model, box, weapon, insect


def shield_model(color):
    p = []
    for x in [-.42, .42]:
        box(p, [.09, 1.1, .10], [x, .57, 0], "#394551", "frame")
    for y in [.06, 1.08]:
        box(p, [.92, .09, .10], [0, y, 0], "#394551", "frame")
    for x in [-.26, 0, .26]:
        box(p, [.20, .85, .07], [x, .57, 0], color, "panel", glow=.12)
    box(p, [.17, .18, .14], [0, .57, .10], "#d6bd7c", "core", glow=.5)
    box(p, [.07, .30, .07], [0, .57, .20], "#394551", "handle")
    return model(p, [0, .57, .20])


def house(walking):
    p = []
    floor = 1.1 if walking else .1
    box(p, [2.8, .18, 3.2], [0, floor, 0], "#7e6952", "floor")
    for side in [-1, 1]:
        box(p, [.16, 1.8, 3.2], [side * 1.32, floor + .97, 0], "#a79978", "wall")
    box(p, [2.8, 1.8, .16], [0, floor + .97, 1.52], "#a79978", "wall")
    for side in [-1, 1]:
        box(p, [.80, 1.8, .16], [side * .96, floor + .97, -1.52], "#a79978", "wall")
        box(p, [.45, .55, .05], [side * .96, floor + 1.1, -1.62], "#7dabc0", "window")
    box(p, [.95, .35, .18], [0, floor + 1.70, -1.52], "#a79978", "lintel")
    for i in range(4):
        box(p, [3.1 - .55 * i, .20, 3.5], [0, floor + 1.96 + .17 * i, 0], "#94583b", "roof")
    box(p, [.35, .65, .4], [.75, floor + 2.55, .7], "#5c6266", "chimney")
    if walking:
        for side in [-1, 1]:
            for z in [-1.0, 1.0]:
                box(p, [.25, .83, .28], [side * .95, .56, z], "#505d60", "leg")
                box(p, [.48, .22, .65], [side * .95, .12, z - .10], "#3b454a", "foot")
    return model(p, [0, floor + .5, 0])


def nest(color):
    p = []
    for i, size in enumerate([1.6, 1.32, 1.02, .68]):
        box(p, [size, .23, size], [0, .12 + i * .21, 0], color, "nest")
    box(p, [.36, .28, .12], [0, .21, -.82], "#27282b", "entrance")
    for side in [-1, 1]:
        box(p, [.18, .12, .18], [side * .26, .91, 0], "#d2b677", "egg")
    return model(p, [0, .3, 0])


def bee_queen():
    p = []
    box(p, [.30, .23, .48], [0, .24, .10], "#c7a450", "abdomen")
    for z in [-.03, .12, .27]:
        box(p, [.31, .24, .045], [0, .24, z], "#3c3930", "stripe")
    box(p, [.22, .20, .19], [0, .27, -.22], "#6c603c", "head")
    for side in [-1, 1]:
        box(p, [.32, .035, .28], [side * .26, .39, .03], "#ced9cf", "wing")
        box(p, [.04, .07, .035], [side * .095, .30, -.325], "#20262b", "eye")
        for z in [-.07, .08, .23]:
            box(p, [.035, .15, .035], [side * .13, .09, z], "#494439", "leg")
        box(p, [.025, .14, .025], [side * .075, .43, -.23], "#494439", "antenna")
    box(p, [.055, .045, .12], [0, .23, .39], "#494439", "stinger")
    return model(p, [0, .25, 0])


def coop():
    visual = house(False)
    for piece in visual["pieces"]:
        piece["pos"] = [v * .65 for v in piece["pos"]]
        piece["size"] = [v * .65 for v in piece["size"]]
    for x in [-.8, .8]:
        for z in [-1.3, -1.8, -2.3]:
            box(visual["pieces"], [.09, .55, .09], [x, .28, z], "#9e8561", "fence")
        for y in [.18, .43]:
            box(visual["pieces"], [.07, .07, 1.4], [x, y, -1.75], "#9e8561", "fence")
    for x in [-.3, 0, .3]:
        box(visual["pieces"], [.15, .12, .18], [x, .11, -1.65], "#d6cba5", "egg")
    return visual


def main():
    defs = read("defs/things.json")
    words = read("lexicon/pt_br/things.json")
    modifiers = read("defs/modifiers.json")
    modifier_words = read("lexicon/pt_br/modifiers.json")
    balance = read("balance.json")
    catalog = read("chaos_catalog.json")
    rows = []
    profiles = {
        "blast": ("bombas", "#b5aa82", 24, {"blast": .15, "nuclear": .75}),
        "neutron": ("nêutrons", "#8cc8cf", 38, {"neutron": .10}),
        "nuclear": ("bombas nucleares", "#d3b96d", 48, {"nuclear": .15, "blast": .40}),
        "gravity": ("gravidade", "#a18bbe", 34, {"gravity": .15}),
        "spatial": ("cortes espaciais", "#b29aca", 60, {"spatial": .25}),
    }
    def add(ident, name, aliases, category, visual, config, stats, effect, group):
        defs[ident] = {"category": category, **config}
        words[ident] = {"name": name, "words": [name, *aliases], "forms": []}
        balance["things"][ident] = stats
        write(f"models/{ident}.json", visual)
        rows.append({"id": ident, "name": name, "phrase": "quero " + name, "group": group, "effect": effect, "pieces": len(visual["pieces"])})

    for profile, (label, color, cost, resistance) in profiles.items():
        name = "escudo anti " + label
        aliases = ["escudo contra " + label]
        if profile == "neutron":
            aliases += ["escudo anti bomba de nêutrons", "escudo anti bomba de neutrons", "escudo anti neutrinos", "escudo anti bomba de neutrinos", "escudo anti bomba de neutrino", "escudo anti neutrino", "escudo anti bomba de neutron"]
        if profile == "blast":
            aliases += ["escudo anti bomba", "escudo antibomba"]
        add(profile + "_shield", name, aliases, "tool", shield_model(color), {"movement": "static", "impact": "stop", "held_protection": True, "shield_profile": profile, "shield_radius": 3.5},
            {"cost": cost, "hp": 150, "weight_kg": 4.0}, "Protege aliados num raio de 3,5 m contra esta ameaca; absorver dano desgasta o escudo. Outros tipos atravessam.", "Defesas")
        modifiers["resist_" + profile] = {"key": "shield_profile", "value": profile}
        aliases = ["anti " + label, "contra " + label, "a prova de " + label]
        if profile == "blast":
            aliases += ["anti bomba", "antibomba", "anti bombas", "anti explosao", "a prova de explosao"]
        elif profile == "neutron":
            aliases += ["anti bomba de neutrons", "anti bomba de neutrinos", "anti neutrinos", "anti bomba de neutrino", "anti neutrino", "anti bomba de neutron", "antineutrons", "contra bomba de neutrons", "a prova de bomba de neutrons"]
        elif profile == "nuclear":
            aliases += ["anti nuclear", "antinuclear", "anti bomba nuclear"]
        elif profile == "gravity":
            aliases += ["anti bomba de gravidade", "antigravidade"]
        modifier_words["resist_" + profile] = {"words": aliases}

    for diet, names in {"ant": ["formiga", "formigas"], "insect": ["inseto", "insetos"], "rodent": ["rato", "ratos"], "chicken": ["galinha", "galinhas"]}.items():
        key = "diet_" + diet
        modifiers[key] = {"key": "diet", "value": diet}
        variants = []
        for noun in names:
            for verb in ["come", "coma", "caca", "cace"]:
                variants += [f"que so {verb} {noun}", f"que {verb} {noun}", f"que {verb} apenas {noun}", f"que so {verb} {noun}"]
            variants += [f"comedor de {noun}", f"que se alimenta de {noun}"]
        modifier_words[key] = {"words": sorted(set(variants))}
    balance["cost"]["mods"]["diet"] = 8
    modifiers["walking"] = {"key": "movement", "value": "chase_enemy"}
    modifier_words["walking"] = {"words": ["ambulante", "andante", "que anda", "que caminhe", "que caminha"]}

    add("house", "casa", ["casinha", "casa de blocos"], "structure", house(False), {"movement": "static", "impact": "stop", "enclosure": True}, {"cost": 38, "hp": 240, "weight_kg": 500}, "Casa oca com porta, janelas e teto em blocos.", "Defesas")
    add("walking_house", "casa ambulante", ["casa que anda", "casa andante", "casa movel"], "vehicle", house(True), {"movement": "chase_enemy", "impact": "stop", "enclosure": True, "voxel_motion": True}, {"cost": 90, "hp": 240, "weight_kg": 600, "speed": 1.6, "impact_damage": 5}, "Casa com pernas; aceita protecoes, armas acopladas e controle remoto.", "Defesas")
    for ident, name, nest_id, child_id, tint, queen_tag in [
        ("queen_ant", "formiga rainha", "ant_nest", "ant", "#9c7144", "ant_queen"),
        ("queen_bee", "abelha rainha", "beehive", "bee", "#c3a25a", "bee_queen"),
    ]:
        visual = copy.deepcopy(insect("ant") if child_id == "ant" else bee_queen())
        for piece in visual["pieces"]:
            if piece["shape"] != "box":
                # The old bee's rounded pieces become box silhouettes for the new queen.
                diameter = float(piece.get("radius", .1)) * 2
                piece["size"] = piece.get("_stretch", [diameter, piece.get("height", diameter), diameter])
                piece["shape"] = "box"
                piece.pop("_stretch", None)
            piece["pos"] = [v * 2 for v in piece["pos"]]
            piece["size"] = [v * 2 for v in piece["size"]]
        head = next(p for p in visual["pieces"] if p.get("tag") == "head")
        crown_y = head["pos"][1] + head["size"][1] / 2 + .055
        for x in [-.06, 0, .06]:
            box(visual["pieces"], [.045, .07 + (.04 if x == 0 else 0), .045], [x, crown_y, head["pos"][2]], "#d6b86c", "crown")
        add(ident, name, ["rainha das formigas" if child_id == "ant" else "rainha das abelhas"], "creature", visual,
            {"movement": "chase_enemy" if child_id == "ant" else "fly", "impact": "stop", "voxel_motion": True, "aerial": child_id == "bee", "ecology_tags": [child_id, "insect", "queen", queen_tag], "ecology": {"produces": nest_id, "interval": 8, "local_cap": 1}},
            {"cost": 85, "hp": 85, "weight_kg": 1.5, "speed": .55, "impact_damage": 3}, "Constroi um ninho pago com sua materia. Um ninho por rainha; a morte dela interrompe a producao.", "Ecologia")
        add(nest_id, "ninho de formigas" if child_id == "ant" else "colmeia", ["formigueiro", "ninho"] if child_id == "ant" else ["ninho de abelhas"], "structure", nest(tint),
            {"movement": "static", "impact": "stop", "ecology_tags": ["nest"], "ecology": {"produces": child_id, "interval": 5, "local_cap": 8 if child_id == "ant" else 5, "needs_queen": True, "queen_tag": queen_tag, "child_lifetime": 60}},
            {"cost": 30, "hp": 90, "weight_kg": 10}, "Gera uma criatura a cada 5 s, consumindo materia. Precisa de rainha viva; producao limitada por ninho.", "Ecologia")
    add("chicken_coop", "galinheiro", ["criador de galinhas"], "structure", coop(), {"movement": "static", "impact": "stop", "enclosure": True, "ecology": {"produces": "chicken", "interval": 8, "local_cap": 4, "child_lifetime": 60}},
        {"cost": 55, "hp": 130, "weight_kg": 80}, "Produz ate quatro galinhas vivas, pagando materia por cada uma.", "Ecologia")
    visual = copy.deepcopy(read("models/capybara.json"))
    box(visual["pieces"], [.10, .10, .57], [0, .41, -.67], "#9b8b70", "snout")
    box(visual["pieces"], [.28, .22, .8], [0, .31, .73], "#676250", "tail")
    add("anteater", "tamanduá", ["tamandua", "tamanduás"], "creature", visual, {"movement": "chase_enemy", "impact": "stop", "diet": "ant", "voxel_motion": True},
        {"cost": 28, "hp": 55, "weight_kg": 20, "speed": 3.1, "impact_damage": 6}, "Caca somente formigas e rainhas, inclusive da sua colonia. Nao ataca jogadores.", "Ecologia")
    add("shield_projector", "projetor de escudos", ["arma que faz escudos", "arma de escudos"], "weapon", weapon("shield_projector", "#91b5c2", True),
        {"projectile": "blast_shield", "behaviors": [{"when": {"type": "on_fire"}, "do": {"type": "spawn", "arg": {"thing": "blast_shield"}}}]},
        {"cost": 65, "hp": 60, "weight_kg": 3, "fire_cooldown": 1.5}, "Cria escudos no mundo. Cada disparo paga o escudo; limite de tres campos por equipe.", "Armas especiais")
    balance["weapons"]["shield_projector"] = {"rear": {"fire_interval_s": 1.5, "magazine": 0}, "front": {"power": 1}, "muzzle": {"barrels": 1}}

    for ident, tags in {"ant": ["ant", "insect"], "bee": ["bee", "insect"], "beetle": ["insect"], "butterfly": ["insect"], "mantis": ["insect"], "rat": ["rodent"], "chicken": ["chicken"]}.items():
        defs[ident]["ecology_tags"] = tags
    prices = {"nuclear_bomb": 240, "neutron_bomb": 210, "gravity_bomb": 110, "hypothetical_gravity_bomb": 145, "singularity_bomb": 220, "repulsion_bomb": 65, "frost_bomb": 60, "inferno_bomb": 85, "storm_bomb": 100, "emp_bomb": 55, "meteor_bomb": 160, "cluster_bomb": 110, "rift_knife": 180, "gravity_hammer": 90, "thunder_hammer": 95, "frost_axe": 70, "inferno_sword": 80, "ant_launcher": 60, "chicken_launcher": 75, "bee_launcher": 75}
    for ident, price in prices.items():
        balance["things"][ident]["cost"] = price
    for ident in prices:
        if ident.endswith("_bomb"):
            action = defs[ident]["behaviors"][0]["do"]
            defs[ident]["threat_type"] = {"hypothetical": "gravity", "singularity": "gravity", "repulsion": "gravity"}.get(action["mode"], action["mode"])
    defs["rift_knife"]["threat_type"] = "spatial"
    defs["rift_knife"]["behaviors"][1]["do"].update(reach=16, damage=48)
    balance["weapons"]["rift_knife"]["rear"]["fire_interval_s"] = 1.6
    for ident, radius, damage in [("nuclear_bomb", 12, 160), ("neutron_bomb", 9, 110), ("gravity_bomb", 7, 30), ("singularity_bomb", 8, 65)]:
        defs[ident]["behaviors"][0]["do"].update(radius=radius, damage=damage)
        balance["things"][ident].update(explosion_radius=radius, explosion_damage=damage)
    for ident, definition in defs.items():
        if not isinstance(definition, dict) or not ident.endswith("_grenade"):
            continue
        act = definition["behaviors"][0]["do"]
        if act["type"] == "burst_into":
            payload = act["arg"]
            balance["things"][ident]["cost"] = round(5 + balance["things"][payload["thing"]]["cost"] * payload["mods"]["count"], 1)
    words["neutron_bomb"]["words"] = list(dict.fromkeys([*words["neutron_bomb"]["words"], "bomba de neutrinos", "bomba de neutrino"]))
    balance["innovation"] = {"shield_wear": .70, "resistance": {key: value[3] for key, value in profiles.items()}, "protection_costs": {"blast": 14, "neutron": 26, "nuclear": 36, "gravity": 22, "spatial": 48}}
    # Keep curated base prices high; extra abilities and offspring are still charged recursively.
    balance["cost"]["action_weight"]["anomaly"] = 25
    write("defs/things.json", defs)
    write("defs/modifiers.json", modifiers)
    write("lexicon/pt_br/things.json", words)
    write("lexicon/pt_br/modifiers.json", modifier_words)
    write("balance.json", balance)
    display = read("lexicon/pt_br/display.json")
    display["mods"]["shield_profile"] = {"blast": "proteção contra bombas", "neutron": "proteção contra nêutrons", "nuclear": "proteção nuclear", "gravity": "proteção gravitacional", "spatial": "proteção espacial"}
    display["mods"]["diet"] = {"ant": "come só formigas", "insect": "come só insetos", "rodent": "come só ratos", "chicken": "come só galinhas"}
    write("lexicon/pt_br/display.json", display)
    manifest = read("world_assets_manifest.json")
    new_ids = {r["id"] for r in rows}
    manifest["assets"] = [r for r in manifest["assets"] if r["id"] not in new_ids] + [{"id": r["id"], "group": defs[r["id"]]["category"], "pieces": r["pieces"], "reference": "arte original em blocos do pacote Criatividade"} for r in rows]
    manifest["new_definitions"] = len(manifest["assets"])
    write("world_assets_manifest.json", manifest)
    ids = {r["id"] for r in rows}
    catalog["creations"] = [r for r in catalog["creations"] if r["id"] not in ids] + rows
    for row in catalog["creations"]:
        row["base_cost"] = balance["things"][row["id"]]["cost"]
        if row["id"] == "neutron_bomb":
            row["effect"] = "Explosao azul com blocos e cratera curta; o pulso de neutrons atinge criaturas mais longe. Escudo comum nao protege."
    catalog["version"] = 2
    catalog["combinations"] = [
        {"name": "Arma que fabrica defesa", "phrase": "quero uma arma que faça um escudo anti bomba de nêutrons", "effect": "Cria o escudo especializado ao disparar; a producao paga materia por escudo."},
        {"name": "Jacare armado", "phrase": "quero um jacaré que use uma AK47", "effect": "Animal com arma acoplada e mira automatica; a arma aumenta o custo."},
        {"name": "Casa protegida", "phrase": "quero uma casa ambulante anti bomba de nêutrons", "effect": "Combina movimento, casa oca e campo de protecao especializado."},
        {"name": "Colonia de formigas", "phrase": "quero uma formiga rainha que faça um ninho", "effect": "A rainha faz um ninho pago que produz formigas enquanto ela vive e ha materia."},
        {"name": "Pato predador", "phrase": "quero um pato que só coma formigas", "effect": "Caca apenas formigas e rainhas, ate da propria equipe. Sem elas, fica quieto."},
        {"name": "Barreira com protecao escolhida", "phrase": "quero uma parede anti bomba nuclear", "effect": "O mesmo modificador de defesa pode ser aplicado em outras criacoes."},
        {"name": "Raposa seletiva", "phrase": "quero uma raposa que só coma ratos", "effect": "Outra combinacao de criatura com uma dieta especifica."},
    ]
    write("chaos_catalog.json", catalog)
    print(f"Creativity pack: {len(rows)} new templates, {len(catalog['combinations'])} composed examples, paid production and counter-play prices.")


if __name__ == "__main__":
    main()
