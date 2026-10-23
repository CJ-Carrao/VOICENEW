"""Build the voxel-style Chaos Pack catalogs and original procedural models."""
from pathlib import Path
import copy
import json
import math

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "game/data"


def read(path):
    return json.loads((DATA / path).read_text(encoding="utf-8-sig"))


def write(path, value):
    (DATA / path).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def box(pieces, size, pos, color, tag="body", rot=None, glow=0):
    item = {"shape": "box", "size": size, "pos": pos, "color": color, "tag": tag}
    if rot:
        item["rot"] = rot
    if glow:
        item["glow"] = glow
    pieces.append(item)


def bar(pieces, a, b, width, color, tag):
    d = [b[i] - a[i] for i in range(3)]
    length = math.sqrt(sum(x * x for x in d))
    box(pieces, [round(length, 5), width, width], [round((a[i] + b[i]) / 2, 5) for i in range(3)], color, tag,
        [0, math.degrees(math.atan2(-d[2], d[0])), math.degrees(math.atan2(d[1], math.hypot(d[0], d[2])))])


def model(pieces, anchor=None):
    return {"_comment": "Arte original do Pacote Caos: silhueta em blocos, sem superficies arredondadas.",
            "units": "meters", "anchor": anchor or [0, 0.45, 0], "pieces": pieces}


def insect(kind):
    p = []
    colors = {"ant": ["#85452d", "#5b3024"], "beetle": ["#365f3e", "#243d30"], "mantis": ["#749f48", "#476a35"]}
    c, dark = colors[kind]
    box(p, [.115, .09, .10], [0, .13, -.13], c, "head")
    box(p, [.085, .08, .115], [0, .11, -.025], c)
    box(p, [.045, .045, .045], [0, .11, .055], dark, "waist")
    box(p, [.14, .105, .15], [0, .12, .14], dark, "abdomen")
    box(p, [.105, .035, .11], [0, .19 if kind == "mantis" else .19 - .015, .14], c, "shell")
    for side in [-1, 1]:
        for index, z in enumerate([-.07, -.025, .018]):
            knee = [side * .115, .08, z + [-.05, 0, .055][index]]
            bar(p, [side * .03, .11, z], knee, .022, c, "leg")
            bar(p, knee, [side * .18, .015, z + [-.09, .01, .11][index]], .018, dark, "leg")
        box(p, [.022, .026, .024], [side * .054, .15, -.155], "#171b22", "eye")
        bar(p, [side * .03, .16, -.16], [side * .06, .205, -.205], .014, dark, "antenna")
        bar(p, [side * .06, .205, -.205], [side * .11, .19, -.26], .012, dark, "antenna")
        box(p, [.025, .025, .045], [side * .025, .105, -.192], dark, "mandible")
    if kind == "beetle":
        for side in [-1, 1]:
            box(p, [.085, .09, .18], [side * .048, .165, .12], c, "shell")
        box(p, [.035, .11, .035], [0, .22, -.16], dark, "horn")
    if kind == "mantis":
        for side in [-1, 1]:
            bar(p, [side * .05, .14, -.06], [side * .11, .24, -.16], .027, c, "leg")
            bar(p, [side * .11, .24, -.16], [side * .06, .14, -.23], .024, dark, "leg")
    return model(p, [0, .11, 0])


def animal(kind, color, accent, scale=1.0):
    if kind in ["beetle", "mantis"]:
        return insect(kind)
    p = []
    birds = ["duck", "goose", "turkey"]
    flyers = ["bat", "butterfly"]
    if kind in birds:
        box(p, [.31, .29, .43], [0, .30, 0], color)
        neck = .27 if kind == "goose" else .12
        box(p, [.12, neck, .13], [0, .42 + neck / 2, -.19], color, "neck")
        box(p, [.18, .17, .18], [0, .48 + neck, -.23], color, "head")
        box(p, [.14, .065, .17], [0, .46 + neck, -.36], "#e5a344", "beak")
        for side in [-1, 1]:
            box(p, [.055, .17, .29], [side * .18, .34, .02], accent, "wing")
            box(p, [.045, .17, .045], [side * .09, .10, 0], "#bf7d35", "leg")
            box(p, [.10, .04, .14], [side * .09, .025, -.045], "#d99239", "foot")
            box(p, [.025, .035, .035], [side * .095, .51 + neck, -.28], "#151b25", "eye")
        box(p, [.17, .11, .13], [0, .36, .27], accent, "tail")
        if kind == "turkey":
            for i in range(5):
                box(p, [.095, .29 + .05 * (2 - abs(i - 2)), .045], [(i - 2) * .08, .52, .23], accent, "tail", [0, 0, (i - 2) * -16])
            box(p, [.04, .14, .04], [0, .52, -.34], "#b74835", "wattle")
    elif kind in flyers:
        box(p, [.12, .14, .30], [0, .42, 0], color)
        box(p, [.15, .13, .12], [0, .47, -.18], color, "head")
        for side in [-1, 1]:
            for row in range(3):
                box(p, [.22, .025, .20 - .035 * row], [side * (.17 + .17 * row), .44, row * .045], accent, "wing")
                box(p, [.07, .03, .065], [side * (.17 + .17 * row), .46, row * .045], color, "wing")
            box(p, [.035, .11, .035], [side * .07, .57, -.18], accent, "ear" if kind == "bat" else "antenna")
            box(p, [.024, .03, .03], [side * .075, .49, -.24], "#18212a", "eye")
    elif kind == "snail":
        box(p, [.20, .10, .50], [0, .06, -.025], "#a78e61")
        box(p, [.24, .27, .25], [0, .22, .08], color, "shell")
        box(p, [.18, .08, .18], [0, .39, .08], accent, "shell")
        for side in [-1, 1]:
            box(p, [.025, .13, .025], [side * .065, .17, -.23], "#a78e61", "antenna")
            box(p, [.04, .04, .04], [side * .065, .245, -.23], "#19212b", "eye")
        for i in range(4):
            box(p, [.015, .04, .045], [.128, .14 + (i % 2) * .07, .025 + (i // 2) * .07], accent, "shell")
    elif kind == "octopus":
        box(p, [.30, .27, .29], [0, .23, 0], color, "head")
        box(p, [.23, .065, .23], [0, .39, 0], color, "head")
        for i in range(8):
            angle = math.tau * i / 8
            a = [math.cos(angle) * .10, .13, math.sin(angle) * .10]
            b = [math.cos(angle) * .27, .065, math.sin(angle) * .27]
            c = [math.cos(angle) * .41, .025, math.sin(angle) * .41]
            bar(p, a, b, .07, color, "leg"); bar(p, b, c, .055, accent, "leg")
        for side in [-1, 1]:
            box(p, [.055, .065, .035], [side * .09, .25, -.16], "#eee6c9", "eye")
            box(p, [.025, .04, .018], [side * .09, .25, -.183], "#18212a", "eye")
    elif kind == "slime":
        box(p, [.53, .30, .49], [0, .16, 0], color)
        box(p, [.41, .12, .39], [0, .36, 0], color)
        box(p, [.28, .06, .27], [0, .45, 0], accent)
        for side in [-1, 1]:
            box(p, [.065, .065, .025], [side * .11, .25, -.25], "#18212a", "eye")
        box(p, [.12, .035, .025], [0, .15, -.25], "#285539", "mouth")
    else:
        low = kind in ["capybara", "otter", "hedgehog", "armadillo"]
        body_y = .40 if low else .64
        body_h = .35 if low else .45
        box(p, [.53, body_h, .87], [0, body_y, 0], color)
        head_y = body_y + .15
        neck = {"giraffe": 1.18, "llama": .59, "camel": .39}.get(kind, 0)
        if neck:
            box(p, [.22, neck, .25], [0, body_y + neck / 2, -.40], color, "neck")
            head_y = body_y + neck
        box(p, [.31, .30, .36], [0, head_y, -.53], color, "head")
        box(p, [.24, .14, .14], [0, head_y - .065, -.76], accent, "muzzle")
        leg_h = body_y - body_h / 2
        for side in [-1, 1]:
            for z in [-.29, .29]:
                box(p, [.115, leg_h, .13], [side * .19, leg_h / 2, z], accent, "leg")
                box(p, [.13, .07, .17], [side * .19, .035, z - .02], "#3b3d3e", "hoof")
            ear_height = .26 if kind in ["donkey", "llama"] else .11
            box(p, [.095, ear_height, .09], [side * .17, head_y + .17 + ear_height / 2, -.49], accent, "ear")
            box(p, [.025, .045, .045], [side * .165, head_y + .035, -.66], "#17202a", "eye")
        box(p, [.085, .09, .33], [0, body_y + .02, .57], accent, "tail")
        if kind in ["cow", "bison", "rhino"]:
            for side in [-1, 1]:
                box(p, [.06, .18, .06], [side * .16, head_y + .22, -.52], "#d7ccab", "horn")
        if kind == "rhino":
            box(p, [.11, .25, .10], [0, head_y + .13, -.74], "#d7ccab", "horn")
        if kind == "camel":
            for z in [-.16, .18]:
                box(p, [.34, .28, .25], [0, body_y + .31, z], accent, "hump")
        if kind == "giraffe":
            for i in range(6):
                for side in [-1, 1]:
                    box(p, [.025, .12, .12], [side * .125, body_y + .12 + i * .16, -.40], accent, "patch")
        if kind in ["zebra", "raccoon"]:
            for i in range(6):
                for side in [-1, 1]:
                    box(p, [.018, body_h * .9, .07], [side * .274, body_y, -.35 + i * .14], accent, "stripe")
        if kind in ["panda", "koala", "raccoon"]:
            for side in [-1, 1]:
                box(p, [.10, .10, .022], [side * .09, head_y + .03, -.72], accent, "mask")
                box(p, [.027, .04, .025], [side * .09, head_y + .035, -.74], "#ece9d6", "eye")
        if kind in ["sheep", "armadillo", "hedgehog"]:
            for i in range(5):
                for side in [-1, 0, 1]:
                    box(p, [.15, .10 if kind != "hedgehog" else .17, .11], [side * .17, body_y + body_h / 2 + .025, -.31 + i * .16], accent, "shell")
        if kind == "cow":
            for side in [-1, 1]:
                box(p, [.025, .24, .25], [side * .277, body_y, .11], accent, "patch")
        if kind == "pig":
            for side in [-1, 1]:
                box(p, [.035, .04, .022], [side * .06, head_y - .065, -.84], "#7b4c46", "nose")
        if kind == "bison":
            box(p, [.57, .24, .38], [0, body_y + .26, -.19], accent, "hump")
        if kind == "hippo":
            box(p, [.44, .23, .26], [0, head_y - .03, -.73], accent, "muzzle")
        if kind in ["raptor", "dragon"]:
            for i in range(3):
                box(p, [.19 - i * .045, .16 - i * .03, .34], [0, body_y - i * .055, .57 + i * .27], accent, "tail")
            for i in range(6):
                box(p, [.07, .13, .07], [0, body_y + body_h / 2 + .06, -.28 + i * .16], accent, "spine")
        if kind == "dragon":
            for side in [-1, 1]:
                for i in range(3):
                    box(p, [.35, .045, .43 - i * .07], [side * (.36 + i * .27), body_y + .29, .025 + i * .08], accent, "wing", [0, 0, side * 12])
                box(p, [.07, .19, .07], [side * .14, head_y + .22, -.48], "#d7ccab", "horn")
    # The models stay in a readable game scale rather than real insect millimeters.
    for piece in p:
        piece["pos"] = [round(v * scale, 5) for v in piece["pos"]]
        piece["size"] = [round(v * scale, 5) for v in piece["size"]]
    return model(p, [0, .35 * scale, 0])


def device(kind, accent, payload=False):
    p = []
    body = "#303b46"
    if kind in ["gravity", "hypothetical", "singularity"]:
        for side in [-1, 1]:
            box(p, [.055, .29, .055], [side * .12, .16, 0], body)
            box(p, [.055, .055, .29], [0, .16, side * .12], body)
        box(p, [.29, .05, .29], [0, .025, 0], body)
        box(p, [.29, .05, .29], [0, .295, 0], body)
        box(p, [.13, .13, .13], [0, .16, 0], accent, "core", glow=1.3)
        if kind == "hypothetical":
            box(p, [.09, .09, .09], [0, .25, 0], "#f0ce64", "core", glow=1.0)
    else:
        height = .43 if kind in ["nuclear", "meteor"] else .24
        box(p, [.22, height, .22], [0, height / 2, 0], body)
        box(p, [.26, .055, .26], [0, height * .30, 0], accent)
        box(p, [.26, .055, .26], [0, height * .75, 0], accent)
        box(p, [.16, .055, .16], [0, height + .025, 0], "#8996a1", "cap")
        box(p, [.045, .10, .045], [.09, height + .05, 0], "#e7b758", "pin")
        for side in [-1, 1]:
            box(p, [.024, height * .45, .09], [side * .123, height * .52, 0], accent, "panel", glow=.2)
        if kind == "nuclear":
            for side in [-1, 1]:
                box(p, [.08, .12, .05], [side * .15, .08, 0], accent, "fin")
                box(p, [.05, .12, .08], [0, .08, side * .15], accent, "fin")
        if payload:
            for i in range(4):
                box(p, [.045, .045, .045], [(-.06 if i % 2 else .06), height + .08, -.04 + (i // 2) * .08], accent, "payload")
    return model(p, [0, .12, 0])


def weapon(kind, accent, launcher=False):
    p = []
    box(p, [.075, .14, .075], [0, -.05, .075], "#3a4047", "handle")
    box(p, [.09, .045, .07], [0, -.13, .075], accent, "pommel")
    if launcher:
        box(p, [.16, .16, .37], [0, .065, -.08], "#36434d", "body")
        for side in [-1, 1]:
            box(p, [.035, .13, .31], [side * .10, .065, -.10], accent, "panel")
        box(p, [.11, .11, .20], [0, .065, -.35], "#1c2730", "barrel")
        box(p, [.13, .13, .04], [0, .065, -.46], accent, "muzzle", glow=.3)
        box(p, [.04, .04, .10], [0, .17, -.09], accent, "sight")
    elif kind in ["gravity_hammer", "thunder_hammer", "frost_axe"]:
        box(p, [.055, .055, .55], [0, 0, -.20], "#5c5143", "handle")
        box(p, [.32 if kind != "frost_axe" else .22, .18, .15], [0, 0, -.49], "#66717a", "head")
        box(p, [.36, .07, .10], [0, 0, -.49], accent, "blade", glow=.6)
    else:
        box(p, [.19, .045, .065], [0, 0, -.025], "#6c7580", "guard")
        count = 7 if kind == "inferno_sword" else 5
        for i in range(count):
            box(p, [.07 - i * .006, .035, .065], [0, 0, -.09 - i * .06], "#d1d8d9", "blade")
            box(p, [.025, .042, .06], [.034 - i * .003, 0, -.09 - i * .06], accent, "blade", glow=1.1)
    m = model(p, [0, -.025, .06])
    m["joints"] = {"trigger": [0, 0, 0], "muzzle": [0, .065 if launcher else 0, -.30]}
    return m


def behavior(mode, radius=8, damage=50, **extra):
    return {"type": "anomaly", "mode": mode, "radius": radius, "damage": damage, **extra}


def main():
    defs = read("defs/things.json")
    words = read("lexicon/pt_br/things.json")
    balance = read("balance.json")
    macros = read("lexicon/pt_br/macros.json")
    actions = read("defs/actions.json")
    actions["anomaly"] = {"descends": True}
    entries = []

    def add(ident, name, names, category, visual, definition, stats, description, group, internal=False):
        defs[ident] = {"category": category, **definition}
        words[ident] = {"name": name, "words": list(dict.fromkeys([name, *names])), "forms": []}
        balance["things"][ident] = stats
        write(f"models/{ident}.json", visual)
        if not internal:
            entries.append({"id": ident, "name": name, "phrase": "quero " + name, "group": group, "effect": description, "pieces": len(visual["pieces"])})

    creatures = [
        ("duck", "pato", ["pata", "patos", "patinho", "patinhos"], "#d8d1ae", "#6b8465", .85),
        ("goose", "ganso", ["gansa", "gansos"], "#e0dac8", "#aeb5ae", 1.0),
        ("turkey", "peru", ["perus", "perua"], "#775341", "#a36e43", 1.05),
        ("pig", "porco", ["porca", "porcos", "porquinho", "porquinhos"], "#bd9189", "#946b64", .75),
        ("cow", "vaca", ["vacas", "vaquinha"], "#d4cfba", "#51463d", 1.15),
        ("sheep", "ovelha", ["ovelhas", "carneiro", "carneiros"], "#c1bda5", "#e0dbc4", .80),
        ("donkey", "burro", ["burros", "jumento", "jumentos"], "#96938a", "#555653", .95),
        ("camel", "camelo", ["camelos"], "#b69b6a", "#907149", 1.1),
        ("llama", "lhama", ["lhamas", "alpaca", "alpacas"], "#cfc2a4", "#89745e", .9),
        ("giraffe", "girafa", ["girafas"], "#c1a264", "#79563c", 1.1),
        ("zebra", "zebra", ["zebras"], "#d5d3c3", "#333a3c", 1.0),
        ("rhino", "rinoceronte", ["rinocerontes"], "#818b89", "#5f696b", 1.25),
        ("hippo", "hipopótamo", ["hipopótamos"], "#91858a", "#71656c", 1.25),
        ("bison", "bisão", ["bisões", "búfalo", "búfalos"], "#725441", "#4b3e35", 1.2),
        ("panda", "panda", ["pandas", "urso panda"], "#d5d1bd", "#343c40", .85),
        ("koala", "coala", ["coalas", "koala"], "#999f99", "#596267", .55),
        ("capybara", "capivara", ["capivaras"], "#9b8060", "#705d49", .8),
        ("otter", "lontra", ["lontras"], "#735a45", "#a19372", .58),
        ("raccoon", "guaxinim", ["guaxinins"], "#929389", "#424c50", .6),
        ("hedgehog", "ouriço", ["ouriços", "porco espinho"], "#aa9577", "#685849", .48),
        ("armadillo", "tatu", ["tatus"], "#a09277", "#6c7167", .56),
        ("cave_bat", "morcego", ["morcegos"], "#615950", "#383f47", 1.0),
        ("butterfly", "borboleta", ["borboletas"], "#383f47", "#cc9755", .65),
        ("beetle", "besouro", ["besouros", "escaravelho"], "#365f3e", "#243d30", 1),
        ("mantis", "louva a deus", ["louva-deus", "louva deuses"], "#749f48", "#476a35", 1),
        ("snail", "caracol", ["caracóis", "caramujo", "caramujos"], "#9c8055", "#5d503e", 1),
        ("octopus", "polvo", ["polvos"], "#a27483", "#705367", 1),
        ("raptor", "velociraptor", ["velociraptores", "raptor", "raptores"], "#879367", "#526047", .85),
        ("dragon", "dragão", ["dragões", "dragaozinho"], "#687d55", "#a27b4e", 1.35),
        ("slime", "slime", ["slimes", "geleca", "gelecas"], "#70a875", "#a3c087", 1),
    ]
    for ident, name, synonyms, color, accent, scale in creatures:
        if ident in defs and defs[ident].get("category") != "creature":
            raise ValueError("Creature id collides with existing object: " + ident)
        aerial = ident in ["cave_bat", "butterfly", "dragon"]
        definition = {"movement": "fly" if aerial else "chase_enemy", "impact": "stop", "voxel_motion": True}
        if aerial:
            definition["aerial"] = True
        if ident == "dragon":
            definition["behaviors"] = [{"when": {"type": "every", "s": 2.5}, "do": {"type": "shoot", "aim": "enemy", "arg": {"thing": "sphere", "movement": "straight", "mods": {"element": "fire", "scale": .45}}}}]
        stats = {"weight_kg": round(8 * scale * scale, 2), "cost": 12 if not aerial else 16, "hp": 40 * scale, "speed": 3.5 if not aerial else 6, "impact_damage": 4 * scale}
        if ident in ["beetle", "mantis", "snail", "butterfly"]:
            stats.update(cost=5.5, hp=18, speed=.7 if ident != "butterfly" else 3, impact_damage=2)
        if ident == "dragon":
            stats.update(cost=42, hp=120, speed=6, impact_damage=15)
        add(ident, name, synonyms, "creature", animal("bat" if ident == "cave_bat" else ident, color, accent, scale), definition, stats,
            "Criatura em blocos com movimento e animacao; cospe fogo." if ident == "dragon" else "Criatura em blocos com movimento e animacao.", "Animais")

    # Replace the previous rounded ant, without touching its vocabulary or economy.
    write("models/ant.json", insect("ant"))
    defs["ant"]["voxel_motion"] = True

    payloads = [("ant", "formigas", "#a96e43"), ("chicken", "galinhas", "#dfcc8f"), ("duck", "patos", "#76a07c"),
                ("bee", "abelhas", "#d9b957"), ("spider", "aranhas", "#8c6d9e"), ("crab", "caranguejos", "#be7756"),
                ("frog", "sapos", "#7ca06b"), ("rat", "ratos", "#9b9991"), ("pigeon", "pombos", "#98abb0"),
                ("raptor", "velociraptores", "#8b9c63"), ("slime", "slimes", "#8fb485"), ("beetle", "besouros", "#63895a")]
    for payload, plural, tint in payloads:
        count = 6 if payload != "raptor" else 3
        act = {"type": "burst_into", "arg": {"thing": payload, "mods": {"count": count}}}
        add(payload + "_grenade", "granada de " + plural, ["bomba de " + plural, "granada de " + words[payload]["name"]], "projectile",
            device("swarm", tint, True), {"movement": "ballistic", "impact": "stop", "behaviors": [{"when": {"type": "after", "s": 2.5}, "do": act}]},
            {"cost": 18 if payload != "raptor" else 32, "weight_kg": 1.0, "hp": 25, "speed": 12, "explosion_radius": 2.1, "explosion_damage": 8},
            f"Explode depois de arremessada e libera {count} {plural} vivos.", "Granadas de criaturas")

    bombs = [
        ("nuclear_bomb", "bomba nuclear", ["bomba atômica", "bomba atomica", "ogiva nuclear"], "nuclear", 14, 180, "#d9b95b", 75, "Explosao ampla com cratera e cogumelo de blocos."),
        ("neutron_bomb", "bomba de nêutrons", ["bomba de neutrons", "bomba de neutron", "bomba de nêutron"], "neutron", 12, 140, "#8cc8cf", 65, "Pulso contra combatentes e criaturas, sem escavar terreno."),
        ("gravity_bomb", "bomba de gravidade", ["bomba gravitacional", "granada de gravidade"], "gravity", 8, 45, "#a38bc9", 35, "Puxa inimigos por tres segundos e causa dano de compressao."),
        ("hypothetical_gravity_bomb", "bomba hipotética de gravidade", ["bomba hipotetica de gravidade", "bomba de antigravidade", "bomba antigravitacional"], "hypothetical", 9, 35, "#cebd69", 40, "Inverte a gravidade: levanta alvos e depois os repele."),
        ("singularity_bomb", "bomba de singularidade", ["granada de singularidade", "bomba buraco negro"], "singularity", 10, 85, "#8364aa", 55, "Campo de atracao mais forte por quatro segundos."),
        ("repulsion_bomb", "bomba de repulsão", ["bomba de repulsao", "granada de onda de choque"], "repulsion", 9, 25, "#a6c3cf", 25, "Onda de choque que lanca inimigos para fora."),
        ("frost_bomb", "bomba criogênica", ["bomba criogenica", "granada de gelo", "bomba congelante"], "frost", 7, 20, "#95bec9", 24, "Congela os alvos proximos e causa dano frio."),
        ("inferno_bomb", "bomba incendiária", ["bomba incendiaria", "granada infernal", "bomba de fogo"], "inferno", 6, 55, "#d4864d", 28, "Explode e aplica incendio na area."),
        ("storm_bomb", "bomba de tempestade", ["granada elétrica", "granada eletrica", "bomba de raios"], "storm", 8, 55, "#aaa4cf", 32, "Descargas em blocos atingem os inimigos na area."),
        ("emp_bomb", "bomba eletromagnética", ["bomba eletromagnetica", "granada emp", "bomba emp"], "emp", 7, 0, "#8fa8b8", 22, "Pulso que desacelera e desloca alvos, sem cratera."),
        ("meteor_bomb", "bomba de meteoros", ["granada de meteoros", "chuva de meteoros"], "meteor", 9, 0, "#b7845b", 45, "Invoca seis fragmentos explosivos que caem do alto."),
        ("cluster_bomb", "bomba de fragmentação", ["bomba de fragmentacao", "granada de fragmentação", "bomba cluster"], "cluster", 5, 0, "#8d9c72", 30, "Libera seis minibombas, com explosoes secundarias."),
    ]
    for ident, name, names, mode, radius, damage, tint, cost, description in bombs:
        add(ident, name, names, "projectile", device(mode, tint), {"movement": "ballistic", "impact": "stop", "behaviors": [{"when": {"type": "after", "s": 3.0}, "do": behavior(mode, radius, damage, color=tint)}]},
            {"cost": cost, "weight_kg": 3.0, "hp": 35, "speed": 12, "explosion_radius": radius, "explosion_damage": damage}, description, "Bombas especiais")

    for ident, name, tint in [("meteor_fragment", "fragmento de meteoro", "#c77a47"), ("cluster_fragment", "minibomba", "#8d9c72")]:
        add(ident, name, [], "projectile", device("fragment", tint), {"movement": "ballistic", "impact": "stop", "behaviors": [{"when": {"type": "on_hit"}, "do": {"type": "explode"}}] if ident == "meteor_fragment" else [{"when": {"type": "after", "s": 1.0}, "do": {"type": "explode"}}]},
            {"cost": 4, "weight_kg": .4, "hp": 10, "speed": 15, "lifetime": 8, "explosion_radius": 2.1, "explosion_damage": 30}, "Componente de bomba.", "Componentes", True)

    melee = [("rift_knife", "faca que corta o espaço", ["faca espacial", "faca dimensional", "faca do espaço"], "rift", "#ac85d2", 45),
             ("gravity_hammer", "martelo de gravidade", ["martelo gravitacional"], "repulsion", "#a38bc9", 28),
             ("thunder_hammer", "martelo do trovão", ["martelo de raios", "martelo do trovao"], "storm", "#aaa4cf", 28),
             ("frost_axe", "machado de gelo", ["machado congelante"], "frost", "#95bec9", 23),
             ("inferno_sword", "espada infernal", ["espada de fogo", "espada do inferno"], "inferno", "#d4864d", 25)]
    for ident, name, names, mode, tint, cost in melee:
        spec = behavior(mode, 4, 65 if mode == "rift" else 25, color=tint)
        if mode != "rift":
            spec["weapon_pulse"] = True
        add(ident, name, names, "weapon", weapon(ident, tint), {"melee": True, "behaviors": [{"when": {"type": "on_fire"}, "do": {"type": "strike"}}, {"when": {"type": "on_fire"}, "do": spec}]},
            {"cost": cost, "weight_kg": 2, "hp": 70, "fire_cooldown": 1.0, "impact_damage": 18},
            "Abre uma fenda de ate 22 metros que corta inimigos e blocos." if mode == "rift" else "Golpe corpo a corpo acompanhado de pulso elemental.", "Armas especiais")
        balance["weapons"][ident] = {"rear": {"fire_interval_s": 1.05, "magazine": 0, "automatic": False}, "front": {"power": 1.25, "knockback": 1.2}, "muzzle": {"barrels": 1, "arc_deg": 110, "style": "slash"}}
    for payload, name, tint in [("ant", "lança formigas", "#a96e43"), ("chicken", "lança galinhas", "#dfcc8f"), ("bee", "lança abelhas", "#d9b957")]:
        ident = payload + "_launcher"
        add(ident, name, [name.replace(" ", "-"), "arma de " + words[payload]["name"]], "weapon", weapon(ident, tint, True), {"projectile": payload, "behaviors": [{"when": {"type": "on_fire"}, "do": {"type": "shoot", "arg": {"thing": payload}}}]},
            {"cost": 27, "weight_kg": 3, "hp": 60, "fire_cooldown": .75}, "Dispara criaturas vivas; use um pente para recarregar.", "Armas especiais")
        balance["weapons"][ident] = {"rear": {"fire_interval_s": .8, "magazine": 8, "reload_s": 1.5, "automatic": False}, "front": {"power": 1, "recoil_deg": 2}, "muzzle": {"barrels": 1, "speed_mult": 1.0, "spread_deg": 2}}

    # These phrases now resolve to real objects rather than older shortcut substitutions.
    new_names = {s.casefold() for e in entries for s in words[e["id"]]["words"]}
    for key in list(macros):
        entry = macros[key]
        aliases = [key, *(entry.get("words", []) if isinstance(entry, dict) else [])]
        if any(alias.casefold() in new_names for alias in aliases):
            del macros[key]
    # Shortcuts remain compositional, and use the very same generic burst action.
    macros["granada zoologica"] = {"to": "granada de galinhas", "words": ["granada zoológica", "granada zoologica"]}
    write("defs/things.json", defs)
    write("defs/actions.json", actions)
    write("lexicon/pt_br/things.json", words)
    write("lexicon/pt_br/macros.json", macros)
    verbs = read("lexicon/pt_br/verbs.json")
    verbs["explode"]["words"] = list(dict.fromkeys([*verbs["explode"]["words"], "exploda", "detone", "estoure"]))
    verbs["burst_into"]["words"] = list(dict.fromkeys([*verbs["burst_into"]["words"], "exploda em", "estoure em"]))
    write("lexicon/pt_br/verbs.json", verbs)
    write("balance.json", balance)
    write("chaos_catalog.json", {"title": "Pacote Caos", "version": 1, "creations": entries})
    manifest = read("world_assets_manifest.json")
    added_ids = {e["id"] for e in entries} | {"ant", "meteor_fragment", "cluster_fragment"}
    manifest["assets"] = [a for a in manifest["assets"] if a["id"] not in added_ids]
    for ident in sorted(added_ids):
        m = read(f"models/{ident}.json")
        manifest["assets"].append({"id": ident, "group": defs[ident]["category"], "pieces": len(m["pieces"]), "reference": "Arte original em blocos do Pacote Caos."})
    manifest["new_definitions"] = len(manifest["assets"])
    write("world_assets_manifest.json", manifest)
    print(f"Generated {len(entries)} playable creations, 2 internal fragments and redesigned voxel ant.")


if __name__ == "__main__":
    main()
