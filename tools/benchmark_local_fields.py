"""Compare bounded local slots with actual Godot recipes, never opening a match."""
import argparse
import json
import os
from pathlib import Path
import socket
import statistics
import subprocess
import time
import urllib.request

from benchmark_local_interpreter import CASES, HOLDOUT, ROOT, memory, parser_probe, post
from local_interpretation_fields import SYSTEM, EXAMPLES, compile_plan, ground, messages, schema, plan_from_recipe

# Fixed before this round's inference; not supplied as examples or per-request answers.
NEW_CASES = [
    ('creation','Cria pra mim cinco abelhas','quero cinco abelhas'),
    ('creation','Me traz um urso usando um rifle que dispara abelhas','quero um urso com rifle que atira abelhas'),
    ('creation','Preciso de um coelho com rosto de uma galinha','quero um coelho com cabeca de galinha'),
    ('creation','Faz um cavalo que se transforme em tanque quando estiver com pouca vida','quero um cavalo que vire tanque quando estiver com pouca vida'),
    ('creation','Quero uma galinha que so coma as aranhas','quero uma galinha que so come aranhas'),
    ('creation','Me da um gato agressivo com uma escopeta que atire pombos','quero um gato agressivo com escopeta que atira pombos'),
    ('command','Lobos, quero que voces venham atras de mim','lobos me sigam'),
    ('command','Ovelhas, nao saiam desse lugar','ovelhas fiquem aqui'),
    ('command','Cavalos, ataquem aquele inimigo','cavalos ataquem aquele jogador'),
    ('command','Urso, quando eu for atacado vem me proteger','urso se eu for atacado me proteja'),
    ('command','Aguia transporte o gato','aguia carregue gato'),
    ('command','Cachorro, recua se estiver com pouca vida','cachorro se ficar com pouca vida recue'),
    ('unsupported','Nao faca nenhuma bomba de neutrons',None),
    ('unsupported','Crie um coelho que atravesse todas as paredes',None),
    ('unsupported','Crie um gato que controle meu Windows',None),
    ('command','Quero um jacare',None),
]

FINAL_CASES = [
    ('creation','Me arruma quatro patos','quero quatro patos'),
    ('creation','Quero uma galinha usando uma pistola que dispare ratos','quero uma galinha com pistola que atira ratos'),
    ('creation','Preciso de um urso com cabeca de um coelho','quero um urso com cabeca de coelho'),
    ('creation','Faz um elefante que so coma galinhas','quero um elefante que so come galinhas'),
    ('command','Gatos, nao se mexam','gatos fiquem aqui'),
    ('command','Coelhos venham me acompanhando','coelhos me sigam'),
    ('command','Todos voces me sigam','todos me sigam'),
    ('command','Leao pegue o gato e carregue ele','leao carregue gato'),
    ('command','Rato quando eu for atacado me proteja','rato se eu for atacado me proteja'),
    ('unsupported','Quero um cachorro com poder de apagar arquivos',None),
    ('unsupported','Crie um rato que controle o clima',None),
    ('command','Me de um tanque',None),
]


def evaluate(args,rows,metrics):
    phrases=[]
    for row in rows: phrases.extend([row['input'],row['expected'] or '',row['phrase']])
    parsed=parser_probe(phrases,args.output,args.godot)
    for index,row in enumerate(rows):
        original,want,got=parsed[index*3:index*3+3]
        row.update(original=original,reference=want,actual=got)
        if row['expected'] is not None:
            if not want['ok']: raise ValueError('Invalid reference: '+row['expected'])
            row['correct']=bool(row['phrase']) and got['ok'] and got['recipe']==want['recipe']
            row['original_correct']=original['ok'] and original['recipe']==want['recipe'] and (row['mode']!='command' or 'command' in (original['recipe'] or {}))
        else:
            row['correct']=not row['phrase'] and not got['ok']
            row['original_correct']=not original['ok'] or (row['mode']=='command' and 'command' not in (original['recipe'] or {}))
        row['wrong_accepted']=bool(row['phrase']) and got['ok'] and not row['correct']
        row['false_rejection']=(not row['phrase'] or not got['ok']) and row['expected'] is not None
        row['invalid_syntax']=bool(row['phrase']) and not got['ok']
        start=time.perf_counter()
        old_plan=plan_from_recipe(original.get('recipe'))
        fast_phrase,fast_why=compile_plan(old_plan,ground(row['input']),row['mode']) if old_plan else ('','unsupported_existing_recipe')
        row['fast_path_check_ms']=(time.perf_counter()-start)*1000
        row['fast_phrase']=fast_phrase; row['fast_validation']=fast_why
        row['fast_plan']=old_plan
    # Replay the hybrid decision using recorded answers; no new inference or reference-answer hints.
    # The fast path always validates through the SAME compiler as model-generated plans.
    hybrid_dir=args.output/'hybrid'; hybrid_dir.mkdir(exist_ok=True)
    fast_rows=parser_probe([r['fast_phrase'] for r in rows],hybrid_dir,args.godot)
    for row,fast in zip(rows,fast_rows):
        use_fast=bool(row['fast_phrase']) and fast['ok']
        chosen=fast if use_fast else row['actual']
        accepted=bool(row['fast_phrase']) if use_fast else bool(row['phrase'])
        row['hybrid_route']='existing_parser' if use_fast else 'model'
        row['hybrid_correct']=(accepted and chosen['ok'] and chosen['recipe']==row['reference']['recipe']) if row['expected'] is not None else not accepted and not chosen['ok']
        row['hybrid_wrong_accepted']=accepted and chosen['ok'] and not row['hybrid_correct']
        row['hybrid_false_rejection']=(not accepted or not chosen['ok']) and row['expected'] is not None
    times=[r['seconds'] for r in rows]
    def group(subset):
        return {'n':len(subset),'correct':sum(r['correct'] for r in subset),
                'supported_n':sum(r['expected'] is not None for r in subset),
                'correct_creations_or_orders':sum(r['correct'] and r['expected'] is not None for r in subset),
                'expected_rejections':sum(r['expected'] is None for r in subset),
                'correct_rejections':sum(r['correct'] and r['expected'] is None for r in subset),
                'wrong_accepted':sum(r['wrong_accepted'] for r in subset),
                'false_rejections':sum(r['false_rejection'] for r in subset),
                'invalid_syntax':sum(r['invalid_syntax'] for r in subset),
                'hybrid_correct':sum(r['hybrid_correct'] for r in subset),
                'hybrid_wrong_accepted':sum(r['hybrid_wrong_accepted'] for r in subset),
                'hybrid_false_rejection':sum(r['hybrid_false_rejection'] for r in subset),
                'fast_path':sum(r['hybrid_route']=='existing_parser' for r in subset),
                'original_correct':sum(r['original_correct'] for r in subset)}
    summary={'date':'2026-10-26','model':args.model,'cpu_threads':4,'thinking':False,'context':4096,**metrics,
             'first_request_seconds':times[0],'warm_median_seconds':statistics.median(times[1:]),
             'warm_p95_seconds':sorted(times[1:])[int(.95*(len(times)-2))],
             'all':group(rows),'previous_46':group(rows[:46]),'new_16':group(rows[46:62]),'final_12':group(rows[62:]),
             'rejection_uses':'empty input -> existing PhraseParser failure; no custom text or clarification',
             'limitations':['Fixed developer-authored text corpus, not real microphone recordings.',
                            'New 16 requests fixed before this run; not in few-shot examples.',
                            'Entity grounding, count extraction and validation also contribute; not model-only accuracy.',
                            'Prototype slots cover only the listed operations; no gameplay or menu integration.',
                            'No gameplay FPS measurement. Requests run sequentially.']}
    result={'summary':summary,'system':SYSTEM,'examples':EXAMPLES,'rows':rows}
    (args.output/'results.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8')
    print(json.dumps(summary,ensure_ascii=False),flush=True)


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--root',type=Path,default=Path(os.environ['LOCALAPPDATA'])/'VOICENEW-AI-Test')
    ap.add_argument('--model',default='Qwen3-0.6B-Q4_K_M.gguf')
    ap.add_argument('--output',type=Path,default=ROOT/'analysis/local-ai-fields06')
    ap.add_argument('--godot',type=Path,default=ROOT/'tools/godot/Godot_v4.7.2-stable_win64_console.exe')
    ap.add_argument('--rescore-only',action='store_true')
    args=ap.parse_args(); args.output=args.output.resolve(); args.output.mkdir(parents=True,exist_ok=True)
    if args.rescore_only:
        rows=json.loads((args.output/'partial.json').read_text(encoding='utf8'))
        for row in rows:
            row['grounded']=ground(row['input'])
            row['phrase'],row['validation']=compile_plan(row['plan'],row['grounded'],row['mode'])
        metrics=json.loads((args.output/'measurements.json').read_text(encoding='utf8'))
        (args.output/'validation_snapshot.py.txt').write_text((ROOT/'tools/local_interpretation_fields.py').read_text(encoding='utf8'),encoding='utf8')
        evaluate(args,rows,metrics)
        return
    with socket.socket() as sock:
        sock.bind(('127.0.0.1',0)); port=sock.getsockname()[1]
    url=f'http://127.0.0.1:{port}'
    cmd=[str(args.root/'runtime/llama-server.exe'),'-m',str(args.root/args.model),'-c','4096','-t','4','-tb','4','-ngl','0','-np','1','--host','127.0.0.1','--port',str(port),'--reasoning','off','--no-webui']
    started=time.perf_counter(); log=(args.output/'server.log').open('wb')
    process=subprocess.Popen(cmd,stdout=log,stderr=log,creationflags=subprocess.CREATE_NO_WINDOW)
    (args.output/'implementation_snapshot.py.txt').write_text((ROOT/'tools/local_interpretation_fields.py').read_text(encoding='utf8'),encoding='utf8')
    rows=[]; metrics={}
    try:
        deadline=time.monotonic()+90
        while True:
            if process.poll() is not None: raise RuntimeError('Server failed; see log')
            try:
                with urllib.request.urlopen(url+'/health',timeout=1) as health:
                    if health.status==200: break
            except (OSError,urllib.error.URLError): pass
            if time.monotonic()>deadline: raise TimeoutError('Model startup')
            time.sleep(.2)
        metrics={'cold_load_seconds':time.perf_counter()-started,'idle_memory':memory(process.pid)}
        for i,(mode,text,expected) in enumerate(CASES+HOLDOUT+NEW_CASES+FINAL_CASES):
            grounded=ground(text); start=time.perf_counter()
            response=post(url+'/v1/chat/completions',{'messages':messages(text,mode,grounded),
                'temperature':0,'seed':42,'max_tokens':220,'stream':False,'chat_template_kwargs':{'enable_thinking':False},
                'response_format':{'type':'json_schema','json_schema':{'name':'slots','strict':True,'schema':schema(grounded,mode)}}})
            seconds=time.perf_counter()-start
            raw=response['choices'][0]['message'].get('content','')
            try: plan=json.loads(raw)
            except (ValueError,TypeError): plan={}
            phrase,why=compile_plan(plan,grounded,mode)
            row={'split':'previous' if i<46 else ('development_16' if i<62 else 'final_12'),'mode':mode,'input':text,'expected':expected,
                 'grounded':grounded,'plan':plan,'phrase':phrase,'validation':why,'seconds':seconds,
                 'finish_reason':response['choices'][0].get('finish_reason'),'raw':raw,'usage':response.get('usage')}
            rows.append(row); metrics['last_memory']=memory(process.pid)
            (args.output/'partial.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf8')
            (args.output/'measurements.json').write_text(json.dumps(metrics),encoding='utf8')
            print(json.dumps({'case':i+1,'seconds':round(seconds,3),'plan':plan,'validation':why,'phrase':phrase},ensure_ascii=False),flush=True)
    finally:
        process.terminate()
        try: process.wait(timeout=10)
        except subprocess.TimeoutExpired: process.kill();process.wait()
        log.close()
    evaluate(args,rows,metrics)


if __name__=='__main__': main()
