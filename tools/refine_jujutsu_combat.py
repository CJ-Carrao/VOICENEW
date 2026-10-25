"""Separate contact attacks, travelling cuts and the fire arrow; retain existing aliases."""
from add_dinosaur_pack import read, write

def main():
    defs, words, mods, mwords, bal, catalog = [read(p) for p in ['defs/things.json','lexicon/pt_br/things.json','defs/modifiers.json','lexicon/pt_br/modifiers.json','balance.json','chaos_catalog.json']]
    defs['yuji_black_flash'].update(melee=True,strike_style='thrust')
    bal['things']['yuji_black_flash']['fire_cooldown']=.8
    for alias in ['raio negro','raio negro do yuji','soco do yuji']:
        if alias not in words['yuji_black_flash']['words']: words['yuji_black_flash']['words'].append(alias)
    # A gauntlet rather than a spell wand: the impact belongs to the fist.
    pieces=[dict(shape='box',size=[.26,.24,.28],pos=[0,0,-.04],color='#302732',tag='body'),dict(shape='box',size=[.19,.22,.16],pos=[0,-.16,.03],color='#4b3940',tag='grip')]
    for i in range(4): pieces.append(dict(shape='box',size=[.055,.08,.08],pos=[-.09+i*.06,.07,-.20],color='#9b3243',tag='knuckle'))
    write('models/yuji_black_flash.json',dict(anchor=[0,0,0],pieces=pieces))
    defs['sukuna_contact_cleave']=dict(category='tool',movement='static',impact='stop',melee=True,strike_style='thrust',jujutsu={'contact_cleave':True},behaviors=[{'when':{'type':'on_fire'},'do':{'type':'jujutsu'}}])
    aliases=['cleave','clivar','clivagem','corte de contato do sukuna','clivagem do sukuna']
    words['sukuna_contact_cleave']=dict(name='Cleave · corte de contato',words=aliases,forms=[])
    words['sukuna_cleave']['words']=[w for w in words['sukuna_cleave']['words'] if w not in aliases]
    words['sukuna_cleave']['name']='Dismantle · corte do Sukuna'
    mwords['jj_cleave']['words']=[w for w in mwords['jj_cleave']['words'] if not any(w.endswith(' '+a) for a in aliases)]
    mods['jj_contact_cleave']=dict(key='jj_contact_cleave',value=True)
    mwords['jj_contact_cleave']=dict(words=[p+a for a in aliases for p in ['com ','com o ','com a habilidade de ','com a habilidade do ','que usa ','que tem ']])
    bal['cost']['mods']['jj_contact_cleave']=105
    bal['things']['sukuna_contact_cleave']=dict(cost=105,hp=120,weight_kg=1,speed=0,impact_damage=0,fire_cooldown=.8)
    write('models/sukuna_contact_cleave.json',dict(anchor=[0,0,0],pieces=pieces))
    for ident,mode,title,speed,damage in [('sukuna_dismantle_wave','dismantle','Corte em movimento',36,32),('sukuna_fire_arrow','fuga','Flecha de fogo',25,65)]:
        defs[ident]=dict(category='projectile',movement='straight',impact='stop',cursed_projectile={'mode':mode})
        words[ident]=dict(name=title,words=[],forms=[])
        bal['things'][ident]=dict(cost=0,hp=1,weight_kg=0,speed=speed,impact_damage=0,lifetime=2.5 if mode=='fuga' else .7)
        if mode=='fuga':
            visual=[dict(shape='box',size=[.13,.13,1.5],pos=[0,0,0],color='#fff0a3',glow=2,tag='body'),dict(shape='box',size=[.55,.09,.55],pos=[0,0,-.75],rot=[0,45,0],color='#ff9b37',glow=2,tag='head')]
            for side in [-1,1]: visual.append(dict(shape='box',size=[.08,.3,.45],pos=[side*.15,0,.55],color='#ee5d2c',glow=1,tag='flame'))
        else:
            visual=[dict(shape='box',size=[2.5,.035,.06],pos=[0,0,0],rot=[0,0,32],color='#ecedf3',glow=.4,tag='body'),dict(shape='box',size=[1.8,.025,.05],pos=[0,-.15,.10],rot=[0,0,30],color='#8d96a5',tag='body')]
        write('models/'+ident+'.json',dict(anchor=[0,0,0],pieces=visual))
    updates={
        'yuji_black_flash':'Soco de contato: solte o clique na janela de precisão para um Black Flash. 18 de dano normal ou 45 preciso, raios pretos/vermelhos só no impacto; 0,8 s de recarga. Acerto preciso abre uma zona de 6 s.',
        'sukuna_cleave':'Dismantle: corte branco que viaja a 36 m/s, 32 de dano. Pode ser esquivado e é bloqueado pelo cenário; recarga de 1,2 s.',
        'sukuna_fuga':'Fuga: prepara por 0,45 s e lança uma flecha de fogo a 25 m/s. Explode e incendeia no impacto; recarga de 5 s.',
        'sukuna_world_cut':'Prepara o corte espacial por 0,55 s. Corta o cenário e atravessa o Infinito, com 100 de dano e 4,5 s de recarga.',
        'reversal_red':'Projétil de repulsão: uma única detonação forte ao tocar um alvo ou o cenário. Pode fundir com Azul antes do impacto.'
    }
    for row in catalog['creations']:
        if row['id'] in updates: row['effect']=updates[row['id']]
        if row['id']=='yuji_black_flash': row['pieces']=len(pieces)
    catalog['creations']=[r for r in catalog['creations'] if r['id']!='sukuna_contact_cleave']
    catalog['creations'].append(dict(id='sukuna_contact_cleave',name='Cleave · contato',phrase='quero cleave',group='Jujutsu',effect='Corte de contato em um alvo: ajusta o dano à resistência vital, limitado entre 32 e 70. Não atravessa Infinito. Recarga de 0,8 s.',pieces=len(pieces),base_cost=105))
    for p,v in zip(['defs/things.json','lexicon/pt_br/things.json','defs/modifiers.json','lexicon/pt_br/modifiers.json','balance.json','chaos_catalog.json'],[defs,words,mods,mwords,bal,catalog]): write(p,v)

if __name__=='__main__': main()
