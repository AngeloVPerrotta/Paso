class_name GitExplica
extends Control

# "Aprendé Git" — Capa 1: explicador visual guiado (casi un video), navegable con
# Anterior/Siguiente, en la paleta del juego (Tema) + el robot de guía. Es
# presentación pura: NO toca intérprete/validador/niveles. Autocontenido: main.gd
# lo instancia (oculto) y llama abrir().
#
# La consola interactiva con carpetas es la Capa 2 (próximo hito).

signal abrir_consola                     # el botón del último paso pide abrir la Capa 2

var _mono: SystemFont
var _sans: SystemFont

var _paso := 0
var _b_consola: Button
var _lienzo: Lienzo
var _robot: Robot
var _titulo: Label
var _cmd_pill: PanelContainer
var _cmd_label: Label
var _caption: Label
var _b_prev: Button
var _b_next: Button
var _paso_label: Label


# Cada paso: {titulo, comando, caption, escena, fase}. escena/fase manejan el dibujo.
func _pasos() -> Array:
	return [
		{"titulo": "¿Qué es un repositorio?", "comando": "", "escena": "repo", "fase": "",
			"caption": "Un repositorio es tu proyecto seguido por git: una carpeta con TODO su historial. Cada vez que guardás, queda registrada una versión."},
		{"titulo": "Local y nube", "comando": "", "escena": "local_nube", "fase": "",
			"caption": "De un lado, tu PC (local). Del otro, un servidor en la nube: GitHub. Git mantiene los dos sincronizados."},
		{"titulo": "1 · Hacés cambios", "comando": "", "escena": "flujo", "fase": "cambios",
			"caption": "Editás archivos en tu PC. Son cambios locales: todavía no están guardados en el historial."},
		{"titulo": "2 · Preparás los cambios", "comando": "git add", "escena": "flujo", "fase": "add",
			"caption": "Con git add elegís qué cambios van a entrar en la próxima foto (los ponés en el «stage»)."},
		{"titulo": "3 · Guardás una foto local", "comando": "git commit", "escena": "flujo", "fase": "commit",
			"caption": "git commit guarda una foto del proyecto en tu historial LOCAL. Cada commit tiene fecha y un mensaje."},
		{"titulo": "4 · La mandás a la nube", "comando": "git push", "escena": "flujo", "fase": "push",
			"caption": "git push manda tus commits al servidor. Las fotos viajan de tu PC a la nube (GitHub)."},
		{"titulo": "5 · La traés de la nube", "comando": "git pull  /  git clone", "escena": "flujo", "fase": "pull",
			"caption": "git pull trae lo nuevo de la nube a tu PC. git clone baja el repo entero la primera vez."},
		{"titulo": "Comandos frecuentes", "comando": "", "escena": "resumen", "fase": "",
			"caption": "Estos son los que vas a usar casi siempre. (En la próxima capa los vas a poder tipear vos.)"},
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

	# ✕ cerrar, anclado arriba a la derecha.
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
	center.add_child(v)

	_robot = Robot.new()
	_robot.custom_minimum_size = Vector2(84, 84)
	_robot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(_robot)

	_titulo = _label("Aprendé Git", _sans, 30, Tema.TEXTO, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_titulo)

	# Pill del comando (mono, acento). Se muestra solo si el paso tiene comando.
	_cmd_pill = PanelContainer.new()
	_cmd_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var pill_sb := StyleBoxFlat.new()
	pill_sb.bg_color = Tema.PRIMARIO_TENUE
	pill_sb.border_color = Tema.PRIMARIO
	pill_sb.set_border_width_all(1)
	pill_sb.set_corner_radius_all(8)
	pill_sb.content_margin_left = 14; pill_sb.content_margin_right = 14
	pill_sb.content_margin_top = 6; pill_sb.content_margin_bottom = 6
	_cmd_pill.add_theme_stylebox_override("panel", pill_sb)
	_cmd_label = _label("", _mono, 18, Tema.PRIMARIO, HORIZONTAL_ALIGNMENT_CENTER)
	_cmd_pill.add_child(_cmd_label)
	v.add_child(_cmd_pill)

	_lienzo = Lienzo.new()
	_lienzo.custom_minimum_size = Vector2(800, 340)
	_lienzo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lienzo.mono = _mono
	_lienzo.sans = _sans
	v.add_child(_lienzo)

	_caption = _label("", _sans, 17, Tema.TEXTO, HORIZONTAL_ALIGNMENT_CENTER)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.custom_minimum_size = Vector2(740, 64)
	v.add_child(_caption)

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

	# Botón a la Capa 2 (consola interactiva), visible en el último paso.
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
	var p = pasos[_paso]
	_titulo.text = p.titulo
	_caption.text = p.caption
	_cmd_pill.visible = p.comando != ""
	_cmd_label.text = "$  " + str(p.comando)
	_lienzo.escena = p.escena
	_lienzo.fase = p.fase
	_lienzo._t = 0.0
	_lienzo.queue_redraw()
	_b_prev.disabled = _paso == 0
	_b_prev.modulate.a = 0.4 if _paso == 0 else 1.0
	_b_next.text = "Terminar ✓" if _paso == pasos.size() - 1 else "Siguiente ▶"
	if _b_consola:
		_b_consola.visible = _paso == pasos.size() - 1
	_paso_label.text = "Paso %d de %d" % [_paso + 1, pasos.size()]
	if _robot:
		_robot.set_mood("feliz" if _paso == pasos.size() - 1 else "idle")


# ---------------------------------------------------------------------------
# Helpers de widgets
# ---------------------------------------------------------------------------
func _label(texto: String, fuente: Font, tam: int, color: Color, halign := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return UiKit.label(texto, fuente, tam, color, halign)


func _boton(txt: String, acento: bool) -> Button:
	return UiKit.boton(txt, acento, _sans)


# ---------------------------------------------------------------------------
# Lienzo: dibuja (y anima) la escena del paso actual. Cosmético.
# ---------------------------------------------------------------------------
class Lienzo extends Control:
	var escena := ""
	var fase := ""
	var _t := 0.0
	var mono: Font
	var sans: Font

	func _process(delta: float) -> void:
		if is_visible_in_tree():
			_t += delta
			queue_redraw()

	func _draw() -> void:
		match escena:
			"repo":
				_draw_repo()
			"local_nube":
				_draw_local_nube(false)
			"flujo":
				_draw_flujo()
			"resumen":
				_draw_resumen()

	# --- Escena: repositorio (carpeta + historial) ---
	func _draw_repo() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.42)
		_carpeta(c, "tu-proyecto/")
		# Historial: línea de commits (fotos) creciendo hacia la derecha.
		var y := c.y + 96.0
		var x0 := size.x * 0.5 - 150.0
		_texto("historial (commits)", Vector2(size.x * 0.5 - 90, y - 22), 13, Tema.TENUE)
		var n := 5
		for k in n:
			var brillo := 1.0 if (k <= int(fmod(_t * 1.2, n + 1.0))) else 0.18
			var col := Tema.PRIMARIO if k < n - 1 else Tema.CALIDO
			_foto(Vector2(x0 + k * 70.0, y + 14), 1.0, Color(col.r, col.g, col.b, 0.25 + 0.75 * brillo))
			if k < n - 1:
				draw_line(Vector2(x0 + k * 70.0 + 16, y + 14), Vector2(x0 + (k + 1) * 70.0 - 16, y + 14), Tema.CELDA_BORDE, 2.0)

	# --- Escena ancla: PC (local) <-> servidor en la nube ---
	func _draw_local_nube(activo: bool, etiqueta_linea := "") -> void:
		var pc := Vector2(size.x * 0.24, size.y * 0.45)
		var srv := Vector2(size.x * 0.76, size.y * 0.45)
		# Conexión.
		var col_linea := Tema.PRIMARIO if activo else Tema.CELDA_BORDE
		draw_line(Vector2(pc.x + 70, pc.y), Vector2(srv.x - 64, srv.y), col_linea, 3.0)
		if etiqueta_linea != "":
			_texto(etiqueta_linea, Vector2((pc.x + srv.x) * 0.5 - 40, pc.y - 16), 13, Tema.PRIMARIO)
		_pc(pc)
		_servidor(srv)

	# --- Escena: el flujo (mismo ancla + animación del commit según la fase) ---
	func _draw_flujo() -> void:
		var pc := Vector2(size.x * 0.24, size.y * 0.45)
		var srv := Vector2(size.x * 0.76, size.y * 0.45)
		var activo := fase == "push" or fase == "pull"
		_draw_local_nube(activo)

		# Pilas de fotos (historial) bajo cada lado.
		var pc_pila := Vector2(pc.x, pc.y + 96)
		var srv_pila := Vector2(srv.x, srv.y + 96)
		var locales := 2
		var remotas := 1
		if fase == "commit":
			locales = 3
		if fase == "push":
			remotas = 2
		_pila(pc_pila, locales, "tu historial")
		_pila(srv_pila, remotas, "en la nube")

		var p_ini := Vector2(pc.x + 70, pc.y)
		var p_fin := Vector2(srv.x - 64, srv.y)
		match fase:
			"cambios":
				# Un archivo "latiendo" en la pantalla de la PC.
				var a := 0.5 + 0.5 * sin(_t * 4.0)
				_foto(Vector2(pc.x, pc.y - 4), 0.8, Color(Tema.CALIDO.r, Tema.CALIDO.g, Tema.CALIDO.b, 0.35 + 0.5 * a))
				_texto("cambios sin guardar", Vector2(pc.x - 60, pc.y + 150), 13, Tema.TENUE)
			"add":
				_foto(Vector2(pc.x, pc.y - 4), 0.85, Tema.CALIDO)
				_texto("preparado (stage)", Vector2(pc.x - 52, pc.y + 150), 13, Tema.CALIDO)
			"commit":
				# Una foto recién agregada a la pila local, con un pop.
				var pop := 1.0 + 0.25 * maxf(0.0, sin(_t * 5.0)) * exp(-_t * 1.5)
				_foto(pc_pila + Vector2((locales - 1) * 8, -(locales - 1) * 8), pop, Tema.PRIMARIO)
				_texto("foto guardada (local)", Vector2(pc.x - 58, pc.y + 150), 13, Tema.PRIMARIO)
			"push":
				var t01 := _ciclo()
				_foto(p_ini.lerp(p_fin, t01), 1.0, Tema.PRIMARIO)
				_texto("→ a la nube", Vector2((pc.x + srv.x) * 0.5 - 36, pc.y - 16), 13, Tema.PRIMARIO)
			"pull":
				var t01b := _ciclo()
				_foto(p_fin.lerp(p_ini, t01b), 1.0, Tema.PRIMARIO)
				_texto("← a tu PC", Vector2((pc.x + srv.x) * 0.5 - 34, pc.y - 16), 13, Tema.PRIMARIO)

	# --- Escena: resumen de comandos ---
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
		var y0 := 30.0
		var x_cmd := size.x * 0.5 - 280.0
		var x_desc := size.x * 0.5 - 70.0
		for k in filas.size():
			var y := y0 + k * 42.0
			draw_string(mono, Vector2(x_cmd, y + 16), filas[k][0], HORIZONTAL_ALIGNMENT_LEFT, 200, 17, Tema.PRIMARIO)
			draw_string(sans, Vector2(x_desc, y + 16), filas[k][1], HORIZONTAL_ALIGNMENT_LEFT, 360, 15, Tema.TEXTO)

	# --- Loop 0..1 con pausa al final (para fotos viajando) ---
	func _ciclo() -> float:
		var ciclo := 2.2
		var viaje := 1.4
		return clampf(fmod(_t, ciclo) / viaje, 0.0, 1.0)

	# --- Primitivas de dibujo ---
	func _pc(c: Vector2) -> void:
		var r := Rect2(c.x - 62, c.y - 42, 124, 84)
		_rrect(r, 8.0, Tema.PANEL, Tema.PRIMARIO)
		draw_rect(Rect2(r.position.x + 10, r.position.y + 12, r.size.x - 20, 7), Tema.CELDA)
		draw_rect(Rect2(r.position.x + 10, r.position.y + 26, (r.size.x - 20) * 0.6, 7), Tema.CELDA)
		draw_rect(Rect2(c.x - 9, c.y + 42, 18, 12), Tema.CELDA_BORDE)
		draw_rect(Rect2(c.x - 28, c.y + 54, 56, 6), Tema.CELDA_BORDE)
		_texto("Tu PC · local", Vector2(c.x - 44, c.y + 78), 14, Tema.TENUE)

	func _servidor(c: Vector2) -> void:
		# Nube tenue detrás (connota "nube" sin satélite); la caja es el servidor.
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
		# pestaña
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

	func _rrect(r: Rect2, radio: float, fill: Color, borde: Color) -> void:
		draw_rect(Rect2(r.position.x + radio, r.position.y, r.size.x - radio * 2.0, r.size.y), fill)
		draw_rect(Rect2(r.position.x, r.position.y + radio, r.size.x, r.size.y - radio * 2.0), fill)
		draw_circle(r.position + Vector2(radio, radio), radio, fill)
		draw_circle(r.position + Vector2(r.size.x - radio, radio), radio, fill)
		draw_circle(r.position + Vector2(radio, r.size.y - radio), radio, fill)
		draw_circle(r.position + Vector2(r.size.x - radio, r.size.y - radio), radio, fill)
		# Borde (4 líneas).
		var x0 := r.position.x; var y0 := r.position.y
		var x1 := r.position.x + r.size.x; var y1 := r.position.y + r.size.y
		draw_line(Vector2(x0 + radio, y0), Vector2(x1 - radio, y0), borde, 2.0)
		draw_line(Vector2(x0 + radio, y1), Vector2(x1 - radio, y1), borde, 2.0)
		draw_line(Vector2(x0, y0 + radio), Vector2(x0, y1 - radio), borde, 2.0)
		draw_line(Vector2(x1, y0 + radio), Vector2(x1, y1 - radio), borde, 2.0)
