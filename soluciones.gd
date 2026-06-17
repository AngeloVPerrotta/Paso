class_name Soluciones
extends RefCounted

# Soluciones de referencia de cada nivel. Sirven para:
#   - verificar en headless que cada nivel es resoluble,
#   - fijar los `par` de cada JSON con los numeros reales que mide el validador.
# El jugador construye su propio programa con el editor; esto es la vara.
# Los saltos se escriben por NOMBRE de etiqueta; resolver_etiquetas() los resuelve.

const POR_ID := {
	"b1_eco": [
		["TOMAR", null], ["SOLTAR", null],
		["TOMAR", null], ["SOLTAR", null],
		["TOMAR", null], ["SOLTAR", null],
	],
	"b2_invertir_par": [
		["TOMAR", null],
		["GUARDAR", 0],
		["TOMAR", null],
		["SOLTAR", null],
		["COPIAR", 0],
		["SOLTAR", null],
	],
	"b3_eco_infinito": [
		["ETIQUETA", "inicio"],
		["TOMAR", null],
		["SOLTAR", null],
		["SALTAR", "inicio"],
	],
	"b4_filtrar_ceros": [
		["ETIQUETA", "inicio"],
		["TOMAR", null],
		["SALTAR_SI_CERO", "inicio"],
		["SOLTAR", null],
		["SALTAR", "inicio"],
	],

	# --- Niveles nuevos ---

	# Duplicar: entra A -> sale A, A. (guarda A, lo suelta dos veces)
	"duplicar": [
		["TOMAR", null],
		["GUARDAR", 0],
		["SOLTAR", null],
		["COPIAR", 0],
		["SOLTAR", null],
	],

	# Invertir el trio: entran A,B,C -> salen C,B,A. (dos slots para A y B)
	"invertir_trio": [
		["TOMAR", null],
		["GUARDAR", 0],
		["TOMAR", null],
		["GUARDAR", 1],
		["TOMAR", null],
		["SOLTAR", null],
		["COPIAR", 1],
		["SOLTAR", null],
		["COPIAR", 0],
		["SOLTAR", null],
	],

	# Sumar el par: entran A,B -> sale A+B.
	"sumar_par": [
		["TOMAR", null],
		["GUARDAR", 0],
		["TOMAR", null],
		["SUMAR", 0],
		["SOLTAR", null],
	],

	# Restar el par: entran A,B -> sale A-B. (RESTAR hace mano - slot, asi que A en mano, B en slot)
	"restar_par": [
		["TOMAR", null],
		["GUARDAR", 0],
		["TOMAR", null],
		["GUARDAR", 1],
		["COPIAR", 0],
		["RESTAR", 1],
		["SOLTAR", null],
	],

	# Duplicar la cola: cada valor de la cola sale dos veces. (loop del duplicar)
	"duplicar_cola": [
		["ETIQUETA", "inicio"],
		["TOMAR", null],
		["GUARDAR", 0],
		["SOLTAR", null],
		["COPIAR", 0],
		["SOLTAR", null],
		["SALTAR", "inicio"],
	],

	# Sumar de a pares: por cada par (a,b) de la cola, sale a+b. (loop del sumar_par)
	"sumar_pares": [
		["ETIQUETA", "inicio"],
		["TOMAR", null],
		["GUARDAR", 0],
		["TOMAR", null],
		["SUMAR", 0],
		["SOLTAR", null],
		["SALTAR", "inicio"],
	],

	# Cortar en el cero: saca valores hasta toparse un 0; al 0 no lo saca, frena.
	"cortar_en_cero": [
		["ETIQUETA", "inicio"],
		["TOMAR", null],
		["SALTAR_SI_CERO", "fin"],
		["SOLTAR", null],
		["SALTAR", "inicio"],
		["ETIQUETA", "fin"],
	],

	# Pares iguales: la cola viene de a pares; si a==b saca uno, si no descarta el par.
	# a==b  <=>  b-a==0  (RESTAR hace mano-slot: b en mano, a en slot 0).
	"pares_iguales": [
		["ETIQUETA", "inicio"],
		["TOMAR", null],
		["GUARDAR", 0],
		["TOMAR", null],
		["RESTAR", 0],
		["SALTAR_SI_CERO", "iguales"],
		["SALTAR", "inicio"],
		["ETIQUETA", "iguales"],
		["COPIAR", 0],
		["SOLTAR", null],
		["SALTAR", "inicio"],
	],

	# --- Niveles avanzados (track C#) ---

	# Sumar el trío: por cada (a,b,c) sale a+b+c. (acumula en slot 0)
	"sumar_trio": [
		["ETIQUETA", "inicio"],
		["TOMAR", null], ["GUARDAR", 0],
		["TOMAR", null], ["SUMAR", 0], ["GUARDAR", 0],
		["TOMAR", null], ["SUMAR", 0],
		["SOLTAR", null],
		["SALTAR", "inicio"],
	],

	# Restar el trío: por cada (a,b,c) sale a-b-c. (a,b,c en slots 0,1,2)
	"restar_trio": [
		["ETIQUETA", "inicio"],
		["TOMAR", null], ["GUARDAR", 0],
		["TOMAR", null], ["GUARDAR", 1],
		["TOMAR", null], ["GUARDAR", 2],
		["COPIAR", 0], ["RESTAR", 1], ["RESTAR", 2],
		["SOLTAR", null],
		["SALTAR", "inicio"],
	],

	# Invertir el cuarteto: por cada (a,b,c,d) salen d,c,b,a. (a,b,c en slots 0,1,2; d en mano)
	"invertir_cuarteto": [
		["ETIQUETA", "inicio"],
		["TOMAR", null], ["GUARDAR", 0],
		["TOMAR", null], ["GUARDAR", 1],
		["TOMAR", null], ["GUARDAR", 2],
		["TOMAR", null], ["SOLTAR", null],
		["COPIAR", 2], ["SOLTAR", null],
		["COPIAR", 1], ["SOLTAR", null],
		["COPIAR", 0], ["SOLTAR", null],
		["SALTAR", "inicio"],
	],

	# Filtrar y duplicar: descarta ceros; cada distinto de cero sale dos veces.
	"filtrar_duplicar": [
		["ETIQUETA", "inicio"],
		["TOMAR", null],
		["SALTAR_SI_CERO", "inicio"],
		["GUARDAR", 0],
		["SOLTAR", null],
		["COPIAR", 0],
		["SOLTAR", null],
		["SALTAR", "inicio"],
	],

	# Pares iguales, doble: si a==b saca el valor dos veces; si no, descarta el par.
	"pares_iguales_doble": [
		["ETIQUETA", "inicio"],
		["TOMAR", null],
		["GUARDAR", 0],
		["TOMAR", null],
		["RESTAR", 0],
		["SALTAR_SI_CERO", "iguales"],
		["SALTAR", "inicio"],
		["ETIQUETA", "iguales"],
		["COPIAR", 0], ["SOLTAR", null],
		["COPIAR", 0], ["SOLTAR", null],
		["SALTAR", "inicio"],
	],
}


static func para(id: String) -> Array:
	return POR_ID.get(id, []).duplicate(true)
