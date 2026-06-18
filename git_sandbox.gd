class_name GitSandbox
extends Control

# "Aprendé Git" — Capa 2: sandbox interactivo. Se VEN las carpetas/archivos de
# "tu PC" (con estado por color) y el remoto en "la nube"; escribís comandos git
# REALES en una consola que el modelo (GitMini) parsea y ejecuta, y las cosas se
# mueven visualmente. Más una secuencia de ejercicios guiados con el robot.
#
# Es presentación: NO toca el juego (intérprete/validador/niveles). La lógica de
# git vive en GitMini (modelo puro, testeado en test_git.gd).

var _mono: SystemFont
var _sans: SystemFont
var modelo: GitMini

# Vista
var _pc_archivos: VBoxContainer
var _pc_staging: Label
var _pc_hist: Label
var _nube_hist: Label
var _nube_estado: Label
var _consola_out: RichTextLabel
var _consola_in: LineEdit
var _robot: Robot

# Ejercicios (Parte C)
var _ej_label: Label
var _ej_estado: Label
var _ej_btn: Button
var _ej_panel: PanelContainer            # panel del ejercicio (para la transición de auto-avance)
var _avanzando := false                  # transición de auto-avance en curso (evita doble disparo)
var _ej_pista_btn: Button
var _ej_pista_label: Label
var _pista_nivel := 0            # 0 = nada revelado, 1 = pista conceptual, 2 = comando
var _ejercicio := 0
# Progreso RELATIVO por ejercicio: cada paso se cuenta "hecho" por lo que pasa
# DESPUÉS de entrar al paso, no por contadores absolutos (si no, explorar libre
# adelanta y saltea la lección).
var _base_commits := 0
var _base_remoto := 0
var _ej_pull_base := -1          # commits al entrar al paso del pull (-1 = no estamos en él)
var _vio_status := false         # tipeó git status (paso guiado)
var _vio_log := false            # tipeó git log (paso guiado)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_mono = SystemFont.new()
	_mono.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "JetBrains Mono", "DejaVu Sans Mono", "monospace"])
	_sans = SystemFont.new()
	_sans.font_names = PackedStringArray(["Segoe UI", "Inter", "Helvetica Neue", "Arial", "sans-serif"])
	modelo = GitMini.new()
	_construir()


func abrir() -> void:
	modelo = GitMini.new()
	_ejercicio = 0
	_base_commits = 0
	_base_remoto = 0
	_ej_pull_base = -1
	_vio_status = false
	_vio_log = false
	_avanzando = false
	if _ej_panel:
		_ej_panel.modulate.a = 1.0           # por si quedó a medio fade de una transición previa
	_consola_out.clear()
	_log_info("Sandbox de git. Escribí comandos reales abajo. Empezá por: git init")
	_refrescar()
	_mostrar_ejercicio()
	visible = true
	move_to_front()
	_consola_in.grab_focus()


func cerrar_modulo() -> void:
	visible = false


# ---------------------------------------------------------------------------
# Construcción de la UI
# ---------------------------------------------------------------------------
func _construir() -> void:
	# ── Envoltorio "SO de Paso": escritorio (wallpaper) + ventana de app. Es SOLO
	# presentación; el sandbox (consola, paneles, ejercicios, pista) vive adentro igual. ──
	var escritorio := Escritorio.new()
	escritorio.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	escritorio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(escritorio)

	# Margen del escritorio: deja ver el wallpaper alrededor de la ventana.
	var marco := MarginContainer.new()
	marco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "top", "right", "bottom"]:
		marco.add_theme_constant_override("margin_" + lado, 34)
	add_child(marco)

	# Ventana de la app: esquinas redondeadas + sombra que la despega del escritorio.
	var ventana := PanelContainer.new()
	var win_sb := StyleBoxFlat.new()
	win_sb.bg_color = Tema.FONDO
	win_sb.set_corner_radius_all(16)
	win_sb.border_color = Tema.PRIMARIO
	win_sb.set_border_width_all(1)
	win_sb.shadow_color = Color(0.12, 0.11, 0.09, 0.32)
	win_sb.shadow_size = 22
	win_sb.shadow_offset = Vector2(0, 9)
	ventana.add_theme_stylebox_override("panel", win_sb)
	marco.add_child(ventana)

	var v_win := VBoxContainer.new()
	v_win.add_theme_constant_override("separation", 0)
	ventana.add_child(v_win)

	# Barra de título del SO de Paso (icono robot + nombre + 3 botoncitos).
	v_win.add_child(_construir_titlebar())

	# Cuerpo de la ventana (padding interno). Acá adentro va el sandbox tal cual.
	var cuerpo_margin := MarginContainer.new()
	cuerpo_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cuerpo_margin.add_theme_constant_override("margin_left", 18)
	cuerpo_margin.add_theme_constant_override("margin_right", 18)
	cuerpo_margin.add_theme_constant_override("margin_top", 14)
	cuerpo_margin.add_theme_constant_override("margin_bottom", 16)
	v_win.add_child(cuerpo_margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	cuerpo_margin.add_child(v)

	# Barra de ejercicio.
	v.add_child(_construir_ejercicio())

	# Paneles: PC (local) | Nube (origin). Tamaño según CONTENIDO (no se estiran):
	# así nunca se los aplasta contra el toolbar en pantallas bajas (aspect=expand).
	var cuerpo := HBoxContainer.new()
	cuerpo.add_theme_constant_override("separation", 16)
	cuerpo.add_child(_construir_pc())
	cuerpo.add_child(_construir_nube())
	v.add_child(cuerpo)

	# Toolbar para "tocar" archivos / simular la nube.
	var tb := HBoxContainer.new()
	tb.add_theme_constant_override("separation", 8)
	var b_edit := _boton("✎ editar un archivo", false)
	b_edit.pressed.connect(_editar_archivo)
	tb.add_child(b_edit)
	var b_new := _boton("+ archivo nuevo", false)
	b_new.pressed.connect(_nuevo_archivo)
	tb.add_child(b_new)
	var b_sim := _boton("☁ simular cambio en la nube", false)
	b_sim.pressed.connect(_simular_remoto)
	tb.add_child(b_sim)
	v.add_child(tb)

	# Consola: salida + entrada.
	_consola_out = RichTextLabel.new()
	_consola_out.bbcode_enabled = true
	_consola_out.scroll_following = true
	_consola_out.focus_mode = Control.FOCUS_NONE
	# La consola absorbe el espacio vertical sobrante (y se achica en pantallas bajas),
	# en vez de que lo haga el panel de archivos: evita que el panel pise el toolbar.
	_consola_out.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_consola_out.custom_minimum_size = Vector2(0, 130)
	_consola_out.add_theme_font_override("normal_font", _mono)
	_consola_out.add_theme_font_size_override("normal_font_size", 14)
	var out_sb := StyleBoxFlat.new()
	out_sb.bg_color = Tema.TEXTO
	out_sb.set_corner_radius_all(10)
	out_sb.set_content_margin_all(12)
	_consola_out.add_theme_stylebox_override("normal", out_sb)
	v.add_child(_consola_out)

	var fila_in := HBoxContainer.new()
	fila_in.add_theme_constant_override("separation", 8)
	var prompt := _lbl("$", _mono, 18, Tema.PRIMARIO)
	prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fila_in.add_child(prompt)
	_consola_in = LineEdit.new()
	_consola_in.placeholder_text = "git status"
	_consola_in.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_consola_in.add_theme_font_override("font", _mono)
	_consola_in.add_theme_font_size_override("font_size", 16)
	_consola_in.text_submitted.connect(_on_enter)
	fila_in.add_child(_consola_in)
	var b_run := _boton("Enter ⏎", true)
	b_run.pressed.connect(func(): _on_enter(_consola_in.text))
	fila_in.add_child(b_run)
	v.add_child(fila_in)


# Barra de título del "SO de Paso": robot de marca como icono (reacciona al progreso),
# nombre de la ventana y los tres botoncitos clásicos. Cerrar es funcional (reusa
# cerrar_modulo); minimizar/maximizar son decorativos. Paleta del juego, no imita ningún OS.
func _construir_titlebar() -> Control:
	var bar := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Tema.PRIMARIO
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	bar.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	bar.add_child(h)

	_robot = Robot.new()
	_robot.custom_minimum_size = Vector2(40, 40)
	_robot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_robot)

	var titulo := _lbl("Consola Git — tu-proyecto", _sans, 18, Tema.PANEL)   # claro sobre el teal
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(titulo)

	# Tres botoncitos: minimizar (ámbar) · maximizar (verde) decorativos, cerrar (rojo) funcional.
	h.add_child(_os_dot(Tema.CALIDO))
	h.add_child(_os_dot(Tema.EXITO))
	h.add_child(_os_boton_cerrar())
	return bar


# Puntito decorativo de la barra de título (un círculo de color, sin acción).
func _os_dot(color: Color) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(15, 15)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(8)
	p.add_theme_stylebox_override("panel", sb)
	return p


# Botoncito de cerrar (el único funcional): reusa el cierre del sandbox que ya existe.
func _os_boton_cerrar() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(15, 15)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "Cerrar"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Tema.ERROR
	sb.set_corner_radius_all(8)
	var hover := sb.duplicate()
	hover.bg_color = Tema.ERROR.lerp(Color.WHITE, 0.28)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", sb)
	b.pressed.connect(cerrar_modulo)
	return b


func _construir_ejercicio() -> Control:
	var panel := _panel(Tema.PRIMARIO_TENUE, Tema.PRIMARIO)
	_ej_panel = panel
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	col.add_child(h)
	_ej_estado = _lbl("○", _sans, 18, Tema.PRIMARIO)
	_ej_estado.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(_ej_estado)
	_ej_label = _lbl("", _sans, 15, Tema.TEXTO)
	_ej_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ej_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ej_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(_ej_label)
	_ej_pista_btn = _boton("💡 ¿Cómo?", false)
	_ej_pista_btn.pressed.connect(_revelar_pista)
	h.add_child(_ej_pista_btn)
	_ej_btn = _boton("Siguiente ▶", true)
	_ej_btn.pressed.connect(_ejercicio_siguiente)
	h.add_child(_ej_btn)

	# Fila de ayuda graduada (oculta hasta que la piden con 💡): pista → comando.
	_ej_pista_label = _lbl("", _sans, 14, Tema.TEXTO)
	_ej_pista_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ej_pista_label.visible = false
	col.add_child(_ej_pista_label)
	return panel


# Revela la ayuda en dos niveles: 1ª vez la PISTA conceptual, 2ª vez el COMANDO.
func _revelar_pista() -> void:
	var e: Dictionary = _ejercicios()[_ejercicio]
	if not e.has("comando"):
		return
	_pista_nivel += 1
	if _pista_nivel == 1:
		_ej_pista_label.add_theme_font_override("font", _sans)
		_ej_pista_label.add_theme_color_override("font_color", Tema.TEXTO)
		_ej_pista_label.text = "💡 " + str(e.get("pista", ""))
		_ej_pista_btn.text = "Ver el comando"
	else:
		_ej_pista_label.add_theme_font_override("font", _mono)
		_ej_pista_label.add_theme_color_override("font_color", Tema.PRIMARIO)
		_ej_pista_label.text = "$ " + str(e.comando)
		_ej_pista_btn.disabled = true
		_ej_pista_btn.modulate.a = 0.4
	_ej_pista_label.visible = true


func _construir_pc() -> Control:
	var panel := _panel(Tema.PANEL, Tema.PANEL_BORDE)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.clip_contents = true   # nunca derrama contenido fuera del panel (anti-overlap)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(_lbl("TU PC · LOCAL", _sans, 13, Tema.TENUE))
	v.add_child(_lbl("📁 tu-proyecto/", _mono, 16, Tema.TEXTO))
	_pc_archivos = VBoxContainer.new()
	_pc_archivos.add_theme_constant_override("separation", 4)
	v.add_child(_pc_archivos)
	v.add_child(_sep())
	_pc_staging = _lbl("", _sans, 13, Tema.TEXTO)
	_pc_staging.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_pc_staging)
	_pc_hist = _lbl("", _sans, 13, Tema.TEXTO)
	_pc_hist.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_pc_hist)
	return panel


func _construir_nube() -> Control:
	var panel := _panel(Tema.PANEL, Tema.PANEL_BORDE)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.clip_contents = true
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(_lbl("NUBE · origin (GitHub)", _sans, 13, Tema.TENUE))
	v.add_child(_lbl("☁ servidor remoto", _mono, 16, Tema.TEXTO))
	_nube_hist = _lbl("", _sans, 13, Tema.TEXTO)
	_nube_hist.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_nube_hist)
	v.add_child(_sep())
	_nube_estado = _lbl("", _sans, 13, Tema.TENUE)
	_nube_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_nube_estado)
	return panel


# ---------------------------------------------------------------------------
# Consola
# ---------------------------------------------------------------------------
func _on_enter(texto: String) -> void:
	var t := texto.strip_edges()
	_consola_in.clear()
	if t == "":
		return
	var r: Dictionary = modelo.ejecutar(t)
	# Acreditamos los pasos guiados por el subcomando REALMENTE ejecutado sin error,
	# no por el texto crudo: «git   status» (espacios extra) cuenta, «git statusfoo» (error) no.
	var toks := t.split(" ", false)
	var sub: String = toks[1] if toks.size() >= 2 else ""
	if not r.error and sub == "status":
		_vio_status = true
	if not r.error and sub == "log":
		_vio_log = true
	_log_cmd(t)
	if r.salida != "":
		_log_salida(r.salida, r.error)
	_refrescar()
	_chequear_ejercicio()
	_consola_in.grab_focus()


func _log_cmd(t: String) -> void:
	# Eco del comando en un teal claro (buen contraste sobre el fondo oscuro).
	_consola_out.append_text("[color=#%s]$ %s[/color]\n" % [Tema.PRIMARIO_CLARO.to_html(false), t])


func _log_salida(s: String, error: bool) -> void:
	# ERROR_CLARO (no ERROR pleno) para que el feedback de error se lea bien sobre el fondo oscuro.
	var col := Tema.ERROR_CLARO if error else Tema.FONDO
	_consola_out.append_text("[color=#%s]%s[/color]\n" % [col.to_html(false), s])


func _log_info(s: String) -> void:
	_consola_out.append_text("[color=#%s]%s[/color]\n" % [Tema.CALIDO.to_html(false), s])


# ---------------------------------------------------------------------------
# Toolbar (tocar archivos / simular la nube)
# ---------------------------------------------------------------------------
func _editar_archivo() -> void:
	# Editamos el primer archivo "limpio" (seguido); si no hay, README.md.
	var objetivo := "README.md"
	for n in modelo.con_estado(GitMini.LIMPIO):
		objetivo = n
		break
	modelo.editar_archivo(objetivo)
	_log_info("(editaste «%s» — ahora está modificado)" % objetivo)
	_refrescar()
	_chequear_ejercicio()


func _nuevo_archivo() -> void:
	var n := 1
	while modelo.archivos.has("nota%d.txt" % n):
		n += 1
	var nombre := "nota%d.txt" % n
	modelo.crear_archivo(nombre)
	_log_info("(creaste «%s» — está sin seguir)" % nombre)
	_refrescar()
	_chequear_ejercicio()


func _simular_remoto() -> void:
	modelo.simular_remoto("mejora de un compañero")
	_log_info("(alguien subió un commit a la nube — probá: git pull)")
	_refrescar()
	_chequear_ejercicio()


# ---------------------------------------------------------------------------
# Refrescar la vista desde el modelo
# ---------------------------------------------------------------------------
func _refrescar() -> void:
	for hijo in _pc_archivos.get_children():
		hijo.queue_free()
	var nombres := modelo.archivos.keys()
	nombres.sort()
	for nombre in nombres:
		_pc_archivos.add_child(_fila_archivo(nombre, modelo.archivos[nombre]))

	var prep := modelo.con_estado(GitMini.PREPARADO)
	_pc_staging.text = "preparado (staging):  %s" % ("—" if prep.is_empty() else ", ".join(prep))
	_pc_hist.text = "historial local:  %s" % _resumen_commits(modelo.commits)

	_nube_hist.text = "historial remoto:  %s" % _resumen_commits(modelo.remoto)
	var notas := []
	if modelo.adelantados() > 0:
		notas.append("↑ tenés %d sin subir (push)" % modelo.adelantados())
	if modelo.atrasados() > 0:
		notas.append("↓ hay %d sin traer (pull)" % modelo.atrasados())
	_nube_estado.text = "  ·  ".join(notas) if not notas.is_empty() else "sincronizado con tu PC"


func _resumen_commits(arr: Array) -> String:
	if arr.is_empty():
		return "sin commits"
	var ultimo: Dictionary = arr[arr.size() - 1]
	return "%d commit(s) · último: «%s»" % [arr.size(), ultimo.msg]


func _fila_archivo(nombre: String, estado: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var col := Tema.TENUE
	var etiqueta := "sin seguir"
	match estado:
		GitMini.MODIFICADO:
			col = Tema.CALIDO; etiqueta = "modificado"
		GitMini.PREPARADO:
			col = Tema.PRIMARIO; etiqueta = "preparado ✓"
		GitMini.LIMPIO:
			col = Tema.EXITO; etiqueta = "guardado"
	var punto := _lbl("●", _sans, 14, col)
	h.add_child(punto)
	var nom := _lbl(nombre, _mono, 14, Tema.TEXTO)
	nom.custom_minimum_size = Vector2(150, 0)
	h.add_child(nom)
	h.add_child(_lbl(etiqueta, _sans, 12, col))
	return h


# ---------------------------------------------------------------------------
# Ejercicios guiados (Parte C)
# ---------------------------------------------------------------------------
func _ejercicios() -> Array:
	# Cada uno: {texto (OBJETIVO), pista (conceptual), comando (último recurso),
	# hecho: Callable()->bool, [prepara_remoto]}. El comando NO se muestra de entrada:
	# se revela con el botón 💡 en dos niveles (pista → comando) para hacer pensar.
	# Los pasos 6/7/8 miden progreso RELATIVO (baselines al entrar al paso).
	return [
		{"texto": "Iniciá el repositorio.",
			"pista": "Necesitás decirle a git que empiece a seguir esta carpeta.",
			"comando": "git init",
			"hecho": func(): return modelo.iniciado},
		{"texto": "Mirá en qué estado está todo.",
			"pista": "Hay un comando para ver qué cambió y qué falta preparar.",
			"comando": "git status",
			"hecho": func(): return _vio_status},
		{"texto": "Prepará los archivos para el primer commit.",
			"pista": "Tenés que poner los cambios en el «stage». El punto «.» significa «todo».",
			"comando": "git add .",
			"hecho": func(): return not modelo.con_estado(GitMini.PREPARADO).is_empty() or modelo.commits.size() >= 1},
		{"texto": "Guardá tu primer commit, con un mensaje.",
			"pista": "Un commit es un punto guardado de tu proyecto. El mensaje va entre comillas, con -m.",
			"comando": "git commit -m \"primer commit\"",
			"hecho": func(): return modelo.commits.size() >= 1},
		{"texto": "Mirá tu historial de commits.",
			"pista": "Hay un comando que lista los commits que ya guardaste.",
			"comando": "git log",
			"hecho": func(): return _vio_log},
		{"texto": "Subí tu trabajo a la nube.",
			"pista": "Necesitás mandar tus commits al servidor remoto.",
			"comando": "git push",
			"hecho": func(): return modelo.remoto.size() >= 1},
		{"texto": "Hacé un cambio en un archivo y guardalo.",
			"pista": "Tocá «✎ editar un archivo», después preparalo y commiteá (los dos pasos).",
			"comando": "git add .   ·   git commit -m \"...\"",
			"hecho": func(): return modelo.commits.size() > _base_commits},
		{"texto": "Subí ese commit nuevo.",
			"pista": "Igual que antes: mandá los commits nuevos al remoto.",
			"comando": "git push",
			"hecho": func(): return modelo.remoto.size() > _base_remoto},
		{"texto": "Alguien subió algo a la nube. Traelo a tu PC.",
			"pista": "Necesitás traer a tu PC los commits que están en el remoto.",
			"comando": "git pull",
			"prepara_remoto": true,
			"hecho": func(): return _ej_pull_base >= 0 and modelo.commits.size() > _ej_pull_base},
		{"texto": "¡Listo! Ese es el flujo completo de git. Seguí practicando lo que quieras.",
			"hecho": func(): return true},
	]


func _mostrar_ejercicio() -> void:
	var ejs := _ejercicios()
	if _ejercicio >= ejs.size():
		_ejercicio = ejs.size() - 1
	var e: Dictionary = ejs[_ejercicio]
	_avanzando = false                       # nuevo paso: listo para volver a auto-avanzar al completarlo
	_ej_label.text = "Ejercicio %d/%d:  %s" % [_ejercicio + 1, ejs.size(), e.texto]
	# Reset de la ayuda graduada al entrar a un paso nuevo (el último no tiene comando).
	_pista_nivel = 0
	_ej_pista_label.visible = false
	_ej_pista_label.text = ""
	_ej_pista_btn.visible = e.has("comando")
	_ej_pista_btn.disabled = false
	_ej_pista_btn.modulate.a = 1.0
	_ej_pista_btn.text = "💡 ¿Cómo?"
	# Baseline al entrar al paso: los pasos 6/7 se cuentan por lo que pase desde acá.
	_base_commits = modelo.commits.size()
	_base_remoto = modelo.remoto.size()
	_ej_pull_base = -1
	# Paso del pull (marcado con prepara_remoto en los datos, no por índice): garantizamos
	# que SIEMPRE haya algo para traer y medimos el pull recién desde que se entra al paso,
	# sin depender de si el usuario ya tocó el botón «simular cambio en la nube».
	if e.get("prepara_remoto", false):
		if modelo.atrasados() == 0:
			_simular_remoto()
		_ej_pull_base = modelo.commits.size()
	_chequear_ejercicio()


func _chequear_ejercicio() -> void:
	var ejs := _ejercicios()
	var e: Dictionary = ejs[_ejercicio]
	var hecho: bool = e.hecho.call()
	_ej_estado.text = "✓" if hecho else "○"
	_ej_estado.add_theme_color_override("font_color", Tema.EXITO if hecho else Tema.PRIMARIO)
	var ultimo := _ejercicio >= ejs.size() - 1
	_ej_btn.text = "Cerrar" if ultimo else "Siguiente ▶"
	_ej_btn.disabled = not hecho and not ultimo
	_ej_btn.modulate.a = 1.0 if (hecho or ultimo) else 0.4
	# Avance dinámico (no headless): al completar un paso no-último, pasa SOLO al siguiente.
	# El botón queda solo para el «Cerrar» final. En headless el botón es el camino (test_git_ui).
	if not _headless():
		_ej_btn.visible = ultimo
	if _robot:
		# El último paso (flujo completo) cierra con fiesta; los demás, feliz/pensando.
		if hecho and ultimo:
			_robot.set_mood("fiesta")
		else:
			_robot.set_mood("feliz" if hecho else "pensando")
	if hecho and not ultimo and not _avanzando and not _headless():
		_avanzar_auto()


func _ejercicio_siguiente() -> void:
	var ejs := _ejercicios()
	if _ejercicio >= ejs.size() - 1:
		cerrar_modulo()
		return
	_ejercicio += 1
	_mostrar_ejercicio()


func _headless() -> bool:
	return DisplayServer.get_name() == "headless"


# Avance dinámico: deja ver el ✓ un instante, hace un fade y pasa solo al próximo ejercicio.
func _avanzar_auto() -> void:
	_avanzando = true
	var t := create_tween()
	t.tween_interval(0.85)                   # deja leer el ✓ del paso completado
	t.tween_callback(_fade_y_avanzar)


func _fade_y_avanzar() -> void:
	if not _avanzando:
		return
	if _ej_panel == null:
		_ejercicio_siguiente()
		return
	var t := create_tween()
	t.tween_property(_ej_panel, "modulate:a", 0.0, 0.18)
	t.tween_callback(_ejercicio_siguiente)   # cambia el texto al próximo (resetea _avanzando)
	t.tween_property(_ej_panel, "modulate:a", 1.0, 0.22)


# ---------------------------------------------------------------------------
# Helpers de widgets
# ---------------------------------------------------------------------------
func _lbl(texto: String, fuente: Font, tam: int, color: Color) -> Label:
	return UiKit.label(texto, fuente, tam, color)


func _panel(fondo: Color, borde: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = fondo
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(14)
	sb.border_color = borde
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _sep() -> HSeparator:
	var s := HSeparator.new()
	var sb := StyleBoxLine.new()
	sb.color = Tema.PANEL_BORDE
	s.add_theme_stylebox_override("separator", sb)
	return s


func _boton(txt: String, acento: bool) -> Button:
	return UiKit.boton(txt, acento, _sans)


# ---------------------------------------------------------------------------
# Escritorio: wallpaper del "SO de Paso" dibujado por código (sin assets). Gradiente
# suave teal↔arena + dos halos tenues + una rejilla de puntitos discreta. Solo visual
# (mouse IGNORE); se redibuja al cambiar de tamaño, no cada frame.
# ---------------------------------------------------------------------------
class Escritorio extends Control:
	func _ready() -> void:
		queue_redraw()

	func _notification(que: int) -> void:
		if que == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w < 2.0 or h < 2.0:
			return
		# Gradiente diagonal (arena con un dejo teal arriba → arena abajo) vía polígono
		# de 4 colores: da una base de wallpaper sin ser un color plano.
		var c_tl := Tema.PRIMARIO.lerp(Tema.FONDO, 0.68)
		var c_tr := Tema.PRIMARIO.lerp(Tema.FONDO, 0.80)
		var c_br := Tema.FONDO
		var c_bl := Tema.CALIDO.lerp(Tema.FONDO, 0.84)
		draw_polygon(
			PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([c_tl, c_tr, c_br, c_bl]))
		# Halos grandes muy tenues (profundidad).
		var d := maxf(w, h)
		draw_circle(Vector2(w * 0.16, h * 0.20), d * 0.30, Color(Tema.PRIMARIO.r, Tema.PRIMARIO.g, Tema.PRIMARIO.b, 0.07))
		draw_circle(Vector2(w * 0.88, h * 0.82), d * 0.24, Color(Tema.CALIDO.r, Tema.CALIDO.g, Tema.CALIDO.b, 0.07))
		# Rejilla de puntitos discreta (textura sutil de escritorio).
		var paso := 46.0
		var col_pt := Color(Tema.PRIMARIO.r, Tema.PRIMARIO.g, Tema.PRIMARIO.b, 0.085)
		var y := paso * 0.5
		while y < h:
			var x := paso * 0.5
			while x < w:
				draw_circle(Vector2(x, y), 1.6, col_pt)
				x += paso
			y += paso
