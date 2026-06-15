# Builds de Paso

Hay dos presets en `export_presets.cfg`:

- **Windows Desktop** → `builds/windows/paso.exe` (un único .exe doble-clickable; el `.pck` va embebido).
- **Web** (HTML5) → `builds/web/index.html` (para itch.io / un link más adelante).

`builds/` está gitignoreado (no se commitea el binario).

## Requisito por única vez: export templates

Exportar necesita los *export templates* de Godot **4.6.3**. Si nunca los bajaste,
el export falla con *"No se encontró una plantilla de exportación"*. Para instalarlos:

> Abrí Godot → **Editor → Manage Export Templates… → Download and Install**

(Es una sola vez por versión de Godot.)

## Exportar (sin abrir el editor)

En PowerShell, con el `_console.exe` de Godot:

```powershell
$g = 'C:\Users\Usuario\Desktop\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe'
& $g --headless --path . --import                                  # 1ra vez / tras cambios
& $g --headless --path . --export-release "Windows Desktop"
& $g --headless --path . --export-release "Web"
```

## Cómo correr cada uno

- **Windows**: doble-click en `builds\windows\paso.exe`. Listo.
- **Web**: **no** abre con doble-click (los navegadores no cargan el juego por `file://`).
  Hay que servirlo por HTTP. Para probar local:

  ```powershell
  cd builds\web
  python -m http.server 8000
  ```

  y abrí <http://localhost:8000>. Para publicarlo, subí el contenido de `builds\web\`
  a **itch.io** (HTML5 game), que ya lo sirve por HTTP.
