class_name GitMini
extends RefCounted

# Mini-git: el MODELO del sandbox de "Aprendé Git" (Capa 2). Lógica pura, sin UI
# —igual que el intérprete del juego, estado→estado, testeable headless—. NO toca
# el juego (intérprete/validador/niveles); es su propio módulo.
#
# Estado:
#   - working dir: archivos con estado (sin_seguir / modificado / preparado / limpio)
#   - staging: los archivos "preparado"
#   - historial local: commits
#   - remoto ("la nube", origin): los commits pusheados
# Soporta el flujo central: init, status, add, commit, push, pull, log, clone.
# (branch/merge quedan para después: agregan mucho estado.)

# Estados de un archivo en el working dir.
const SIN_SEGUIR := "sin_seguir"     # nuevo, git todavía no lo sigue (untracked)
const MODIFICADO := "modificado"     # seguido y cambiado, sin preparar
const PREPARADO := "preparado"       # en el staging (git add)
const LIMPIO := "limpio"             # seguido y sin cambios (commiteado)

var iniciado := false
var archivos := {}                   # nombre -> estado
var commits := []                    # local: [{id, msg}]
var remoto := []                     # nube: [{id, msg}]
var _prox_id := 1


func _init() -> void:
	# El working dir arranca con un par de archivos (todavía sin seguir).
	archivos = {"README.md": SIN_SEGUIR, "hola.c": SIN_SEGUIR}


# --- Entrada de la consola: parsea una línea y la ejecuta ---
func ejecutar(linea: String) -> Dictionary:
	var s := linea.strip_edges()
	if s == "":
		return _ok("")
	var tokens := s.split(" ", false)
	if tokens[0] != "git":
		return _err("Acá los comandos empiezan con «git». Probá: git status")
	if tokens.size() < 2:
		return _err("Te faltó el comando. Probá: git status")
	var sub: String = tokens[1]
	var args := tokens.slice(2)
	match sub:
		"init": return _cmd_init()
		"status": return _cmd_status()
		"add": return _cmd_add(args)
		"commit": return _cmd_commit(s)
		"push": return _cmd_push()
		"pull": return _cmd_pull()
		"log": return _cmd_log()
		"clone": return _cmd_clone()
		_: return _err("«git %s» no lo conozco en este sandbox.\nComandos: init, status, add, commit, push, pull, log, clone." % sub)


# --- Acciones del working dir (las dispara la UI: editar / crear archivos) ---
func editar_archivo(nombre: String) -> void:
	if not archivos.has(nombre):
		archivos[nombre] = SIN_SEGUIR
	elif archivos[nombre] == LIMPIO:
		archivos[nombre] = MODIFICADO
	elif archivos[nombre] == PREPARADO:
		archivos[nombre] = MODIFICADO     # editar algo ya preparado lo vuelve a modificar


func crear_archivo(nombre: String) -> void:
	if not archivos.has(nombre):
		archivos[nombre] = SIN_SEGUIR


# Simula que ALGUIEN MÁS subió un commit a la nube (para poder demostrar pull).
func simular_remoto(msg: String) -> void:
	remoto.append({"id": _prox_id, "msg": msg, "externo": true})
	_prox_id += 1


# --- Consultas para la vista ---
func con_estado(estado: String) -> Array:
	var r := []
	for nombre in archivos:
		if archivos[nombre] == estado:
			r.append(nombre)
	r.sort()
	return r


func adelantados() -> int:        # commits locales que faltan en la nube
	var ids := _ids(remoto)
	var n := 0
	for c in commits:
		if not ids.has(c.id):
			n += 1
	return n


func atrasados() -> int:          # commits en la nube que faltan localmente
	var ids := _ids(commits)
	var n := 0
	for c in remoto:
		if not ids.has(c.id):
			n += 1
	return n


# --- Comandos ---
func _cmd_init() -> Dictionary:
	if iniciado:
		return _ok("Ya era un repositorio git (lo reinicializaste).")
	iniciado = true
	return _ok("Inicializaste un repositorio git vacío en tu-proyecto/.")


func _cmd_status() -> Dictionary:
	if not iniciado:
		return _err("fatal: esto no es un repositorio git.\nProbá: git init")
	var lineas := ["En la rama main"]
	if adelantados() > 0:
		lineas.append("Tu rama está adelantada de origin/main por %d commit(s) (hacé push)." % adelantados())
	if atrasados() > 0:
		lineas.append("Tu rama está atrasada respecto de origin/main por %d commit(s) (hacé pull)." % atrasados())
	var prep := con_estado(PREPARADO)
	var mod := con_estado(MODIFICADO)
	var nue := con_estado(SIN_SEGUIR)
	if not prep.is_empty():
		lineas.append("\nCambios preparados para commit:")
		for n in prep:
			lineas.append("    preparado:   %s" % n)
	if not mod.is_empty():
		lineas.append("\nCambios sin preparar:")
		for n in mod:
			lineas.append("    modificado:  %s" % n)
	if not nue.is_empty():
		lineas.append("\nArchivos sin seguir:")
		for n in nue:
			lineas.append("    %s" % n)
	if prep.is_empty() and mod.is_empty() and nue.is_empty():
		lineas.append("nada para commitear, el árbol de trabajo está limpio")
	return _ok("\n".join(lineas))


func _cmd_add(args: Array) -> Dictionary:
	if not iniciado:
		return _err("fatal: esto no es un repositorio git.\nProbá: git init")
	if args.is_empty():
		return _err("¿Qué agrego? Usá: git add <archivo>  o  git add .")
	var objetivo: String = args[0]
	var preparados := []
	if objetivo == ".":
		for nombre in archivos:
			if archivos[nombre] == SIN_SEGUIR or archivos[nombre] == MODIFICADO:
				archivos[nombre] = PREPARADO
				preparados.append(nombre)
	else:
		if not archivos.has(objetivo):
			return _err("fatal: no existe el archivo «%s»." % objetivo)
		var e: String = archivos[objetivo]
		if e == SIN_SEGUIR or e == MODIFICADO:
			archivos[objetivo] = PREPARADO
			preparados.append(objetivo)
		else:
			return _ok("No hay cambios para preparar en «%s»." % objetivo)
	if preparados.is_empty():
		return _ok("No había nada para preparar.")
	preparados.sort()
	return _ok("Preparaste: %s" % ", ".join(preparados))


func _cmd_commit(linea_completa: String) -> Dictionary:
	if not iniciado:
		return _err("fatal: esto no es un repositorio git.\nProbá: git init")
	var msg := _mensaje_de(linea_completa)
	if msg == "":
		return _err("Faltó el mensaje. Usá: git commit -m \"qué cambiaste\"")
	var prep := con_estado(PREPARADO)
	if prep.is_empty():
		return _err("No hay nada preparado para commitear.\nProbá: git add <archivo>")
	for nombre in prep:
		archivos[nombre] = LIMPIO
	var id := _prox_id
	_prox_id += 1
	commits.append({"id": id, "msg": msg})
	return _ok("[main #%d] %s\n %d archivo(s) commiteado(s)." % [id, msg, prep.size()])


func _cmd_push() -> Dictionary:
	if not iniciado:
		return _err("fatal: esto no es un repositorio git.\nProbá: git init")
	var ids := _ids(remoto)
	var nuevos := []
	for c in commits:
		if not ids.has(c.id):
			nuevos.append(c)
	if nuevos.is_empty():
		return _ok("Ya está todo subido. (nada para hacer push)")
	for c in nuevos:
		remoto.append(c)
	return _ok("Subiste %d commit(s) a la nube (origin/main)." % nuevos.size())


func _cmd_pull() -> Dictionary:
	if not iniciado:
		return _err("fatal: esto no es un repositorio git.\nProbá: git init")
	var ids := _ids(commits)
	var nuevos := []
	for c in remoto:
		if not ids.has(c.id):
			nuevos.append(c)
	if nuevos.is_empty():
		return _ok("Ya estás al día con la nube.")
	for c in nuevos:
		commits.append(c)
	return _ok("Trajiste %d commit(s) de la nube." % nuevos.size())


func _cmd_log() -> Dictionary:
	if not iniciado:
		return _err("fatal: esto no es un repositorio git.\nProbá: git init")
	if commits.is_empty():
		return _ok("Todavía no hay commits. Hacé tu primer commit.")
	var lineas := []
	for i in range(commits.size() - 1, -1, -1):
		lineas.append("commit #%d   %s" % [commits[i].id, commits[i].msg])
	return _ok("\n".join(lineas))


func _cmd_clone() -> Dictionary:
	return _ok("git clone se usa para BAJAR por primera vez un repo que todavía no tenés.\nAcá ya estás trabajando en tu-proyecto/, así que no hace falta. Para traer cambios usá: git pull")


# --- Helpers ---
func _mensaje_de(linea: String) -> String:
	var i := linea.find("-m")
	if i == -1:
		return ""
	var resto := linea.substr(i + 2).strip_edges()
	# Sacar comillas (simples o dobles) si las hay.
	resto = resto.lstrip("\"'").rstrip("\"'").strip_edges()
	return resto


func _ids(arr: Array) -> Dictionary:
	var d := {}
	for c in arr:
		d[c.id] = true
	return d


func _ok(salida: String) -> Dictionary:
	return {"salida": salida, "error": false}


func _err(salida: String) -> Dictionary:
	return {"salida": salida, "error": true}
