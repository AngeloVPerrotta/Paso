extends SceneTree

# Smoke test headless de la UI del sandbox de git (Capa 2). Recorre los ejercicios
# por el CAMINO REAL que vive el usuario:
#   - _on_enter (tipear comando + Enter) actualiza el estado del paso (✓ / botón).
#   - el botón "Siguiente" (su señal `pressed`, conectada a _ejercicio_siguiente)
#     avanza _ejercicio Y refresca el header ("Ejercicio N/10").
# Cubre además los must-fix (baselines relativos, el paso del pull SIEMPRE con algo
# para traer) y el gating del botón (bloqueado hasta completar el paso).
#   godot --headless --script test_git_ui.gd

func _initialize() -> void:
	var sb := GitSandbox.new()
	get_root().add_child(sb)
	await process_frame          # _ready() arma la UI recién en el próximo frame
	sb.abrir()

	# Arranca en 1/10 (10 pasos: + status y log) con "Siguiente" bloqueado.
	assert(sb._ejercicio == 0, "arranca en el ejercicio 0")
	assert(sb._ej_label.text.contains("1/10"), "el header arranca en «Ejercicio 1/10»")
	assert(sb._ej_btn.disabled, "Siguiente arranca bloqueado (init no hecho)")
	assert(not _hecho(sb), "ej0 (init) no está hecho de entrada")
	sb._on_enter("git init")
	assert(_hecho(sb) and not sb._ej_btn.disabled, "tras git init: hecho y Siguiente habilitado")
	_avanzar(sb)

	# ej1: status (paso guiado, acreditado por subcomando real, no por texto crudo).
	assert(sb._ejercicio == 1 and not _hecho(sb), "ej1 status: no hecho hasta tipearlo")
	sb._on_enter("git   status")          # espacios extra: igual debe acreditar (robustez)
	assert(_hecho(sb), "tras git status (con espacios), ej1 hecho")
	_avanzar(sb)

	# ej2: add .
	assert(sb._ejercicio == 2, "ej2 add .")
	sb._on_enter("git add .")
	assert(_hecho(sb), "tras add ., ej2 hecho")
	_avanzar(sb)

	# ej3: primer commit
	assert(sb._ejercicio == 3, "ej3 commit")
	sb._on_enter("git commit -m \"primero\"")
	assert(_hecho(sb), "tras commit, ej3 hecho")
	_avanzar(sb)

	# ej4: log (paso guiado). Un comando inválido NO debe acreditar.
	assert(sb._ejercicio == 4 and not _hecho(sb), "ej4 log: no hecho hasta tipearlo")
	sb._on_enter("git logfoo")            # comando erróneo: no acredita el paso
	assert(not _hecho(sb), "un comando inválido (git logfoo) no acredita el paso log")
	sb._on_enter("git log")
	assert(_hecho(sb), "tras git log, ej4 hecho")
	_avanzar(sb)

	# ej5: push
	assert(sb._ejercicio == 5, "ej5 push")
	sb._on_enter("git push")
	assert(_hecho(sb), "tras push, ej5 hecho")
	_avanzar(sb)

	# ej6: cambio + commit. Baseline relativo: entrar al paso NO lo da por hecho.
	assert(sb._ejercicio == 6 and not _hecho(sb), "ej6: no hecho con solo entrar (baseline relativo)")
	assert(sb._ej_btn.disabled, "Siguiente bloqueado hasta hacer el cambio")
	sb._editar_archivo()                 # toca el primer archivo limpio
	sb._on_enter("git add .")
	sb._on_enter("git commit -m \"segundo\"")
	assert(_hecho(sb), "tras cambio+commit, ej6 hecho")
	_avanzar(sb)

	# ej7: push del commit nuevo (baseline relativo sobre el remoto).
	assert(sb._ejercicio == 7 and not _hecho(sb), "ej7: no hecho con solo entrar")
	sb._on_enter("git push")
	assert(_hecho(sb), "tras push, ej7 hecho")
	_avanzar(sb)

	# ej8: pull. MUST-FIX: el paso fuerza un commit remoto pendiente aunque nunca
	# hayamos tocado el botón de simular la nube, así la lección no se saltea.
	assert(sb._ejercicio == 8, "ej8 pull")
	assert(sb.modelo.atrasados() > 0, "el paso del pull SIEMPRE deja algo para traer")
	assert(not _hecho(sb), "ej8: no hecho hasta pullear")
	sb._on_enter("git pull")
	assert(_hecho(sb), "tras git pull, ej8 hecho")
	_avanzar(sb)

	# ej9: cierre. Header en 10/10, el botón pasa a "Cerrar" y oculta el módulo.
	assert(sb._ejercicio == 9, "ej9 cierre")
	assert(sb._ej_label.text.contains("10/10"), "el header llega a «Ejercicio 10/10»")
	assert(_hecho(sb) and not sb._ej_btn.disabled, "último paso: hecho y botón habilitado")
	assert(sb._ej_btn.text == "Cerrar", "el último paso muestra «Cerrar»")
	sb._ej_btn.pressed.emit()            # en el último, el botón cierra (no avanza)
	assert(not sb.visible, "«Cerrar» oculta el módulo")

	sb.queue_free()
	print("OK: el sandbox recorre los 10 ejercicios; Siguiente (señal real) avanza _ejercicio y refresca el header")
	quit()


# Avanza por el CAMINO REAL del botón: chequea que esté habilitado, dispara su
# señal `pressed` (conectada a _ejercicio_siguiente) y verifica que _ejercicio
# subió y que el header ("Ejercicio N/10") se refrescó.
func _avanzar(sb: GitSandbox) -> void:
	assert(not sb._ej_btn.disabled, "Siguiente debería estar habilitado tras completar el paso")
	var antes := sb._ejercicio
	var header_antes := sb._ej_label.text
	sb._ej_btn.pressed.emit()
	assert(sb._ejercicio == antes + 1, "el botón Siguiente avanza _ejercicio")
	assert(sb._ej_label.text != header_antes, "el header cambió al avanzar")
	assert(sb._ej_label.text.contains("%d/" % (sb._ejercicio + 1)), "el header refleja el nuevo número de ejercicio")


func _hecho(sb: GitSandbox) -> bool:
	return sb._ejercicios()[sb._ejercicio].hecho.call()
