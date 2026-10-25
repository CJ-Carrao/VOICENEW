"""A block-style yellow smiling companion inspired by ThatMob's Verity."""
from add_dinosaur_pack import read, write, box
import math

def main():
    defs, words, bal, catalog, commands, phrases = [read(p) for p in ['defs/things.json','lexicon/pt_br/things.json','balance.json','chaos_catalog.json','defs/commands.json','lexicon/pt_br/commands.json']]
    defs['verity'] = dict(category='creature',movement='fly',aerial=True,impact='stop',default_order='follow',verity_companion=True,ecology_tags=['verity','orb','companion'])
    words['verity'] = dict(name='Verity',words=['verity','veriti','verite','bolinha amarela','bolinha sorridente','assistente amarelo'],forms=['veritys','verities','bolinhas amarelas','bolinhas sorridentes'])
    bal['things']['verity'] = dict(cost=85,hp=65,speed=4.0,weight_kg=2,impact_damage=6)
    pieces=[]
    step=.17
    for y in range(-3,4):
        for z in range(-3,4):
            width = math.floor(math.sqrt(max(0,3.5**2-y*y-z*z))) if y*y+z*z <= 3.5**2 else -1
            if width < 0: continue
            color = '#ffe35e' if y >= 1 else '#f4cd38' if y >= -1 else '#dbac28'
            box(pieces,[(width*2+1)*step,step,step],[0,y*step,z*step],color,'head')
    for side in [-1,1]: box(pieces,[.09,.18,.045],[side*.18,.15,-.59],'#25221b','eye')
    for x,y in [(-.27,-.09),(-.18,-.17),(-.09,-.21),(0,-.22),(.09,-.21),(.18,-.17),(.27,-.09)]:
        box(pieces,[.095,.045,.045],[x,y,-.59],'#25221b','mouth')
    write('models/verity.json',dict(units='meters',anchor=[0,0,0],pieces=pieces))
    catalog['creations']=[v for v in catalog['creations'] if v['id']!='verity']
    catalog['creations'].append(dict(id='verity',name='Verity',phrase='quero um verity',group='Criaturas',effect='Bolinha amarela sorridente. Flutua ao seu lado e aceita ordens, captura, armas e poderes. Perto do dono, cura 4 de vida a cada 4 s quando ele está abaixo de 60%; vários Veritys compartilham a recarga.',pieces=len(pieces),base_cost=85))
    for action in ['follow','stay','guard','attack','evade','retaliate','free','build','aggressive']:
        key='animal_order_verity_'+action
        commands[key]=dict(animal_order=action,species='verity')
        verbs=phrases['animal_order_'+action]['words']
        phrases[key]=dict(words=[noun+' '+verb for noun in words['verity']['words'] for verb in verbs])
    for p,v in zip(['defs/things.json','lexicon/pt_br/things.json','balance.json','chaos_catalog.json','defs/commands.json','lexicon/pt_br/commands.json'],[defs,words,bal,catalog,commands,phrases]): write(p,v)

if __name__=='__main__': main()
