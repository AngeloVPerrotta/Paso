class_name Csharp
extends RefCounted

# Genera C# idiomático a partir del programa del jugador (el modelo de
# programa_modelo()). Es COSMÉTICO/educativo: no toca intérprete ni validador.
#
# Reconoce los patrones de las soluciones de referencia y los emite lindo:
#   - lineal (sin saltos)                         -> secuencia de sentencias
#   - "etiqueta arriba + salto al final"          -> while (entrada.Count > 0) { ... }
#   - "si es cero saltá a inicio"                 -> if (mano == 0) continue;
#   - "si es cero saltá a (etiqueta después)"     -> if (mano == 0) break;
#   - "si es cero saltá a X" + "saltá a inicio"   -> if (mano == 0) { <bloque X> }
# Si un programa no matchea, cae a una versión FIEL con goto (sin romper).
#
# Modelo: la mano y cada memoria son int. Se declaran la 1ª vez (int x = ...) y
# se asignan después (x = ...). agarrá=leer entrada, soltá=escribir salida,
# recuperá=mano=memoria, sumá/restá = += / -=.

const FIRMA := "void Resolver(Queue<int> entrada, List<int> salida)"


# Punto de entrada: recibe el modelo de programa_modelo() ({lineas, descripcion, ...}).
static func generar(modelo) -> String:
	var lineas: Array = []
	var descripcion := ""
	if typeof(modelo) == TYPE_DICTIONARY:
		lineas = modelo.get("lineas", [])
		descripcion = str(modelo.get("descripcion", ""))
	var out: Array = []
	if descripcion != "":
		out.append_array(_wrap_comentario(descripcion, 70))   # qué hace el método
	out.append(FIRMA)
	out.append("{")
	if lineas.is_empty():
		out.append(_ind(1) + "// (programa vacío — agregá instrucciones)")
	else:
		var decl := {}
		if _es_lineal(lineas):
			_emit_ops(lineas, 0, lineas.size(), out, 1, decl, null)
		else:
			var loop = _detectar_loop(lineas)
			if loop != null:
				_emit_loop(lineas, loop, out, decl)
			else:
				_emit_goto(lineas, out)
	out.append("}")
	return "\n".join(out)


# Conveniencia para tests / UI: arma el modelo desde un `programa` crudo ([op,arg]).
static func desde_programa(programa: Array, slots := 0, nivel_id := "", descripcion := "") -> String:
	var lineas := []
	for instr in programa:
		lineas.append({"op": instr[0], "arg": instr[1] if instr.size() > 1 else null})
	return generar({"lineas": lineas, "slots": slots, "nivel": nivel_id, "descripcion": descripcion})


# ---------------------------------------------------------------------------
# Detección de estructura
# ---------------------------------------------------------------------------
static func _es_lineal(lineas: Array) -> bool:
	for l in lineas:
		var op := _op(l)
		if op == "ETIQUETA" or op == "SALTAR" or op == "SALTAR_SI_CERO":
			return false
	return true


# Devuelve {inicio, fin_set, body_lo, body_hi} si el programa es un loop reconocido,
# o null si no lo es (entonces se usa el fallback goto).
static func _detectar_loop(lineas: Array):
	if lineas.is_empty() or _op(lineas[0]) != "ETIQUETA":
		return null
	var inicio = _arg(lineas[0])
	# El último "saltá a inicio" cierra el loop.
	var loop_end := -1
	for i in lineas.size():
		if _op(lineas[i]) == "SALTAR" and _arg(lineas[i]) == inicio:
			loop_end = i
	if loop_end < 0:
		return null
	# Después del loop solo puede haber etiquetas (marcadores de "fin/break").
	var fin_set := {}
	for i in range(loop_end + 1, lineas.size()):
		if _op(lineas[i]) == "ETIQUETA":
			fin_set[_arg(lineas[i])] = true
		else:
			return null
	var body_lo := 1
	var body_hi := loop_end
	# El cuerpo arranca con agarrá (TOMAR): así while + Dequeue modela el "termina si no hay entrada".
	if body_hi <= body_lo or _op(lineas[body_lo]) != "TOMAR":
		return null
	if not _loop_valido(lineas, body_lo, body_hi, inicio, fin_set):
		return null
	return {"inicio": inicio, "fin_set": fin_set, "body_lo": body_lo, "body_hi": body_hi}


# Valida que TODOS los saltos del cuerpo sean clasificables (continue/break/branch).
static func _loop_valido(lineas: Array, lo: int, hi: int, inicio, fin_set: Dictionary) -> bool:
	for i in range(lo, hi):
		var op := _op(lineas[i])
		var arg = _arg(lineas[i])
		if op == "SALTAR":
			if arg != inicio and not fin_set.has(arg):
				return false
		elif op == "SALTAR_SI_CERO":
			if arg == inicio or fin_set.has(arg):
				continue
			# Branch: "si es cero saltá a X" donde el camino "else" (entre la
			# condición y la etiqueta X) es exactamente un "saltá a inicio".
			var xi := _buscar_etiqueta(lineas, arg, i + 1, hi)
			if xi < 0:
				return false
			if xi - (i + 1) != 1:
				return false
			if not (_op(lineas[i + 1]) == "SALTAR" and _arg(lineas[i + 1]) == inicio):
				return false
	return true


# ---------------------------------------------------------------------------
# Emisión
# ---------------------------------------------------------------------------
# Emite las instrucciones [lo, hi). ctx=null en código lineal; {inicio, fin_set}
# dentro de un while (habilita continue/break/branch).
static func _emit_ops(lineas: Array, lo: int, hi: int, out: Array, indent: int, decl: Dictionary, ctx) -> void:
	var i := lo
	while i < hi:
		var l = lineas[i]
		var op := _op(l)
		var arg = _arg(l)
		match op:
			"TOMAR":
				_asignar(out, indent, decl, "mano", "entrada.Dequeue()")
			"SOLTAR":
				_push(out, indent, "salida.Add(mano);")
			"GUARDAR":
				_asignar(out, indent, decl, _mem(arg), "mano")
			"COPIAR":
				_asignar(out, indent, decl, "mano", _mem(arg))
			"SUMAR":
				_push(out, indent, "mano += %s;" % _mem(arg))
			"RESTAR":
				_push(out, indent, "mano -= %s;" % _mem(arg))
			"ETIQUETA":
				pass
			"SALTAR":
				if ctx != null and arg == ctx.inicio:
					_push(out, indent, "continue;")
				elif ctx != null and ctx.fin_set.has(arg):
					_push(out, indent, "break;")
			"SALTAR_SI_CERO":
				if ctx != null and arg == ctx.inicio:
					_push(out, indent, "// si la mano vale 0, saltás al próximo valor")
					_push(out, indent, "if (mano == 0) continue;")
				elif ctx != null and ctx.fin_set.has(arg):
					_push(out, indent, "// si la mano vale 0, cortás el recorrido")
					_push(out, indent, "if (mano == 0) break;")
				else:
					# Branch: el resto del cuerpo (desde la etiqueta X) es el if-block.
					var xi := _buscar_etiqueta(lineas, arg, i + 1, hi)
					if xi >= 0:
						_push(out, indent, "// solo cuando la mano quedó en 0")
						_push(out, indent, "if (mano == 0)")
						_push(out, indent, "{")
						_emit_ops(lineas, xi + 1, hi, out, indent + 1, decl, ctx)
						_push(out, indent, "}")
						return   # consumido: el "else" es el loop-back implícito
		i += 1


static func _emit_loop(lineas: Array, loop: Dictionary, out: Array, decl: Dictionary) -> void:
	var ctx := {"inicio": loop.inicio, "fin_set": loop.fin_set}
	_push(out, 1, "// repetí mientras queden valores en la entrada")
	_push(out, 1, "while (entrada.Count > 0)")
	_push(out, 1, "{")
	_emit_ops(lineas, loop.body_lo, loop.body_hi, out, 2, decl, ctx)
	_push(out, 1, "}")


# Fallback FIEL: etiquetas + goto. Declara registros arriba (con goto no se puede
# declarar-en-primer-uso de forma segura). No se usa para las 12 de referencia.
static func _emit_goto(lineas: Array, out: Array) -> void:
	_push(out, 1, "int mano = 0;")
	var mems := {}
	for l in lineas:
		if _op(l) in ["GUARDAR", "COPIAR", "SUMAR", "RESTAR"] and typeof(_arg(l)) == TYPE_INT:
			mems[int(_arg(l))] = true
	var claves := mems.keys()
	claves.sort()
	for k in claves:
		_push(out, 1, "int memoria%d = 0;" % k)
	for l in lineas:
		var op := _op(l)
		var arg = _arg(l)
		match op:
			"ETIQUETA":
				_push(out, 1, "%s: ;" % _label(arg))
			"TOMAR":
				_push(out, 1, "if (entrada.Count == 0) goto fin_programa;")
				_push(out, 1, "mano = entrada.Dequeue();")
			"SOLTAR":
				_push(out, 1, "salida.Add(mano);")
			"GUARDAR":
				_push(out, 1, "memoria%d = mano;" % int(arg))
			"COPIAR":
				_push(out, 1, "mano = memoria%d;" % int(arg))
			"SUMAR":
				_push(out, 1, "mano += memoria%d;" % int(arg))
			"RESTAR":
				_push(out, 1, "mano -= memoria%d;" % int(arg))
			"SALTAR":
				_push(out, 1, "goto %s;" % _label(arg))
			"SALTAR_SI_CERO":
				_push(out, 1, "if (mano == 0) goto %s;" % _label(arg))
	_push(out, 1, "fin_programa: ;")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
static func _op(linea) -> String:
	return str(linea.get("op", "")) if typeof(linea) == TYPE_DICTIONARY else ""


static func _arg(linea):
	return linea.get("arg", null) if typeof(linea) == TYPE_DICTIONARY else null


static func _mem(arg) -> String:
	return "memoria%d" % (int(arg) if typeof(arg) == TYPE_INT else 0)


static func _ind(n: int) -> String:
	return "    ".repeat(n)


static func _push(out: Array, indent: int, texto: String) -> void:
	out.append(_ind(indent) + texto)


# Declara con `int` la 1ª vez; asigna después.
static func _asignar(out: Array, indent: int, decl: Dictionary, nombre: String, expr: String) -> void:
	if decl.has(nombre):
		_push(out, indent, "%s = %s;" % [nombre, expr])
	else:
		decl[nombre] = true
		_push(out, indent, "int %s = %s;" % [nombre, expr])


# Parte un texto largo en varias líneas "// ..." para que no necesite scroll horizontal.
static func _wrap_comentario(texto: String, ancho: int) -> Array:
	var lineas := []
	var actual := ""
	for p in texto.split(" ", false):
		if actual == "":
			actual = p
		elif actual.length() + 1 + p.length() <= ancho:
			actual += " " + p
		else:
			lineas.append("// " + actual)
			actual = p
	if actual != "":
		lineas.append("// " + actual)
	return lineas


static func _buscar_etiqueta(lineas: Array, nombre, lo: int, hi: int) -> int:
	for i in range(lo, hi):
		if _op(lineas[i]) == "ETIQUETA" and _arg(lineas[i]) == nombre:
			return i
	return -1


# Nombre de etiqueta seguro para C# (solo en el fallback goto).
static func _label(arg) -> String:
	var s := str(arg)
	var r := ""
	for i in s.length():
		var c := s[i]
		r += c if (c.is_valid_identifier() or (r != "" and c >= "0" and c <= "9")) else "_"
	if r == "" or (r[0] >= "0" and r[0] <= "9"):
		r = "L_" + r
	return r
