$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$engine = Join-Path $projectRoot 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
$pythonCandidates = @(
    (Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'),
    'python'
)
$pythonRuntime = $pythonCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $pythonRuntime) { $pythonRuntime = 'python' }
$buildRoot = Join-Path $projectRoot 'build/H4-Lab'
New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null
& $engine --headless --path (Join-Path $projectRoot 'game') --editor --import
if ($LASTEXITCODE -ne 0) { throw 'Falha ao importar o projeto.' }
& $engine --headless --path (Join-Path $projectRoot 'game') --export-pack 'Windows Desktop' (Join-Path $projectRoot 'build/LAVOICE-Lab-H4.pck')
if ($LASTEXITCODE -ne 0) { throw 'Falha ao exportar o pacote.' }
& $pythonRuntime (Join-Path $projectRoot 'tools/package_game.py') --pack (Join-Path $projectRoot 'build/LAVOICE-Lab-H4.pck') --output (Join-Path $buildRoot 'LAVOICE-Lab-H4-v26.exe')
if ($LASTEXITCODE -ne 0) { throw 'Falha ao montar o executavel.' }
foreach ($folder in @('voice', 'licenses')) {
    $target = Join-Path $buildRoot $folder
    if (-not (Test-Path -LiteralPath $target)) {
        Copy-Item -LiteralPath (Join-Path $projectRoot "game/$folder") -Destination $target -Recurse
    }
}
Get-ChildItem -LiteralPath (Join-Path $projectRoot 'tools/runtime') -File -Filter '*.dll' | Copy-Item -Destination $buildRoot -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'tools/runtime/x86_64') -Destination $buildRoot -Recurse -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'game/CREDITOS.txt') -Destination (Join-Path $buildRoot 'CREDITOS.txt') -Force
Write-Host "Pronto: $buildRoot\LAVOICE-Lab-H4-v26.exe"
