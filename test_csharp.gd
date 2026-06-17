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

	# --- Cobertura por TRACK: generar el código de CADA solución de referencia ---
	# Track C: los 12 base con el generador de C. Track C#: los 12 + avanzados con C#.
	var por_track := {
		"c": Niveles.orden(),
		"csharp": Niveles.orden() + Niveles.avanzados(),
	}
	for tr in por_track:
		for id in por_track[tr]:
			var nivel = Niveles.cargar(id)
			var sol = Soluciones.para(id)
			assert(not sol.is_empty(), "%s: falta solución de referencia" % id)
			var code: String = (Cc.desde_programa(sol, nivel.slots, id, nivel.descripcion) if tr == "c" \
				else Csharp.desde_programa(sol, nivel.slots, id, nivel.descripcion))
			var firma := "void resolver(" if tr == "c" else "void Resolver("
			assert(code.contains(firma), "%s/%s: falta la firma" % [tr, id])
			assert(code.count("{") == code.count("}"), "%s/%s: llaves desbalanceadas" % [tr, id])
			assert(not code.contains("goto"), "%s/%s: no debería usar goto (patrón reconocido)" % [tr, id])
			assert(not code.contains("null"), "%s/%s: apareció 'null'" % [tr, id])
			assert(code.contains("int mano"), "%s/%s: no declara la mano" % [tr, id])
			assert(code.begins_with("// "), "%s/%s: falta el comentario de qué hace" % [tr, id])
	print("tracks C y C# generan el código de todas las soluciones sin romper")

	# C idiomático: índice sobre arreglo + printf.
	var c_inv := Cc.desde_programa(Soluciones.para("invertir_trio"), 2)
	assert(c_inv.contains("void resolver(int entrada[], int n)"), "C: firma")
	assert(c_inv.contains("int i = 0;"), "C: índice de lectura")
	assert(c_inv.contains("int mano = entrada[i++];"), "C: agarrá -> entrada[i++]")
	assert(c_inv.contains("printf(\"%d\\n\", mano);"), "C: soltá -> printf")
	assert(Cc.desde_programa(Soluciones.para("b3_eco_infinito"), 0).contains("while (i < n)"), "C: loop -> while (i < n)")
	assert(Cc.desde_programa(Soluciones.para("b4_filtrar_ceros"), 0).contains("if (mano == 0) continue;"), "C: continue")

	# Avanzados (track C#): salen estructurados (while / if), no goto.
	var av := Csharp.desde_programa(Soluciones.para("invertir_cuarteto"), 3)
	assert(av.contains("while (entrada.Count > 0)") and av.contains("memoria2"), "avanzado invertir_cuarteto")
	assert(Csharp.desde_programa(Soluciones.para("pares_iguales_doble"), 1).contains("if (mano == 0)"),
		"avanzado pares_iguales_doble: branch")

	print("OK: C y C# generados para sus tracks (12 base + avanzados), sin romper")
	quit()
