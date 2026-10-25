"""Voice-programmed companions, transformations and a bounded projectile converter."""
from add_dinosaur_pack import read, write, box
from copy import deepcopy

def main():
    paths=['defs/things.json','lexicon/pt_br/things.json','balance.json','chaos_catalog.json','defs/commands.json','lexicon/pt_br/commands.json','defs/modifiers.json','lexicon/pt_br/modifiers.json','lexicon/pt_br/display.json']
    defs,words,bal,catalog,commands,phrases,mods,mwords,display=[read(p) for p in paths]
    mods['armored']=dict(key='armored',value=True)
    mwords['armored']=dict(words=['com armadura','armadurado','armadurada','blindado','blindada'])
    display['mods']['armored']='armadura'
    display['mods']['transform_to']='transformação: {value}'
    bal['cost']['mods']['armored']=35
    examples=['aguia carregue um cachorro','elefante carregue uma torre','formigas consertem a armadura do elefante','cachorro proteja o pikachu se ele ficar ferido leve ele ate mim','cachorro se eu for atacado me proteja','cachorro se ficar com pouca vida recue','aguia solte a carga','cachorro cancele a regra','cachorro transforme agora','cachorro volte a forma original']
    commands['creature_tactics']=dict(tactical=True)
    phrases['creature_tactics']=dict(words=examples)
    display['commands']['creature_tactics']='ordem de equipe'
    # These entries also supply the offline recognizer with conditional creation vocabulary.
    phrases['creature_tactics']['words'] += ['quero um cachorro que vire tanque quando estiver com pouca vida','quero um cachorro que se transforme em tanque quando ficar com pouca vida','quero um cachorro que vire tanque quando tiver pouca vida']
    for id,advanced,cost in [('butterfly_shield',False,100),('advanced_butterfly_shield',True,220)]:
        name='Escudo de borboletas'+(' avançado' if advanced else '')
        defs[id]=dict(category='tool',movement='static',impact='stop',butterfly_shield=True,butterfly_shield_advanced=advanced,shield_profile='butterfly',shield_radius=3.0)
        words[id]=dict(name=name,words=['escudo de borboletas avancado','escudo que transforma tiros fortes em borboletas'] if advanced else ['escudo de borboletas','escudo que transforma balas em borboletas','escudo que transforma tiros em borboletas'],forms=[])
        bal['things'][id]=dict(cost=cost,hp=110 if advanced else 70,weight_kg=2)
        pieces=[]
        for side in [-1,1]:
            box(pieces,[.06,.38,.07],[side*.20,.05,0],'#5b6075','frame')
            box(pieces,[.16,.07,.07],[side*.12,.22,0],'#bdb0d9' if not advanced else '#a3c5df','wing')
            box(pieces,[.16,.07,.07],[side*.12,-.12,0],'#a58dbc' if not advanced else '#88adc4','wing')
        box(pieces,[.06,.32,.06],[0,-.02,.03],'#3e424d','grip')
        box(pieces,[.12,.12,.08],[0,.04,0],'#ebd3e1' if not advanced else '#d0e2ef','core')
        write('models/'+id+'.json',dict(units='meters',anchor=[0,0,0],pieces=pieces,joints={'trigger':[0,-.1,.05]}))
        catalog['creations']=[r for r in catalog['creations'] if r['id']!=id]
        catalog['creations'].append(dict(id=id,name=name,phrase='quero '+words[id]['words'][0],group='Defesas',base_cost=cost,pieces=len(pieces),effect='Converte projéteis comuns em borboletas inofensivas num raio de 3 m. Energia limitada, regeneração de 4/s. '+('Suporta projéteis de até 45 de dano; reserva 32.' if advanced else 'Até 25 de dano por projétil; reserva 20.')+' Não converte bombas nem técnicas fortes.'))
    bal['innovation']['resistance']['butterfly']={}
    defs['shield_butterfly']=dict(category='projectile',movement='fly',impact='stop',shield_cosmetic=True)
    words['shield_butterfly']=dict(name='Borboleta do escudo',words=[],forms=[])
    bal['things']['shield_butterfly']=dict(cost=0,hp=1,speed=2,lifetime=3,impact_damage=0,weight_kg=.01)
    write('models/shield_butterfly.json',deepcopy(read('models/butterfly.json')))
    for path,value in zip(paths,[defs,words,bal,catalog,commands,phrases,mods,mwords,display]): write(path,value)

if __name__=='__main__': main()
