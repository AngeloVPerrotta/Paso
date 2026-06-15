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

const COL_CUERPO := Color("e9e2d4")     # gris-crema cálido
const COL_BORDE := Color("c8bfad")
const COL_OJO := Color("3d3a34")
const COL_ACENTO := Color("d97757")     # coral: antena, cachetes
const COL_PANEL := Color("fbf9f4")

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
	var base_y := h * 0.62 + off.y

	# Sombra de contacto (suave, sin sombra dura): elipse tenue que se achica al saltar.
	var sombra_a := 0.10 * (1.0 - clampf(_salto, 0.0, 1.0) * 0.6)
	draw_circle(Vector2(w * 0.5, h * 0.92), 26.0, Color(0.2, 0.18, 0.15, sombra_a))

	# --- Antena ---
	var antena_base := Vector2(cx, base_y - 34)
	var late := 1.0 + (sin(_antena * 9.0) * 0.18 if (mood == "pensando" or mood == "fiesta") else 0.0)
	draw_line(antena_base, antena_base + Vector2(0, -14), COL_OJO, 2.0)
	var brillo := COL_ACENTO
	if mood == "fiesta":
		brillo = COL_ACENTO.lerp(Color.WHITE, 0.5 + 0.5 * sin(_antena * 12.0))
	draw_circle(antena_base + Vector2(0, -16), 4.5 * late, brillo)

	# --- Cabeza (rect redondeado cálido) ---
	var cab := Rect2(cx - 28, base_y - 34, 56, 46)
	_rect_redondeado(cab, 12.0, COL_CUERPO)
	_rect_redondeado_borde(cab, 12.0, COL_BORDE, 2.0)

	# Visor (zona oscura para los ojos), redondeado.
	var visor := Rect2(cx - 20, base_y - 26, 40, 24)
	_rect_redondeado(visor, 9.0, Color("2b2925"))

	# --- Ojos ---
	var ojo_y := base_y - 14
	var sep := 9.0
	match mood:
		"feliz", "fiesta":
			# Ojos felices ^^
			_ojo_arco(Vector2(cx - sep, ojo_y), true)
			_ojo_arco(Vector2(cx + sep, ojo_y), true)
		"animo":
			# Guiño: uno abierto, el otro cerrado (línea).
			draw_circle(Vector2(cx - sep, ojo_y), 3.6, Color.WHITE)
			draw_circle(Vector2(cx - sep, ojo_y), 2.0, COL_OJO)
			draw_line(Vector2(cx + sep - 4, ojo_y), Vector2(cx + sep + 4, ojo_y), Color.WHITE, 2.0)
		"pensando":
			# Ojos entornados (concentrado): círculos chicos con párpado.
			_ojo_redondo(Vector2(cx - sep, ojo_y), 1.0 - 0.5)
			_ojo_redondo(Vector2(cx + sep, ojo_y), 1.0 - 0.5)
		_:
			# Idle: ojos redondos, parpadeo.
			_ojo_redondo(Vector2(cx - sep, ojo_y), 1.0 - _blink)
			_ojo_redondo(Vector2(cx + sep, ojo_y), 1.0 - _blink)

	# Cachetes coral (solo cuando está contento).
	if mood == "feliz" or mood == "fiesta":
		draw_circle(Vector2(cx - 18, base_y - 8), 3.0, Color(COL_ACENTO.r, COL_ACENTO.g, COL_ACENTO.b, 0.5))
		draw_circle(Vector2(cx + 18, base_y - 8), 3.0, Color(COL_ACENTO.r, COL_ACENTO.g, COL_ACENTO.b, 0.5))

	# --- Cuerpo ---
	var cuerpo := Rect2(cx - 22, base_y + 12, 44, 30)
	_rect_redondeado(cuerpo, 10.0, COL_CUERPO)
	_rect_redondeado_borde(cuerpo, 10.0, COL_BORDE, 2.0)
	# Pequeño "corazón"/luz de pecho coral.
	draw_circle(Vector2(cx, base_y + 27), 4.0, COL_ACENTO)


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
		draw_rect(Rect2(c.x - r, c.y - r, r * 2.0, tapa), Color("2b2925"))


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
