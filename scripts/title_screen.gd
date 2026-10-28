extends Control
## L'écran titre, par-dessus la porte ouverte du SGC (dont main.gd anime la caméra) :
## continuer, nouvelle partie, options, crédits, quitter. Entrée continue, Échap revient au menu principal.

const T = preload("res://scripts/ui_theme.gd")
const Data = preload("res://scripts/data.gd")
const SettingsMenu = preload("res://scripts/settings_menu.gd")

signal continue_requested
signal new_game_requested
signal outpost_requested
signal assets_requested

## L'adresse d'Abydos, la première composée par le SGC
const TITLE_ADDRESS := [27, 7, 15, 32, 12, 30, 1]

var _box: VBoxContainer
var _head: Control
var _sub_open := false
var _link: VBoxContainer
var _link_status: Label
var _glyphs: Array[TextureRect] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Un voile sombre en bas pour lire les boutons
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.01, 0.015, 0.03, 0.0))
	grad.set_color(1, Color(0.01, 0.015, 0.03, 0.92))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.65, 0)
	gt.fill_to = Vector2(0, 0)
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 40)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	margin.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_theme_constant_override("separation", 20)
	scroll.add_child(body)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 0)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(head)
	_head = head
	head.add_child(T.label("STARGATE COMMAND  /  TERRE", "Caption", T.BLUE))
	var logo := T.label("STARGATE", "Heading")
	logo.add_theme_font_size_override("font_size", 64)
	head.add_child(logo)
	head.add_child(T.label("SG-1  /  COMMANDEMENT", "Section", T.TEXT))
	var line := HSeparator.new()
	head.add_child(line)
	head.add_child(T.wrap(T.label("Base du SGC · Salle d'embarquement", "Body", T.DIM)))
	var fit := func():
		margin.add_theme_constant_override("margin_top", int(maxf(32, (size.y - 1000) * 0.35)))
		margin.offset_right = -maxf(32, size.x - minf(500, size.x - 40) - 40)
		logo.add_theme_font_size_override("font_size", 48 if size.x < 900 else 64)
	resized.connect(fit)
	fit.call_deferred()

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	body.add_child(_box)
	_build_link(body)
	_main_page()


func _build_link(body: VBoxContainer) -> void:
	_link = VBoxContainer.new()
	_link.add_theme_constant_override("separation", 8)
	body.add_child(_link)
	_link.add_child(HSeparator.new())
	_link.add_child(T.label("LIAISON DE LA PORTE / ABYDOS", "Caption", T.DIM))
	var symbols := HBoxContainer.new()
	symbols.add_theme_constant_override("separation", 10)
	_link.add_child(symbols)
	for glyph in TITLE_ADDRESS:
		var icon := TextureRect.new()
		icon.texture = T.glyph(glyph)
		icon.custom_minimum_size = Vector2(48, 48)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.tooltip_text = Data.GLYPH_NAMES[glyph]
		symbols.add_child(icon)
		_glyphs.append(icon)
	_link_status = T.wrap(T.label("Composition de l'adresse…", "Body", T.BLUE))
	_link_status.add_theme_font_size_override("font_size", 18)
	_link.add_child(_link_status)
	set_gate_status("dial", 0)


func set_gate_status(phase: String, encoded: int) -> void:
	for i in _glyphs.size():
		_glyphs[i].modulate = T.AMBER if i < encoded else (T.TEXT if i == encoded and phase == "dial" else Color(T.DIM, 0.35))
	match phase:
		"dial":
			_link_status.text = "Chevron %02d / 07 · %s" % [mini(encoded + 1, 7), Data.GLYPH_NAMES[TITLE_ADDRESS[mini(encoded, 6)]]]
		"opening":
			_link_status.text = "Septième chevron verrouillé · ouverture"
		"stable":
			_link_status.text = "Liaison établie · horizon stable"
		"closing":
			_link_status.text = "Fermeture de la liaison"
		"standby":
			_link_status.text = "Porte en attente"


# ---------- Les pages ----------

func _clear() -> void:
	_box.visible = true
	_head.visible = true
	_link.visible = false
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()


func _text(text: String, size: int = 22, color: Color = T.TEXT) -> Label:
	var l := T.wrap(T.label(text, "Body", color))
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_box.add_child(l)
	return l


func _button(text: String, cb: Callable, variation: String = "", tip: String = "") -> void:
	var b := T.button(text.to_upper(), func():
		Audio.play("press")
		cb.call(), variation, tip)
	b.custom_minimum_size = Vector2(0, 52 if variation == "Nav" else 60)
	b.add_theme_font_size_override("font_size", 22 if variation == "Nav" else 24)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_box.add_child(b)


func _main_page() -> void:
	_clear()
	_sub_open = false
	_link.visible = true
	_text("CAMPAGNE SG-1", 18, T.BLUE)
	if Game.has_save():
		_button("Continuer la campagne", continue_requested.emit, "Accent", "Rejoindre la base du SGC · Entrée")
		var done := int(Game.stats.done)
		var where: String = "Toutes les missions accomplies" if done >= Data.PLANETS.size() else "Prochaine mission : %s" % Data.PLANETS[done].n
		_text("Niveau %d · %s" % [Game.stats.lvl, where], 19, T.DIM)
	_button("Nouvelle campagne", _new_page, "Nav" if Game.has_save() else "Accent")
	_button("Expédition RTS · P3X-742", outpost_requested.emit, "Nav", "Opération indépendante de la campagne")
	_button("Options", func(): _options(), "Nav")
	_button("Archives et crédits", _extras, "Nav")
	_button("Quitter", func(): get_tree().quit(), "Nav")
	(_box.get_child(1) as Control).grab_focus()


func _new_page() -> void:
	if not Game.has_save():
		new_game_requested.emit()
		return
	_clear()
	_sub_open = true
	_head.visible = false
	_text("NOUVELLE CAMPAGNE", 24, T.AMBER)
	_text("Repartir du SGC avec une nouvelle équipe ? La sauvegarde de campagne actuelle sera remplacée.")
	_button("Commencer une nouvelle campagne", new_game_requested.emit, "Danger")
	_button("Conserver ma campagne", _main_page, "Ghost")
	(_box.get_child(_box.get_child_count() - 1) as Control).grab_focus()


func _extras() -> void:
	_clear()
	_sub_open = true
	_head.visible = false
	_text("EXTRAS", 24, T.AMBER)
	_button("Galerie des modèles", assets_requested.emit, "Ghost")
	_button("Crédits", _credits, "Ghost")
	_button("Retour", _main_page, "Ghost")


func open_options(tab: String = "") -> void:
	_options(tab)


func _options(tab: String = "") -> void:
	_sub_open = true
	_box.visible = false
	_head.visible = false
	_link.visible = false
	var m := SettingsMenu.new()
	if tab != "":
		m.tab = tab
	m.closed.connect(_main_page)
	add_child(m)


func _credits() -> void:
	_clear()
	_sub_open = true
	_head.visible = false
	_text("CRÉDITS", 22, T.AMBER).add_theme_font_override("font", T.font("caption"))
	_text("Jeu de fan non officiel, d'après la série Stargate SG-1 (MGM).\n\nGlyphes de la porte : Max Willis, Wikimedia Commons, CC BY-SA 3.0.\nPolices Press Start 2P (CodeMan38), Rajdhani (Indian Type Foundry) et Share Tech Mono (Carrois) : SIL Open Font License.\nMoteur : Godot Engine.\nPorte 3D « Milky Way Stargate | Stargate SG-1 » : Anquietas System, CC BY-NC 4.0.\nsketchfab.com/anquietas-sys · creativecommons.org/licenses/by-nc/4.0/\nAnneaux de transport : Anquietas System, CC BY-NC 4.0.\nRéplicateur : TaurWing, CC BY 4.0 · sketchfab.com/TaurWing.\nConsole ancienne : merlincodes, CC BY 4.0 · sketchfab.com/merlincodes.\nPersonnages, animations et végétation : Quaternius (CC0). Textures de sol : Poly Haven (CC0).\nEffets sonores et générique : Stargate SG-1 (MGM), copie à usage personnel.", 21)
	_button("Retour", _main_page, "Ghost", "Échap")


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	if e.keycode == KEY_ESCAPE and _sub_open:
		_main_page()
	elif e.keycode in [KEY_ENTER, KEY_KP_ENTER] and not _sub_open:
		if Game.has_save():
			continue_requested.emit()
		else:
			_new_page()
	else:
		return
	get_viewport().set_input_as_handled()
