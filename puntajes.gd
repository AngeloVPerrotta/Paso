class_name Puntajes
extends RefCounted

# Persistencia local del mejor puntaje del jugador por nivel (y un par de flags
# de UI, como si ya vio el tutorial). Solo local por ahora — el ranking global
# es fase posterior. Es data: no toca el intérprete ni el validador.
#
# Guardamos el doble score del juego (instrucciones y pasos). "Mejor" es
# lexicográfico: primero menos instrucciones, y a igualdad, menos pasos. Es la
# misma intuición de "optimizá tu solución" que premia el género.

const RUTA := "user://paso_puntajes.cfg"
const SEC_MEJOR := "mejor"
const SEC_FLAGS := "flags"


static func _cargar() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(RUTA)            # si no existe, queda vacío (no es error)
	return cfg


# Devuelve {instrucciones, pasos} o null si el nivel todavía no tiene marca.
static func mejor(id: String):
	var cfg := _cargar()
	if not cfg.has_section_key(SEC_MEJOR, id):
		return null
	var v = cfg.get_value(SEC_MEJOR, id)
	if typeof(v) == TYPE_DICTIONARY and v.has("instrucciones") and v.has("pasos"):
		return {"instrucciones": int(v.instrucciones), "pasos": int(v.pasos)}
	return null


# Registra un resultado. Devuelve true si es un NUEVO RÉCORD (mejoró la marca
# anterior, o es la primera vez que se resuelve el nivel).
static func registrar(id: String, instrucciones: int, pasos: int) -> bool:
	var actual = mejor(id)
	var es_record := actual == null or _mejor_que(instrucciones, pasos, actual.instrucciones, actual.pasos)
	if es_record:
		var cfg := _cargar()
		cfg.set_value(SEC_MEJOR, id, {"instrucciones": instrucciones, "pasos": pasos})
		cfg.save(RUTA)
	return es_record


# ¿(i1,p1) es estrictamente mejor que (i2,p2)? Lexicográfico: instrucciones y
# después pasos.
static func _mejor_que(i1: int, p1: int, i2: int, p2: int) -> bool:
	if i1 != i2:
		return i1 < i2
	return p1 < p2


# --- Flags de UI (p. ej. tutorial visto) ---
static func flag(nombre: String, def := false) -> bool:
	var cfg := _cargar()
	return bool(cfg.get_value(SEC_FLAGS, nombre, def))


static func set_flag(nombre: String, valor: bool) -> void:
	var cfg := _cargar()
	cfg.set_value(SEC_FLAGS, nombre, valor)
	cfg.save(RUTA)
