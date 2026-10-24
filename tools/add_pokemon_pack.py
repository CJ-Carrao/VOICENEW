"""Four original voxel companions and localized, explicitly spoken move orders."""
from add_dinosaur_pack import box, read, write

SPECS = [
 ('pikachu','Pikachu',['pikachu','picachu','picaxu'],100,145,3.8,12,'electric',[
  ('thunderbolt','Choque do trovão',['choque do trovão','choque do trovao','choque de trovão','thunderbolt','thunder shock'],30,18,3.5,'electric'),
  ('quick_attack','Ataque rápido',['ataque rápido','ataque rapido','quick attack'],20,9,2.5,'quick')]),
 ('charmander','Charmander',['charmander','charmandar'],105,160,3.0,13,'fire',[
  ('ember','Brasa',['brasa','brasas','ember'],23,14,2.8,'fire'),
  ('flamethrower','Lança-chamas',['lança chamas','lanca chamas','lança-chamas','flamethrower'],40,17,5.5,'flame')]),
 ('squirtle','Squirtle',['squirtle','squitle','squirtou','esquirtle'],100,180,2.7,11,'water',[
  ('water_gun','Jato de água',['jato de água','jato de agua','revólver de água','revolver de agua','water gun'],26,17,3.2,'water'),
  ('bubble','Bolhas',['bolhas','bolha','bubble','ataque de bolhas'],20,13,2.8,'bubble')]),
 ('bulbasaur','Bulbasaur',['bulbasaur','bulbassauro','bulbassaur'],105,185,2.6,12,'grass',[
  ('vine_whip','Chicote de cipó',['chicote de cipó','chicote de cipo','chicote de vinha','vine whip'],28,11,3.3,'vine'),
  ('razor_leaf','Folha navalha',['folha navalha','folhas navalha','folha afiada','folhas afiadas','razor leaf'],32,17,4.2,'leaf')]),
]

def model(ident):
 p=[]
 def b(s,v,c,t='body',r=None): box(p,s,v,c,t,r)
 def eyes(y,z,x=.20):
  for side in [-1,1]:
   b([.12,.18,.065],[side*x,y,z],'#303130','eye')
   b([.04,.06,.025],[side*x-.02,y+.04,z-.04],'#faf1dc','eye')
 def feet(color,x=.24,z=.0):
  for side in [-1,1]:
   b([.23,.37,.27],[side*x,.26,z],color,'leg')
   b([.28,.16,.45],[side*x,.09,z-.10],color,'foot')
 if ident=='pikachu':
  b([.62,.72,.52],[0,.70,0],'#d8b83e'); b([.76,.58,.58],[0,1.28,-.12],'#e1c24e','head')
  feet('#d7b53c')
  for side in [-1,1]:
   b([.19,.65,.16],[side*.29,1.81,-.07],'#dcc04a','ear',[0,0,-side*18])
   b([.19,.20,.16],[side*.39,2.12,-.07],'#3c3931','ear',[0,0,-side*18])
   b([.19,.32,.20],[side*.40,.84,-.08],'#dcc04a','body',[0,0,side*22])
   b([.16,.13,.045],[side*.30,1.16,-.43],'#be5946','head')
  eyes(1.37,-.44)
  b([.10,.055,.04],[0,1.23,-.45],'#42372a','mouth')
  for y in [.65,.87]: b([.42,.09,.04],[0,y,.28],'#87613e')
  for s,v,r in [([.16,.35,.17],[.15,.49,.39],[0,0,-25]),([.39,.16,.18],[.31,.73,.45],[0,0,-28]),([.19,.47,.18],[.53,.96,.47],[0,0,-25]),([.46,.23,.18],[.57,1.22,.47],[0,0,-15])]: b(s,v,'#c9a73a','tail',r)
 elif ident=='charmander':
  b([.57,.70,.50],[0,.73,0],'#c88543'); b([.39,.52,.055],[0,.73,-.27],'#e3c58a')
  b([.63,.59,.57],[0,1.35,-.10],'#d3914c','head')
  b([.50,.20,.32],[0,1.16,-.39],'#d7a15c','snout'); eyes(1.43,-.40)
  feet('#c88543')
  for side in [-1,1]: b([.18,.41,.22],[side*.38,.89,-.04],'#ca8d4c','body',[0,0,side*20])
  for i in range(4): b([.30-i*.05,.23,.35],[0,.46+i*.06,.36+i*.22],'#bd7d3e','tail')
  b([.27,.43,.26],[0,.91,1.09],'#cc613b','tail')
  b([.16,.31,.17],[0,.96,1.09],'#edb54d','tail')
  b([.10,.19,.11],[0,1.17,1.09],'#e4ce75','tail')
 elif ident=='squirtle':
  b([.66,.70,.44],[0,.77,.07],'#8bb0b4')
  b([.69,.71,.23],[0,.78,.32],'#896849')
  b([.79,.64,.15],[0,.77,.46],'#b4a17c')
  b([.56,.56,.06],[0,.78,-.19],'#d7c294')
  for x in [-.21,.21]: b([.025,.49,.045],[x,.78,-.23],'#ac976e')
  for y in [.64,.85]: b([.48,.025,.045],[0,y,-.23],'#ac976e')
  b([.67,.56,.58],[0,1.39,-.09],'#8ebbc0','head'); eyes(1.46,-.40)
  b([.19,.05,.04],[0,1.19,-.40],'#617a78','mouth')
  feet('#8eb6b8')
  for side in [-1,1]: b([.23,.38,.25],[side*.45,.87,-.02],'#8eb6b8','body',[0,0,side*28])
  for s,v in [([.24,.20,.45],[0,.39,.64]),([.24,.40,.22],[0,.53,.87]),([.24,.18,.27],[0,.76,.77])]: b(s,v,'#8eb6b8','tail')
 else:
  b([.78,.53,1.0],[0,.53,.07],'#83a99a')
  b([.83,.55,.61],[0,.79,-.51],'#91b5a1','head'); eyes(.88,-.84,.26)
  b([.33,.06,.05],[0,.61,-.84],'#56796b','mouth')
  for side in [-1,1]:
   b([.19,.25,.20],[side*.28,1.13,-.47],'#85ab96','ear',[0,0,-side*12])
   for z in [-.32,.39]:
    b([.26,.34,.29],[side*.31,.24,z],'#81a796','leg')
    b([.29,.16,.36],[side*.31,.09,z-.035],'#8cb09b','foot')
   b([.13,.16,.035],[side*.26,.80,-.84],'#5d8170','head',[0,0,side*20])
   b([.035,.17,.24],[side*.41,.56,.20],'#5e826f')
  for s,y in [(.75,.92),(.64,1.17),(.37,1.41)]: b([s,.28,s],[0,y,.23],'#708b52')
  b([.11,.44,.09],[0,1.24,-.11],'#a2b374')
  for side in [-1,1]: b([.10,.42,.10],[side*.17,1.19,.26],'#536d41','body',[0,0,side*25])
 return dict(units='meters',anchor=[0,.45,0],pieces=p)

def main():
 paths=['defs/things.json','lexicon/pt_br/things.json','balance.json','chaos_catalog.json','defs/modifiers.json','lexicon/pt_br/modifiers.json','lexicon/pt_br/display.json','defs/commands.json','lexicon/pt_br/commands.json']
 defs,words,bal,catalog,mods,mwords,display,commands,cwords=[read(p) for p in paths]
 ids={r[0] for r in SPECS}; catalog['creations']=[r for r in catalog['creations'] if r['id'] not in ids]
 for ident,name,aliases,cost,hp,speed,damage,element,moves in SPECS:
  visual=model(ident); write('models/'+ident+'.json',visual)
  skills={key:dict(name=title,damage=dmg,range=reach,cooldown=cd,style=style,element=element if style!='quick' else 'normal') for key,title,_,dmg,reach,cd,style in moves}
  defs[ident]=dict(category='creature',movement='chase_enemy',impact='stop',voxel_motion=True,ecology_tags=['pokemon',ident],pokemon=dict(id=ident,element=element,moves=skills))
  words[ident]=dict(name=name,words=aliases,forms=[])
  bal['things'][ident]=dict(cost=cost,hp=hp,speed=speed,weight_kg=6 if ident=='pikachu' else 9,impact_damage=damage)
  for move,title,forms,*_ in moves:
   key='pokemon_'+ident+'_'+move
   commands[key]=dict(pokemon=ident,move=move)
   phrases=[]
   for alias in aliases:
    for form in forms:
     phrases += [f'{alias} {verb}{form}' for verb in ['', 'use ', 'use o ', 'use a ', 'usa ', 'solta ', 'ataque com ', 'usar ']]
     phrases.append(f'{form} {alias}')
   cwords[key]=dict(words=list(dict.fromkeys(phrases)))
  diet='species:'+ident
  mods['diet_species_'+ident]=dict(key='diet',value=diet)
  mwords['diet_species_'+ident]=dict(words=[f'que {o}{v} {a}' for a in aliases for o in ['','só ','apenas '] for v in ['coma','come','ataque','ataca','cace','caça']])
  display['mods']['diet'][diet]='caça só '+name
  mods['purge_species_'+ident]=dict(key='target_species',value=ident)
  mwords['purge_species_'+ident]=dict(words=[f'que {v} {q}{a}' for a in aliases for v in ['mate','mata','elimine','elimina','extermine','extermina'] for q in ['','todas as ','todos os ','todas ','todos ','todos os animais da espécie ']])
  display['mods']['target_species'][ident]='elimina todos: '+name
  catalog['creations'].append(dict(id=ident,name=name,phrase='quero um '+name,group='Pokémon',effect='Comandos: '+ '; '.join(name+', '+m[1].lower() for m in moves)+'. Aceita captura e misturas.',pieces=len(visual['pieces']),base_cost=cost))
 for path,value in zip(paths,[defs,words,bal,catalog,mods,mwords,display,commands,cwords]): write(path,value)
 print('Added four Pokemon, eight moves and spoken orders.')

if __name__=='__main__': main()
