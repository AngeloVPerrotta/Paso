class_name Tema
extends RefCounted

# Paleta ÚNICA del juego. Esta es la única fuente de verdad de color: ni main.gd
# ni robot.gd definen colores propios, solo referencian estos. Para recolorear
# todo el juego, se toca SOLO este archivo.
#
# Identidad cálida y prolija, claramente propia (NO el coral/crema de Claude):
# fondo arena, texto casi negro, primario verde-azulado, éxito verde, detalle ámbar.
#
# TEMA (claro/oscuro): los colores son `static var` mutables, no `const`. Arrancan
# en "claro" (los valores históricos, idénticos a antes) y se swapean con aplicar().
# Como TODO el juego lee estos campos, cambiar de tema es cambiar esta paleta y
# reconstruir la escena (main.gd lo hace con reload_current_scene). Los `const … :=
# Tema.X` que antes capturaban estos colores pasaron a `var` (main.gd, robot.gd):
# se evalúan al instanciar, después de aplicar(), así toman la paleta activa.

# --- Marca (paleta ACTIVA, mutable; default = claro) ---
static var FONDO := Color("f5f2ea")        # arena cálida (base de todo)
static var TEXTO := Color("232220")        # casi negro cálido
static var PRIMARIO := Color("1c7c74")     # verde-azulado: EL acento (acciones, foco)
static var EXITO := Color("6ba368")        # verde calmo: ✓, nivel resuelto, récord
static var CALIDO := Color("e3a23a")       # ámbar: detalle/realce (robot, brillos)

# --- Neutros derivados del fondo (grises cálidos de celdas y controles) ---
static var PANEL := Color("fcfbf6")        # panel casi blanco (fondo aclarado)
static var PANEL_BORDE := Color("e3ddcf")
static var CELDA := Color("ece7da")
static var CELDA_BORDE := Color("d8d0bf")
static var TENUE := Color("8f897d")        # texto/íconos apagados

# --- Derivados de marca ---
static var PRIMARIO_TENUE := Color("1c7c74", 0.14)   # fondo de hover/foco sutil
static var ERROR := Color("b5564a")        # rojo-arcilla apagado (nunca estridente)

# --- Consola de git: SIEMPRE terminal oscura, en cualquier tema. ESTABLES (const):
# NO dependen de la paleta activa, así el swap claro↔oscuro no invierte fondo/texto
# (bug previo: la consola usaba TEXTO como fondo y FONDO como texto, que se daban
# vuelta en oscuro y la dejaban clara con acentos lavados). Las terminales son
# oscuras: mantenerlas fijas es lo correcto y garantiza contraste AA. Los valores
# son los del terminal en tema claro, así el claro queda idéntico a antes.
const CONSOLA_FONDO := Color("232220")   # superficie oscura del terminal
const CONSOLA_TEXTO := Color("f5f2ea")   # texto normal / salida (claro sobre el fondo)
const CONSOLA_ECO := Color("82b7b3")     # eco del comando ($ …): teal claro
const CONSOLA_ERROR := Color("cf9189")   # errores: rojo claro
const CONSOLA_ACENTO := Color("e3a23a")  # info / realce: ámbar

# Velo oscuro cálido para overlays modales (panel C#, confirmaciones, spotlight).
static var VELO := Color(0.14, 0.13, 0.11, 0.5)


# --- Variantes de paleta. Cada una define los 11 colores base; el resto se deriva. ---
# "claro" = la identidad histórica. "oscuro" = la misma identidad de noche: fondo
# casi-negro cálido, texto arena, teal/verde/ámbar realzados para contraste sobre oscuro.
const _CLARO := {
	"FONDO": "f5f2ea", "TEXTO": "232220", "PRIMARIO": "1c7c74",
	"EXITO": "6ba368", "CALIDO": "e3a23a", "PANEL": "fcfbf6",
	"PANEL_BORDE": "e3ddcf", "CELDA": "ece7da", "CELDA_BORDE": "d8d0bf",
	"TENUE": "8f897d", "ERROR": "b5564a",
}
const _OSCURO := {
	"FONDO": "26241f", "TEXTO": "f2efe6", "PRIMARIO": "3aa79d",
	"EXITO": "82c077", "CALIDO": "e9ad48", "PANEL": "302d28",
	"PANEL_BORDE": "47433b", "CELDA": "35322c", "CELDA_BORDE": "4d483f",
	"TENUE": "9c968a", "ERROR": "d4776a",
}

const TEMAS := ["claro", "oscuro"]
static var _actual := "claro"


# Tema activo ("claro" | "oscuro").
static func actual() -> String:
	return _actual


# Swapea la paleta activa al tema pedido (default "claro" si no se reconoce).
# Tras llamarla hay que reconstruir lo ya dibujado: los widgets ya creados tienen
# sus colores horneados. main.gd lo resuelve recargando la escena.
static func aplicar(nombre: String) -> void:
	var n := nombre if nombre in TEMAS else "claro"
	_actual = n
	var p: Dictionary = _OSCURO if n == "oscuro" else _CLARO
	FONDO = Color(p.FONDO)
	TEXTO = Color(p.TEXTO)
	PRIMARIO = Color(p.PRIMARIO)
	EXITO = Color(p.EXITO)
	CALIDO = Color(p.CALIDO)
	PANEL = Color(p.PANEL)
	PANEL_BORDE = Color(p.PANEL_BORDE)
	CELDA = Color(p.CELDA)
	CELDA_BORDE = Color(p.CELDA_BORDE)
	TENUE = Color(p.TENUE)
	ERROR = Color(p.ERROR)
	# Derivados (alpha / lerp: no expresables como literal de paleta):
	PRIMARIO_TENUE = Color(PRIMARIO, 0.18 if n == "oscuro" else 0.14)
	VELO = Color(0.0, 0.0, 0.0, 0.62) if n == "oscuro" else Color(0.14, 0.13, 0.11, 0.5)
