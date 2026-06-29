# PISTAS por nivel — propuesta para revisar (MD-04, COWORK)

Angelo: acá va **una pista propuesta por nivel** (17: 12 base + 5 avanzados). Revisá,
reescribí o aprobá. **Todavía NO están cableadas al juego** — el código de la ayuda ya
está listo y muestra un texto orientador genérico (placeholder) hasta que confirmemos
estas.

## Decisión de implementación (la más limpia)
- Las pistas van en un **archivo aparte**, `pistas.json` en la raíz (un diccionario
  `id_de_nivel → pista`). **No toco `niveles/*.json`** (quedan puros: entrada/salida/par).
- `main.gd::_pista_nivel(id)` ya lee `res://pistas.json` si existe; si falta el archivo o
  el id, cae al placeholder genérico. **Enchufar = generar `pistas.json` con lo aprobado.**
- Una pista por nivel (si después querés progresivas, se evalúa; por ahora una buena).

## Tono (decisión de Angelo)
Voz del robot: **cálida, seca, sin condescendencia**. **Orienta, no resuelve**: da una idea
más evidente de cómo encarar, sin la respuesta ni los pasos exactos.

## Nombre del jugador (MD-03) — opcional
Cualquier pista puede incluir el token **`{nombre}`**: se reemplaza por el nombre guardado,
o se borra solo (junto a un `, ` previo) si no hay nombre. Ej.:
`"Tranquilo, {nombre}: ..."` → con nombre *"Tranquilo, Berenice: ..."*, sin nombre
*"Tranquilo: ..."*. Las propuestas de abajo van **sin** `{nombre}` para no atarlas al
nombre; agregalo donde te guste.

> Vocabulario del juego: **agarrá**=tomar de la entrada · **soltá**=imprimir a la salida ·
> **guardá**=copiar mano→memoria · **recuperá**=copiar memoria→mano · **sumá/restá**=opera
> la mano contra una memoria · **saltá a / etiqueta**=loop · **si es cero saltá a**=condición.

---

# Track C — 12 niveles base

### 1. `b1_eco` — Eco
- **Objetivo:** Sacá los tres valores de la entrada en el mismo orden en que entran.
- **Instrucciones:** agarrá, soltá · sin memoria
- **PISTA PROPUESTA:** Es un eco: nada cambia. Por cada número hay una sola idea —
  agarrarlo y soltarlo— y la repetís hasta vaciar la fila.

### 2. `b2_invertir_par` — Invertir el par
- **Objetivo:** Entran A y B; tienen que salir al revés: B, A.
- **Instrucciones:** agarrá, soltá, recuperá, guardá · 1 memoria
- **PISTA PROPUESTA:** Para dar vuelta dos valores necesitás soltar uno y tener el otro
  esperando. Si guardás el primero en memoria, podés sacar el segundo y recién después
  recuperar el guardado.

### 3. `duplicar` — Duplicar
- **Objetivo:** Entra un valor. Sacalo dos veces.
- **Instrucciones:** agarrá, soltá, recuperá, guardá · 1 memoria
- **PISTA PROPUESTA:** Al soltar, la mano queda vacía. Si querés volver a soltar el mismo
  número, necesitás tener una copia guardada para recuperarla.

### 4. `invertir_trio` — Invertir el trío
- **Objetivo:** Entran tres valores. Sacalos en orden inverso.
- **Instrucciones:** agarrá, soltá, recuperá, guardá · 2 memorias
- **PISTA PROPUESTA:** Como el par, pero con uno más. Guardá los que entran primero y
  traelos de vuelta en el orden contrario. Pensá en qué orden recuperarlos para que salgan
  al revés.

### 5. `sumar_par` — Sumar el par
- **Objetivo:** Entran dos valores. Sacá su suma.
- **Instrucciones:** agarrá, soltá, guardá, sumá · 1 memoria
- **PISTA PROPUESTA:** Sumá trabaja sobre lo que tenés en la mano, usando una memoria.
  Guardá el primero, agarrá el segundo y recién ahí sumá. Fijate qué memoria elegís en la
  cuenta.

### 6. `restar_par` — Restar el par
- **Objetivo:** Entran A y B (en ese orden). Sacá A menos B.
- **Instrucciones:** agarrá, soltá, recuperá, guardá, restá · 2 memorias
- **PISTA PROPUESTA:** El orden importa: A − B no es lo mismo que B − A. Pensá cuál tenés
  que tener en la mano al momento de restar, y cuál guardado.

### 7. `b3_eco_infinito` — Eco infinito
- **Objetivo:** Sacá TODOS los valores en orden, sin importar cuántos sean (con un loop).
- **Instrucciones:** agarrá, soltá, saltá a, etiqueta · sin memoria
- **PISTA PROPUESTA:** No sabés cuántos vienen, así que no podés escribir un par por cada
  uno. Marcá un punto con una etiqueta al principio y volvé ahí con saltá: eso es repetir.
  Cuando la fila se vacía, el programa frena solo.

### 8. `duplicar_cola` — Duplicar la cola
- **Objetivo:** Entra una cola de cualquier largo. Sacá cada valor dos veces.
- **Instrucciones:** agarrá, soltá, recuperá, guardá, saltá a, etiqueta · 1 memoria
- **PISTA PROPUESTA:** Es "Duplicar" pero para una cola entera: meté esa idea adentro de un
  loop. En cada vuelta, sacá el valor dos veces antes de volver al principio.

### 9. `sumar_pares` — Sumar de a pares
- **Objetivo:** La cola viene de a pares. Por cada par, sacá su suma.
- **Instrucciones:** agarrá, soltá, guardá, sumá, saltá a, etiqueta · 1 memoria
- **PISTA PROPUESTA:** Cada vuelta del loop trabaja un par: agarrá dos, sumalos y soltá el
  resultado. Después, de vuelta al principio para el par que sigue.

### 10. `b4_filtrar_ceros` — Filtrar ceros
- **Objetivo:** Sacá solo los valores distintos de cero, en orden; los ceros se descartan.
- **Instrucciones:** agarrá, soltá, saltá a, si es cero saltá a, etiqueta · sin memoria
- **PISTA PROPUESTA:** Dentro del loop, mirá cada valor: con "si es cero saltá a" podés
  esquivar el soltar cuando es cero, y soltarlo cuando no lo es.

### 11. `cortar_en_cero` — Cortar en el cero
- **Objetivo:** Sacá los valores; cuando aparezca un 0, frená (al 0 no lo saques).
- **Instrucciones:** agarrá, soltá, saltá a, si es cero saltá a, etiqueta · sin memoria
- **PISTA PROPUESTA:** Parecido a filtrar, pero el cero no se esquiva: corta todo. Si es
  cero, en vez de volver al principio, saltá hacia el FINAL (fuera del loop).

### 12. `pares_iguales` — Pares iguales
- **Objetivo:** La cola viene de a pares. Si los dos son iguales, sacá uno; si no, descartá.
- **Instrucciones:** agarrá, soltá, recuperá, guardá, restá, saltá a, si es cero saltá a, etiqueta · 1 memoria
- **PISTA PROPUESTA:** Dos valores son iguales cuando su resta da cero. Restá uno del otro y
  usá "si es cero saltá a" para decidir entre soltar o descartar. Ojo: restar te pisa la
  mano, así que guardá una copia antes.

---

# Track C# — +5 niveles avanzados

### 13. `sumar_trio` — Sumar el trío
- **Objetivo:** Entran de a tres. Sacá la suma de cada trío.
- **Instrucciones:** agarrá, soltá, recuperá, guardá, sumá, saltá a, etiqueta · 1 memoria
- **PISTA PROPUESTA:** Como "Sumar de a pares", pero con tres por vuelta. Pensá cómo ir
  acumulando la suma en una memoria antes de soltar el total.

### 14. `restar_trio` — Restar el trío
- **Objetivo:** Entran de a tres (a, b, c). Sacá a − b − c.
- **Instrucciones:** agarrá, soltá, recuperá, guardá, restá, saltá a, etiqueta · 3 memorias
- **PISTA PROPUESTA:** Se hace de a una resta por vez, siempre sobre la mano. El orden
  manda: arrancá con a en la mano y restale los otros dos, uno después del otro.

### 15. `invertir_cuarteto` — Invertir el cuarteto
- **Objetivo:** Entran de a cuatro. Sacalos en orden inverso.
- **Instrucciones:** agarrá, soltá, recuperá, guardá, saltá a, etiqueta · 3 memorias
- **PISTA PROPUESTA:** Como invertir el trío, con uno más. Guardá los que entran y traelos
  de vuelta al revés. Con cuatro, contá cuántas memorias te hacen falta.

### 16. `filtrar_duplicar` — Filtrar y duplicar
- **Objetivo:** Sacá cada valor distinto de cero repetido dos veces; descartá los ceros.
- **Instrucciones:** agarrá, soltá, recuperá, guardá, saltá a, si es cero saltá a, etiqueta · 1 memoria
- **PISTA PROPUESTA:** Mezclá dos cosas que ya hiciste: descartar los ceros (como en
  "Filtrar ceros") y, para los que pasan, soltarlos dos veces (como en "Duplicar").

### 17. `pares_iguales_doble` — Pares iguales, doble
- **Objetivo:** La cola viene de a pares; si son iguales, sacá ese valor dos veces; si no, descartá.
- **Instrucciones:** agarrá, soltá, recuperá, guardá, restá, saltá a, si es cero saltá a, etiqueta · 1 memoria
- **PISTA PROPUESTA:** Es "Pares iguales", pero cuando son iguales soltás el valor DOS veces
  en vez de una. La decisión (iguales o no) se sigue tomando con la resta y "si es cero
  saltá a".

---

## Cuando apruebes
Decime cuáles dejás como están y cuáles reescribís. Con eso genero `pistas.json` así:

```json
{
  "b1_eco": "Es un eco: nada cambia...",
  "b2_invertir_par": "Para dar vuelta dos valores...",
  "...": "..."
}
```

y el panel de Ayuda pasa a mostrar la pista de cada nivel automáticamente (sin más cambios
de código).
