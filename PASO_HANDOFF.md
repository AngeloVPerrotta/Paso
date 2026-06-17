# Paso — Handoff / Contexto del proyecto

> Documento para continuar el proyecto en un chat nuevo. Leélo entero antes de seguir.

## Qué es Paso
Juego 2D educativo de lógica de programación en **Godot 4 / GDScript**, estilo Zachtronics / Human Resource Machine. El jugador resuelve puzzles **apilando instrucciones** en un lenguaje visual mínimo; un robot las ejecuta paso a paso. La gracia: enseñar a pensar como un programa, sin escribir código, y tender el puente hacia los lenguajes tipados.

- Repo: https://github.com/AngeloVPerrotta/Paso.git
- Local (Windows): `C:\Users\Usuario\Desktop\paso`
- Godot: `C:\Users\Usuario\Desktop\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe`

## Quién es Angelo y qué busca
Estudiante de 3º de Ingeniería en Sistemas + ayudante (Álgebra/Cálculo) en UAI Buenos Aires, dev de agentes en Botmaker. Habla en rioplatense, directo, le molesta el output "con olor a IA". Objetivos del juego: (1) que programar sea divertido para los de primer año, (2) tender el puente C → C# (lo que ven en sus materias), (3) impresionar a sus profes ("qué laburazo"), (4) portfolio, (5) a futuro Steam / recurso educativo.

## El modelo de la máquina (el lenguaje)
Un solo agente que sostiene UN valor ("la mano"); slots de memoria; colas de entrada y salida.
Instrucciones (en castellano amable): **agarrá** (toma el próximo de la entrada → la mano), **soltá** (la mano → salida), **guardá** (la mano → memoria), **recuperá** (memoria → la mano), **sumá / restá** (con una memoria), **saltá a** (etiqueta), **si es cero saltá a**, **ETIQUETA**.
Regla del mundo: `agarrá` con la entrada vacía termina el nivel. Puntaje doble: minimizar **instrucciones** Y **pasos** (el meta-loop de optimización). Limitación conocida: no hay carga de constante → hace transformaciones por elemento (map/filter), no agregación (sumar-todo).

## Principio de arquitectura (NUNCA romper)
- **El intérprete es lógica pura estado→estado** (`interpreter.gd`, clase Estado, `ejecutar_paso`, `correr`).
- **La UI solo dibuja snapshots del estado.**
- **Los niveles son datos** (JSON).
- Tests headless en GDScript, **siempre en verde** (hoy 10/10).
- Los módulos de "presentación" (panel de código, Aprendé Git, etc.) **no tocan** intérprete/validador/niveles.

## Paleta (propia, NO la de Claude)
Centralizada en `tema.gd`:
Fondo `#F5F2EA` · Texto `#232220` · Primario/petróleo `#1C7C74` · Éxito/verde `#6BA368` · Cálido/ámbar `#E3A23A`.
(Se reskineó a propósito para que NO parezca Claude.)

## Mapa de archivos
- `interpreter.gd` — intérprete puro.
- `niveles.gd` — carga de niveles, `orden_track()`, `avanzados()`, `listar()`.
- `validador.gd` — validación de soluciones.
- `puntajes.gd` — progreso en `user://`, `track()` / `set_track()`.
- `soluciones.gd` — soluciones de referencia (para tests/capturas).
- `main.gd` — toda la UI (editor, selector, panel de código, pantallas, inicio).
- `robot.gd` — robot dibujado por código (la marca).
- `tema.gd` — paleta/tokens de color.
- `sfx.gd` — audio sintetizado (placeholder, reemplazable).
- `csharp.gd` — generador de C# (panel "Ver en C#").
- `c.gd` — generador de C (panel "Ver en C").
- `git_explica.gd` — módulo "Aprendé Git", Capa 1 (explicador visual).
- `git_mini.gd` — modelo PURO del sandbox de git (Capa 2): working dir/staging/commits/remoto, estado→estado, testeable headless. NO toca el juego.
- `git_sandbox.gd` — UI de la Capa 2: carpetas visibles local↔nube + consola que parsea git real (init/status/add/commit/push/pull/log/clone) + ejercicios guiados.
- `ui_kit.gd` — helpers de widgets compartidos (`UiKit.label`/`UiKit.boton`, estáticos) que usan Capa 1 y Capa 2.
- `shot.gd` — tour de capturas → carpeta `shots/` (sobrescribe en cada corrida).
- Tests: `test_niveles`, `test_orden`, `test_ui`, `test_selector`, `test_editor`, `test_paso`, `test_csharp`, `test_edge_cases`, `test_git` (modelo), `test_git_ui` (sandbox).
- `niveles/*.json` + `orden.json` (12 base) + `orden_avanzado.json` (5 avanzados).
- `export_presets.cfg` (Windows + Web), `BUILD.md`.
- `CLAUDE.md` — convenciones para Claude Code (lo lee solo).

## Flujo de trabajo (importante)
- Angelo corre Godot y **Claude Code** en su máquina. El Claude del chat es **planner/arquitecto**: escribe briefs para CC → Angelo los pega en Claude Code → Angelo pega los resultados/capturas de vuelta → Claude revisa y dirige el próximo paso.
- **CC NO commitea.** Al terminar cada bloque/tanda, CC **resume en lenguaje claro qué tocó y frena**; Angelo revisa y **commitea a mano** (y commitea cada tanda antes de correr la próxima).
- `shot.gd` captura todo el tour en `shots/`; Angelo manda esas capturas.
- Mantener arquitectura pura + tests en verde.
- Briefs cortos y concretos. Decisiones técnicas: que Claude las tome y avance, no preguntar por cada detalle.

## Qué está hecho (DONE)
- Núcleo: intérprete puro + validador + cargador + etiquetas + puntaje doble.
- **12 niveles base** (la escalera: eco → invertir_par → duplicar → invertir_trio → sumar_par → restar_par → eco_infinito → duplicar_cola → sumar_pares → filtrar_ceros → cortar_en_cero → pares_iguales). Mapea al programa de "Intro a los Algoritmos" (secuencia → memoria → aritmética → loops → condicionales).
- Editor interactivo, selector de niveles, progreso en `user://`.
- **Reskin a paleta propia** (teal/arena/ámbar vía `tema.gd`), ya NO parece Claude.
- Robot (dibujado por código), animación con jugo (los valores vuelan a las celdas), sfx placeholder, banner de éxito compacto (no tapa el programa).
- **Tutorial interactivo** (nivel 1: spotlight que deja pasar el clic al botón real, avanza con la acción del jugador), tooltips en instrucciones + zonas de estado, botón **"¿Cómo se juega?"** (repasable), pantalla **"Cómo funciona la máquina"** (mini-demo auto) + **modo libre**.
- Pantalla de inicio (Paso + tagline + Jugar + Continuar + Cómo funciona la máquina + footer: Acerca de / Reportar un bug → issues de GitHub / Reiniciar progreso).
- **Panel "Ver en código"**: traduce el programa del jugador a código **idiomático y comentado** — C# (`csharp.gd`) y C (`c.gd`), con while/if (no goto), tipado, y comentarios (objetivo del método + loop + condición). Botón/título según el track.
- **Tracks C / C#**: elección en el inicio "Empezá en C · fundamentos" / "Seguí en C# · avanzado". Track C = 12 base, código en C. Track C# = 12 + **5 avanzados nuevos** (sumar_trio, restar_trio, invertir_cuarteto [3 memorias], filtrar_duplicar [continue], pares_iguales_doble [branch]) = 17, código en C#. Track guardado en `puntajes.gd`.
- **Export**: .exe de Windows (doble click) + Web/HTML5, sin archivos de dev; templates instalados; builds limpios.
- **UX**: Reportar un bug (issues de GitHub), Reiniciar progreso (borra `user://` + flags de primera vez), Acerca de.
- **Módulo "Aprendé Git" — Capa 1** (`git_explica.gd`): explicador visual guiado, 8 pasos (qué es un repo / local↔nube [servidor, NO satélite] / flujo animado add→commit→push→pull→clone con el comando al lado / resumen de comandos), navegable, en la paleta + el robot.
- **Módulo "Aprendé Git" — Capa 2** (`git_sandbox.gd` + modelo puro `git_mini.gd`): sandbox interactivo. Se ven las carpetas/archivos de "tu PC" (color por estado: sin seguir/modificado/preparado/limpio) y el remoto en "la nube"; consola que parsea git REAL (init/status/add/commit/push/pull/log/clone) y mueve el estado; toolbar para editar/crear archivos y simular cambios en la nube; 10 ejercicios guiados con el robot. `git_mini` rechaza el push non-fast-forward (enseña por qué hay que pull-ear antes). Testeado headless: `test_git` (modelo) + `test_git_ui` (recorrido de ejercicios).
  - *Ojo historial*: la Capa 2 se commiteó dentro de `3a0e30f`, mal rotulado como "Capa 1"; ese commit incluía toda la Capa 2.

## Por dónde seguimos (ROADMAP)
**Hecho — Módulo Git, Capa 2** (el build más grande): sandbox dentro de "Aprendé Git" con carpetas visibles + consola que simula git. (Brief original abajo, ya implementado; el QA adversarial posterior pulió: push non-fast-forward, parseo de `-m`/`--message`, pasos guiados status/log, baselines relativos en ejercicios, etc.)

**Inmediato — Landing en Hostinger**: página marketinera en la paleta del juego + el robot de marca, pitch, CTAs, capturas, "Jugar en el navegador" (build web) + "Descargar (.exe)". (Stack de Angelo: Astro/React.) Gotcha del web de Godot 4: exportar con threads OFF, o headers COOP/COEP por `.htaccess`.

**Diferido (después de feedback)**: branch/merge en la consola de git (Capa 2.5); mecánicas específicas de C# (puzzles de tipos) si alguna vez; **mejorar la intuitividad del "cómo se juega"** — Angelo siente que el core no es del todo intuitivo para alguien que recién arranca; es la prioridad real a clavar cuando lo muestre, posponible pero importante.

**Nota estratégica**: el demo + el panel de C# están COMPLETOS y buenos. La recomendación parada de Claude fue **mostrarlo/shipearlo** (itch.io o la landing de Hostinger) y juntar feedback de los contactos de videojuegos/labs, y después mostrárselo al profe Battaglia. Angelo eligió construir los módulos primero (su decisión; el módulo de git es también una pieza para mostrar lo que sabe hacer). No re-machacar con esto; ya está hablado.

## Brief listo para Claude Code — Módulo Git, Capa 2
```
Módulo Git — Capa 2 (consola + carpetas, lo interactivo). El build más grande; andá por partes. NO commitees: resumí y frená. Tests en verde, sin tocar el juego (intérprete/validador/niveles); todo en su módulo aparte.

Es un sandbox dentro de "Aprendé Git" donde se VEN las carpetas y se simula git de verdad, con la misma metáfora local↔nube de la Capa 1.

A) Modelo de estado (mini-git): working dir (archivos con estado: sin seguir / modificado / preparado), staging, historial de commits local, y el remoto (lo pusheado). Esto es lo que tiene que ser correcto.

B) Vista visual: carpetas/archivos dibujados del lado "tu PC", con color/ícono según estado; el remoto del lado "nube/servidor". Al correr comandos, las cosas se mueven visualmente (al staging, al historial, a la nube).

C) Consola simulada: escribís comandos reales, los parsea, actualiza el modelo y muestra salida tipo git. Flujo central: git init, git status, git add <archivo> / git add ., git commit -m "...", git push, git pull, git log, git clone. Comando desconocido o mal usado → error amable. (branch/merge NO en esta versión; agregan mucho estado, quedan para después.)

D) Ejercicios guiados: una secuencia que enseña el flujo —iniciá el repo, preparás cambios, primer commit, subilo a la nube, hacés un cambio, lo subís, lo traés con pull— con detección de cada paso completado y feedback. El robot acompaña.

Orden: modelo + consola con init/status/add/commit primero; después push/pull/remoto; después los ejercicios. Tests en verde. Al terminar resumime qué tocaste y frená.
```
