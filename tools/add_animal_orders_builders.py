"""Animal voice orders, voxel beavers and bounded builder products."""
from add_dinosaur_pack import read, write, box

ORDERS = {
 'follow': ['me siga', 'siga me', 'siga o jogador', 'venha comigo'],
 'stay': ['fique aqui', 'fica aqui', 'pare aqui'],
 'guard': ['proteja minha casa', 'proteja a casa', 'defenda minha casa'],
 'attack': ['ataque aquele jogador', 'ataque o jogador', 'ataque aquele inimigo'],
 'evade': ['fuja das bombas', 'foge das bombas', 'evite as bombas'],
 'retaliate': ['ataque só quem me atacar', 'ataque so quem me atacar', 'ataque apenas quem me atacar'],
 'free': ['volte ao normal', 'aja normalmente', 'cancele a ordem'],
 'build': ['construa aqui', 'comece a construir', 'trabalhe aqui'],
 'aggressive': ['seja agressivo', 'seja agressiva', 'ataque tudo na sua frente', 'fique agressivo'],
}

def model_beaver():
 p=[]
 def b(s,v,c,t='body',r=None): box(p,s,v,c,t,r)
 b([.65,.56,1.0],[0,.52,.05],'#8e7154')
 b([.58,.48,.51],[0,.70,-.58],'#987b5b','head')
 b([.43,.22,.23],[0,.56,-.87],'#ac9473','snout')
 for side in [-1,1]:
  b([.14,.18,.12],[side*.24,.98,-.50],'#7c624b','ear')
  b([.08,.10,.04],[side*.20,.76,-.85],'#282b29','eye')
  b([.10,.18,.05],[side*.065,.40,-1.0],'#d3c6a1','mouth')
  for z in [-.27,.40]:
   b([.19,.30,.23],[side*.28,.23,z],'#806246','leg')
   b([.24,.10,.33],[side*.30,.06,z-.05],'#55483b','foot')
 b([.16,.10,.08],[0,.62,-1.0],'#36342e','mouth')
 b([.48,.10,.90],[0,.14,.94],'#665644','tail')
 for z in [.65,.85,1.05,1.25]: b([.43,.018,.025],[0,.20,z],'#807057','tail')
 return dict(units='meters',anchor=[0,.35,0],pieces=p)

def main():
 paths=['defs/things.json','lexicon/pt_br/things.json','balance.json','chaos_catalog.json','defs/commands.json','lexicon/pt_br/commands.json']
 defs,words,bal,catalog,commands,cwords=[read(p) for p in paths]
 defs['beaver']=dict(category='creature',movement='chase_enemy',impact='stop',voxel_motion=True,ecology_tags=['mammal','beaver'],builder='dam')
 defs['ant']['builder']='tunnel'; defs['spider']['builder']='web'
 words['beaver']=dict(name='castor',words=['castor','castores','beaver'],forms=[])
 bal['things']['beaver']=dict(cost=28,hp=100,speed=2.3,weight_kg=18,impact_damage=9)
 v=model_beaver(); write('models/beaver.json',v)
 catalog['creations']=[r for r in catalog['creations'] if r['id']!='beaver']
 catalog['creations'].append(dict(id='beaver',name='Castor',phrase='quero um castor',group='Animais',effect='Diga: castor, construa uma barragem. Aceita ordens, captura e misturas.',pieces=len(v['pieces']),base_cost=28))
 for ident,title,cost,hp in [('beaver_dam','barragem de castor',32,220),('spider_web','teia de aranha',16,40)]:
  defs[ident]=dict(category='structure',movement='static',impact='stop',builder_product='dam' if ident=='beaver_dam' else 'web')
  words[ident]=dict(name=title,words=[title],forms=[])
  bal['things'][ident]=dict(cost=cost,hp=hp,speed=0,weight_kg=45 if ident=='beaver_dam' else 1,impact_damage=0)
  p=[]
  if ident=='beaver_dam':
   for level in range(5):
    box(p,[3.0,.22,.32],[0,.14+level*.24,0],'#8c7657','body')
   for side in [-1,1]:
    box(p,[.20,1.5,.20],[side*1.10,.72,.04],'#63513e','body')
  else:
   for i in range(7):
    box(p,[2.2,.035,.035],[0,.16+i*.17,0],'#c7c8b5','body')
    box(p,[.035,1.22,.035],[-1.02+i*.34,.70,0],'#bfc3b1','body')
   box(p,[.035,1.68,.035],[0,.70,0],'#d3d4bd','body',[0,0,56])
   box(p,[.035,1.68,.035],[0,.70,0],'#d3d4bd','body',[0,0,-56])
  write('models/'+ident+'.json',dict(units='meters',anchor=[0,0,0],pieces=p))
 for action,phrases in ORDERS.items():
  key='animal_order_'+action
  commands[key]=dict(animal_order=action,species='')
  cwords[key]=dict(words=phrases)
 for ident,d in defs.items():
  if not isinstance(d,dict) or d.get('category')!='creature' or ident not in words: continue
  aliases=words[ident]['words']
  for action,phrases in ORDERS.items():
   key='animal_order_'+ident+'_'+action
   commands[key]=dict(animal_order=action,species=ident)
   forms=[alias+' '+phrase for alias in aliases for phrase in phrases]
   if action=='build':
    extra={'ant':['cave um túnel','cave um tunel','escave um túnel','escave um tunel'], 'beaver':['construa uma barragem','faça uma barragem','faca uma barragem'], 'spider':['faça uma teia','faca uma teia','construa uma teia']}.get(ident,[])
    forms += [a+' '+p for a in aliases for p in extra]
   cwords[key]=dict(words=list(dict.fromkeys(forms)))
 bal['animal_orders']=dict(range_m=60,tick_s=.2,guard_radius_m=10,retaliation_s=10)
 bal['creature_builders']=dict(dam_seconds=4,web_seconds=2.5,work_tick_s=.25,dig_cell_cost=.3,dig_cells_per_job=96,dig_team_cell_cap=512,cooldown_s=8)
 bal['status']['webbed']=dict(duration_s=1.2,speed_mult=.35,element='')
 for path,value in zip(paths,[defs,words,bal,catalog,commands,cwords]): write(path,value)
 mods=read('defs/modifiers.json'); mwords=read('lexicon/pt_br/modifiers.json'); display=read('lexicon/pt_br/display.json')
 mods['aggressive']=dict(key='aggressive',value=True)
 mwords['aggressive']=dict(words=['agressivo','agressiva','agressivos','agressivas','que ataca tudo na sua frente','que ataque tudo na sua frente'])
 display['mods']['aggressive']='agressivo'
 write('defs/modifiers.json',mods); write('lexicon/pt_br/modifiers.json',mwords); write('lexicon/pt_br/display.json',display)
 print('Animal orders, beavers, dams, webs and builder balance added.')

if __name__=='__main__': main()
