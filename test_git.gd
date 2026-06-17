extends SceneTree

# Verificación headless del MODELO mini-git (git_mini.gd), sin UI. Recorre el flujo
# central (init → add → commit → push → cambio → commit → push → pull) y los casos
# de error, asertando las transiciones de estado y la salida.
#   godot --headless --script test_git.gd

func _initialize() -> void:
	var g := GitMini.new()

	# Working dir inicial: dos archivos sin seguir.
	assert(g.con_estado(GitMini.SIN_SEGUIR).size() == 2, "deberían arrancar 2 archivos sin seguir")

	# status antes de init -> error amable.
	var r = g.ejecutar("git status")
	assert(r.error, "status sin repo debería ser error")
	print("status sin init -> ", r.salida.split("\n")[0])

	# init.
	r = g.ejecutar("git init")
	assert(not r.error and g.iniciado, "git init debería iniciar el repo")

	# status: muestra los sin seguir.
	r = g.ejecutar("git status")
	assert(not r.error and r.salida.contains("README.md"), "status debería listar README.md")

	# add un archivo -> preparado.
	r = g.ejecutar("git add README.md")
	assert(not r.error and g.archivos["README.md"] == GitMini.PREPARADO, "add debería preparar README.md")

	# add . -> prepara el resto.
	r = g.ejecutar("git add .")
	assert(g.con_estado(GitMini.PREPARADO).size() == 2, "git add . debería preparar todo")

	# commit sin -m -> error.
	r = g.ejecutar("git commit")
	assert(r.error, "commit sin mensaje debería fallar")

	# commit con mensaje -> 1 commit, archivos limpios.
	r = g.ejecutar("git commit -m \"primer commit\"")
	assert(not r.error and g.commits.size() == 1, "debería haber 1 commit")
	assert(g.con_estado(GitMini.LIMPIO).size() == 2, "tras commit los archivos quedan limpios")
	assert(g.con_estado(GitMini.PREPARADO).is_empty(), "el staging queda vacío tras commit")
	print("commit -> ", r.salida.split("\n")[0])

	# adelantado respecto del remoto; push lo sube.
	assert(g.adelantados() == 1, "debería estar adelantado 1 antes de push")
	r = g.ejecutar("git push")
	assert(not r.error and g.remoto.size() == 1 and g.adelantados() == 0, "push debería subir el commit")

	# editar un archivo limpio -> modificado.
	g.editar_archivo("README.md")
	assert(g.archivos["README.md"] == GitMini.MODIFICADO, "editar debería marcar modificado")

	# preparar + commitear el cambio.
	g.ejecutar("git add README.md")
	r = g.ejecutar("git commit -m \"segundo\"")
	assert(g.commits.size() == 2, "debería haber 2 commits")
	r = g.ejecutar("git push")
	assert(g.remoto.size() == 2, "push debería subir el 2do commit")

	# pull sin novedades -> al día.
	r = g.ejecutar("git pull")
	assert(not r.error and r.salida.contains("al día"), "pull sin novedades: al día")

	# alguien sube algo a la nube -> atrasado; pull lo trae.
	g.simular_remoto("cambio de un compañero")
	assert(g.atrasados() == 1, "debería estar atrasado 1 tras un commit remoto")
	r = g.ejecutar("git pull")
	assert(not r.error and g.commits.size() == 3 and g.atrasados() == 0, "pull debería traer el commit remoto")
	print("pull -> ", r.salida)

	# log.
	r = g.ejecutar("git log")
	assert(not r.error and r.salida.contains("commit #"), "log debería listar commits")

	# --- Errores amables ---
	assert(g.ejecutar("git banana").error, "comando desconocido debería ser error")
	assert(g.ejecutar("ls").error, "lo que no empieza con git debería ser error")
	assert(g.ejecutar("git add noexiste.txt").error, "add de archivo inexistente debería ser error")
	assert(not g.ejecutar("git clone").error, "clone debería dar un mensaje informativo (no error)")

	print("OK: el modelo mini-git simula el flujo de git correctamente")
	quit()
