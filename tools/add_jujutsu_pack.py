"""Original voxel models and composable techniques inspired by Jujutsu Kaisen."""
import json
from pathlib import Path
from improve_jujutsu_visuals import mahoraga

DATA = Path(__file__).resolve().parent.parent / 'game/data'
def read(p): return json.loads((DATA / p).read_text(encoding='utf-8'))
def write(p, v): (DATA / p).write_text(json.dumps(v, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
def box(size, pos, color, tag='core'):
    return dict(shape='box', size=size, pos=pos, color=color, tag=tag)

def main():
    things, words, mods, modwords, bal, catalog = [read(p) for p in ['defs/things.json', 'lexicon/pt_br/things.json', 'defs/modifiers.json', 'lexicon/pt_br/modifiers.json', 'balance.json', 'chaos_catalog.json']]
    specs = [
        ('mahoraga', 'Mahoraga', 'adaptation', 240, ['mahoraga', 'makora'], 'Adapta apos tres exposicoes espacadas; ataques repetidos perdem 80% do dano. Aprende a atravessar o Infinito.'),
        ('gojo_infinity', 'Infinito', 'infinity', 120, ['infinito', 'ilimitado', 'barreira do gojo', 'infinito do gojo', 'ilimitado do gojo'], 'Barreira pessoal: bloqueia ataques comuns por 16 s, recarrega por 8 s. Adaptacao, amplificacao, dominios e corte do mundo sao respostas.'),
        ('sukuna_cleave', 'Corte do Sukuna', 'cleave', 95, ['corte do sukuna', 'corte de sukuna', 'desmantelar', 'desmantelamento', 'clivar', 'dismantle', 'cleave'], 'Corte de 24 m, 32 de dano; quebra blocos comuns, mas respeita paredes e Infinito.'),
        ('sukuna_world_cut', 'Corte que corta o mundo', 'world_cut', 260, ['corte que corta o mundo', 'corte do mundo', 'corte mundial', 'corte espacial do sukuna'], '100 de dano, corta o espaco e atravessa Infinito; recarga de 4,5 s.'),
        ('sukuna_fuga', 'Fuga', 'fuga', 160, ['fuga', 'fuga do sukuna', 'flecha de fogo', 'chama divina'], 'Linha de fogo de 24 m; varia o tipo de dano contra adaptacao a cortes.'),
        ('yuji_black_flash', 'Flash Negro', 'black_flash', 85, ['flash negro', 'kokusen', 'black flash'], 'Golpe concentrado de curto alcance, 55 de dano e recarga de 3 s.'),
        ('reverse_curse', 'Tecnica reversa', 'reverse', 100, ['tecnica reversa', 'tecnica amaldicoada reversa', 'cura reversa'], 'Recupera 6 de vida a cada 1,5 s, sem ressuscitar nem passar da vida maxima.'),
        ('malevolent_shrine', 'Santuario Malevolente', 'shrine', 280, ['santuario malevolente', 'santuario do sukuna', 'dominio do sukuna', 'expansao de dominio do sukuna'], 'Dominio de 9 m por 6 s: cortes de acerto garantido; disputa com outro dominio e resistencia do dominio simples.'),
        ('unlimited_void', 'Vazio Infinito', 'void', 270, ['vazio infinito', 'dominio do gojo', 'expansao de dominio do gojo'], 'Dominio de 9 m: lentidao por 6 s; dominio simples, disputa de dominios e adaptacao sao respostas.'),
        ('simple_domain', 'Dominio Simples', 'simple_domain', 75, ['dominio simples', 'dominio antitecnica'], 'Reduz em 85% os cortes garantidos do dominio e protege da lentidao do Vazio Infinito.'),
        ('domain_amplification', 'Amplificacao de dominio', 'amplification', 110, ['amplificacao de dominio', 'amplificacao'], 'Permite ataques comuns atravessarem o Infinito, mas impede lancar outras tecnicas enquanto ativa.'),
    ]
    words['rift_knife']['words'] += [w for w in ['faca que corte o espaco', 'faca que corte espaco'] if w not in words['rift_knife']['words']]
    ids = {s[0] for s in specs}
    catalog['creations'] = [r for r in catalog['creations'] if r['id'] not in ids]
    for ident, name, key, cost, aliases, effect in specs:
        color = '#e2cf96' if key == 'adaptation' else '#9be7fa' if key in ['infinity', 'void'] else '#90e6b0' if key == 'reverse' else '#e76d80'
        pieces = [box([.18,.32,.10],[0,0,0],color), box([.11,.07,.13],[0,.20,0],'#e7d9bd'), box([.08,.28,.08],[0,-.24,0],'#4d535c','grip')]
        for side in [-1,1]: pieces += [box([.06,.12,.14],[side*.16,.04,0],color,'rune'),box([.08,.06,.13],[side*.10,-.12,0],'#d4cfb8','rune')]
        if key == 'adaptation':
            pieces = mahoraga()['pieces']
        write('models/'+ident+'.json', dict(units='meters', anchor=[0,0,0], pieces=pieces))
        things[ident] = dict(category='creature' if key == 'adaptation' else 'tool', movement='chase_enemy' if key == 'adaptation' else 'static', impact='stop', jujutsu={key:True})
        if key == 'adaptation': things[ident].update(voxel_motion=True, ecology_tags=['mahoraga','shikigami'])
        else:
            things[ident]['behaviors'] = [dict(when=dict(type='on_fire'), do=dict(type='jujutsu'))]
        words[ident] = dict(name=name, words=aliases, forms=[])
        bal['things'][ident] = dict(cost=cost, hp=380 if key=='adaptation' else 120, weight_kg=120 if key=='adaptation' else 1, speed=3.4 if key=='adaptation' else 0, fire_cooldown=1.0, impact_damage=12 if key=='adaptation' else 0)
        modid = 'jj_'+key
        mods[modid] = dict(key=modid, value=True)
        forms = []
        for alias in aliases:
            forms += [f'com {alias}',f'com o {alias}',f'com a {alias}',f'com a habilidade do {alias}',f'com a habilidade de {alias}',f'com a habilidade {alias}',f'com o poder do {alias}',f'que usa {alias}',f'que tem {alias}']
        if key == 'adaptation': forms += ['adaptativo', 'adaptativa', 'com adaptacao do mahoraga', 'com a adaptacao do mahoraga']
        modwords[modid] = dict(words=forms)
        bal['cost']['mods'][modid] = cost - (20 if key == 'adaptation' else 0)
        catalog['creations'].append(dict(id=ident, name=name, phrase='quero '+name.lower(), group='Jujutsu', effect=effect, pieces=len(pieces), base_cost=cost))
    for key, name, cost in [('blue','azul',100),('red','vermelho',160),('purple','vazio roxo',290)]:
        modid = 'jj_'+key
        mods[modid] = dict(key=modid, value=True)
        modwords[modid] = dict(words=[f'com a habilidade do {name}',f'com o poder do {name}',f'que usa {name}',f'com a tecnica {name}'])
        bal['cost']['mods'][modid] = cost
    for p,v in [('defs/things.json',things),('lexicon/pt_br/things.json',words),('defs/modifiers.json',mods),('lexicon/pt_br/modifiers.json',modwords),('balance.json',bal),('chaos_catalog.json',catalog)]: write(p,v)

if __name__ == '__main__': main()
