extends SceneTree

# Harness de screenshots (corre EN VENTANA, no headless). Guarda TODOS los PNG en
# shots/ (sobrescribe siempre los mismos en cada corrida):
#   - shot_inicio.png  : pantalla inicial (Paso + tagline + Jugar/Continuar + robot)
#   - shot_tutorial.png / shot_tutorial_agarra.png : tutorial (intro + paso interactivo)
#   - shot_editor.png  : editor reskineado + escenario
#   - shot_run_N.png   : corrida (valores aterrizando en su casilla)
#   - shot_win.png     : banner de celebración (no tapa el programa)
#   - shot_csharp.png  : panel "Ver en C#" abierto
#   godot --path . --script shot.gd

const DIR := "res://shots"
var escena


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	# Evitar que el auto-abrir de "Cómo funciona" tape la captura del inicio.
	Puntajes.set_flag("vio_maquina", true)
	escena = load("res://main.tscn").instantiate()
	get_root().add_child(escena)
	await process_frame
	await _esperar(8)

	await _shot_inicio()
	await _shot_git()
	await _shot_sandbox()
	await _shot_ux()
	await _shot_como()
	await _shot_tutorial()
	await _shot_corrida_y_win()
	await _shot_codigo("c", "invertir_trio", "shot_c.png")
	await _shot_codigo("csharp", "invertir_cuarteto", "shot_csharp.png")

	print("listo: screenshots guardados en shots/")
	quit()


# Módulo "Aprendé Git": ancla (local vs nube), flujo (push: foto viajando) y resumen.
func _shot_git() -> void:
	escena.inicio_capa.visible = false
	escena.git_capa.abrir()
	await _esperar(4)
	escena.git_capa._siguiente()              # paso 1: local vs nube (ancla)
	await _esperar(18)
	await _guardar("shot_git_nube.png")
	for n in 4:
		escena.git_capa._siguiente()          # hasta paso 5: git push
	await _esperar(22)                         # la foto viajando a mitad de camino
	await _guardar("shot_git_push.png")
	escena.git_capa._siguiente()
	escena.git_capa._siguiente()              # paso 7: resumen de comandos
	await _esperar(8)
	await _guardar("shot_git_resumen.png")
	escena.git_capa.cerrar_modulo()
	await _esperar(2)


# Sandbox de git (Capa 2): corre comandos reales y captura el estado visual.
func _shot_sandbox() -> void:
	escena.inicio_capa.visible = false
	escena.git_sandbox.abrir()
	await _esperar(4)
	escena.git_sandbox._on_enter("git init")
	escena.git_sandbox._on_enter("git add .")
	escena.git_sandbox._on_enter("git commit -m \"primer commit\"")
	await _esperar(6)
	await _guardar("shot_git_consola.png")
	escena.git_sandbox._on_enter("git push")
	escena.git_sandbox._simular_remoto()
	escena.git_sandbox._on_enter("git pull")
	await _esperar(6)
	await _guardar("shot_git_sync.png")
	escena.git_sandbox.cerrar_modulo()
	await _esperar(2)


# Modales de UX estándar (sobre el inicio): "Acerca de" y "Reiniciar progreso".
func _shot_ux() -> void:
	escena._acerca_de()
	await _esperar(8)
	await _guardar("shot_acerca.png")
	_cerrar_modal_top()
	await _esperar(2)
	escena._reiniciar_progreso()
	await _esperar(8)
	await _guardar("shot_reiniciar.png")
	_cerrar_modal_top()              # cancelamos (no reseteamos de verdad)
	await _esperar(2)


func _cerrar_modal_top() -> void:
	var n = escena.get_child_count()
	if n > 0 and escena.get_child(n - 1) is Control:
		escena.get_child(n - 1).queue_free()


# Pantalla "Cómo funciona la máquina" en el paso "guardá" (valor en memoria).
func _shot_como() -> void:
	escena._abrir_como_funciona()
	escena._demo_timer.stop()      # control manual para una captura estable
	escena._demo_tick()            # agarrá
	escena._demo_tick()            # guardá (queda el valor en memoria)
	await _esperar(10)
	await _guardar("shot_como.png")
	escena._cerrar_como_funciona()
	await _esperar(2)


func _shot_inicio() -> void:
	# Forzamos un "ultimo nivel" para que se vea el boton Continuar.
	Puntajes.set_ultimo("invertir_trio")
	escena._mostrar_inicio()
	await _esperar(8)
	await _guardar("shot_inicio.png")


func _shot_tutorial() -> void:
	Puntajes.set_flag("tuto_b1_eco", false)
	escena.inicio_capa.visible = false
	escena._cargar_indice(escena.orden.find("b1_eco"))
	await _esperar(14)
	await _guardar("shot_tutorial.png")            # paso intro
	# Avanzar hasta el paso interactivo "tocá agarrá" (hueco sobre la paleta).
	escena._tutorial_siguiente()
	await _esperar(6)
	escena._tutorial_siguiente()
	await _esperar(12)
	await _guardar("shot_tutorial_agarra.png")     # spotlight con hueco interactivo
	escena._saltar_tutorial()
	await _esperar(2)


func _shot_corrida_y_win() -> void:
	var id := "invertir_trio"
	escena.inicio_capa.visible = false
	escena._cargar_indice(escena.orden.find(id))
	await _esperar(4)

	for instr in Soluciones.para(id):
		escena.agregar_op(instr[0])
		if instr.size() > 1 and typeof(instr[1]) == TYPE_INT:
			escena.set_arg(escena.programa.size() - 1, instr[1])
	await _esperar(4)
	await _guardar("shot_editor.png")

	# Velocidad "lento" para leer las animaciones; capturamos a mitad de cada vuelo.
	escena.vel_idx = 0
	escena._reset_corrida()
	await _esperar(2)
	for n in 6:
		escena._on_step_pressed()
		await _esperar(14)         # ~0.23s: el valor está llegando a su casilla
		await _guardar("shot_run_%d.png" % n)

	escena._on_validar_pressed()
	await _esperar(16)             # banner escalado + conteo casi terminado
	await _guardar("shot_win.png")
	await _esperar(2)


# Panel "Ver en C#" sobre el nivel más interesante (pares_iguales: while + if).
# Cargamos el programa de referencia DIRECTO (agregar_op autonombra etiquetas
# L1/L2 y no fija destinos de salto por nombre; acá queremos el programa exacto).
# Panel de código en un track + nivel dado. Carga el programa de referencia directo.
func _shot_codigo(tr: String, id: String, archivo: String) -> void:
	escena._cerrar_csharp()
	escena.track = tr
	escena.orden = Niveles.orden_track(tr)
	escena._refrescar_track_ui()
	escena.inicio_capa.visible = false
	var idx = escena.orden.find(id)
	escena._cargar_indice(idx if idx >= 0 else 0)
	await _esperar(4)
	escena.programa = Soluciones.para(id).duplicate(true)
	escena._repintar_programa()
	escena._reset_corrida()
	await _esperar(4)
	escena._toggle_csharp()
	await _esperar(8)
	await _guardar(archivo)
	escena._cerrar_csharp()
	await _esperar(2)


func _esperar(frames: int) -> void:
	for i in frames:
		await process_frame


func _guardar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_png("%s/%s" % [DIR, nombre])
	print("  ", nombre, "  ", img.get_size())
