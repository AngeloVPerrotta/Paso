class_name Sfx
extends Node

# Hooks de audio del juego. Bajo esfuerzo / alto impacto: todos los sonidos son
# TONOS SINTÉTICOS generados por código (no se pueden bajar assets en el sandbox).
# Quedan fáciles de reemplazar: si existe un .wav/.ogg en res://assets/sfx/<nombre>,
# se usa ESE en vez del tono sintético. Ver assets/sfx/README.md.
#
# Es cosmético puro: nunca toca el estado de simulación. En headless se desactiva
# solo (no hay salida de audio y no queremos ruido en los tests).

const MIX := 44100

# Nombre lógico -> archivo opcional que lo reemplaza (si está presente).
const ARCHIVOS := {
	"click":    "res://assets/sfx/click",
	"tick":     "res://assets/sfx/tick",
	"win":      "res://assets/sfx/win",
	"fail":     "res://assets/sfx/fail",
	"record":   "res://assets/sfx/record",
	"colocar":  "res://assets/sfx/colocar",
}

var habilitado := true       # false en headless (sin device de audio real)
var silenciado := false      # mute del jugador (persistido); el balbuceo y TODO el audio lo respeta
var _players := {}          # nombre -> AudioStreamPlayer


func _ready() -> void:
	# En headless no hay device real: evitamos ruido en los tests y cualquier
	# rareza del driver dummy.
	if DisplayServer.get_name() == "headless":
		habilitado = false
		return
	silenciado = Puntajes.flag("audio_off", false)   # mute del jugador (persistido en el .cfg)
	_preparar("click",   _tono([880.0], 0.045, 0.28, "seno"))
	_preparar("tick",    _tono([1320.0], 0.035, 0.16, "seno"))
	_preparar("colocar", _secuencia([{"f": 660.0, "d": 0.05, "v": 0.30}, {"f": 990.0, "d": 0.06, "v": 0.26}]))
	_preparar("win",     _secuencia([{"f": 783.99, "d": 0.10, "v": 0.34}, {"f": 1046.5, "d": 0.18, "v": 0.34}]))
	_preparar("fail",    _secuencia([{"f": 440.0, "d": 0.10, "v": 0.22}, {"f": 329.63, "d": 0.16, "v": 0.20}]))
	# Fanfarria de récord: arpegio ascendente cortito y alegre.
	_preparar("record",  _secuencia([
		{"f": 523.25, "d": 0.09, "v": 0.30},
		{"f": 659.25, "d": 0.09, "v": 0.30},
		{"f": 783.99, "d": 0.09, "v": 0.30},
		{"f": 1046.5, "d": 0.22, "v": 0.34},
	]))
	# Balbuceo del robot-tutor: bliplets cortos, agudos y suaves (estilo "personaje que
	# habla"). ~0.4s: acompaña la aparición de la burbuja, no suena todo el rato.
	_preparar("tutor",   _balbuceo())


# --- API pública: los hooks que llama la UI ---
func click() -> void:    _play("click")
func tick() -> void:      _play("tick")
func colocar() -> void:   _play("colocar")
func win() -> void:       _play("win")
func fail() -> void:      _play("fail")
func record() -> void:    _play("record")
func tutor() -> void:     _play("tutor")


# Mute global del jugador, persistido en el .cfg de Puntajes. TODO el audio (incluido el
# balbuceo del tutor) lo respeta porque el gate está en _play.
func set_silenciado(v: bool) -> void:
	silenciado = v
	Puntajes.set_flag("audio_off", v)


func _play(nombre: String) -> void:
	if not habilitado or silenciado:
		return
	var p: AudioStreamPlayer = _players.get(nombre)
	if p:
		p.play()


# Crea el player de un sonido. Si hay un archivo de audio en assets/sfx/ que lo
# reemplace, lo carga; si no, usa el tono sintético `fallback`.
func _preparar(nombre: String, fallback: AudioStream) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = _cargar_reemplazo(nombre)
	if p.stream == null:
		p.stream = fallback
	p.volume_db = -4.0
	add_child(p)
	_players[nombre] = p


func _cargar_reemplazo(nombre: String) -> AudioStream:
	var base: String = ARCHIVOS.get(nombre, "")
	if base == "":
		return null
	for ext in [".wav", ".ogg", ".mp3"]:
		if ResourceLoader.exists(base + ext):
			var r = load(base + ext)
			if r is AudioStream:
				return r
	return null


# --- Síntesis ---

# Un tono: suma de senos (uno o varios = acorde) con envolvente attack/decay y
# fade-out al final para que no "clickee".
func _tono(freqs: Array, dur: float, vol: float, _forma := "seno") -> AudioStreamWAV:
	return _construir([{"freqs": freqs, "d": dur, "v": vol}])


# Una secuencia de notas (cada una {f|freqs, d, v}) concatenadas en un solo stream.
func _secuencia(notas: Array) -> AudioStreamWAV:
	var segs := []
	for nota in notas:
		var freqs: Array = nota.get("freqs", [nota.get("f", 440.0)])
		segs.append({"freqs": freqs, "d": nota.get("d", 0.1), "v": nota.get("v", 0.3)})
	return _construir(segs)


# Balbuceo "personaje que habla": 5 bliplets agudos y suaves con micro-silencios entre
# medio (se leen discretos, no un warble continuo). Coherente con el robot: claro y
# juguetón, nunca chillón.
func _balbuceo() -> AudioStreamWAV:
	var notas := []
	var pitches := [1180.0, 1320.0, 1245.0, 1410.0, 1300.0]
	for i in pitches.size():
		notas.append({"f": pitches[i], "d": 0.058, "v": 0.17})
		if i < pitches.size() - 1:
			notas.append({"f": 0.0, "d": 0.022, "v": 0.0})   # micro silencio entre blips
	return _secuencia(notas)


func _construir(segs: Array) -> AudioStreamWAV:
	var total := 0
	for s in segs:
		total += int(s.d * MIX)
	var bytes := PackedByteArray()
	bytes.resize(total * 2)

	var pos := 0
	for s in segs:
		var n := int(s.d * MIX)
		var freqs: Array = s.freqs
		var vol: float = s.v
		var atk := 0.006                       # attack corto (6ms)
		for i in n:
			var t := float(i) / MIX
			# Envolvente: rampa de ataque, luego caída exponencial.
			var env := minf(t / atk, 1.0) * exp(-3.5 * t)
			# Fade-out de los últimos 8ms para cerrar en cero.
			var resto := float(n - i) / MIX
			if resto < 0.008:
				env *= resto / 0.008
			var muestra := 0.0
			for f in freqs:
				muestra += sin(TAU * f * t)
			muestra = muestra / float(freqs.size()) * env * vol
			var v := int(clampf(muestra, -1.0, 1.0) * 32767.0)
			bytes.encode_s16((pos + i) * 2, v)
		pos += n

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX
	stream.stereo = false
	stream.data = bytes
	return stream
