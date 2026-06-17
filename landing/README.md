# Landing de Paso

Landing de una sola página para **Paso**, el juego educativo de lógica (Godot).
Astro + CSS propio. Cero React, cero dependencias 3D. Mobile-first.

## Correr en local

```bash
cd landing
npm install
npm run dev        # http://localhost:4321
npm run build      # genera dist/  (esto es lo que subís a Hostinger)
npm run preview    # sirve dist/ para revisar el build final
```

Subís a Hostinger el **contenido de `dist/`** (no la carpeta `landing/` entera).

## Qué tenés que completar (3 cosas)

### 1. Las dos URLs de los botones
Están como constantes **bien arriba** de `src/pages/index.astro`:

```js
const URL_JUGAR    = "/jugar";                 // ruta del juego web
const URL_DESCARGA = "/descargas/paso.exe";    // el .exe de Windows
```

- El **.exe**: poné el binario en `public/descargas/paso.exe` (queda en `dist/descargas/paso.exe`).
- El **juego web**: ver punto 3.

### 2. Las capturas
Van en `public/shots/`. La landing usa estas (sacalas de la carpeta `shots/` del repo del juego):

- `shot_inicio.png` — la cara del juego (hero / sección "qué es")
- `shot_como.png` — la mecánica (entradas / mano / memoria / salidas)
- `shot_git_nube.png` — local ↔ nube
- `shot_git_consola.png` — el sandbox de git en acción (ejercicio 6/10)
- `shot_git_push.png` — el flujo push

Si falta alguna, la landing igual carga (la imagen queda con su marco vacío); regenerá con `shot.gd` del repo del juego.

### 3. El juego web (`/jugar`)
Decisión tomada: el juego va en **su propia ruta** (`/jugar`), no embebido en el hero,
así la landing queda liviana y el juego **no carga hasta que hacen clic en "Jugar"**.

`src/pages/jugar.astro` ya monta el build del juego en un `<iframe>` que apunta a `/juego/`.
Poné el export web de Godot en `public/juego/` (que tenga su `index.html` adentro):

```
public/juego/index.html
public/juego/index.wasm
public/juego/index.pck
...
```

## ⚠️ Gotcha del build web de Godot 4 (COOP/COEP)

El export web de Godot 4 **no levanta embebido** sin *cross-origin isolation*, salvo
que lo hayas exportado con **threads OFF**. Dos caminos:

- **Recomendado y simple:** exportá el juego con **threads OFF** (en el preset Web de Godot).
  Así no necesitás tocar ningún header y `/jugar` funciona directo. Borrá `public/juego/.htaccess`.
- **Si exportaste con threads ON:** dejá el archivo `public/juego/.htaccess` (ya incluido).
  Setea los headers `Cross-Origin-Opener-Policy` y `Cross-Origin-Embedder-Policy` **solo en
  la carpeta del juego** (no en todo el sitio, para no romper las Google Fonts de la landing).

> Por qué scopeado a `/juego/`: si ponés COEP `require-corp` en todo el sitio, el navegador
> bloquea recursos cross-origin (las Google Fonts). Por eso los headers van solo donde corre el juego.

## Estructura

```
landing/
├─ astro.config.mjs
├─ package.json
├─ public/
│  ├─ favicon.svg
│  ├─ shots/            ← pegá acá las capturas (ver arriba)
│  ├─ descargas/        ← pegá acá paso.exe
│  └─ juego/            ← pegá acá el export web de Godot (+ .htaccess si threads ON)
└─ src/
   ├─ layouts/Base.astro      (shell, fuentes, scroll-reveal + parallax)
   ├─ styles/global.css       (paleta del juego, tipografía, botones, secciones)
   ├─ components/
   │  ├─ Robot.astro          (el robot de marca en SVG inline + animación CSS)
   │  ├─ Boton.astro          (CTA reusable: primario teal / secundario outline)
   │  └─ Icono.astro          (íconos SVG de los 3 bullets)
   └─ pages/
      ├─ index.astro          (la landing)
      └─ jugar.astro          (el juego web, ruta aparte)
```

## Notas de diseño

- Paleta **idéntica** al juego (`src/styles/global.css`, variables `--*`). No hay colores fuera de gama.
- Tipografía: **Fraunces** (serif humanista, para títulos) + **Inter** (sans, cuerpo), vía Google Fonts.
  Para cambiar la serif: una línea en `global.css` (`--serif`).
- Animaciones (flote/parpadeo/antena del robot, reveal al scroll, parallax leve) respetan
  `prefers-reduced-motion`: si está activo, se muestran sin animar.
- Sin tracking, sin newsletter, sin redes.
