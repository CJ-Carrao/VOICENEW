"""A spatial sword cuts a local arc; it does not launch a laser."""
from add_dinosaur_pack import read, write, box

def main():
    defs,words,bal,catalog=[read(p) for p in ['defs/things.json','lexicon/pt_br/things.json','balance.json','chaos_catalog.json']]
    defs['rift_knife']['behaviors']=[dict(when={'type':'on_fire'},do={'type':'anomaly','mode':'rift','damage':48,'reach':4.2})]
    defs['rift_knife']['strike_style']='slash'
    for alias in ['espada que corta o espaço','espada que corta espaço','espada dimensional','espada espacial','espada que corta o espaco']:
        if alias not in words['rift_knife']['words']: words['rift_knife']['words'].append(alias)
    bal['things']['rift_knife']['fire_cooldown']=.85
    pieces=[]
    box(pieces,[.095,.085,.32],[0,0,.18],'#30303c','grip')
    box(pieces,[.12,.11,.065],[0,0,.37],'#8e89bd','pommel')
    box(pieces,[.48,.12,.065],[0,0,0],'#aaa5bf','guard')
    box(pieces,[.19,.06,1.05],[0,0,-.57],'#d8d9e5','blade')
    box(pieces,[.025,.07,.99],[-.1,0,-.57],'#aba0df','edge')
    box(pieces,[.025,.07,.99],[.1,0,-.57],'#eeeafa','edge')
    box(pieces,[.10,.05,.2],[-.035,0,-1.18],'#e2e0ef','blade',[0,-23,0])
    write('models/rift_knife.json',dict(units='meters',anchor=[0,0,0],pieces=pieces,joints={'trigger':[0,0,.18],'muzzle':[0,0,-1.2]}))
    for row in catalog['creations']:
        if row['id']=='rift_knife':
            row.update(name='Espada que corta o espaço',phrase='quero uma espada dimensional',pieces=len(pieces),effect='Golpe de lâmina: abre uma fenda curva perto do jogador, sem projétil ou laser. 48 de dano (até 72 carregado), atravessa Infinito e corta blocos no arco. Recarga de 0,85 s.')
    for p,v in zip(['defs/things.json','lexicon/pt_br/things.json','balance.json','chaos_catalog.json'],[defs,words,bal,catalog]): write(p,v)

if __name__=='__main__': main()
