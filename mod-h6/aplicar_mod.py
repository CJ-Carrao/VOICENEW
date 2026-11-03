"""Apply the VOICENEW source changes to an existing, user-supplied editable H-6 copy."""
from pathlib import Path
import argparse, hashlib, json, shutil

def digest(data): return hashlib.sha256(data).hexdigest()
def text_hash(data): return digest(data.replace('\r\n','\n').encode('utf8'))
def at_path(value, path):
    for key in path: value=value[key]
    return value
def apply_json(value, operations):
    for op in operations:
        if op['kind']=='replace_root': value=op['value'];continue
        target=at_path(value,op['path'])
        if op['kind']=='set': target[op['key']]=op['value']
        elif op['kind']=='remove': target.pop(op['key'])
        elif op['kind']=='order':
            items=[(key,target[key]) for key in op['keys']];target.clear();target.update(items)
        elif op['kind']=='splice': target[op['start']:op['end']]=op['values']
    return value
def safe(root, relative):
    path=(root/relative).resolve()
    if not path.is_relative_to(root.resolve()): raise ValueError('Caminho fora do projeto')
    return path
def apply(base, output, kit):
    base=base.resolve();output=output.resolve()
    if not (base/'project.godot').is_file():raise ValueError('Selecione a pasta da base editável H-6, com project.godot.')
    if output.exists():raise ValueError('Escolha uma pasta de saída nova. A base original não será alterada.')
    if output==base or output.is_relative_to(base):raise ValueError('A saída deve ficar fora da base original.')
    manifest=json.loads((kit/'alteracoes.json').read_text(encoding='utf8'))
    resolved={}
    # Validate every input before copying or changing any files.
    for op in manifest['files']:
        rel=op.get('source',op['path'])
        if op['kind']=='local_copy':
            sources=[p for p in base.glob(op['pattern']) if p.is_file() and digest(p.read_bytes())==op['before']]
            if len(sources)!=1:raise ValueError('Recurso original necessário não encontrado: '+op['path'])
            resolved[op['path']]=sources[0]
        elif op.get('before'):
            source=safe(base,rel)
            if not source.is_file():raise ValueError('Arquivo original ausente: '+rel)
            actual=text_hash(source.read_text(encoding='utf8')) if op['kind']=='text' else digest(source.read_bytes())
            if actual!=op['before']:raise ValueError('Base diferente da H-6 esperada: '+rel)
    shutil.copytree(base,output,ignore=shutil.ignore_patterns('.godot','.git','gdre_export.log'))
    for op in manifest['files']:
        target=safe(output,op['path']);target.parent.mkdir(parents=True,exist_ok=True)
        if op['kind']=='local_copy':shutil.copy2(resolved[op['path']],target)
        elif op['kind']=='new_file':shutil.copy2(safe(kit,op['payload']),target)
        elif op['kind']=='new_text':target.write_text(op['text'],encoding='utf8')
        elif op['kind']=='text':
            lines=safe(base,op['path']).read_text(encoding='utf8').replace('\r\n','\n').splitlines(keepends=True)
            for edit in reversed(op['edits']):lines[edit['start']:edit['end']]=edit['lines']
            result=''.join(lines)
            if text_hash(result)!=op['after']:raise ValueError('Resultado inválido: '+op['path'])
            target.write_text(result,encoding='utf8')
        elif op['kind']=='json':
            value=json.loads(safe(base,op.get('source',op['path'])).read_text(encoding='utf8'))
            value=apply_json(value,op['operations'])
            encoded=json.dumps(value,ensure_ascii=False,indent=2)+'\n'
            if text_hash(encoded)!=op['after']:raise ValueError('Resultado JSON inválido: '+op['path'])
            target.write_text(encoded,encoding='utf8')
        elif op['kind']=='new_json':target.write_text(json.dumps(op['value'],ensure_ascii=False,indent=2)+'\n',encoding='utf8')
        elif op['kind']=='h6_manifest':
            value=op['metadata'].copy()
            definitions=json.loads((base/'data/defs/things.json').read_text(encoding='utf8'))
            value['new_definitions']={key:definitions[key] for key in op['definition_ids']}
            target.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    return len(manifest['files'])
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base',type=Path,required=True)
    parser.add_argument('--saida',type=Path,required=True)
    args=parser.parse_args()
    try: count=apply(args.base,args.saida,Path(__file__).resolve().parent)
    except (ValueError,FileNotFoundError) as error:parser.exit(1,str(error)+'\n')
    print(f'Aplicadas {count} alterações. Projeto preparado em: {args.saida}')
