# paso

Juego de puzzles de lógica donde resolvés cada nivel escribiendo "código" en un
lenguaje visual mínimo. Inspirado en Human Resource Machine. 2D, pixel art,
estética abstracta y minimalista. Motor: Godot 4.

## El lenguaje

Un agente sostiene UN valor por vez (la "mano"). Hay una cola de entrada, una
cola de salida y unos pocos slots de memoria. Con ~7 instrucciones ya se arma
un curriculum entero: secuencia, variables, loops y condicionales.

| Instrucción        | Qué hace                                          |
|--------------------|---------------------------------------------------|
| `TOMAR`            | Agarra el próximo valor de la entrada a la mano   |
| `SOLTAR`           | Deja el valor de la mano en la salida             |
| `COPIAR n`         | Copia el slot n a la mano                         |
| `GUARDAR n`        | Guarda la mano en el slot n                       |
| `SUMAR n`          | Suma el slot n a la mano                          |
| `RESTAR n`         | Resta el slot n a la mano                         |
| `SALTAR e`         | Salta a la etiqueta e                             |
| `SALTAR_SI_CERO e` | Salta a e solo si la mano vale 0                  |

## Reglas del mundo

- `TOMAR` con la entrada vacía termina el nivel.
- Doble score: se minimiza cantidad de instrucciones Y cantidad de pasos
  ejecutados. Ese es el loop de rejugar para optimizar (lo que hace volver al jugador).

## Arquitectura (importante, no romper esto)

La simulación está TOTALMENTE separada del render. `interpreter.gd` es pura
lógica: `estado → estado`, no toca nodos ni UI. Godot solo dibuja "fotos" del
estado en cada paso. Esto da step/undo gratis y lo hace testeable sin abrir
ninguna escena.

## Banco de puzzles (semilla)

Cada puzzle es solo: qué entra, qué tiene que salir, qué instrucciones hay.
Diseñá y resolvé cada uno EN PAPEL antes de hacerle UI.

**Beat 1 — Secuencia**
1. Eco: entran 3 valores → salen en el mismo orden. (Tutorial.)

**Beat 2 — Memoria**
2. Invertir el par: entran A, B → salen B, A. (Obliga a usar un slot.)
3. Duplicar: entra A → sale A, A.

**Beat 3 — Loops**
4. Eco infinito: entran N valores → salen todos. (`inicio: TOMAR / SOLTAR / SALTAR inicio`)
5. Duplicar la cola entera. (a diseñar)

**Beat 4 — Condicionales**
6. Cortar en el cero: sacá valores hasta toparte un 0, ahí frená.
7. Filtrar ceros: sacá solo los valores distintos de cero.
   (`inicio: TOMAR / SALTAR_SI_CERO inicio / SOLTAR / SALTAR inicio`)

Faltan ~5 para llegar a 12. Ideas: sacar el mayor, sumar de a pares, restar dos
colas, contar elementos, invertir el orden de toda la cola. Diseñalos y
traceálos a mano.

## Orden de construcción (para Claude Code)

1. Intérprete: `interpreter.gd` ya tiene el esqueleto. Que pase el test.
2. Test headless: `test_paso.gd` corre "Invertir el par" sin UI.
3. UI mínima: lista de instrucciones a la izquierda, escenario a la derecha
   (mano, slots, entrada, salida), botones Run / Step / Reset.
4. Animar el paso (`ejecutar_paso`) — ese es el jugo del género.
5. Recién después: editor de programa (agregar/ordenar instrucciones), niveles,
   validación de salida, scoring.

## Probar el intérprete

```
godot --headless --script test_paso.gd
```

Esperado: `salida: [3, 7]` y `OK: invertir el par anda`.
