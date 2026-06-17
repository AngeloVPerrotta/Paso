class_name Cc
extends RefCounted

# Generador de C (espejo de csharp.gd). Cosmético/educativo: no toca intérprete
# ni validador. Mismo reconocimiento de patrones que Csharp; cambia el dialecto:
#
#   - entrada = arreglo int con índice `i`; salida = printf.
#   - agarrá -> mano = entrada[i++];   soltá -> printf("%d\n", mano);
#   - recuperá -> mano = memoria;      sumá/restá -> += / -=
#   - loop "etiqueta + salto al final" -> while (i < n) { ... }  (no goto)
#   - "si es cero saltá a inicio/X/fin" -> if (mano == 0) continue/{...}/break
# Si no matchea, cae a una versión FIEL con goto (sin romper).

const FIRMA := "void resolver(int entrada[], int n)"


static func generar(modelo) -> String:
	var lineas: Array = []
	var descripcion := ""
	if typeof(modelo) == TYPE_DICTIONARY:
		lineas = modelo.get("lineas", [])
		descripcion = str(modelo.get("descripcion", ""))
	var out: Array = []
	if descripcion != "":
		out.append_array(_wrap_comentario(descripcion, 70))
	out.append(FIRMA)
	out.append("{")
	if lineas.is_empty():
		out.append(_ind(1) + "// (programa vacío — agregá instrucciones)")
	else:
		_push(out, 1, "int i = 0;")              # índice de lectura de la entrada
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


static func desde_programa(programa: Array, slots := 0, nivel_id := "", descripcion := "") -> String:
	var lineas := []
	for instr in programa:
		lineas.append({"op": instr[0], "arg": instr[1] if instr.size() > 1 else null})
	return generar({"lineas": lineas, "slots": slots, "nivel": nivel_id, "descripcion": descripcion})


# ---------------------------------------------------------------------------
# Detección de estructura (idéntica a csharp.gd)
# ---------------------------------------------------------------------------
static func _es_lineal(lineas: Array) -> bool:
	for l in lineas:
		var op := _op(l)
		if op == "ETIQUETA" or op == "SALTAR" or op == "SALTAR_SI_CERO":
			return false
	return true


static func _detectar_loop(lineas: Array):
	if lineas.is_empty() or _op(lineas[0]) != "ETIQUETA":
		return null
	var inicio = _arg(lineas[0])
	var loop_end := -1
	for i in lineas.size():
		if _op(lineas[i]) == "SALTAR" and _arg(lineas[i]) == inicio:
			loop_end = i
	if loop_end < 0:
		return null
	var fin_set := {}
	for i in range(loop_end + 1, lineas.size()):
		if _op(lineas[i]) == "ETIQUETA":
			fin_set[_arg(lineas[i])] = true
		else:
			return null
	var body_lo := 1
	var body_hi := loop_end
	if body_hi <= body_lo or _op(lineas[body_lo]) != "TOMAR":
		return null
	if not _loop_valido(lineas, body_lo, body_hi, inicio, fin_set):
		return null
	return {"inicio": inicio, "fin_set": fin_set, "body_lo": body_lo, "body_hi": body_hi}


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
			var xi := _buscar_etiqueta(lineas, arg, i + 1, hi)
			if xi < 0:
				return false
			if xi - (i + 1) != 1:
				return false
			if not (_op(lineas[i + 1]) == "SALTAR" and _arg(lineas[i + 1]) == inicio):
				return false
	return true


# ---------------------------------------------------------------------------
# Emisión (dialecto C)
# ---------------------------------------------------------------------------
static func _emit_ops(lineas: Array, lo: int, hi: int, out: Array, indent: int, decl: Dictionary, ctx) -> void:
	var i := lo
	while i < hi:
		var l = lineas[i]
		var op := _op(l)
		var arg = _arg(l)
		match op:
			"TOMAR":
				_asignar(out, indent, decl, "mano", "entrada[i++]")
			"SOLTAR":
				_push(out, indent, "printf(\"%d\\n\", mano);")
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
					var xi := _buscar_etiqueta(lineas, arg, i + 1, hi)
					if xi >= 0:
						_push(out, indent, "// solo cuando la mano quedó en 0")
						_push(out, indent, "if (mano == 0)")
						_push(out, indent, "{")
						_emit_ops(lineas, xi + 1, hi, out, indent + 1, decl, ctx)
						_push(out, indent, "}")
						return
		i += 1


static func _emit_loop(lineas: Array, loop: Dictionary, out: Array, decl: Dictionary) -> void:
	var ctx := {"inicio": loop.inicio, "fin_set": loop.fin_set}
	_push(out, 1, "// repetí mientras queden valores en la entrada")
	_push(out, 1, "while (i < n)")
	_push(out, 1, "{")
	_emit_ops(lineas, loop.body_lo, loop.body_hi, out, 2, decl, ctx)
	_push(out, 1, "}")


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
				_push(out, 1, "if (i >= n) goto fin_programa;")
				_push(out, 1, "mano = entrada[i++];")
			"SOLTAR":
				_push(out, 1, "printf(\"%d\\n\", mano);")
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
# Helpers (idénticos a csharp.gd)
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


static func _asignar(out: Array, indent: int, decl: Dictionary, nombre: String, expr: String) -> void:
	if decl.has(nombre):
		_push(out, indent, "%s = %s;" % [nombre, expr])
	else:
		decl[nombre] = true
		_push(out, indent, "int %s = %s;" % [nombre, expr])


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


static func _label(arg) -> String:
	var s := str(arg)
	var r := ""
	for i in s.length():
		var c := s[i]
		r += c if (c.is_valid_identifier() or (r != "" and c >= "0" and c <= "9")) else "_"
	if r == "" or (r[0] >= "0" and r[0] <= "9"):
		r = "L_" + r
	return r
