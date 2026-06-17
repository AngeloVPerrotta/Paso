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

	# --- Guards: todos los comandos que requieren repo fallan antes de init ---
	var g0 := GitMini.new()
	assert(g0.ejecutar("git add .").error, "add sin repo: error")
	assert(g0.ejecutar("git commit -m \"x\"").error, "commit sin repo: error")
	assert(g0.ejecutar("git push").error, "push sin repo: error")
	assert(g0.ejecutar("git pull").error, "pull sin repo: error")
	assert(g0.ejecutar("git log").error, "log sin repo: error")
	assert(not g0.ejecutar("git clone").error, "clone NO requiere repo (informativo)")

	# --- add sin argumentos (repo iniciado): pide un archivo, no crashea ---
	assert(g.ejecutar("git add").error, "add sin argumentos debería pedir un archivo")

	# --- add . con el working dir limpio: no-op ---
	r = g.ejecutar("git add .")
	assert(not r.error and r.salida.contains("nada para preparar"), "add . con todo limpio es no-op")

	# --- MUST-FIX: push divergente (non-fast-forward) se RECHAZA ---
	g.simular_remoto("commit de un compañero")          # la nube se adelanta
	g.editar_archivo("README.md")
	g.ejecutar("git add README.md")
	g.ejecutar("git commit -m \"mío\"")                  # ahora local Y nube divergieron
	assert(g.adelantados() > 0 and g.atrasados() > 0, "debería quedar divergente")
	r = g.ejecutar("git push")
	assert(r.error and r.salida.contains("RECHAZADO"), "push divergente debe rechazarse (non-fast-forward)")
	print("push divergente -> ", r.salida.split("\n")[0])
	r = g.ejecutar("git pull")
	assert(not r.error and g.atrasados() == 0, "pull pone al día tras el rechazo")
	r = g.ejecutar("git push")
	assert(not r.error and g.adelantados() == 0 and g.atrasados() == 0, "tras pull+push: sincronizado")

	# --- push sin novedades: no-op idempotente (no duplica) ---
	var n_remoto := g.remoto.size()
	r = g.ejecutar("git push")
	assert(not r.error and r.salida.contains("todo subido") and g.remoto.size() == n_remoto, "push sin novedades no duplica ni falla")

	# --- re-init: no falla y NO resetea el estado ---
	var nc := g.commits.size()
	var na := g.archivos.size()
	r = g.ejecutar("git init")
	assert(not r.error and r.salida.contains("Ya era un repositorio") and g.iniciado, "re-init no debe fallar")
	assert(g.commits.size() == nc and g.archivos.size() == na, "re-init no debe resetear estado")

	# --- MUST-FIX: parseo del mensaje (-m / --message como TOKEN, no substring) ---
	var gm := GitMini.new()
	gm.ejecutar("git init")
	gm.ejecutar("git add .")
	gm.ejecutar("git commit --message=\"forma larga\"")
	assert(gm.commits.size() == 1 and gm.commits[0].msg == "forma larga", "--message= no debe guardar basura tipo «essage=»")
	gm.editar_archivo("README.md"); gm.ejecutar("git add README.md")
	gm.ejecutar("git commit -m \"arreglo el login\"")
	assert(gm.commits[gm.commits.size() - 1].msg == "arreglo el login", "-m con espacios conserva el mensaje entero")
	gm.editar_archivo("README.md"); gm.ejecutar("git add README.md")
	gm.ejecutar("git commit -m \"v2''\"")
	assert(gm.commits[gm.commits.size() - 1].msg == "v2''", "no se comen las comillas internas: solo un par envolvente")
	gm.editar_archivo("README.md"); gm.ejecutar("git add README.md")
	gm.ejecutar("git commit -m \"viejo\" -m \"nuevo\"")
	assert(gm.commits[gm.commits.size() - 1].msg == "nuevo", "con dos -m gana el último (parser por posición de token, como git)")

	# --- add de un archivo ya limpio (sin cambios): no-op, no lo re-prepara ---
	r = gm.ejecutar("git add README.md")
	assert(not r.error and r.salida.contains("No hay cambios") and gm.archivos["README.md"] == GitMini.LIMPIO, "add de archivo limpio es no-op")

	# --- commit con -m válido pero staging vacío: falla por staging, no por mensaje ---
	r = gm.ejecutar("git commit -m \"sin nada\"")
	assert(r.error and r.salida.contains("nada preparado"), "commit con -m pero sin staging debe fallar por staging vacío")

	# --- log en un repo recién iniciado (sin commits): informa, no falla ---
	var g2 := GitMini.new()
	g2.ejecutar("git init")
	r = g2.ejecutar("git log")
	assert(not r.error and r.salida.contains("Todavía no hay commits"), "log sin commits informa, no falla")

	# --- robustez del tokenizador: línea vacía, espacios extra, case-sensitive ---
	var gc := GitMini.new()
	gc.ejecutar("git init")
	assert(not gc.ejecutar("").error and gc.ejecutar("").salida == "", "línea vacía es no-op")
	assert(not gc.ejecutar("  git   status  ").error, "espacios extra se toleran")
	assert(gc.ejecutar("git INIT").error, "el subcomando es case-sensitive")

	print("OK: el modelo mini-git simula el flujo de git correctamente")
	quit()
