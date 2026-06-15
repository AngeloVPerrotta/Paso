extends SceneTree

# Harness de screenshots (corre EN VENTANA, no headless). Guarda PNGs del feel:
#   - shot_inicio.png  : pantalla inicial (Paso + tagline + Jugar/Continuar + robot)
#   - shot_tutorial.png: spotlight del tutorial (nivel 1)
#   - shot_editor.png  : editor reskineado + escenario (invertir el trío)
#   - shot_run_N.png   : corrida a velocidad real (valores aterrizando en su casilla)
#   - shot_win.png      : banner de celebración sobre el escenario (no tapa el programa)
#   godot --path . --script shot.gd

var escena


func _initialize() -> void:
	escena = load("res://main.tscn").instantiate()
	get_root().add_child(escena)
	await process_frame
	await _esperar(8)

	await _shot_inicio()
	await _shot_tutorial()
	await _shot_corrida_y_win()

	print("listo: screenshots guardados")
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
	await _guardar("shot_tutorial.png")
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


func _esperar(frames: int) -> void:
	for i in frames:
		await process_frame


func _guardar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_png("res://%s" % nombre)
	print("  ", nombre, "  ", img.get_size())
