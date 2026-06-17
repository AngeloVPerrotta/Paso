extends SceneTree

# Verificación headless del generador de C# (csharp.gd). Recorre los 12 niveles con
# su solución de referencia, imprime el C# generado y confirma que:
#   - no rompe y produce algo sensato (firma, llaves balanceadas, declara la mano),
#   - las 12 salen SIN goto (patrón reconocido),
#   - los loops salen como while, y los condicionales como if (mano == 0) continue/break,
#   - un programa que no matchea cae al fallback (con goto) sin romper.
#   godot --headless --script test_csharp.gd

func _initialize() -> void:
	var orden := Niveles.orden()
	assert(orden.size() == 12, "deberían ser 12 niveles")

	for id in orden:
		var nivel = Niveles.cargar(id)
		assert(nivel != null, "no carga %s" % id)
		var sol = Soluciones.para(id)
		assert(not sol.is_empty(), "falta solución de referencia: %s" % id)
		var cs: String = Csharp.desde_programa(sol, nivel.slots, id, nivel.descripcion)
		print("==== %s ====" % id)
		print(cs)
		print("")
		assert(cs.contains("void Resolver"), "%s: falta la firma" % id)
		assert(cs.count("{") == cs.count("}"), "%s: llaves desbalanceadas" % id)
		assert(not cs.contains("goto"), "%s: no debería usar goto (patrón reconocido)" % id)
		assert(not cs.contains("null"), "%s: apareció 'null' en el C#" % id)
		assert(cs.contains("int mano"), "%s: no declara la mano" % id)
		# Comentario-resumen arriba del método (= enunciado del nivel).
		assert(cs.begins_with("// "), "%s: falta el comentario de qué hace" % id)

	# Loops -> while (con su comentario).
	for id in ["b3_eco_infinito", "b4_filtrar_ceros", "duplicar_cola", "sumar_pares", "cortar_en_cero", "pares_iguales"]:
		var nivel = Niveles.cargar(id)
		var cs: String = Csharp.desde_programa(Soluciones.para(id), nivel.slots, id)
		assert(cs.contains("while (entrada.Count > 0)"), "%s: debería ser while" % id)
		assert(cs.contains("// repetí mientras"), "%s: falta el comentario del loop" % id)

	# Lineales -> sin while.
	for id in ["b1_eco", "b2_invertir_par", "duplicar", "invertir_trio", "sumar_par", "restar_par"]:
		var cs: String = Csharp.desde_programa(Soluciones.para(id), 2, id)
		assert(not cs.contains("while"), "%s: lineal no debería tener while" % id)

	# Condicionales idiomáticos.
	assert(Csharp.desde_programa(Soluciones.para("b4_filtrar_ceros"), 0).contains("if (mano == 0) continue;"),
		"filtrar_ceros: debería ser continue")
	assert(Csharp.desde_programa(Soluciones.para("cortar_en_cero"), 0).contains("if (mano == 0) break;"),
		"cortar_en_cero: debería ser break")
	var pi := Csharp.desde_programa(Soluciones.para("pares_iguales"), 1)
	assert(pi.contains("if (mano == 0)"), "pares_iguales: falta el if")
	assert(pi.contains("mano -= memoria0;"), "pares_iguales: falta el restá")

	# Tipado: agarrá declara, soltá escribe, recuperá/sumá idiomáticos.
	var inv := Csharp.desde_programa(Soluciones.para("invertir_trio"), 2)
	assert(inv.contains("int mano = entrada.Dequeue();"), "agarrá -> leer entrada")
	assert(inv.contains("int memoria0 = mano;"), "guardá -> declarar memoria")
	assert(inv.contains("salida.Add(mano);"), "soltá -> escribir salida")
	assert(inv.contains("mano = memoria0;"), "recuperá -> asignar desde memoria")
	assert(Csharp.desde_programa(Soluciones.para("sumar_par"), 1).contains("mano += memoria0;"), "sumá -> +=")

	# Fallback: un programa que NO matchea un patrón conocido no rompe (usa goto).
	var raro := Csharp.desde_programa([
		["TOMAR", null], ["SALTAR_SI_CERO", "X"], ["SOLTAR", null], ["ETIQUETA", "X"]], 0)
	assert(raro.contains("void Resolver"), "fallback: debería generar igual")
	assert(raro.count("{") == raro.count("}"), "fallback: llaves balanceadas")

	print("OK: C# generado para los 12 niveles, idiomático y sin romper")
	quit()
