param(
    [string]$Dotnet = 'dotnet',
    [string]$Vpk = 'vpk',
    [string]$Version = '0.4.1',
    [string]$Output = (Join-Path $PSScriptRoot 'Releases')
)
$ErrorActionPreference = 'Stop'
$project = Join-Path $PSScriptRoot 'VOICENEW.csproj'
$publish = Join-Path $PSScriptRoot 'publish'
& $Dotnet publish $project -c Release -r win-x64 --self-contained -p:Version=$Version -o $publish
if ($LASTEXITCODE) { throw 'Falha ao compilar o iniciador.' }
& $Vpk pack --packId CJCarrao.VOICENEW --packVersion $Version --packDir $publish --mainExe VOICENEW.exe --runtime win-x64 --packTitle VOICENEW --packAuthors CJ-Carrao --outputDir $Output
if ($LASTEXITCODE) { throw 'Falha ao empacotar o iniciador.' }
Write-Output "Pacotes criados em $Output. Publique também game-update.json e os arquivos de integridade; consulte LEIA-ME.md."
