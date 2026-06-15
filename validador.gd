class_name Validador
extends RefCounted

# Validacion + scoring, COMO CAPA encima del Interprete (que sigue siendo pura
# logica estado->estado). El validador no toca nodos ni UI; recibe un Nivel y un
# programa del jugador y devuelve un Resultado.

class Resultado:
	var paso: bool = false                 # pasa solo si TODOS los casos dan ok
	var motivo: String = ""                # por que fallo la validacion estructural (si aplica)
	var score: Dictionary = {"instrucciones": 0, "pasos": 0}
	var detalle_por_caso: Array = []       # de {entrada, salida_esperada, salida_obtenida, ok, termino}

# Ops que llevan un indice de slot como argumento.
const _OPS_CON_SLOT := ["COPIAR", "GUARDAR", "SUMAR", "RESTAR"]
# Ops que saltan a una etiqueta (arg = nombre de etiqueta, o indice ya resuelto).
const _OPS_CON_ETIQUETA := ["SALTAR", "SALTAR_SI_CERO"]


static func validar(nivel, programa: Array) -> Resultado:
	var r := Resultado.new()

	# Etiquetas declaradas, para validar los destinos de salto.
	var etiquetas := {}
	for instr in programa:
		if not instr.is_empty() and instr[0] == "ETIQUETA":
			etiquetas[instr[1] if instr.size() > 1 else null] = true

	# --- 1) Validacion estructural (antes de correr nada) ---
	for instr in programa:
		if instr.is_empty():
			r.motivo = "Instrucción vacía."
			return r
		var op: String = instr[0]
		if not nivel.instrucciones_permitidas.has(op):
			r.motivo = "Instrucción no permitida: %s" % op
			return r
		if op in _OPS_CON_SLOT:
			var s = instr[1] if instr.size() > 1 else null
			if typeof(s) != TYPE_INT or s < 0 or s >= nivel.slots:
				r.motivo = "Slot fuera de rango (%s) en %s; el nivel tiene %d slot(s)." % [str(s), op, nivel.slots]
				return r
		elif op in _OPS_CON_ETIQUETA:
			var destino = instr[1] if instr.size() > 1 else null
			if typeof(destino) == TYPE_STRING:
				if not etiquetas.has(destino):
					r.motivo = "Etiqueta desconocida en %s: '%s'." % [op, destino]
					return r
			elif typeof(destino) != TYPE_INT:
				r.motivo = "%s necesita una etiqueta de destino." % op
				return r

	# --- 2) instrucciones = lineas del programa SIN contar las ETIQUETA ---
	var n_instr := 0
	for instr in programa:
		if instr[0] != "ETIQUETA":
			n_instr += 1

	# --- 3) correr cada caso (resolviendo etiquetas una sola vez) ---
	var resuelto := Interprete.resolver_etiquetas(programa)
	var total_pasos := 0
	var todos_ok := true
	for caso in nivel.casos:
		var res := _correr_contando(caso.entrada, nivel.slots, resuelto)
		# Pasa el caso solo si TERMINO (no quedo en loop infinito) y la salida coincide.
		var ok: bool = res.termino and res.salida == caso.salida_esperada
		todos_ok = todos_ok and ok
		total_pasos += res.pasos
		r.detalle_por_caso.append({
			"entrada": caso.entrada,
			"salida_esperada": caso.salida_esperada,
			"salida_obtenida": res.salida,
			"ok": ok,
			"termino": res.termino,
		})

	r.paso = todos_ok
	r.score = {"instrucciones": n_instr, "pasos": total_pasos}
	return r


# Corre un caso contando pasos segun la regla de scoring:
#   - NO cuenta la transicion que termina el nivel (pc fuera de rango, o TOMAR
#     con entrada vacia: ninguna de las dos hace "trabajo").
#   - NO cuenta las ejecuciones de ETIQUETA (son marcadores).
# `programa` ya viene con las etiquetas resueltas a indices.
static func _correr_contando(entrada: Array, slots: int, programa: Array, max_iter := 100000) -> Dictionary:
	var estado := Interprete.Estado.new(entrada, slots)
	var pasos := 0
	var iter := 0
	while not estado.terminado and iter < max_iter:
		iter += 1
		# Decidimos si este paso cuenta MIRANDO el estado antes de ejecutarlo.
		var cuenta := true
		if estado.pc < 0 or estado.pc >= programa.size():
			cuenta = false                         # termina por pc fuera de rango
		else:
			var op: String = programa[estado.pc][0]
			if op == "ETIQUETA":
				cuenta = false                     # marcador, no es trabajo
			elif op == "TOMAR" and estado.entrada.is_empty():
				cuenta = false                     # TOMAR con entrada vacia: termina
		Interprete.ejecutar_paso(estado, programa)
		if cuenta:
			pasos += 1
	return {
		"salida": estado.salida,
		"pasos": pasos,
		"termino": estado.terminado,
	}
