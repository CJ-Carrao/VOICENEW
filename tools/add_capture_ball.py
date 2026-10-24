"""Capture ball in the game's voxel style; no creature recipe duplication."""
import json
from pathlib import Path
DATA = Path(__file__).resolve().parent.parent / 'game/data'
def read(p): return json.loads((DATA/p).read_text(encoding='utf-8'))
def write(p,v): (DATA/p).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def main():
    pieces=[]
    def box(size,pos,color,tag): pieces.append(dict(shape='box',size=size,pos=pos,color=color,tag=tag))
    for y,color in [(.12,'#d84645'),(-.12,'#e4ded1')]:
        box([.34,.15,.34],[0,y,0],color,'shell')
        box([.42,.10,.27],[0,y*.58,0],color,'shell')
        box([.27,.10,.42],[0,y*.58,0],color,'shell')
    box([.43,.055,.33],[0,0,0],'#303b42','band')
    box([.33,.055,.43],[0,0,0],'#303b42','band')
    box([.13,.13,.055],[0,0,-.23],'#303b42','button_frame')
    box([.085,.085,.03],[0,0,-.27],'#f3eac9','button')
    write('models/capture_ball.json',dict(units='meters',anchor=[0,0,0],pieces=pieces))
    defs=read('defs/things.json')
    defs['capture_ball']=dict(category='projectile',movement='ballistic',impact='stop',capture_ball=True)
    write('defs/things.json',defs)
    words=read('lexicon/pt_br/things.json')
    words['capture_ball']=dict(name='Pokébola',words=['pokebola','pokébola','pokebolas','pokébolas','poke bola','bola de captura','esfera de captura'],forms=[])
    write('lexicon/pt_br/things.json',words)
    bal=read('balance.json')
    bal['things']['capture_ball']=dict(cost=38,hp=45,weight_kg=1,speed=14,lifetime=0,impact_damage=0,fire_cooldown=.8)
    write('balance.json',bal)
    catalog=read('chaos_catalog.json')
    catalog['creations']=[r for r in catalog['creations'] if r['id']!='capture_ball']
    catalog['creations'].append(dict(id='capture_ball',name='Pokébola',phrase='quero uma pokebola',group='Captura',effect='Arremesse para tentar capturar. Criaturas feridas entram mais facilmente. E pega a bola e solta a arma atual; arremesse a bola cheia para liberar a criatura no seu time.',pieces=len(pieces),base_cost=38))
    write('chaos_catalog.json',catalog)

if __name__=='__main__': main()
