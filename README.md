# Paso

Un juego de lógica 2D donde cada nivel se resuelve armando un programita, y un robot
lo ejecuta paso a paso delante tuyo. La idea: que programar se entienda jugando.

🎮 **Jugalo en el navegador:** https://paso.angeloperrotta.online

## Qué es

En Paso los puzzles *son* programas. Cada nivel te da un objetivo en lenguaje claro
(agarrá estos tres números y devolvelos al revés, sacá los ceros, ese tipo de cosa) y
un set chico de instrucciones para lograrlo. Apilás las instrucciones, le das a *Probar*
y mirás al robot hacer exactamente lo que le dijiste: agarra un valor, lo guarda en
memoria, lo suelta a la salida. Si lo que sale coincide con lo pedido, lo resolviste.
Ahí arranca el verdadero desafío: resolverlo con **menos instrucciones y menos pasos**.

Lo empecé por algo que veo seguido como ayudante de cátedra: meterse en programación
cuesta, y casi siempre se enseña de una forma bastante seca. Encima se suele aprender en
un lenguaje suelto y permisivo, y después cuesta el salto a uno estricto y tipado. Quería
un juego que haga *click* con la lógica de abajo, y que dé ganas de seguir jugando.

## Cómo se juega

El objetivo se lee como una oración, no como una spec. Tenés solo las instrucciones que
el nivel necesita, y el set crece a medida que se complica. El robot corre tu programa
paso a paso y muestra todo: qué tiene en la mano, qué hay en memoria, qué va saliendo.
Cada solución se puntúa por instrucciones usadas y pasos corridos, y ganarle a tu propio
récord es donde está la mayor parte de la diversión.

Las instrucciones se leen en español (`agarrá`, `guardá`, `soltá`, etc.), pero los valores
tienen tipo y la memoria se declara como en un lenguaje real. Hay un panel **"Ver en C / C#"**
que traduce tu solución a código comentado, para tender el puente hacia los lenguajes
tipados (los dos tracks: C y C#). También hay un módulo **"Aprendé Git"** con una consola
que simula el flujo real (`init → add → commit → push`) con carpetas local ↔ nube.

## Stack

- **Juego:** Godot 4.6 + GDScript, sin dependencias externas. La simulación es lógica pura
  (`interpreter.gd`: estado → estado) y la interfaz solo dibuja snapshots. Los niveles son
  datos (`niveles/*.json`).
- **Landing:** [Astro](https://astro.build) + CSS propio (sin React), en `landing/`.

## Cómo correrlo (juego)

Cloná el repo, abrí la carpeta en **Godot 4.6** y dale a *Play*.

```bash
git clone https://github.com/AngeloVPerrotta/Paso.git
```

Para correr los tests headless (no necesitan ventana):

```bash
godot --headless --path . --import          # genera el caché de clases (una vez)
godot --headless --path . --script test_paso.gd
```

Cómo exportar los builds de Windows y Web está documentado en [`BUILD.md`](BUILD.md).

## Cómo correr la landing

```bash
cd landing
npm install
npm run dev      # http://localhost:4321
npm run build    # genera dist/
```

## Estructura

```
paso/
├─ interpreter.gd      # núcleo: lógica pura estado → estado (sin UI)
├─ validador.gd        # validación y scoring por encima del intérprete
├─ main.gd             # UI: arma el escenario y dibuja snapshots del estado
├─ niveles/*.json      # los niveles son datos; orden.json + orden_avanzado.json
├─ csharp.gd / c.gd    # generadores del panel "Ver en C / C#"
├─ git_mini.gd         # modelo puro que simula git (para el módulo "Aprendé Git")
├─ tema.gd / ui_kit.gd # paleta única y widgets compartidos
├─ test_*.gd           # suite headless (corre sin ventana)
└─ landing/            # sitio web (Astro)
```

## Estado

Temprano pero jugable. Hay 12 niveles base hechos a mano que recorren secuencia, memoria,
aritmética, bucles y condicionales, más o menos en ese orden, y 5 niveles avanzados en el
track C#. El loop completo está: armar un programa, correrlo, validarlo y después tratar de
achicarlo. Los primeros niveles tienen tutorial guiado.

## Sobre mí

Soy Angelo, estudiante de Ingeniería en Sistemas en Buenos Aires, construyendo cosas en el
cruce entre programación y educación. Paso es el proyecto que más estoy disfrutando ahora
mismo. Es un trabajo en progreso: si lo probás, me encantaría saber qué te pareció.
