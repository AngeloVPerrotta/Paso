# Sonidos de `paso`

Por ahora **todos los sonidos son tonos sintéticos generados por código**
(ver `sfx.gd`). En el sandbox no se pueden bajar assets de audio, así que estos
tonos son placeholders: andan, pero la idea es reemplazarlos por sonidos lindos
cuando los tengas.

## Cómo reemplazar un sonido

Soltá un archivo de audio en esta carpeta con el nombre lógico del hook. Si el
archivo existe, `sfx.gd` lo usa en vez del tono sintético — no hay que tocar
código.

| Hook       | Archivo esperado (cualquier extensión) | Cuándo suena                          |
|------------|----------------------------------------|---------------------------------------|
| `click`    | `assets/sfx/click.{wav,ogg,mp3}`       | click genérico de UI                  |
| `colocar`  | `assets/sfx/colocar.{wav,ogg,mp3}`     | al colocar una instrucción en el programa |
| `tick`     | `assets/sfx/tick.{wav,ogg,mp3}`        | un tick por cada paso de ejecución    |
| `win`      | `assets/sfx/win.{wav,ogg,mp3}`         | el nivel pasó                         |
| `fail`     | `assets/sfx/fail.{wav,ogg,mp3}`        | "no" suave: la solución no pasó       |
| `record`   | `assets/sfx/record.{wav,ogg,mp3}`      | fanfarria corta: ¡nuevo récord!       |

Formatos recomendados: `.ogg` (loops/música) o `.wav` (efectos cortos).
Mantené los efectos cortos (< 0.5 s) y a volumen parejo.
