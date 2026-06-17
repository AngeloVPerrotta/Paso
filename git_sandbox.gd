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
	var fondo := ColorRect.new()
	fondo.color = Tema.FONDO
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)

	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "top", "right", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 26)
	add_child(margen)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	margen.add_child(v)

	# Título + robot + cerrar.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	var titulo := _lbl("Consola Git · sandbox", _sans, 26, Tema.TEXTO)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(titulo)
	_robot = Robot.new()
	_robot.custom_minimum_size = Vector2(64, 64)
	top.add_child(_robot)
	var cerrar := _boton("✕", false)
	cerrar.custom_minimum_size = Vector2(40, 36)
	cerrar.pressed.connect(cerrar_modulo)
	top.add_child(cerrar)
	v.add_child(top)

	# Barra de ejercicio.
	v.add_child(_construir_ejercicio())

	# Paneles: PC (local) | Nube (origin).
	var cuerpo := HBoxContainer.new()
	cuerpo.add_theme_constant_override("separation", 16)
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	_consola_out.custom_minimum_size = Vector2(0, 170)
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


func _construir_ejercicio() -> Control:
	var panel := _panel(Tema.PRIMARIO_TENUE, Tema.PRIMARIO)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	panel.add_child(h)
	_ej_estado = _lbl("○", _sans, 18, Tema.PRIMARIO)
	_ej_estado.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(_ej_estado)
	_ej_label = _lbl("", _sans, 15, Tema.TEXTO)
	_ej_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ej_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ej_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(_ej_label)
	_ej_btn = _boton("Siguiente ▶", true)
	_ej_btn.pressed.connect(_ejercicio_siguiente)
	h.add_child(_ej_btn)
	return panel


func _construir_pc() -> Control:
	var panel := _panel(Tema.PANEL, Tema.PANEL_BORDE)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	# Cada uno: {texto, hecho: Callable()->bool, [prepara_remoto]}. El robot acompaña.
	# Los pasos 6/7/8 miden progreso RELATIVO (baselines capturados al entrar), para
	# que la acción del paso se ejecute estando en el paso y no se saltee explorando.
	return [
		{"texto": "Iniciá el repositorio.  →  git init",
			"hecho": func(): return modelo.iniciado},
		{"texto": "Mirá en qué estado está todo.  →  git status",
			"hecho": func(): return _vio_status},
		{"texto": "Prepará los archivos para el primer commit.  →  git add .",
			"hecho": func(): return not modelo.con_estado(GitMini.PREPARADO).is_empty() or modelo.commits.size() >= 1},
		{"texto": "Hacé tu primer commit con un mensaje.  →  git commit -m \"...\"",
			"hecho": func(): return modelo.commits.size() >= 1},
		{"texto": "Mirá tu historial de commits.  →  git log",
			"hecho": func(): return _vio_log},
		{"texto": "Subilo a la nube.  →  git push",
			"hecho": func(): return modelo.remoto.size() >= 1},
		{"texto": "Hacé un cambio (tocá «✎ editar un archivo») y guardalo: git add + git commit.",
			"hecho": func(): return modelo.commits.size() > _base_commits},
		{"texto": "Subí ese commit nuevo.  →  git push",
			"hecho": func(): return modelo.remoto.size() > _base_remoto},
		{"texto": "Alguien subió algo a la nube. Traelo.  →  git pull",
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
	_ej_label.text = "Ejercicio %d/%d:  %s" % [_ejercicio + 1, ejs.size(), e.texto]
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
	if _robot:
		# El último paso (flujo completo) cierra con fiesta; los demás, feliz/pensando.
		if hecho and ultimo:
			_robot.set_mood("fiesta")
		else:
			_robot.set_mood("feliz" if hecho else "pensando")


func _ejercicio_siguiente() -> void:
	var ejs := _ejercicios()
	if _ejercicio >= ejs.size() - 1:
		cerrar_modulo()
		return
	_ejercicio += 1
	_mostrar_ejercicio()


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
