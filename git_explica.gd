class_name GitExplica
extends Control

# "Aprendé Git" — Capa 1: explicador VISUAL guiado. El robot VIAJA por la pantalla
# hacia donde está la acción (Tween) y habla en un bocadillo de 1 frase. En el
# momento clave de cada paso, un SPOTLIGHT (mismo mecanismo que el tutorial del
# nivel 1 en main.gd) oscurece todo menos la burbuja y el objeto señalado. Avance
# mixto: pasos conceptuales se MIRAN, los de acción se HACEN (un botón con el gesto
# dispara la animación). Presentación pura: NO toca intérprete/validador/niveles/
# git_mini/git_sandbox. La consola interactiva es la Capa 2.

signal abrir_consola                     # el botón del último paso pide abrir la Capa 2

var _mono: SystemFont
var _sans: SystemFont

var _paso := 0
var _flujo_tween: Tween                  # animación del flujo (prog 0→1)
var _guia_tween: Tween                   # viaje del robot
var _spot_tween: Tween                   # pulso del spotlight

var _lienzo: Lienzo
var _spotlight: Spotlight
var _guia: HBoxContainer                 # robot + bocadillo (viaja por la pantalla)
var _robot: Robot
var _bocadillo: Bocadillo
var _accion_row: HBoxContainer
var _b_accion: Button
var _cmd_pill: PanelContainer
var _cmd_label: Label
var _b_prev: Button
var _b_next: Button
var _paso_label: Label
var _b_consola: Button


# Cada paso: id, frase (≤1 línea), tipo "mira"|"hace", escena, gesto, comando,
# foco (Rect2 REL al lienzo: el hueco del spotlight), robot_x (REL al lienzo: a dónde viaja).
func _pasos() -> Array:
	return [
		{"frase": "Git guarda todo el historial de tu proyecto: cada cambio que hacés, guardado.", "tipo": "mira", "escena": "repo",
			"gesto": "", "comando": "", "foco": Rect2(0.30, 0.20, 0.44, 0.55), "robot_x": 0.50},
		{"frase": "Tu computadora y un servidor en la nube, conectados.", "tipo": "mira", "escena": "local_nube",
			"gesto": "", "comando": "", "foco": Rect2(0.08, 0.20, 0.84, 0.44), "robot_x": 0.32},
		{"frase": "Marcás qué cambios querés guardar.", "tipo": "hace", "escena": "cambio_add",
			"gesto": "Preparar el archivo", "comando": "git add", "foco": Rect2(0.12, 0.18, 0.74, 0.60), "robot_x": 0.26},
		{"frase": "Es un punto del historial al que podés volver.", "tipo": "hace", "escena": "commit",
			"gesto": "Guardar este avance", "comando": "git commit", "foco": Rect2(0.16, 0.16, 0.66, 0.58), "robot_x": 0.32},
		{"frase": "Tu avance queda guardado online.", "tipo": "hace", "escena": "push",
			"gesto": "Subir a la nube", "comando": "git push", "foco": Rect2(0.10, 0.18, 0.80, 0.44), "robot_x": 0.62},
		{"frase": "Bajás los cambios nuevos desde la nube.", "tipo": "hace", "escena": "pull",
			"gesto": "Traer de la nube", "comando": "git pull", "foco": Rect2(0.10, 0.18, 0.80, 0.44), "robot_x": 0.60},
		{"frase": "¡Listo! Ya entendés git.", "tipo": "mira", "escena": "resumen",
			"gesto": "", "comando": "", "foco": Rect2(0.06, 0.04, 0.88, 0.90), "robot_x": 0.46, "robot_y": -150.0},
	]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_mono = SystemFont.new()
	_mono.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "JetBrains Mono", "DejaVu Sans Mono", "monospace"])
	_sans = SystemFont.new()
	_sans.font_names = PackedStringArray(["Segoe UI", "Inter", "Helvetica Neue", "Arial", "sans-serif"])

	var fondo := ColorRect.new()
	fondo.color = Tema.FONDO
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)

	# Banda superior reservada para el robot viajero (que flota por encima, no en el flujo).
	var banda := Control.new()
	banda.custom_minimum_size = Vector2(820, 104)
	banda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(banda)

	_lienzo = Lienzo.new()
	_lienzo.custom_minimum_size = Vector2(820, 320)
	_lienzo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lienzo.mono = _mono
	_lienzo.sans = _sans
	v.add_child(_lienzo)

	# Fila de acción: botón del gesto (pasos "hace") + rótulo del comando (tras el gesto).
	_accion_row = HBoxContainer.new()
	_accion_row.add_theme_constant_override("separation", 14)
	_accion_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_accion_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_accion_row.custom_minimum_size = Vector2(0, 52)
	_b_accion = _boton("", true)
	_b_accion.custom_minimum_size = Vector2(220, 46)
	_b_accion.pressed.connect(_on_accion)
	_accion_row.add_child(_b_accion)
	_cmd_pill = _crear_pill()
	_accion_row.add_child(_cmd_pill)
	v.add_child(_accion_row)

	# Navegación.
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 14)
	nav.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_b_prev = _boton("◀ Anterior", false)
	_b_prev.custom_minimum_size = Vector2(140, 42)
	_b_prev.pressed.connect(_anterior)
	nav.add_child(_b_prev)
	_paso_label = _label("", _sans, 14, Tema.TENUE, HORIZONTAL_ALIGNMENT_CENTER)
	_paso_label.custom_minimum_size = Vector2(110, 0)
	_paso_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nav.add_child(_paso_label)
	_b_next = _boton("Siguiente ▶", true)
	_b_next.custom_minimum_size = Vector2(140, 42)
	_b_next.pressed.connect(_siguiente)
	nav.add_child(_b_next)
	v.add_child(nav)

	_b_consola = _boton("Practicá en la consola ▶", true)
	_b_consola.custom_minimum_size = Vector2(260, 42)
	_b_consola.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_b_consola.pressed.connect(func():
		cerrar_modulo()
		abrir_consola.emit())
	v.add_child(_b_consola)

	# Spotlight (mismo mecanismo que el tutorial del nivel 1): velo con un hueco.
	# Es SOLO visual (mouse IGNORE): enfatiza, no bloquea. Va sobre el flujo.
	_spotlight = Spotlight.new()
	_spotlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_spotlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_spotlight)

	# Robot viajero + bocadillo: por ENCIMA del spotlight (siempre iluminado).
	_guia = HBoxContainer.new()
	_guia.add_theme_constant_override("separation", 4)
	_guia.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_robot = Robot.new()
	_robot.custom_minimum_size = Vector2(92, 92)
	_guia.add_child(_robot)
	_bocadillo = Bocadillo.new(_sans)
	_bocadillo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_guia.add_child(_bocadillo)
	add_child(_guia)

	# ✕ cerrar: lo último, siempre clickeable arriba a la derecha.
	var cerrar := _boton("✕", false)
	cerrar.set_anchor(SIDE_LEFT, 1.0)
	cerrar.set_anchor(SIDE_RIGHT, 1.0)
	cerrar.offset_left = -58
	cerrar.offset_right = -18
	cerrar.offset_top = 18
	cerrar.offset_bottom = 54
	cerrar.pressed.connect(cerrar_modulo)
	add_child(cerrar)

	var header := _label("Aprendé Git", _sans, 20, Tema.TENUE)
	header.position = Vector2(24, 22)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)


func abrir() -> void:
	visible = true
	move_to_front()
	_paso = 0
	_mostrar_paso(true)


# Coloca el spotlight y el robot según la geometría YA calculada del lienzo. Se
# llama un frame DESPUÉS de cambiar de paso, porque la visibilidad de los botones
# (b_accion / b_consola) cambia la altura del VBox y mueve el lienzo: si midiéramos
# antes, el hueco quedaría corrido (cortaba el resumen, el robot pisaba la lista).
func _colocar_foco(instantaneo: bool) -> void:
	var p: Dictionary = _pasos()[_paso]
	var lr := Rect2(_lienzo.global_position, _lienzo.size)
	if lr.size.x < 10.0:
		return
	var fr: Rect2 = p.foco
	_spotlight.objetivo = Rect2(lr.position.x + fr.position.x * lr.size.x, lr.position.y + fr.position.y * lr.size.y,
		fr.size.x * lr.size.x, fr.size.y * lr.size.y)
	var cx: float = lr.position.x + float(p.robot_x) * lr.size.x
	var ry: float = float(p.get("robot_y", -100.0))   # offset y del robot respecto al tope del lienzo
	var destino := Vector2(clampf(cx - 46.0, 16.0, size.x - 360.0), clampf(lr.position.y + ry, 50.0, size.y - 130.0))
	if _guia_tween and _guia_tween.is_valid():
		_guia_tween.kill()
	if instantaneo:
		_guia.position = destino
	else:
		_guia_tween = create_tween()
		_guia_tween.tween_property(_guia, "position", destino, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pulso_spotlight()


func cerrar_modulo() -> void:
	_matar_tweens()
	visible = false


func _matar_tweens() -> void:
	for t in [_flujo_tween, _guia_tween, _spot_tween]:
		if t and t.is_valid():
			t.kill()


func _anterior() -> void:
	if _paso > 0:
		_paso -= 1
		_mostrar_paso(false)


func _siguiente() -> void:
	if _paso >= _pasos().size() - 1:
		cerrar_modulo()
		return
	_paso += 1
	_mostrar_paso(false)


func _mostrar_paso(instantaneo: bool) -> void:
	_matar_tweens()
	_spotlight.intensidad = 0.0                  # sin velo viejo durante el frame de espera
	var pasos := _pasos()
	var p: Dictionary = pasos[_paso]
	var es_accion: bool = p.tipo == "hace"
	var ultimo := _paso == pasos.size() - 1

	_bocadillo.set_texto(p.frase)
	_lienzo.escena = p.escena
	_lienzo._t = 0.0
	_cmd_label.text = str(p.comando)
	_cmd_pill.visible = false

	_b_accion.visible = es_accion
	_b_accion.text = str(p.gesto)
	_b_accion.disabled = false
	_b_accion.modulate.a = 1.0

	_b_next.text = "Terminar ✓" if ultimo else "Siguiente ▶"
	_b_next.disabled = es_accion
	_b_next.modulate.a = 0.4 if es_accion else 1.0
	_b_prev.disabled = _paso == 0
	_b_prev.modulate.a = 0.4 if _paso == 0 else 1.0
	_paso_label.text = "Paso %d de %d" % [_paso + 1, pasos.size()]
	_b_consola.visible = ultimo
	if _robot:
		_robot.set_mood("fiesta" if ultimo else "idle")

	# Animación del flujo: "mira" corre sola; "hace" espera el gesto.
	if es_accion:
		_lienzo.prog = 0.0
		_lienzo.queue_redraw()
	elif instantaneo:
		_lienzo.prog = 1.0
		_lienzo.queue_redraw()
	else:
		_animar_flujo(false)

	# El foco (spotlight + robot) se coloca un frame DESPUÉS, con el layout ya estable.
	var paso_actual := _paso
	await get_tree().process_frame
	if not is_inside_tree() or not visible or _paso != paso_actual:
		return
	_colocar_foco(instantaneo)


# Pulso del spotlight: oscurece (sube intensidad), sostiene y se levanta. Solo visual.
func _pulso_spotlight() -> void:
	if _spot_tween and _spot_tween.is_valid():
		_spot_tween.kill()
	_spotlight.intensidad = 0.0
	_spotlight.queue_redraw()
	_spot_tween = create_tween()
	_spot_tween.tween_property(_spotlight, "intensidad", 1.0, 0.35)
	_spot_tween.tween_interval(0.55)
	_spot_tween.tween_property(_spotlight, "intensidad", 0.0, 0.5)


func _animar_flujo(con_callback: bool) -> void:
	if _flujo_tween and _flujo_tween.is_valid():
		_flujo_tween.kill()
	_lienzo.prog = 0.0
	_flujo_tween = create_tween()
	_flujo_tween.tween_property(_lienzo, "prog", 1.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if con_callback:
		_flujo_tween.tween_callback(_accion_terminada)


func _on_accion() -> void:
	_b_accion.disabled = true
	_b_accion.modulate.a = 0.5
	if _robot:
		_robot.set_mood("pensando")
	_animar_flujo(true)


func _accion_terminada() -> void:
	var p: Dictionary = _pasos()[_paso]
	_b_next.disabled = false
	_b_next.modulate.a = 1.0
	_cmd_pill.visible = p.comando != ""
	if _robot:
		_robot.set_mood("feliz")


# ---------------------------------------------------------------------------
# Helpers de widgets
# ---------------------------------------------------------------------------
func _label(texto: String, fuente: Font, tam: int, color: Color, halign := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return UiKit.label(texto, fuente, tam, color, halign)


func _boton(txt: String, acento: bool) -> Button:
	return UiKit.boton(txt, acento, _sans)


func _crear_pill() -> PanelContainer:
	var pill := PanelContainer.new()
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Tema.PRIMARIO_TENUE
	sb.border_color = Tema.PRIMARIO
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(9)
	sb.content_margin_left = 14; sb.content_margin_right = 14
	sb.content_margin_top = 8; sb.content_margin_bottom = 8
	pill.add_theme_stylebox_override("panel", sb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.add_child(_label("Este comando es:", _sans, 14, Tema.TENUE))
	_cmd_label = _label("", _mono, 17, Tema.PRIMARIO)
	hb.add_child(_cmd_label)
	pill.add_child(hb)
	return pill


# ---------------------------------------------------------------------------
# Bocadillo: burbuja de 1 frase con colita que apunta al robot (el robot habla).
# ---------------------------------------------------------------------------
class Bocadillo extends MarginContainer:
	var _label: Label

	func _init(fuente: Font) -> void:
		add_theme_constant_override("margin_left", 22)
		add_theme_constant_override("margin_right", 16)
		add_theme_constant_override("margin_top", 11)
		add_theme_constant_override("margin_bottom", 11)
		_label = Label.new()
		_label.add_theme_font_override("font", fuente)
		_label.add_theme_font_size_override("font_size", 18)
		_label.add_theme_color_override("font_color", Tema.TEXTO)
		# Frases más largas: envolvemos a un ancho fijo para que el bocadillo no se
		# salga del viewport (1000px). El ancho mantiene robot+burbuja ≤ ~360px, la
		# reserva que ya usa el clamp de _colocar_foco al ubicar al robot a la derecha.
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.custom_minimum_size = Vector2(220, 0)
		add_child(_label)

	func set_texto(t: String) -> void:
		_label.text = t
		queue_redraw()

	func _draw() -> void:
		var ty := size.y * 0.5
		# Colita hacia la izquierda (al robot): deja claro quién habla.
		draw_colored_polygon(PackedVector2Array([Vector2(10, ty - 9), Vector2(10, ty + 9), Vector2(-2, ty)]), Tema.PANEL)
		draw_line(Vector2(10, ty - 9), Vector2(-2, ty), Tema.CALIDO, 2.0)
		draw_line(Vector2(-2, ty), Vector2(10, ty + 9), Tema.CALIDO, 2.0)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Tema.PANEL
		sb.border_color = Tema.CALIDO
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(13)
		sb.shadow_color = Color(0.14, 0.13, 0.11, 0.18)
		sb.shadow_size = 6
		draw_style_box(sb, Rect2(8, 0, size.x - 8, size.y))


# ---------------------------------------------------------------------------
# Spotlight: velo oscuro con un hueco (mismo mecanismo que el tutorial, main.gd).
# `intensidad` (0..1) multiplica el alpha para poder hacer fade in/out.
# ---------------------------------------------------------------------------
class Spotlight extends Control:
	var objetivo := Rect2()
	var intensidad := 0.0
	var _velo := Color(0.14, 0.13, 0.11, 0.62)

	func _process(_delta: float) -> void:
		if is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		if intensidad <= 0.001:
			return
		var a := clampf(intensidad, 0.0, 1.0)
		var velo := Color(_velo.r, _velo.g, _velo.b, _velo.a * a)
		if objetivo.size == Vector2.ZERO:
			draw_rect(Rect2(Vector2.ZERO, size), velo)
			return
		var o := objetivo
		draw_rect(Rect2(0, 0, size.x, o.position.y), velo)
		draw_rect(Rect2(0, o.position.y + o.size.y, size.x, size.y - (o.position.y + o.size.y)), velo)
		draw_rect(Rect2(0, o.position.y, o.position.x, o.size.y), velo)
		draw_rect(Rect2(o.position.x + o.size.x, o.position.y, size.x - (o.position.x + o.size.x), o.size.y), velo)
		draw_rect(o, Color(Tema.PRIMARIO.r, Tema.PRIMARIO.g, Tema.PRIMARIO.b, a), false, 2.0)


# ---------------------------------------------------------------------------
# Lienzo: dibuja y ANIMA la escena. `prog` (0..1) maneja la transición del paso.
# ---------------------------------------------------------------------------
class Lienzo extends Control:
	var escena := ""
	var prog := 0.0
	var _t := 0.0
	var mono: Font
	var sans: Font

	func _process(delta: float) -> void:
		if is_visible_in_tree():
			_t += delta
			queue_redraw()

	func _draw() -> void:
		match escena:
			"repo": _draw_repo()
			"local_nube": _draw_local_nube()
			"cambio_add": _draw_cambio_add()
			"commit": _draw_commit()
			"push": _draw_push()
			"pull": _draw_pull()
			"resumen": _draw_resumen()

	func _pc_pos() -> Vector2: return Vector2(size.x * 0.24, size.y * 0.40)
	func _srv_pos() -> Vector2: return Vector2(size.x * 0.76, size.y * 0.40)

	# --- 1. Repo: git le saca una foto a tu proyecto ---
	func _draw_repo() -> void:
		var c := Vector2(size.x * 0.42, size.y * 0.48)
		_carpeta(c, "tu-proyecto/")
		var a := clampf(prog, 0.0, 1.0)
		if a > 0.1:
			# La "foto" que git saca, apareciendo al lado de la carpeta.
			var fp := Vector2(c.x + 150, c.y - 6)
			draw_line(c + Vector2(74, -6), fp + Vector2(-18, 0), Color(Tema.PRIMARIO.r, Tema.PRIMARIO.g, Tema.PRIMARIO.b, 0.5 * a), 2.0)
			_foto(fp, 1.3 + 0.15 * a, Color(Tema.PRIMARIO.r, Tema.PRIMARIO.g, Tema.PRIMARIO.b, 0.35 + 0.65 * a))
			_texto("una copia de tu proyecto", Vector2(fp.x - 56, fp.y + 40), 13, Color(Tema.TEXTO.r, Tema.TEXTO.g, Tema.TEXTO.b, a))

	# --- 2. Local y nube: la línea se "dibuja" entre la PC y el servidor ---
	func _draw_local_nube() -> void:
		var pc := _pc_pos()
		var srv := _srv_pos()
		var p_ini := Vector2(pc.x + 70, pc.y)
		var p_fin := Vector2(srv.x - 64, srv.y)
		draw_line(p_ini, p_fin, Tema.CELDA_BORDE, 3.0)
		draw_line(p_ini, p_ini.lerp(p_fin, clampf(prog, 0.0, 1.0)), Tema.PRIMARIO, 3.0)
		_pc(pc)
		_servidor(srv)
		if prog >= 0.98:
			_foto(p_ini.lerp(p_fin, fmod(_t * 0.5, 1.0)), 0.55, Tema.PRIMARIO)

	# --- 3 (fusión cambios+add). Elegís qué entra en la foto (metáfora física) ---
	func _draw_cambio_add() -> void:
		var pc := Vector2(size.x * 0.20, size.y * 0.40)
		_pc(pc)
		var marco := Vector2(size.x * 0.70, size.y * 0.42)
		_marco_foto(marco, "lo que vas a guardar")
		var t := clampf(prog, 0.0, 1.0)
		# Tus archivos editados, en el medio. Dos limpios quedan afuera; uno lo ELEGÍS.
		var base := Vector2(size.x * 0.44, size.y * 0.34)
		_foto(base + Vector2(-2, 46), 1.0, Tema.EXITO)
		_foto(base + Vector2(32, 46), 1.0, Tema.EXITO)
		_texto("quedan afuera", Vector2(base.x - 12, base.y + 80), 12, Tema.TENUE)
		# El elegido (modificado → preparado) viaja al marco de la próxima foto.
		var col := Tema.CALIDO.lerp(Tema.PRIMARIO, t)
		_foto(base.lerp(marco, t), 1.4, col)

	# --- 4. Commit: la cajita entra al historial local (con flash de foto) ---
	# Horizontal: la cajita sale del marco de la foto y entra al historial (a la
	# derecha). Así la trayectoria no pasa por debajo de ningún rótulo.
	func _draw_commit() -> void:
		var stage := Vector2(size.x * 0.30, size.y * 0.46)
		var hist := Vector2(size.x * 0.64, size.y * 0.46)
		_marco_foto(stage, "este avance", -54)          # rótulo ARRIBA del marco
		_pila(hist, 1, "historial local")               # rótulo ABAJO de la pila
		var t := clampf(prog, 0.0, 1.0)
		if t < 0.35:
			draw_circle(stage, 36.0, Color(1, 1, 1, 0.32 * (1.0 - t / 0.35)))
		_foto(stage.lerp(hist, t), 1.3, Tema.PRIMARIO)

	# --- 5. Push: la cajita viaja por la línea, de la PC a la nube ---
	func _draw_push() -> void:
		var pc := _pc_pos()
		var srv := _srv_pos()
		var p_ini := Vector2(pc.x + 70, pc.y)
		var p_fin := Vector2(srv.x - 64, srv.y)
		draw_line(p_ini, p_fin, Tema.PRIMARIO, 3.0)
		_pc(pc)
		_servidor(srv)
		# Pilas BIEN abajo, lejos de la línea por la que viaja la cajita (en y = pc.y).
		_pila(Vector2(pc.x, pc.y + 116), 1, "tu historial")
		var t := clampf(prog, 0.0, 1.0)
		_pila(Vector2(srv.x, srv.y + 116), 1 if t >= 0.96 else 0, "en la nube")
		if t < 0.96:
			_foto(p_ini.lerp(p_fin, t), 1.1, Tema.PRIMARIO)
		_texto("→ a la nube", Vector2((pc.x + srv.x) * 0.5 - 36, pc.y - 22), 13, Tema.PRIMARIO)

	# --- 6. Pull: alguien subió algo; la cajita viaja de la nube a la PC ---
	func _draw_pull() -> void:
		var pc := _pc_pos()
		var srv := _srv_pos()
		var p_ini := Vector2(pc.x + 70, pc.y)
		var p_fin := Vector2(srv.x - 64, srv.y)
		draw_line(p_ini, p_fin, Tema.PRIMARIO, 3.0)
		_pc(pc)
		_servidor(srv)
		var t := clampf(prog, 0.0, 1.0)
		_pila(Vector2(pc.x, pc.y + 116), 1 if t >= 0.96 else 0, "tu historial")
		_pila(Vector2(srv.x, srv.y + 116), 1, "en la nube")
		if t < 0.96:
			_foto(p_fin.lerp(p_ini, t), 1.1, Tema.CALIDO)
		_texto("← a tu PC", Vector2((pc.x + srv.x) * 0.5 - 34, pc.y - 22), 13, Tema.PRIMARIO)

	# --- 7. Resumen de comandos ---
	func _draw_resumen() -> void:
		var filas := [
			["git init", "empezás a seguir una carpeta con git"],
			["git status", "ves qué cambió y qué está preparado"],
			["git add", "elegís qué cambios querés guardar"],
			["git commit", "guardás un avance en tu historial local"],
			["git log", "ves el historial de commits que ya guardaste"],
			["git push", "mandás tus commits a la nube"],
			["git pull", "traés lo nuevo de la nube a tu PC"],
			["git clone", "bajás un repo entero la primera vez"],
		]
		# Paso de fila ajustado para que las 8 filas entren en el alto del lienzo (320).
		var y0 := 20.0
		var x_cmd := size.x * 0.5 - 280.0
		var x_desc := size.x * 0.5 - 70.0
		for k in filas.size():
			var y := y0 + k * 37.0
			draw_string(mono, Vector2(x_cmd, y + 16), filas[k][0], HORIZONTAL_ALIGNMENT_LEFT, 200, 17, Tema.PRIMARIO)
			draw_string(sans, Vector2(x_desc, y + 16), filas[k][1], HORIZONTAL_ALIGNMENT_LEFT, 360, 15, Tema.TEXTO)

	# --- Primitivas ---
	# label_off: dónde va el rótulo respecto al centro (>0 abajo, <0 arriba).
	func _marco_foto(c: Vector2, label: String, label_off := 60.0) -> void:
		# Caja/contenedor donde "guardás" (ya no una cámara): rrect + línea de tapa.
		var r := Rect2(c.x - 56, c.y - 42, 112, 84)
		_rrect(r, 8.0, Tema.PRIMARIO_TENUE, Tema.PRIMARIO)
		var tapa := Color(Tema.PRIMARIO.r, Tema.PRIMARIO.g, Tema.PRIMARIO.b, 0.45)
		draw_line(Vector2(r.position.x + 12, r.position.y + 22), Vector2(r.end.x - 12, r.position.y + 22), tapa, 2.0)
		_texto(label, Vector2(c.x - 42, c.y + label_off), 12, Tema.PRIMARIO)

	func _pc(c: Vector2) -> void:
		var r := Rect2(c.x - 62, c.y - 42, 124, 84)
		_rrect(r, 8.0, Tema.PANEL, Tema.PRIMARIO)
		draw_rect(Rect2(r.position.x + 10, r.position.y + 12, r.size.x - 20, 7), Tema.CELDA)
		draw_rect(Rect2(r.position.x + 10, r.position.y + 26, (r.size.x - 20) * 0.6, 7), Tema.CELDA)
		draw_rect(Rect2(c.x - 9, c.y + 42, 18, 12), Tema.CELDA_BORDE)
		draw_rect(Rect2(c.x - 28, c.y + 54, 56, 6), Tema.CELDA_BORDE)
		_texto("Tu PC · local", Vector2(c.x - 44, c.y + 78), 14, Tema.TENUE)

	func _servidor(c: Vector2) -> void:
		var nube := Color(Tema.CELDA.r, Tema.CELDA.g, Tema.CELDA.b, 0.9)
		draw_circle(c + Vector2(-26, -34), 22, nube)
		draw_circle(c + Vector2(4, -44), 26, nube)
		draw_circle(c + Vector2(32, -32), 20, nube)
		var r := Rect2(c.x - 48, c.y - 44, 96, 92)
		_rrect(r, 8.0, Tema.PANEL, Tema.PRIMARIO)
		for k in 3:
			var sy := r.position.y + 12 + k * 26
			draw_rect(Rect2(r.position.x + 12, sy, r.size.x - 24, 14), Tema.CELDA)
			draw_circle(Vector2(r.position.x + 22, sy + 7), 3.0, Tema.EXITO)
		_texto("GitHub · servidor en la nube", Vector2(c.x - 92, c.y + 70), 14, Tema.TENUE)

	func _carpeta(c: Vector2, label: String) -> void:
		var r := Rect2(c.x - 70, c.y - 36, 140, 96)
		draw_rect(Rect2(r.position.x + 6, r.position.y - 12, 54, 16), Tema.CALIDO)
		_rrect(r, 8.0, Tema.PANEL, Tema.CALIDO)
		_texto(label, Vector2(c.x - 50, c.y + 6), 16, Tema.TEXTO)

	func _pila(base: Vector2, n: int, label: String) -> void:
		for k in n:
			_foto(base + Vector2(k * 8, -k * 8), 1.0, Tema.PRIMARIO)
		_texto(label, Vector2(base.x - 36, base.y + 34), 12, Tema.TENUE)

	# Archivo/cajita guardada (ya no una polaroid): rrect + esquina doblada + renglones.
	func _foto(pos: Vector2, s: float, color: Color) -> void:
		var w := 26.0 * s
		var h := 22.0 * s
		var r := Rect2(pos.x - w * 0.5, pos.y - h * 0.5, w, h)
		_rrect(r, 3.0, Tema.PANEL, color)
		var dog := 6.0 * s
		draw_colored_polygon(PackedVector2Array([Vector2(r.end.x - dog, r.position.y), Vector2(r.end.x, r.position.y + dog), Vector2(r.end.x - dog, r.position.y + dog)]), color)
		var lc := Color(color.r, color.g, color.b, 0.7)
		draw_line(Vector2(r.position.x + 4, r.position.y + h * 0.55), Vector2(r.end.x - 4, r.position.y + h * 0.55), lc, 1.5)
		draw_line(Vector2(r.position.x + 4, r.position.y + h * 0.72), Vector2(r.position.x + w * 0.62, r.position.y + h * 0.72), lc, 1.5)

	func _texto(s: String, pos: Vector2, tam: int, color: Color) -> void:
		if sans:
			draw_string(sans, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, color)

	func _solo_borde(r: Rect2, radio: float, col: Color) -> void:
		var x0 := r.position.x; var y0 := r.position.y
		var x1 := r.position.x + r.size.x; var y1 := r.position.y + r.size.y
		draw_line(Vector2(x0 + radio, y0), Vector2(x1 - radio, y0), col, 2.0)
		draw_line(Vector2(x0 + radio, y1), Vector2(x1 - radio, y1), col, 2.0)
		draw_line(Vector2(x0, y0 + radio), Vector2(x0, y1 - radio), col, 2.0)
		draw_line(Vector2(x1, y0 + radio), Vector2(x1, y1 - radio), col, 2.0)

	func _rrect(r: Rect2, radio: float, fill: Color, borde: Color) -> void:
		draw_rect(Rect2(r.position.x + radio, r.position.y, r.size.x - radio * 2.0, r.size.y), fill)
		draw_rect(Rect2(r.position.x, r.position.y + radio, r.size.x, r.size.y - radio * 2.0), fill)
		draw_circle(r.position + Vector2(radio, radio), radio, fill)
		draw_circle(r.position + Vector2(r.size.x - radio, radio), radio, fill)
		draw_circle(r.position + Vector2(radio, r.size.y - radio), radio, fill)
		draw_circle(r.position + Vector2(r.size.x - radio, r.size.y - radio), radio, fill)
		_solo_borde(r, radio, borde)
