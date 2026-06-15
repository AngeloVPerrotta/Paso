extends SceneTree

# Tests de edge cases para resolver_etiquetas

func _initialize() -> void:
	print("=== Tests de resolver_etiquetas ===")
	
	# Edge case 1: Etiqueta duplicada
	print("\n1. Etiqueta duplicada")
	var prog1 := [
		["ETIQUETA", "inicio"],
		["TOMAR", null],
		["ETIQUETA", "inicio"],  # duplicada
		["SOLTAR", null],
	]
	var resuelto1 = Interprete.resolver_etiquetas(prog1)
	# Segun el codigo, la ultima gana (linea 84: destinos[nombre] = i)
	# Asi que un salto a "inicio" debe ir a la linea 2
	print("   Programa original tiene ETIQUETA 'inicio' en linea 0 y 2")
	print("   Esperado: la ultima (linea 2) gana")
	# Verificar que el programa resuelto NO muta el original
	assert(prog1[2][0] == "ETIQUETA", "El original fue mutado!")
	print("   OK: el original no fue mutado")
	
	# Edge case 2: Etiqueta desconocida
	print("\n2. Etiqueta desconocida")
	var prog2 := [
		["TOMAR", null],
		["SALTAR", "no_existe"],
		["SOLTAR", null],
	]
	var resuelto2 = Interprete.resolver_etiquetas(prog2)
	print("   Salto a 'no_existe' se resuelve a -1")
	assert(resuelto2[1][1] == -1, "El salto a etiqueta desconocida deberia ser -1")
	print("   OK: devuelve -1")
	
	# Edge case 3: Argumento ya entero (idempotencia)
	print("\n3. Argumento ya entero (idempotencia)")
	var prog3 := [
		["TOMAR", null],
		["SALTAR", 0],  # ya es indice, no nombre
		["SOLTAR", null],
	]
	var resuelto3 = Interprete.resolver_etiquetas(prog3)
	assert(resuelto3[1][1] == 0, "El salto ya-entero deberia conservarse")
	print("   OK: el salto entero se respeta")
	
	# Edge case 4: ETIQUETA sin nombre (nombre = null)
	print("\n4. ETIQUETA sin nombre")
	var prog4 := [
		["ETIQUETA"],  # sin arg, nombre sera null
		["TOMAR", null],
		["SALTAR", null],  # salto a null
		["SOLTAR", null],
	]
	var resuelto4 = Interprete.resolver_etiquetas(prog4)
	# Si el salto tiene arg null, deberia quedarse como null (no es STRING)
	assert(resuelto4[2][1] == null, "Salto a null deberia quedarse null")
	print("   OK: null se respeta")
	
	# Edge case 5: Salto cuyo destino es la propia linea ETIQUETA
	print("\n5. Salto a la propia linea ETIQUETA")
	var prog5 := [
		["ETIQUETA", "bucle"],
		["TOMAR", null],
		["SALTAR", "bucle"],
	]
	var resuelto5 = Interprete.resolver_etiquetas(prog5)
	# El salto "bucle" debe apuntar a la linea 0 (donde esta ETIQUETA)
	assert(resuelto5[2][1] == 0, "El salto a la etiqueta deberia ser 0")
	print("   OK: salto a la etiqueta resuelto a 0")
	
	# Edge case 6: Verificar que instr.duplicate() es suficiente (no es shallow)
	print("\n6. Verificar que la copia NO comparta referencias")
	var prog6 := [
		["TOMAR", null],
		["SOLTAR", null],
	]
	var resuelto6 = Interprete.resolver_etiquetas(prog6)
	# Mutamos el original y vemos si afecta a la copia
	prog6[0][0] = "MUTADO"
	assert(resuelto6[0][0] == "TOMAR", "El programa resuelto fue afectado por mutacion del original!")
	print("   OK: la copia es independiente del original")
	
	# Edge case 7: ETIQUETA es no-op en ejecucion
	print("\n7. ETIQUETA es verdaderamente no-op")
	var prog7 := [
		["ETIQUETA", "inicio"],
		["TOMAR", null],
		["SOLTAR", null],
	]
	# Simular ejecucion
	var estado7 = Interprete.Estado.new([42], 0)
	Interprete.ejecutar_paso(estado7, prog7)
	# Despues del primer paso, pc deberia ser 1 (ETIQUETA avanzo sin hacer nada)
	assert(estado7.pc == 1, "ETIQUETA no avanzo correctamente o hizo algo")
	assert(estado7.mano == null, "ETIQUETA cambio la mano")
	print("   OK: ETIQUETA es no-op")
	
	# Edge case 8: Arg null en operaciones que no son SALTAR/SALTAR_SI_CERO
	print("\n8. Args null en COPIAR (deberia dejar null como slot)")
	var prog8 := [
		["COPIAR", 0],
		["SOLTAR", null],
	]
	var estado8 = Interprete.Estado.new([], 1)
	Interprete.ejecutar_paso(estado8, prog8)
	assert(estado8.mano == null, "COPIAR de slot vacio deberia dejar mano null")
	print("   OK: COPIAR null funciona")
	
	print("\n=== OK: todos los edge cases pasaron ===")
	quit()
