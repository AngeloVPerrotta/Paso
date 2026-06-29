# ============================================================
#  deploy_paso.ps1  —  Build & deploy helper para Paso  (v2)
#  Encadena: export .exe (Godot) -> export build WEB (Godot) ->
#  build web Astro -> zip del dist -> (opcional) commit + push.
#
#  Uso:  powershell -ExecutionPolicy Bypass -File deploy_paso.ps1
# ============================================================

# --- CONFIG: ajustá estas rutas/nombres si cambian ---
$RAIZ        = "C:\Users\Usuario\Desktop\paso"
$GODOT       = "C:\Users\Usuario\Desktop\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe"
$PRESET_EXE  = "Windows Desktop"   # nombre EXACTO del preset de escritorio en Godot
$PRESET_WEB  = "Web"               # nombre EXACTO del preset web en Godot (ojo: puede ser "HTML5")
$EXE_OUT     = "$RAIZ\landing\public\descargas\paso.exe"
$WEB_OUT     = "$RAIZ\landing\public\juego\index.html"   # destino del build web
$LANDING     = "$RAIZ\landing"
$DIST        = "$LANDING\dist"
$ZIP_OUT     = "$RAIZ\paso_dist.zip"
# ----------------------------------------------

$ErrorActionPreference = "Stop"

function Paso($txt) { Write-Host "`n=== $txt ===" -ForegroundColor Cyan }
function OK($txt)   { Write-Host "  OK  $txt" -ForegroundColor Green }
function Aviso($txt){ Write-Host "  !!  $txt" -ForegroundColor Yellow }

Set-Location $RAIZ

Write-Host ""
Write-Host "  PASO - deploy helper (v2)" -ForegroundColor White -BackgroundColor DarkCyan
Write-Host ""

# --- Preguntar qué hacer ---
$hacerExe = (Read-Host "Exportar el .exe (escritorio) desde Godot? (s/n)").ToLower() -match '^(s|y)$'
$hacerWebGodot = (Read-Host "Exportar el build WEB del juego desde Godot? (s/n)").ToLower() -match '^(s|y)$'
$hacerWeb = (Read-Host "Rebuildear la landing (Astro) y generar el zip? (s/n)").ToLower() -match '^(s|y)$'

# =========================================================
# 1) EXPORT DEL .EXE (escritorio)
# =========================================================
if ($hacerExe) {
  Paso "Exportando el .exe (escritorio) desde Godot"
  if (-not (Test-Path $GODOT)) {
    Aviso "No encontre Godot en: $GODOT"; Read-Host "Enter para salir"; exit 1
  }
  $exeDir = Split-Path $EXE_OUT
  if (-not (Test-Path $exeDir)) { New-Item -ItemType Directory -Force -Path $exeDir | Out-Null }
  & $GODOT --headless --export-release $PRESET_EXE $EXE_OUT
  if (Test-Path $EXE_OUT) {
    $mb = [math]::Round((Get-Item $EXE_OUT).Length / 1MB, 1)
    OK ".exe generado ($mb MB)"
    Aviso "Probalo con doble clic (jugar un nivel alto)."
  } else {
    Aviso "El .exe NO se genero. Revisa el nombre del preset (\$PRESET_EXE = '$PRESET_EXE')."
    Read-Host "Enter para salir"; exit 1
  }
}

# =========================================================
# 2) EXPORT DEL BUILD WEB (juego) desde Godot
# =========================================================
if ($hacerWebGodot) {
  Paso "Exportando el build WEB del juego desde Godot"
  $webDir = Split-Path $WEB_OUT
  if (-not (Test-Path $webDir)) { New-Item -ItemType Directory -Force -Path $webDir | Out-Null }
  & $GODOT --headless --export-release $PRESET_WEB $WEB_OUT
  if (Test-Path $WEB_OUT) {
    OK "build web generado en $webDir"
    Aviso "El juego web usa threads: Hostinger necesita el .htaccess con COOP/COEP (ver README)."
  } else {
    Aviso "El build web NO se genero. Revisa el nombre del preset (\$PRESET_WEB = '$PRESET_WEB')."
    Aviso "En Godot, Proyecto -> Exportar, mira el nombre EXACTO del preset web (puede ser 'HTML5')."
    Read-Host "Enter para salir"; exit 1
  }
}

# =========================================================
# 3) BUILD LANDING (Astro) + ZIP
# =========================================================
if ($hacerWeb) {
  Paso "Build de la landing (Astro)"
  Set-Location $LANDING
  npm run build
  if (-not (Test-Path $DIST)) {
    Aviso "No se genero dist/. Revisa errores de npm run build arriba."
    Read-Host "Enter para salir"; exit 1
  }
  OK "dist/ generado"

  Paso "Generando el zip para Hostinger"
  if (Test-Path $ZIP_OUT) { Remove-Item $ZIP_OUT -Force }
  Compress-Archive -Path "$DIST\*" -DestinationPath $ZIP_OUT
  OK "zip listo: $ZIP_OUT"
  Set-Location $RAIZ
}

# =========================================================
# 4) COMMIT + PUSH (opcional)
# =========================================================
Paso "Git"
Set-Location $RAIZ
Write-Host "Estado actual:" -ForegroundColor Gray
git status --short

$hacerCommit = (Read-Host "`nQueres commitear y pushear? (s/n)").ToLower() -match '^(s|y)$'
if ($hacerCommit) {
  $msg = Read-Host "Nombre del commit"
  if ([string]::IsNullOrWhiteSpace($msg)) {
    Aviso "Mensaje vacio, cancelo el commit."
  } else {
    git add -A
    git commit -m "$msg"
    git push
    OK "Commit y push hechos."
  }
} else {
  Aviso "Salteo el commit (commiteas a mano)."
}

# =========================================================
# CIERRE
# =========================================================
Write-Host ""
Paso "Listo"
if ($hacerWeb) {
  Write-Host "  Subi a Hostinger: " -NoNewline
  Write-Host "$ZIP_OUT" -ForegroundColor White
  Write-Host "  -> File Manager -> public_html/ -> borra lo viejo -> subi el zip -> Extraer." -ForegroundColor Gray
  Write-Host "  -> Confirma que index.html quede en la raiz y que el .htaccess (COOP/COEP) este presente." -ForegroundColor Gray
}
Write-Host ""
Read-Host "Enter para cerrar"
