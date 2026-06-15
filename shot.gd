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
	escena = load("res://main.tscn").instantiate()
	get_root().add_child(escena)
	await process_frame
	await _esperar(8)

	await _shot_inicio()
	await _shot_tutorial()
	await _shot_corrida_y_win()
	await _shot_csharp()

	print("listo: screenshots guardados en shots/")
	quit()


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
func _shot_csharp() -> void:
	escena._cerrar_csharp()
	escena.inicio_capa.visible = false
	var id := "pares_iguales"
	escena._cargar_indice(escena.orden.find(id))
	await _esperar(4)
	escena.programa = Soluciones.para(id).duplicate(true)
	escena._repintar_programa()
	escena._reset_corrida()
	await _esperar(4)
	escena._toggle_csharp()
	await _esperar(8)
	await _guardar("shot_csharp.png")
	await _esperar(2)


func _esperar(frames: int) -> void:
	for i in frames:
		await process_frame


func _guardar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_png("%s/%s" % [DIR, nombre])
	print("  ", nombre, "  ", img.get_size())
