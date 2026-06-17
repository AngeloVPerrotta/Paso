class_name Tema
extends RefCounted

# Paleta ÚNICA del juego. Esta es la única fuente de verdad de color: ni main.gd
# ni robot.gd definen colores propios, solo referencian estos. Para recolorear
# todo el juego, se toca SOLO este archivo.
#
# Identidad cálida y prolija, claramente propia (NO el coral/crema de Claude):
# fondo arena, texto casi negro, primario verde-azulado, éxito verde, detalle ámbar.

# --- Marca ---
const FONDO := Color("f5f2ea")        # arena cálida (base de todo)
const TEXTO := Color("232220")        # casi negro cálido
const PRIMARIO := Color("1c7c74")     # verde-azulado: EL acento (acciones, foco)
const EXITO := Color("6ba368")        # verde calmo: ✓, nivel resuelto, récord
const CALIDO := Color("e3a23a")       # ámbar: detalle/realce (robot, brillos)

# --- Neutros derivados del fondo (grises cálidos de celdas y controles) ---
const PANEL := Color("fcfbf6")        # panel casi blanco (fondo aclarado)
const PANEL_BORDE := Color("e3ddcf")
const CELDA := Color("ece7da")
const CELDA_BORDE := Color("d8d0bf")
const TENUE := Color("8f897d")        # texto/íconos apagados

# --- Derivados de marca ---
const PRIMARIO_TENUE := Color("1c7c74", 0.14)   # fondo de hover/foco sutil
const ERROR := Color("b5564a")        # rojo-arcilla apagado (nunca estridente)

# Velo oscuro cálido para overlays modales (panel C#, confirmaciones, spotlight).
const VELO := Color(0.14, 0.13, 0.11, 0.5)
