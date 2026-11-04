"""Add missing transferable profiles and generic anatomy without resetting existing custom kits."""
from copy import deepcopy
from add_dinosaur_pack import read,write,box

def refresh():
    defs=read('defs/things.json');words=read('lexicon/pt_br/things.json');bal=read('balance.json');catalog=read('chaos_catalog.json')
    modifiers=read('defs/modifiers.json');mod_words=read('lexicon/pt_br/modifiers.json');display=read('lexicon/pt_br/display.json')
    count=0
    for donor,definition in list(defs.items()):
        if not isinstance(definition,dict) or definition.get('personal_power') or definition.get('coop_boss') or donor.startswith(('personal_','_')):continue
        creature=definition.get('category')=='creature'
        eligible=creature or definition.get('category')=='vehicle' or definition.get('kaiju') or definition.get('crossover')
        if not eligible or not words.get(donor,{}).get('words'):continue
        if definition.get('behaviors'):definition['fusion_behaviors']=True
        aliases=list(dict.fromkeys(words[donor]['words']+words[donor].get('forms',[])));name=words[donor].get('name',donor)
        if creature or definition.get('category')=='vehicle' or definition.get('crossover'):
            key='fusion_'+donor;modifiers[key]=dict(key=key,value=True)
            mod_words[key]=dict(words=list(dict.fromkeys(mod_words.get(key,{}).get('words',[])+[f'{prefix} {of} {alias}' for prefix in ['habilidade','habilidades','poder','poderes'] for of in ['do','de','da'] for alias in aliases])))
            display.setdefault('mods',{})[key]='poder de '+name
        ident='personal_'+donor
        if ident in words:
            words[ident]['words']=list(dict.fromkeys(words[ident].get('words',[])+[f'{p} {of} {a}' for p in ['poderes','poder','habilidades','habilidade','tecnicas','tecnica'] for of in ['de','do','da','dos','das'] for a in aliases]))
        if ident in defs and (definition.get('aerial') or definition.get('movement') in ['fly','flyover','follow_aim']):defs[ident]['personal_power']['flight']=True
        if ident in defs and not definition.get('kaiju') and not (definition.get('crossover') and definition['crossover'].get('kind') not in ['sans','sans_power']):continue
        profile=dict(donor=donor,universal=True)
        focus=dict(category='tool',movement='static',impact='stop',personal_power=profile)
        for field in ['jujutsu','pokemon','builder','ecology','crossover']:
            if definition.get(field):focus[field]=deepcopy(definition[field])
        if focus.get('pokemon'):focus['pokemon']['evolution']={}
        if definition.get('aerial') or definition.get('movement') in ['fly','flyover','follow_aim']:profile['flight']=True
        if definition.get('verity_companion'):profile['verity']=True
        if definition.get('kaiju'):
            config=deepcopy(definition['kaiju']);attack=config['attack'];config['range']=3.5 if attack=='smash' else min(100,config['range']);config['muzzles']=[[0,0,0]]
            if attack=='gravity':config['muzzles']=[[-.18,0,0],[0,0,0],[.18,0,0]]
            if attack!='smash':
                beam='personal_kaiju_'+attack+'_beam';source=deepcopy(defs['kaiju_'+attack+'_beam']);b=source['cursed_beam'];b.pop('source_muzzles',None);b.update(range=config['range'],width=.65,terrain_radius=.65,charge=.7,life=3.2,requires_equipped=True)
                defs[beam]=source;bal['things'][beam]=dict(cost=0,hp=1,weight_kg=.01,speed=0,lifetime=4)
                words[beam]=dict(name='Feixe pessoal '+attack,words=[],forms=[])
                write('models/'+beam+'.json',dict(anchor=[0,0,0],pieces=[dict(shape='box',size=[.08,.08,.12],pos=[0,0,0],color='#65bfff',tag='body')]))
                config['beam_id']=beam
            focus['kaiju']=config;profile['kaiju']=True
        elif definition.get('crossover'):
            kind=definition['crossover']['kind']
            modes=['bones','blue_bones','blaster','gravity'] if kind in ['sans','sans_power'] else ['slayer_shot','slayer_melee'] if kind=='slayer' else [kind]
            labels=dict(slayer_shot='Disparo',slayer_melee='Golpe da lâmina',rail='Tiro carregado',football='Chute',crucible='Corte da lâmina')
            profile['actions']=[dict(type='crossover',mode=mode,name=name+' · '+labels.get(mode,mode)) for mode in modes];profile['action_cooldown']=.25
        elif definition.get('behaviors'):
            profile['actions']=[deepcopy(row['do']) for row in definition['behaviors'] if row.get('do',{}).get('type') in ['shoot','drop','strike','spawn','summon','push','pull','freeze','ignite','heal']]
            for action in profile['actions']:action.pop('aim',None)
            profile['action_cooldown']=max([float(row.get('when',{}).get('s',2.5)) for row in definition['behaviors']]+[1.5])
        if not any(focus.get(k) for k in ['jujutsu','pokemon','builder','ecology','kaiju','crossover']) and not profile.get('actions'):profile['physical']=True
        defs[ident]=focus
        words[ident]=dict(name='Poderes de '+name,words=[f'{prefix} {of} {alias}' for prefix in ['poderes','poder','habilidades','habilidade','tecnicas','tecnica'] for of in ['de','do','da','dos','das'] for alias in aliases],forms=[])
        price=max(60,round(float(bal['things'].get(donor,{}).get('cost',60))*(.4 if definition.get('kaiju') else 1.35)))
        bal['things'][ident]=dict(cost=price,hp=100,weight_kg=1,speed=0,fire_cooldown=.25,impact_damage=0)
        pieces=[];box(pieces,[.25,.12,.36],[0,0,0],'#333b4c','body');box(pieces,[.15,.08,.2],[0,.07,-.1],'#70c7ef','body')
        write('models/'+ident+'.json',dict(anchor=[0,0,0],pieces=pieces))
        catalog['creations']=[row for row in catalog['creations'] if row['id']!=ident]
        catalog['creations'].append(dict(id=ident,name='Poderes de '+name,phrase='quero ter as habilidades de '+name,group='Poderes',effect='Clique usa; R troca. Poderes do doador adaptados ao jogador, com recarga e custo de criação.',pieces=len(pieces),base_cost=price));count+=1
    for part,title in [('legs','pernas'),('head','cabeça'),('body','corpo'),('arms','braços'),('wings','asas'),('tail','cauda')]:
        ident='player_anatomy_'+part
        defs[ident]=dict(category='wearable',movement='static',impact='stop',ability='anatomy_'+part,socket='anatomy_'+part,player_anatomy=part)
        words[ident]=dict(name='Enxerto de '+title,words=['enxerto anatomico de '+title],forms=[])
        bal['things'][ident]=dict(cost=25,hp=80,weight_kg=.5,speed=0,impact_damage=0)
        write('models/'+ident+'.json',dict(anchor=[0,0,0],pieces=[dict(shape='box',size=[.15,.15,.15],pos=[0,0,0],color='#aab3c8',tag='body')]))
    parts=read('defs/parts.json');pwords=read('lexicon/pt_br/parts.json')
    parts['animal_arms']=dict(section='arms',anatomy='arms');pwords['animal_arms']=dict(words=['braco','braço','braços','bracos'])
    display.setdefault('parts',{})['animal_arms']='braços'
    pwords['animal_legs']['words']=list(dict.fromkeys(pwords['animal_legs']['words']+['perna','pata','pe','pé']))
    pwords['animal_wings']['words']=list(dict.fromkeys(pwords['animal_wings']['words']+['asa']))
    write('defs/parts.json',parts);write('lexicon/pt_br/parts.json',pwords)
    for path,value in [('defs/things.json',defs),('lexicon/pt_br/things.json',words),('balance.json',bal),('chaos_catalog.json',catalog),('defs/modifiers.json',modifiers),('lexicon/pt_br/modifiers.json',mod_words),('lexicon/pt_br/display.json',display)]:write(path,value)
    print('Refreshed',count,'missing/kaiju power profiles; all creature fusion aliases and six anatomy slots')
if __name__=='__main__':refresh()
