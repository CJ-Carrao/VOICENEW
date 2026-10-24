$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$engine = Join-Path $projectRoot 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
$pythonCandidates = @(
    (Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'),
    'python'
)
$pythonRuntime = $pythonCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $pythonRuntime) { $pythonRuntime = 'python' }
New-Item -ItemType Directory -Path (Join-Path $projectRoot 'build') -Force | Out-Null
& $engine --headless --path (Join-Path $projectRoot 'game') --editor --import
if ($LASTEXITCODE -ne 0) { throw 'Falha ao importar o projeto.' }
& $engine --headless --path (Join-Path $projectRoot 'game') --export-pack 'Windows Desktop' (Join-Path $projectRoot 'build/LAVOICE-Lab-Corrigido.pck')
if ($LASTEXITCODE -ne 0) { throw 'Falha ao exportar o pacote.' }
& $pythonRuntime (Join-Path $projectRoot 'tools/package_game.py') --pack (Join-Path $projectRoot 'build/LAVOICE-Lab-Corrigido.pck') --output (Join-Path $projectRoot 'build/LAVOICE-Lab-Corrigido.exe')
if ($LASTEXITCODE -ne 0) { throw 'Falha ao montar o executavel.' }
foreach ($folder in @('voice', 'licenses')) {
    $target = Join-Path $projectRoot "build/$folder"
    if (-not (Test-Path -LiteralPath $target)) {
        Copy-Item -LiteralPath (Join-Path $projectRoot "game/$folder") -Destination $target -Recurse
    }
}
Get-ChildItem -LiteralPath (Join-Path $projectRoot 'tools/runtime') -File -Filter '*.dll' | Copy-Item -Destination (Join-Path $projectRoot 'build') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'tools/runtime/x86_64') -Destination (Join-Path $projectRoot 'build') -Recurse -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'game/CREDITOS.txt') -Destination (Join-Path $projectRoot 'build/CREDITOS.txt') -Force
Write-Host "Pronto: $projectRoot\build\LAVOICE-Lab-Corrigido.exe"
