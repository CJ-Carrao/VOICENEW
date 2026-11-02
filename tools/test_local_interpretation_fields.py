"""Semantic guard regressions: accepted slots must match real parser recipes."""
import json
from pathlib import Path
from benchmark_local_interpreter import ROOT, parser_probe
from local_interpretation_fields import compile_plan, ground

fixtures=[
    ('creation','quero uma abelha agressiva com minigun que atira pokebola',
     {'intent':'create','subject':'bee','aggressive':True,'weapon':'minigun','shots':['capture_ball']},
     'quero uma abelha agressiva com minigun que atira pokebola'),
    ('creation','quero um cachorro que atira gato que atira pombo que atira rato',
     {'intent':'create','subject':'dog','shots':['cat','pigeon','rat']},
     'quero um cachorro que atira gato que atira pombo que atira rato'),
    ('command','ovelhas nao saiam desse lugar',{'intent':'stay','subject':'sheep'},'ovelhas fiquem aqui'),
    ('command','squirtle manda um jato de agua',{'intent':'move','subject':'squirtle','move':'water_gun'},'squirtle jato de agua'),
    ('creation','quero uma abelha com minigun que atira pokebola',{'intent':'create','subject':'bee','weapon':'minigun'},None),
    ('creation','quero um cachorro que atira gato que atira pombo que atira rato',{'intent':'create','subject':'dog','shots':['rat','cat','pigeon']},None),
    ('creation','quero uma galinha que so coma aranhas',{'intent':'create','subject':'chicken','head':'spider'},None),
    ('creation','quero uma formiga rainha que construa um ninho',{'intent':'create','subject':'queen_ant','form':'ant_nest'},None),
    ('creation','nao crie uma bomba nuclear',{'intent':'create','subject':'nuclear_bomb'},None),
    ('command','quero uma galinha',{'intent':'create','subject':'chicken'},None),
    ('creation','quero um cachorro com poder de apagar arquivos',{'intent':'create','subject':'dog'},None),
    ('command','cachorro quando tiver quase morrendo foge',{'intent':'evade','subject':'dog'},None),
    ('creation','quero um cachorro',None,None),
    ('creation','quero um cachorro',{'intent':'create','subject':[]},None),
    ('creation','quero um cachorro',{'intent':'create','subject':'dog','shots':None},None),
    ('creation','quero um cachorro',{'intent':'create','subject':'dog','count':True},None),
    ('creation','quero um cachorro',{'intent':'create','subject':'dog','question':'qual cachorro?'},None),
    ('command','elefante carregue o cachorro',{'intent':'carry','subject':'elephant'},'elefante carregue cachorro'),
    ('command','elefante carregue o cachorro e o gato',{'intent':'carry','subject':'elephant'},None),
    ('creation','quero um pato que so coma ratos',{'intent':'create','subject':'duck'},'quero um pato que so come ratos'),
]
phrases=[]; plans=[]
for mode,text,plan,expected in fixtures:
    phrase,why=compile_plan(plan,ground(text),mode)
    assert bool(phrase)==bool(expected),(text,why,phrase)
    plans.append((text,phrase,why,expected)); phrases.extend([phrase,expected or ''])
output=ROOT/'analysis/local-ai-field-guards'; output.mkdir(exist_ok=True)
rows=parser_probe(phrases,output,ROOT/'tools/godot/Godot_v4.7.2-stable_win64_console.exe')
for i,(text,phrase,why,expected) in enumerate(plans):
    actual,reference=rows[i*2:i*2+2]
    if expected: assert actual['ok'] and actual['recipe']==reference['recipe'],(text,actual,reference)
    else: assert not actual['ok'] and actual['recipe'] is None,(text,actual)
print(json.dumps({'fixtures':len(fixtures),'failures':[],'normal_parser_failure_verified':True}))
