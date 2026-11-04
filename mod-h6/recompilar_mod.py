"""Build locally with the user's original runtime and speech files; ships none of them."""
from pathlib import Path
import argparse, hashlib, json, shutil, struct, subprocess

def run(godot, *arguments):
    result=subprocess.run([str(godot),*map(str,arguments)],check=False)
    if result.returncode:raise RuntimeError('O Godot não concluiu a etapa de compilação.')
def build(project,godot,original,output):
    project=project.resolve();original=original.resolve();output=output.resolve()
    if output.exists():raise ValueError('Escolha uma pasta de saída nova.')
    if output==original.parent or output.is_relative_to(original.parent):raise ValueError('Mantenha a saída fora da instalação original.')
    if not (project/'project.godot').is_file():raise ValueError('Projeto modificado não encontrado.')
    for name in ['voice','licenses','x86_64']:
        if not (original.parent/name).is_dir():raise ValueError('Mantenha a distribuição oficial completa junto do EXE: '+name)
    raw=original.read_bytes()
    metadata=json.loads((Path(__file__).resolve().parent/'alteracoes.json').read_text(encoding='utf8'))
    if hashlib.sha256(raw).hexdigest()!=metadata['original_exe_sha256']:raise ValueError('Use o executável oficial H-6 correspondente a este pacote.')
    if raw[-4:]!=b'GDPC':raise ValueError('Executável original não reconhecido.')
    size=struct.unpack_from('<Q',raw,len(raw)-12)[0];offset=len(raw)-12-size
    if raw[offset:offset+4]!=b'GDPC':raise ValueError('Pacote original não reconhecido.')
    # Keep the original runtime local. Only its PE pack section changes.
    engine=bytearray(raw[:offset]);output.mkdir(parents=True)
    pack=output/'temporario.pck'
    run(godot,'--headless','--path',project,'--editor','--import')
    run(godot,'--headless','--path',project,'--export-pack','Windows Desktop',pack)
    data=pack.read_bytes();pe=struct.unpack_from('<I',engine,0x3c)[0]
    count=struct.unpack_from('<H',engine,pe+6)[0];optional=struct.unpack_from('<H',engine,pe+20)[0]
    found=False
    for i in range(count):
        section=pe+24+optional+i*40
        if engine[section:section+8].rstrip(b'\0')==b'pck':struct.pack_into('<II',engine,section+16,len(data)+12,len(engine));found=True;break
    if not found:raise ValueError('Runtime sem seção de pacote.')
    revision=int(metadata['gameplay'].rsplit('-',1)[-1])
    exe=output/('VOICENEW-H6-v'+str(revision)+'.exe');exe.write_bytes(engine+data+struct.pack('<Q4s',len(data),b'GDPC'))
    pack.unlink()
    for name in ['voice','licenses','x86_64']:shutil.copytree(original.parent/name,output/name)
    for item in original.parent.glob('*.dll'):shutil.copy2(item,output/item.name)
    for name in ['CREDITOS.txt','LICENCA.txt','CRIATIVIDADE.txt']:
        source=project/name if name=='CRIATIVIDADE.txt' else original.parent/name
        if source.is_file():shutil.copy2(source,output/name)
    (output/'jogar.cmd').write_text('@echo off\nstart "VOICENEW" /D "%~dp0" "%~dp0'+exe.name+'" %*\n',encoding='utf8')
    result={'exe':exe.name,'sha256':hashlib.sha256(exe.read_bytes()).hexdigest(),'base_sha256':hashlib.sha256(raw).hexdigest()}
    (output/'build-info.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
    return result
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--projeto',type=Path,required=True);parser.add_argument('--godot',type=Path,required=True)
    parser.add_argument('--original-exe',type=Path,required=True);parser.add_argument('--saida',type=Path,required=True)
    args=parser.parse_args()
    print(json.dumps(build(args.projeto,args.godot,args.original_exe,args.saida),ensure_ascii=False))
