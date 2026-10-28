extends Control
## Briefing d'expédition avant le premier franchissement de la porte.

const T = preload("res://scripts/ui_theme.gd")
const Sim = preload("res://scripts/outpost_sim.gd")
const SettingsMenu = preload("res://scripts/settings_menu.gd")
const Harness = preload("res://scripts/debug_harness.gd")

var panel: PanelContainer
var details: Label
var malp: Label
var profile_buttons := {}
var difficulty_buttons := {}
var _sub: Control
var _scroll: ScrollContainer


func _ready() -> void:
	add_child(Harness.new(self))
	theme = T.make()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("09121e")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 36)
	add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 0)
	center.add_child(panel)
	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(900, 720)
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	box.add_child(T.label("SGC // PROGRAMME AVANT-POSTE", "Section"))
	box.add_child(T.label("NOUVELLE EXPÉDITION", "Heading"))
	box.add_child(T.wrap(T.label("P3X-742 · Vallée boisée\nUne porte isolée, un gisement potentiel et une présence goa'uld. Première planète disponible pour ce prototype.", "Body")))
	var sequence := T.wrap(T.label("1 · Briefing et rapport MALP    →    2 · Première équipe SG\n3 · Reconnaissance et sécurisation    →    4 · Ingénieurs et avant-poste", "Body", T.BLUE))
	box.add_child(sequence)
	box.add_child(T.label("PREMIÈRE ÉQUIPE / DOTATION", "Section"))
	var profiles := HFlowContainer.new()
	profiles.add_theme_constant_override("h_separation", 12)
	profiles.add_theme_constant_override("v_separation", 8)
	box.add_child(profiles)
	for key in ["balanced", "assault", "recon"]:
		var choice: String = key
		var button := T.button(Sim.PROFILES[key].name, func(): _choose_profile(choice))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 20)
		profiles.add_child(button)
		profile_buttons[key] = button
	details = T.wrap(T.label("", "Body"))
	box.add_child(details)
	box.add_child(T.label("DIFFICULTÉ DE L'EXPÉDITION RTS", "Section"))
	var levels := HFlowContainer.new()
	box.add_child(levels)
	for entry in [["easy", "Recrue"], ["normal", "Officier"], ["hard", "Vétéran"]]:
		var level: String = entry[0]
		var button := T.button(entry[1], func(): Expedition.difficulty = level; _refresh(), "Ghost")
		button.toggle_mode = true
		levels.add_child(button)
		difficulty_buttons[level] = button
	box.add_child(T.button("Consulter le rapport MALP", _show_malp, "Ghost"))
	malp = T.wrap(T.label("Rapport de reconnaissance disponible. La zone n'est pas encore sécurisée.", "Body", T.DIM))
	box.add_child(malp)
	box.add_child(T.button("Composer l'adresse et envoyer l'équipe", _launch, "Accent"))
	box.add_child(T.wrap(T.label("EXPÉDITION NON SAUVEGARDÉE · Quitter ou recommencer efface cette partie RTS. La campagne est indépendante.", "Body", T.AMBER)))
	var resume := T.button("Reprendre une expédition · bientôt", func(): pass, "Ghost")
	resume.disabled = true
	resume.tooltip_text = "La sauvegarde RTS n'est pas encore disponible. La sauvegarde de campagne est indépendante."
	box.add_child(resume)
	var nav := HFlowContainer.new()
	nav.add_theme_constant_override("h_separation", 12)
	nav.add_theme_constant_override("v_separation", 8)
	box.add_child(nav)
	nav.add_child(T.button("Options", _options, "Ghost"))
	nav.add_child(T.button("Commandes RTS", _controls, "Ghost"))
	nav.add_child(T.button("Menu principal", _back, "Ghost"))
	resized.connect(_fit)
	_fit()
	_refresh()


func _fit() -> void:
	# Le briefing reste défilable avec une grande échelle d'interface ou en paysage.
	var available := size - Vector2(72, 72)
	var width := minf(900, maxf(0, available.x))
	panel.custom_minimum_size = Vector2(width, 0)
	_scroll.custom_minimum_size = Vector2(maxf(0, width - 36), minf(720, maxf(100, available.y - 36)))


func _choose_profile(key: String) -> void:
	Expedition.profile = key
	_refresh()


func _cycle_difficulty() -> void:
	var levels := ["easy", "normal", "hard"]
	Expedition.difficulty = levels[(levels.find(Expedition.difficulty) + 1) % levels.size()]
	_refresh()


func _refresh() -> void:
	var d: Dictionary = Sim.PROFILES[Expedition.profile]
	var roster := "O'Neill · Carter · Jackson · Teal'c" if Expedition.profile == "balanced" else "Quatre militaires du SGC"
	details.text = "%s\n%d PV / soldat · dégâts %d · vision %d cases · %d ravitaillement affecté à l'expédition\nLe poste de commandement n'existe pas encore : l'équipe doit d'abord ouvrir la voie aux ingénieurs." % [roster, d.hp, d.damage, d.vision, d.supplies]
	for key in difficulty_buttons:
		difficulty_buttons[key].set_pressed_no_signal(key == Expedition.difficulty)
		difficulty_buttons[key].theme_type_variation = "Accent" if key == Expedition.difficulty else "Ghost"
	for key in profile_buttons:
		profile_buttons[key].theme_type_variation = "Accent" if key == Expedition.profile else "Ghost"


func _show_malp() -> void:
	malp.text = "RAPPORT MALP · Atmosphère respirable. Clairière constructible à l'est de la porte. Signatures hostiles dans les environs ; pas de position ennemie précise confirmée. Maintenez le passage libre pour le convoi."
	malp.add_theme_color_override("font_color", T.TEXT)


func _launch() -> void:
	Audio.play("dhd")
	get_tree().change_scene_to_file.call_deferred("res://outpost.tscn")


func _options() -> void:
	panel.visible = false
	_sub = SettingsMenu.new()
	_sub.closed.connect(func(): _sub = null; panel.visible = true)
	add_child(_sub)


func _controls() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Commandes de l'expédition"
	dialog.dialog_text = "Toucher : sélectionner, puis terrain = avancer / ennemi = attaquer.\nGlisser : caméra. Mini-carte : recentrer. + / − : zoom.\n\nBASE : construire. SGC : recruter par la porte.\nUNITÉS : options, sélection multiple et escouades mémorisables.\nMédecin : soins. Ingénieur : réparations. Scientifique : ruines.\nÀ portée, utilisez Halte / travailler ici.\n\nReconnaissez et sécurisez la clairière, appelez le déploiement\npuis protégez les ingénieurs pendant l'installation.\n\nClavier : 1–3 = escouades, Maj+1–3 = mémoriser.\nEspace : soldats. Échap : menu. Souris : clic droit = ordre."
	dialog.confirmed.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()


func _back() -> void:
	get_tree().change_scene_to_file.call_deferred("res://main.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _sub == null:
		_back()
		get_viewport().set_input_as_handled()
