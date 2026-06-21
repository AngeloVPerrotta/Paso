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
	await _shot_onboarding()
	await _shot_sandbox()
	await _shot_ux()
	await _shot_como()
	await _shot_tutorial()
	await _shot_tutorial_fixes()
	await _shot_corrida_y_win()
	await _shot_avance()
	await _shot_codigo("c", "invertir_trio", "shot_c.png")
	await _shot_codigo("csharp", "invertir_cuarteto", "shot_csharp.png")

	print("listo: screenshots guardados en shots/")
	quit()


# Módulo "Aprendé Git": ancla (local vs nube), flujo (push: foto viajando) y resumen.
func _shot_git() -> void:
	var g = escena.git_capa
	escena.inicio_capa.visible = false
	g.abrir()                                  # paso 0: repo (le saca fotos)
	await _esperar(24)                          # spotlight en intensidad alta
	await _guardar("shot_git_spotlight.png")    # SPOTLIGHT activo (oscurece todo menos el foco + burbuja)
	await _esperar(70)                          # se levanta el velo
	g._siguiente()                             # paso 1: local y nube (conceptual)
	await _esperar(90)                          # línea dibujada + velo abajo
	await _guardar("shot_git_nube.png")
	g._siguiente()                             # paso 2: cambio+add (elegís qué entra en la foto)
	await _esperar(90)
	g._lienzo.prog = 0.6                        # la cajita entrando al marco de "la próxima foto"
	g._lienzo.queue_redraw()
	await _esperar(2)
	await _guardar("shot_git_add.png")          # metáfora de la foto
	g._siguiente()                             # paso 3: commit (acción)
	await _esperar(90)
	g._lienzo.prog = 0.5
	g._lienzo.queue_redraw()
	await _esperar(2)
	await _guardar("shot_git_commit.png")
	g._siguiente()                             # paso 4: push — transición con viaje grande del robot
	await _esperar(10)                          # robot a mitad del viaje (commit→push)
	await _guardar("shot_git_viaje.png")        # el ROBOT viajando
	await _esperar(80)
	g._lienzo.prog = 0.5                        # la cajita viajando por la línea PC→nube
	g._lienzo.queue_redraw()
	await _esperar(2)
	await _guardar("shot_git_push.png")
	g._siguiente(); g._siguiente()             # 5 pull, 6 cierre
	await _esperar(60)
	await _guardar("shot_git_resumen.png")
	g.cerrar_modulo()
	await _esperar(2)


# Sandbox de git (Capa 2): JUGAMOS los ejercicios de verdad (comando + "Siguiente"),
# así el header avanza y las capturas caen en un ejercicio avanzado (no en 1/10).
func _shot_sandbox() -> void:
	var sgit = escena.git_sandbox
	escena.inicio_capa.visible = false
	sgit.abrir()
	await _esperar(4)
	# 1/10 init -> 2/10 status -> 3/10 add -> 4/10 commit -> 5/10 log -> 6/10 push.
	sgit._on_enter("git init");                       sgit._ejercicio_siguiente()
	sgit._on_enter("git status");                     sgit._ejercicio_siguiente()
	sgit._on_enter("git add .");                      sgit._ejercicio_siguiente()
	sgit._on_enter("git commit -m \"primer commit\""); sgit._ejercicio_siguiente()
	sgit._on_enter("git log");                        sgit._ejercicio_siguiente()
	sgit._on_enter("git push")                        # header: «Ejercicio 6/10»
	await _esperar(6)
	await _guardar("shot_git_consola.png")
	# 7/10 cambio + commit -> 8/10 push -> 9/10 pull (el paso auto-simula la nube).
	sgit._ejercicio_siguiente()
	sgit._editar_archivo()
	sgit._on_enter("git add .")
	sgit._on_enter("git commit -m \"segundo\"");      sgit._ejercicio_siguiente()
	sgit._on_enter("git push");                       sgit._ejercicio_siguiente()
	sgit._on_enter("git pull")                        # header: «Ejercicio 9/10», sincronizado
	await _esperar(6)
	await _guardar("shot_git_sync.png")
	sgit.cerrar_modulo()
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
	escena._abrir_como_funciona()                 # paso 1 de 4
	await _esperar(4)
	escena._demo_avanzar()                         # agarrá
	escena._demo_avanzar()                         # guardá (valor en mano + memoria)
	await _esperar(10)
	await _guardar("shot_como.png")                # con el botón "Siguiente ▶" de avance manual
	escena._demo_avanzar()                         # soltá (último paso: "Siguiente" se deshabilita)
	await _esperar(10)
	await _guardar("shot_como_fin.png")
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


# Issue #2: pasos NUEVOS del tutorial nivel 1 — "tu programa ejecutándose" (con "Ver de
# nuevo") y el FOCO final en la consigna. Los pasos intermedios son interactivos, así que
# saltamos directo a los índices nuevos.
func _shot_tutorial_fixes() -> void:
	Puntajes.set_flag("tuto_b1_eco", false)
	escena.inicio_capa.visible = false
	escena._cargar_indice(escena.orden.find("b1_eco"))
	await _esperar(14)
	escena._tuto_i = 5                              # "Eso que viste es tu programa ejecutándose, paso a paso."
	escena._tutorial_mostrar_paso()
	await _esperar(14)
	await _guardar("shot_tuto_ejecuto.png")        # nuevo wording + botón "▶ Ver de nuevo"
	escena._tuto_i = 6                              # foco en la consigna del nivel
	escena._tutorial_mostrar_paso()
	await _esperar(14)
	await _guardar("shot_tuto_consigna.png")       # spotlight sobre la consigna (desc_label)
	escena._saltar_tutorial()
	await _esperar(2)


# Issue #1: avance ofrecido SIEMPRE al ganar, incluso pasadas las 3 veces de código-al-ganar.
func _shot_avance() -> void:
	for i in 3:
		Puntajes.set_flag("cod_ganar_%d" % (i + 1), true)   # simular "ya se mostró el código 3 veces"
	var id := "invertir_trio"
	escena.inicio_capa.visible = false
	escena._cargar_indice(escena.orden.find(id))
	await _esperar(4)
	escena.programa = Soluciones.para(id).duplicate(true)
	escena._repintar_programa()
	escena._reset_corrida()
	await _esperar(2)
	escena._on_validar_pressed()                   # gana → banner (sin código pendiente)
	await _esperar(40)
	await _guardar("shot_win_alto.png")            # banner de victoria en nivel alto
	escena._ofrecer_avance_al_ganar()              # lo que dispara _descartar_banner al cerrar
	await _esperar(40)
	await _guardar("shot_avance.png")              # robot ofreciendo "Siguiente nivel ▸"
	escena._cerrar_comentario()
	await _esperar(4)


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

	# Capturamos a mitad de cada vuelo. (El selector de velocidad ya no existe; antes
	# acá se forzaba escena.vel_idx = 0, propiedad removida → rompía el harness.)
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


# Onboarding "primera vez" (FASE 3): presentaciones de zonas con spotlight.
func _shot_onboarding() -> void:
	escena.inicio_capa.visible = false
	escena._cargar_indice(escena.orden.find("invertir_trio"))   # nivel que SÍ usa memoria
	await _esperar(8)
	escena._cerrar_tutorial()                                    # limpiar lo que haya disparado auto
	await _capturar_zona("« ENTRAN » — los números que llegan, en fila.", func(): return escena.entrada_box, "shot_onb_entran.png")
	await _capturar_zona("« EN LA MANO » — lo que el robot tiene agarrado ahora.", func(): return escena.mano_celda, "shot_onb_mano.png")
	await _capturar_zona("« MEMORIA » — un cajón para guardar algo y usarlo después.", func(): return escena.slots_box, "shot_onb_memoria.png")
	await _capturar_zona("« SALEN » — lo que el robot va sacando, en orden.", func(): return escena.salida_box, "shot_onb_salen.png")


func _capturar_zona(texto: String, getter: Callable, nombre: String) -> void:
	escena._cerrar_tutorial()
	escena._tuto_pasos = [{"texto": texto, "objetivo": getter}]
	escena._tuto_i = 0
	escena._tuto_marca_visto = false
	escena._tutorial_arrancar()
	await _esperar(12)     # _tutorial_mostrar_paso espera 2 frames para ubicar el globo
	await _guardar(nombre)
	escena._cerrar_tutorial()
	await _esperar(2)


func _esperar(frames: int) -> void:
	for i in frames:
		await process_frame


func _guardar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_png("%s/%s" % [DIR, nombre])
	print("  ", nombre, "  ", img.get_size())
