extends Node
## Les outils de développement pilotés par la ligne de commande (voir cli.gd) :
## --shot=<png>@<s>,… captures d'écran, --quit=<s> arrêt programmé, --fps et --debugflash dans la console,
## --inputlog journal des touchers dans user://input.log. Il tourne même pendant la pause.

const Cli = preload("res://scripts/cli.gd")

var main: Node
var shots := []
var quit_at := -1.0
var clock := 0.0
var _fps_tick := 0.0
var _input_log: FileAccess
var _logged := 0


func _init(m: Node) -> void:
	main = m


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	quit_at = Cli.number("--quit", -1.0)
	var s := Cli.value("--shot")
	if s != "":
		for one in s.split(","):
			var kv := one.split("@")
			shots.append({"path": kv[0], "t": float(kv[1])})
	set_process_input(Cli.has("--inputlog"))


func _process(delta: float) -> void:
	clock += delta
	if Cli.has("--fps") and clock - _fps_tick >= 1.0:
		_fps_tick = clock
		print("fps ", Engine.get_frames_per_second())
	for s in shots:
		if not s.has("done") and clock >= s.t:
			s["done"] = true
			get_viewport().get_texture().get_image().save_png(s.path)
			print("shot ", s.path, " at ", snapped(clock, 0.1), "s, ", Engine.get_frames_per_second(), " FPS")
	if Cli.has("--debugflash") and int(clock * 2) != int((clock - delta) * 2):
		print("t=%.1f flash=%s view=%s" % [clock, main.flash.color, "planet" if main.planet else "sgc"])
	if quit_at > 0 and clock >= quit_at:
		get_tree().quit()


func _input(e: InputEvent) -> void:
	if _logged >= 400:
		return
	if e is InputEventScreenTouch or e is InputEventScreenDrag or e is InputEventMouseButton or e is InputEventMagnifyGesture or e is InputEventPanGesture:
		if _input_log == null:
			_input_log = FileAccess.open("user://input.log", FileAccess.WRITE)
			_input_log.store_line("écran %s, fenêtre %s, viewport %s" % [DisplayServer.screen_get_size(), DisplayServer.window_get_size(), get_viewport().get_visible_rect().size])
		_input_log.store_line("%.2f %s" % [clock, e.as_text() if not (e is InputEventScreenTouch or e is InputEventScreenDrag) else "%s idx=%d pos=%s" % [e.get_class(), e.index, e.position]])
		_input_log.flush()
		_logged += 1
