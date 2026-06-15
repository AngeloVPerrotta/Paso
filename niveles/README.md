# Formato de nivel

Cada nivel es un archivo `.json` en esta carpeta. El loader (`niveles.gd`) lo
lee y devuelve una estructura tipada (`Niveles.Nivel`). La validación y el
scoring viven en `validador.gd`, **encima** del intérprete (que sigue siendo
pura lógica `estado → estado`).

## Esquema

```json
{
  "id": "b2_invertir_par",
  "nombre": "Invertir el par",
  "descripcion": "Enunciado que ve el jugador.",
  "slots": 1,
  "instrucciones_permitidas": ["TOMAR", "SOLTAR", "COPIAR", "GUARDAR"],
  "casos": [
    { "entrada": [7, 3], "salida_esperada": [3, 7] }
  ],
  "par": { "instrucciones": 6, "pasos": 6 }
}
```

| Campo | Tipo | Qué es |
|-------|------|--------|
| `id` | string | Identificador único; el archivo se llama `<id>.json`. |
| `nombre` | string | Título corto del nivel. |
| `descripcion` | string | Enunciado para el jugador. |
| `slots` | int | Cantidad de slots de memoria disponibles. |
| `instrucciones_permitidas` | string[] | Ops habilitadas. Si el programa usa una op fuera de esta lista, se rechaza. `ETIQUETA` debe estar listada para poder usar loops/condicionales. |
| `casos` | objeto[] | Lista de `{ entrada, salida_esperada }`. La validación corre el programa contra **todos** y solo pasa si **todos** dan. |
| `par.instrucciones` | int | Meta de score (cantidad de instrucciones). **Placeholder**, se afina jugando. |
| `par.pasos` | int | Meta de score (pasos ejecutados). **Placeholder**, se afina jugando. |

### Notas

- **Enteros.** El juego es entero; JSON no distingue int/float, así que el
  loader coerciona los valores de `entrada`/`salida_esperada` a `int`.
- **Varios casos = sin hardcodeo.** Para tutoriales alcanza un caso. Para
  loops/condicionales conviene usar varios casos de distinto largo y forma, así
  no se puede ganar devolviendo una salida fija.

## Scoring (lo calcula `validador.gd`)

- **`instrucciones`** = líneas del programa **sin contar** las `ETIQUETA`.
- **`pasos`** = suma, sobre todos los casos, de las instrucciones ejecutadas.
  **No** se cuenta:
  - la transición que termina el nivel (pc fuera de rango, o `TOMAR` con la
    entrada vacía: ninguna hace trabajo), ni
  - las ejecuciones de `ETIQUETA` (son marcadores, destino de saltos).

El doble score (minimizar instrucciones **y** pasos) es el loop de rejugar.

## Etiquetas y saltos

Los saltos se escriben por **nombre** de etiqueta y se resuelven a índice con
`Interprete.resolver_etiquetas(programa)` antes de correr. Ejemplo (eco infinito):

```
ETIQUETA inicio
TOMAR
SOLTAR
SALTAR inicio      # salta a la línea ETIQUETA "inicio"
```
