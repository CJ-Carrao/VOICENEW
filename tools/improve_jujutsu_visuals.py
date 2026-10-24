"""An imposing, original box-built Mahoraga; retain the existing cost and powers."""
from add_dinosaur_pack import read, write, box

def mahoraga():
 p=[]
 def b(size,pos,color,tag='body',rot=None,glow=0):
  box(p,size,pos,color,tag,rot)
  if glow: p[-1]['glow']=glow
 skin='#d5d4bf'; shade='#b6b9a8'; ivory='#ece7cf'; cloth='#454a49'; gold='#bda46a'
 b([1.12,.82,.66],[0,2.28,0],skin)
 b([1.40,.48,.68],[0,2.76,0],skin)
 b([.82,.72,.57],[0,1.80,0],shade)
 for side in [-1,1]:
  b([.60,.36,.17],[side*.33,2.70,-.40],ivory)
  b([.35,.44,.22],[side*.42,2.30,-.32],skin)
  for y in [1.86,2.10,2.32]: b([.29,.18,.12],[side*.17,y,-.35],skin)
  b([.50,.51,.63],[side*.89,2.76,0],skin)
  b([.43,.71,.47],[side*1.08,2.24,-.01],shade,'arm',[0,0,side*12])
  b([.49,.63,.50],[side*1.18,1.69,-.10],skin,'arm',[0,0,-side*7])
  b([.46,.27,.46],[side*1.21,1.33,-.12],shade,'arm')
  for x in [-.12,.02,.16]: b([.10,.27,.14],[side*1.21+x,1.16,-.27],ivory,'arm')
  b([.52,1.01,.60],[side*.36,.91,0],cloth,'leg')
  b([.48,.33,.56],[side*.36,.28,-.04],shade,'leg')
  b([.59,.26,.87],[side*.36,.13,-.20],shade,'foot')
  for x in [-.17,0,.17]: b([.12,.10,.16],[side*.36+x,.09,-.68],ivory,'foot')
 b([1.03,.31,.66],[0,1.48,0],'#e0dbbf')
 for x in [-.42,-.21,0,.21,.42]:
  b([.18,.66,.14],[x,1.13,-.34],'#515653','body',[0,0,x*-8])
  b([.06,.65,.04],[x+.07,1.13,-.42],'#69706a')
 b([.54,.28,.46],[0,3.10,-.02],shade,'head')
 b([.66,.56,.53],[0,3.40,-.06],skin,'head')
 b([.54,.23,.36],[0,3.20,-.31],shade,'mouth')
 b([.48,.11,.06],[0,3.24,-.51],'#353a35','mouth')
 for x in [-.18,-.09,0,.09,.18]: b([.065,.08,.065],[x,3.25,-.55],ivory,'mouth')
 b([.15,.22,.14],[0,3.40,-.39],ivory,'head')
 for side in [-1,1]:
  # Four eye-fins belong to the head, not to flight-granting anatomical wings.
  for upper in [-1,1]:
   b([.52,.14,.19],[side*.51,3.48+upper*.13,-.16],ivory,'head',[0,0,side*upper*22])
   b([.31,.10,.14],[side*.84,3.51+upper*.23,-.15],ivory,'head',[0,0,side*upper*30])
 b([.21,.25,.56],[0,3.47,.39],shade,'head')
 b([.16,.19,.54],[0,3.25,.80],skin,'head',[-35,0,0])
 # Sword of Extermination attached to the right forearm.
 b([.62,.15,.58],[1.18,1.65,-.17],gold,'arm')
 b([.20,1.37,.21],[1.20,.90,-.49],ivory,'arm',[-15,0,0],.45)
 b([.08,1.19,.06],[1.20,.90,-.62],'#f2e6b1','arm',[-15,0,0],.9)
 b([.19,.25,.21],[1.20,.17,-.68],ivory,'arm',[-15,0,0])
 return dict(units='meters',anchor=[0,0,0],pieces=p)

def main():
 model=mahoraga(); write('models/mahoraga.json',model)
 catalog=read('chaos_catalog.json')
 for row in catalog['creations']:
  if row['id']=='mahoraga':
   row['pieces']=len(model['pieces'])
   row['effect']='General de quase 4 m, espada e roda de oito pontas. Adapta após três exposições espaçadas e aprende a atravessar o Infinito.'
 write('chaos_catalog.json',catalog)
 print('Mahoraga rebuilt:',len(model['pieces']),'original box pieces; balance unchanged.')

if __name__=='__main__': main()
