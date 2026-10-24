"""Extend the existing companion pack with voxel evolutions and spoken commands."""
from copy import deepcopy
from add_pokemon_pack import SPECS, model
from add_dinosaur_pack import read, write, box

FORMS = [
    ('raichu', 'Raichu', 'pikachu', 1.15, 230, 4.2, 18, 270),
    ('charmeleon', 'Charmeleon', 'charmander', 1.14, 230, 3.4, 18, 280),
    ('charizard', 'Charizard', 'charmander', 1.55, 340, 4.4, 25, 480),
    ('wartortle', 'Wartortle', 'squirtle', 1.16, 255, 3.0, 16, 280),
    ('blastoise', 'Blastoise', 'squirtle', 1.55, 370, 2.7, 24, 480),
    ('ivysaur', 'Ivysaur', 'bulbasaur', 1.17, 260, 2.9, 18, 285),
    ('venusaur', 'Venusaur', 'bulbasaur', 1.60, 380, 2.5, 25, 485),
]
NEXT = {'pikachu': 'raichu', 'charmander': 'charmeleon', 'charmeleon': 'charizard',
        'squirtle': 'wartortle', 'wartortle': 'blastoise', 'bulbasaur': 'ivysaur', 'ivysaur': 'venusaur'}


def visual(ident, base, scale):
    data = model(base)
    pieces = data['pieces']
    def b(size, at, color, tag='body', rot=None): box(pieces, size, at, color, tag, rot)
    if ident == 'raichu':
        for p in pieces:
            if p['color'] in ['#d8b83e', '#e1c24e', '#d7b53c', '#dcc04a']: p['color'] = '#c98b43'
        pieces[:] = [p for p in pieces if p['tag'] != 'tail']
        b([.40, .48, .055], [0, .73, -.29], '#e6c994')
        for side in [-1, 1]:
            b([.36, .12, .17], [side*.52, 1.87, -.07], '#79533a', 'ear', [0, 0, side*25])
        for i in range(5): b([.08, .08, .27], [.08+i*.13, .42+i*.07, .37+i*.18], '#68503c', 'tail', [0, -25, 0])
        b([.44, .27, .10], [.77, .89, 1.19], '#d4b64e', 'tail', [0, 0, -25])
    elif ident in ['charmeleon', 'charizard']:
        for p in pieces:
            if p['color'] in ['#c88543', '#d3914c', '#ca8d4c', '#bd7d3e']: p['color'] = '#b56249' if ident == 'charmeleon' else '#c18b4c'
        for side in ([-1, 1] if ident == 'charizard' else [0]):
            b([.14, .40, .17], [side*.22, 1.75, .02], '#cfa876', 'head', [-25, 0, -side*15])
        if ident == 'charizard':
            for side in [-1, 1]:
                b([.87, .10, .72], [side*.69, 1.18, .18], '#547f7d', 'wing', [0, 0, -side*16])
                b([.64, .10, .49], [side*1.20, 1.36, .24], '#547f7d', 'wing', [0, 0, -side*28])
                b([1.31, .09, .11], [side*.88, 1.37, -.12], '#ba854a', 'wing', [0, 0, -side*20])
                b([.13, .12, .16], [side*1.49, 1.60, -.13], '#e2d7b9', 'wing')
    elif ident == 'wartortle':
        pieces[:] = [p for p in pieces if p['tag'] != 'tail']
        for side in [-1, 1]:
            b([.25, .52, .13], [side*.40, 1.65, .01], '#b4cacc', 'ear', [0, 0, -side*28])
        for size, at in [([.30, .26, .48], [0, .40, .65]), ([.42, .47, .29], [0, .63, .88]), ([.49, .21, .28], [0, .93, .80])]: b(size, at, '#c4d5cc', 'tail')
    elif ident == 'blastoise':
        for side in [-1, 1]:
            b([.31, .30, .97], [side*.40, 1.22, .12], '#858e8c', 'body', [-16, 0, 0])
            b([.23, .21, .06], [side*.40, 1.35, -.35], '#333b3c', 'body')
            b([.32, .25, .15], [side*.40, 1.34, -.30], '#aab0a8', 'body')
            b([.18, .12, .025], [side*.40, 1.35, -.39], '#303637', 'body')
    elif ident in ['ivysaur', 'venusaur']:
        # Keep the quadruped body; replace the starter's bulb with a bud or flowering canopy.
        pieces[:] = [p for p in pieces if not (p['tag'] == 'body' and p['pos'][1] > .88 and p['pos'][2] > -.2)]
        for i in range(4):
            b([.74, .10, .30], [(-1 if i%2 else 1)*.32, 1.03, .21+(-.26 if i<2 else .26)], '#587a4d', 'body', [0, i*45, 0])
        if ident == 'ivysaur':
            b([.49, .48, .47], [0, 1.31, .21], '#bc777e')
            b([.31, .20, .31], [0, 1.63, .21], '#cf8f91')
        else:
            b([.24, .82, .25], [0, 1.40, .21], '#886e45')
            for i in range(4):
                b([.98, .15, .39], [0, 1.84, .21], '#c17e86', 'body', [0, i*45, 0])
            b([.34, .24, .34], [0, 2.02, .21], '#d8bf72')
    for p in pieces:
        p['size'] = [round(v*scale, 4) for v in p['size']]
        p['pos'] = [round(v*scale, 4) for v in p['pos']]
    data['anchor'] = [0, round(.45*scale, 4), 0]
    return data


def main():
    paths = ['defs/things.json', 'lexicon/pt_br/things.json', 'balance.json', 'chaos_catalog.json',
             'defs/commands.json', 'lexicon/pt_br/commands.json']
    defs, words, bal, catalog, commands, cwords = [read(p) for p in paths]
    for ident, name, base, scale, hp, speed, damage, cost in FORMS:
        d = deepcopy(defs[base]); d['pokemon']['id'] = ident
        if ident == 'charizard': d.update(movement='fly', aerial=True)
        for skill in d['pokemon']['moves'].values(): skill['damage'] = round(skill['damage']*(1.55 if ident in ['charizard', 'blastoise', 'venusaur'] else 1.25))
        d['ecology_tags'] = ['pokemon', ident]
        defs[ident] = d
        words[ident] = dict(name=name, words=[ident], forms=[])
        bal['things'][ident] = dict(cost=cost, hp=hp, speed=speed, weight_kg=bal['things'][base]['weight_kg']*scale**3, impact_damage=damage)
        v = visual(ident, base, scale); write('models/'+ident+'.json', v)
        catalog['creations'] = [r for r in catalog['creations'] if r['id'] != ident]
        catalog['creations'].append(dict(id=ident, name=name, phrase='quero um '+name, group='Pokémon', effect='Forma evoluída. Aceita ordens, captura e misturas.', pieces=len(v['pieces']), base_cost=cost))
        # Evolved forms keep their family's move vocabulary, using their own name.
        base_aliases = words[base]['words']
        for key in list(commands):
            if not isinstance(commands[key], dict) or commands[key].get('pokemon') != base or 'move' not in commands[key]: continue
            new_key = key.replace('pokemon_'+base+'_', 'pokemon_'+ident+'_')
            commands[new_key] = dict(pokemon=ident, move=commands[key]['move'])
            phrases = []
            for phrase in cwords[key]['words']:
                for alias in sorted(base_aliases, key=len, reverse=True):
                    if alias in phrase:
                        phrases.append(phrase.replace(alias, ident)); break
            cwords[new_key] = dict(words=list(dict.fromkeys(phrases)))
    all_ids = [s[0] for s in SPECS] + [f[0] for f in FORMS]
    for ident in all_ids:
        next_id = NEXT.get(ident, '')
        defs[ident]['pokemon']['evolution'] = dict(next=next_id, xp=90 if ident in ['charmeleon','wartortle','ivysaur'] else 40, cost=140 if ident in ['charmeleon','wartortle','ivysaur'] else 75)
        for action in ['evolve', 'progress']:
            key = 'pokemon_'+ident+'_'+action
            commands[key] = dict(pokemon=ident, pokemon_action=action)
            phrases = []
            for alias in words[ident]['words']:
                phrases += ([f'{alias} evolua', f'{alias} evoluir', f'evolua o {alias}', f'evoluir {alias}', f'{alias} pode evoluir'] if action == 'evolve' else [f'{alias} experiência', f'{alias} experiencia', f'{alias} progresso', f'{alias} nível', f'{alias} nivel'])
            cwords[key] = dict(words=phrases)
    for path, value in zip(paths, [defs, words, bal, catalog, commands, cwords]): write(path, value)
    print('Seven evolution forms, evolution requirements and spoken commands added.')


if __name__ == '__main__': main()
