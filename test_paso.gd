extends SceneTree

# Corre el puzzle "Invertir el par" sin UI, para probar la simulacion sola.
#   godot --headless --script test_paso.gd
# Esperado:  salida: [3, 7]   y   OK: invertir el par anda

func _init() -> void:
	# entran A=7, B=3  ->  debe salir [3, 7]
	var programa := [
		["TOMAR", null],
		["GUARDAR", 0],
		["TOMAR", null],
		["SOLTAR", null],
		["COPIAR", 0],
		["SOLTAR", null],
	]
	var estado := Interprete.correr([7, 3], 1, programa)
	print("salida: ", estado.salida)
	assert(estado.salida == [3, 7], "El swap fallo")
	print("OK: invertir el par anda")
	quit()
