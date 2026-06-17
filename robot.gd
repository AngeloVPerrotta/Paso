class_name Robot
extends Control

# Robot compañero: sprite ORIGINAL dibujado por código (sin assets, sin IP).
# Es cosmético: reacciona al juego pero no lo controla. Vive en una esquina del
# escenario y "respira" con un bob suave; cambia de cara según el momento.
#
# Moods:
#   "idle"      tranquilo, parpadea de vez en cuando
#   "pensando"  concentrado mientras corre (ojos entornados, antena late)
#   "feliz"     pasó el nivel (ojos ^^, sonrisa, salta)
#   "fiesta"    récord (igual que feliz + salto más alto, brillo de antena)
#   "animo"     falló pero alentador (nunca triste): guiño y media sonrisa

# Colores desde la paleta única (tema.gd). El DISEÑO no cambia, solo el color:
# cuerpo neutro cálido + acento ámbar (antena, cachetes, luz de pecho).
const COL_CUERPO := Tema.CELDA          # gris-arena cálido (neutro de la paleta)
const COL_BORDE := Tema.CELDA_BORDE
const COL_OJO := Tema.TEXTO
const COL_ACENTO := Tema.CALIDO         # ámbar: antena, cachetes, pecho
const COL_PANEL := Tema.PANEL
const COL_VISOR := Color("232220")      # visor oscuro = texto de la paleta

var mood := "idle"

var _t := 0.0                 # tiempo para animaciones cíclicas
var _blink := 0.0             # fase de parpadeo (0 = ojos abiertos)
var _prox_blink := 2.0
var _salto := 0.0             # impulso de salto (decae)
var _antena := 0.0            # fase de pulso de antena


func _ready() -> void:
	custom_minimum_size = Vector2(120, 120)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_mood(nuevo: String) -> void:
	if nuevo == mood:
		return
	mood = nuevo
	if nuevo == "feliz" or nuevo == "animo":
		_salto = 1.0
	elif nuevo == "fiesta":
		_salto = 1.4
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	# Parpadeo ocasional en idle.
	if mood == "idle" or mood == "pensando":
		_prox_blink -= delta
		if _prox_blink <= 0.0:
			_blink = 1.0
			_prox_blink = randf_range(2.0, 4.5)
	if _blink > 0.0:
		_blink = maxf(0.0, _blink - delta * 8.0)
	if _salto > 0.0:
		_salto = maxf(0.0, _salto - delta * 2.2)
	if mood == "pensando" or mood == "fiesta":
		_antena += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	# Bob suave + salto de celebración.
	var bob := sin(_t * 2.2) * 2.5
	var brinco := sin(minf(_salto, 1.0) * PI) * 16.0 * _salto
	var off := Vector2(0, bob - brinco)

	var cx := w * 0.5 + off.x
	var cy := h * 0.5 + off.y

	# Sombra de contacto (suave, sin sombra dura): elipse tenue que se achica al saltar.
	var sombra_a := 0.10 * (1.0 - clampf(_salto, 0.0, 1.0) * 0.6)
	draw_circle(Vector2(w * 0.5, h * 0.93), 24.0, Color(0.2, 0.18, 0.15, sombra_a))

	# Cuerpo + cuello + cabeza se SOLAPAN y se leen como UNA pieza. Truco para el
	# contorno sin costuras internas: primero la silueta inflada en color borde
	# (las 3 formas se fusionan en una sola union), encima el relleno crema.
	_silueta(cx, cy, COL_BORDE, 2.0)
	_silueta(cx, cy, COL_CUERPO, 0.0)

	# Visor (zona oscura para los ojos), redondeado.
	var visor := Rect2(cx - 20, cy - 26, 40, 24)
	_rect_redondeado(visor, 9.0, COL_VISOR)

	# --- Ojos ---
	var ojo_y := cy - 14
	var sep := 9.0
	match mood:
		"feliz", "fiesta":
			_ojo_arco(Vector2(cx - sep, ojo_y), true)
			_ojo_arco(Vector2(cx + sep, ojo_y), true)
		"animo":
			# Guiño: uno abierto, el otro cerrado (línea).
			draw_circle(Vector2(cx - sep, ojo_y), 3.6, Color.WHITE)
			draw_circle(Vector2(cx - sep, ojo_y), 2.0, COL_OJO)
			draw_line(Vector2(cx + sep - 4, ojo_y), Vector2(cx + sep + 4, ojo_y), Color.WHITE, 2.0)
		"pensando":
			_ojo_redondo(Vector2(cx - sep, ojo_y), 0.5)
			_ojo_redondo(Vector2(cx + sep, ojo_y), 0.5)
		_:
			_ojo_redondo(Vector2(cx - sep, ojo_y), 1.0 - _blink)
			_ojo_redondo(Vector2(cx + sep, ojo_y), 1.0 - _blink)

	# Cachetes coral (solo cuando está contento).
	if mood == "feliz" or mood == "fiesta":
		draw_circle(Vector2(cx - 18, cy - 8), 3.0, Color(COL_ACENTO.r, COL_ACENTO.g, COL_ACENTO.b, 0.5))
		draw_circle(Vector2(cx + 18, cy - 8), 3.0, Color(COL_ACENTO.r, COL_ACENTO.g, COL_ACENTO.b, 0.5))

	# Luz de pecho coral.
	draw_circle(Vector2(cx, cy + 27), 3.5, COL_ACENTO)

	# --- Antena (desde el tope de la cabeza, dibujada al final) ---
	var antena_base := Vector2(cx, cy - 34)
	var late := 1.0 + (sin(_antena * 9.0) * 0.18 if (mood == "pensando" or mood == "fiesta") else 0.0)
	draw_line(antena_base, antena_base + Vector2(0, -13), COL_OJO, 2.0)
	var brillo := COL_ACENTO
	if mood == "fiesta":
		brillo = COL_ACENTO.lerp(Color.WHITE, 0.5 + 0.5 * sin(_antena * 12.0))
	draw_circle(antena_base + Vector2(0, -15), 4.5 * late, brillo)


# La silueta del robot (cuerpo + cuello + cabeza solapados) en un color, opcionalmente
# inflada `inf` px. Dibujarla inflada en color borde y luego sin inflar en crema da
# un contorno limpio de toda la pieza sin líneas internas.
func _silueta(cx: float, cy: float, color: Color, inf: float) -> void:
	# Cuerpo.
	_rect_redondeado(Rect2(cx - 23 - inf, cy + 12 - inf, 46 + inf * 2, 30 + inf * 2), 11.0 + inf, color)
	# Cuello (conecta cabeza y cuerpo).
	draw_rect(Rect2(cx - 9 - inf, cy + 2 - inf, 18 + inf * 2, 14 + inf * 2), color)
	# Cabeza.
	_rect_redondeado(Rect2(cx - 28 - inf, cy - 34 - inf, 56 + inf * 2, 46 + inf * 2), 13.0 + inf, color)


# Ojo abierto: blanco con pupila. `abierto` 0..1 escala la altura (parpadeo).
func _ojo_redondo(c: Vector2, abierto: float) -> void:
	if abierto <= 0.05:
		draw_line(c - Vector2(3, 0), c + Vector2(3, 0), Color.WHITE, 2.0)
		return
	var r := 3.6
	# Aproximamos el "entrecerrar" dibujando el ojo y tapando con el color del visor.
	draw_circle(c, r, Color.WHITE)
	draw_circle(c, r * 0.55, COL_OJO)
	if abierto < 1.0:
		var tapa := r * (1.0 - abierto)
		draw_rect(Rect2(c.x - r, c.y - r, r * 2.0, tapa), COL_VISOR)


# Ojo "feliz" ^ : un arco.
func _ojo_arco(c: Vector2, _feliz: bool) -> void:
	draw_arc(c + Vector2(0, 2), 4.0, PI, TAU, 10, Color.WHITE, 2.0)


# --- Helpers de dibujo de rects redondeados (sin sombras duras) ---
func _rect_redondeado(r: Rect2, radio: float, color: Color) -> void:
	# Cuerpo central + 4 bordes + 4 esquinas con círculos.
	draw_rect(Rect2(r.position.x + radio, r.position.y, r.size.x - radio * 2.0, r.size.y), color)
	draw_rect(Rect2(r.position.x, r.position.y + radio, r.size.x, r.size.y - radio * 2.0), color)
	var rr := radio
	draw_circle(r.position + Vector2(rr, rr), rr, color)
	draw_circle(r.position + Vector2(r.size.x - rr, rr), rr, color)
	draw_circle(r.position + Vector2(rr, r.size.y - rr), rr, color)
	draw_circle(r.position + Vector2(r.size.x - rr, r.size.y - rr), rr, color)


func _rect_redondeado_borde(r: Rect2, radio: float, color: Color, ancho: float) -> void:
	# Borde simple: 4 líneas (las esquinas quedan levemente abiertas, casi imperceptible).
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.position.x + r.size.x
	var y1 := r.position.y + r.size.y
	draw_line(Vector2(x0 + radio, y0), Vector2(x1 - radio, y0), color, ancho)
	draw_line(Vector2(x0 + radio, y1), Vector2(x1 - radio, y1), color, ancho)
	draw_line(Vector2(x0, y0 + radio), Vector2(x0, y1 - radio), color, ancho)
	draw_line(Vector2(x1, y0 + radio), Vector2(x1, y1 - radio), color, ancho)
