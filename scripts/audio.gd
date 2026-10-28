extends Node
## Le son (autoload « Audio ») : les bruitages ponctuels, les boucles (anneau, horizon, générique)
## et les bus Musique et Effets que règle le menu des options.

const SOUNDS := ["dial", "lock", "kawoosh", "travel", "iris", "alarm", "close", "press", "staff", "gun", "zat", "boom",
	"hurt", "heal", "levelup", "victory", "defeat", "found", "rings", "glider",
	"iris_close", "asgard", "horizon", "theme", "dhd", "kree", "lock_in"]
const MUSIC := ["theme"]
const BUS_MUSIC := "Musique"
const BUS_SFX := "Effets"

var _streams := {}
var _loops := {}
var _background := false
var _mute_background := true
var _master_silent := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in [BUS_MUSIC, BUS_SFX]:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	for n in SOUNDS:
		var path := ProjectSettings.globalize_path("res://assets/sfx/%s.wav" % n)
		var st := AudioStreamWAV.load_from_file(path)
		if st:
			_streams[n] = st
		else:
			push_warning("Son introuvable : %s" % path)


func set_background_mute(enabled: bool) -> void:
	_mute_background = enabled
	_update_master_mute()


func _update_master_mute() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), _master_silent or (_background and _mute_background))


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_background = true
		_update_master_mute()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		_background = false
		_update_master_mute()


## Volume linéaire (0 à 1) d'un bus : "Master", BUS_MUSIC ou BUS_SFX
func set_volume(bus: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	if bus == "Master":
		_master_silent = linear <= 0.0
		_update_master_mute()
	else:
		AudioServer.set_bus_mute(i, linear <= 0.0)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.01)))


func _bus(n: String) -> String:
	return BUS_MUSIC if n in MUSIC else BUS_SFX


## Un bruitage ponctuel ; il joue même pendant la pause (boutons du menu)
func play(n: String, volume_db: float = 0.0) -> void:
	if not _streams.has(n):
		return
	var p := AudioStreamPlayer.new()
	p.stream = _streams[n]
	p.volume_db = volume_db
	p.bus = _bus(n)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


## Un son en boucle, arrêté par loop_stop. Le générique continue pendant la pause ;
## l'anneau et l'horizon s'arrêtent avec le jeu.
func loop_play(n: String, db: float = 0.0) -> void:
	loop_stop(n, 0.0)
	if not _streams.has(n):
		return
	var st := (_streams[n] as AudioStreamWAV).duplicate() as AudioStreamWAV
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = st.data.size() / (2 if st.stereo else 1) / 2
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.volume_db = db
	p.bus = _bus(n)
	p.process_mode = Node.PROCESS_MODE_ALWAYS if n in MUSIC else Node.PROCESS_MODE_PAUSABLE
	add_child(p)
	p.play()
	_loops[n] = p


func loop_stop(n: String, fade: float = 0.3) -> void:
	if not _loops.has(n):
		return
	var p: AudioStreamPlayer = _loops[n]
	_loops.erase(n)
	if not is_instance_valid(p):
		return
	if fade <= 0.0:
		p.queue_free()
		return
	var tw := p.create_tween()
	tw.tween_property(p, "volume_db", -45.0, fade)
	tw.tween_callback(p.queue_free)
