extends SceneTree

# Harness de screenshots (corre EN VENTANA, no headless): instancia la escena,
# construye programas con la API del editor y guarda PNGs del FEEL nuevo:
#   - shot_tutorial.png : spotlight del tutorial (nivel 1)
#   - shot_editor.png   : editor reskineado + escenario (invertir el trío)
#   - shot_run_N.png    : pasos de la corrida (valores volando, memoria, línea actual)
#   - shot_win.png       : celebración al pasar (onda + conteo + récord)
# Solo para inspección visual; no es parte del juego.
#   godot --path . --script shot.gd

var escena


func _initialize() -> void:
	escena = load("res://main.tscn").instantiate()
	get_root().add_child(escena)
	await process_frame
	await _esperar(6)

	await _shot_tutorial()
	await _shot_corrida_y_win()

	print("listo: screenshots guardados")
	quit()


# --- Tutorial (nivel 1): forzamos que se muestre limpiando el flag ---
func _shot_tutorial() -> void:
	Puntajes.set_flag("tuto_b1_eco", false)
	escena._cargar_indice(escena.orden.find("b1_eco"))
	await _esperar(12)             # el tutorial se arma con call_deferred + await
	await _guardar("shot_tutorial.png")
	escena._saltar_tutorial()
	await _esperar(2)


# --- Corrida con juice + celebración (invertir el trío: usa memoria) ---
func _shot_corrida_y_win() -> void:
	var id := "invertir_trio"
	escena._cargar_indice(escena.orden.find(id))
	await _esperar(4)

	# Construir la solución de referencia con la API del editor.
	for instr in Soluciones.para(id):
		escena.agregar_op(instr[0])
		if instr.size() > 1 and typeof(instr[1]) == TYPE_INT:
			escena.set_arg(escena.programa.size() - 1, instr[1])
	await _esperar(4)
	await _guardar("shot_editor.png")

	# Unos pasos, capturando a mitad de animación (valores volando, memoria).
	escena._reset_corrida()
	await _esperar(2)
	for n in 6:
		escena._on_step_pressed()
		await _esperar(2)          # atrapa el tween a mitad de camino
		await _guardar("shot_run_%d.png" % n)

	# Validar -> celebración (onda + conteo + ★/récord).
	escena._on_validar_pressed()
	await _esperar(3)
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
