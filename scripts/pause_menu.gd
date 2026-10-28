extends Control
## Le menu pause : il met l'arbre en pause et reste actif pendant celle-ci.
## Il ne sait rien de la partie : main.gd l'ouvre avec ce qu'il faut afficher et écoute ses signaux.

const T = preload("res://scripts/ui_theme.gd")
const SettingsMenu = preload("res://scripts/settings_menu.gd")

signal abandon_requested(to_title: bool)

var _panel: PanelContainer
var _box: VBoxContainer
var _page := ""
var _subtitle := ""
var _on_planet := false
var _can_abandon := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var veil := ColorRect.new()
	veil.color = Color(0.0, 0.01, 0.02, 0.72)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	_box = T.modal(self, 640)
	_panel = _box.get_parent().get_parent()


## subtitle : où l'on est ; can_abandon : false pendant une séquence animée (on ne peut pas quitter la planète)
func open(subtitle: String, on_planet: bool, can_abandon: bool) -> void:
	if visible:
		return
	_subtitle = subtitle
	_on_planet = on_planet
	_can_abandon = can_abandon
	get_tree().paused = true
	visible = true
	Audio.play("press")
	_main_page()


func close() -> void:
	visible = false
	get_tree().paused = false


# ---------- Les pages ----------

func _clear(page: String) -> void:
	_page = page
	_panel.visible = true
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()


func _button(text: String, cb: Callable, variation: String = "", tip: String = "") -> Button:
	var b := T.button(text.to_upper(), func():
		Audio.play("press")
		cb.call(), variation, tip)
	b.custom_minimum_size = Vector2(0, 58)
	b.add_theme_font_size_override("font_size", 23)
	_box.add_child(b)
	return b


func _head(title: String, sub: String) -> void:
	var h := T.label(title, "Heading")
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(h)
	if sub != "":
		var c := T.wrap(T.label(sub, "Caption"))
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_box.add_child(c)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	_box.add_child(gap)


func _main_page() -> void:
	_clear("main")
	_head("PAUSE", _subtitle)
	_button("Reprendre", close, "Accent", "Échap").grab_focus()
	_button("Options", _options)
	_button("Commandes", _controls)
	if _on_planet:
		var ab := _button("Abandonner la mission", func(): _confirm("Rentrer au SGC ? La planète sera à refaire ; l'expérience et le naquadah gagnés sont conservés.",
			"Rentrer au SGC", func(): _abandon(false)), "Danger", "Retour au SGC")
		ab.disabled = not _can_abandon
		var mm := _button("Menu principal", func(): _confirm("Quitter la mission pour l'écran titre ? La planète sera à refaire.",
			"Écran titre", func(): _abandon(true)), "Ghost")
		mm.disabled = not _can_abandon
		if not _can_abandon:
			var w := T.wrap(T.label("Attendez la fin de l'action en cours pour quitter la planète.", "Body", T.DIM))
			w.add_theme_font_size_override("font_size", 18)
			w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_box.add_child(w)
	_button("Quitter le jeu", func(): _confirm("Quitter le jeu ? La progression enregistrée au SGC est conservée.",
		"Quitter", func(): get_tree().quit()), "Danger")


func _abandon(to_title: bool) -> void:
	close()
	abandon_requested.emit(to_title)


func _options() -> void:
	_page = "options"
	_panel.visible = false
	var m := SettingsMenu.new()
	m.closed.connect(_main_page)
	add_child(m)


func _controls() -> void:
	_clear("sub")
	_head("COMMANDES", "")
	for part in [
		["TACTILE", "Toucher : déplacer l'équipe, viser, choisir.\nGlisser : déplacer la caméra.\nPincer à deux doigts : zoomer et tourner."],
		["SOURIS", "Clic : déplacer, viser, choisir.\nGlisser : caméra · clic droit glissé : tourner · molette : zoom."],
		["CLAVIER", "1 à 9 : choix et actions de combat · Échap : menu pause.\nCombat temps réel : Espace met en pause tactique ; les ordres restent possibles.\nZQSD / flèches : caméra · A / E : tourner · + / − : zoom.\nC : recentrer · H : trousse de soins.\nSGC en coupe : Q/D ou ←/→ pour marcher, ↑/↓ pour l'ascenseur, E pour entrer.\nPréparez la destination au briefing, puis autorisez le départ près de la porte."]]:
		_box.add_child(T.label(part[0], "Section"))
		var l := T.wrap(T.label(part[1], "Body", T.TEXT))
		l.add_theme_font_size_override("font_size", 20)
		_box.add_child(l)
	_button("Retour", _main_page, "Ghost", "Échap").grab_focus()


func _confirm(text: String, yes: String, cb: Callable) -> void:
	_clear("sub")
	_head("CONFIRMER", "")
	var l := T.wrap(T.label(text, "Body", T.TEXT))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(l)
	_button(yes, cb, "Danger")
	_button("Annuler", _main_page, "Ghost", "Échap").grab_focus()


## Échap : ferme la pause depuis la page principale, sinon revient à celle-ci.
## (L'écran des options gère lui-même son Échap.)
func _input(e: InputEvent) -> void:
	if not visible or _page == "options" or not e.is_action_pressed("ui_cancel"):
		return
	if _page == "main":
		close()
	else:
		_main_page()
	get_viewport().set_input_as_handled()
