# CLAUDE.md — Paso (instrucciones para Claude Code)

Paso es un juego educativo 2D en Godot 4 / GDScript (estilo Human Resource Machine): el jugador apila instrucciones en un lenguaje visual mínimo y un robot las ejecuta. Enseña lógica de programación y tiende el puente C → C#.

## Reglas de trabajo
- **NO ejecutes `git commit` ni hagas push.** Al terminar cada bloque/tanda, **resumí en lenguaje claro qué archivos tocaste y qué hace cada cambio, y frená.** Angelo revisa y commitea a mano.
- Mantené **todos los tests headless en verde** (hoy 10/10: paso, niveles, orden, ui, selector, editor, csharp, git, git_ui, edge_cases). Corré la suite antes de frenar.
- **No toques** `interpreter.gd`, `validador.gd` ni los niveles cuando el trabajo sea de "presentación" (UI, paneles, módulos nuevos).
- Las capturas van a la carpeta `shots/` (las maneja `shot.gd`, sobrescribe en cada corrida). `shots/` y `builds/` están gitignoreados.

## Arquitectura (no romper)
- **`interpreter.gd` es lógica pura estado→estado** (clase Estado, `ejecutar_paso`, `correr`). La UI solo dibuja snapshots. Los niveles son datos (JSON).
- Colores centralizados en **`tema.gd`** (paleta propia: fondo #F5F2EA, texto #232220, primario/petróleo #1C7C74, éxito #6BA368, ámbar #E3A23A). No hardcodees colores.
- Generadores de código: `csharp.gd` (C#) y `c.gd` (C). Reconocen patrones (lineal/while/continue/break/branch), tipan, comentan, y caen a goto solo si no matchea.
- Niveles: `niveles/*.json` + `orden.json` (12 base) + `orden_avanzado.json` (5 avanzados). `niveles.gd` arma el orden por track.

## Tracks
- Track C = 12 niveles base, panel de código en C.
- Track C# = 12 + 5 avanzados, panel en C#. El track se guarda en `puntajes.gd`.

## Estado y qué sigue
**Hecho**: núcleo + 12 niveles + editor + reskin propio + tutorial interactivo + "Cómo funciona la máquina" + modo libre + panel Ver en C/C# comentado + tracks C/C# + export Windows/Web + UX (reportar bug, reiniciar progreso, acerca de) + módulo "Aprendé Git" **Capa 1** (`git_explica.gd`, explicador visual) **y Capa 2** (`git_sandbox.gd` + modelo puro `git_mini.gd`: consola que simula git con carpetas visibles local↔nube, ejercicios guiados, init/status/add/commit/push/pull/log/clone, con rechazo de push non-fast-forward).

> Nota histórica: la Capa 2 (`git_mini.gd`, `git_sandbox.gd`, `test_git.gd`) se commiteó dentro de `3a0e30f`, mal rotulado como "Capa 1"; ese commit en realidad incluía toda la Capa 2.

**Siguiente**: **landing web en Hostinger** (Astro/React, paleta del juego + robot, pitch, CTAs, "Jugar en el navegador" + descargar .exe). Diferido: branch/merge en la consola de git (Capa 2.5); mejorar la intuitividad del "cómo se juega".

Helpers de widgets compartidos por los módulos Git viven en `ui_kit.gd` (`UiKit.label`/`UiKit.boton`, estáticos).
