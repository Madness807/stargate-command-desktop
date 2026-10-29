extends Control
## Briefing d'expédition avant le premier franchissement de la porte.

const T = preload("res://scripts/ui_theme.gd")
const Sim = preload("res://scripts/outpost_sim.gd")
const SettingsMenu = preload("res://scripts/settings_menu.gd")
const Harness = preload("res://scripts/debug_harness.gd")

var panel: PanelContainer
var details: Label
var profile_buttons := {}
var difficulty_buttons := {}
var _sub: Control
var _scroll: ScrollContainer


var _content: VBoxContainer
var _tabs := {}
var _page := "briefing"
var _summary: Label
var _difficulty: Label

func _ready() -> void:
	get_tree().auto_accept_quit = false
	add_child(Harness.new(self))
	theme = T.make()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("0b1015")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	add_child(margin)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", T.box(Color("101922"), T.LINE, 0, 1, 20))
	margin.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	panel.add_child(body)
	var top := HBoxContainer.new()
	body.add_child(top)
	var id_label := T.label("SGC  /  ORDRE D'OPÉRATION 001", "Caption", T.BLUE)
	id_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(id_label)
	top.add_child(T.button("Retour", _back, "Ghost"))
	body.add_child(T.label("P3X-742", "Heading"))
	body.add_child(T.wrap(T.label("DERNIÈRE VEILLE · Opération originale du SGC", "Body", T.DIM)))
	var nav := HBoxContainer.new()
	body.add_child(nav)
	for entry in [["briefing", "01  Briefing"], ["forces", "02  Équipe"], ["rules", "03  Engagement"]]:
		var key: String = entry[0]
		var button := T.button(entry[1], func(): _show_page(key), "Tab")
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nav.add_child(button)
		_tabs[key] = button
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	body.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 14)
	_scroll.add_child(_content)
	body.add_child(HSeparator.new())
	_summary = T.wrap(T.label("", "Body"))
	body.add_child(_summary)
	var foot := HBoxContainer.new()
	body.add_child(foot)
	foot.add_child(T.button("Options", _options, "Ghost"))
	foot.add_child(T.button("Commandes", _controls, "Ghost"))
	var launch := T.button("Nouvelle expédition" if Expedition.has_save() else "Déployer l'équipe", _launch, "Ghost" if Expedition.has_save() else "Accent")
	launch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(launch)
	if Expedition.has_save():
		var resume := T.button("Reprendre", func():
			Expedition.resume_pending = true
			get_tree().change_scene_to_file.call_deferred("res://outpost.tscn"), "Accent", "Reprendre la base et les unités sauvegardées")
		resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(resume)
	body.add_child(T.wrap(T.label("Sauvegarde automatique · reprise en pause depuis cet écran.", "Body", T.DIM)))
	_show_page("briefing")
	if not Expedition.last_error.is_empty():
		_content.add_child(T.wrap(T.label(Expedition.last_error, "Body", T.RED)))


func _show_page(page: String) -> void:
	_page = page
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	profile_buttons.clear()
	difficulty_buttons.clear()
	for key in _tabs:
		_tabs[key].set_pressed_no_signal(key == page)
	_scroll.scroll_vertical = 0
	match page:
		"briefing":
			_content.add_child(T.label("MISSION", "Section"))
			_content.add_child(T.wrap(T.label("Récupérez les archives. Ramenez votre personnel.", "Heading")))
			_content.add_child(T.wrap(T.label("Pendant la saison 3, après l’acquisition des générateurs d’Orban, le SGC enquête sur une installation ancienne occupée par les Goa’ulds. Le MALP confirme une clairière près de la porte. Établissez une tête de pont, déchiffrez les archives et coupez le bouclier du camp. La mission se termine au retour du personnel au SGC, pas à la destruction du camp.", "Body")))
			for entry in [["01–02  TÊTE DE PONT", "Reconnaître la clairière, appeler les ingénieurs et protéger l'installation du commandement. Les modules sont assemblés sur place ; les renforts viennent du SGC."], ["03  ARCHIVES", "Construire un laboratoire alimenté et escorter un scientifique aux ruines. L'analyse exige 60 secondes de travail en zone sécurisée."], ["04  RELAIS", "Exploiter le gisement puis déployer deux générateurs de terrain : 40 N et 45 secondes d'intervention par relais. Nord : réduit les renforts ennemis ; est : retarde une colonne et affaiblit le camp. Choisir l’ordre ou diviser les forces."], ["05–06  ASSAUT ET TRANSMISSION", "Neutraliser le camp une fois son bouclier coupé. Protéger ensuite une transmission de 90 secondes aux ruines, face aux réserves ennemies."], ["07  RAPATRIEMENT", "Rapporter les données au commandement, rassembler les survivants et ouvrir vers la Terre. Une connexion sortante empêche l'arrivée des renforts."], ["CHOIX ET RISQUES", "Le naquadah conditionné alimente les dispositifs : relais 40 N chacun, secours électrique 25 N / 45 s, régulation 80 N. Régulation : +4 énergie, interventions 25 % plus rapides. Le détachement est limité à 12 militaires, hors spécialistes. Un scientifique peut être remplacé avant le départ ; pendant le rapatriement, au moins un scientifique et un militaire doivent rentrer. Le commandement doit tenir jusqu'au dernier passage."], ["DÉTOUR FACULTATIF · SG-11", "Une balise émet au nord-ouest. Sécurisez le refuge puis escortez les deux survivants au commandement. Leurs relevés radio portent l’alerte raid à 50 secondes. Ce détour mobilise une escorte, mais fournit aussi un scientifique et un ingénieur."], ["RYTHME", "Mission à plusieurs phases, sauvegarde automatique et reprise en pause. Les travaux s'interrompent si le site est contesté, sans effacer leur progression. Aucun chronomètre global : préparez vos opérations entre les raids."]]:
				_content.add_child(HSeparator.new())
				_content.add_child(T.label(entry[0], "Caption", T.BLUE))
				_content.add_child(T.wrap(T.label(entry[1], "Body")))
		"forces":
			_content.add_child(T.label("ÉQUIPE DE PREMIER CONTACT", "Section"))
			for key in ["balanced", "assault", "recon"]:
				var choice: String = key
				var button := T.button(Sim.PROFILES[key].name, func(): _choose_profile(choice), "Row")
				button.toggle_mode = true
				_content.add_child(button)
				profile_buttons[key] = button
			details = T.wrap(T.label("", "Body"))
			_content.add_child(details)
		"rules":
			_content.add_child(T.label("DIFFICULTÉ", "Section"))
			for entry in [["easy", "Recrue"], ["normal", "Officier"], ["hard", "Vétéran"]]:
				var level: String = entry[0]
				var button := T.button(entry[1], func(): Expedition.difficulty = level; _refresh(), "Row")
				button.toggle_mode = true
				_content.add_child(button)
				difficulty_buttons[level] = button
			_difficulty = T.wrap(T.label("", "Body"))
			_content.add_child(_difficulty)
			_content.add_child(HSeparator.new())
			_content.add_child(T.label("DOCTRINE", "Section"))
			_content.add_child(T.wrap(T.label("Commandez vos unités en temps réel. Le terrain inexploré masque les positions adverses. Gardez la porte libre pour recevoir les renforts.

La pause interrompt la simulation ; le menu vous permet de consulter les commandes et les options.", "Body")))
	_refresh()


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
	if is_instance_valid(details):
		details.text = "%s\n\n%d PV par soldat · puissance de feu %d · vision %d cases\n%d ravitaillements disponibles au départ.\n\nL'équipe ouvre la voie. Les ingénieurs rejoindront la zone après sa sécurisation." % [roster, d.hp, d.damage, d.vision, d.supplies]
	var labels := {"easy": "Recrue", "normal": "Officier", "hard": "Vétéran"}
	_summary.text = "%s  /  %s  /  %d ravitaillements" % [d.name, labels[Expedition.difficulty], d.supplies]
	if is_instance_valid(_difficulty):
		_difficulty.text = {"easy": "Premier raid 130 secondes après la mise en service du commandement.", "normal": "Premier raid 100 secondes après la mise en service du commandement.", "hard": "Premier raid 80 secondes après la mise en service du commandement."}[Expedition.difficulty]
		_difficulty.text += " Le compte à rebours reste arrêté pendant la reconnaissance et l'installation. Les colonnes suivantes annoncent leur axe et leur cible 30 secondes avant le contact."
	for key in difficulty_buttons:
		difficulty_buttons[key].set_pressed_no_signal(key == Expedition.difficulty)
	for key in profile_buttons:
		profile_buttons[key].set_pressed_no_signal(key == Expedition.profile)




func _launch() -> void:
	if Expedition.has_save():
		_show_page("replace")
		_content.add_child(T.wrap(T.label("Remplacer l'expédition sauvegardée ? La base et les unités de l'opération précédente seront abandonnées.", "Body")))
		_content.add_child(T.button("Remplacer et déployer", _deploy_new, "Danger"))
		_content.add_child(T.button("Conserver ma sauvegarde", func(): _show_page("briefing"), "Ghost"))
		return
	_deploy_new()

func _deploy_new() -> void:
	if not Expedition.clear_session():
		_content.add_child(T.wrap(T.label("Impossible de remplacer la sauvegarde. Elle a été conservée.", "Body", T.RED)))
		return
	Audio.play("dhd")
	get_tree().change_scene_to_file.call_deferred("res://outpost.tscn")


func _options() -> void:
	panel.visible = false
	_sub = SettingsMenu.new()
	_sub.closed.connect(func(): _sub = null; panel.visible = true)
	add_child(_sub)


func _controls() -> void:
	_show_page("controls")
	_content.add_child(T.label("COMMANDER SUR LE TERRAIN", "Section"))
	for entry in [
		["TACTILE", "Touchez une unité pour la sélectionner, puis le terrain pour avancer ou un ennemi pour attaquer. Glissez pour déplacer la caméra. La mini-carte recentre la vue ; + et − règlent le zoom."],
		["SOURIS ET CLAVIER", "Glisser gauche : sélectionner · clic droit : donner un ordre. Bouton milieu : caméra · molette : zoom. Flèches ou ZQSD : caméra. 1–3 : rappeler une escouade · Maj+1–3 : mémoriser. Espace : soldats. Échap : menu."],
		["BASE / SGC / UNITÉS", "Construisez la base, recrutez les renforts par la porte et composez vos escouades. Un médecin soigne à proximité ; un ingénieur répare ; un scientifique étudie les ruines. Placez-les à portée puis choisissez Halte / travailler ici."]
	]:
		_content.add_child(T.label(entry[0], "Caption", T.BLUE))
		_content.add_child(T.wrap(T.label(entry[1], "Body")))
		_content.add_child(HSeparator.new())
	_content.add_child(T.button("Retour au briefing", func(): _show_page("briefing"), "Ghost"))


func _back() -> void:
	get_tree().change_scene_to_file.call_deferred("res://main.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _sub == null:
		_back()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()
