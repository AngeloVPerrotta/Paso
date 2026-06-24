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
# `var` (no `const`): la paleta de Tema es mutable (tema claro/oscuro), así que se
# capturan al instanciar el robot —después de Tema.aplicar()—, no en tiempo de compilación.
var COL_CUERPO := Tema.CELDA          # gris-arena cálido (neutro de la paleta)
var COL_BORDE := Tema.CELDA_BORDE
var COL_OJO := Tema.TEXTO
var COL_ACENTO := Tema.CALIDO         # ámbar: antena, cachetes, pecho
var COL_PANEL := Tema.PANEL
var COL_VISOR := Color("232220")      # visor oscuro (igual en ambos temas)
# Pupila SIEMPRE oscura (igual que el visor, en ambos temas). En claro coincide con
# COL_OJO (=TEXTO); en oscuro TEXTO es claro y, sobre el blanco del ojo, la pupila se
# perdía (la cara "desaparecía" — issue #41). Fijarla oscura la mantiene legible.
var COL_PUPILA := Color("232220")

signal presionado             # el jugador clickeó el robot (solo si es interactivo)

var mood := "idle"
var hablando := false         # robot-tutor hablando: la antena oscila (y parpadea) un toque
var interactivo := false      # solo el robot del juego: reacciona al hover y emite `presionado`

var _t := 0.0                 # tiempo para animaciones cíclicas
var _blink := 0.0             # fase de parpadeo (0 = ojos abiertos)
var _prox_blink := 2.0
var _salto := 0.0             # impulso de salto (decae)
var _antena := 0.0            # fase de pulso de antena
var _habla := 0.0             # fase del "hablar": oscilación de antena, viva al aparecer (balbuceo)
var _hover := false           # el mouse está encima (solo si interactivo)
var _hover_amt := 0.0         # 0..1 suavizado: intensidad de la micro-reacción de hover


func _ready() -> void:
	custom_minimum_size = Vector2(120, 120)
	# Respetar `interactivo`: si `set_interactivo(true)` se llamó ANTES de entrar al
	# árbol (el robot del juego lo hace), `_ready` corre después y NO debe pisar el
	# STOP con IGNORE —si lo hace, el Control deja de recibir hover/_gui_input (bug #27).
	mouse_filter = Control.MOUSE_FILTER_STOP if interactivo else Control.MOUSE_FILTER_IGNORE


# Activa la interacción cosmética (hover + click). La usan todos los robots visibles
# (inicio, juego, demo, tutor): el HOVER siempre reacciona; el `presionado` lo conecta
# quien quiera (hoy: solo el robot del juego, que suelta una frase). No corre lógica de
# juego: es presentación pura.
func set_interactivo(activo: bool) -> void:
	interactivo = activo
	mouse_filter = Control.MOUSE_FILTER_STOP if activo else Control.MOUSE_FILTER_IGNORE
	if activo:
		if not mouse_entered.is_connected(_on_mouse_entered):
			mouse_entered.connect(_on_mouse_entered)
			mouse_exited.connect(_on_mouse_exited)


func _on_mouse_entered() -> void:
	_hover = true
	_blink = 1.0                 # un parpadeo de "atender" al pasar por encima
	queue_redraw()


func _on_mouse_exited() -> void:
	_hover = false


func _gui_input(event: InputEvent) -> void:
	if not interactivo:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		presionado.emit()
		accept_event()


func set_mood(nuevo: String) -> void:
	if nuevo == mood:
		return
	mood = nuevo
	if nuevo == "feliz" or nuevo == "animo":
		_salto = 1.0
	elif nuevo == "fiesta":
		_salto = 1.4
	queue_redraw()


func set_hablando(activo: bool) -> void:
	if activo == hablando:
		return
	hablando = activo
	if activo:
		_habla = 0.0              # reinicia la fase para sincronizar la antena con el balbuceo
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	# Parpadeo ocasional en idle / pensando / al hablar.
	if mood == "idle" or mood == "pensando" or hablando:
		_prox_blink -= delta
		if _prox_blink <= 0.0:
			_blink = 1.0
			_prox_blink = randf_range(2.0, 4.5)
	if _blink > 0.0:
		_blink = maxf(0.0, _blink - delta * 8.0)
	if _salto > 0.0:
		_salto = maxf(0.0, _salto - delta * 2.2)
	if mood == "pensando" or mood == "fiesta" or hablando:
		_antena += delta
	if hablando:
		_habla += delta
	# Hover: la intensidad sube/baja suave (entra atento, sale calmo). Anima escala,
	# ladeo de cabeza, antena y luz —todo interpolado vía _hover_amt, nunca a saltos.
	_hover_amt = move_toward(_hover_amt, 1.0 if _hover else 0.0, delta * (6.0 if _hover else 3.0))
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

	# --- Hover (cosmético): el robot se agranda apenas y ladea la cabeza, atento. Se hace
	# escalando/rotando el DIBUJO (draw_set_transform), NO el Control: así el área de hover
	# y el layout siguen iguales (sin parpadeo de "salir de sí mismo" ni saltos en la fila).
	# La sombra queda fuera de la transformación (vive en el piso). El pivote está en la base
	# del cuerpo, para que "crezca hacia arriba" en vez de hundirse.
	if _hover_amt > 0.0:
		var hs := 1.0 + 0.07 * _hover_amt                                              # +7% de escala
		var tilt := _hover_amt * (deg_to_rad(5.0) + deg_to_rad(1.5) * sin(_t * 2.0))   # ladeo + micro-balanceo
		var piv := Vector2(cx, cy + 28)
		var M := Transform2D(tilt, Vector2(hs, hs), 0.0, Vector2.ZERO)
		draw_set_transform(piv - M * piv, tilt, Vector2(hs, hs))

	# Cuerpo + cuello + cabeza se SOLAPAN y se leen como UNA pieza. Truco para el
	# contorno sin costuras internas: primero la silueta inflada en color borde
	# (las 3 formas se fusionan en una sola union), encima el relleno crema.
	# Issue #41: en tema oscuro el cuerpo (CELDA #35322c) casi se funde con el fondo
	# (#26241f). Le damos un contorno más claro y un toque más grueso SOLO en oscuro,
	# para despegar la silueta. En claro queda idéntico (COL_BORDE, 2px).
	var borde_col := COL_BORDE
	var borde_inf := 2.0
	if Tema.actual() == "oscuro":
		borde_col = Tema.TENUE          # gris cálido claro: rim que contrasta con el fondo
		borde_inf = 3.0
	_silueta(cx, cy, borde_col, borde_inf)
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
			draw_circle(Vector2(cx - sep, ojo_y), 2.0, COL_PUPILA)
			draw_line(Vector2(cx + sep - 4, ojo_y), Vector2(cx + sep + 4, ojo_y), Color.WHITE, 2.0)
		"pensando":
			_ojo_redondo(Vector2(cx - sep, ojo_y), 0.5)
			_ojo_redondo(Vector2(cx + sep, ojo_y), 0.5)
		"dormido":
			# Ojos cerrados (cabecea cuando el jugador lo deja quieto un rato).
			draw_line(Vector2(cx - sep - 4, ojo_y), Vector2(cx - sep + 4, ojo_y), Color.WHITE, 2.0)
			draw_line(Vector2(cx + sep - 4, ojo_y), Vector2(cx + sep + 4, ojo_y), Color.WHITE, 2.0)
		_:
			_ojo_redondo(Vector2(cx - sep, ojo_y), 1.0 - _blink)
			_ojo_redondo(Vector2(cx + sep, ojo_y), 1.0 - _blink)

	# Hover: una chispa blanca en cada ojo (independiente del mood) — "se le iluminan".
	if _hover_amt > 0.0:
		var chispa := Color(1.0, 1.0, 1.0, 0.55 * _hover_amt)
		draw_circle(Vector2(cx - sep + 1.2, ojo_y - 1.2), 1.3, chispa)
		draw_circle(Vector2(cx + sep + 1.2, ojo_y - 1.2), 1.3, chispa)

	# Cachetes coral (solo cuando está contento).
	if mood == "feliz" or mood == "fiesta":
		draw_circle(Vector2(cx - 18, cy - 8), 3.0, Color(COL_ACENTO.r, COL_ACENTO.g, COL_ACENTO.b, 0.5))
		draw_circle(Vector2(cx + 18, cy - 8), 3.0, Color(COL_ACENTO.r, COL_ACENTO.g, COL_ACENTO.b, 0.5))

	# Luz de pecho coral (al hover late más grande y se aclara, con un halo tenue).
	var pecho_r := 3.5 + 1.6 * _hover_amt
	if _hover_amt > 0.0:
		draw_circle(Vector2(cx, cy + 27), pecho_r + 3.5, Color(COL_ACENTO.r, COL_ACENTO.g, COL_ACENTO.b, 0.18 * _hover_amt))
	draw_circle(Vector2(cx, cy + 27), pecho_r, COL_ACENTO.lerp(Color.WHITE, 0.35 * _hover_amt))

	# --- Antena (desde el tope de la cabeza, dibujada al final) ---
	var antena_base := Vector2(cx, cy - 34)
	var late := 1.0 + (sin(_antena * 9.0) * 0.18 if (mood == "pensando" or mood == "fiesta") else 0.0)
	# Al hablar, la antena oscila de lado: viva al aparecer (acompaña el balbuceo) y luego apenas.
	var sway := 0.0
	if hablando:
		var intens := 0.35 + 0.65 * exp(-3.0 * _habla)
		sway = sin(_habla * 21.0) * 3.4 * intens
	# Hover (cosmético): la antena se balancea claramente y se yergue, como atendiendo.
	var lift := 0.0
	if _hover_amt > 0.0:
		sway += sin(_t * 5.0) * 5.0 * _hover_amt
		lift = 3.5 * _hover_amt
	var tip := antena_base + Vector2(sway, -13 - lift)
	if mood == "dormido":
		tip = antena_base + Vector2(8.0, -5.0)   # antena caída: dormido
	draw_line(antena_base, tip, COL_OJO, 2.0)
	var brillo := COL_ACENTO
	if mood == "fiesta":
		brillo = COL_ACENTO.lerp(Color.WHITE, 0.5 + 0.5 * sin(_antena * 12.0))
	elif mood == "dormido":
		brillo = Color(COL_ACENTO.r, COL_ACENTO.g, COL_ACENTO.b, 0.45)   # luz tenue
	var tip_r := (4.5 + 1.8 * _hover_amt) * late
	if _hover_amt > 0.0:
		brillo = brillo.lerp(Color.WHITE, 0.45 * _hover_amt)             # brillo extra al atender
		draw_circle(tip + Vector2(0, -2), tip_r + 3.0, Color(COL_ACENTO.r, COL_ACENTO.g, COL_ACENTO.b, 0.16 * _hover_amt))   # halo
	draw_circle(tip + Vector2(0, -2), tip_r, brillo)


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
	draw_circle(c, r * 0.55, COL_PUPILA)
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
