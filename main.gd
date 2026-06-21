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

# Ayuda (tooltip) de cada instrucción: una línea clara de qué hace.
const OP_AYUDA := {
	"TOMAR": "agarrá: toma el próximo valor de la entrada y lo deja en la mano.",
	"SOLTAR": "soltá: deja el valor de la mano en la salida (y la mano queda vacía).",
	"COPIAR": "recuperá: copia una memoria a la mano (la memoria no cambia).",
	"GUARDAR": "guardá: copia la mano a una memoria (la mano no cambia).",
	"SUMAR": "sumá: le suma una memoria al valor que tenés en la mano.",
	"RESTAR": "restá: le resta una memoria al valor que tenés en la mano.",
	"SALTAR": "saltá a: salta a una etiqueta (sirve para repetir = loop).",
	"SALTAR_SI_CERO": "si es cero saltá a: si la mano vale 0, salta a una etiqueta; si no, sigue.",
	"ETIQUETA": "etiqueta: marca un punto del programa para poder saltar ahí.",
}

# Leyenda de cada zona del escenario (tooltip explicativo).
const ZONA_AYUDA := {
	"mano": "La mano: sostenés UN valor por vez (int). Casi todo pasa por acá.",
	"memoria": "Memoria: cajitas tipadas (int) para guardar valores y recuperarlos después.",
	"entran": "Entran: la fila de valores que recibís, en orden. Cuando se vacía, el programa termina.",
	"salen": "Salen: lo que vas soltando. Para resolver, tiene que coincidir con lo pedido.",
}

# Mini-demo de la pantalla "Cómo funciona la máquina": un ejemplo de 3 instrucciones
# que se corre solo y lento. Usa el MISMO intérprete (lógica pura) que el juego.
const DEMO_PROG := [["TOMAR", null], ["GUARDAR", 0], ["SOLTAR", null]]
const DEMO_IN := [3, 9]
const DEMO_CAPS := [
	"Esta es la máquina: una fila que ENTRA, la MANO (sostiene un valor a la vez), las MEMORIAS y lo que SALE.",
	"El robot AGARRA el primero de la fila y lo tiene en la mano. Sostiene una sola cosa a la vez.",
	"Lo puede GUARDAR en una memoria para usarlo más tarde (la mano lo sigue teniendo).",
	"…o SOLTARLO a la salida. Eso es todo: agarrar, guardar, soltar. Con eso armás cualquier nivel.",
]

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

# --- Paleta: alias locales que apuntan a Tema (única fuente de verdad, ver tema.gd) ---
# Identidad propia cálida: arena + verde-azulado + verde éxito + ámbar de detalle.
# `var` (no `const`): la paleta de Tema es mutable (tema claro/oscuro). Se inicializan
# con la paleta por defecto y se re-sincronizan en _ready con _sincronizar_colores(),
# después de aplicar el tema guardado. Todo el dibujado lee estos campos por nombre.
var COL_FONDO := Tema.FONDO
var COL_PANEL := Tema.PANEL
var COL_PANEL_BORDE := Tema.PANEL_BORDE
var COL_CELDA := Tema.CELDA
var COL_CELDA_BORDE := Tema.CELDA_BORDE
var COL_TEXTO := Tema.TEXTO
var COL_TENUE := Tema.TENUE
var COL_ACENTO := Tema.PRIMARIO         # el acento ahora es el verde-azulado
var COL_ACENTO_TENUE := Tema.PRIMARIO_TENUE
var COL_MANO := Tema.PRIMARIO
var COL_OK := Tema.EXITO
var COL_ERROR := Tema.ERROR

# --- Identidad / enlaces ---
const VERSION := "1.0"
const URL_REPORTAR_BUG := "https://github.com/AngeloVPerrotta/Paso/issues/new"

# Velocidades: Run rapido / Step lento. paso = seg por tick; anim = duracion de animacion.
# Velocidad ÚNICA fija (la "normal" de antes): un solo ritmo, sin selector.
const VEL_PASO := 0.42                    # seg por paso (timer de la corrida)
const VEL_ANIM := 0.30                    # seg de animación de cada valor al correr

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

# --- Track: "c" (fundamentos) | "csharp" (avanzado). Define niveles + lenguaje del panel. ---
var track := "c"
var _inicio_track_label: Label          # indicador "estás en: …" en el inicio

# --- Panel "Ver en C / C#" ---
var csharp_capa: Control
var csharp_texto: TextEdit
var csharp_titulo: Label                 # "Tu solución en C / C#"
var boton_codigo: Button                 # "‹/› Ver en C / C#" (barra de controles)
var boton_ayuda: Button                  # lamparita de Ayuda: revela «Paso»
var boton_step: Button                   # «Paso» (oculto hasta tocar Ayuda)
var _corrida_auto := false               # la corrida la lanzó el botón unificado → valida al terminar

# --- "Aprendé Git": explicador (Capa 1) + sandbox interactivo (Capa 2), módulos aparte ---
var git_capa: GitExplica
var git_sandbox: GitSandbox

# --- "Cómo funciona la máquina" (intro demo) + modo libre ---
var como_capa: Control
var es_libre := false                   # modo libre: sin objetivo, solo experimentar
var _demo_estado
var _demo_paso_i := 0
var _demo_b_atras: Button
var _demo_b_sig: Button
var _demo_paso_label: Label
var _demo_entrada_box: HBoxContainer
var _demo_salida_box: HBoxContainer
var _demo_mano_celda: Panel
var _demo_mem_celda: Panel
var _demo_caption: Label
var _demo_robot: Robot

# --- Tutorial ---
var tutorial_capa: Control
var _spotlight                          # Spotlight (inner class)
var _tuto_pasos: Array = []
var _tuto_i := 0
var _tuto_globo: PanelContainer
var _tuto_txt: Label
var _tuto_btn_sig: Button
var _tuto_btn_accion: Button            # botón de acción opcional por paso (p.ej. "▶ Ver de nuevo")
var _tuto_accion_cb := Callable()       # callback del botón de acción del paso actual
var _tuto_marca_visto := true           # true: al terminar marca el nivel como "ya visto"
var _tuto_mostrar_como := false         # true SOLO en la leyenda "¿Cómo se juega?": ofrece "Cómo funciona"


# --- Robot-tutor: el robot se asoma a una esquina y comenta en momentos clave ---
# Presentación pura. Textos cortos/rioplatenses (Angelo: cambialos si querés). Flags
# de "primera vez" en Puntajes (vio_robot_*): "Reiniciar progreso" los borra solos.
const TUTOR_PRIMER_PROG := "¡Buen comienzo! Apilá las órdenes y yo las hago una por una, de arriba a abajo."
# Sub-tanda D: puente "lo que armaste = código real". %s = nombre del track (C / C#).
const TUTOR_CODIGO_GANAR := "¡Lo resolviste! Esto que armaste, en %s real se ve así 👇  Ya es código que compila."
const TUTOR_PANEL_CODIGO := "Tu programa, traducido a %s real — comentado, como lo escribirías de verdad."
var tutor_capa: Control                  # overlay propio (no se encima con tutorial_capa/spotlight)
var _tutorbot: Robot                     # robot que se asoma (reusa robot.gd)
var _tutor_burbuja: PanelContainer       # burbuja del comentario (mismo mecanismo que el tutorial)
var _tutor_activo := false               # hay un comentario en pantalla
var _tutor_cerrando := false             # cierre en curso (evita doble disparo)
var _tutor_tween: Tween
var _tutor_origen := Vector2.ZERO        # posición del robot real (para volver)
var _gano_pendiente := false             # al cerrar el banner: mostrar el código traducido + el robot
var _codigo_modo_ganar := false          # el panel de código está en modo "al ganar" (Seguir/Siguiente)
var _codigo_x: Button                    # ✕ del panel (se oculta en modo ganar)
var _codigo_footer: HBoxContainer        # footer del panel en modo ganar (Seguir / Siguiente nivel)

# --- Humor (presentación pura): saludos contextuales, comentarios al ganar, gato, idle ---
# Secos, una línea, rioplatense. Sin signos de más, sin "jaja", sin emojis de risa.
const SALUDOS_MADRUGADA := ["Buenas, noctámbulo.", "A esta hora se piensa mejor."]
const SALUDOS_MANANA := ["Café y lógica.", "Día de puzzles.", "Arrancamos."]
const SALUDOS_TARDE := ["Seguimos donde quedamos.", "Otra vez por acá.", "La tarde rinde."]
const SALUDOS_NOCHE := ["De vuelta.", "La noche es de los que piensan."]
const SALUDOS_GENERICOS := ["Por acá de nuevo.", "Listo cuando vos."]
const SALUDO_FINDE := "Finde de código."
const CHISTES_GANAR := [
	"Funcionó a la primera. Sospechoso.",
	"Funciona y no sé por qué. Dejémoslo así.",
	"Eso es un bug. Bueno, una feature no documentada.",
	"Menos líneas. Tu yo del futuro te lo agradece.",
	"Salió. No toques nada.",
	"Cero warnings. Hoy es un buen día.",
	"Funciona en mi máquina.",
	"Si funciona, no es estúpido.",
]
const CHISTE_PROB := 0.5                 # prob. de soltar un comentario al ganar (cuando NO se muestra el código)
const IDLE_SEG := 45.0                   # segundos quieto antes de que el robot cabecee
var _inicio_saludo: Label                # línea de saludo contextual en la pantalla de inicio
var _ultimo_saludo := ""                 # para no repetir el saludo dos veces seguidas
var _chistes_baraja: Array = []          # cola barajada de índices (rotación SIN repetir hasta agotar)
var _idle_t := 0.0                       # segundos sin input del jugador
var _dormido := false                    # el robot del juego está cabeceando

# Charla ocasional: al clickear el robot suelta una frase seca (reusa el pool de chistes
# + saludos genéricos y la burbuja del tutor). Auto-cierra a los pocos segundos o al click.
const CHARLA_SEG := 4.5                   # auto-cierre de la burbuja de charla
var _charla_activa := false              # hay una burbuja de charla en pantalla
var _ultima_charla := ""                 # frase anterior (para no repetirla)
var _charla_id := 0                      # token: el timer solo cierra SU propia burbuja


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Tema guardado primero: aplica la paleta y re-sincroniza los COL_ antes de
	# que cualquier _construir_* hornee colores en los widgets.
	Tema.aplicar(_tema_guardado())
	_sincronizar_colores()
	fuente_mono = SystemFont.new()
	fuente_mono.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "JetBrains Mono", "DejaVu Sans Mono", "monospace"])
	fuente_sans = SystemFont.new()
	fuente_sans.font_names = PackedStringArray(["Segoe UI", "Inter", "Helvetica Neue", "Arial", "sans-serif"])

	sfx = Sfx.new()
	add_child(sfx)

	track = Puntajes.track()
	orden = Niveles.orden_track(track)
	_construir_ui()
	_construir_inicio()
	git_capa = GitExplica.new()          # "Aprendé Git" Capa 1 (oculto hasta abrir)
	add_child(git_capa)
	git_sandbox = GitSandbox.new()       # Capa 2: consola interactiva
	add_child(git_sandbox)
	git_capa.abrir_consola.connect(git_sandbox.abrir)
	_refrescar_track_ui()
	_cargar_indice(0)
	_mostrar_inicio()
	_arrancado = true


# Idle (humor sutil): si el jugador deja el juego quieto un rato, el robot del nivel
# cabecea (ojos cerrados). Cualquier input lo despierta. No corre en headless/tests.
func _input(event: InputEvent) -> void:
	_idle_t = 0.0
	if _dormido:
		_dormido = false
		if robot and robot.mood == "dormido":
			robot.set_mood("idle")
	# Click en cualquier lado cierra la charla ocasional (también el tap en la burbuja).
	if _charla_activa and event is InputEventMouseButton and event.pressed:
		_cerrar_charla()


func _process(delta: float) -> void:
	if not _puede_tutorial():
		return
	if inicio_capa and inicio_capa.visible:
		_idle_t = 0.0
		return
	if _dormido and robot and robot.mood != "dormido":
		_dormido = false                 # el juego cambió el mood (corrida/victoria): ya no duerme
	_idle_t += delta
	if not _dormido and _idle_t >= IDLE_SEG and robot and robot.mood == "idle" and not corriendo:
		_dormido = true
		robot.set_mood("dormido")


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
	_tutor_cerrar_inmediato()
	es_libre = false
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
	_quizas_primeras_veces()


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
		b.tooltip_text = OP_AYUDA.get(op, "")     # al pasar el mouse: qué hace
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", fuente_sans)
		_estilo_boton_paleta(b)
		b.pressed.connect(func(): agregar_op(op))
		paleta_box.add_child(b)


# Devuelve el botón de la paleta para un op (los botones van en el orden de
# instrucciones_permitidas). Lo usa el tutorial interactivo para apuntar el foco.
func _boton_paleta(op: String) -> Control:
	if nivel == null:
		return null
	var idx: int = nivel.instrucciones_permitidas.find(op)
	if idx >= 0 and idx < paleta_box.get_child_count():
		return paleta_box.get_child(idx)
	return null


# Clave de progreso de un nivel, namespaced por TRACK. Los tracks C y C# comparten
# los 12 ids base (C# = base + avanzados), así que sin el prefijo ganar un nivel en un
# track marcaba el equivalente del otro (bug cross-track). Con "c:<id>" / "csharp:<id>"
# el progreso queda independiente, tanto en memoria (resueltos) como en disco (Puntajes).
func _clave(id: String) -> String:
	return track + ":" + id


func _repintar_cabecera() -> void:
	if nivel == null:
		return
	if es_libre:
		titulo_label.text = "Modo libre   ·   experimentá"
		titulo_label.add_theme_color_override("font_color", COL_ACENTO)
		desc_label.text = nivel.descripcion
		meta_label.text = ""              # sin objetivo ni "tu mejor"
		return
	var resuelto: bool = resueltos.has(_clave(nivel.id))
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
	var m = Puntajes.mejor(_clave(nivel.id))
	var mejor_txt := "tu mejor  ·  —"
	if m != null:
		mejor_txt = "tu mejor  ·  %d instrucciones · %d pasos" % [m.instrucciones, m.pasos]
	meta_label.text = "🎯  %s        ★  %s" % [obj, mejor_txt]


func _repintar_progreso() -> void:
	for hijo in progreso_box.get_children():
		hijo.queue_free()
	for k in orden.size():
		var id_k: String = orden[k]
		var resuelto: bool = resueltos.has(_clave(id_k))
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
		margen.add_theme_constant_override("margin_" + lado, 22)
	add_child(margen)

	var raiz := VBoxContainer.new()
	raiz.add_theme_constant_override("separation", 11)
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

	# Capa de tutorial: por encima de todo (se llena bajo demanda). IGNORE para que,
	# en pasos interactivos, los clics dentro del "hueco" del spotlight lleguen al
	# botón real de abajo (el spotlight decide qué bloquear via _has_point).
	tutorial_capa = Control.new()
	tutorial_capa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tutorial_capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_capa.visible = false
	add_child(tutorial_capa)

	# Capa del robot-tutor (comentarios en momentos clave). Propia, para no encimarse con
	# el tutorial/spotlight. IGNORE: el juego de atrás sigue usable; la burbuja captura su tap.
	tutor_capa = Control.new()
	tutor_capa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tutor_capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutor_capa.visible = false
	add_child(tutor_capa)

	_construir_csharp()
	_construir_como_funciona()

	timer = Timer.new()
	timer.wait_time = VEL_PASO
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
	col.add_theme_constant_override("separation", 12)
	escenario_col = col

	# Robot compañero arriba a la derecha del escenario.
	var fila_top := HBoxContainer.new()
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila_top.add_child(sp)
	robot = Robot.new()
	robot.set_interactivo(true)               # hover + click (presentación: charla ocasional)
	robot.presionado.connect(_on_robot_click)
	fila_top.add_child(robot)
	col.add_child(fila_top)

	# MANO.
	col.add_child(_zona_label("en la mano  ·  int", ZONA_AYUDA.mano))
	mano_celda = _celda(COL_CELDA)
	mano_celda.tooltip_text = ZONA_AYUDA.mano
	mano_label = mano_celda.get_child(0)
	mano_label.add_theme_color_override("font_color", COL_MANO)
	var fila_mano := HBoxContainer.new()
	fila_mano.add_child(mano_celda)
	col.add_child(fila_mano)

	# MEMORIA (slots tipados).
	col.add_child(_zona_label("memoria", ZONA_AYUDA.memoria))
	slots_box = HBoxContainer.new()
	slots_box.add_theme_constant_override("separation", 10)
	col.add_child(slots_box)

	# ENTRAN.
	col.add_child(_zona_label("entran  ·  int", ZONA_AYUDA.entran))
	entrada_box = HBoxContainer.new()
	entrada_box.add_theme_constant_override("separation", 8)
	col.add_child(entrada_box)

	# SALEN.
	col.add_child(_zona_label("salen  ·  int", ZONA_AYUDA.salen))
	salida_box = HBoxContainer.new()
	salida_box.add_theme_constant_override("separation", 8)
	col.add_child(salida_box)

	return col


func _construir_controles() -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)

	# Botón UNIFICADO: corre la animación y, al terminar, valida solo (ves tu programa antes
	# del veredicto). Reusa boton_run/_correr/_detener; el handler marca la corrida como "auto".
	boton_run = _boton_accion("▶ Probar", true)
	boton_run.tooltip_text = "Corre tu programa y, al terminar, lo valida contra el objetivo."
	boton_run.pressed.connect(_on_probar_pressed)
	fila.add_child(boton_run)

	var b_reset := _boton_accion("↺ Reiniciar", false)
	b_reset.pressed.connect(_on_reset_pressed)
	fila.add_child(b_reset)

	# Lamparita de Ayuda: recién acá aparece «Paso», para no invitar a saltear pasos sin entender.
	boton_ayuda = _boton_accion("💡 Ayuda", false)
	boton_ayuda.tooltip_text = "¿Trabado? Mostrá «Paso» para ejecutar de a una instrucción."
	boton_ayuda.pressed.connect(_toggle_ayuda)
	fila.add_child(boton_ayuda)

	boton_step = _boton_accion("⏯ Paso", false)
	boton_step.tooltip_text = "Ejecutá una instrucción por vez."
	boton_step.visible = false                # oculto hasta tocar Ayuda
	boton_step.pressed.connect(_on_step_pressed)
	fila.add_child(boton_step)

	var b_ayuda := _boton_accion("? ¿Cómo se juega?", false)
	b_ayuda.tooltip_text = "Repasá cómo se juega cuando quieras."
	b_ayuda.pressed.connect(_abrir_ayuda)
	fila.add_child(b_ayuda)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(sp)

	boton_codigo = _boton_accion("‹/› Ver en C#", false)
	boton_codigo.tooltip_text = "Mirá tu solución como código real."
	boton_codigo.pressed.connect(_toggle_csharp)
	fila.add_child(boton_codigo)

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

	# Saludo contextual del robot (cambia según hora/día; lo setea _mostrar_inicio).
	_inicio_saludo = _etiqueta("", 15, COL_TENUE)
	_inicio_saludo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inicio_saludo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(_inicio_saludo)

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

	# Elección de track, framed como progresión: C = fundamentos, C# = avanzado.
	var b_c := _boton_accion("Empezá en C  ·  fundamentos", true)
	b_c.custom_minimum_size = Vector2(280, 46)
	b_c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b_c.pressed.connect(func(): _elegir_track("c"))
	v.add_child(b_c)

	var b_cs := _boton_accion("Seguí en C#  ·  avanzado", false)
	b_cs.custom_minimum_size = Vector2(280, 46)
	b_cs.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b_cs.pressed.connect(func(): _elegir_track("csharp"))
	v.add_child(b_cs)

	_inicio_track_label = _etiqueta("", 13, COL_TENUE)
	_inicio_track_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inicio_track_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(_inicio_track_label)

	_btn_continuar = _boton_accion("Continuar", false)
	_btn_continuar.custom_minimum_size = Vector2(240, 44)
	_btn_continuar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_btn_continuar.pressed.connect(_continuar)
	v.add_child(_btn_continuar)

	var b_como := _boton_accion("Cómo funciona la máquina", false)
	b_como.custom_minimum_size = Vector2(240, 42)
	b_como.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b_como.pressed.connect(_abrir_como_funciona)
	v.add_child(b_como)

	var b_git := _boton_accion("Aprendé Git", false)
	b_git.custom_minimum_size = Vector2(240, 42)
	b_git.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b_git.pressed.connect(func(): git_capa.abrir())
	v.add_child(b_git)

	# El pie quedó limpio: Acerca de / Reportar bug / Reiniciar / Sonido / Tema
	# ahora viven detrás de la tuerca (esquina arriba-derecha, _abrir_config).
	var tuerca := Tuerca.new()
	tuerca.anchor_left = 1.0
	tuerca.anchor_right = 1.0
	tuerca.offset_left = -54
	tuerca.offset_right = -14
	tuerca.offset_top = 14
	tuerca.offset_bottom = 54
	tuerca.color = COL_TENUE
	tuerca.color_hover = COL_ACENTO
	tuerca.color_hueco = COL_FONDO
	tuerca.tooltip_text = "Configuración"
	tuerca.apretado.connect(_abrir_config)
	inicio_capa.add_child(tuerca)


# Etiqueta del toggle de sonido (pie de la pantalla de inicio). Mute = todo el audio.
func _texto_sonido() -> String:
	return "🔇 Sonido: no" if (sfx and sfx.silenciado) else "🔊 Sonido: sí"


func _mostrar_inicio() -> void:
	_detener()
	_cerrar_tutorial()
	_refrescar_track_ui()
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
	if _inicio_saludo:
		_inicio_saludo.text = _saludo_contextual()
	_tutor_cerrar_inmediato()
	inicio_capa.visible = true
	inicio_capa.move_to_front()
	# La 1ª vez de todas, mostrale el modelo antes de tocar nada.
	if _puede_tutorial() and not Puntajes.flag("vio_maquina"):
		Puntajes.set_flag("vio_maquina", true)
		_abrir_como_funciona()


func _jugar() -> void:
	inicio_capa.visible = false
	_cargar_indice(0)


func _continuar() -> void:
	inicio_capa.visible = false
	var idx := orden.find(Puntajes.ultimo_nivel())
	_cargar_indice(idx if idx >= 0 else 0)


# ---------------------------------------------------------------------------
# UX estándar (desde el pie del inicio): acerca de, reportar bug, reiniciar.
# ---------------------------------------------------------------------------

# Overlay modal genérico: velo + tarjeta centrada con la paleta. Devuelve el VBox
# interno donde el caller mete el contenido. Tocar el velo lo cierra. Se libera solo.
func _abrir_modal(ancho_min: int) -> VBoxContainer:
	var capa := Control.new()
	capa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	capa.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(capa)
	capa.move_to_front()

	var back := ColorRect.new()
	back.color = Tema.VELO
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			capa.queue_free())
	capa.add_child(back)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(center)

	var card := _panel(COL_PANEL)
	card.custom_minimum_size = Vector2(ancho_min, 0)
	center.add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.set_meta("capa", capa)        # para que el caller pueda cerrar (queue_free)
	card.add_child(v)
	return v


func _reportar_bug() -> void:
	var v := _abrir_modal(440)
	var capa: Control = v.get_meta("capa")
	v.add_child(_etiqueta("Reportar un bug", 22, COL_TEXTO))
	var cuerpo := Label.new()
	cuerpo.text = "¿Algo se rompió o se portó raro? Contámelo y lo reviso. " \
		+ "Se abre el formulario en tu navegador."
	cuerpo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cuerpo.custom_minimum_size = Vector2(400, 0)
	cuerpo.add_theme_font_override("font", fuente_sans)
	cuerpo.add_theme_font_size_override("font_size", 15)
	cuerpo.add_theme_color_override("font_color", COL_TENUE)
	v.add_child(cuerpo)

	var abrir := _boton_accion("Abrir el formulario", true)
	abrir.pressed.connect(func(): OS.shell_open(URL_REPORTAR_BUG))
	v.add_child(abrir)
	var cerrar := _boton_accion("Cerrar", false)
	cerrar.pressed.connect(capa.queue_free)
	v.add_child(cerrar)

	# Toque de personalidad al pie (seco, sin avisar que es chiste).
	var pie := _etiqueta("Ningún ; fue olvidado en la creación de este juego.", 12, COL_TENUE)
	pie.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pie.custom_minimum_size = Vector2(400, 0)
	pie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(pie)


func _acerca_de() -> void:
	var v := _abrir_modal(440)
	var capa: Control = v.get_meta("capa")
	v.add_child(_etiqueta("Acerca de Paso", 22, COL_TEXTO))
	var cuerpo := Label.new()
	cuerpo.text = "Paso es un juego de lógica: armás un programita, paso a paso, " \
		+ "para que la máquina resuelva cada nivel. Aprendés a pensar como un " \
		+ "programa, sin escribir código.\n\nVersión %s" % VERSION
	cuerpo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cuerpo.custom_minimum_size = Vector2(400, 0)
	cuerpo.add_theme_font_override("font", fuente_sans)
	cuerpo.add_theme_font_size_override("font_size", 15)
	cuerpo.add_theme_color_override("font_color", COL_TENUE)
	v.add_child(cuerpo)
	var cerrar := _boton_accion("Cerrar", true)
	cerrar.pressed.connect(capa.queue_free)
	v.add_child(cerrar)


func _reiniciar_progreso() -> void:
	var v := _abrir_modal(440)
	var capa: Control = v.get_meta("capa")
	v.add_child(_etiqueta("¿Reiniciar progreso?", 22, COL_TEXTO))
	var cuerpo := Label.new()
	cuerpo.text = "Se borran tus mejores puntajes y el avance de los tutoriales. " \
		+ "El juego vuelve a estar como recién instalado. Esto no se puede deshacer."
	cuerpo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cuerpo.custom_minimum_size = Vector2(400, 0)
	cuerpo.add_theme_font_override("font", fuente_sans)
	cuerpo.add_theme_font_size_override("font_size", 15)
	cuerpo.add_theme_color_override("font_color", COL_TENUE)
	v.add_child(cuerpo)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var cancelar := _boton_accion("Cancelar", false)
	cancelar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancelar.pressed.connect(capa.queue_free)
	row.add_child(cancelar)
	var confirmar := _boton_accion("Sí, borrar todo", true)
	confirmar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirmar.pressed.connect(func():
		Puntajes.borrar_todo()
		resueltos.clear()
		_repintar_cabecera()
		_repintar_progreso()
		capa.queue_free()
		_mostrar_inicio())          # refresca "Continuar" (desaparece) = estado fresco
	row.add_child(confirmar)
	v.add_child(row)


# ---------------------------------------------------------------------------
# Configuración (detrás de la tuerca): agrupa Tema, Sonido y los enlaces de UX
# (Acerca de / Reportar bug / Reiniciar). Reusa el modal estándar. Cierra con la
# X del encabezado o tocando el velo.
# ---------------------------------------------------------------------------
func _abrir_config() -> void:
	var v := _abrir_modal(420)
	var capa: Control = v.get_meta("capa")

	# Encabezado: título + X (la X cierra; tocar afuera también).
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var titulo := _etiqueta("Configuración", 22, COL_TEXTO)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titulo)
	var x := _boton_link("✕")
	x.add_theme_font_size_override("font_size", 18)
	x.pressed.connect(capa.queue_free)
	head.add_child(x)
	v.add_child(head)

	# Tema: selector segmentado (Claro / Oscuro). El activo va en acento.
	v.add_child(_etiqueta("Tema", 13, COL_TENUE))
	var fila_tema := HBoxContainer.new()
	fila_tema.add_theme_constant_override("separation", 8)
	var es_oscuro := Tema.actual() == "oscuro"
	var b_claro := _boton_accion("Claro", not es_oscuro)
	b_claro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_claro.pressed.connect(func(): _set_tema("claro"))
	fila_tema.add_child(b_claro)
	var b_oscuro := _boton_accion("Oscuro", es_oscuro)
	b_oscuro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_oscuro.pressed.connect(func(): _set_tema("oscuro"))
	fila_tema.add_child(b_oscuro)
	v.add_child(fila_tema)

	# Sonido: toggle (el texto refleja el estado actual).
	var b_sonido := _boton_accion(_texto_sonido(), false)
	b_sonido.pressed.connect(func():
		if sfx:
			sfx.set_silenciado(not sfx.silenciado)
		b_sonido.text = _texto_sonido())
	v.add_child(b_sonido)

	v.add_child(_separador())

	# Enlaces de UX (antes en el pie). Cierran este panel y abren su propio modal.
	var b_acerca := _boton_accion("Acerca de", false)
	b_acerca.pressed.connect(func():
		capa.queue_free()
		_acerca_de())
	v.add_child(b_acerca)
	var b_bug := _boton_accion("Reportar un bug", false)
	b_bug.pressed.connect(func():
		capa.queue_free()
		_reportar_bug())
	v.add_child(b_bug)
	var b_reset := _boton_accion("Reiniciar progreso", false)
	b_reset.pressed.connect(func():
		capa.queue_free()
		_reiniciar_progreso())
	v.add_child(b_reset)


# Tema persistido en el .cfg de Puntajes (como los otros flags). Bool por simpleza:
# no toca la API de Puntajes (flag es bool-only). false = claro, true = oscuro.
func _tema_guardado() -> String:
	return "oscuro" if Puntajes.flag("tema_oscuro", false) else "claro"


# Cambia el tema: persiste, aplica la paleta y reconstruye la escena para que TODO
# (robot, celdas, paneles, git) tome los colores nuevos sin parchear widget por widget.
func _set_tema(nombre: String) -> void:
	if Tema.actual() == nombre:
		return
	Puntajes.set_flag("tema_oscuro", nombre == "oscuro")
	Tema.aplicar(nombre)
	get_tree().reload_current_scene()


# Re-sincroniza los COL_ con la paleta activa de Tema (tras Tema.aplicar()).
func _sincronizar_colores() -> void:
	COL_FONDO = Tema.FONDO
	COL_PANEL = Tema.PANEL
	COL_PANEL_BORDE = Tema.PANEL_BORDE
	COL_CELDA = Tema.CELDA
	COL_CELDA_BORDE = Tema.CELDA_BORDE
	COL_TEXTO = Tema.TEXTO
	COL_TENUE = Tema.TENUE
	COL_ACENTO = Tema.PRIMARIO
	COL_ACENTO_TENUE = Tema.PRIMARIO_TENUE
	COL_MANO = Tema.PRIMARIO
	COL_OK = Tema.EXITO
	COL_ERROR = Tema.ERROR


# ---------------------------------------------------------------------------
# Panel "Ver en C#": muestra el programa actual como C# real (Csharp.generar).
# Cara de editor (mono, cálido), abre/cierra. El modelo sale de programa_modelo().
# ---------------------------------------------------------------------------
func _construir_csharp() -> void:
	csharp_capa = Control.new()
	csharp_capa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	csharp_capa.mouse_filter = Control.MOUSE_FILTER_STOP
	csharp_capa.visible = false
	add_child(csharp_capa)

	# Fondo tenue; clic afuera cierra.
	var back := ColorRect.new()
	back.color = Tema.VELO
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_cerrar_csharp())
	csharp_capa.add_child(back)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	csharp_capa.add_child(center)

	var card := _panel(COL_PANEL)
	card.custom_minimum_size = Vector2(680, 540)
	center.add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)

	var hrow := HBoxContainer.new()
	csharp_titulo = Label.new()
	csharp_titulo.text = "Tu solución en C#"
	csharp_titulo.add_theme_font_override("font", fuente_sans)
	csharp_titulo.add_theme_font_size_override("font_size", 20)
	csharp_titulo.add_theme_color_override("font_color", COL_TEXTO)
	csharp_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(csharp_titulo)
	_codigo_x = _boton_accion("✕", false)
	_codigo_x.custom_minimum_size = Vector2(40, 36)
	_codigo_x.pressed.connect(_cerrar_csharp)
	hrow.add_child(_codigo_x)
	v.add_child(hrow)

	csharp_texto = TextEdit.new()
	csharp_texto.editable = false
	csharp_texto.add_theme_font_override("font", fuente_mono)
	csharp_texto.add_theme_font_size_override("font_size", 15)
	csharp_texto.add_theme_color_override("font_color", COL_TEXTO)
	csharp_texto.add_theme_color_override("font_readonly_color", COL_TEXTO)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_FONDO
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(14)
	sb.border_color = COL_CELDA_BORDE
	sb.set_border_width_all(1)
	csharp_texto.add_theme_stylebox_override("normal", sb)
	csharp_texto.add_theme_stylebox_override("read_only", sb)
	csharp_texto.add_theme_stylebox_override("focus", sb)
	csharp_texto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	csharp_texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	csharp_texto.custom_minimum_size = Vector2(648, 448)
	v.add_child(csharp_texto)

	# Footer "al ganar" (oculto en modo normal): Seguir (queda) / Siguiente nivel (avanza).
	_codigo_footer = HBoxContainer.new()
	_codigo_footer.add_theme_constant_override("separation", 10)
	_codigo_footer.visible = false
	var fsp := Control.new()
	fsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_codigo_footer.add_child(fsp)
	var b_seguir := _boton_accion("Seguir", false)
	b_seguir.pressed.connect(_codigo_seguir)
	_codigo_footer.add_child(b_seguir)
	var b_sig := _boton_accion("Siguiente nivel ▸", true)
	b_sig.pressed.connect(_codigo_siguiente_nivel)
	_codigo_footer.add_child(b_sig)
	v.add_child(_codigo_footer)


func _toggle_csharp() -> void:
	if csharp_capa.visible:
		_cerrar_csharp()
		return
	_codigo_modo_ganar = false
	_aplicar_modo_codigo()                # modo normal: ✕ visible, footer oculto, título base
	# El generador y el título dependen del track.
	csharp_texto.text = (Cc.generar(programa_modelo()) if track == "c" else Csharp.generar(programa_modelo()))
	csharp_capa.visible = true
	csharp_capa.move_to_front()
	if sfx:
		sfx.click()
	# Momento 2 (sub-tanda D): la PRIMERA vez que el jugador abre el panel por su cuenta,
	# el robot explica qué es. Una sola vez (flag); después abre normal.
	if _puede_tutorial() and not Puntajes.flag("vio_codigo_panel"):
		Puntajes.set_flag("vio_codigo_panel", true)
		_robot_comenta(TUTOR_PANEL_CODIGO % _nombre_track(), "idle")


func _cerrar_csharp() -> void:
	csharp_capa.visible = false
	_codigo_modo_ganar = false
	if _tutor_activo:
		_tutor_cerrar_inmediato()         # cierra el robot que acompaña el panel (si lo hay)


# Ajusta los textos que dependen del track (botón del panel, título, indicador del inicio).
func _refrescar_track_ui() -> void:
	var es_c := track == "c"
	if boton_codigo:
		boton_codigo.text = "‹/› Ver en C" if es_c else "‹/› Ver en C#"
	if csharp_titulo:
		csharp_titulo.text = "Tu solución en C" if es_c else "Tu solución en C#"
	if _inicio_track_label:
		_inicio_track_label.text = "Estás en: C · fundamentos" if es_c else "Estás en: C# · avanzado"


func _elegir_track(t: String) -> void:
	track = t
	Puntajes.set_track(t)
	orden = Niveles.orden_track(t)
	_refrescar_track_ui()
	inicio_capa.visible = false
	_cargar_indice(0)


# ---------------------------------------------------------------------------
# "Cómo funciona la máquina": intro conceptual con un mini-demo que se corre solo
# y lento sobre un ejemplo de 3 instrucciones. Usa el intérprete puro. La idea es
# que quien recién arranca VEA el modelo (mano / memoria / entra / sale) antes de
# tocar nada. Accesible desde inicio y desde "¿Cómo se juega?".
# ---------------------------------------------------------------------------
func _construir_como_funciona() -> void:
	como_capa = Control.new()
	como_capa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	como_capa.mouse_filter = Control.MOUSE_FILTER_STOP
	como_capa.visible = false
	add_child(como_capa)

	var fondo := ColorRect.new()
	fondo.color = COL_FONDO
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	como_capa.add_child(fondo)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	como_capa.add_child(center)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	center.add_child(v)

	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 14)
	trow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var titulo := Label.new()
	titulo.text = "Cómo funciona la máquina"
	titulo.add_theme_font_override("font", fuente_sans)
	titulo.add_theme_font_size_override("font_size", 30)
	titulo.add_theme_color_override("font_color", COL_TEXTO)
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	trow.add_child(titulo)
	_demo_robot = Robot.new()
	_demo_robot.custom_minimum_size = Vector2(96, 96)
	trow.add_child(_demo_robot)
	v.add_child(trow)

	var sub := Label.new()
	# Issue #5: enmarcado como REPASO opcional (la puerta de entrada es jugar el nivel 1).
	sub.text = "Un repaso de las piezas de la máquina, por si querés volver a verlas.\nMirá al robot resolver un ejemplo chiquito, una cosa a la vez."
	sub.add_theme_font_override("font", fuente_sans)
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", COL_TENUE)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(sub)

	# Mini-escenario.
	var card := _panel(COL_PANEL)
	card.custom_minimum_size = Vector2(560, 0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 10)
	card.add_child(cv)
	cv.add_child(_demo_fila("entran"))
	cv.add_child(_demo_fila("en la mano"))
	cv.add_child(_demo_fila("memoria"))
	cv.add_child(_demo_fila("salen"))
	v.add_child(card)

	_demo_caption = Label.new()
	_demo_caption.add_theme_font_override("font", fuente_sans)
	_demo_caption.add_theme_font_size_override("font_size", 17)
	_demo_caption.add_theme_color_override("font_color", COL_TEXTO)
	_demo_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_demo_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_demo_caption.custom_minimum_size = Vector2(560, 66)
	_demo_caption.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(_demo_caption)

	# Navegación a RITMO DEL JUGADOR: nada avanza por reloj; el demo pasa al tocar.
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 12)
	nav.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_demo_b_atras = _boton_accion("◀ Atrás", false)
	_demo_b_atras.custom_minimum_size = Vector2(120, 44)
	_demo_b_atras.pressed.connect(_demo_atras)
	nav.add_child(_demo_b_atras)
	_demo_paso_label = Label.new()
	_demo_paso_label.add_theme_font_override("font", fuente_sans)
	_demo_paso_label.add_theme_font_size_override("font_size", 14)
	_demo_paso_label.add_theme_color_override("font_color", COL_TENUE)
	_demo_paso_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_demo_paso_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_demo_paso_label.custom_minimum_size = Vector2(110, 0)
	nav.add_child(_demo_paso_label)
	_demo_b_sig = _boton_accion("Siguiente ▶", true)
	_demo_b_sig.custom_minimum_size = Vector2(150, 44)
	_demo_b_sig.pressed.connect(_demo_avanzar)
	nav.add_child(_demo_b_sig)
	v.add_child(nav)

	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 10)
	brow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var entendido := _boton_accion("Entendido", true)
	entendido.custom_minimum_size = Vector2(160, 44)
	entendido.pressed.connect(_cerrar_como_funciona)
	brow.add_child(entendido)
	var libre := _boton_accion("Probar en modo libre", false)
	libre.custom_minimum_size = Vector2(200, 44)
	libre.pressed.connect(_modo_libre)
	brow.add_child(libre)
	v.add_child(brow)


# Una fila del mini-escenario: etiqueta + caja de celdas. Guarda la referencia que
# corresponda (entrada/mano/memoria/salida) para actualizarla en cada tick.
func _demo_fila(cual: String) -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	var et := _etiqueta(cual, 13, COL_TENUE, true)
	et.custom_minimum_size = Vector2(110, 0)
	et.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fila.add_child(et)
	match cual:
		"entran":
			_demo_entrada_box = HBoxContainer.new()
			_demo_entrada_box.add_theme_constant_override("separation", 8)
			fila.add_child(_demo_entrada_box)
		"en la mano":
			_demo_mano_celda = _celda(COL_CELDA)
			_demo_mano_celda.get_child(0).add_theme_color_override("font_color", COL_MANO)
			fila.add_child(_demo_mano_celda)
		"memoria":
			_demo_mem_celda = _celda(COL_CELDA)
			fila.add_child(_demo_mem_celda)
		"salen":
			_demo_salida_box = HBoxContainer.new()
			_demo_salida_box.add_theme_constant_override("separation", 8)
			fila.add_child(_demo_salida_box)
	return fila


func _abrir_como_funciona() -> void:
	_cerrar_tutorial()
	_tutor_cerrar_inmediato()
	_demo_paso_i = 0
	_demo_mostrar(0)
	como_capa.visible = true
	como_capa.move_to_front()


func _cerrar_como_funciona() -> void:
	como_capa.visible = false


# Avance a RITMO DEL JUGADOR (sin timer): el demo pasa al próximo momento al tocar.
func _demo_avanzar() -> void:
	if _demo_paso_i < DEMO_CAPS.size() - 1:
		_demo_paso_i += 1
		_demo_mostrar(_demo_paso_i)


func _demo_atras() -> void:
	if _demo_paso_i > 0:
		_demo_paso_i -= 1
		_demo_mostrar(_demo_paso_i)


# Muestra el momento i re-derivando el estado desde cero (i ejecuciones del DEMO_PROG).
# Re-derivar permite ir y volver sin que se rompa el estado visual.
func _demo_mostrar(i: int) -> void:
	_demo_estado = Interprete.Estado.new(DEMO_IN, 1)
	for _k in range(i):
		Interprete.ejecutar_paso(_demo_estado, DEMO_PROG)
	_demo_redibujar(i)


func _demo_redibujar(i: int) -> void:
	_pintar_fila(_demo_entrada_box, _demo_estado.entrada, false)
	_pintar_fila(_demo_salida_box, _demo_estado.salida, false)
	_demo_mano_celda.get_child(0).text = _str_valor(_demo_estado.mano)
	_demo_mem_celda.get_child(0).text = _str_valor(_demo_estado.slots[0])
	_demo_caption.text = DEMO_CAPS[i]
	# Estado de la navegación manual.
	if _demo_paso_label:
		_demo_paso_label.text = "Paso %d de %d" % [i + 1, DEMO_CAPS.size()]
	if _demo_b_atras:
		_demo_b_atras.disabled = i == 0
		_demo_b_atras.modulate.a = 0.4 if i == 0 else 1.0
	if _demo_b_sig:
		var _ult := i >= DEMO_CAPS.size() - 1
		_demo_b_sig.disabled = _ult
		_demo_b_sig.modulate.a = 0.4 if _ult else 1.0
	match i:
		0:
			if _demo_robot: _demo_robot.set_mood("idle")
		1:
			if _demo_robot: _demo_robot.set_mood("pensando")
			_pop(_demo_mano_celda, 0.5)
		2:
			if _demo_robot: _demo_robot.set_mood("idle")
			_brillo(_demo_mem_celda, 0.5)
		3:
			if _demo_robot: _demo_robot.set_mood("feliz")
			_pop_ultimo(_demo_salida_box, 0.5)


# Modo libre: un sandbox sin objetivo (todas las instrucciones, entrada de ejemplo).
# El nivel se arma en código (no es parte del orden de juego ni de los tests).
func _modo_libre() -> void:
	_cerrar_como_funciona()
	_cerrar_tutorial()
	_cerrar_csharp()
	if inicio_capa:
		inicio_capa.visible = false
	es_libre = true
	nivel = Niveles.desde_dict({
		"id": "libre",
		"nombre": "Modo libre",
		"descripcion": "Modo libre: experimentá sin objetivo. Agarrá, guardá/recuperá, sumá/restá, soltá — y corré.",
		"slots": 2,
		"instrucciones_permitidas": ["TOMAR", "SOLTAR", "COPIAR", "GUARDAR", "SUMAR", "RESTAR", "SALTAR", "SALTAR_SI_CERO", "ETIQUETA"],
		"casos": [{"entrada": [3, 1, 4, 1, 5], "salida_esperada": []}],
		"par": {"instrucciones": 0, "pasos": 0},
	})
	programa = []
	programa_run = []
	cantidad_slots = nivel.slots
	entrada_inicial = nivel.casos[0].entrada.duplicate()
	_repintar_paleta()
	_repintar_programa()
	_construir_memoria()
	_repintar_cabecera()
	_repintar_progreso()
	_reset_corrida()
	if robot:
		robot.set_mood("idle")


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
	_tutorial_evento("op:" + op)
	_quizas_comentario_primer_programa()


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


# «Paso» (herramienta de ayuda): corre UNA instrucción. No es auto, así que no valida.
func _on_step_pressed() -> void:
	_detener()
	_paso()


# Toggle puro de corrida (sin validar). Lo usa el test de UI; el botón unificado usa _on_probar_pressed.
func _on_run_pressed() -> void:
	if corriendo:
		_detener()
	else:
		_correr()


# Botón UNIFICADO: corre la animación y, al TERMINAR la corrida, valida solo (ver _al_terminar_corrida).
func _on_probar_pressed() -> void:
	if corriendo:
		_detener()                           # segundo toque = pausa (no valida)
	else:
		_corrida_auto = true                 # esta corrida valida al terminar
		_correr()


# Lamparita de Ayuda: muestra/oculta «Paso» (la ejecución paso a paso aparece cuando se busca ayuda).
func _toggle_ayuda() -> void:
	if boton_step:
		boton_step.visible = not boton_step.visible
		if boton_ayuda:
			boton_ayuda.modulate.a = 0.6 if boton_step.visible else 1.0
	if sfx:
		sfx.click()


func _on_reset_pressed() -> void:
	_reset_corrida()


func _on_validar_pressed() -> void:
	if nivel == null:
		return
	if es_libre:
		validacion_label.text = "Modo libre: no hay objetivo. Probá lo que quieras y mirá la máquina."
		validacion_label.add_theme_color_override("font_color", COL_TENUE)
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
		var clave := _clave(nivel.id)
		if not resueltos.has(clave):
			resueltos[clave] = true
			_repintar_progreso()
			_repintar_cabecera()
		var es_par: bool = r.score.instrucciones <= nivel.par_instrucciones and r.score.pasos <= nivel.par_pasos
		var es_record: bool = Puntajes.registrar(clave, r.score.instrucciones, r.score.pasos)
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
		# Ajuste D: el código-al-ganar solo las PRIMERAS 3 victorias; de ahí en más, banner solo.
		_gano_pendiente = _puede_tutorial() and _veces_cod_ganar() < 3
		# Issue #1: el avance ya NO viaja con el chiste. Al cerrar el banner, _descartar_banner
		# ofrece el avance SIEMPRE (con un chiste ocasional encima); ver _ofrecer_avance_al_ganar.
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
		_al_terminar_corrida()


# Corrida terminada: acá disparamos lo que depende de "ya viste correr el programa".
func _al_terminar_corrida() -> void:
	# Issue #2(a): en el paso "run" del tutorial, la corrida FRENA y se ve el estado final
	# LIMPIO (sin el "✗" de validar). Detectamos ese paso antes de avanzarlo.
	var en_tuto_run: bool = not _tuto_pasos.is_empty() and _tuto_i < _tuto_pasos.size() \
		and tutorial_capa != null and tutorial_capa.visible \
		and _tuto_pasos[_tuto_i].get("espera", "") == "run"
	_tutorial_evento("run")                  # #3: el "¿viste el viaje?" avanza al TERMINAR (no al arrancar)
	if _corrida_auto:                        # #8: el botón unificado valida tras la corrida
		_corrida_auto = false
		if not en_tuto_run:                  # durante el tutorial NO validamos: dejamos ver el estado final
			_on_validar_pressed()


# Issue #2(c): repetir la corrida del tutorial sin validar (botón "▶ Ver de nuevo").
func _tutorial_ver_de_nuevo() -> void:
	_reset_corrida()                         # vuelve al estado inicial (no toca el programa)
	_correr()                                # corre la animación; al terminar no valida (no es _corrida_auto)


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
		boton_run.text = "▶ Probar"
	if timer:
		timer.stop()


func _on_tick() -> void:
	if estado.terminado:
		_detener()
		return
	_paso()


func _reset_corrida() -> void:
	_detener()
	_corrida_auto = false                    # editar/resetear cancela la validación automática pendiente
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
	# Run usa la velocidad fija; Step (no corriendo) va mas lento para que se lea.
	return VEL_ANIM if corriendo else 0.34


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
	# Sub-tanda D: tras la celebración mostramos el código traducido con el robot de guía
	# (orden: celebración → código+robot → Seguir/Siguiente). Nunca dos cosas hablando a la vez.
	if _gano_pendiente:
		_gano_pendiente = false
		t.tween_callback(_mostrar_codigo_al_ganar)
	else:
		# Issue #1: el banner SIEMPRE nace de una victoria → ofrecer avance siempre que no
		# se muestre el código (que trae su propio "Siguiente nivel"). Antes acá solo caía
		# el chiste ocasional y, pasadas 3 victorias, el jugador quedaba sin forma de avanzar.
		t.tween_callback(_ofrecer_avance_al_ganar)


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
					return "Casi 👀  con %s: en el %s lugar iba %s y saliste %s. Revisá el orden en que guardás/recuperás de memoria." % [
						str(d.entrada), _ordinal(k + 1), _str_valor(esperada[k]), _str_valor(obtenida[k])]
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
		"descripcion": nivel.descripcion if nivel else "",
		"slots": cantidad_slots,
		"lineas": lineas,
	}


# ---------------------------------------------------------------------------
# Tutorial con spotlight (solo niveles 1-2, dismissable, no invasivo).
# ---------------------------------------------------------------------------
func _puede_tutorial() -> bool:
	return DisplayServer.get_name() != "headless"


# Tutorial automático la primera vez (niveles 1-2). El nivel 1 es INTERACTIVO.
func _quizas_tutorial() -> void:
	if not _puede_tutorial() or nivel == null:
		return
	if inicio_capa and inicio_capa.visible:
		return                                   # no arrancamos el tutorial bajo la pantalla inicial
	if nivel_idx > 1:
		return
	if Puntajes.flag("tuto_" + nivel.id):
		return
	_tuto_pasos = _pasos_tutorial(nivel.id)
	_tuto_i = 0
	_tuto_marca_visto = true                     # primera vez: al terminar, marcar visto
	_tuto_mostrar_como = false                   # el tutorial ES la puerta de entrada; no ofrece el repaso
	call_deferred("_tutorial_arrancar")


# Botón "¿Cómo se juega?": leyenda repasable en cualquier momento (no marca visto).
func _abrir_ayuda() -> void:
	if not _puede_tutorial():
		return
	_cerrar_tutorial()
	_tutor_cerrar_inmediato()
	_tuto_pasos = _pasos_legenda()
	_tuto_i = 0
	_tuto_marca_visto = false
	_tuto_mostrar_como = true                     # repaso: acá SÍ ofrecemos "Cómo funciona la máquina"
	call_deferred("_tutorial_arrancar")


# Onboarding "PRIMERA VEZ": presenta cada zona/panel con una frase física de 1 línea
# (qué hace, no jerga) la primera vez que aparece, reusando el MISMO spotlight del
# tutorial. Convive con el tutorial automático sin encimarse: si el tutorial va a
# arrancar este load, espera. No repite ENTRAN/MEMORIA si el tutorial de los niveles
# 1-2 ya las explicó. Cada zona se muestra una sola vez (flag pv_*); "Reiniciar
# progreso" los borra solos (borra el .cfg entero). En headless no corre (tests).
func _quizas_primeras_veces() -> void:
	if not _puede_tutorial() or nivel == null:
		return
	if inicio_capa and inicio_capa.visible:
		return
	if tutorial_capa and tutorial_capa.visible:
		return
	# No pisar el tutorial automático: si va a arrancar (niveles 1-2 aún sin verse), esperamos.
	if nivel_idx <= 1 and not Puntajes.flag("tuto_" + nivel.id):
		return
	# Operaciones (sumá/restá): la PRIMERA vez que un nivel las ofrece. Tiene PRIORIDAD
	# sobre el onboarding de zona porque es justo el concepto que los testers no captaban:
	# que sumar/restar operan contra una MEMORIA que hay que elegir (Issue #31). Es un
	# flujo guiado (concepto → spotlight memoria → agarrá la op → spotlight su desplegable).
	if not Puntajes.flag("pv_operaciones") and _ofrece_operacion():
		_tuto_pasos = _pasos_operaciones()
		_tuto_i = 0
		_tuto_marca_visto = false                    # marca su propio flag pv_operaciones, no tuto_<id>
		_tuto_mostrar_como = false
		call_deferred("_tutorial_arrancar")
		return
	# Cola de zonas sin presentar. La lambda «objetivo» va SIEMPRE última (limitación del parser).
	var pasos := []
	if not Puntajes.flag("pv_entran") and not Puntajes.flag("tuto_b1_eco"):
		pasos.append({"texto": "« ENTRAN » — los números que llegan, en fila.", "flag": "pv_entran", "objetivo": func(): return entrada_box})
	if not Puntajes.flag("pv_mano"):
		pasos.append({"texto": "« EN LA MANO » — lo que el robot tiene agarrado ahora.", "flag": "pv_mano", "objetivo": func(): return mano_celda})
	if not Puntajes.flag("pv_memoria") and not Puntajes.flag("tuto_b2_invertir_par"):
		pasos.append({"texto": "« MEMORIA » — un cajón para guardar algo y usarlo después.", "flag": "pv_memoria", "objetivo": func(): return slots_box})
	if not Puntajes.flag("pv_salen"):
		pasos.append({"texto": "« SALEN » — lo que el robot va sacando, en orden.", "flag": "pv_salen", "objetivo": func(): return salida_box})
	if not Puntajes.flag("pv_instr"):
		pasos.append({"texto": "« INSTRUCCIONES » — las órdenes que le podés dar al robot.", "flag": "pv_instr", "objetivo": func(): return paleta_box})
	if not Puntajes.flag("pv_programa"):
		pasos.append({"texto": "« TU PROGRAMA » — la lista de órdenes, en orden.", "flag": "pv_programa", "objetivo": func(): return programa_vbox})
	if pasos.is_empty():
		return
	# UNA zona por nivel (no encolamos todas): mostramos la primera no vista; las demás
	# caen en los siguientes niveles. Cada paso marca su flag pv_*, así no se repiten.
	_tuto_pasos = [pasos[0]]
	_tuto_i = 0
	_tuto_marca_visto = false                    # no marca tuto_<id>; cada paso marca su propio flag pv_*
	_tuto_mostrar_como = false                   # onboarding 1-zona: sin "Cómo funciona" (evita amontonar)
	call_deferred("_tutorial_arrancar")


# Pasos por nivel (primera vez). Cada paso:
#   {texto, objetivo: Callable->Control|null, espera?: "op:X"|"run", sin_velo?: bool}
# Si trae `espera`, el paso es INTERACTIVO: se oculta "Siguiente" y avanza solo
# cuando el jugador hace esa acción (el spotlight deja pasar el clic al objetivo).
func _pasos_tutorial(id: String) -> Array:
	if id == "b2_invertir_par":
		return [
			{"texto": "Nuevo: la MEMORIA. Guardás un valor con « guardá » y lo traés de vuelta con « recuperá ».",
				"objetivo": func(): return slots_box},
			{"texto": "Pista: para invertir, guardá el primero, sacá el segundo y recién ahí soltá el guardado.",
				"objetivo": func(): return programa_vbox},
		]
	# Nivel 1 (b1_eco u otro): tutorial DE LA MANO, lo hacés vos. Es la PUERTA DE ENTRADA
	# (Issue #5): presenta cada pieza A MEDIDA que se usa, con contexto y el objetivo del juego.
	# (En cada dict, la lambda `objetivo` va ÚLTIMA: un lambda de una línea seguido
	#  de otra clave confunde al parser.)
	return [
		{"texto": "¡Hola! Soy tu robot: vos me das órdenes y yo las ejecuto. Tu objetivo en cada nivel: que lo que SALE coincida con lo pedido. Te lo enseño jugando. Tocá « Siguiente ».",
			"objetivo": func(): return null},
		{"texto": "« Entran »: la fila de números que llegan, en orden. Acá entran tres y hay que sacarlos tal cual.",
			"objetivo": func(): return entrada_box},
		{"texto": "Probá vos: tocá « agarrá » para tomar el primero. Queda « en la mano »: lo único que sostengo, de a uno por vez.",
			"espera": "op:TOMAR", "objetivo": func(): return _boton_paleta("TOMAR")},
		{"texto": "¡Bien! Ahora tocá « soltá »: lo que tengo en la mano pasa a « salen », la fila de resultados.",
			"espera": "op:SOLTAR", "objetivo": func(): return _boton_paleta("SOLTAR")},
		{"texto": "Ya armaste dos órdenes: ese es tu programa. Tocá « ▶ Probar » y mirame ejecutarlo.",
			"espera": "run", "objetivo": func(): return boton_run},
		# Issue #2: la corrida ya frenó y se ve el estado final; recién acá el mensaje, con
		# botón para repetirla si no se vio.
		{"texto": "Eso que viste es tu programa ejecutándose, paso a paso.",
			"sin_velo": true, "accion": {"label": "▶ Ver de nuevo", "cb": Callable(self, "_tutorial_ver_de_nuevo")},
			"objetivo": func(): return null},
		# Issue #2(d): al cerrar, foco en la consigna del nivel (mismo spotlight del onboarding).
		{"texto": "Esta es la consigna del nivel: lo que hay que lograr. Repetí agarrá/soltá hasta vaciar la entrada y tocá « ▶ Probar ». ¡A jugar!",
			"objetivo": func(): return desc_label},
	]


# ¿Este nivel ofrece sumá o restá? (las dos operaciones que actúan contra una memoria elegida)
func _ofrece_operacion() -> bool:
	if nivel == null:
		return false
	return "SUMAR" in nivel.instrucciones_permitidas or "RESTAR" in nivel.instrucciones_permitidas


# Onboarding de sumá/restá (Issue #31). Flujo guiado en la voz del robot, seco:
#   1. Concepto + spotlight sobre la zona MEMORIA: la operación toma un valor de ahí.
#   2. Interactivo: agarrá la operación (spotlight sobre su botón en INSTRUCCIONES).
#   3. Al agarrarla, spotlight sobre SU desplegable: ahí elegís CUÁL memoria entra.
# El paso 2/3 usa la op que el nivel ofrece (sumá si está, si no restá): el primer
# encuentro en los órdenes que se envían es «sumar_par» (SUMAR), pero queda genérico.
func _pasos_operaciones() -> Array:
	var op := "SUMAR" if "SUMAR" in nivel.instrucciones_permitidas else "RESTAR"
	var verbo: String = OP_LABEL.get(op, op)         # «sumá» / «restá»
	var accion := "suma" if op == "SUMAR" else "resta"
	return [
		{"texto": "Algo nuevo: « %s ». No trabaja sola: agarra el valor de una MEMORIA y lo %s a lo que tengo en la mano." % [verbo, accion],
			"flag": "pv_operaciones", "objetivo": func(): return slots_box},
		{"texto": "Probá: agarrá « %s » de las instrucciones." % verbo,
			"espera": "op:" + op, "objetivo": func(): return _boton_paleta(op)},
		{"texto": "Ahí elegís QUÉ memoria entra en la cuenta. La operación usa ESA, no otra.",
			"objetivo": func(): return _slot_dropdown_ultima_fila()},
	]


# El OptionButton de memoria de la última fila del programa (la op recién agregada).
# Lo usa el onboarding de operaciones para apuntar el spotlight a la selección concreta.
func _slot_dropdown_ultima_fila():
	if filas_panel.is_empty():
		return null
	return _buscar_option_button(filas_panel.back())


func _buscar_option_button(nodo: Node):
	if nodo is OptionButton:
		return nodo
	for hijo in nodo.get_children():
		var r = _buscar_option_button(hijo)
		if r != null:
			return r
	return null


# Leyenda repasable (read-only) para el botón "¿Cómo se juega?": sirve en cualquier nivel.
func _pasos_legenda() -> Array:
	return [
		{"texto": "Cómo se juega: armás un programa con instrucciones y el robot lo ejecuta. La salida tiene que coincidir con lo pedido.",
			"objetivo": func(): return null},
		{"texto": "« Entran »: la fila de valores que recibís, en orden. Cuando se vacía, el programa termina.",
			"objetivo": func(): return entrada_box},
		{"texto": "« La mano »: sostenés UN valor por vez. Casi todo pasa por la mano.",
			"objetivo": func(): return mano_celda},
		{"texto": "« Memoria »: cajitas (int) para guardar un valor y recuperarlo después.",
			"objetivo": func(): return slots_box},
		{"texto": "« Salen »: lo que vas soltando. Pasá el mouse por cada instrucción para ver qué hace.",
			"objetivo": func(): return salida_box},
		{"texto": "« Correr » ejecuta todo; « Paso » va de a uno. « Validar » chequea tu solución contra el objetivo.",
			"objetivo": func(): return boton_run},
	]


# Avance dirigido por acción del jugador (pasos interactivos).
func _tutorial_evento(tag: String) -> void:
	if _tuto_pasos.is_empty() or _tuto_i >= _tuto_pasos.size():
		return
	if tutorial_capa == null or not tutorial_capa.visible:
		return
	var espera: String = _tuto_pasos[_tuto_i].get("espera", "")
	if espera != "" and espera == tag:
		_tutorial_siguiente()


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
	# Link tenue (no botón sólido): no compite con el botón objetivo resaltado.
	var saltar := _boton_link("Saltar tutorial" if _tuto_marca_visto else "Cerrar")
	saltar.pressed.connect(_saltar_tutorial)
	fila.add_child(saltar)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(sp)
	# Botón de acción opcional por paso (p.ej. "▶ Ver de nuevo"): oculto salvo que el paso lo pida.
	_tuto_btn_accion = _boton_accion("", false)
	_tuto_btn_accion.visible = false
	_tuto_btn_accion.pressed.connect(func(): if _tuto_accion_cb.is_valid(): _tuto_accion_cb.call())
	fila.add_child(_tuto_btn_accion)
	_tuto_btn_sig = _boton_accion("Siguiente ▸", true)
	_tuto_btn_sig.pressed.connect(_tutorial_siguiente)
	fila.add_child(_tuto_btn_sig)
	gv.add_child(fila)

	# Solo en la leyenda repasable "¿Cómo se juega?": acceso al repaso conceptual. (El onboarding
	# de zonas y el tutorial guiado NO lo muestran, para no amontonar — Issue #5.)
	if _tuto_mostrar_como:
		var b_maq := _boton_accion("Cómo funciona la máquina ▸", false)
		b_maq.pressed.connect(_abrir_como_funciona)   # _abrir_como_funciona cierra el tutorial
		gv.add_child(b_maq)

	_tuto_globo = globo
	tutorial_capa.add_child(globo)
	tutorial_capa.visible = true
	if robot:
		robot.set_mood("idle")
	_tutorial_mostrar_paso()


func _tutorial_mostrar_paso() -> void:
	if _tuto_i >= _tuto_pasos.size():
		if _tuto_marca_visto and nivel:
			Puntajes.set_flag("tuto_" + nivel.id, true)
		_cerrar_tutorial()
		return
	var paso = _tuto_pasos[_tuto_i]
	if paso.has("flag"):
		Puntajes.set_flag(paso.flag, true)        # onboarding "primera vez": esta zona ya se mostró
	var globo := _tuto_globo
	var espera: String = paso.get("espera", "")
	var sin_velo: bool = paso.get("sin_velo", false)

	if _tuto_txt:
		_tuto_txt.text = paso.texto
	if _tuto_btn_sig:
		# En pasos interactivos avanza la ACCIÓN del jugador, no el botón.
		_tuto_btn_sig.visible = (espera == "")
		_tuto_btn_sig.text = "¡Dale! ✓" if _tuto_i == _tuto_pasos.size() - 1 else "Siguiente ▸"
	# Botón de acción opcional del paso (p.ej. "▶ Ver de nuevo" para repetir la corrida).
	if _tuto_btn_accion:
		var acc = paso.get("accion", null)
		if acc != null:
			_tuto_btn_accion.text = acc.get("label", "")
			_tuto_accion_cb = acc.get("cb", Callable())
			_tuto_btn_accion.visible = true
		else:
			_tuto_accion_cb = Callable()
			_tuto_btn_accion.visible = false

	# Apuntar el spotlight al objetivo (o sin foco si null/rect sin resolver).
	var objetivo_node = paso.objetivo.call()
	var rect := Rect2()
	if objetivo_node is Control:
		rect = objetivo_node.get_global_rect()
	if _spotlight:
		# Set inmediato (best-effort) para no parpadear; se RECALCULA tras el layout abajo.
		_spotlight.objetivo = rect.grow(8.0) if rect.size != Vector2.ZERO else Rect2()
		_spotlight.permitir_hueco = (espera != "")   # interactivo: el clic pasa al objetivo
		_spotlight.mostrar_velo = not sin_velo        # último paso: sin velo, mirás el juego
		_spotlight.queue_redraw()

	# Posicionar el globito. Esperamos 2 frames a que el layout (label con autowrap)
	# se asiente, si no su alto sale enorme y el globo se va de pantalla.
	if globo:
		await get_tree().process_frame
		await get_tree().process_frame
		# El tutorial pudo cerrarse (navegacion/skip) mientras esperabamos.
		if not is_instance_valid(globo) or not tutorial_capa.visible:
			return
		# #3/#4: RECALCULAR el rect del objetivo YA con el layout asentado. Tomado antes del
		# await (nivel recién cargado → memoria/salida recién reconstruidas) venía stale y el
		# foco aparecía DESFASADO de la celda. Refrescamos spotlight y reposicionamos el globo.
		if is_instance_valid(objetivo_node) and objetivo_node is Control:
			rect = (objetivo_node as Control).get_global_rect()
			if _spotlight:
				_spotlight.objetivo = rect.grow(8.0) if rect.size != Vector2.ZERO else Rect2()
				_spotlight.queue_redraw()
		var gs: Vector2 = globo.size
		var pos: Vector2
		if rect.size != Vector2.ZERO:
			# Si el objetivo está en la mitad de abajo, el globo va ARRIBA (no lo tapa).
			if rect.position.y > size.y * 0.55:
				pos = Vector2(rect.position.x, rect.position.y - gs.y - 14)
			else:
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
	if _tuto_marca_visto and nivel:
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
# Robot-tutor: el robot se desliza a una esquina libre, se asoma y comenta UNA frase.
# Se queda hasta que el jugador la cierra (NO auto-cierra por timer). Reusa robot.gd y
# el mecanismo de burbuja (_panel + label + botón) del tutorial/onboarding. Nunca habla
# si hay otra cosa hablando (tutorial/spotlight/inicio/cómo). En headless no corre.
# ---------------------------------------------------------------------------
func _tutor_libre() -> bool:
	if not _puede_tutorial():
		return false                              # headless / tests: nunca corre
	if _tutor_activo:
		return false                              # ya hay un comentario (nunca dos a la vez)
	if tutorial_capa and tutorial_capa.visible:
		return false                              # tutorial / onboarding hablando
	if inicio_capa and inicio_capa.visible:
		return false
	if como_capa and como_capa.visible:
		return false
	if escenario_col == null or escenario_col.get_global_rect().size == Vector2.ZERO:
		return false                              # sin layout todavía (boot)
	return true


# Muestra un comentario. Devuelve true si efectivamente se mostró (para marcar el flag).
func _robot_comenta(texto: String, animo: String, con_boton := true, accion_texto := "", accion_cb := Callable()) -> bool:
	if not _tutor_libre() or robot == null:
		return false
	_tutor_activo = true
	_tutor_cerrando = false
	tutor_capa.visible = true
	tutor_capa.move_to_front()

	var esc := escenario_col.get_global_rect()
	var tam := 120.0

	# Ocultamos el robot real (modulate.a, NO visible: así conserva su lugar y nada salta)
	# y mostramos uno igual en la capa: se lee como "el mismo" robot que se va a la esquina.
	_tutor_origen = robot.global_position
	robot.modulate.a = 0.0
	_tutorbot = Robot.new()
	tutor_capa.add_child(_tutorbot)
	_tutorbot.size = Vector2(tam, tam)
	_tutorbot.position = _tutor_origen
	_tutorbot.set_mood(animo)

	# Burbuja: mismo mecanismo que el tutorial/onboarding (_panel + label + botón).
	_tutor_burbuja = _panel(COL_PANEL)
	_tutor_burbuja.custom_minimum_size = Vector2(240, 0)
	_tutor_burbuja.mouse_filter = Control.MOUSE_FILTER_STOP   # tap en la burbuja = cerrar
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 10)
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutor_burbuja.add_child(bv)
	var lbl := Label.new()
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_override("font", fuente_sans)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", COL_TEXTO)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(216, 0)
	lbl.text = texto
	bv.add_child(lbl)
	# Botón "dale ✓" + tap-para-cerrar: solo cuando el robot se cierra por sí mismo. En el
	# panel de código al ganar (con_boton=false) el flujo lo dan Seguir / Siguiente nivel.
	if con_boton:
		var fila := HBoxContainer.new()
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(sp)
		if accion_texto != "":
			# Botón de acción (p.ej. "Siguiente nivel ▸"): cierra la burbuja y dispara el callback.
			var act := _boton_accion(accion_texto, true)
			act.pressed.connect(func():
				_cerrar_comentario()
				if accion_cb.is_valid():
					accion_cb.call())
			fila.add_child(act)
		else:
			var ok := _boton_accion("dale ✓", true)
			ok.pressed.connect(_cerrar_comentario)
			fila.add_child(ok)
		bv.add_child(fila)
	_tutor_burbuja.modulate.a = 0.0
	tutor_capa.add_child(_tutor_burbuja)
	if con_boton:
		_tutor_burbuja.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed:
				_cerrar_comentario())

	# Destino: esquina inferior-derecha del área de juego (franja derecha libre, la misma
	# que usa la celebración), por encima de los controles. Nunca pisa el editor (izquierda).
	var destino := Vector2(esc.end.x - tam - 6.0, esc.end.y - tam - 6.0)
	# Vida al hablar: micro-bote al asomarse + antena oscilando + balbuceo. Matamos el tween
	# anterior antes de relanzar para que spamear abrir/cerrar no encime animaciones.
	_tutorbot.pivot_offset = Vector2(tam, tam) * 0.5
	_tutorbot.set_hablando(true)
	if _tutor_tween and _tutor_tween.is_valid():
		_tutor_tween.kill()
	_tutor_tween = create_tween()
	_tutor_tween.tween_property(_tutorbot, "position", destino, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tutor_tween.parallel().tween_property(_tutorbot, "scale", Vector2.ONE, 0.42).from(Vector2(0.86, 0.86)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if sfx:
		sfx.tutor()                              # balbuceo corto (respeta el mute global)
	_posicionar_burbuja(destino, tam)            # async, fire-and-forget (no bloquea el retorno)
	return true


# Coloca la burbuja arriba del robot (franja derecha) y la hace aparecer. Espera 2 frames
# a que el layout (label con autowrap) se asiente, igual que el globo del tutorial.
func _posicionar_burbuja(destino: Vector2, tam: float) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not _tutor_activo or not is_instance_valid(_tutor_burbuja):
		return
	var esc := escenario_col.get_global_rect()
	var bs: Vector2 = _tutor_burbuja.size
	var bx := clampf(destino.x + tam - bs.x, esc.position.x + 6.0, size.x - bs.x - 8.0)
	var by := clampf(destino.y - bs.y - 8.0, 8.0, size.y - bs.y - 8.0)
	_tutor_burbuja.position = Vector2(bx, by)
	var entra := create_tween()
	entra.tween_property(_tutor_burbuja, "modulate:a", 1.0, 0.25)


# Cierre con animación (lo dispara el jugador: botón o tap en la burbuja).
func _cerrar_comentario() -> void:
	if not _tutor_activo or _tutor_cerrando:
		return
	_tutor_cerrando = true
	if is_instance_valid(_tutorbot):
		_tutorbot.set_hablando(false)            # apaga la animación de "hablar" limpio
		_tutorbot.scale = Vector2.ONE            # por si el bote no terminó (cierre rápido)
	if sfx:
		sfx.click()
	if is_instance_valid(_tutor_burbuja):
		var f := create_tween()
		f.tween_property(_tutor_burbuja, "modulate:a", 0.0, 0.15)
		f.tween_callback(func(): if is_instance_valid(_tutor_burbuja): _tutor_burbuja.queue_free())
	if _tutor_tween and _tutor_tween.is_valid():
		_tutor_tween.kill()
	_tutor_tween = create_tween()
	if is_instance_valid(_tutorbot):
		_tutor_tween.tween_property(_tutorbot, "position", _tutor_origen, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tutor_tween.tween_callback(_finalizar_comentario)


func _finalizar_comentario() -> void:
	if is_instance_valid(_tutorbot):
		_tutorbot.queue_free()
	_tutorbot = null
	_tutor_burbuja = null
	if tutor_capa:
		tutor_capa.visible = false
	if robot:
		robot.modulate.a = 1.0
	_tutor_activo = false
	_tutor_cerrando = false
	_charla_activa = false


# Cierre inmediato (sin animación) cuando se navega de nivel o se abre otra pantalla.
func _tutor_cerrar_inmediato() -> void:
	if _tutor_tween and _tutor_tween.is_valid():
		_tutor_tween.kill()
	if is_instance_valid(_tutor_burbuja):
		_tutor_burbuja.queue_free()
	_tutor_burbuja = null
	if is_instance_valid(_tutorbot):
		_tutorbot.queue_free()
	_tutorbot = null
	if tutor_capa:
		tutor_capa.visible = false
	if robot:
		robot.modulate.a = 1.0
	_tutor_activo = false
	_tutor_cerrando = false
	_charla_activa = false
	_gano_pendiente = false


# Momento clave 1: primera vez que el jugador arma programa (pone una instrucción). Si la
# pantalla no está libre (p. ej. tutorial del nivel 1), no marca el flag y reintenta luego.
func _quizas_comentario_primer_programa() -> void:
	if not _puede_tutorial() or Puntajes.flag("vio_robot_prog"):
		return
	if _robot_comenta(TUTOR_PRIMER_PROG, "feliz"):
		Puntajes.set_flag("vio_robot_prog", true)


# Saludo seco según hora/día reales (Time). Rota sin repetir el último mostrado.
func _saludo_contextual() -> String:
	var ahora := Time.get_datetime_dict_from_system()
	var hora := int(ahora.get("hour", 12))
	var dia := int(ahora.get("weekday", 1))    # 0=domingo ... 6=sábado
	var pool: Array = []
	if dia == 0 or dia == 6:
		pool.append(SALUDO_FINDE)
	if hora < 6:
		pool.append_array(SALUDOS_MADRUGADA)
	elif hora < 12:
		pool.append_array(SALUDOS_MANANA)
	elif hora < 19:
		pool.append_array(SALUDOS_TARDE)
	else:
		pool.append_array(SALUDOS_NOCHE)
	pool.append_array(SALUDOS_GENERICOS)
	var opciones := pool.filter(func(s): return s != _ultimo_saludo)
	if opciones.is_empty():
		opciones = pool
	var elegido: String = opciones[randi() % opciones.size()]
	_ultimo_saludo = elegido
	return elegido


# Comentario seco al ganar (rotación SIN repetir hasta agotar el pool). Reusa el robot+
# burbuja del tutor; _robot_comenta ya garantiza "nunca dos cosas hablando a la vez".
func _chiste_random() -> String:
	if CHISTES_GANAR.is_empty():
		return ""
	if _chistes_baraja.is_empty():
		_chistes_baraja = range(CHISTES_GANAR.size())
		_chistes_baraja.shuffle()
	var i: int = _chistes_baraja.pop_back()
	return CHISTES_GANAR[i]


func _comentario_ganar_random() -> void:
	var c := _chiste_random()
	if c != "":
		_robot_comenta(c, "feliz")


# Click en el robot del juego: suelta una frase seca (charla ocasional). Reusa el pool
# (chistes de programación + saludos genéricos) y la MISMA burbuja del tutor. No molesta:
# si ya hay algo hablando o el robot está corriendo un programa, no dispara (mismo guard).
# La burbuja se cierra sola a CHARLA_SEG o al primer click (lo maneja _input).
func _on_robot_click() -> void:
	if corriendo or not _tutor_libre():
		return
	var frase := _charla_random()
	if frase == "" or not _robot_comenta(frase, "feliz", false):
		return
	_charla_activa = true
	_charla_id += 1
	var id := _charla_id
	get_tree().create_timer(CHARLA_SEG).timeout.connect(func():
		if _charla_activa and _charla_id == id:
			_cerrar_charla())


func _cerrar_charla() -> void:
	if not _charla_activa:
		return
	_charla_activa = false
	_cerrar_comentario()


# Frase de charla rotando SIN repetir la anterior (chistes + saludos genéricos secos).
func _charla_random() -> String:
	var pool: Array = []
	pool.append_array(CHISTES_GANAR)
	pool.append_array(SALUDOS_GENERICOS)
	var ops := pool.filter(func(s): return s != _ultima_charla)
	if ops.is_empty():
		ops = pool
	if ops.is_empty():
		return ""
	var elegida: String = ops[randi() % ops.size()]
	_ultima_charla = elegida
	return elegida


# Issue #1 — AVANCE al ganar, SEPARADO del gate de código. La celebración (banner) y el
# código-al-ganar (solo las 3 primeras veces) ya no son el único camino para avanzar:
# tras cerrar el banner, si hay un próximo nivel el robot lo ofrece SIEMPRE con un botón
# (a veces con un comentario seco encima). En el último nivel no hay a dónde ir: cae al
# comentario ocasional. (El código-al-ganar mantiene su propio "Siguiente nivel" en el footer.)
func _ofrecer_avance_al_ganar() -> void:
	if nivel_idx < orden.size() - 1:
		var txt := "¡Listo! ¿Vamos al que sigue?"
		if randf() < CHISTE_PROB:
			var c := _chiste_random()
			if c != "":
				txt = c
		_robot_comenta(txt, "feliz", true, "Siguiente nivel ▸", Callable(self, "_on_next"))
	elif randf() < CHISTE_PROB:
		_comentario_ganar_random()


# Ajuste D: cuántas veces ya se mostró el código-al-ganar (tope 3). Vive en el .cfg de
# Puntajes → "Reiniciar progreso" lo resetea con el resto. La API de flags es bool-only
# (no hay setter de int), así que el contador se representa con 3 flags cod_ganar_1/2/3.
func _veces_cod_ganar() -> int:
	var n := 0
	for i in 3:
		if Puntajes.flag("cod_ganar_%d" % (i + 1)):
			n += 1
	return n


func _marcar_cod_ganar() -> void:
	var n := _veces_cod_ganar()
	if n < 3:
		Puntajes.set_flag("cod_ganar_%d" % (n + 1), true)


# Sub-tanda D — AL GANAR: tras la celebración mostramos el programa traducido a código
# (el mismo del panel "Ver en C/C#", según el track) y el robot lo comenta a alto nivel.
# Salteable: Seguir (queda) / Siguiente nivel (avanza). Reusa el panel y el tutor; no
# rehace UI ni traducción. En headless no corre (igual el banner nunca dispara ahí).
# Solo las primeras 3 victorias (_gano_pendiente ya viene gateado por _veces_cod_ganar).
func _mostrar_codigo_al_ganar() -> void:
	if not _puede_tutorial() or nivel == null:
		return
	_marcar_cod_ganar()               # registra esta aparición (cuenta para el tope de 3)
	_codigo_modo_ganar = true
	_aplicar_modo_codigo()
	csharp_texto.text = (Cc.generar(programa_modelo()) if track == "c" else Csharp.generar(programa_modelo()))
	csharp_capa.visible = true
	csharp_capa.move_to_front()
	# El robot acompaña con el puente (sin su botón: el flujo lo dan Seguir/Siguiente nivel).
	_robot_comenta(TUTOR_CODIGO_GANAR % _nombre_track(), "feliz", false)


func _codigo_seguir() -> void:
	_cerrar_csharp()                  # cierra panel + robot (modo ganar); queda en el nivel


func _codigo_siguiente_nivel() -> void:
	_cerrar_csharp()
	_on_next()                        # _cargar_indice ya resetea el nivel y cierra el tutor


# Nombre del track para los textos del robot ("C" / "C#").
func _nombre_track() -> String:
	return "C" if track == "c" else "C#"


# Ajusta el panel de código según el modo: normal (✕, título base) vs "al ganar"
# (sin ✕, footer Seguir/Siguiente, título festejo). No toca la traducción.
func _aplicar_modo_codigo() -> void:
	var base := "Tu solución en C" if track == "c" else "Tu solución en C#"
	if csharp_titulo:
		csharp_titulo.text = ("¡Pasaste!  " + base) if _codigo_modo_ganar else base
	if _codigo_x:
		_codigo_x.visible = not _codigo_modo_ganar
	if _codigo_footer:
		_codigo_footer.visible = _codigo_modo_ganar


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
	# Deshabilitado: mismo stylebox que normal (no el gris del tema); lo atenúa el modulate.
	b.add_theme_stylebox_override("disabled", normal)
	b.add_theme_color_override("font_disabled_color", Color.WHITE if acento else COL_TEXTO)
	return b


func _boton_nav(txt: String) -> Button:
	var b := _boton_accion(txt, false)
	b.custom_minimum_size = Vector2(44, 40)
	return b


# Botón estilo "enlace": sin fondo, texto tenue que se vuelve acento al pasar.
func _boton_link(txt: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", fuente_sans)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", COL_TENUE)
	b.add_theme_color_override("font_hover_color", COL_ACENTO)
	b.add_theme_color_override("font_pressed_color", COL_ACENTO)
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


# Caption de una zona del escenario con tooltip explicativo (hover/tap).
func _zona_label(texto: String, tip: String) -> Label:
	var l := _etiqueta(texto, 13, COL_TENUE, true)
	l.tooltip_text = tip
	l.mouse_filter = Control.MOUSE_FILTER_STOP   # para que el tooltip aparezca
	return l


func _str_valor(v) -> String:
	if v == null:
		return "·"
	return str(v)


# ---------------------------------------------------------------------------
# Inner classes cosmeticas (onda de celebracion + spotlight del tutorial).
# ---------------------------------------------------------------------------

# Onda: anillo (color primario) que se expande y se desvanece. Cosmetico.
class Onda extends Control:
	var color := Tema.PRIMARIO
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
#   permitir_hueco=true -> los clics dentro del objetivo PASAN al control de abajo
#                          (paso interactivo: "tocá agarrá"); el resto se bloquea.
#   mostrar_velo=false  -> no oscurece ni bloquea nada (último paso: mirás el juego).
class Spotlight extends Control:
	var objetivo := Rect2()
	var velo := Color(0.14, 0.13, 0.11, 0.62)
	var marco := Tema.PRIMARIO
	var permitir_hueco := false
	var mostrar_velo := true
	var _t := 0.0                            # fase del pulso del marco (pasos interactivos)

	func _process(delta: float) -> void:
		# Solo animamos (y redibujamos) cuando hay un objetivo interactivo que pulsar.
		if permitir_hueco and objetivo.size != Vector2.ZERO:
			_t += delta
			queue_redraw()

	# Picking: con velo, captura todo MENOS el hueco interactivo. Sin velo, no captura.
	func _has_point(p: Vector2) -> bool:
		if not mostrar_velo:
			return false
		if permitir_hueco and objetivo.size != Vector2.ZERO and objetivo.has_point(p):
			return false
		return true

	func _draw() -> void:
		if not mostrar_velo:
			return
		if objetivo.size == Vector2.ZERO:
			draw_rect(Rect2(Vector2.ZERO, size), velo)
			return
		# 4 rects alrededor del objetivo (deja el hueco transparente).
		var o := objetivo
		draw_rect(Rect2(0, 0, size.x, o.position.y), velo)                                   # arriba
		draw_rect(Rect2(0, o.position.y + o.size.y, size.x, size.y - (o.position.y + o.size.y)), velo)  # abajo
		draw_rect(Rect2(0, o.position.y, o.position.x, o.size.y), velo)                       # izquierda
		draw_rect(Rect2(o.position.x + o.size.x, o.position.y, size.x - (o.position.x + o.size.x), o.size.y), velo)  # derecha
		# Marco alrededor del hueco. En pasos interactivos, pulso/glow para gritar "tocá acá".
		if permitir_hueco:
			var p := 0.5 + 0.5 * sin(_t * 4.2)
			draw_rect(o.grow(3.0 + 4.0 * p), Color(marco.r, marco.g, marco.b, 0.22 + 0.4 * p), false, 3.0)
		draw_rect(o, marco, false, 2.0)


# Botón-tuerca dibujado por código (no usa imágenes): cuerpo con 8 dientes y hueco
# central del color del fondo. Apagado en COL_TENUE, acento al pasar el mouse.
# Vive en la esquina de la pantalla de inicio y abre la Configuración.
class Tuerca extends Control:
	signal apretado
	var color := Tema.TENUE              # color en reposo
	var color_hover := Tema.PRIMARIO     # color al pasar el mouse
	var color_hueco := Tema.FONDO        # hueco central (= fondo donde se apoya)
	var _hover := false

	func _ready() -> void:
		custom_minimum_size = Vector2(40, 40)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func(): _hover = true; queue_redraw())
		mouse_exited.connect(func(): _hover = false; queue_redraw())

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			apretado.emit()
			accept_event()

	func _draw() -> void:
		var c := size / 2.0
		var col := color_hover if _hover else color
		var r := minf(size.x, size.y) * 0.30   # radio del cuerpo
		var dientes := 8
		var ang_medio := deg_to_rad(13.0)       # mitad del ancho angular del diente (base)
		var ang_punta := deg_to_rad(8.0)         # algo más angosto en la punta (trapecio)
		var r_punta := r * 1.42
		for i in dientes:
			var a := TAU * i / float(dientes)
			var quad := PackedVector2Array([
				c + Vector2(cos(a - ang_medio), sin(a - ang_medio)) * r,
				c + Vector2(cos(a - ang_punta), sin(a - ang_punta)) * r_punta,
				c + Vector2(cos(a + ang_punta), sin(a + ang_punta)) * r_punta,
				c + Vector2(cos(a + ang_medio), sin(a + ang_medio)) * r,
			])
			draw_colored_polygon(quad, col)
		draw_circle(c, r * 1.04, col)            # cuerpo (tapa las bases de los dientes)
		draw_circle(c, r * 0.40, color_hueco)    # hueco central
