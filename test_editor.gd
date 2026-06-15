extends SceneTree

# Verificacion headless del EDITOR de programa: construye programas usando la API
# del editor (agregar_op / mover_linea / borrar_linea), no arrays hardcodeados, y
# comprueba dos invariantes clave:
#   (a) un SALTAR a una etiqueta inexistente queda RECHAZADO con mensaje claro.
#   (b) reordenar lineas mantiene la resolucion de etiquetas (resuelven por NOMBRE
#       al indice ACTUAL, asi que mover una ETIQUETA reapunta los saltos solos).
#   godot --headless --script test_editor.gd

func _initialize() -> void:
	var escena = load("res://main.tscn").instantiate()
	get_root().add_child(escena)
	await process_frame

	# Cargamos b3 (eco infinito), que permite TOMAR/SOLTAR/SALTAR/ETIQUETA, via el selector.
	escena._cargar_indice(escena.orden.find("b3_eco_infinito"))
	assert(escena.nivel.id == "b3_eco_infinito", "no se cargo el nivel esperado")
	assert(escena.programa.is_empty(), "el programa deberia arrancar vacio tras cargar el nivel")

	# --- (a) SALTAR a etiqueta inexistente -> rechazado ---
	print("== (a) etiqueta inexistente ==")
	escena.agregar_op("ETIQUETA")        # L1 en linea 0
	escena.agregar_op("TOMAR")
	escena.agregar_op("SOLTAR")
	escena.agregar_op("SALTAR")          # destino por defecto: la 1ra etiqueta (L1)
	assert(escena.programa[0] == ["ETIQUETA", "L1"], "el autonombre de etiqueta deberia ser L1")
	assert(escena.programa[3] == ["SALTAR", "L1"], "SALTAR deberia apuntar a L1 por defecto")

	# Con la etiqueta presente, este programa es la solucion del eco infinito: pasa.
	var r_ok := Validador.validar(escena.nivel, escena.programa)
	print("   con L1 presente -> paso=%s  score=%s" % [str(r_ok.paso), str(r_ok.score)])
	assert(r_ok.paso, "el eco infinito construido en el editor deberia pasar")
	assert(r_ok.score.instrucciones == 3, "instrucciones del eco deberian ser 3 (sin contar ETIQUETA)")

	# Ahora borramos la ETIQUETA: el SALTAR queda colgado apuntando a "L1" inexistente.
	escena.borrar_linea(0)
	assert(escena.programa.size() == 3, "deberia quedar [TOMAR, SOLTAR, SALTAR]")
	var r_colgado := Validador.validar(escena.nivel, escena.programa)
	print("   tras borrar L1 -> paso=%s  motivo='%s'" % [str(r_colgado.paso), r_colgado.motivo])
	assert(not r_colgado.paso, "un salto a etiqueta inexistente deberia ser rechazado")
	assert(r_colgado.motivo.contains("Etiqueta desconocida"), "el motivo deberia explicar la etiqueta colgada")

	# Limpiar el programa con la API del editor.
	while escena.programa.size() > 0:
		escena.borrar_linea(0)
	assert(escena.programa.is_empty(), "no se pudo limpiar el programa")

	# --- (b) reordenar mantiene la resolucion de etiquetas ---
	print("== (b) reordenar conserva los saltos ==")
	# Construimos en un orden donde la ETIQUETA NO esta primera: [TOMAR, L1, SOLTAR, SALTAR L1]
	escena.agregar_op("TOMAR")           # idx 0
	escena.agregar_op("ETIQUETA")        # idx 1 -> L1
	escena.agregar_op("SOLTAR")          # idx 2
	escena.agregar_op("SALTAR")          # idx 3 -> L1 (1ra etiqueta existente)
	assert(escena.programa[3] == ["SALTAR", "L1"], "SALTAR deberia apuntar a L1")
	# L1 esta en el indice 1 -> el salto resuelto debe ir al indice 1.
	assert(escena.programa_run[3][1] == 1, "L1 esta en idx 1; el salto deberia resolver a 1")
	print("   L1 en idx 1 -> salto resuelve a %d" % escena.programa_run[3][1])

	# Movemos la ETIQUETA del idx 1 al idx 0: ahora L1 esta en el indice 0.
	escena.mover_linea(1, -1)
	assert(escena.programa[0] == ["ETIQUETA", "L1"], "la ETIQUETA deberia haber subido al idx 0")
	assert(escena.programa_run[3][1] == 0, "tras mover, L1 esta en idx 0; el salto deberia resolver a 0")
	print("   L1 movida a idx 0 -> salto resuelve a %d" % escena.programa_run[3][1])

	# Y el programa reordenado [L1, TOMAR, SOLTAR, SALTAR L1] es el eco infinito valido.
	var r_reord := Validador.validar(escena.nivel, escena.programa)
	print("   reordenado -> paso=%s  score=%s" % [str(r_reord.paso), str(r_reord.score)])
	assert(r_reord.paso, "el programa reordenado deberia seguir siendo valido")

	print("OK: el editor construye, rechaza saltos colgados y conserva saltos al reordenar")
	quit()
