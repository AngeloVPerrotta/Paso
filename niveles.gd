class_name Niveles
extends RefCounted

# Loader de niveles data-driven. Lee un JSON de res://niveles/ y devuelve una
# estructura TIPADA (Nivel + Caso). No corre nada: solo parsea y normaliza.
# La validacion/scoring vive en validador.gd, encima del Interprete.

# Un caso de prueba: una entrada y la salida que debe producir.
class Caso:
	var entrada: Array              # ints
	var salida_esperada: Array      # ints


# Un nivel completo, tal como lo ve el jugador y el validador.
class Nivel:
	var id: String
	var nombre: String
	var descripcion: String
	var slots: int
	var instrucciones_permitidas: Array   # nombres de op (String)
	var casos: Array                       # de Caso
	var par_instrucciones: int             # meta de score (placeholder)
	var par_pasos: int                     # meta de score (placeholder)


# Carga por id: res://niveles/<id>.json
static func cargar(id: String) -> Nivel:
	return cargar_archivo("res://niveles/%s.json" % id)


static func cargar_archivo(ruta: String) -> Nivel:
	if not FileAccess.file_exists(ruta):
		push_error("Nivel no encontrado: %s" % ruta)
		return null
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		push_error("No se pudo abrir el nivel: %s" % ruta)
		return null
	var txt := f.get_as_text()
	f.close()
	return desde_json(txt)


static func desde_json(txt: String) -> Nivel:
	var data = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("JSON de nivel invalido (se esperaba un objeto).")
		return null
	return desde_dict(data)


static func desde_dict(data: Dictionary) -> Nivel:
	var n := Nivel.new()
	n.id = str(data.get("id", ""))
	n.nombre = str(data.get("nombre", ""))
	n.descripcion = str(data.get("descripcion", ""))
	n.slots = _entero(data.get("slots", 0))

	# El loader es tolerante: ante un JSON mal formado degrada con defaults sensatos
	# en vez de romper, asi un nivel autorado a mano con un typo no tira un error cripico.
	var permitidas = data.get("instrucciones_permitidas", [])
	n.instrucciones_permitidas = permitidas if typeof(permitidas) == TYPE_ARRAY else []

	n.casos = []
	var casos_raw = data.get("casos", [])
	if typeof(casos_raw) == TYPE_ARRAY:
		for c in casos_raw:
			if typeof(c) != TYPE_DICTIONARY:
				continue
			var caso := Caso.new()
			# JSON no distingue int/float: coercionamos a int (el juego es entero).
			caso.entrada = _a_enteros(c.get("entrada", []))
			caso.salida_esperada = _a_enteros(c.get("salida_esperada", []))
			n.casos.append(caso)

	var par = data.get("par", {})
	if typeof(par) != TYPE_DICTIONARY:
		par = {}
	n.par_instrucciones = _entero(par.get("instrucciones", 0))
	n.par_pasos = _entero(par.get("pasos", 0))
	return n


# Lista los ids de nivel disponibles en res://niveles/ (sin extension).
# Excluye los archivos de orden (orden / orden_avanzado), que no son niveles.
static func listar() -> Array:
	var ids := []
	var d := DirAccess.open("res://niveles")
	if d:
		for archivo in d.get_files():
			var base := archivo.get_basename()
			if archivo.ends_with(".json") and base != "orden" and base != "orden_avanzado":
				ids.append(base)
	ids.sort()
	return ids


# Niveles avanzados (aditivos, solo track C#): lista en res://niveles/orden_avanzado.json.
static func avanzados() -> Array:
	var ruta := "res://niveles/orden_avanzado.json"
	if FileAccess.file_exists(ruta):
		var f := FileAccess.open(ruta, FileAccess.READ)
		if f:
			var data = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(data) == TYPE_ARRAY:
				var ids := []
				for x in data:
					ids.append(str(x))
				return ids
	return []


# Orden de juego según el track: "c" = los 12 fundamentos; "csharp" = los 12 + avanzados.
static func orden_track(track: String) -> Array:
	var base := orden()
	if track == "csharp":
		return base + avanzados()
	return base


# Orden de juego curado (data): lista de ids en res://niveles/orden.json.
# Si falta o esta mal, cae a listar() (orden alfabetico) como fallback.
static func orden() -> Array:
	var ruta := "res://niveles/orden.json"
	if FileAccess.file_exists(ruta):
		var f := FileAccess.open(ruta, FileAccess.READ)
		if f:
			var data = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(data) == TYPE_ARRAY and not data.is_empty():
				var ids := []
				for x in data:
					ids.append(str(x))
				return ids
	push_warning("orden.json ausente o invalido; usando orden alfabetico.")
	return listar()


static func _a_enteros(arr) -> Array:
	var salida := []
	if typeof(arr) != TYPE_ARRAY:
		return salida          # entrada/salida null o de tipo raro -> lista vacia
	for v in arr:
		salida.append(_entero(v))
	return salida


# Coerciona a int de forma segura (numeros de JSON vienen como int o float).
static func _entero(v, def := 0) -> int:
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return int(v)
	return def
