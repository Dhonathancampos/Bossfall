# Regenera todos os modelos 3D do jogo a partir dos scripts.
#
#     powershell -File tools/models/build_all.ps1
#
# Modelo é código: os .glb em assets/models/ são artefatos deste build, nunca
# editados à mão. common.py é biblioteca, não modelo — por isso é pulado.

$ErrorActionPreference = "Stop"
$blender = "C:\Blender\blender-4.2.14-windows-x64\blender.exe"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not (Test-Path $blender)) {
    Write-Error "Blender nao encontrado em $blender"
}

$failed = 0
Get-ChildItem (Join-Path $here "*.py") | Where-Object { $_.Name -ne "common.py" } | ForEach-Object {
    Write-Host ">> $($_.Name)"
    # Via cmd para o stderr do Blender (avisos inofensivos de TBBmalloc) nao
    # virar ErrorRecord no PowerShell 5.1.
    $out = cmd /c "`"$blender`" --background --python `"$($_.FullName)`" 2>nul"
    $out | Select-String "EXPORTED|Error|Traceback" | ForEach-Object { Write-Host "   $_" }
    if ($LASTEXITCODE -ne 0 -or -not ($out -match "EXPORTED")) {
        Write-Host "   FALHOU ($LASTEXITCODE)" -ForegroundColor Red
        $script:failed++
    }
}

if ($failed -gt 0) { exit 1 }
Write-Host "Todos os modelos gerados." -ForegroundColor Green
