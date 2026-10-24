"""Add original voxel dinosaurs to the existing anatomy, diet and power systems."""
import json
from pathlib import Path

DATA = Path(__file__).resolve().parent.parent / 'game/data'
def read(p): return json.loads((DATA / p).read_text(encoding='utf-8'))
def write(p, v): (DATA / p).write_text(json.dumps(v, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
def box(p, size, pos, color, tag, rot=None):
    piece = dict(shape='box', size=size, pos=pos, color=color, tag=tag)
    if rot: piece['rot'] = rot
    p.append(piece)

SPECS = [
    ('trex', 'tiranossauro rex', ['tiranossauro rex', 'tiranossauro', 't rex', 't-rex', 'trex', 'tiranossauros rex', 'tiranossauros', 'tyrannosaurus rex'], '#718052', 'biped', 130, 280, 3.2, 22),
    ('triceratops', 'tricerátops', ['triceratops', 'tricerátops', 'triceratope', 'triceratopes'], '#9e8862', 'horns', 100, 260, 2.4, 18),
    ('stegosaurus', 'estegossauro', ['estegossauro', 'estegossauros', 'stegosaurus'], '#6d8c72', 'plates', 95, 240, 1.8, 16),
    ('brachiosaurus', 'braquiossauro', ['braquiossauro', 'braquiossauros', 'brachiosaurus'], '#8c9272', 'longneck', 145, 340, 1.5, 18),
    ('spinosaurus', 'espinossauro', ['espinossauro', 'espinossauros', 'spinosaurus'], '#a17a66', 'sail', 135, 280, 2.7, 22),
    ('ankylosaurus', 'anquilossauro', ['anquilossauro', 'anquilossauros', 'ankylosaurus'], '#7e8270', 'armor', 115, 300, 1.7, 20),
    ('parasaurolophus', 'parassaurolofo', ['parassaurolofo', 'parassaurolofos', 'parasaurolophus', 'parassauro'], '#bd9660', 'crest', 80, 190, 3.0, 12),
    ('diplodocus', 'diplodoco', ['diplodoco', 'diplodocos', 'diplodocus'], '#7e9b92', 'longtail', 140, 320, 1.8, 17),
]

def visual(kind, color):
    p = []
    biped = kind in ['biped','sail','crest']
    long = kind in ['longneck','longtail']
    body_y = 1.25 if biped else .95
    box(p,[1.0, .85, 1.7],[0,body_y,0],color,'body')
    box(p,[.85,.40,1.35],[0,body_y-.4,-.04],'#c6b891','body')
    neck_y = 2.85 if long else 1.72 if biped else 1.20
    head_z = -1.45 if long else -1.12
    if long:
        box(p,[.44,1.7,.48],[0,1.95,-.73],color,'body')
        box(p,[.38,.8,.42],[0,2.95,-1.02],color,'body',[-22,0,0])
    else:
        box(p,[.6,.6,.65],[0,neck_y-.22,-.65],color,'body')
    head = [.65,.55,.85] if kind == 'biped' else [.43,.35,.6] if long else [.55,.42,.85]
    if kind == 'sail': head = [.4,.36,1.15]
    box(p,head,[0,neck_y,head_z],color,'head')
    box(p,[head[0]*.85,.14,head[2]*.9],[0,neck_y-head[1]*.45,head_z-.04],'#d6c8a4','mouth')
    for side in [-1,1]:
        box(p,[.055,.09,.10],[side*(head[0]/2+.012),neck_y+.08,head_z-.10],'#ebc45f','eye')
        box(p,[.025,.055,.04],[side*(head[0]/2+.04),neck_y+.08,head_z-.12],'#252b25','eye')
        for z in ([-.48,.55] if not biped else [.40]):
            box(p,[.34,.72,.40],[side*.43,.50,z],color,'leg')
            box(p,[.42,.22,.60],[side*.43,.11,z-.10],'#515951','foot')
        if biped:
            box(p,[.16,.35,.20],[side*.59,1.17,-.60],color,'body',[-25,0,side*-15])
        if kind in ['biped','sail']:
            for z in [-.24,0,.24]:
                box(p,[.07,.10,.06],[side*head[0]*.33,neck_y-.18,head_z+z],'#eee2bc','mouth')
    tail_steps = 6 if kind == 'longtail' else 4
    for i in range(tail_steps):
        box(p,[max(.13,.60-i*.085),max(.12,.45-i*.06),.64],[0,body_y-i*.07,.95+i*.45],color,'tail')
    if kind == 'horns':
        box(p,[1.05,.85,.18],[0,1.40,-.73],'#78634d','head',[-12,0,0])
        for side in [-1,1]:
            box(p,[.12,.12,.65],[side*.25,1.47,-1.55],'#e5dab7','horn',[-15,0,0])
        box(p,[.13,.24,.18],[0,1.4,-1.57],'#e5dab7','horn')
    if kind == 'plates':
        for i in range(6):
            box(p,[.16,.55+(.18 if i in [2,3] else 0),.32],[(-1 if i%2 else 1)*.16,1.62,-.6+i*.29],'#a9805a','body',[0,0,(-1 if i%2 else 1)*12])
        for side in [-1,1]: box(p,[.10,.11,.50],[side*.20,.76,2.35],'#d5cbae','tail',[0,side*30,0])
    if kind == 'sail':
        for i in range(7):
            box(p,[.12,.50+(.48 if i in [2,3,4] else .2),.25],[0,1.97,-.65+i*.25],'#775556','body')
    if kind == 'armor':
        for x in [-.4,0,.4]:
            for z in [-.6,0,.6]: box(p,[.30,.17,.35],[x,1.47,z],'#596558','body')
        box(p,[.70,.42,.58],[0,.74,2.45],'#6c7761','tail')
    if kind == 'crest':
        box(p,[.16,.24,.85],[0,2.02,-.75],'#8c593e','head',[-24,0,0])
    return dict(units='meters', anchor=[0,.45,0], pieces=p)

def main():
    defs, words, bal, catalog, mods, modwords, display = [read(p) for p in ['defs/things.json','lexicon/pt_br/things.json','balance.json','chaos_catalog.json','defs/modifiers.json','lexicon/pt_br/modifiers.json','lexicon/pt_br/display.json']]
    ids = {s[0] for s in SPECS}
    catalog['creations'] = [r for r in catalog['creations'] if r['id'] not in ids]
    for ident, name, aliases, color, kind, cost, hp, speed, damage in SPECS:
        model = visual(kind,color)
        write('models/'+ident+'.json',model)
        defs[ident] = dict(category='creature',movement='chase_enemy',impact='stop',voxel_motion=True,ecology_tags=['dinosaur',ident])
        words[ident] = dict(name=name,words=aliases,forms=[])
        bal['things'][ident] = dict(cost=cost,hp=hp,weight_kg=500 if kind not in ['longneck','longtail'] else 1200,speed=speed,impact_damage=damage)
        diet = 'species:'+ident
        key = 'diet_species_'+ident
        mods[key] = dict(key='diet',value=diet)
        modwords[key] = dict(words=[f'que {only}{verb} {alias}' for alias in aliases for only in ['','só ','apenas '] for verb in ['coma','come','ataque','ataca','cace','caça']])
        display['mods']['diet'][diet] = 'caça só '+name
        catalog['creations'].append(dict(id=ident,name=name,phrase='quero um '+name,group='Dinossauros',effect='Animal em blocos: aceita mistura de cabeça, corpo, patas e cauda, dietas, armas e técnicas.',pieces=len(model['pieces']),base_cost=cost))
    words['raptor']['words'] = list(dict.fromkeys(words['raptor']['words']+['velociraptor','velociraptors','velocirraptor','velocirraptores']))
    parts = read('lexicon/pt_br/parts.json')
    parts['blade']['words'] = list(dict.fromkeys(parts['blade']['words']+['cara','caras','rosto','rostos']))
    write('lexicon/pt_br/parts.json',parts)
    for p,v in [('defs/things.json',defs),('lexicon/pt_br/things.json',words),('balance.json',bal),('chaos_catalog.json',catalog),('defs/modifiers.json',mods),('lexicon/pt_br/modifiers.json',modwords),('lexicon/pt_br/display.json',display)]: write(p,v)

if __name__ == '__main__': main()
