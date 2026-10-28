extends Node
## Navigation de la coupe, services et intégration ; jamais la vraie sauvegarde.
const Walk = preload("res://scripts/sgc_walk.gd")
const Main = preload("res://scripts/main.gd")
const Data = preload("res://scripts/data.gd")
const Layout = preload("res://scripts/sgc_layout.gd")
var checks := 0
var fails := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		printerr("ÉCHEC SGC : ", message)


func advance(walk: Control, seconds: float) -> void:
	for i in int(seconds * 10):
		walk.advance(0.1)


func _ready() -> void:
	var previous_stats: Dictionary = Game.stats.duplicate(true)
	var previous_team: Array = Game.team.duplicate()
	var previous_path: String = Game.save_path
	var previous_contents := FileAccess.get_file_as_string(previous_path) if FileAccess.file_exists(previous_path) else ""
	Game.save_path = "user://test_sgc_sandbox.json"
	Game.stats = Game._fresh()
	Game.refresh_team()
	_test_navigation()
	await _test_compact()
	await _test_integration()
	Game.stats = previous_stats
	Game.team = previous_team
	Game.save_path = previous_path
	var contents := FileAccess.get_file_as_string(previous_path) if FileAccess.file_exists(previous_path) else ""
	check(contents == previous_contents, "vraie sauvegarde inchangée")
	print("SGC navigable : %d/%d vérifications réussies" % [checks - fails, checks])
	get_tree().quit(1 if fails else 0)


func _test_navigation() -> void:
	var walk := Walk.new()
	add_child(walk)
	walk.set_process(false)
	walk.open()
	var requests := []
	walk.room_requested.connect(func(key): requests.append(key))
	check(Walk.FLOOR_NUMBERS[walk.level] == 28 and walk.nearest_room() == "gate", "arrivée dans la salle de la porte au niveau 28")
	var stats: Dictionary = Game.stats.duplicate(true)
	check(not walk.navigate("absent"), "salle inconnue refusée")
	for key in ["briefing", "infirmary", "armory", "team"]:
		check(walk.navigate(key), "trajet accepté : " + key)
		advance(walk, 20)
		check(walk.route.is_empty() and walk.level == Walk.ROOMS[key].level, "trajet terminé au bon étage : " + key)
		check(requests[-1] == key and requests.count(key) == 1, "interaction émise une seule fois : " + key)
		check(walk.player == Vector2(Walk.ROOMS[key].x, Walk.FLOORS[walk.level]), "personnage au point d'interaction : " + key)
	check(Game.stats == stats, "marcher ne modifie pas les ressources ni les PV")
	walk.travel_floor(Layout.GATE_LEVEL)
	advance(walk, 20)
	check(walk.player == Vector2(Walk.LIFT_X, Layout.SPAWN.y), "ascenseur accessible depuis une salle")
	walk.interact()
	check(requests.size() == 4, "aucun service à distance depuis l'ascenseur")
	walk.travel_floor(0)
	walk.advance(0.5)
	check(walk.player.x == Walk.LIFT_X and walk.player.y < Layout.SPAWN.y and walk.player.y > Walk.FLOORS[0], "déplacement vertical réel, pas de téléportation d'étage")
	walk.close()
	check(walk.route.is_empty() and walk.player.y == Walk.FLOORS[walk.level], "fermeture pendant transfert : personnage ramené à un palier sûr")
	var position: Vector2 = walk.player
	walk.advance(3, 1)
	check(walk.player == position, "navigation inactive lorsque l'écran est fermé")
	walk.open()
	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	walk._input(key)
	walk._process(0.1)
	walk._process(0.1)
	check(is_equal_approx(walk.player.x - position.x, 46), "touche maintenue : déplacement continu")
	key.pressed = false
	walk._input(key)
	position = walk.player
	walk._process(0.1)
	check(walk.player == position, "relâchement de touche : arrêt immédiat")
	walk.advance(100, 1)
	check(walk.player.x == Layout.walk_limit(walk.level), "limite du couloir à droite")
	walk.advance(100, -1)
	check(walk.player.x == Walk.LIFT_X, "limite du couloir à gauche")
	walk.toggle_overview()
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = walk._origin + walk.room_rect("infirmary").get_center() * walk._scale
	walk._gui_input(mouse)
	check(walk.destination_room == "infirmary", "toucher une salle planifie le bon parcours")
	advance(walk, 20)
	check(requests[-1] == "infirmary", "trajet tactile mène au service demandé")
	walk.prepared_mission = 0
	walk.navigate("gate", false)
	advance(walk, 20)
	check(walk._modal == null and walk.nearest_room() == "gate", "mission préparée : marche vers la porte sans départ automatique")
	walk.interact()
	check(walk._modal != null, "confirmation de départ présentée près de la porte")
	position = walk.player
	walk.advance(1, -1)
	check(walk.player == position, "dialogue modal bloque le déplacement")
	key.keycode = KEY_ESCAPE
	key.pressed = true
	walk._input(key)
	check(walk._modal == null and walk.visible, "Échap ferme le dialogue sans quitter le SGC")
	walk.navigate("briefing")
	walk.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	position = walk.player
	walk.advance(2)
	check(walk.player == position and walk.route.is_empty(), "interruption arrête aussi le trajet automatique")
	walk.reset_visit()
	check(walk.prepared_mission == -1 and walk.level == Layout.GATE_LEVEL and walk.player == Layout.SPAWN, "nouvelle partie réinitialise la visite et la destination")
	_test_layout(walk)
	walk.free()


func _test_layout(walk: Control) -> void:
	for pair in [["daniel", 18], ["infirmary", 21], ["mess", 22], ["malp", 24], ["team", 25], ["office", 27], ["briefing", 27], ["armory", 28], ["control", 28], ["gate", 28]]:
		check(Walk.FLOOR_NUMBERS[Walk.ROOMS[pair[0]].level] == pair[1], "répartition documentée : " + pair[0])
	var gate: Rect2 = walk.room_rect("gate")
	check(gate.position.y <= walk.room_rect("briefing").position.y and gate.end.y == Walk.FLOORS[Layout.GATE_LEVEL], "salle de la porte en double hauteur sur N27–28")
	walk.open()
	walk.navigate("briefing", false)
	check(walk.route.has(Layout.STAIR_LANDING) and not walk.route.has(Vector2(Walk.LIFT_X, Layout.SPAWN.y)), "trajet porte–briefing par l'escalier")
	var cabin: float = walk.cabin_y
	advance(walk, 20)
	check(walk.cabin_y == cabin, "l'escalier ne déplace pas la cabine d'ascenseur")
	walk.advance(100, 1)
	check(walk.player.x == 930, "pas de marche dans le vide de la salle de la porte au N27")
	walk.navigate("control", false)
	check(walk.route.has(Layout.STAIR_LANDING), "escalier utilisable en descente")
	advance(walk, 20)
	for key in ["office", "malp", "mess", "daniel"]:
		walk.navigate(key)
		advance(walk, 25)
		check(walk._modal != null and walk.route.is_empty(), "salle secondaire visitable : " + key)
		walk._close_modal()


func _test_compact() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1067, 600)
	add_child(viewport)
	var walk := Walk.new()
	viewport.add_child(walk)
	walk.open()
	walk.set_process(false)
	await get_tree().process_frame
	await get_tree().process_frame
	var screen := Rect2(Vector2.ZERO, Vector2(viewport.size))
	check(screen.encloses(walk.footer.get_global_rect()), "panneau de commandes entièrement contenu sur écran compact")
	for button in walk.find_children("*", "Button", true, false):
		check(screen.encloses(button.get_global_rect()), "commande contenue sur écran compact : " + button.text)
	walk.toggle_overview()
	for room in Walk.ROOMS:
		var rect: Rect2 = walk.room_rect(room)
		var drawn := Rect2(walk._origin + rect.position * walk._scale, rect.size * walk._scale)
		check(screen.encloses(drawn), "salle visible sur écran compact : " + room)
	walk.interact()
	await get_tree().process_frame
	await get_tree().process_frame
	for button in walk._modal.find_children("*", "Button", true, false):
		check(screen.encloses(button.get_global_rect()), "dialogue de porte contenu sur écran compact : " + button.text)
	viewport.free()


func _test_integration() -> void:
	var main := Main.new()
	add_child(main)
	await get_tree().process_frame
	main._close_title()
	Audio.loop_stop("theme", 0)
	Audio.loop_stop("horizon", 0)
	main.show_menu()
	check(main.sgc.visible and not main.hub.visible, "SGC navigable remplace le menu par défaut")
	check(not main.room.visible and not main.gate.visible and not main.wormhole.visible, "décor 3D masqué derrière la coupe 2D")
	main._open_sgc_room("armory")
	check(main.hub.visible and main.hub.tab == "armory" and not main.sgc.visible, "armurerie reliée au service existant")
	check(main.hub.location_label.text.ends_with("28"), "armurerie identifiée N28 dans son panneau")
	main.return_to_sgc()
	check(main.sgc.visible and not main.hub.visible, "retour du service au couloir")
	check(not main.prepare_mission(-1) and not main.prepare_mission(99) and not main.prepare_mission(2), "missions invalides et verrouillées refusées")
	main._open_sgc_room("briefing")
	main.hub.sel = 0
	main.hub.launch()
	check(main.sgc.prepared_mission == 0 and main.sgc.visible, "briefing prépare la destination et rend la main au SGC")
	check(main.sgc.destination_room == "gate" and not main.sgc.auto_interact, "équipe dirigée vers la porte sans lancer la cinématique")
	check(not main.busy and main.planet == null, "préparation ne démarre pas de mission prématurément")
	main.sgc.stop()
	Game.stats.hp.oneill = 1
	var naq: int = Game.stats.naq
	var kits: int = Game.stats.kits
	main._open_sgc_room("infirmary")
	check(main.hub.location_label.text.ends_with("21"), "infirmerie identifiée N21 dans son panneau")
	var heal: Button
	for button in main.hub.find_children("*", "Button", true, false):
		if button.text == "SOIGNER SG-1 · GRATUIT":
			heal = button
	check(heal != null and not heal.disabled, "infirmerie propose des soins si SG-1 est blessée")
	if heal != null:
		heal.pressed.emit()
	check(Game.stats.hp.oneill == Game.hp_max("oneill") and Game.stats.naq == naq and Game.stats.kits == kits, "soins gratuits sans consommer de trousses")
	main.return_to_sgc()
	main.show_title()
	check(not main.sgc.visible and main.title_screen != null, "écran titre masque la coupe du SGC")
	main._leave_title()
	check(main.sgc.visible and main.title_screen == null, "continuer ramène au SGC navigable")
	main.sgc.navigate("gate", false)
	advance(main.sgc, 20)
	main.sgc.interact()
	var launch: Button
	for button in main.sgc._modal.find_children("*", "Button", true, false):
		if button.text == "Autoriser le départ":
			launch = button
	check(launch != null, "bouton d'autorisation disponible après préparation")
	if launch != null:
		launch.pressed.emit()
	check(main.current == 0 and main.busy, "confirmation de porte lance réellement la composition d'Abydos")
	check(not main.sgc.visible and not main.hub.visible and main.busy, "départ ferme les deux interfaces et garde la transition 3D")
	check(main.room.visible and main.gate.visible and main.wormhole.visible, "décor 3D réactivé au départ")
	main.free()
