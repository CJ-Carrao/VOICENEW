"""Finish fusion skills, creative tools, creature care and the cooperative challenge."""
from add_dinosaur_pack import read, write, box
from copy import deepcopy

def main():
    paths=['defs/things.json','lexicon/pt_br/things.json','balance.json','chaos_catalog.json','defs/commands.json','lexicon/pt_br/commands.json','defs/modifiers.json','lexicon/pt_br/modifiers.json','lexicon/pt_br/display.json']
    defs,words,bal,catalog,commands,phrases,mods,mwords,display=[read(p) for p in paths]
    defs['dragon']['fusion_behaviors']=True
    for donor,definition in list(defs.items()):
        if not isinstance(definition,dict) or definition.get('category')!='creature' or not (definition.get('pokemon') or definition.get('jujutsu') or definition.get('fusion_behaviors')) or not words.get(donor,{}).get('words'): continue
        key='fusion_'+donor
        mods[key]=dict(key=key,value=True)
        name=words[donor]['words'][0]
        mwords[key]=dict(words=[prefix+name for prefix in ['habilidade do ','habilidade de ','poder do ','poder de ','poderes do ']])
        display['mods'][key]='poder de '+words[donor]['name']
    entries=[('age_ray','Raio de envelhecimento',['raio de envelhecimento','arma que envelhece','raio que envelhece criaturas'],'age',95,5.0),('head_swap_ray','Raio de troca de cabeças',['raio de troca de cabecas','raio que troca cabecas','arma que troca cabecas'],'swap',145,12.0),('team_charm_grenade','Granada de inversão de equipe',['granada de inversao de equipe','granada que troca equipes','granada de confusao','granada que inverte equipes'],'charm',180,18.0)]
    for id,name,aliases,mode,cost,cooldown in entries:
        grenade=mode=='charm'
        defs[id]=dict(category='projectile' if grenade else 'weapon',impact='stop',movement='ballistic' if grenade else 'static',behaviors=[dict(when={'type':'after','s':2.0} if grenade else {'type':'on_fire'},do={'type':'creative','mode':mode})])
        words[id]=dict(name=name,words=aliases,forms=[])
        bal['things'][id]=dict(cost=cost,hp=45,weight_kg=1.4,lifetime=10 if grenade else 0,speed=15 if grenade else 0,fire_cooldown=cooldown)
        if not grenade: bal['weapons'][id]=dict(rear=dict(fire_interval_s=cooldown,magazine=0,automatic=False),front=dict(power=1.0,knockback=0.0),muzzle=dict(barrels=1,spread_deg=0.0))
        pieces=[]
        if grenade:
            box(pieces,[.32,.38,.32],[0,0,0],'#aa638e','body')
            box(pieces,[.20,.08,.20],[0,.22,0],'#d6ca8b','cap')
            for side in [-1,1]: box(pieces,[.035,.23,.34],[side*.17,0,0],'#ead2df','band')
        else:
            box(pieces,[.16,.20,.45],[0,0,0],'#746361' if mode=='age' else '#68587e','body')
            box(pieces,[.12,.22,.13],[0,-.16,.14],'#353641','grip')
            box(pieces,[.13,.13,.25],[0,0,-.32],'#aeb392' if mode=='age' else '#d8b4e5','barrel')
            for side in [-1,1]: box(pieces,[.035,.12,.30],[side*.10,.02,-.08],'#e5d8aa' if mode=='age' else '#afdbed','coil')
        write('models/'+id+'.json',dict(units='meters',anchor=[0,0,0],pieces=pieces,joints={'muzzle':[0,0,-.5],'trigger':[0,-.1,.1]}))
        effects={'age':'Envelhece uma criatura por 6 s: lentidão de 45%, sem perda de habilidades. Recarga 5 s, alcance 24 m, proteção contra renovação.','swap':'Troca a aparência das cabeças de duas criaturas inimigas na mira por 8 s, preservando vida, poderes e armas. Recarga 12 s.','charm':'Após 2 s, converte até 8 criaturas inimigas num raio de 5 m por 6 s. Equipe e dono originais retornam; captura encerra o efeito antes de transferir a posse.'}
        catalog['creations']=[r for r in catalog['creations'] if r['id']!=id]
        catalog['creations'].append(dict(id=id,name=name,phrase='quero '+aliases[0],group='Criatividade',effect=effects[mode],pieces=len(pieces),base_cost=cost))
    bal['status']['aged']=dict(duration_s=6.0,speed_mult=.55)
    bal['status']['age_immunity']=dict(duration_s=14.0,speed_mult=1.0)
    actions={'care':['cuidar da criatura','cuide da criatura','fazer carinho','carinho','alimentar criatura'],'status':['vinculo da criatura','como esta minha criatura','personalidade da criatura'],'pack':['proteja seus companheiros','proteja os companheiros']}
    for action,aliases in actions.items():
        commands['bond_'+action]=dict(bond=action)
        phrases['bond_'+action]=dict(words=aliases)
        display['commands']['bond_'+action]=aliases[0]
        for species,definition in list(defs.items()):
            if not isinstance(definition,dict) or definition.get('category')!='creature': continue
            key='bond_'+species+'_'+action
            commands[key]=dict(bond=action,species=species)
            verbs={'care':['carinho','cuidar','cuide'],'status':['vinculo','personalidade'],'pack':['proteja seus companheiros']}[action]
            phrases[key]=dict(words=[noun+' '+verb for noun in words.get(species,{}).get('words',[])[:2] for verb in verbs])
            if action=='care': phrases[key]['words'] += [prefix+noun for noun in words.get(species,{}).get('words',[])[:2] for prefix in ['cuidar do ','cuidar da ','fazer carinho no ','fazer carinho na ']]
    for action,aliases in {'invite':['desafio cooperativo','invocar chefe cooperativo','quero enfrentar o chefe'],'accept':['aceitar desafio','aceito desafio'],'cancel':['cancelar desafio'],'status':['status do desafio','progresso do chefe']}.items():
        key='coop_'+action
        commands[key]=dict(coop=action)
        phrases[key]=dict(words=aliases)
        display['commands'][key]=aliases[0]
    commands['fusion_info']=dict(fusion_info=True)
    phrases['fusion_info']=dict(words=['habilidades da fusao','poderes da fusao','quais poderes minha criatura tem'])
    display['commands']['fusion_info']='habilidades da fusão'
    defs['coop_chimera']=dict(category='creature',movement='fly',impact='stop',voxel_motion=True,aerial=True,coop_boss=True,jujutsu={'adaptation':True},ecology_tags=['dinosaur','boss'])
    words['coop_chimera']=dict(name='Quimera Adaptativa',words=[],forms=[])
    # Private species: the only public entry is the paid, consented encounter command.
    bal['things']['coop_chimera']=dict(cost=300,hp=600,speed=4.5,weight_kg=160,impact_damage=0)
    model=deepcopy(read('models/trex.json'))
    for side in [-1,1]:
        box(model['pieces'],[2.3,.16,1.1],[side*1.4,1.7,.25],'#8f596c','wing',[0,0,side*16])
        box(model['pieces'],[1.8,.10,.65],[side*2.1,1.9,.45],'#b38171','wing',[0,0,side*25])
        for i in range(3): box(model['pieces'],[.14,.40,.14],[side*(1.1+i*.6),1.8+i*.12,-.3],'#dfc69d','wing_spine')
    write('models/coop_chimera.json',model)
    for path,value in zip(paths,[defs,words,bal,catalog,commands,phrases,mods,mwords,display]): write(path,value)

if __name__=='__main__': main()
