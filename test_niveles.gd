extends SceneTree

# Verificacion headless del sistema de niveles (loader + validador + scoring),
# sin UI. Corre la solucion conocida de cada nivel y confirma que pasa, imprime
# el score real (para fijar los `par`), y prueba que los rechazos funcionan.
#   godot --headless --script test_niveles.gd

func _initialize() -> void:
	var ids := ["b1_eco", "b2_invertir_par", "b3_eco_infinito", "b4_filtrar_ceros"]
	var todo_ok := true

	print("== Soluciones de ejemplo ==")
	for id in ids:
		var nivel = Niveles.cargar(id)
		assert(nivel != null, "no se pudo cargar %s" % id)
		var prog = Soluciones.para(id)
		var r = Validador.validar(nivel, prog)
		print("%-18s paso=%s  instrucciones=%d  pasos=%d   (par i=%d p=%d)" % [
			id, str(r.paso), r.score.instrucciones, r.score.pasos,
			nivel.par_instrucciones, nivel.par_pasos])
		if not r.paso:
			todo_ok = false
			if r.motivo != "":
				print("   motivo: ", r.motivo)
			for d in r.detalle_por_caso:
				if not d.ok:
					print("   FALLA  entrada=%s  obtuvo=%s  esperaba=%s  termino=%s" % [
						str(d.entrada), str(d.salida_obtenida), str(d.salida_esperada), str(d.termino)])
		assert(r.paso, "la solucion de %s no paso la validacion" % id)

	print("== Rechazos ==")

	# Instruccion fuera de instrucciones_permitidas (b1 solo permite TOMAR/SOLTAR).
	var r_op = Validador.validar(Niveles.cargar("b1_eco"),
		[["TOMAR", null], ["SALTAR", "x"], ["SOLTAR", null]])
	print("op no permitida    -> paso=%s  motivo='%s'" % [str(r_op.paso), r_op.motivo])
	assert(not r_op.paso, "deberia rechazar op no permitida")
	assert(r_op.motivo.contains("no permitida"), "el motivo deberia mencionar 'no permitida'")

	# Slot fuera de rango (b2 tiene slots=1, indice valido solo 0).
	var r_slot = Validador.validar(Niveles.cargar("b2_invertir_par"),
		[["TOMAR", null], ["GUARDAR", 5], ["SOLTAR", null]])
	print("slot fuera de rango-> paso=%s  motivo='%s'" % [str(r_slot.paso), r_slot.motivo])
	assert(not r_slot.paso, "deberia rechazar slot fuera de rango")
	assert(r_slot.motivo.contains("Slot"), "el motivo deberia mencionar el slot")

	# Estructura valida pero salida incorrecta (eco de un solo valor).
	var r_mal = Validador.validar(Niveles.cargar("b1_eco"),
		[["TOMAR", null], ["SOLTAR", null]])
	print("salida incorrecta  -> paso=%s  obtuvo=%s" % [
		str(r_mal.paso), str(r_mal.detalle_por_caso[0].salida_obtenida)])
	assert(not r_mal.paso, "deberia fallar por salida incorrecta")

	# Salto sin destino (no debe colgar ni spamear: se rechaza de entrada).
	var r_sd = Validador.validar(Niveles.cargar("b3_eco_infinito"),
		[["TOMAR", null], ["SALTAR"]])
	print("salto sin destino  -> paso=%s  motivo='%s'" % [str(r_sd.paso), r_sd.motivo])
	assert(not r_sd.paso, "deberia rechazar salto sin destino")
	assert(r_sd.motivo.contains("destino"), "el motivo deberia mencionar el destino")

	# Salto a una etiqueta inexistente (typo).
	var r_typo = Validador.validar(Niveles.cargar("b3_eco_infinito"),
		[["ETIQUETA", "inicio"], ["TOMAR", null], ["SALTAR", "iniico"]])
	print("etiqueta inexistente-> paso=%s  motivo='%s'" % [str(r_typo.paso), r_typo.motivo])
	assert(not r_typo.paso, "deberia rechazar etiqueta inexistente")
	assert(r_typo.motivo.contains("Etiqueta desconocida"), "el motivo deberia mencionar etiqueta desconocida")

	print("== Robustez del loader ==")
	# JSON con campos raros: entrada null y par no-dict no deben romper el loader.
	var n_mal = Niveles.desde_dict({
		"id": "x", "slots": 0,
		"instrucciones_permitidas": ["TOMAR", "SOLTAR"],
		"casos": [{ "entrada": null, "salida_esperada": [1] }],
		"par": 42,
	})
	assert(n_mal != null, "el loader no deberia devolver null por campos raros")
	assert(n_mal.casos.size() == 1, "deberia conservar el caso")
	assert(n_mal.casos[0].entrada == [], "entrada null deberia degradar a []")
	assert(n_mal.par_instrucciones == 0 and n_mal.par_pasos == 0, "par no-dict deberia degradar a 0")
	print("loader tolera entrada=null y par no-dict")

	if todo_ok:
		print("OK: soluciones de ejemplo pasan y los rechazos andan")
	quit()
