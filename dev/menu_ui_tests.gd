extends Node
## Audit de disposition sans rendu : écrans logiques normaux et agrandis.
## Ne modifie ni la sauvegarde, ni les réglages persistants.

var checks := 0
var fails := 0


func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		printerr("ÉCHEC UX/UI : ", text)


func settle() -> void:
	for i in 6:
		await get_tree().process_frame


func layout_issues(node: Node) -> Array[String]:
	var issues: Array[String] = []
	if node is Control and not node.is_visible_in_tree():
		return issues
	if node is Button or node is Label:
		var rect: Rect2 = node.get_global_rect()
		var ancestor := node.get_parent()
		var scroll: ScrollContainer
		while ancestor != null:
			if ancestor is ScrollContainer:
				scroll = ancestor
				break
			ancestor = ancestor.get_parent()
		if scroll == null:
			if not get_viewport().get_visible_rect().grow(1).encloses(rect):
				issues.append(node.text.left(50) + " hors écran " + str(rect))
		elif rect.position.x < scroll.global_position.x - 1 or rect.end.x > scroll.get_global_rect().end.x + 1:
			issues.append(node.text.left(50) + " déborde du défilement " + str(rect))
	for child in node.get_children():
		issues.append_array(layout_issues(child))
	return issues


func layout(label: String, node: Node) -> void:
	var issues := layout_issues(node)
	check(issues.is_empty(), label + " : " + "; ".join(issues))


func _ready() -> void:
	await settle()
	var expedition := Expedition.options().duplicate(true)
	var campaign: Dictionary = Game.stats.duplicate(true)
	var settings: Dictionary = Settings._values.duplicate(true)
	var main = load("res://main.tscn").instantiate()
	add_child(main)
	await settle()
	main.set_process(false)
	for dimensions in [Vector2i(1600, 900), Vector2i(1067, 600), Vector2i(1280, 720), Vector2i(853, 480)]:
		get_tree().root.content_scale_factor = 1
		get_tree().root.content_scale_size = dimensions
		get_tree().root.size = dimensions
		await settle()
		main.title_screen.show()
		main.title_screen._main_page()
		await settle()
		layout("titre " + str(dimensions), main.title_screen)
		check(not main.title_screen._head.get_global_rect().intersects(main.title_screen._box.get_global_rect()), "titre et boutons séparés " + str(dimensions))
		main.title_screen._extras()
		await settle()
		layout("extras", main.title_screen)
		main.title_screen._credits()
		await settle()
		layout("crédits", main.title_screen)
		main.title_screen.hide()
		main.sgc.open()
		await settle()
		layout("SGC " + str(dimensions), main.sgc)
		main.sgc._gate_dialog("control")
		await settle()
		layout("contrôle SGC", main.sgc._modal)
		main.sgc.close()
		for tab in ["briefing", "armory", "team", "infirmary"]:
			main.hub.open(tab)
			await settle()
			layout("hub " + tab + " " + str(dimensions), main.hub)
		main.hub.close()
		var options = load("res://scripts/settings_menu.gd").new()
		main.ui.add_child(options)
		await settle()
		for tab in ["display", "graphics", "audio", "game"]:
			options.show_tab(tab)
			await settle()
			layout("options " + tab + " " + str(dimensions), options)
		options.close()
		await settle()
		main.pause_menu.open("ABYDOS", true, true)
		await settle()
		layout("pause campagne", main.pause_menu)
		main.pause_menu._controls()
		await settle()
		layout("commandes campagne", main.pause_menu)
		main.pause_menu.close()
		main._build_hud()
		main.top_bar.show()
		main.title_lbl.text = "ABYDOS // COMBAT EN TEMPS RÉEL"
		main.top_info.text = "NIV 10   XP 1200/3000   NAQUADAH 10000   TROUSSES 3"
		main.sub_panel.show()
		main.sub_name.text = "O'NEILL · COMMANDEMENT"
		main.sub_text.text = "PV 90/90 · SG-1 entière · TEMPS RÉEL\nTouchez le terrain pour avancer, un ennemi pour concentrer les tirs."
		var actions: Array = []
		for title in ["Pause tactique", "SG-1 entière", "Grenade", "Tenir la position", "Trousse · 3", "Repli"]:
			actions.append([title, Color(0.6, 0.8, 1), func(): pass])
		main.action_grid(actions)
		await settle()
		layout("HUD combat " + str(dimensions), main.ui)
		if main._journal_toggle.visible:
			main._journal_toggle.pressed.emit()
			for i in 6:
				main._log("SGC", "Transmission %d de mission longue pour vérifier le défilement et conserver l'accès au journal sur écran compact." % i)
			await settle()
			layout("journal compact", main.hud)
		main.top_bar.hide()
		main.hud.queue_free()
		main.sub_panel.hide()
		main.clear_actions()
		await settle()
		var briefing = load("res://outpost_menu.tscn").instantiate()
		add_child(briefing)
		await settle()
		layout("préparation RTS " + str(dimensions), briefing)
		for page in ["briefing", "forces", "rules"]:
			briefing._show_page(page)
			await settle()
			layout("préparation " + page + " " + str(dimensions), briefing)
		check(briefing.difficulty_buttons.size() == 3, "trois difficultés explicites")
		briefing._controls()
		await settle()
		layout("commandes préparation " + str(dimensions), briefing)
		briefing._show_page("forces")
		briefing._choose_profile("recon")
		check(Expedition.profile == "recon", "équipe choisie conservée")
		briefing._show_page("briefing")
		check("SG-9" in briefing._summary.text, "résumé de déploiement actualisé")
		briefing.queue_free()
		await settle()
		var view = load("res://scripts/outpost.gd").new()
		view.persistence_enabled = false
		view.sim = load("res://scripts/outpost_sim.gd").new({"established": true})
		add_child(view)
		view.set_process(false)
		await settle()
		for tab in ["base", "sgc", "selection"]:
			view._show_command_tab(tab)
			await settle()
			layout("RTS " + tab + " " + str(dimensions), view.ui)
			check(get_viewport().get_visible_rect().encloses(view.minimap.get_global_rect()), "mini-carte accessible " + tab)
		check(not view.minimap.get_parent() is ScrollContainer, "carte hors du défilement")
		var ancestor: Node = view.research_button.get_parent()
		while not ancestor is ScrollContainer:
			ancestor = ancestor.get_parent()
		check((ancestor as ScrollContainer).size.y >= 52, "zone de commandes assez haute pour un bouton")
		view.sim.supplies = 999999
		view.sim.naquadah = 99999
		view._update_ui()
		await settle()
		layout("RTS stocks élevés", view.ui)
		view.multi_select = true
		view._show_command_tab("base")
		check(not view.multi_select, "changement d'onglet quitte la sélection multiple")
		view._save_squad(1)
		view.selected = [view.selected[0]]
		view._save_squad(1)
		view._undo_squad()
		check(view.sim.squad_members(1).size() == 4, "affectation d'escouade annulable")
		view._menu()
		await settle()
		check(view.paused and view._menu_page == "main", "vraie pause RTS")
		var clock: float = view.sim.elapsed
		view._process(0.1)
		check(view.sim.elapsed == clock, "aucun combat derrière le menu")
		layout("pause RTS", view.pause_overlay)
		view._menu_controls()
		await settle()
		layout("commandes RTS", view.pause_overlay)
		view._menu_options()
		await settle()
		layout("options en pause RTS", view.pause_overlay)
		view._menu_dialog.close()
		await settle()
		check(view.paused and view._menu_page == "main", "retour des options sans reprise du combat")
		view._confirm_quit()
		await settle()
		layout("confirmation quitter RTS", view.pause_overlay)
		view._restart()
		await settle()
		layout("confirmation recommencer RTS", view.pause_overlay)
		view._close_menu()
		check(not view.paused, "fermeture reprend une partie active")
		await settle()
		view._toggle_pause()
		view._menu()
		view._close_menu()
		check(view.paused, "pause préexistante conservée")
		await settle()
		check(is_instance_valid(view.ancient_console), "console ancienne intégrée aux ruines RTS")
		view.sim.ruins_studied = true
		view._update_ui()
		check(view.ancient_console.activated, "étude scientifique active la console")
		view.sim.result = "victory"
		view._update_ui()
		await settle()
		check(view._result_shown and is_instance_valid(view.pause_overlay), "écran de résultat automatique")
		layout("résultat RTS", view.pause_overlay)
		view.queue_free()
		await settle()
	Expedition.profile = expedition.profile
	Expedition.difficulty = expedition.difficulty
	check(Game.stats == campaign, "campagne inchangée")
	check(Settings._values == settings, "réglages persistants inchangés")
	check(not Settings.is_active("upscaler"), "FSR désactivé avec le rendu mobile")
	main.queue_free()
	await settle()
	print("Menus UX/UI : %d/%d vérifications réussies" % [checks - fails, checks])
	get_tree().quit(1 if fails else 0)
