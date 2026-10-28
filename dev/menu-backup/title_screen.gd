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
	gt.fill_from = Vector2(0, 0.25)
	gt.fill_to = Vector2(0, 0.75)
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var body := T.modal(self, 680)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(head)
	_head = head
	var logo := _pixel_label("STARGATE", 72, Color(0.75, 0.88, 1.0))
	logo.add_theme_color_override("font_shadow_color", Color(0.1, 0.4, 0.9, 0.7))
	logo.add_theme_constant_override("shadow_offset_x", 0)
	logo.add_theme_constant_override("shadow_offset_y", 8)
	head.add_child(logo)
	head.add_child(_pixel_label("SG-1 · MISSIONS & AVANT-POSTE", 20, Color(1.0, 0.82, 0.48)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for g in TITLE_ADDRESS:
		var tr := TextureRect.new()
		tr.texture = T.glyph(g)
		tr.custom_minimum_size = Vector2(44, 44)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.modulate = Color(1.0, 0.7, 0.4, 0.85)
		row.add_child(tr)
	head.add_child(row)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	body.add_child(_box)
	_main_page()


func _pixel_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", T.font("PressStart2P"))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


# ---------- Les pages ----------

func _clear() -> void:
	_box.visible = true
	_head.visible = true
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()


func _text(text: String, size: int = 22, color: Color = T.TEXT) -> Label:
	var l := T.wrap(T.label(text, "Body", color))
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(l)
	return l


func _button(text: String, cb: Callable, variation: String = "", tip: String = "") -> void:
	var b := T.button(text.to_upper(), func():
		Audio.play("press")
		cb.call(), variation, tip)
	b.custom_minimum_size = Vector2(0, 60)
	b.add_theme_font_size_override("font_size", 24)
	_box.add_child(b)


func _main_page() -> void:
	_clear()
	_sub_open = false
	if Game.has_save():
		var done := int(Game.stats.done)
		var where: String = "toutes les missions accomplies" if done >= Data.PLANETS.size() else "prochaine mission : %s" % Data.PLANETS[done].n
		_button("Continuer la campagne", continue_requested.emit, "Accent", "Entrée")
		_text("Niveau %d · %d naquadah · %s" % [Game.stats.lvl, Game.stats.naq, where], 19, T.DIM)
	_button("Nouvelle campagne", _new_page)
	_button("Expédition · Avant-poste RTS", outpost_requested.emit, "Accent", "Escarmouche indépendante · prototype")
	_button("Options", func(): _options())
	_button("Extras et crédits", _extras, "Ghost")
	_button("Quitter", func(): get_tree().quit(), "Danger")
	(_box.get_child(0) as Control).grab_focus()


func _extras() -> void:
	_clear()
	_sub_open = true
	_head.visible = false
	_text("EXTRAS", 24, T.AMBER)
	_button("Galerie des modèles", assets_requested.emit, "Ghost")
	_button("Crédits", _credits, "Ghost")
	_button("Retour", _main_page, "Ghost")


func _new_page() -> void:
	if not Game.has_save():
		new_game_requested.emit()
		return
	_clear()
	_sub_open = true
	_text("Effacer la progression actuelle et repartir de zéro ?", 24, T.AMBER)
	_button("Oui, nouvelle partie", new_game_requested.emit, "Danger")
	_button("Annuler", _main_page, "Ghost", "Échap")


func open_options(tab: String = "") -> void:
	_options(tab)


func _options(tab: String = "") -> void:
	_sub_open = true
	_box.visible = false
	_head.visible = false
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
	_text("Jeu de fan non officiel, d'après la série Stargate SG-1 (MGM).\n\nGlyphes de la porte : Max Willis, Wikimedia Commons, CC BY-SA 3.0.\nPolices Press Start 2P (CodeMan38), Rajdhani (Indian Type Foundry) et Share Tech Mono (Carrois) : SIL Open Font License.\nMoteur : Godot Engine.\nPersonnages, animations et végétation : Quaternius (CC0). Textures de sol : Poly Haven (CC0).\nEffets sonores et générique : Stargate SG-1 (MGM), copie à usage personnel.", 21)
	_button("Retour", _main_page, "Ghost", "Échap")


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	if e.keycode == KEY_ESCAPE and _sub_open:
		_main_page()
	elif e.keycode in [KEY_ENTER, KEY_KP_ENTER] and not _sub_open and Game.has_save():
		continue_requested.emit()
	else:
		return
	get_viewport().set_input_as_handled()
