$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech
$domainAudioRoot = Join-Path $PSScriptRoot '../game/assets/audio/domains'
New-Item -ItemType Directory -Path $domainAudioRoot -Force | Out-Null
$domainSpeaker = New-Object System.Speech.Synthesis.SpeechSynthesizer
$domainVoice = $domainSpeaker.GetInstalledVoices() | Where-Object { $_.VoiceInfo.Culture.Name -eq 'pt-BR' } | Select-Object -First 1
if (-not $domainVoice) { throw 'Instale uma voz pt-BR do Windows para regenerar as falas.' }
$domainSpeaker.SelectVoice($domainVoice.VoiceInfo.Name)
$domainSpeaker.Rate = -1
try {
    $domainSpeaker.SetOutputToWaveFile((Join-Path $domainAudioRoot 'void.wav'))
    $domainSpeaker.Speak('Expansão de domínio! Vazio Infinito!')
    $domainSpeaker.SetOutputToNull()
    $domainSpeaker.SetOutputToWaveFile((Join-Path $domainAudioRoot 'shrine.wav'))
    $domainSpeaker.Speak('Expansão de domínio! Santuário Malevolente!')
    $domainSpeaker.SetOutputToNull()
} finally { $domainSpeaker.Dispose() }
Write-Output 'Falas originais sintetizadas em português.'
