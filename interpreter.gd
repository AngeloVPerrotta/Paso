class_name Interprete
extends RefCounted

# La idea central: esto es PURA logica. No toca nodos, escenas ni UI.
# Godot solo va a dibujar "fotos" de este estado en cada paso.
# Eso te da step/undo gratis y lo hace testeable sin abrir nada.

# Estado del programa: todo lo que cambia paso a paso.
class Estado:
	var mano                      # un solo valor a la vez, o null si esta vacia
	var slots: Array              # memoria: slots[n]
	var entrada: Array            # cola de entrada
	var salida: Array             # cola de salida
	var pc: int = 0               # program counter: que instruccion sigue
	var terminado: bool = false

	func _init(entrada_inicial: Array, cantidad_slots: int) -> void:
		mano = null
		slots = []
		slots.resize(cantidad_slots)   # arranca con null
		entrada = entrada_inicial.duplicate()
		salida = []


# Una instruccion es [op, arg]. arg puede ser null.
# Ops: "TOMAR", "SOLTAR", "COPIAR", "GUARDAR", "SUMAR", "RESTAR",
#      "SALTAR", "SALTAR_SI_CERO", "ETIQUETA".
# "ETIQUETA" es un marcador no-op: solo sirve de destino de saltos.
# Las etiquetas se resuelven a indice (pc destino) con resolver_etiquetas()
# ANTES de correr: ahi los args de SALTAR/SALTAR_SI_CERO pasan de nombre a indice.
static func ejecutar_paso(estado: Estado, programa: Array) -> void:
	if estado.terminado:
		return
	if estado.pc < 0 or estado.pc >= programa.size():
		estado.terminado = true
		return

	var instr = programa[estado.pc]
	var op: String = instr[0]
	var arg = instr[1] if instr.size() > 1 else null
	var siguiente_pc := estado.pc + 1

	match op:
		"TOMAR":
			if estado.entrada.is_empty():
				estado.terminado = true        # regla del mundo: entrada vacia = fin
				return
			estado.mano = estado.entrada.pop_front()
		"SOLTAR":
			estado.salida.append(estado.mano)
			estado.mano = null
		"COPIAR":
			estado.mano = estado.slots[arg]
		"GUARDAR":
			estado.slots[arg] = estado.mano
		"SUMAR":
			estado.mano = estado.mano + estado.slots[arg]
		"RESTAR":
			estado.mano = estado.mano - estado.slots[arg]
		"SALTAR":
			# arg = indice destino ya resuelto. Si no es un indice (programa sin
			# resolver o mal formado), cortamos en vez de quedarnos colgados.
			if typeof(arg) == TYPE_INT:
				siguiente_pc = arg
			else:
				estado.terminado = true
				return
		"SALTAR_SI_CERO":
			if estado.mano == 0:
				if typeof(arg) == TYPE_INT:
					siguiente_pc = arg
				else:
					estado.terminado = true
					return
		"ETIQUETA":
			pass                               # no-op: solo es destino de saltos

	estado.pc = siguiente_pc


# Resuelve etiquetas a indices. Los programas autorados escriben los saltos por
# NOMBRE (p. ej. ["SALTAR", "inicio"]); aca convertimos ese nombre al indice de
# la linea ETIQUETA correspondiente, devolviendo una COPIA del programa lista
# para correr. Idempotente: si un arg ya es un indice entero, se deja igual.
static func resolver_etiquetas(programa: Array) -> Array:
	# 1ra pasada: ubicar cada ETIQUETA por nombre -> indice de su linea.
	var destinos := {}
	for i in programa.size():
		var instr = programa[i]
		if instr[0] == "ETIQUETA":
			var nombre = instr[1] if instr.size() > 1 else null
			if destinos.has(nombre):
				push_warning("Etiqueta duplicada '%s'; gana la ultima (linea %d)." % [str(nombre), i])
			destinos[nombre] = i

	# 2da pasada: copiar resolviendo los saltos.
	var resuelto := []
	for instr in programa:
		var op: String = instr[0]
		if op == "SALTAR" or op == "SALTAR_SI_CERO":
			var arg = instr[1] if instr.size() > 1 else null
			if typeof(arg) == TYPE_STRING:
				if not destinos.has(arg):
					push_error("Etiqueta desconocida '%s'; el salto terminara el nivel." % arg)
					resuelto.append([op, -1])      # pc fuera de rango -> termina
				else:
					resuelto.append([op, destinos[arg]])
			else:
				resuelto.append(instr.duplicate())  # ya es indice (o null): se respeta
		else:
			resuelto.append(instr.duplicate())
	return resuelto


# Corre el programa entero con un tope de pasos (para no colgarse en loops).
# Devuelve el estado final. La UI NO usa esto: la UI llama ejecutar_paso()
# de a uno y dibuja entre paso y paso.
static func correr(entrada: Array, cantidad_slots: int, programa: Array, max_pasos := 10000) -> Estado:
	var estado := Estado.new(entrada, cantidad_slots)
	var pasos := 0
	while not estado.terminado and pasos < max_pasos:
		ejecutar_paso(estado, programa)
		pasos += 1
	return estado
