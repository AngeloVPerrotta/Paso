extends Control

# UI de "paso". Mantiene la separacion sim/render INTACTA:
#   - El estado vive en Interprete.Estado (pura logica). No se toca.
#   - El editor solo MUTA el array `programa` (data); nunca toca el estado.
#   - redibujar() es una FUNCION del estado: dibuja una "foto" y nada mas.
#   - _animar() / juice / sonido / robot / tutorial son COSMETICA: leen el estado
#     para mostrarlo, nunca lo mutan. La semantica la sigue mandando el validador.
# El programa del jugador arranca VACIO; se construye con la paleta de instrucciones.

# Categorias de op (espejo de validador.gd): definen que control de arg lleva cada linea.
const OPS_CON_SLOT := ["COPIAR", "GUARDAR", "SUMAR", "RESTAR"]
const OPS_CON_ETIQUETA := ["SALTAR", "SALTAR_SI_CERO"]

# Instrucciones en castellano amigable (cara de editor, pero legible). El nombre
# interno (la clave) es el que entiende el interprete/validador; esto es solo display.
const OP_LABEL := {
	"TOMAR": "agarrá",
	"SOLTAR": "soltá",
	"COPIAR": "recuperá",
	"GUARDAR": "guardá",
	"SUMAR": "sumá",
	"RESTAR": "restá",
	"SALTAR": "saltá a",
	"SALTAR_SI_CERO": "si es cero saltá a",
	"ETIQUETA": "etiqueta",
}

# --- Banco de niveles ---
var orden: Array = []
var nivel_idx := 0
var resueltos := {}

# --- Datos del nivel actual ---
var nivel
var programa: Array = []                # crudo, editable: saltos por NOMBRE de etiqueta
var programa_run: Array = []            # resuelto: saltos por indice (para ejecutar)
var entrada_inicial: Array = []
var cantidad_slots := 0

# --- Paleta calida-minimalista (estilo UX Claude: off-white, un solo acento coral) ---
const COL_FONDO := Color("f4f1ea")        # off-white calido
const COL_PANEL := Color("fbf9f4")        # panel casi blanco
const COL_PANEL_BORDE := Color("e7e1d5")
const COL_CELDA := Color("efeadf")
const COL_CELDA_BORDE := Color("ddd5c6")
const COL_TEXTO := Color("3d3a34")        # gris calido oscuro
const COL_TENUE := Color("9b958a")        # apagado
const COL_ACENTO := Color("d97757")       # coral/clay: EL acento
const COL_ACENTO_TENUE := Color("d97757", 0.14)
const COL_MANO := Color("d97757")
const COL_OK := Color("6f9a6a")           # verde calmo, solo para ✓ sutiles
const COL_ERROR := Color("c25a4e")        # clay-rojo apagado (nunca estridente)

# Velocidades: Run rapido / Step lento. paso = seg por tick; anim = duracion de animacion.
const VELOCIDADES := [
	{"nombre": "lento",  "paso": 0.70, "anim": 0.46},
	{"nombre": "normal", "paso": 0.42, "anim": 0.30},
	{"nombre": "rápido", "paso": 0.16, "anim": 0.13},
]
var vel_idx := 1

# --- Estado de simulacion ---
var estado
var pasos := 0
var corriendo := false

# --- Fuentes (cara de editor: mono numerada; UI: sans limpia) ---
var fuente_mono: SystemFont
var fuente_sans: SystemFont

# --- Referencias a nodos ---
var filas_op: Array = []                # Label del op por linea (resaltado + pulso)
var filas_panel: Array = []             # PanelContainer por linea (resalte de linea actual)
var filas_sb: Array = []                # StyleBoxFlat por linea (se muta para resaltar)
var programa_vbox: VBoxContainer
var titulo_label: Label
var desc_label: Label
var meta_label: Label                   # "🎯 objetivo … · tu mejor …"
var paleta_box: HFlowContainer
var progreso_box: HFlowContainer
var mano_celda: Panel
var mano_label: Label
var slots_box: HBoxContainer
var slot_celdas: Array = []             # Panel por slot (para brillo al escribir)
var entrada_box: HBoxContainer
var salida_box: HBoxContainer
var estado_label: Label
var validacion_label: Label
var boton_run: Button
var boton_vel: Button
var timer: Timer
var capa_anim: Control
var robot: Robot
var sfx: Sfx
var _tween_beat: Tween
var escenario_col: VBoxContainer       # columna derecha (para ubicar la celebracion)

# --- Pantalla inicial ---
var inicio_capa: Control
var _btn_continuar: Button
var _inicio_robot: Robot
var _arrancado := false                 # true tras el boot: a partir de ahi guardamos "ultimo nivel"

# --- Tutorial ---
var tutorial_capa: Control
var _spotlight                          # Spotlight (inner class)
var _tuto_pasos: Array = []
var _tuto_i := 0
var _tuto_globo: PanelContainer
var _tuto_txt: Label
var _tuto_btn_sig: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fuente_mono = SystemFont.new()
	fuente_mono.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "JetBrains Mono", "DejaVu Sans Mono", "monospace"])
	fuente_sans = SystemFont.new()
	fuente_sans.font_names = PackedStringArray(["Segoe UI", "Inter", "Helvetica Neue", "Arial", "sans-serif"])

	sfx = Sfx.new()
	add_child(sfx)

	orden = Niveles.orden()
	_construir_ui()
	_construir_inicio()
	_cargar_indice(0)
	_mostrar_inicio()
	_arrancado = true


func _cargar_nivel(id: String) -> void:
	nivel = Niveles.cargar(id)
	if nivel == null:
		push_error("No se pudo cargar el nivel '%s'." % id)
		return
	programa = []
	programa_run = []
	cantidad_slots = nivel.slots
	entrada_inicial = nivel.casos[0].entrada.duplicate() if not nivel.casos.is_empty() else []


func _cargar_indice(idx: int) -> void:
	if orden.is_empty():
		return
	_cerrar_tutorial()
	nivel_idx = clampi(idx, 0, orden.size() - 1)
	_cargar_nivel(orden[nivel_idx])
	if nivel == null:
		return
	if _arrancado:
		Puntajes.set_ultimo(orden[nivel_idx])   # para "Continuar" (no en el boot)
	_repintar_paleta()
	_repintar_programa()
	_construir_memoria()
	_repintar_cabecera()
	_repintar_progreso()
	_reset_corrida()
	if robot:
		robot.set_mood("idle")
	_quizas_tutorial()


func _on_prev() -> void:
	_cargar_indice(nivel_idx - 1)


func _on_next() -> void:
	_cargar_indice(nivel_idx + 1)


# La paleta muestra SOLO las instrucciones permitidas del nivel actual, con su
# etiqueta en castellano amigable (el op interno sigue siendo el de siempre).
func _repintar_paleta() -> void:
	for hijo in paleta_box.get_children():
		hijo.queue_free()
	if nivel == null:
		return
	for op in nivel.instrucciones_permitidas:
		var b := Button.new()
		b.text = OP_LABEL.get(op, op)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", fuente_sans)
		_estilo_boton_paleta(b)
		b.pressed.connect(func(): agregar_op(op))
		paleta_box.add_child(b)


func _repintar_cabecera() -> void:
	if nivel == null:
		return
	var resuelto: bool = resueltos.has(nivel.id)
	var marca := "   ✓" if resuelto else ""
	titulo_label.text = "%s   ·   nivel %d/%d%s" % [nivel.nombre, nivel_idx + 1, orden.size(), marca]
	titulo_label.add_theme_color_override("font_color", COL_OK if resuelto else COL_TEXTO)
	desc_label.text = nivel.descripcion
	_repintar_meta()


# "objetivo: … · tu mejor: …" — el objetivo es el par; el mejor es la marca local.
func _repintar_meta() -> void:
	if nivel == null:
		return
	var obj := "objetivo  ·  %d instrucciones · %d pasos" % [nivel.par_instrucciones, nivel.par_pasos]
	var m = Puntajes.mejor(nivel.id)
	var mejor_txt := "tu mejor  ·  —"
	if m != null:
		mejor_txt = "tu mejor  ·  %d instrucciones · %d pasos" % [m.instrucciones, m.pasos]
	meta_label.text = "🎯  %s        ★  %s" % [obj, mejor_txt]


func _repintar_progreso() -> void:
	for hijo in progreso_box.get_children():
		hijo.queue_free()
	for k in orden.size():
		var id_k: String = orden[k]
		var resuelto: bool = resueltos.has(id_k)
		var b := Button.new()
		b.custom_minimum_size = Vector2(30, 28)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", fuente_mono)
		b.text = "✓" if resuelto else str(k + 1)
		var color := COL_TENUE
		if k == nivel_idx:
			color = COL_ACENTO
		elif resuelto:
			color = COL_OK
		b.add_theme_color_override("font_color", color)
		b.pressed.connect(func(): _cargar_indice(k))
		progreso_box.add_child(b)


# ---------------------------------------------------------------------------
# Construccion de la UI (una sola vez).
# ---------------------------------------------------------------------------
func _construir_ui() -> void:
	var fondo := ColorRect.new()
	fondo.color = COL_FONDO
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)

	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "top", "right", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 28)
	add_child(margen)

	var raiz := VBoxContainer.new()
	raiz.add_theme_constant_override("separation", 14)
	margen.add_child(raiz)

	# Cabecera: navegacion + titulo.
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 12)
	raiz.add_child(nav)

	var b_inicio := _boton_nav("⌂")
	b_inicio.tooltip_text = "Volver al inicio"
	b_inicio.pressed.connect(_mostrar_inicio)
	nav.add_child(b_inicio)

	var b_prev := _boton_nav("◀")
	b_prev.pressed.connect(_on_prev)
	nav.add_child(b_prev)

	titulo_label = Label.new()
	titulo_label.add_theme_font_override("font", fuente_sans)
	titulo_label.add_theme_font_size_override("font_size", 24)
	titulo_label.add_theme_color_override("font_color", COL_TEXTO)
	titulo_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nav.add_child(titulo_label)

	var b_next := _boton_nav("▶")
	b_next.pressed.connect(_on_next)
	nav.add_child(b_next)

	# Strip de progreso.
	progreso_box = HFlowContainer.new()
	progreso_box.add_theme_constant_override("h_separation", 5)
	progreso_box.add_theme_constant_override("v_separation", 5)
	raiz.add_child(progreso_box)

	# Enunciado del nivel (una frase clara).
	desc_label = Label.new()
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_override("font", fuente_sans)
	desc_label.add_theme_font_size_override("font_size", 17)
	desc_label.add_theme_color_override("font_color", COL_TEXTO)
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	raiz.add_child(desc_label)

	# Meta: objetivo + tu mejor.
	meta_label = Label.new()
	meta_label.add_theme_font_override("font", fuente_sans)
	meta_label.add_theme_font_size_override("font_size", 13)
	meta_label.add_theme_color_override("font_color", COL_TENUE)
	raiz.add_child(meta_label)

	# Cuerpo: editor a la izquierda, escenario a la derecha.
	var cuerpo := HBoxContainer.new()
	cuerpo.add_theme_constant_override("separation", 24)
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	raiz.add_child(cuerpo)

	cuerpo.add_child(_construir_editor())
	cuerpo.add_child(_construir_escenario())

	raiz.add_child(_construir_controles())

	estado_label = Label.new()
	estado_label.add_theme_font_override("font", fuente_mono)
	estado_label.add_theme_font_size_override("font_size", 15)
	estado_label.add_theme_color_override("font_color", COL_TENUE)
	raiz.add_child(estado_label)

	validacion_label = Label.new()
	validacion_label.add_theme_font_override("font", fuente_sans)
	validacion_label.add_theme_font_size_override("font_size", 16)
	validacion_label.add_theme_color_override("font_color", COL_TENUE)
	validacion_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	validacion_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	validacion_label.custom_minimum_size = Vector2(0, 44)
	raiz.add_child(validacion_label)

	# Capa de animacion: toda la pantalla, encima, sin bloquear clicks.
	capa_anim = Control.new()
	capa_anim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	capa_anim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(capa_anim)

	# Capa de tutorial: por encima de todo (se llena bajo demanda).
	tutorial_capa = Control.new()
	tutorial_capa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tutorial_capa.visible = false
	add_child(tutorial_capa)

	timer = Timer.new()
	timer.wait_time = VELOCIDADES[vel_idx].paso
	timer.one_shot = false
	timer.timeout.connect(_on_tick)
	add_child(timer)


func _construir_editor() -> Control:
	var panel := _panel(COL_PANEL)
	panel.custom_minimum_size = Vector2(460, 0)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	v.add_child(_etiqueta("INSTRUCCIONES", 13, COL_TENUE, true))

	paleta_box = HFlowContainer.new()
	paleta_box.add_theme_constant_override("h_separation", 7)
	paleta_box.add_theme_constant_override("v_separation", 7)
	v.add_child(paleta_box)

	v.add_child(_separador())
	v.add_child(_etiqueta("TU PROGRAMA", 13, COL_TENUE, true))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)

	programa_vbox = VBoxContainer.new()
	programa_vbox.add_theme_constant_override("separation", 2)
	programa_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(programa_vbox)

	return panel


func _construir_escenario() -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 16)
	escenario_col = col

	# Robot compañero arriba a la derecha del escenario.
	var fila_top := HBoxContainer.new()
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila_top.add_child(sp)
	robot = Robot.new()
	fila_top.add_child(robot)
	col.add_child(fila_top)

	# MANO.
	col.add_child(_etiqueta("en la mano  ·  int", 13, COL_TENUE, true))
	mano_celda = _celda(COL_CELDA)
	mano_label = mano_celda.get_child(0)
	mano_label.add_theme_color_override("font_color", COL_MANO)
	var fila_mano := HBoxContainer.new()
	fila_mano.add_child(mano_celda)
	col.add_child(fila_mano)

	# MEMORIA (slots tipados).
	col.add_child(_etiqueta("memoria", 13, COL_TENUE, true))
	slots_box = HBoxContainer.new()
	slots_box.add_theme_constant_override("separation", 10)
	col.add_child(slots_box)

	# ENTRAN.
	col.add_child(_etiqueta("entran  ·  int", 13, COL_TENUE, true))
	entrada_box = HBoxContainer.new()
	entrada_box.add_theme_constant_override("separation", 8)
	col.add_child(entrada_box)

	# SALEN.
	col.add_child(_etiqueta("salen  ·  int", 13, COL_TENUE, true))
	salida_box = HBoxContainer.new()
	salida_box.add_theme_constant_override("separation", 8)
	col.add_child(salida_box)

	return col


func _construir_controles() -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)

	boton_run = _boton_accion("▶ Correr", true)
	boton_run.pressed.connect(_on_run_pressed)
	fila.add_child(boton_run)

	var b_step := _boton_accion("⏯ Paso", false)
	b_step.pressed.connect(_on_step_pressed)
	fila.add_child(b_step)

	var b_reset := _boton_accion("↺ Reiniciar", false)
	b_reset.pressed.connect(_on_reset_pressed)
	fila.add_child(b_reset)

	boton_vel = _boton_accion("⏩ %s" % VELOCIDADES[vel_idx].nombre, false)
	boton_vel.pressed.connect(_on_vel_pressed)
	fila.add_child(boton_vel)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(sp)

	var b_validar := _boton_accion("✓ Validar", true)
	b_validar.pressed.connect(_on_validar_pressed)
	fila.add_child(b_validar)

	return fila


# ---------------------------------------------------------------------------
# Pantalla inicial: calma, misma onda cálida. Nombre + tagline + Jugar/Continuar
# + robot. Es un overlay encima del juego (el juego vive detrás); se oculta al jugar.
# ---------------------------------------------------------------------------
func _construir_inicio() -> void:
	inicio_capa = Control.new()
	inicio_capa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inicio_capa.mouse_filter = Control.MOUSE_FILTER_STOP   # tapa el juego de atrás
	add_child(inicio_capa)

	var fondo := ColorRect.new()
	fondo.color = COL_FONDO
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inicio_capa.add_child(fondo)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inicio_capa.add_child(center)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)

	_inicio_robot = Robot.new()
	_inicio_robot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(_inicio_robot)

	var titulo := Label.new()
	titulo.text = "Paso"
	titulo.add_theme_font_override("font", fuente_sans)
	titulo.add_theme_font_size_override("font_size", 72)
	titulo.add_theme_color_override("font_color", COL_TEXTO)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(titulo)

	var tag := Label.new()
	tag.text = "Un juego de lógica: programá la solución, paso a paso."
	tag.add_theme_font_override("font", fuente_sans)
	tag.add_theme_font_size_override("font_size", 18)
	tag.add_theme_color_override("font_color", COL_TENUE)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(tag)

	var esp := Control.new()
	esp.custom_minimum_size = Vector2(0, 18)
	v.add_child(esp)

	var b_jugar := _boton_accion("▶  Jugar", true)
	b_jugar.custom_minimum_size = Vector2(240, 48)
	b_jugar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b_jugar.pressed.connect(_jugar)
	v.add_child(b_jugar)

	_btn_continuar = _boton_accion("Continuar", false)
	_btn_continuar.custom_minimum_size = Vector2(240, 44)
	_btn_continuar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_btn_continuar.pressed.connect(_continuar)
	v.add_child(_btn_continuar)


func _mostrar_inicio() -> void:
	_detener()
	_cerrar_tutorial()
	if _btn_continuar:
		var u := Puntajes.ultimo_nivel()
		var idx := orden.find(u)
		if idx >= 0:
			_btn_continuar.visible = true
			_btn_continuar.text = "Continuar  ·  nivel %d" % (idx + 1)
		else:
			_btn_continuar.visible = false
	if _inicio_robot:
		_inicio_robot.set_mood("feliz")
	inicio_capa.visible = true
	inicio_capa.move_to_front()


func _jugar() -> void:
	inicio_capa.visible = false
	_cargar_indice(0)


func _continuar() -> void:
	inicio_capa.visible = false
	var idx := orden.find(Puntajes.ultimo_nivel())
	_cargar_indice(idx if idx >= 0 else 0)


# ---------------------------------------------------------------------------
# Editor de programa: API que MUTA `programa` (data).
# ---------------------------------------------------------------------------
func agregar_op(op: String) -> void:
	var instr: Array
	if op in OPS_CON_SLOT:
		instr = [op, 0]
	elif op == "ETIQUETA":
		instr = [op, _proximo_nombre_etiqueta()]
	elif op in OPS_CON_ETIQUETA:
		var labels := _etiquetas_existentes()
		instr = [op, labels[0] if not labels.is_empty() else null]
	else:
		instr = [op, null]
	programa.append(instr)
	_repintar_programa()
	_reset_corrida()
	if sfx:
		sfx.colocar()


func mover_linea(i: int, delta: int) -> void:
	var j := i + delta
	if i < 0 or i >= programa.size() or j < 0 or j >= programa.size():
		return
	var tmp = programa[i]
	programa[i] = programa[j]
	programa[j] = tmp
	_repintar_programa()
	_reset_corrida()
	if sfx:
		sfx.click()


func borrar_linea(i: int) -> void:
	if i < 0 or i >= programa.size():
		return
	programa.remove_at(i)
	_repintar_programa()
	_reset_corrida()
	if sfx:
		sfx.click()


func set_arg(i: int, valor) -> void:
	if i < 0 or i >= programa.size():
		return
	programa[i][1] = valor
	_reset_corrida()


func _etiquetas_existentes() -> Array:
	var r := []
	for instr in programa:
		if instr[0] == "ETIQUETA" and instr.size() > 1 and instr[1] != null:
			r.append(instr[1])
	return r


func _proximo_nombre_etiqueta() -> String:
	var usados := {}
	for nombre in _etiquetas_existentes():
		usados[nombre] = true
	var n := 1
	while usados.has("L%d" % n):
		n += 1
	return "L%d" % n


func _repintar_programa() -> void:
	filas_op.clear()
	filas_panel.clear()
	filas_sb.clear()
	for hijo in programa_vbox.get_children():
		hijo.queue_free()
	if programa.is_empty():
		var vacio := _etiqueta("// vacío — tocá una instrucción de arriba", 14, COL_TENUE)
		vacio.add_theme_font_override("font", fuente_mono)
		programa_vbox.add_child(vacio)
		return
	var labels := _etiquetas_existentes()
	for i in programa.size():
		programa_vbox.add_child(_construir_fila(i, labels))


func _construir_fila(i: int, labels: Array) -> Control:
	var instr = programa[i]
	var op: String = instr[0]
	var arg = instr[1] if instr.size() > 1 else null

	# Cada fila es un PanelContainer: su fondo se resalta cuando es la linea actual.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_corner_radius_all(7)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	sb.border_width_left = 3
	sb.border_color = Color(0, 0, 0, 0)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", sb)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filas_panel.append(pc)
	filas_sb.append(sb)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_child(fila)

	var idx := _etiqueta("%2d" % i, 13, COL_TENUE)
	idx.add_theme_font_override("font", fuente_mono)
	idx.custom_minimum_size = Vector2(24, 0)
	fila.add_child(idx)

	# El label del op (mono): es lo que se resalta por pc y recibe el pulso.
	var lop := _etiqueta(OP_LABEL.get(op, op), 16, COL_TEXTO)
	lop.add_theme_font_override("font", fuente_mono)
	lop.custom_minimum_size = Vector2(170, 0)
	lop.pivot_offset = Vector2(10, 12)
	fila.add_child(lop)
	filas_op.append(lop)

	if op in OPS_CON_SLOT:
		var ob := OptionButton.new()
		ob.focus_mode = Control.FOCUS_NONE
		ob.add_theme_font_override("font", fuente_mono)
		for s in cantidad_slots:
			ob.add_item("memoria %d" % s)         # items en orden 0..n-1 => indice == slot
		var sel: int = int(arg) if typeof(arg) == TYPE_INT else 0
		ob.select(clampi(sel, 0, max(0, cantidad_slots - 1)))
		ob.item_selected.connect(func(s_idx): set_arg(i, s_idx))
		fila.add_child(ob)
	elif op == "ETIQUETA":
		var le := _etiqueta(str(arg), 16, COL_ACENTO)
		le.add_theme_font_override("font", fuente_mono)
		fila.add_child(le)
	elif op in OPS_CON_ETIQUETA:
		fila.add_child(_dropdown_destino(i, arg, labels))

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(sp)

	var up := _boton_mini("▲")
	up.pressed.connect(func(): mover_linea(i, -1))
	fila.add_child(up)
	var dn := _boton_mini("▼")
	dn.pressed.connect(func(): mover_linea(i, 1))
	fila.add_child(dn)
	var del := _boton_mini("✕")
	del.pressed.connect(func(): borrar_linea(i))
	fila.add_child(del)

	return pc


func _dropdown_destino(i: int, arg, labels: Array) -> OptionButton:
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_NONE
	ob.add_theme_font_override("font", fuente_mono)
	ob.add_item("—")
	ob.set_item_metadata(0, null)
	var sel := 0
	for nombre in labels:
		ob.add_item(nombre)
		ob.set_item_metadata(ob.get_item_count() - 1, nombre)
		if arg == nombre:
			sel = ob.get_item_count() - 1
	if typeof(arg) == TYPE_STRING and not labels.has(arg):
		ob.add_item("⚠ %s" % arg)
		ob.set_item_metadata(ob.get_item_count() - 1, arg)
		sel = ob.get_item_count() - 1
	ob.select(sel)
	ob.item_selected.connect(func(s_idx): set_arg(i, ob.get_item_metadata(s_idx)))
	return ob


# ---------------------------------------------------------------------------
# Simulacion: step / run / reset. Todo pasa por el Interprete (sin cambios).
# ---------------------------------------------------------------------------
func _avanzar() -> int:
	if estado.terminado:
		return -1
	var pc_ejecutado: int = estado.pc
	var cuenta := true
	if pc_ejecutado < 0 or pc_ejecutado >= programa_run.size():
		cuenta = false
	else:
		var op: String = programa_run[pc_ejecutado][0]
		if op == "ETIQUETA":
			cuenta = false
		elif op == "TOMAR" and estado.entrada.is_empty():
			cuenta = false
	Interprete.ejecutar_paso(estado, programa_run)
	if cuenta:
		pasos += 1
	return pc_ejecutado


func _on_step_pressed() -> void:
	_detener()
	_paso()


func _on_run_pressed() -> void:
	if corriendo:
		_detener()
	else:
		_correr()


func _on_reset_pressed() -> void:
	_reset_corrida()


func _on_vel_pressed() -> void:
	vel_idx = (vel_idx + 1) % VELOCIDADES.size()
	timer.wait_time = VELOCIDADES[vel_idx].paso
	boton_vel.text = "⏩ %s" % VELOCIDADES[vel_idx].nombre
	if sfx:
		sfx.click()


func _on_validar_pressed() -> void:
	if nivel == null:
		return
	var r := Validador.validar(nivel, programa)
	if r.motivo != "":
		# Rechazo estructural: mensaje humano, en clave de tipos/IDE, con pista.
		validacion_label.text = "✗  %s" % _humanizar_motivo(r.motivo)
		validacion_label.add_theme_color_override("font_color", COL_ERROR)
		if robot:
			robot.set_mood("animo")
		if sfx:
			sfx.fail()
		return

	var sc := "%d instrucciones · %d pasos" % [r.score.instrucciones, r.score.pasos]
	if r.paso:
		if not resueltos.has(nivel.id):
			resueltos[nivel.id] = true
			_repintar_progreso()
			_repintar_cabecera()
		var es_par: bool = r.score.instrucciones <= nivel.par_instrucciones and r.score.pasos <= nivel.par_pasos
		var es_record: bool = Puntajes.registrar(nivel.id, r.score.instrucciones, r.score.pasos)
		_repintar_meta()
		var extra := ""
		if es_record:
			extra += "    🎉 ¡nuevo récord!"
		elif es_par:
			extra += "    ★ ¡objetivo!"
		validacion_label.text = "✓ ¡PASÓ!  ·  %s%s" % [sc, extra]
		validacion_label.add_theme_color_override("font_color", COL_OK)
		if robot:
			robot.set_mood("fiesta" if es_record else "feliz")
		if sfx:
			if es_record:
				sfx.record()
			else:
				sfx.win()
		_celebrar(r.score.instrucciones, r.score.pasos, es_par, es_record)
	else:
		validacion_label.text = "✗  %s" % _mensaje_falla(r)
		validacion_label.add_theme_color_override("font_color", COL_ERROR)
		if robot:
			robot.set_mood("animo")
		if sfx:
			sfx.fail()


func _paso() -> void:
	var mano_antes = estado.mano
	var pc := _avanzar()
	redibujar()
	if pc >= 0:
		_animar(pc, mano_antes)
		if sfx:
			sfx.tick()
		if robot and not estado.terminado:
			robot.set_mood("pensando")
	if estado.terminado:
		_detener()
		if robot:
			robot.set_mood("idle")


func _correr() -> void:
	if estado.terminado:
		return
	corriendo = true
	boton_run.text = "⏸ Pausa"
	if robot:
		robot.set_mood("pensando")
	timer.start()


func _detener() -> void:
	corriendo = false
	if boton_run:
		boton_run.text = "▶ Correr"
	if timer:
		timer.stop()


func _on_tick() -> void:
	if estado.terminado:
		_detener()
		return
	_paso()


func _reset_corrida() -> void:
	_detener()
	estado = Interprete.Estado.new(entrada_inicial, cantidad_slots)
	programa_run = Interprete.resolver_etiquetas(programa)
	pasos = 0
	if validacion_label:
		validacion_label.text = ""
	if robot:
		robot.set_mood("idle")
	redibujar()


# ---------------------------------------------------------------------------
# Render: "foto" del estado. Es funcion del estado, no guarda nada propio.
# ---------------------------------------------------------------------------
func redibujar() -> void:
	mano_label.text = _str_valor(estado.mano)

	_actualizar_memoria(estado.slots)
	_pintar_fila(entrada_box, estado.entrada, false)
	_pintar_fila(salida_box, estado.salida, false)

	# Resalte de la linea actual (fondo + texto coral) + "latido" sutil.
	if _tween_beat and _tween_beat.is_valid():
		_tween_beat.kill()
	for i in filas_op.size():
		var l: Label = filas_op[i]
		var sb: StyleBoxFlat = filas_sb[i] if i < filas_sb.size() else null
		var es_actual: bool = not estado.terminado and i == estado.pc
		if es_actual:
			l.add_theme_color_override("font_color", COL_ACENTO)
			if sb:
				sb.bg_color = COL_ACENTO_TENUE
				sb.border_color = COL_ACENTO
		else:
			l.add_theme_color_override("font_color", COL_TEXTO)
			if sb:
				sb.bg_color = Color(0, 0, 0, 0)
				sb.border_color = Color(0, 0, 0, 0)

	# Latido de la linea actual (cosmetico; respeta el estado).
	if not estado.terminado and estado.pc >= 0 and estado.pc < filas_panel.size():
		var pcn: PanelContainer = filas_panel[estado.pc]
		pcn.modulate = Color.WHITE
		_tween_beat = create_tween().set_loops()
		_tween_beat.tween_property(pcn, "modulate", Color(1.06, 1.0, 0.95), 0.55).set_trans(Tween.TRANS_SINE)
		_tween_beat.tween_property(pcn, "modulate", Color.WHITE, 0.55).set_trans(Tween.TRANS_SINE)

	if estado.terminado:
		estado_label.text = "TERMINADO  ·  pasos: %d  ·  líneas: %d  ·  salen: %s" % [
			pasos, programa.size(), str(estado.salida)]
		estado_label.add_theme_color_override("font_color", COL_OK)
	else:
		estado_label.text = "pasos: %d  ·  líneas: %d" % [pasos, programa.size()]
		estado_label.add_theme_color_override("font_color", COL_TENUE)


# Memoria tipada: se construye UNA vez por nivel (cada slot = columna "int memoriaN"
# + su celda). Asi las celdas tienen un rect estable y los valores que vuelan
# aterrizan en la CASILLA, no encima de la etiqueta. redibujar solo actualiza texto.
func _construir_memoria() -> void:
	slot_celdas.clear()
	for hijo in slots_box.get_children():
		hijo.queue_free()
	if cantidad_slots <= 0:
		slots_box.add_child(_etiqueta("(este nivel no usa memoria)", 13, COL_TENUE))
		return
	for i in cantidad_slots:
		var colm := VBoxContainer.new()
		colm.add_theme_constant_override("separation", 4)
		colm.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var cap := _etiqueta("int memoria%d" % i, 12, COL_TENUE)
		cap.add_theme_font_override("font", fuente_mono)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		colm.add_child(cap)
		var celda := _celda(COL_CELDA)
		colm.add_child(celda)
		slots_box.add_child(colm)
		slot_celdas.append(celda)


func _actualizar_memoria(valores: Array) -> void:
	for i in slot_celdas.size():
		var v = valores[i] if i < valores.size() else null
		slot_celdas[i].get_child(0).text = _str_valor(v)


func _pintar_fila(box: HBoxContainer, valores: Array, mostrar_vacias: bool) -> void:
	for hijo in box.get_children():
		hijo.queue_free()
	if valores.is_empty() and not mostrar_vacias:
		box.add_child(_etiqueta("·", 18, COL_TENUE))
		return
	for i in valores.size():
		var celda := _celda(COL_CELDA)
		celda.get_child(0).text = _str_valor(valores[i])
		box.add_child(celda)


# ---------------------------------------------------------------------------
# Juice: animacion de la ejecucion. Cosmetica pura; nunca muta el estado.
# ---------------------------------------------------------------------------
func _dur_anim() -> float:
	# Run usa la velocidad elegida; Step (no corriendo) va mas lento para que se lea.
	return VELOCIDADES[vel_idx].anim if corriendo else 0.34


func _animar(pc_ejecutado: int, mano_antes) -> void:
	if pc_ejecutado < 0 or pc_ejecutado >= filas_op.size():
		return
	var dur := _dur_anim()

	# Pulso (pop) sobre la linea ejecutada.
	var l: Label = filas_op[pc_ejecutado]
	l.scale = Vector2.ONE
	var tp := create_tween()
	tp.tween_property(l, "scale", Vector2(1.18, 1.18), dur * 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tp.tween_property(l, "scale", Vector2.ONE, dur * 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var instr = programa[pc_ejecutado]
	var op: String = instr[0]
	var arg = instr[1] if instr.size() > 1 else null
	match op:
		"TOMAR":
			_volar(_str_valor(estado.mano), entrada_box, mano_celda, COL_MANO, dur)
			_pop(mano_celda, dur)
		"SOLTAR":
			_volar(_str_valor(mano_antes), mano_celda, salida_box, COL_MANO, dur)
			_pop_ultimo(salida_box, dur)
		"GUARDAR":
			var destino = _slot_celda(arg)
			if destino:
				_volar(_str_valor(mano_antes), mano_celda, destino, COL_ACENTO, dur)
				_brillo(destino, dur)
		"COPIAR":
			var origen = _slot_celda(arg)
			if origen:
				_volar(_str_valor(estado.mano), origen, mano_celda, COL_ACENTO, dur)
			_pop(mano_celda, dur)
		"SUMAR", "RESTAR":
			var sc = _slot_celda(arg)
			if sc:
				_brillo(sc, dur)
			_pop(mano_celda, dur)


func _slot_celda(arg):
	if typeof(arg) == TYPE_INT and arg >= 0 and arg < slot_celdas.size():
		return slot_celdas[arg]
	return null


# Crea un label temporal y lo desplaza de un nodo a otro, con rebote y pop final.
func _volar(texto: String, desde: Control, hacia: Control, color: Color, dur: float) -> void:
	if texto == "" or texto == "·" or capa_anim == null:
		return
	var r_desde := desde.get_global_rect()
	var r_hacia := hacia.get_global_rect()
	if r_desde.size == Vector2.ZERO or r_hacia.size == Vector2.ZERO:
		return  # layout sin resolver (tests headless): no animamos

	var fsize := 24
	var flotante := Label.new()
	flotante.text = texto
	flotante.mouse_filter = Control.MOUSE_FILTER_IGNORE   # cosmetico: nunca come clicks
	flotante.add_theme_font_override("font", fuente_mono)
	flotante.add_theme_font_size_override("font_size", fsize)
	flotante.add_theme_color_override("font_color", color)
	# Centramos el glifo sobre el CENTRO de cada casilla (no sobre su etiqueta).
	var medio := fuente_mono.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize) * 0.5
	flotante.pivot_offset = medio
	var p0 := r_desde.position + r_desde.size * 0.5 - medio
	var p1 := r_hacia.position + r_hacia.size * 0.5 - medio
	flotante.position = p0
	flotante.scale = Vector2(0.6, 0.6)
	capa_anim.add_child(flotante)

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(flotante, "position", p1, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(flotante, "scale", Vector2(1.25, 1.25), dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(flotante, "scale", Vector2(0.4, 0.4), dur * 0.3)
	t.parallel().tween_property(flotante, "modulate:a", 0.0, dur * 0.3)
	t.chain().tween_callback(flotante.queue_free)


# "Pop": rebote de escala en una celda al recibir un valor.
func _pop(nodo: Control, dur: float) -> void:
	if nodo == null or nodo.get_global_rect().size == Vector2.ZERO:
		return
	nodo.pivot_offset = nodo.size * 0.5
	nodo.scale = Vector2.ONE
	var t := create_tween()
	t.tween_property(nodo, "scale", Vector2(1.22, 1.22), dur * 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(nodo, "scale", Vector2.ONE, dur * 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _pop_ultimo(box: HBoxContainer, dur: float) -> void:
	var n := box.get_child_count()
	if n > 0:
		var ultimo := box.get_child(n - 1)
		if ultimo is Control:
			_pop(ultimo, dur)


# Brillo de la memoria al escribirse: destello coral del borde/fondo de la celda.
func _brillo(celda: Panel, dur: float) -> void:
	if celda == null or celda.get_global_rect().size == Vector2.ZERO:
		return
	var sb := celda.get_theme_stylebox("panel")
	if sb is StyleBoxFlat:
		var original: Color = COL_CELDA
		var t := create_tween()
		t.tween_method(func(c): sb.bg_color = c, COL_ACENTO_TENUE.lerp(COL_ACENTO, 0.4), original, dur * 1.4)\
			.set_trans(Tween.TRANS_SINE)
	_pop(celda, dur)


# Celebracion al pasar: banner PROLIJO en espacio libre (sobre el escenario), no
# tapa el programa ni es sobredimensionado. Trae onda suave LOCALIZADA + conteo de
# puntaje + ★/récord, y es descartable (click) ademas de auto-desvanecerse.
func _celebrar(score_instr: int, score_pasos: int, es_par: bool, es_record: bool) -> void:
	if capa_anim == null or capa_anim.get_global_rect().size == Vector2.ZERO:
		return
	# Centro del banner: arriba del escenario (espacio libre a la derecha), nunca
	# sobre el panel del programa. Si no hay rect (headless), salimos.
	var area := escenario_col.get_global_rect() if escenario_col else Rect2()
	if area.size == Vector2.ZERO:
		return
	var capa_rect := capa_anim.get_global_rect()
	var ancho := 228.0
	# Espacio libre: franja DERECHA del escenario, DEBAJO del robot. Asi no pisa ni
	# al robot (arriba a la derecha) ni las etiquetas de la izquierda (en la mano /
	# memoriaN), que quedan a la izquierda de esta franja.
	var local := area.position - capa_rect.position
	var centro := local + Vector2(area.size.x - ancho * 0.5 - 4.0, 215.0)

	# Onda(s) localizadas alrededor del banner (radio chico).
	for k in (3 if es_record else 2):
		var o := Onda.new()
		o.color = COL_ACENTO
		o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		o.mouse_filter = Control.MOUSE_FILTER_IGNORE
		capa_anim.add_child(o)
		o.lanzar(centro, 36.0 + k * 30.0, 0.85 + k * 0.12)

	# Banner: tarjeta compacta con titular + conteo + hint para cerrar.
	var banner := _panel(COL_PANEL)
	banner.custom_minimum_size = Vector2(ancho, 0)
	banner.mouse_filter = Control.MOUSE_FILTER_STOP   # click = descartar

	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 4)
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE        # el click lo cacha el banner entero
	banner.add_child(bv)

	var titular := Label.new()
	titular.mouse_filter = Control.MOUSE_FILTER_IGNORE
	titular.add_theme_font_override("font", fuente_sans)
	titular.add_theme_font_size_override("font_size", 22)
	titular.add_theme_color_override("font_color", COL_ACENTO)
	titular.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titular.text = "🎉 ¡Nuevo récord!" if es_record else ("★ ¡Objetivo!" if es_par else "✓ ¡Pasó!")
	bv.add_child(titular)

	var sub := Label.new()
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.add_theme_font_override("font", fuente_mono)
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", COL_TEXTO)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(sub)

	var hint := Label.new()
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_font_override("font", fuente_sans)
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", COL_TENUE)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.text = "tocá para cerrar"
	bv.add_child(hint)

	capa_anim.add_child(banner)
	# Posicionar centrado horizontalmente sobre el escenario, tras un frame de layout.
	banner.position = centro - Vector2(ancho * 0.5, 40.0)
	banner.pivot_offset = Vector2(ancho * 0.5, 40.0)
	banner.scale = Vector2(0.85, 0.85)

	var entra := create_tween()
	entra.tween_property(banner, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Conteo del puntaje hacia arriba (dopamina barata).
	var cuenta := create_tween()
	cuenta.tween_method(
		func(v): sub.text = "%d instrucciones\n%d pasos" % [int(v), score_pasos],
		0.0, float(score_instr), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Descartar: por click o auto a los ~3.2s.
	banner.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_descartar_banner(banner))
	var auto := create_tween()
	auto.tween_interval(3.2)
	auto.tween_callback(func(): _descartar_banner(banner))


func _descartar_banner(banner: Control) -> void:
	if not is_instance_valid(banner) or banner.has_meta("cerrando"):
		return
	banner.set_meta("cerrando", true)
	var t := create_tween()
	t.tween_property(banner, "modulate:a", 0.0, 0.25)
	t.tween_callback(func(): if is_instance_valid(banner): banner.queue_free())


# ---------------------------------------------------------------------------
# Mensajes de error: humanos, en clave de tipos/IDE, con pista (sin regalar la solucion).
# ---------------------------------------------------------------------------
func _humanizar_motivo(motivo: String) -> String:
	if motivo.contains("no permitida"):
		return "%s  —  esa instrucción no está habilitada en este nivel. Usá solo las de arriba." % motivo
	if motivo.contains("Slot"):
		return "Esa 'memoriaN' no existe en este nivel (índice fuera de rango). Elegí una memoria válida del desplegable."
	if motivo.contains("Etiqueta desconocida"):
		return "%s  —  el salto apunta a una etiqueta que ya no está. Reapuntá el destino o creá la etiqueta." % motivo
	if motivo.contains("destino"):
		return "Un salto quedó sin destino. Elegí a qué etiqueta tiene que saltar."
	return motivo


func _mensaje_falla(r) -> String:
	# Primer caso que fallo: lo necesita para debuggear.
	for d in r.detalle_por_caso:
		if not d.ok:
			if not d.termino:
				return "Con entrada %s el programa no terminó (¿un loop sin salida?). Revisá tus saltos." % str(d.entrada)
			var esperada: Array = d.salida_esperada
			var obtenida: Array = d.salida_obtenida
			# Primer lugar donde difieren.
			var n: int = min(esperada.size(), obtenida.size())
			for k in n:
				if esperada[k] != obtenida[k]:
					return "Casi 👀  con %s: en el %s lugar iba %d (int) y saliste %d. Revisá el orden en que guardás/recuperás de memoria." % [
						str(d.entrada), _ordinal(k + 1), int(esperada[k]), int(obtenida[k])]
			# Mismo prefijo, distinta cantidad.
			if obtenida.size() < esperada.size():
				return "Casi  con %s: salieron de menos. Esperaba %d valores y salieron %d. ¿Te faltó un SOLTAR?" % [
					str(d.entrada), esperada.size(), obtenida.size()]
			return "Casi  con %s: salieron de más. Esperaba %d valores y salieron %d. ¿Soltaste algo de más?" % [
				str(d.entrada), esperada.size(), obtenida.size()]
	return "No pasó. Revisá la salida."


func _ordinal(n: int) -> String:
	match n:
		1: return "1er"
		2: return "2do"
		3: return "3er"
		4: return "4to"
		5: return "5to"
		6: return "6to"
		_: return "%d°" % n


# Modelo del programa, accesible para generar despues el panel "ver en C#".
# (No se renderiza ahora; es el hook que pide la proxima tanda.)
func programa_modelo() -> Dictionary:
	var lineas := []
	for instr in programa:
		lineas.append({
			"op": instr[0],
			"arg": instr[1] if instr.size() > 1 else null,
			"etiqueta_amigable": OP_LABEL.get(instr[0], instr[0]),
		})
	return {
		"nivel": nivel.id if nivel else "",
		"slots": cantidad_slots,
		"lineas": lineas,
	}


# ---------------------------------------------------------------------------
# Tutorial con spotlight (solo niveles 1-2, dismissable, no invasivo).
# ---------------------------------------------------------------------------
func _puede_tutorial() -> bool:
	return DisplayServer.get_name() != "headless"


func _quizas_tutorial() -> void:
	if not _puede_tutorial() or nivel == null:
		return
	if inicio_capa and inicio_capa.visible:
		return                                   # no arrancamos el tutorial bajo la pantalla inicial
	if nivel_idx > 1:
		return
	if Puntajes.flag("tuto_" + nivel.id):
		return
	# Esperamos a que el layout resuelva los rects antes de apuntar el spotlight.
	_tuto_pasos = _pasos_tutorial(nivel.id)
	_tuto_i = 0
	call_deferred("_tutorial_arrancar")


func _pasos_tutorial(id: String) -> Array:
	# Cada paso: {texto, objetivo} donde objetivo es un Callable -> Control (o null).
	var p := [
		{"texto": "¡Hola! Soy tu copiloto. Te muestro cómo se juega — tocá « Siguiente ».",
			"objetivo": func(): return null},
		{"texto": "Esto es lo que ENTRA: una fila de números (int). Hay que procesarlos y sacarlos.",
			"objetivo": func(): return entrada_box},
		{"texto": "Estas son tus instrucciones. Tocá « agarrá » para agregarla a tu programa.",
			"objetivo": func(): return paleta_box},
		{"texto": "Tu programa se arma acá, línea por línea — como código.",
			"objetivo": func(): return programa_vbox},
		{"texto": "Mientras corre, mirá « en la mano » (sostenés un valor), « memoria » y « salen ».",
			"objetivo": func(): return mano_celda},
		{"texto": "Tocá ▶ Correr para verlo en acción, o ⏯ Paso para ir de a uno. ¡Probá!",
			"objetivo": func(): return boton_run},
	]
	if id == "b2_invertir_par":
		p = [
			{"texto": "Nuevo: la MEMORIA. Guardás un valor con « guardá » y lo traés de vuelta con « recuperá ».",
				"objetivo": func(): return slots_box},
			{"texto": "Pista: para invertir, guardá el primero, sacá el segundo y recién ahí soltá el guardado.",
				"objetivo": func(): return programa_vbox},
		]
	return p


func _tutorial_arrancar() -> void:
	if _tuto_pasos.is_empty():
		return
	for hijo in tutorial_capa.get_children():
		hijo.queue_free()

	_spotlight = Spotlight.new()
	_spotlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_spotlight.mouse_filter = Control.MOUSE_FILTER_STOP   # captura clicks (overlay guiado)
	tutorial_capa.add_child(_spotlight)

	# Globito del robot (panel + texto + botones). Guardamos referencias directas
	# (los nodos son nietos del panel: get_node por nombre no los encontraria).
	var globo := _panel(COL_PANEL)
	globo.custom_minimum_size = Vector2(380, 0)
	var gv := VBoxContainer.new()
	gv.add_theme_constant_override("separation", 10)
	globo.add_child(gv)

	_tuto_txt = Label.new()
	_tuto_txt.add_theme_font_override("font", fuente_sans)
	_tuto_txt.add_theme_font_size_override("font_size", 16)
	_tuto_txt.add_theme_color_override("font_color", COL_TEXTO)
	_tuto_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tuto_txt.custom_minimum_size = Vector2(356, 0)
	gv.add_child(_tuto_txt)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	var saltar := _boton_accion("Saltar tutorial", false)
	saltar.pressed.connect(_saltar_tutorial)
	fila.add_child(saltar)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(sp)
	_tuto_btn_sig = _boton_accion("Siguiente ▸", true)
	_tuto_btn_sig.pressed.connect(_tutorial_siguiente)
	fila.add_child(_tuto_btn_sig)
	gv.add_child(fila)

	_tuto_globo = globo
	tutorial_capa.add_child(globo)
	tutorial_capa.visible = true
	if robot:
		robot.set_mood("idle")
	_tutorial_mostrar_paso()


func _tutorial_mostrar_paso() -> void:
	if _tuto_i >= _tuto_pasos.size():
		_cerrar_tutorial()
		Puntajes.set_flag("tuto_" + nivel.id, true)
		return
	var paso = _tuto_pasos[_tuto_i]
	var globo := _tuto_globo
	if _tuto_txt:
		_tuto_txt.text = paso.texto
	if _tuto_btn_sig:
		_tuto_btn_sig.text = "¡Dale! ✓" if _tuto_i == _tuto_pasos.size() - 1 else "Siguiente ▸"

	# Apuntar el spotlight al objetivo (o sin foco si null/rect sin resolver).
	var objetivo_node = paso.objetivo.call()
	var rect := Rect2()
	if objetivo_node is Control:
		rect = objetivo_node.get_global_rect()
	_spotlight.objetivo = rect.grow(8.0) if rect.size != Vector2.ZERO else Rect2()
	_spotlight.queue_redraw()

	# Posicionar el globito: debajo del objetivo si hay, si no centrado.
	# Esperamos 2 frames a que el layout del panel (label con autowrap) se asiente,
	# si no su alto sale enorme y el globo se va de pantalla.
	if globo:
		await get_tree().process_frame
		await get_tree().process_frame
		# El tutorial pudo cerrarse (navegacion/skip) mientras esperabamos.
		if not is_instance_valid(globo) or not tutorial_capa.visible:
			return
		var gs: Vector2 = globo.size
		var pos: Vector2
		if rect.size != Vector2.ZERO:
			pos = Vector2(rect.position.x, rect.position.y + rect.size.y + 14)
		else:
			pos = (size - gs) * 0.5
		# Siempre dentro de pantalla.
		pos.x = clampf(pos.x, 20, maxf(20, size.x - gs.x - 20))
		pos.y = clampf(pos.y, 20, maxf(20, size.y - gs.y - 20))
		globo.position = pos


func _tutorial_siguiente() -> void:
	_tuto_i += 1
	if sfx:
		sfx.click()
	_tutorial_mostrar_paso()


func _saltar_tutorial() -> void:
	if nivel:
		Puntajes.set_flag("tuto_" + nivel.id, true)
	_cerrar_tutorial()


func _cerrar_tutorial() -> void:
	if tutorial_capa == null:
		return
	tutorial_capa.visible = false
	for hijo in tutorial_capa.get_children():
		hijo.queue_free()
	_spotlight = null
	_tuto_globo = null
	_tuto_txt = null
	_tuto_btn_sig = null
	_tuto_pasos = []


# ---------------------------------------------------------------------------
# Helpers de construccion de widgets.
# ---------------------------------------------------------------------------
func _panel(color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(16)
	sb.border_color = COL_PANEL_BORDE
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _celda(color: Color) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(54, 54)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(10)
	sb.border_color = COL_CELDA_BORDE
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)

	var l := Label.new()
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", fuente_mono)
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", COL_TEXTO)
	p.add_child(l)
	return p


func _estilo_boton_paleta(b: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = COL_FONDO
	normal.set_corner_radius_all(9)
	normal.set_content_margin_all(9)
	normal.border_color = COL_CELDA_BORDE
	normal.set_border_width_all(1)
	var hover := normal.duplicate()
	hover.bg_color = COL_ACENTO_TENUE
	hover.border_color = COL_ACENTO
	var pressed := hover.duplicate()
	pressed.bg_color = COL_ACENTO.lerp(COL_FONDO, 0.6)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_color_override("font_color", COL_TEXTO)
	b.add_theme_color_override("font_hover_color", COL_ACENTO)


func _boton_accion(txt: String, acento: bool) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(0, 40)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", fuente_sans)
	var normal := StyleBoxFlat.new()
	normal.set_corner_radius_all(10)
	normal.set_content_margin_all(11)
	if acento:
		normal.bg_color = COL_ACENTO
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
	else:
		normal.bg_color = COL_PANEL
		normal.border_color = COL_PANEL_BORDE
		normal.set_border_width_all(1)
		b.add_theme_color_override("font_color", COL_TEXTO)
		b.add_theme_color_override("font_hover_color", COL_ACENTO)
	var hover := normal.duplicate()
	hover.bg_color = (COL_ACENTO.lerp(Color.BLACK, 0.08) if acento else COL_ACENTO_TENUE)
	var pressed := hover.duplicate()
	pressed.bg_color = (COL_ACENTO.lerp(Color.BLACK, 0.16) if acento else COL_ACENTO.lerp(COL_PANEL, 0.6))
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	return b


func _boton_nav(txt: String) -> Button:
	var b := _boton_accion(txt, false)
	b.custom_minimum_size = Vector2(44, 40)
	return b


func _boton_mini(txt: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(30, 28)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", fuente_sans)
	b.add_theme_color_override("font_color", COL_TENUE)
	b.add_theme_color_override("font_hover_color", COL_ACENTO)
	return b


func _separador() -> HSeparator:
	var s := HSeparator.new()
	var sb := StyleBoxLine.new()
	sb.color = COL_PANEL_BORDE
	s.add_theme_stylebox_override("separator", sb)
	return s


func _etiqueta(texto: String, tam: int, color: Color, espaciada := false) -> Label:
	var l := Label.new()
	l.text = texto.to_upper() if espaciada else texto
	l.add_theme_font_override("font", fuente_sans)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	return l


func _str_valor(v) -> String:
	if v == null:
		return "·"
	return str(v)


# ---------------------------------------------------------------------------
# Inner classes cosmeticas (onda de celebracion + spotlight del tutorial).
# ---------------------------------------------------------------------------

# Onda: anillo coral que se expande y se desvanece. Cosmetico.
class Onda extends Control:
	var color := Color("d97757")
	var _centro := Vector2.ZERO
	var _radio := 0.0
	var _alpha := 0.0

	func lanzar(centro: Vector2, radio_max: float, dur: float) -> void:
		_centro = centro
		var t := create_tween()
		t.set_parallel(true)
		t.tween_method(func(r): _radio = r; queue_redraw(), 8.0, radio_max, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_method(func(a): _alpha = a; queue_redraw(), 0.5, 0.0, dur).set_trans(Tween.TRANS_SINE)
		t.chain().tween_callback(queue_free)

	func _draw() -> void:
		if _alpha <= 0.001:
			return
		var c := Color(color.r, color.g, color.b, _alpha)
		draw_arc(_centro, _radio, 0.0, TAU, 64, c, 3.0, true)


# Spotlight: oscurece la pantalla MENOS un rect (el objetivo), con marco coral.
class Spotlight extends Control:
	var objetivo := Rect2()
	var velo := Color(0.12, 0.11, 0.10, 0.62)
	var marco := Color("d97757")

	func _draw() -> void:
		if objetivo.size == Vector2.ZERO:
			draw_rect(Rect2(Vector2.ZERO, size), velo)
			return
		# 4 rects alrededor del objetivo (deja el hueco transparente).
		var o := objetivo
		draw_rect(Rect2(0, 0, size.x, o.position.y), velo)                                   # arriba
		draw_rect(Rect2(0, o.position.y + o.size.y, size.x, size.y - (o.position.y + o.size.y)), velo)  # abajo
		draw_rect(Rect2(0, o.position.y, o.position.x, o.size.y), velo)                       # izquierda
		draw_rect(Rect2(o.position.x + o.size.x, o.position.y, size.x - (o.position.x + o.size.x), o.size.y), velo)  # derecha
		# Marco coral alrededor del hueco.
		draw_rect(o, marco, false, 2.0)
