"""A stone castle built from editable block pieces in construction order."""
from add_dinosaur_pack import read,write,box
from copy import deepcopy
def main():
    p=[]
    def b(s,v,c='#777b80',tag='body',collision=True):
        box(p,s,v,c,tag);p[-1]['collision']=collision
    # Foundation, courtyard and an opening for a real, separate moving gate.
    b([20,.3,16],[0,.15,0],'#67696c')
    for row in range(6):
        y=.3+(row+.5)*.8
        for x in range(-9,10,2):
            b([1.94,.78,.7],[x,y,7.65])
            if abs(x)>3:b([1.94,.78,.7],[x,y,-7.65])
        for z in range(-6,7,2):
            for x in [-9.65,9.65]:b([.7,.78,1.94],[x,y,z])
    b([8,.8,.7],[0,5.5,-7.65])
    for x in range(-9,10,2):
        for z in [-7.65,7.65]:b([.9,.75,.8],[x,5.45,z],'#85888b')
    for z in range(-6,7,2):
        for x in [-9.65,9.65]:b([.8,.75,.9],[x,5.45,z],'#85888b')
    # Hollow corner towers; floor and crenellations leave visible walkable chambers.
    for x in [-8.5,8.5]:
        for z in [-6.5,6.5]:
            for y in [.9,2.1,3.3,4.5,5.7,6.9]:
                for dx in [-1.25,1.25]:b([.5,1.18,3],[x+dx,y,z])
                for dz in [-1.25,1.25]:b([2,1.18,.5],[x,y,z+dz])
            b([3,.25,3],[x,6.5,z],'#686d74')
            for dx,dz in [(-1.25,-1.25),(1.25,-1.25),(-1.25,1.25),(1.25,1.25)]:b([.65,.8,.65],[x+dx,7.9,z+dz],'#96989a')
    # Rear keep with a real doorway; courtyard lanes remain open around it.
    for row in range(5):
        y=.3+(row+.5)*1.05
        b([.6,1.03,4],[-3,y,3]);b([.6,1.03,4],[3,y,3]);b([6,1.03,.6],[0,y,4.7])
    b([6,.5,.6],[0,5.3,1.3])
    b([6.6,.3,4.6],[0,5.7,3],'#555b67')
    # Ramp steps into the courtyard; access is never a solid decorative box.
    b([8,.15,1.0],[0,.075,-8.4],'#777b80')
    b([.13,3,.13],[0,5.7,3],'#655649',collision=False)
    b([1.35,.85,.08],[.68,6.45,3],'#7f3c44','flag',False)
    write('models/medieval_castle.json',dict(units='meters',anchor=[0,0,0],pieces=p))
    gate=[];box(gate,[7.9,4.8,.4],[0,2.4,0],'#695341','body')
    for x in [-2.8,0,2.8]:box(gate,[.10,4.8,.43],[x,2.4,0],'#333b42','body')
    write('models/castle_gate.json',dict(units='meters',anchor=[0,0,0],pieces=gate))
    defs=read('defs/things.json');words=read('lexicon/pt_br/things.json');bal=read('balance.json');catalog=read('chaos_catalog.json')
    defs['medieval_castle']=dict(category='structure',movement='static',impact='stop',castle_base=True,hollow=True)
    defs['castle_gate']=dict(category='structure',movement='static',impact='stop',castle_gate=True,internal=True)
    words['castle_gate']=dict(name='Portão da base',words=[],forms=[])
    words['medieval_castle']=dict(name='Castelo medieval',words=['castelo','castelo medieval','castelo de pedra','castelo medieval de pedra','fortaleza','fortaleza medieval','castelo com quatro torres','castelo medieval com quatro torres'],forms=['castelos'])
    bal['things']['medieval_castle']=dict(cost=800,hp=3200,weight_kg=12000,speed=0,impact_damage=0)
    bal['things']['castle_gate']=dict(cost=45,hp=260,weight_kg=500,speed=0,impact_damage=0)
    catalog['creations']=[r for r in catalog['creations'] if r['id']!='medieval_castle']
    catalog['creations'].append(dict(id='medieval_castle',name='Castelo medieval',phrase='quero um castelo medieval de pedra',group='Bases',effect='Base de pedra com quatro torres, portão automático, patrulhas, reparos e blocos destrutíveis. Uma por jogador.',pieces=len(p),base_cost=800))
    for ident,size,cost,hp,name,aliases in [('small_castle',.7,500,2200,'Castelo pequeno',['castelo pequeno','castelo medieval pequeno','castelo pequeno de pedra']),('large_castle',1.3,1250,4200,'Castelo grande',['castelo grande','castelo medieval grande','castelo grande de pedra'])]:
        visual=deepcopy(p)
        for piece in visual:
            for axis in [0,2]:piece['pos'][axis]*=size;piece['size'][axis]*=size
        write('models/'+ident+'.json',dict(units='meters',anchor=[0,0,0],pieces=visual))
        defs[ident]=dict(category='structure',movement='static',impact='stop',castle_base=True,hollow=True,castle_size=size)
        words[ident]=dict(name=name,words=aliases,forms=[])
        bal['things'][ident]=dict(cost=cost,hp=hp,weight_kg=12000*size,speed=0,impact_damage=0)
        catalog['creations']=[r for r in catalog['creations'] if r['id']!=ident]
        catalog['creations'].append(dict(id=ident,name=name,phrase='quero um '+aliases[0],group='Bases',effect='Mesmo sistema de base, com pátio e entrada utilizáveis. Uma base por jogador.',pieces=len(visual),base_cost=cost))
    for path,value in [('defs/things.json',defs),('lexicon/pt_br/things.json',words),('balance.json',bal),('chaos_catalog.json',catalog)]:write(path,value)
    print('Castle:',len(p),'pieces')
if __name__=='__main__':main()
