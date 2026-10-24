"""Original box models based on researched brainrot silhouettes; no imported assets."""
import math
from add_dinosaur_pack import read, write, box

SPECS = [
 ('tung_sahur', 'Tung Tung Tung Sahur', ['tung tung tung sahur','tung tung sahur','tung sahur'], 85, 180, 2.6, 20),
 ('tralalero', 'Tralalero Tralala', ['tralalero tralala','tralalelo tralala','tralalero','tralalelo'], 95, 170, 3.7, 17),
 ('saturnita', 'La Vaca Saturno Saturnita', ['la vaca saturno saturnita','vaca saturno saturnita','vaca saturni sa tinita','vaca saturnita','vaca saturno'], 130, 260, 1.8, 22),
 ('bombardiro', 'Bombardiro Crocodilo', ['bombardiro crocodilo','bombardino crocodilo','bombardiro crocodillo','bombardino crocodillo'], 175, 190, 4.2, 12),
 ('udin', 'Udin Din Din Dun', ['udin din din dun','u din din din dun','u din din din din dun ma din din din dun','udindindum','udindindun','udin'], 100, 230, 2.6, 24),
 ('cappuccino_assassino', 'Cappuccino Assassino', ['cappuccino assassino','capuchino assassino','capuccino assassino','cappucino assassino'], 110, 140, 4.0, 26),
 ('ballerina_cappuccina', 'Ballerina Cappuccina', ['ballerina cappuccina','balerina capuchinha','bailarina capuchina','bailarina cappuccina','balerina capuccina','bailarina capuccino'], 70, 130, 3.5, 12),
 ('patapim', 'Brr Brr Patapim', ['brr brr patapim','brr brrr patapim','brr patapim','patapim'], 105, 240, 2.1, 20),
 ('lirili', 'Lirilì Larilà', ['lirilì larilà','lirili larila','lirili'], 115, 250, 2.0, 21),
 ('chimpanzini', 'Chimpanzini Bananini', ['chimpanzini bananini','chimpanzini banana','chimpanzini'], 75, 150, 3.3, 15),
]

def model(ident):
 p=[]
 def b(s,v,c,t='body',r=None): box(p,s,v,c,t,r)
 def eyes(y,z,x=.19):
  for side in [-1,1]:
   b([.16,.19,.08],[side*x,y,z],'#f3ead4','eye')
   b([.065,.10,.035],[side*x,y,z-.055],'#262524','eye')
 def legs(color,shoes='#654537',y=.46,x=.28):
  for side in [-1,1]:
   b([.22,y*1.65,.24],[side*x,y,.0],color,'leg')
   b([.32,.18,.48],[side*x,.10,-.12],shoes,'foot')
 def arms(color,y=1.15,x=.5):
  for side in [-1,1]: b([.23,.66,.27],[side*x,y,0],color,'body',[0,0,-side*12])
 if ident=='tung_sahur':
  b([.68,1.3,.55],[0,1.35,0],'#aa7040')
  b([.70,.64,.58],[0,2.05,-.015],'#bc8954','head')
  for x in [-.22,0,.22]: b([.035,1.75,.025],[x,1.55,-.29],'#825632')
  eyes(2.15,-.33)
  b([.20,.10,.05],[0,1.88,-.33],'#382c23','mouth')
  legs('#976236'); arms('#b27a43',1.22,.47)
  b([.16,.95,.16],[.69,1.06,-.26],'#77502d','body',[0,0,-18])
  b([.24,.48,.24],[.83,1.70,-.26],'#c19357','body',[0,0,-18])
 elif ident=='tralalero':
  b([.72,.64,1.65],[0,.93,0],'#78999f')
  b([.64,.44,.72],[0,.87,-1.04],'#8faeb1','head')
  b([.59,.17,.74],[0,.65,-1.04],'#e1dbbd','mouth')
  eyes(.99,-1.42,.22)
  for x in [-.23,-.08,.08,.23]: b([.08,.10,.06],[x,.76,-1.43],'#f2eddb','mouth')
  b([.12,.55,.55],[0,1.43,.05],'#5e8087','body',[20,0,0])
  b([.13,.70,.42],[0,.99,1.04],'#638b94','tail',[22,0,0])
  for x,z in [(-.43,-.22),(.43,-.22),(0,.66)]:
   b([.21,.43,.23],[x,.40,z],'#799a9d','leg')
   b([.37,.24,.60],[x,.14,z-.14],'#2776c6','foot')
   b([.38,.07,.60],[x,.045,z-.14],'#e2e8df','foot')
 elif ident=='saturnita':
  for s,y in [(1.35,1.22),(1.7,1.58),(1.35,1.95)]: b([s,.42,1.12],[0,y,0],'#bba877')
  for i in range(16):
   a=math.tau*i/16
   b([.68,.10,.25],[1.32*math.cos(a),1.6+.22*math.cos(a),.92*math.sin(a)],'#e1ca89' if i%2 else '#a69b7f','body',[0,-math.degrees(a),0])
  b([.64,.66,.55],[0,1.95,-.67],'#ece5cc','head')
  b([.22,.30,.06],[-.21,2.08,-.97],'#343533','head')
  b([.61,.27,.28],[0,1.77,-1.04],'#cc9b91','snout'); eyes(2.08,-.99)
  for side in [-1,1]:
   b([.17,.30,.15],[side*.30,2.41,-.62],'#e0c68e','horn',[0,0,side*-22])
   b([.28,.12,.20],[side*.43,2.14,-.64],'#a5957e','ear')
  legs('#ba9a80','#c9aa8c',.46,.39)
 elif ident=='bombardiro':
  b([.57,.49,2.25],[0,1.12,.18],'#65745d')
  b([.53,.37,.65],[0,1.19,-1.12],'#72895a','head')
  b([.47,.23,.79],[0,1.02,-1.38],'#829466','snout')
  b([.44,.07,.72],[0,.88,-1.38],'#d3c9a1','mouth'); eyes(1.30,-1.47)
  for side in [-1,1]:
   b([1.43,.13,.75],[side*.98,1.11,.0],'#78816a','wing',[0,side*-12,0])
   b([.24,.28,.60],[side*.88,.94,.05],'#414c44')
   b([.16,.24,.45],[side*.50,.73,.35],'#6d6b4b')
   for z in [-1.40,-1.12]: b([.07,.12,.07],[side*.2,.96,z],'#ede4c6','mouth')
  b([1.05,.12,.43],[0,1.19,1.19],'#67765e','tail')
  b([.12,.51,.52],[0,1.49,1.12],'#6c785f','tail')
  b([.35,.24,.49],[0,1.45,-.05],'#8caaa6')
 elif ident=='udin':
  b([1.05,.80,.70],[0,1.31,0],'#d88735')
  b([.79,.53,.68],[0,1.83,0],'#e69a3f','head')
  b([.61,.32,.73],[0,1.66,-.02],'#db903d','head'); eyes(1.88,-.39)
  b([.25,.08,.06],[0,1.58,-.41],'#815433','mouth')
  b([.12,.22,.10],[0,2.17,0],'#6a6740','head')
  b([.42,.11,.24],[.17,2.28,0],'#6f8b45','head',[0,0,22])
  b([.67,.26,.56],[0,.91,0],'#a54c51')
  for side in [-1,1]:
   b([.40,.55,.42],[side*.69,1.36,0],'#df9140')
   b([.33,.43,.37],[side*.82,.99,-.08],'#cb7d32')
  legs('#cd8539','#ac4941',.38,.27)
  for side in [-1,1]: b([.33,.06,.49],[side*.27,.025,-.12],'#e5dcc4','foot')
 elif ident in ['cappuccino_assassino','ballerina_cappuccina']:
  ninja=ident=='cappuccino_assassino'; cup='#d4c6a5' if ninja else '#f0dfc0'
  b([.67,.62,.62],[0,1.86,0],cup,'head')
  b([.62,.06,.57],[0,2.19,0],'#724b32','head')
  for x,z in [(0,0),(.12,.08),(-.12,-.08)]: b([.20,.025,.16],[x,2.23,z],'#eee3c6','head')
  for s,v in [([.14,.44,.12],[.47,1.87,0]),([.26,.12,.12],[.39,2.06,0]),([.26,.12,.12],[.39,1.68,0])]: b(s,v,cup,'ear')
  if ninja:
   b([.69,.29,.065],[0,1.71,-.34],'#343b40','mouth')
   b([.70,.16,.065],[0,2.10,-.34],'#343b40','head'); eyes(1.94,-.35)
   b([.55,.65,.43],[0,1.15,0],'#353f43'); arms('#41494a'); legs('#353f43','#343b3b')
   for side in [-1,1]:
    b([.085,.79,.085],[side*.70,1.43,-.27],'#cdd7d5','body',[0,0,side*-25])
    b([.26,.07,.16],[side*.55,1.04,-.27],'#b69c60')
  else:
   eyes(1.92,-.35); b([.16,.06,.05],[0,1.66,-.35],'#b87e7a','mouth')
   b([.42,.58,.38],[0,1.24,0],'#ce94a2'); arms('#dec1a5',1.35,.42)
   b([1.0,.17,.85],[0,.94,0],'#d5a6b4')
   b([.72,.19,.67],[0,1.07,0],'#e7bcc6')
   legs('#e6cab5','#b78091',.40,.21)
 elif ident=='patapim':
  b([.75,1.20,.60],[0,1.1,0],'#7f6846'); legs('#756044','#ad936b',.39,.33)
  arms('#796043',1.1,.55)
  b([.64,.65,.56],[0,1.96,0],'#aa9066','head'); eyes(2.05,-.32)
  b([.19,.23,.58],[0,1.83,-.50],'#997c52','snout')
  for side in [-1,1]:
   b([.27,.34,.18],[side*.42,1.98,0],'#96805d','ear')
   b([.59,.47,.55],[side*.34,2.39,.05],'#687c4b','head')
  b([.66,.40,.53],[0,2.65,.05],'#7e8c56','head')
 elif ident=='lirili':
  b([.94,.88,1.10],[0,1.09,0],'#7e9564'); legs('#8b9c6a','#956e49',.38,.34)
  b([.65,.61,.64],[0,1.80,-.36],'#9aa678','head'); eyes(1.88,-.71)
  b([.25,.62,.24],[0,1.32,-.77],'#9aa678','trunk')
  b([.30,.23,.39],[0,1.06,-.86],'#9aa678','trunk')
  for side in [-1,1]:
   b([.45,.66,.16],[side*.46,1.75,-.28],'#82996c','ear')
   b([.28,.77,.31],[side*.69,1.20,.20],'#69854f')
   b([.31,.25,.31],[side*.57,.94,.20],'#69854f')
   for y in [.98,1.22,1.47]: b([.10,.04,.08],[side*.86,y,.19],'#e2d0a0')
   b([.35,.10,.32],[side*.34,.20,-.12],'#c4ac7d','foot')
 else:
  b([.60,.86,.50],[0,1.12,0],'#ddbf59')
  for side in [-1,1]:
   b([.24,.72,.30],[side*.37,1.30,.03],'#e0c45d','body',[0,0,side*22])
   b([.20,.70,.23],[side*.51,.95,0],'#746046')
   b([.26,.28,.17],[side*.39,1.91,0],'#9a8059','ear')
  b([.59,.58,.52],[0,1.89,0],'#7d684d','head')
  b([.43,.30,.20],[0,1.75,-.28],'#b49a71','snout'); eyes(1.99,-.31)
  b([.25,.19,.07],[0,1.78,-.41],'#4a4033','mouth'); legs('#756146','#8c7755')
 return dict(units='meters',anchor=[0,.45,0],pieces=p)

def main():
 paths=['defs/things.json','lexicon/pt_br/things.json','balance.json','chaos_catalog.json','defs/modifiers.json','lexicon/pt_br/modifiers.json','lexicon/pt_br/display.json']
 defs,words,bal,catalog,mods,mwords,display=[read(p) for p in paths]
 ids={row[0] for row in SPECS}
 catalog['creations']=[r for r in catalog['creations'] if r['id'] not in ids]
 for ident,name,aliases,cost,hp,speed,damage in SPECS:
  visual=model(ident); write('models/'+ident+'.json',visual)
  defs[ident]=dict(category='creature',movement='chase_enemy',impact='stop',voxel_motion=True,ecology_tags=['brainrot',ident])
  if ident=='bombardiro':
   defs[ident].update(aerial=True,movement='fly',behaviors=[dict(when=dict(type='every',s=4.5),do=dict(type='drop',arg=dict(thing='grenade')))])
  words[ident]=dict(name=name,words=aliases,forms=[])
  bal['things'][ident]=dict(cost=cost,hp=hp,weight_kg=170 if ident=='bombardiro' else 90,speed=speed,impact_damage=damage)
  diet='species:'+ident
  mods['diet_species_'+ident]=dict(key='diet',value=diet)
  mwords['diet_species_'+ident]=dict(words=[f'que {only}{verb} {a}' for a in aliases for only in ['','só ','apenas '] for verb in ['coma','come','ataque','ataca','cace','caça']])
  display['mods']['diet'][diet]='caça só '+name
  mods['purge_species_'+ident]=dict(key='target_species',value=ident)
  mwords['purge_species_'+ident]=dict(words=[f'que {v} {q}{a}' for a in aliases for v in ['mate','mata','elimine','elimina','extermine','extermina'] for q in ['','todas as ','todos os ','todas ','todos ','todos os animais da espécie ']])
  display['mods']['target_species'][ident]='elimina todos: '+name
  effect='Criatura em blocos: mistura de partes, armas, dietas, técnicas e captura.'
  if ident=='bombardiro': effect='Crocodilo-avião: voa e solta uma granada a cada 4,5 s; aceita misturas e captura.'
  catalog['creations'].append(dict(id=ident,name=name,phrase='quero um '+name,group='Brainrots',effect=effect,pieces=len(visual['pieces']),base_cost=cost))
 for path,value in zip(paths,[defs,words,bal,catalog,mods,mwords,display]): write(path,value)
 print('Added',len(SPECS),'brainrots with models, aliases, diets and selective bombs.')

if __name__=='__main__': main()
