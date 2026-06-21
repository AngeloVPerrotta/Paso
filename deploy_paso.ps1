# ============================================================
#  deploy_paso.ps1  —  Build & deploy helper para Paso
#  Encadena: export .exe (Godot) -> build web (Astro) -> zip del dist
#  -> (opcional) commit + push.
#
#  Uso:  clic derecho -> "Ejecutar con PowerShell"
#        o desde terminal:  powershell -ExecutionPolicy Bypass -File deploy_paso.ps1
# ============================================================

# --- CONFIG: ajustá estas rutas si cambian ---
$RAIZ      = "C:\Users\Usuario\Desktop\paso"
$GODOT     = "C:\Users\Usuario\Desktop\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe"
$PRESET    = "Windows Desktop"                       # nombre EXACTO del preset en Godot
$EXE_OUT   = "$RAIZ\landing\public\descargas\paso.exe"
$LANDING   = "$RAIZ\landing"
$DIST      = "$LANDING\dist"
$ZIP_OUT   = "$RAIZ\paso_dist.zip"                   # el zip listo para Hostinger
# ----------------------------------------------

$ErrorActionPreference = "Stop"

function Paso($txt) { Write-Host "`n=== $txt ===" -ForegroundColor Cyan }
function OK($txt)   { Write-Host "  OK  $txt" -ForegroundColor Green }
function Aviso($txt){ Write-Host "  !!  $txt" -ForegroundColor Yellow }

Set-Location $RAIZ

Write-Host ""
Write-Host "  PASO - deploy helper" -ForegroundColor White -BackgroundColor DarkCyan
Write-Host ""

# --- Preguntar qué hacer ---
$hacerExe = (Read-Host "Exportar el .exe nuevo desde Godot? (s/n)").ToLower() -eq "s"
$hacerWeb = (Read-Host "Rebuildear la web y generar el zip? (s/n)").ToLower() -eq "s"

# =========================================================
# 1) EXPORT DEL .EXE
# =========================================================
if ($hacerExe) {
  Paso "Exportando el .exe desde Godot"
  if (-not (Test-Path $GODOT)) {
    Aviso "No encontre Godot en: $GODOT"
    Aviso "Ajusta la variable \$GODOT arriba del script."
    Read-Host "Enter para salir"; exit 1
  }
  # Asegurar carpeta de salida
  $exeDir = Split-Path $EXE_OUT
  if (-not (Test-Path $exeDir)) { New-Item -ItemType Directory -Force -Path $exeDir | Out-Null }

  & $GODOT --headless --export-release $PRESET $EXE_OUT
  if (Test-Path $EXE_OUT) {
    $mb = [math]::Round((Get-Item $EXE_OUT).Length / 1MB, 1)
    OK ".exe generado ($mb MB) en $EXE_OUT"
    Aviso "Recorda probarlo con doble clic (jugar un nivel alto para confirmar el avance)."
  } else {
    Aviso "El .exe NO se genero. Revisa el nombre del preset (\$PRESET = '$PRESET')."
    Read-Host "Enter para salir"; exit 1
  }
}

# =========================================================
# 2) BUILD WEB + ZIP
# =========================================================
if ($hacerWeb) {
  Paso "Build de la web (Astro)"
  Set-Location $LANDING
  npm run build
  if (-not (Test-Path $DIST)) {
    Aviso "No se genero dist/. Revisa errores de npm run build arriba."
    Read-Host "Enter para salir"; exit 1
  }
  OK "dist/ generado"

  Paso "Generando el zip para Hostinger"
  if (Test-Path $ZIP_OUT) { Remove-Item $ZIP_OUT -Force }
  # Comprime el CONTENIDO de dist/ (no la carpeta dist envolviendolo)
  Compress-Archive -Path "$DIST\*" -DestinationPath $ZIP_OUT
  OK "zip listo: $ZIP_OUT"
  Set-Location $RAIZ
}

# =========================================================
# 3) COMMIT + PUSH (opcional, con confirmacion)
# =========================================================
Paso "Git"
Set-Location $RAIZ
Write-Host "Estado actual:" -ForegroundColor Gray
git status --short

$hacerCommit = (Read-Host "`nQueres commitear y pushear? (s/n)").ToLower() -eq "s"
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
  Aviso "Salteo el commit (commiteas a mano cuando quieras)."
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
  Write-Host "  -> Confirma que index.html quede en la raiz de public_html/." -ForegroundColor Gray
}
Write-Host ""
Read-Host "Enter para cerrar"
