class_name GitExplica
extends Control

# "Aprendé Git" — Capa 1: explicador VISUAL. No son párrafos para leer: el robot
# muestra y el flujo se anima. Texto mínimo (un bocadillo de 1 frase). Avance mixto:
# pasos conceptuales se MIRAN (Siguiente), pasos de acción se HACEN (un botón con el
# gesto dispara la animación, y recién ahí se habilita Siguiente). Presentación pura:
# NO toca intérprete/validador/niveles/git_mini. La consola interactiva es la Capa 2.

signal abrir_consola                     # el botón del último paso pide abrir la Capa 2

var _mono: SystemFont
var _sans: SystemFont

var _paso := 0
var _tween: Tween
var _lienzo: Lienzo
var _robot: Robot
var _bocadillo: Bocadillo
var _titulo: Label
var _accion_row: HBoxContainer
var _b_accion: Button
var _cmd_pill: PanelContainer
var _cmd_label: Label
var _b_prev: Button
var _b_next: Button
var _paso_label: Label
var _b_consola: Button


# Cada paso: {id, titulo, frase (≤1 línea), tipo "mira"|"hace", escena, gesto, comando}.
# "mira" = la animación corre sola; "hace" = el usuario toca el botón del gesto.
func _pasos() -> Array:
	return [
		{"titulo": "¿Qué es un repositorio?", "frase": "Git vigila tu carpeta.",
			"tipo": "mira", "escena": "repo", "gesto": "", "comando": ""},
		{"titulo": "Local y nube", "frase": "Tu PC y un servidor, conectados.",
			"tipo": "mira", "escena": "local_nube", "gesto": "", "comando": ""},
		{"titulo": "Hacés cambios", "frase": "Editás: el archivo cambia.",
			"tipo": "mira", "escena": "cambios", "gesto": "", "comando": ""},
		{"titulo": "Preparás los cambios", "frase": "Elegís qué entra en la foto.",
			"tipo": "hace", "escena": "add", "gesto": "Preparar el archivo", "comando": "git add"},
		{"titulo": "Guardás una foto", "frase": "Una foto de tu trabajo.",
			"tipo": "hace", "escena": "commit", "gesto": "📸 Sacar la foto", "comando": "git commit"},
		{"titulo": "La mandás a la nube", "frase": "A salvo en la nube.",
			"tipo": "hace", "escena": "push", "gesto": "☁ Mandar a la nube", "comando": "git push"},
		{"titulo": "Traés lo de la nube", "frase": "Traés lo nuevo de la nube.",
			"tipo": "hace", "escena": "pull", "gesto": "⬇ Traer de la nube", "comando": "git pull"},
		{"titulo": "Ese es el flujo", "frase": "¡Listo! Ya entendés git.",
			"tipo": "mira", "escena": "resumen", "gesto": "", "comando": ""},
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

	# Header arriba-izquierda (contexto) + ✕ cerrar arriba-derecha.
	var header := _label("Aprendé Git", _sans, 20, Tema.TENUE)
	header.position = Vector2(24, 20)
	add_child(header)

	var cerrar := _boton("✕", false)
	cerrar.set_anchor(SIDE_LEFT, 1.0)
	cerrar.set_anchor(SIDE_RIGHT, 1.0)
	cerrar.offset_left = -58
	cerrar.offset_right = -18
	cerrar.offset_top = 18
	cerrar.offset_bottom = 54
	cerrar.pressed.connect(cerrar_modulo)
	add_child(cerrar)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)

	# Robot + bocadillo (el robot "habla" en 1 frase).
	var robot_row := HBoxContainer.new()
	robot_row.add_theme_constant_override("separation", 6)
	robot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	robot_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_robot = Robot.new()
	_robot.custom_minimum_size = Vector2(92, 92)
	robot_row.add_child(_robot)
	_bocadillo = Bocadillo.new(_sans)
	_bocadillo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	robot_row.add_child(_bocadillo)
	v.add_child(robot_row)

	_titulo = _label("", _sans, 22, Tema.TEXTO, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_titulo)

	_lienzo = Lienzo.new()
	_lienzo.custom_minimum_size = Vector2(820, 330)
	_lienzo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lienzo.mono = _mono
	_lienzo.sans = _sans
	v.add_child(_lienzo)

	# Fila de acción: el botón del gesto (pasos "hace") + el rótulo del comando
	# ("se llama: git X", que aparece DESPUÉS del gesto). Altura fija para no saltar.
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

	# Botón a la Capa 2 (consola), visible en el último paso. Cableado intacto.
	_b_consola = _boton("Practicá en la consola ▶", true)
	_b_consola.custom_minimum_size = Vector2(260, 42)
	_b_consola.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_b_consola.pressed.connect(func():
		cerrar_modulo()
		abrir_consola.emit())
	v.add_child(_b_consola)


func abrir() -> void:
	_paso = 0
	_mostrar_paso()
	visible = true
	move_to_front()


func cerrar_modulo() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	visible = false


func _anterior() -> void:
	if _paso > 0:
		_paso -= 1
		_mostrar_paso()


func _siguiente() -> void:
	if _paso >= _pasos().size() - 1:
		cerrar_modulo()
		return
	_paso += 1
	_mostrar_paso()


func _mostrar_paso() -> void:
	var pasos := _pasos()
	var p: Dictionary = pasos[_paso]
	var es_accion: bool = p.tipo == "hace"
	var ultimo := _paso == pasos.size() - 1

	_titulo.text = p.titulo
	_bocadillo.set_texto(p.frase)
	_lienzo.escena = p.escena
	_cmd_label.text = str(p.comando)
	_cmd_pill.visible = false                       # el rótulo aparece tras el gesto

	# Botón del gesto: solo en pasos de acción.
	_b_accion.visible = es_accion
	_b_accion.text = str(p.gesto)
	_b_accion.disabled = false
	_b_accion.modulate.a = 1.0

	# Siguiente: en pasos de acción queda bloqueado hasta hacer el gesto.
	_b_next.text = "Terminar ✓" if ultimo else "Siguiente ▶"
	_b_next.disabled = es_accion
	_b_next.modulate.a = 0.4 if es_accion else 1.0
	_b_prev.disabled = _paso == 0
	_b_prev.modulate.a = 0.4 if _paso == 0 else 1.0
	_paso_label.text = "Paso %d de %d" % [_paso + 1, pasos.size()]
	_b_consola.visible = ultimo
	if _robot:
		_robot.set_mood("fiesta" if ultimo else "idle")

	# Estado visual: reseteamos la animación. Mira = corre sola; Hace = espera el gesto.
	_lienzo._t = 0.0
	if es_accion:
		if _tween and _tween.is_valid():
			_tween.kill()
		_lienzo.prog = 0.0
		_lienzo.queue_redraw()
	else:
		_animar_flujo(false)


# Dispara la animación del flujo (0→1). con_callback => era un gesto: al terminar,
# habilita Siguiente y revela el rótulo del comando.
func _animar_flujo(con_callback: bool) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_lienzo.prog = 0.0
	_tween = create_tween()
	_tween.tween_property(_lienzo, "prog", 1.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if con_callback:
		_tween.tween_callback(_accion_terminada)


func _on_accion() -> void:
	# El gesto del usuario dispara la animación (no corre sola).
	_b_accion.disabled = true
	_b_accion.modulate.a = 0.5
	if _robot:
		_robot.set_mood("pensando")
	_animar_flujo(true)


func _accion_terminada() -> void:
	var p: Dictionary = _pasos()[_paso]
	_b_next.disabled = false
	_b_next.modulate.a = 1.0
	_cmd_pill.visible = p.comando != ""             # "se llama: git X"
	if _robot:
		_robot.set_mood("feliz")


# ---------------------------------------------------------------------------
# Helpers de widgets
# ---------------------------------------------------------------------------
func _label(texto: String, fuente: Font, tam: int, color: Color, halign := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return UiKit.label(texto, fuente, tam, color, halign)


func _boton(txt: String, acento: bool) -> Button:
	return UiKit.boton(txt, acento, _sans)


# Pill del rótulo: "se llama"(sans) + "git X"(mono), en acento teal.
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
	hb.add_child(_label("se llama", _sans, 14, Tema.TENUE))
	_cmd_label = _label("", _mono, 17, Tema.PRIMARIO)
	hb.add_child(_cmd_label)
	pill.add_child(hb)
	return pill


# ---------------------------------------------------------------------------
# Bocadillo: burbuja de 1 frase pegada al robot (con colita que apunta a la izq).
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
		add_child(_label)

	func set_texto(t: String) -> void:
		_label.text = t
		queue_redraw()

	func _draw() -> void:
		var ty := size.y * 0.5
		# Colita hacia la izquierda (al robot).
		draw_colored_polygon(PackedVector2Array([Vector2(10, ty - 9), Vector2(10, ty + 9), Vector2(-1, ty)]), Tema.PANEL)
		# Cuerpo redondeado.
		var sb := StyleBoxFlat.new()
		sb.bg_color = Tema.PANEL
		sb.border_color = Tema.CALIDO
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(13)
		draw_style_box(sb, Rect2(8, 0, size.x - 8, size.y))


# ---------------------------------------------------------------------------
# Lienzo: dibuja y ANIMA la escena del paso. `prog` (0..1) maneja la transición.
# ---------------------------------------------------------------------------
class Lienzo extends Control:
	var escena := ""
	var prog := 0.0                  # 0..1 progreso de la animación del paso
	var _t := 0.0                    # tiempo para idles (pulsos, bob)
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
			"cambios": _draw_cambios()
			"add": _draw_add()
			"commit": _draw_commit()
			"push": _draw_push()
			"pull": _draw_pull()
			"resumen": _draw_resumen()

	func _pc_pos() -> Vector2: return Vector2(size.x * 0.24, size.y * 0.40)
	func _srv_pos() -> Vector2: return Vector2(size.x * 0.76, size.y * 0.40)

	# --- 1. Repo: git "empieza a vigilar" la carpeta (anillo teal que crece) ---
	func _draw_repo() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.46)
		var a := clampf(prog, 0.0, 1.0)
		var grow := 4.0 + 12.0 * a
		var r := Rect2(c.x - 70 - grow, c.y - 36 - grow, 140 + grow * 2.0, 96 + grow * 2.0)
		_solo_borde(r, 12.0, Color(Tema.PRIMARIO.r, Tema.PRIMARIO.g, Tema.PRIMARIO.b, 0.55 * a))
		_carpeta(c, "tu-proyecto/")
		if a > 0.25:
			_texto("git la está siguiendo", Vector2(c.x - 66, c.y + 88), 14, Color(Tema.PRIMARIO.r, Tema.PRIMARIO.g, Tema.PRIMARIO.b, a))

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
			var d := fmod(_t * 0.5, 1.0)
			_foto(p_ini.lerp(p_fin, d), 0.55, Tema.PRIMARIO)

	# --- 3. Cambios: un archivo pasa de limpio (verde) a modificado (ámbar) ---
	func _draw_cambios() -> void:
		var pc := Vector2(size.x * 0.5, size.y * 0.42)
		_pc(pc)
		var col := Tema.EXITO.lerp(Tema.CALIDO, clampf(prog, 0.0, 1.0))
		_foto(Vector2(pc.x, pc.y - 4), 1.4, col)
		var etiqueta := "guardado" if prog < 0.5 else "modificado ✎"
		_texto(etiqueta, Vector2(pc.x - 38, pc.y + 96), 14, col)

	# --- 4. Add: la cajita viaja del working dir a la zona de "preparado" ---
	func _draw_add() -> void:
		var orig := Vector2(size.x * 0.28, size.y * 0.45)
		var stage := Vector2(size.x * 0.68, size.y * 0.45)
		_texto("tu PC", Vector2(orig.x - 18, orig.y - 64), 13, Tema.TENUE)
		_zona(stage, "preparado (stage)")
		var t := clampf(prog, 0.0, 1.0)
		var col := Tema.CALIDO.lerp(Tema.PRIMARIO, t)
		_foto(orig.lerp(stage, t), 1.4, col)

	# --- 5. Commit: la cajita entra al historial local (con un "flash" de foto) ---
	func _draw_commit() -> void:
		var stage := Vector2(size.x * 0.32, size.y * 0.34)
		var hist := Vector2(size.x * 0.32, size.y * 0.74)
		_zona(stage, "preparado")
		_pila(hist, 1, "historial local")
		var t := clampf(prog, 0.0, 1.0)
		if t < 0.35:
			var fa := 1.0 - t / 0.35
			draw_circle(stage, 34.0, Color(1, 1, 1, 0.35 * fa))
		_foto(stage.lerp(hist, t), 1.3, Tema.PRIMARIO)

	# --- 6. Push: la cajita viaja por la línea, de la PC a la nube ---
	func _draw_push() -> void:
		var pc := _pc_pos()
		var srv := _srv_pos()
		var p_ini := Vector2(pc.x + 70, pc.y)
		var p_fin := Vector2(srv.x - 64, srv.y)
		draw_line(p_ini, p_fin, Tema.PRIMARIO, 3.0)
		_pc(pc)
		_servidor(srv)
		_pila(Vector2(pc.x, pc.y + 96), 1, "tu historial")
		var t := clampf(prog, 0.0, 1.0)
		_pila(Vector2(srv.x, srv.y + 96), 1 if t >= 0.96 else 0, "en la nube")
		if t < 0.96:
			_foto(p_ini.lerp(p_fin, t), 1.1, Tema.PRIMARIO)
		_texto("→ a la nube", Vector2((pc.x + srv.x) * 0.5 - 36, pc.y - 18), 13, Tema.PRIMARIO)

	# --- 7. Pull: alguien subió algo; la cajita viaja de la nube a la PC ---
	func _draw_pull() -> void:
		var pc := _pc_pos()
		var srv := _srv_pos()
		var p_ini := Vector2(pc.x + 70, pc.y)
		var p_fin := Vector2(srv.x - 64, srv.y)
		draw_line(p_ini, p_fin, Tema.PRIMARIO, 3.0)
		_pc(pc)
		_servidor(srv)
		var t := clampf(prog, 0.0, 1.0)
		_pila(Vector2(pc.x, pc.y + 96), 1 if t >= 0.96 else 0, "tu historial")
		_pila(Vector2(srv.x, srv.y + 96), 1, "en la nube")
		if t < 0.96:
			_foto(p_fin.lerp(p_ini, t), 1.1, Tema.CALIDO)
		_texto("← a tu PC", Vector2((pc.x + srv.x) * 0.5 - 34, pc.y - 18), 13, Tema.PRIMARIO)

	# --- 8. Resumen de comandos ---
	func _draw_resumen() -> void:
		var filas := [
			["git init", "empezás a seguir una carpeta con git"],
			["git status", "ves qué cambió y qué está preparado"],
			["git add", "preparás cambios para la próxima foto"],
			["git commit", "guardás una foto en tu historial local"],
			["git push", "mandás tus commits a la nube"],
			["git pull", "traés lo nuevo de la nube a tu PC"],
			["git clone", "bajás un repo entero la primera vez"],
		]
		var y0 := 26.0
		var x_cmd := size.x * 0.5 - 280.0
		var x_desc := size.x * 0.5 - 70.0
		for k in filas.size():
			var y := y0 + k * 42.0
			draw_string(mono, Vector2(x_cmd, y + 16), filas[k][0], HORIZONTAL_ALIGNMENT_LEFT, 200, 17, Tema.PRIMARIO)
			draw_string(sans, Vector2(x_desc, y + 16), filas[k][1], HORIZONTAL_ALIGNMENT_LEFT, 360, 15, Tema.TEXTO)

	# --- Primitivas de dibujo ---
	func _zona(c: Vector2, label: String) -> void:
		var r := Rect2(c.x - 48, c.y - 34, 96, 68)
		_rrect(r, 8.0, Tema.PRIMARIO_TENUE, Tema.PRIMARIO)
		_texto(label, Vector2(c.x - 44, c.y + 54), 12, Tema.PRIMARIO)

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

	func _foto(pos: Vector2, s: float, color: Color) -> void:
		var w := 26.0 * s
		var h := 22.0 * s
		var r := Rect2(pos.x - w * 0.5, pos.y - h * 0.5, w, h)
		_rrect(r, 3.0, Tema.PANEL, color)
		draw_rect(Rect2(r.position.x + 3, r.position.y + 3, w - 6, 6 * s), color)

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
