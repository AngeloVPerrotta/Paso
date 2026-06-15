extends SceneTree

# Verificacion headless del banco completo: carga los 12 niveles en el ORDEN de
# juego, corre la solucion de referencia de cada uno por el validador, asegura que
# pasa, e imprime el score MEDIDO vs el `par` del JSON (para fijarlos con la
# realidad). Marca "<<< DIFIERE" si no coinciden.
#   godot --headless --script test_orden.gd

func _initialize() -> void:
	var orden := Niveles.orden()
	print("orden de juego (%d): %s" % [orden.size(), str(orden)])
	assert(orden.size() == 12, "deberian ser 12 niveles en el orden de juego")

	var difieren := []
	for id in orden:
		var nivel = Niveles.cargar(id)
		assert(nivel != null, "no carga el nivel: %s" % id)
		var sol = Soluciones.para(id)
		assert(not sol.is_empty(), "falta solucion de referencia: %s" % id)
		var r = Validador.validar(nivel, sol)
		var ok_par: bool = r.score.instrucciones == nivel.par_instrucciones and r.score.pasos == nivel.par_pasos
		print("%-16s paso=%-5s  medido(i=%2d p=%3d)  json(i=%2d p=%3d)  %s" % [
			id, str(r.paso),
			r.score.instrucciones, r.score.pasos,
			nivel.par_instrucciones, nivel.par_pasos,
			"ok" if ok_par else "<<< DIFIERE"])
		if not r.paso:
			if r.motivo != "":
				print("   RECHAZADO: ", r.motivo)
			for d in r.detalle_por_caso:
				if not d.ok:
					print("   FALLA entrada=%s obtuvo=%s esperaba=%s" % [
						str(d.entrada), str(d.salida_obtenida), str(d.salida_esperada)])
		assert(r.paso, "la solucion de referencia de %s no paso la validacion" % id)
		if not ok_par:
			difieren.append("%s: medido(i=%d,p=%d) json(i=%d,p=%d)" % [
				id, r.score.instrucciones, r.score.pasos, nivel.par_instrucciones, nivel.par_pasos])

	if difieren.is_empty():
		print("OK: los 12 cargan, sus soluciones pasan y los `par` coinciden con lo medido")
	else:
		print("ATENCION: hay par que no coinciden y hay que corregir en el JSON:")
		for s in difieren:
			print("   ", s)
	quit()
