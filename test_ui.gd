extends SceneTree

# Smoke test headless de la UI. NO dibuja nada: instancia la escena, ejerce el
# camino real de los botones (Step incluye la capa de animacion) y avanza hasta
# terminar, asertando que el estado evoluciona igual que en el intérprete puro.
#   godot --headless --script test_ui.gd
# Esperado:  salida final [3, 7]  y  OK: la UI maneja el estado bien

func _initialize() -> void:
	var escena = load("res://main.tscn").instantiate()
	get_root().add_child(escena)
	# _ready() (que arma la UI y llama _reset()) se dispara recien en el
	# proximo frame de proceso; esperamos uno antes de mirar el estado.
	await process_frame

	# Cargar "invertir el par" via el selector (el default es el primer nivel, eco).
	escena._cargar_indice(escena.orden.find("b2_invertir_par"))
	assert(escena.nivel.id == "b2_invertir_par", "no se cargo el nivel por el selector")

	# Estado inicial: programa VACIO, mano vacia, nada en la salida.
	assert(escena.estado != null, "la escena no inicializo el estado")
	assert(escena.programa.is_empty(), "el programa deberia arrancar vacio")
	assert(escena.estado.salida.is_empty(), "la salida deberia arrancar vacia")
	assert(escena.mano_label.text == "·", "la mano deberia arrancar vacia")
	assert(escena.estado.pc == 0, "el pc deberia arrancar en 0")

	# Construir la solucion de "invertir el par" con la API del editor.
	for op in ["TOMAR", "GUARDAR", "TOMAR", "SOLTAR", "COPIAR", "SOLTAR"]:
		escena.agregar_op(op)
	# GUARDAR (linea 1) y COPIAR (linea 4) quedan con slot 0 por defecto: justo lo que hace falta.
	assert(escena.programa.size() == 6, "el editor no agrego las 6 lineas")

	# Primer paso por el camino REAL del boton (incluye redibujar + _animar).
	escena._on_step_pressed()
	assert(escena.estado.slots != null, "los slots no existen")

	# Resto de los pasos hasta terminar (tope de seguridad).
	var tope := 1000
	while not escena.estado.terminado and tope > 0:
		escena._paso()
		tope -= 1

	print("salida final ", escena.estado.salida)
	assert(escena.estado.terminado, "el programa no termino")
	assert(escena.estado.salida == [3, 7], "la UI no produjo el swap esperado")
	assert(escena.estado.mano == null, "la mano deberia quedar vacia al final")
	assert(escena.estado_label.text.contains("TERMINADO"), "la linea de estado no marco fin")
	assert(escena.mano_label.text == "·", "el render de la mano final esta mal")

	# Reset vuelve todo al principio.
	escena._on_reset_pressed()
	assert(escena.estado.salida.is_empty(), "reset no limpio la salida")
	assert(escena.estado.pc == 0, "reset no volvio el pc a 0")
	assert(escena.pasos == 0, "reset no reinicio el contador de pasos")

	# Toggle de Run: prende y apaga el modo corrida (logica, sin esperar timing).
	escena._on_run_pressed()
	assert(escena.corriendo, "Run no arranco")
	assert(not escena.timer.is_stopped(), "el timer deberia estar corriendo")
	escena._on_run_pressed()
	assert(not escena.corriendo, "Run no se pauso")
	assert(escena.timer.is_stopped(), "el timer deberia estar detenido")

	print("OK: la UI maneja el estado bien")
	quit()
