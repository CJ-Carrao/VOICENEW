"""Voxel emitters and composable Sendai-inspired beam techniques."""
from add_spatial_pack import read, write

def main():
    defs, words, mods, mwords, bal, catalog = [read(p) for p in ['defs/things.json', 'lexicon/pt_br/things.json', 'defs/modifiers.json', 'lexicon/pt_br/modifiers.json', 'balance.json', 'chaos_catalog.json']]
    for mode, title, cost, color, output, aliases in [
        ('ryu', 'Raio do Ryu', 220, '#7a9bff', 1.1, ['raio do ryu','raio de ryu','granite blast','rajada de granito','disparo do ryu','raio do riu']),
        ('yuta', 'Raio do Yuta', 200, '#f18dcb', 1.0, ['raio do yuta','raio de yuta','raio da rika','feixe do yuta','raio de amor','pure love beam','raio do iuta']),
    ]:
        key = mode + '_beam'
        ident = key + '_technique'
        defs[ident] = dict(category='tool', movement='static', impact='stop', jujutsu={key:True}, behaviors=[{'when':{'type':'on_fire'},'do':{'type':'jujutsu'}}])
        words[ident] = dict(name=title, words=aliases, forms=[])
        bal['things'][ident] = dict(cost=cost, hp=120, weight_kg=1, speed=0, impact_damage=0, fire_cooldown=.8)
        mod = 'jj_' + key
        mods[mod] = dict(key=mod, value=True)
        mwords[mod] = dict(words=[prefix + alias for alias in aliases for prefix in ['com ', 'com o ', 'com a habilidade do ', 'com a habilidade de ', 'que usa ', 'que tem ']])
        bal['cost']['mods'][mod] = cost
        pieces = [dict(shape='box',size=[.16,.32,.12],pos=[0,0,0],color=color,tag='core'),dict(shape='box',size=[.08,.25,.08],pos=[0,-.28,0],color='#454653',tag='grip')]
        for side in [-1,1]:
            pieces.append(dict(shape='box',size=[.09,.16,.14],pos=[side*.18,.04,0],color=color,tag='rune'))
            pieces.append(dict(shape='box',size=[.12,.06,.13],pos=[side*.1,.22,0],color='#fff6ec',tag='rune'))
        write('models/'+ident+'.json',dict(units='meters',anchor=[0,0,0],pieces=pieces))
        stream = key + '_stream'
        words[stream] = dict(name='Feixe ativo · '+title,words=[],forms=[])
        defs[stream] = dict(category='projectile',movement='static',impact='stop',cursed_beam=dict(mode=mode,color=color,output=output,damage=10*output,range=42,life=3.5,charge=.4))
        bal['things'][stream] = dict(cost=0,hp=1,speed=0,weight_kg=0,impact_damage=0,lifetime=6)
        write('models/'+stream+'.json',dict(anchor=[0,0,0],pieces=[dict(shape='box',size=[.05,.05,.05],pos=[0,0,0],color=color,tag='core')]))
        catalog['creations'] = [v for v in catalog['creations'] if v['id'] != ident]
        catalog['creations'].append(dict(id=ident,name=title,phrase='quero '+title.lower(),group='Jujutsu',effect='Feixe carregado de 42 m; clique para disparar. Feixes adversários de frente disputam força por 1,2 s. Recarga de 7 s. Aceita composição com criaturas.',pieces=len(pieces),base_cost=cost))
    for path, value in zip(['defs/things.json','lexicon/pt_br/things.json','defs/modifiers.json','lexicon/pt_br/modifiers.json','balance.json','chaos_catalog.json'],[defs,words,mods,mwords,bal,catalog]): write(path,value)

if __name__ == '__main__': main()
