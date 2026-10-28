extends Node
## Les réglages (autoload « Settings ») : décrits une seule fois dans SCHEMA, d'où découlent
## le menu des options, l'enregistrement (user://settings.cfg) et leur application au moteur.
## Les scènes se signalent par groupes : "sun" pour les lumières qui projettent des ombres,
## "world_env" pour les WorldEnvironment (halo).

const Cli = preload("res://scripts/cli.gd")
const Audio_ = preload("res://scripts/audio.gd")

## Variable pour que les tests (dev/tests.gd) écrivent ailleurs que dans les vrais réglages
var path := "user://settings.cfg"
const LEGACY_PATH := "user://settings.json"

signal changed(key: String)

const TABS := [["display", "AFFICHAGE"], ["graphics", "GRAPHISMES"], ["audio", "SON"], ["game", "JEU"]]

## kind : "choice" (opts = [[libellé, valeur], …]), "range" (min, max, step, fmt) ou "bool"
## when : [clé, valeur] — le réglage n'a d'effet (et n'est modifiable) que dans ce cas
const SCHEMA := [
	{"key": "window_mode", "tab": "display", "label": "Mode d'affichage", "kind": "choice", "def": "fullscreen",
		"opts": [["Plein écran", "fullscreen"], ["Fenêtré", "windowed"]],
		"tip": "Fenêtré : utile sur ordinateur. Sur le téléphone, gardez le plein écran."},
	{"key": "resolution", "tab": "display", "label": "Taille de la fenêtre", "kind": "choice", "def": "1600x900",
		"opts": [["1280 × 720", "1280x720"], ["1600 × 900", "1600x900"], ["1920 × 1080", "1920x1080"], ["2560 × 1440", "2560x1440"]],
		"when": ["window_mode", "windowed"], "tip": "En mode fenêtré seulement."},
	{"key": "render_scale", "tab": "display", "label": "Résolution 3D", "kind": "range", "def": 60, "min": 40, "max": 100, "step": 5, "fmt": "%d %%",
		"tip": "La définition de l'image 3D par rapport à l'écran. Plus bas : plus fluide, plus flou. L'interface reste nette."},
	{"key": "upscaler", "tab": "display", "label": "Mise à l'échelle", "kind": "choice", "def": "bilinear",
		"opts": [["Bilinéaire", "bilinear"], ["AMD FSR 1.0", "fsr"]],
		"tip": "FSR nécessite le moteur Forward+. Avec le rendu mobile, le filtrage bilinéaire est utilisé."},
	{"key": "vsync", "tab": "display", "label": "Synchronisation verticale", "kind": "bool", "def": true,
		"tip": "Évite les déchirures d'image."},
	{"key": "max_fps", "tab": "display", "label": "Images par seconde max.", "kind": "choice", "def": 0,
		"opts": [["30", 30], ["60", 60], ["90", 90], ["120", 120], ["Illimité", 0]],
		"tip": "30 économise la batterie et garde le téléphone au frais."},
	{"key": "ui_scale", "tab": "display", "label": "Taille de l'interface", "kind": "range", "def": 100, "min": 75, "max": 150, "step": 5, "fmt": "%d %%",
		"tip": "Agrandit ou réduit les menus, les textes et le HUD."},
	{"key": "show_fps", "tab": "display", "label": "Afficher les FPS", "kind": "bool", "def": false,
		"tip": "Un compteur d'images par seconde en haut à gauche."},

	{"key": "preset", "tab": "graphics", "label": "Préréglage", "kind": "choice", "def": "normal",
		"opts": [["Économie", "eco"], ["Normale", "normal"], ["Haute", "high"], ["Maximale", "max"], ["Personnalisée", "custom"]],
		"tip": "Règle d'un coup la résolution 3D, les ombres, l'anticrénelage et le halo."},
	{"key": "shadows", "tab": "graphics", "label": "Ombres", "kind": "choice", "def": "high",
		"opts": [["Désactivées", "off"], ["Basses", "low"], ["Hautes", "high"]],
		"tip": "Les ombres du soleil sur les planètes. Basses : moins nettes, plus légères."},
	{"key": "msaa", "tab": "graphics", "label": "Anticrénelage", "kind": "choice", "def": 0,
		"opts": [["Désactivé", 0], ["MSAA 2×", 2], ["MSAA 4×", 4]], "tip": "Lisse les bords des objets. Coûteux sur téléphone."},
	{"key": "glow", "tab": "graphics", "label": "Halo lumineux", "kind": "bool", "def": true,
		"tip": "La lueur de l'horizon des événements, des tirs et des braises."},

	{"key": "vol_master", "tab": "audio", "label": "Volume général", "kind": "range", "def": 100, "min": 0, "max": 100, "step": 5, "fmt": "%d %%",
		"tip": "Tout le son du jeu. À 0 %, le son est coupé."},
	{"key": "vol_music", "tab": "audio", "label": "Musique", "kind": "range", "def": 100, "min": 0, "max": 100, "step": 5, "fmt": "%d %%",
		"tip": "Le générique de l'écran titre."},
	{"key": "vol_sfx", "tab": "audio", "label": "Effets sonores", "kind": "range", "def": 100, "min": 0, "max": 100, "step": 5, "fmt": "%d %%",
		"tip": "La porte, les tirs, les alarmes, les boutons."},
	{"key": "mute_background", "tab": "audio", "label": "Silence en arrière-plan", "kind": "bool", "def": true,
		"tip": "Coupe le son quand le jeu n'a plus le focus. Évite de superposer le son de plusieurs fenêtres du jeu."},

	{"key": "difficulty", "tab": "game", "label": "Difficulté campagne", "kind": "choice", "def": "normal",
		"opts": [["Recrue", "easy"], ["Officier", "normal"], ["Vétéran", "hard"]],
		"tip": "Recrue : ennemis moins résistants et moins dangereux. Vétéran : l'inverse."},
	{"key": "cam_speed", "tab": "game", "label": "Vitesse de la caméra", "kind": "range", "def": 100, "min": 50, "max": 200, "step": 10, "fmt": "%d %%",
		"tip": "Au doigt, à la souris et au clavier."},
	{"key": "shake", "tab": "game", "label": "Secousses de l'image", "kind": "bool", "def": true,
		"tip": "Au kawoosh et aux explosions."},
]

## Ce que règle chaque préréglage
const PRESETS := {
	"eco": {"render_scale": 45, "shadows": "low", "msaa": 0, "glow": false},
	"normal": {"render_scale": 60, "shadows": "high", "msaa": 0, "glow": true},
	"high": {"render_scale": 80, "shadows": "high", "msaa": 2, "glow": true},
	"max": {"render_scale": 100, "shadows": "high", "msaa": 4, "glow": true},
}

var _values := {}
var _spec := {}
var _save_queued := false
var _fps_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for s in SCHEMA:
		_spec[s.key] = s
		_values[s.key] = s.def
	_load()
	# Les nœuds des scènes (soleil, environnement) reçoivent leurs réglages en entrant dans l'arbre
	get_tree().node_added.connect(_on_node_added)
	apply_all.call_deferred()


# ---------- Lecture et écriture ----------

func value(key: String) -> Variant:
	return _values[key]


func spec(key: String) -> Dictionary:
	return _spec[key]


func keys_of(tab: String) -> Array:
	var out := []
	for s in SCHEMA:
		if s.tab == tab:
			out.append(s.key)
	return out


func set_value(key: String, v: Variant) -> void:
	v = _coerce(key, v)
	if _values[key] == v:
		return
	_values[key] = v
	if key == "preset":
		if PRESETS.has(v):
			for k in PRESETS[v]:
				_values[k] = PRESETS[v][k]
				_apply(k)
				changed.emit(k)
	elif PRESETS.normal.has(key):
		_values.preset = _detect_preset()
		changed.emit("preset")
	_apply(key)
	changed.emit(key)
	_queue_save()


## Le réglage a-t-il un effet dans l'état actuel (ex. la taille de fenêtre en plein écran : non)
func is_active(key: String) -> bool:
	if key == "upscaler" and ProjectSettings.get_setting("rendering/renderer/rendering_method", "gl_compatibility") in ["mobile", "gl_compatibility"]:
		return false
	var w = _spec[key].get("when")
	return w == null or _values[w[0]] == w[1]


## Le texte affiché pour la valeur actuelle
func display(key: String) -> String:
	var s: Dictionary = _spec[key]
	var v = _values[key]
	match s.kind:
		"bool":
			return "Oui" if v else "Non"
		"range":
			return s.fmt % v
		_:
			for o in s.opts:
				if o[1] == v:
					return o[0]
	return str(v)


## Passe à la valeur suivante (dir = 1) ou précédente (dir = -1)
func step(key: String, dir: int) -> void:
	var s: Dictionary = _spec[key]
	match s.kind:
		"bool":
			set_value(key, not _values[key])
		"range":
			set_value(key, _values[key] + dir * s.step)
		_:
			var opts: Array = s.opts
			var i := 0
			for j in opts.size():
				if opts[j][1] == _values[key]:
					i = j
			# Le préréglage « Personnalisée » ne se choisit pas : il s'affiche quand on retouche un réglage
			var n := opts.size() - (1 if key == "preset" else 0)
			set_value(key, opts[posmod(i + dir, n)][1])


func reset_defaults() -> void:
	for s in SCHEMA:
		_values[s.key] = s.def
	apply_all()
	for s in SCHEMA:
		changed.emit(s.key)
	_queue_save()


func _coerce(key: String, v: Variant) -> Variant:
	var s: Dictionary = _spec[key]
	match s.kind:
		"bool":
			return bool(v)
		"range":
			var x := int(snappedf(float(v), float(s.step)))
			return clampi(x, int(s.min), int(s.max))
		_:
			for o in s.opts:
				if str(o[1]) == str(v):
					return o[1]
			return s.def


func _detect_preset() -> String:
	for p in PRESETS:
		var same := true
		for k in PRESETS[p]:
			if _values[k] != PRESETS[p][k]:
				same = false
		if same:
			return p
	return "custom"


func _queue_save() -> void:
	if not _save_queued:
		_save_queued = true
		_save.call_deferred()


func _save() -> void:
	_save_queued = false
	var cf := ConfigFile.new()
	for s in SCHEMA:
		cf.set_value(s.tab, s.key, _values[s.key])
	var err := cf.save(path)
	if err != OK:
		push_error("Réglages non enregistrés (%s) : %s" % [error_string(err), path])


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(path) == OK:
		for s in SCHEMA:
			_values[s.key] = _coerce(s.key, cf.get_value(s.tab, s.key, s.def))
	elif FileAccess.file_exists(LEGACY_PATH):
		_load_legacy()
	_values.preset = _detect_preset()


## Les réglages des premières versions : volume (0–1), qualité (0–3 : la résolution 3D seule), halo.
## On reprend exactement le rendu d'alors, sans ajouter l'anticrénelage des nouveaux préréglages.
func _load_legacy() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(LEGACY_PATH))
	if not d is Dictionary:
		return
	_values.vol_master = _coerce("vol_master", float(d.get("volume", 1.0)) * 100.0)
	_values.render_scale = [45, 60, 80, 100][clampi(int(d.get("quality", 1)), 0, 3)]
	_values.glow = bool(d.get("glow", true))
	_queue_save()


# ---------- Application au moteur ----------

func apply_all() -> void:
	for s in SCHEMA:
		_apply(s.key)


func _headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _apply(key: String) -> void:
	var v = _values[key]
	var root := get_tree().root
	match key:
		"window_mode", "resolution":
			_apply_window()
		"render_scale":
			root.scaling_3d_scale = v / 100.0
		"upscaler":
			root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if v == "fsr" and is_active("upscaler") else Viewport.SCALING_3D_MODE_BILINEAR
		"vsync":
			if not _headless():
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if v else DisplayServer.VSYNC_DISABLED)
		"max_fps":
			Engine.max_fps = v
		"ui_scale":
			root.content_scale_factor = v / 100.0
		"show_fps":
			_set_fps_overlay(v)
		"shadows":
			RenderingServer.directional_shadow_atlas_set_size(2048 if v == "low" else 4096, true)
			for n in get_tree().get_nodes_in_group("sun"):
				configure_sun(n)
		"msaa":
			root.msaa_3d = {0: Viewport.MSAA_DISABLED, 2: Viewport.MSAA_2X, 4: Viewport.MSAA_4X}[v]
		"glow":
			for n in get_tree().get_nodes_in_group("world_env"):
				_configure_env(n)
		"vol_master":
			Audio.set_volume("Master", v / 100.0)
		"vol_music":
			Audio.set_volume(Audio_.BUS_MUSIC, v / 100.0)
		"vol_sfx":
			Audio.set_volume(Audio_.BUS_SFX, v / 100.0)
		"mute_background":
			Audio.set_background_mute(bool(v))


func _apply_window() -> void:
	if _headless():
		return
	var want := DisplayServer.WINDOW_MODE_WINDOWED if _values.window_mode == "windowed" else DisplayServer.WINDOW_MODE_FULLSCREEN
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)
	if want == DisplayServer.WINDOW_MODE_WINDOWED:
		var wh: PackedStringArray = String(_values.resolution).split("x")
		var size := Vector2i(int(wh[0]), int(wh[1]))
		var screen := DisplayServer.window_get_current_screen()
		var area := DisplayServer.screen_get_usable_rect(screen)
		size = size.min(area.size)
		DisplayServer.window_set_size(size)
		DisplayServer.window_set_position(area.position + (area.size - size) / 2)


func _on_node_added(n: Node) -> void:
	if n is DirectionalLight3D and n.is_in_group("sun"):
		configure_sun(n)
	elif n is WorldEnvironment and n.is_in_group("world_env"):
		_configure_env.call_deferred(n)


func configure_sun(l: DirectionalLight3D) -> void:
	var s: String = _values.shadows
	l.shadow_enabled = s != "off"
	l.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if s == "high" else DirectionalLight3D.SHADOW_ORTHOGONAL


func _configure_env(we: WorldEnvironment) -> void:
	if is_instance_valid(we) and we.environment:
		we.environment.glow_enabled = bool(_values.glow) and not Cli.has("--noglow")


# ---------- Compteur d'images ----------

func _set_fps_overlay(on: bool) -> void:
	if on and _fps_label == null:
		var layer := CanvasLayer.new()
		layer.layer = 100
		add_child(layer)
		_fps_label = Label.new()
		_fps_label.position = Vector2(12, 8)
		_fps_label.add_theme_font_size_override("font_size", 18)
		_fps_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
		_fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_fps_label.add_theme_constant_override("outline_size", 4)
		layer.add_child(_fps_label)
	if _fps_label:
		_fps_label.get_parent().visible = on
	set_process(on)


func _process(_delta: float) -> void:
	if _fps_label and Engine.get_process_frames() % 15 == 0:
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()
