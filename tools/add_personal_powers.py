"""Create equipment profiles from supported ability-bearing definitions, without changing donors."""
from copy import deepcopy
from add_dinosaur_pack import read,write,box

def main():
    defs=read('defs/things.json');words=read('lexicon/pt_br/things.json');bal=read('balance.json');catalog=read('chaos_catalog.json')
    ids=[]
    for donor, definition in list(defs.items()):
        if not isinstance(definition,dict) or definition.get('personal_power') or definition.get('coop_boss'):continue
        creature=definition.get('category')=='creature'
        transferable=any(definition.get(k) for k in ['jujutsu','spatial_orb','cursed_beam','cursed_projectile'])
        if not transferable and not (creature and any(definition.get(k) for k in ['pokemon','behaviors','builder','ecology','verity_companion','aerial'])):continue
        profile=dict(donor=donor)
        focus=dict(category='tool',movement='static',impact='stop',personal_power=profile)
        for field in ['jujutsu','pokemon','builder','ecology']:
            if definition.get(field):focus[field]=deepcopy(definition[field])
        if 'pokemon' in focus:focus['pokemon']['evolution']={}
        if definition.get('aerial'):profile['flight']=True
        if definition.get('verity_companion'):profile['verity']=True
        if creature and definition.get('behaviors'):
            profile['actions']=[deepcopy(b['do']) for b in definition['behaviors'] if b.get('do',{}).get('type') in ['shoot','drop','strike','spawn','summon','push','pull','freeze','ignite','heal']]
            for action in profile['actions']:action.pop('aim',None)
            profile['action_cooldown']=max([float(b.get('when',{}).get('s',2.0)) for b in definition['behaviors']]+[1.5])
        if any(definition.get(k) for k in ['spatial_orb','cursed_beam','cursed_projectile']):profile['projectile']=donor
        ident='personal_'+donor;ids.append(ident);defs[ident]=focus
        name=words.get(donor,{}).get('name',donor)
        aliases=words.get(donor,{}).get('words',[donor])
        words[ident]=dict(name='Poderes de '+name,words=[f'{p} {of} {a}' for p in ['poderes','poder','habilidades','habilidade','tecnicas','tecnica'] for of in ['de','do','da','dos','das'] for a in aliases],forms=[])
        price=max(60,round(float(bal['things'].get(donor,{}).get('cost',60))*1.35))
        bal['things'][ident]=dict(cost=price,hp=100,weight_kg=1,speed=0,fire_cooldown=.25,impact_damage=0)
        pieces=[]
        color='#ffd65f' if 'pokemon' in focus else '#a8c9fa' if 'jujutsu' in focus else '#c7a4dc'
        box(pieces,[.25,.12,.36],[0,0,0],'#333b4c','body')
        for x in [-.09,0,.09]:box(pieces,[.07,.09,.19],[x,.015,-.20],color,'body')
        box(pieces,[.15,.045,.17],[0,.085,0],color,'body')
        write('models/'+ident+'.json',dict(units='meters',anchor=[0,0,0],pieces=pieces))
        catalog['creations']=[r for r in catalog['creations'] if r['id']!=ident]
        catalog['creations'].append(dict(id=ident,name='Poderes de '+name,phrase='quero ter os poderes de '+name,group='Poderes',effect='Equipe para usar as habilidades. Clique usa; R troca o golpe. Passivas somente no item selecionado.',pieces=len(pieces),base_cost=price))
    for p,v in [('defs/things.json',defs),('lexicon/pt_br/things.json',words),('balance.json',bal),('chaos_catalog.json',catalog)]:write(p,v)
    print('Generated',len(ids),'personal power profiles')
    from adapt_all_creations import refresh
    refresh()
if __name__=='__main__':main()
