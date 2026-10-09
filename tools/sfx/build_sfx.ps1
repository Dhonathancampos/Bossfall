# Regenera todos os efeitos sonoros do jogo a partir do script de síntese.
#
#     powershell -File tools/sfx/build_sfx.ps1
#
# Asset é código: os .wav em assets/sfx/ são artefatos deste build, nunca
# gravados ou editados à mão.

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

python (Join-Path $here "generate.py")
if ($LASTEXITCODE -ne 0) {
    Write-Error "A geracao de SFX falhou ($LASTEXITCODE)"
}
Write-Host "Todos os sons gerados." -ForegroundColor Green
