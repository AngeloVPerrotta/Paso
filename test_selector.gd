extends SceneTree

# Verificacion headless del SELECTOR de niveles: navegacion ◀/▶, salto por indice,
# que cambiar de nivel re-inicializa programa/estado/paleta, y que Validar=PASÓ
# marca el nivel como resuelto (en memoria).
#   godot --headless --script test_selector.gd

func _initialize() -> void:
	Puntajes.set_track("c")          # determinista: el track C son los 12 niveles base
	var escena = load("res://main.tscn").instantiate()
	get_root().add_child(escena)
	await process_frame

	# Arranca en el primer nivel del orden.
	assert(escena.orden.size() == 12, "deberian ser 12 niveles")
	assert(escena.nivel_idx == 0 and escena.nivel.id == "b1_eco", "deberia arrancar en eco")

	# Siguiente / anterior.
	escena._on_next()
	assert(escena.nivel_idx == 1 and escena.nivel.id == "b2_invertir_par", "▶ no avanzo")
	escena._on_prev()
	assert(escena.nivel_idx == 0, "◀ no retrocedio")
	# ◀ en el primero no se pasa de rango.
	escena._on_prev()
	assert(escena.nivel_idx == 0, "◀ en el primer nivel no deberia salir de rango")

	# Salto directo por indice (lo que hace el strip de progreso).
	escena._cargar_indice(11)
	assert(escena.nivel.id == "pares_iguales", "salto al ultimo fallo")
	# ▶ en el ultimo no se pasa de rango.
	escena._on_next()
	assert(escena.nivel_idx == 11, "▶ en el ultimo no deberia salir de rango")

	# Cambiar de nivel re-inicializa el programa.
	escena.agregar_op("TOMAR")
	assert(escena.programa.size() == 1, "no se agrego la instruccion")
	escena._cargar_indice(0)
	assert(escena.programa.is_empty(), "cambiar de nivel deberia limpiar el programa")
	assert(escena.estado.pc == 0 and escena.pasos == 0, "cambiar de nivel deberia reiniciar la corrida")

	# Esperamos un frame para que se vacien los queue_free() diferidos de los
	# repintados anteriores (varios _cargar_indice corrieron en este mismo frame).
	await process_frame

	# La paleta refleja exactamente las instrucciones permitidas del nivel actual.
	assert(escena.paleta_box.get_child_count() == escena.nivel.instrucciones_permitidas.size(),
		"la paleta no coincide con instrucciones_permitidas")
	# El strip de progreso tiene un boton por nivel.
	assert(escena.progreso_box.get_child_count() == 12, "el strip de progreso deberia tener 12 entradas")

	# Resolver el primer nivel (eco) con su solucion, via el editor, y validar.
	assert(escena.nivel.id == "b1_eco", "deberiamos estar en eco")
	# El progreso se guarda con clave namespaced por track (c:<id> / csharp:<id>) para que
	# ganar en un track NO marque el equivalente del otro.
	assert(not escena.resueltos.has(escena._clave("b1_eco")), "no deberia estar resuelto todavia")
	for op in ["TOMAR", "SOLTAR", "TOMAR", "SOLTAR", "TOMAR", "SOLTAR"]:
		escena.agregar_op(op)
	escena._on_validar_pressed()
	assert(escena.resueltos.has(escena._clave("b1_eco")), "Validar=PASÓ deberia marcar el nivel resuelto")
	assert(escena.validacion_label.text.contains("PASÓ"), "deberia mostrar PASÓ")
	# El track C# NO debe verse afectado: el mismo id en el otro track tiene otra clave.
	assert(not escena.resueltos.has("csharp:b1_eco"), "ganar en C no deberia marcar el nivel en C#")

	# Un nivel no resuelto no esta marcado.
	assert(not escena.resueltos.has(escena._clave("pares_iguales")), "pares_iguales no deberia estar resuelto")

	print("OK: el selector navega, recarga nivel/paleta y marca progreso")
	quit()
