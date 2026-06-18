extends SceneTree

# Regresión del crash "Nonexistent 'int' constructor" en _mensaje_falla: validar una
# solución INCORRECTA reventaba con int(null) sobre la salida. Un programa de solo
# « soltá » suelta con la mano vacía -> mete null en la salida (interpreter.gd: SOLTAR
# hace salida.append(mano)), y ese null disparaba int(null). Este camino ("solución
# incorrecta") no estaba cubierto: los otros tests validan soluciones CORRECTAS.
# Cubrimos un nivel SIN memoria (b1_eco) y uno CON memoria (invertir_trio).
#   godot --headless --script test_falla.gd

func _initialize() -> void:
	var escena = load("res://main.tscn").instantiate()
	get_root().add_child(escena)
	await process_frame

	for id in ["b1_eco", "invertir_trio"]:
		var idx: int = escena.orden.find(id)
		assert(idx >= 0, "el nivel %s no está en el orden" % id)
		escena._cargar_indice(idx)
		await process_frame
		assert(escena.nivel.id == id, "no se cargó el nivel %s" % id)

		# Programa incorrecto: solo « soltá » -> mano vacía -> null en la salida.
		escena.agregar_op("SOLTAR")
		assert(escena.programa.size() == 1, "el editor no agregó SOLTAR en %s" % id)

		var r = Validador.validar(escena.nivel, escena.programa)
		assert(r.motivo == "", "SOLTAR no debería ser rechazo estructural en %s: %s" % [id, r.motivo])
		assert(not r.paso, "una solución incorrecta NO debería pasar (%s)" % id)

		# Esto antes crasheaba con int(null); ahora debe devolver el string.
		var msg = escena._mensaje_falla(r)
		assert(msg is String and msg.length() > 0, "_mensaje_falla debe devolver un string sin crashear (%s)" % id)
		print("falla %s -> %s" % [id, msg.split("\n")[0]])

	print("OK: validar una solución incorrecta no crashea (_mensaje_falla con null en la salida)")
	quit()
