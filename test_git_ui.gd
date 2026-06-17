extends SceneTree

# Smoke test headless de la UI del sandbox de git (Capa 2). NO dibuja: instancia
# GitSandbox, abre el módulo y recorre los ejercicios guiados por el camino real
# (_on_enter = lo que pasa al tipear + Enter), asertando el gating de cada paso.
# Cubre los must-fix: los pasos 6/7 usan baseline relativo, y el paso del pull
# SIEMPRE tiene algo para traer aunque nunca se toque el botón de simular la nube.
#   godot --headless --script test_git_ui.gd
# Esperado:  OK: el sandbox de git recorre los ejercicios ...

func _initialize() -> void:
	var sb := GitSandbox.new()
	get_root().add_child(sb)
	await process_frame          # _ready() arma la UI recién en el próximo frame
	sb.abrir()

	assert(sb._ejercicio == 0, "arranca en el ejercicio 0")
	assert(not _hecho(sb), "ej0 (init) no está hecho de entrada")
	sb._on_enter("git init")
	assert(_hecho(sb), "tras git init, ej0 hecho")
	sb._ejercicio_siguiente()

	# ej1: status es un paso guiado (flag _vio_status, acreditado por subcomando real).
	assert(sb._ejercicio == 1 and not _hecho(sb), "ej1 status: no hecho hasta tipearlo")
	sb._on_enter("git   status")          # espacios extra: igual debe acreditar (robustez)
	assert(_hecho(sb), "tras git status (con espacios), ej1 hecho")
	sb._ejercicio_siguiente()

	# ej2: add .
	assert(sb._ejercicio == 2, "ej2 add .")
	sb._on_enter("git add .")
	assert(_hecho(sb), "tras add ., ej2 hecho")
	sb._ejercicio_siguiente()

	# ej3: primer commit
	assert(sb._ejercicio == 3, "ej3 commit")
	sb._on_enter("git commit -m \"primero\"")
	assert(_hecho(sb), "tras commit, ej3 hecho")
	sb._ejercicio_siguiente()

	# ej4: log es un paso guiado (flag _vio_log).
	assert(sb._ejercicio == 4 and not _hecho(sb), "ej4 log: no hecho hasta tipearlo")
	sb._on_enter("git logfoo")            # comando erróneo: NO debe acreditar el paso
	assert(not _hecho(sb), "un comando inválido (git logfoo) no acredita el paso log")
	sb._on_enter("git log")
	assert(_hecho(sb), "tras git log, ej4 hecho")
	sb._ejercicio_siguiente()

	# ej5: push
	assert(sb._ejercicio == 5, "ej5 push")
	sb._on_enter("git push")
	assert(_hecho(sb), "tras push, ej5 hecho")
	sb._ejercicio_siguiente()

	# ej6: cambio + commit. Baseline relativo: entrar al paso NO lo da por hecho.
	assert(sb._ejercicio == 6 and not _hecho(sb), "ej6: no hecho con solo entrar (baseline relativo)")
	sb._editar_archivo()                 # toca el primer archivo limpio
	sb._on_enter("git add .")
	sb._on_enter("git commit -m \"segundo\"")
	assert(_hecho(sb), "tras cambio+commit, ej6 hecho")
	sb._ejercicio_siguiente()

	# ej7: push del commit nuevo. Baseline relativo sobre el remoto.
	assert(sb._ejercicio == 7 and not _hecho(sb), "ej7: no hecho con solo entrar")
	sb._on_enter("git push")
	assert(_hecho(sb), "tras push, ej7 hecho")
	sb._ejercicio_siguiente()

	# ej8: pull. MUST-FIX: el paso fuerza un commit remoto pendiente aunque nunca
	# hayamos tocado el botón de simular la nube, así la lección no se saltea.
	assert(sb._ejercicio == 8, "ej8 pull")
	assert(sb.modelo.atrasados() > 0, "el paso del pull SIEMPRE deja algo para traer")
	assert(not _hecho(sb), "ej8: no hecho hasta pullear")
	sb._on_enter("git pull")
	assert(_hecho(sb), "tras git pull, ej8 hecho")
	sb._ejercicio_siguiente()

	# ej9: cierre del flujo
	assert(sb._ejercicio == 9, "ej9 cierre")
	assert(_hecho(sb), "el último paso queda hecho")

	sb.queue_free()
	print("OK: el sandbox de git recorre los ejercicios y el paso del pull siempre tiene algo para traer")
	quit()


func _hecho(sb: GitSandbox) -> bool:
	return sb._ejercicios()[sb._ejercicio].hecho.call()
