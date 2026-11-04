from pathlib import Path
import zipfile, hashlib, json
root=Path(__file__).resolve().parent.parent
build=root/'build/H6-Lab'
(root/'dist').mkdir(exist_ok=True)
archive=root/'dist/VOICENEW-Windows.zip'
files=[p for p in build.iterdir() if p.is_file() and (p.suffix.lower()=='.dll' or p.name in ['LAVOICE-Lab-H6-v44.exe','LAVOICE-Lab-H6-v44.receipt.json','CREDITOS.txt','LICENCA.txt','CRIATIVIDADE.txt'])]
for folder in ['voice','licenses','x86_64']:
 files.extend(p for p in (build/folder).rglob('*') if p.is_file())
assert any(p.name=='LAVOICE-Lab-H6-v44.exe' for p in files)
assert any(p.suffix=='.onnx' for p in files)
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=1,allowZip64=True) as z:
 for p in sorted(files): z.write(p,'VOICENEW/'+p.relative_to(build).as_posix())
 z.writestr('VOICENEW/jogar.cmd','@echo off\r\nstart "VOICENEW" /D "%~dp0" "%~dp0LAVOICE-Lab-H6-v44.exe" %*\r\n')
 z.writestr('VOICENEW/LEIA-ME.txt','VOICENEW para Windows\r\n\r\nExtraia a pasta inteira e abra jogar.cmd.\r\nMantenha voice, licenses, x86_64 e as DLLs ao lado do executavel.\r\nV: criar por voz. B: dar comandos por voz. T: console de texto.\r\nE: pegar item. G: soltar item. F2: catalogo.\r\nNo online, todos devem usar a mesma versao.\r\n')
with zipfile.ZipFile(archive) as z:
 assert z.testzip() is None
 names=z.namelist()
 assert 'VOICENEW/jogar.cmd' in names and 'VOICENEW/LAVOICE-Lab-H6-v44.exe' in names
 assert not any(p.endswith('.pck') for p in names)
sha=hashlib.sha256()
with archive.open('rb') as f:
 for chunk in iter(lambda:f.read(1024*1024),b''): sha.update(chunk)
(root/'dist/SHA256SUMS.txt').write_text(sha.hexdigest()+'  VOICENEW-Windows.zip\n',encoding='utf8')
print(json.dumps({'files':len(names),'bytes':archive.stat().st_size,'sha256':sha.hexdigest()}))
