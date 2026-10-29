extends Node
## Test d'intégration de la vue, des commandes et de l'isolation de la campagne.
## --show garde la scène dix secondes pour contrôler le rendu avec --shot.

const Outpost = preload("res://scripts/outpost.gd")
const Cli = preload("res://scripts/cli.gd")
const Sim = preload("res://scripts/outpost_sim.gd")
var checks := 0
var fails := 0


func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		printerr("ÉCHEC VUE RTS : ", text)


func _ready() -> void:
	var campaign: Dictionary = Game.stats.duplicate(true)
	var view := Outpost.new()
	view.persistence_enabled = false
	view.sim = Sim.new({"established": true})
	add_child(view)
	await get_tree().process_frame
	check(view.cam.current and view.selected.size() == 4, "caméra tactique et sélection initiale")
	var camp := {}
	for e in view.sim.entities:
		if e.kind == "camp":
			camp = e
	check(not view.visuals[camp.id].node.visible, "camp invisible en 3D avant reconnaissance")
	check(not view.landmarks[0].node.visible and not view.landmarks[1].node.visible,
		"lieux inconnus masqués dans le monde")
	var picked: Dictionary = view._pick(view.cam.unproject_position(view._world(camp.pos, 1)))
	check(picked.is_empty() or picked.id != camp.id, "sélection ne révèle pas un ennemi caché")
	view._choose_build("generator")
	check(view.build_kind == "generator", "commande de construction")
	var pos: Vector2 = view.cam.unproject_position(view._world(Vector2(11, 18)))
	view._tap(pos)
	check(view.build_kind == "" and view.sim.count("generator", false) == 1, "placement depuis la projection écran")
	view._sync_visuals()
	var generator := {}
	for e in view.sim.entities:
		if e.kind == "generator":
			generator = e
	var generator_visual: Dictionary = view.visuals[generator.id]
	check(generator_visual.site.visible and not generator_visual.model.visible, "chantier distinct du bâtiment achevé")
	view.sim.build("turret", Vector2(11, 14))
	view.sim.build("infirmary", Vector2(8, 14))
	for i in 150:
		view.sim.tick(0.1)
	view._sync_visuals()
	view._update_ui()
	check(not generator_visual.site.visible and generator_visual.model.visible and generator_visual.node.scale == Vector3.ONE,
		"bâtiment terminé affiché sans écraser sa géométrie")
	check(generator_visual.rotor != null and not is_zero_approx(generator_visual.rotor.rotation.y), "ventilateur du générateur animé")
	generator.hp = generator.max_hp * 0.4
	view._sync_visuals()
	check(generator_visual.damage.visible, "débris visibles sur un bâtiment très endommagé")
	generator.hp = generator.max_hp
	view._sync_visuals()
	check(not generator_visual.damage.visible, "état intact rétabli sans modifier les autres instances")
	check(view.visuals.size() == view.sim.entities.size(), "visuels créés pour tous les bâtiments")
	var soldier := view.sim.entity(view.selected[0])
	view._tap(view.cam.unproject_position(view._world(soldier.pos, 1)))
	check(view.selected == [soldier.id], "sélection d'un soldat à l'écran")
	var previous: Vector2 = soldier.pos
	view._tap(view.cam.unproject_position(view._world(Vector2(13, 18))))
	for i in 70:
		view.sim.tick(0.1)
	check(soldier.pos.distance_to(previous) > 2, "déplacement après toucher du terrain")
	view._toggle_pause()
	var clock: float = view.sim.elapsed
	view._process(0.1)
	check(view.sim.elapsed == clock, "pause bloque la simulation")
	view._toggle_pause()
	view._select_all()
	view._sync_visuals()
	view._update_ui()
	var minimap_event := InputEventMouseButton.new()
	minimap_event.button_index = MOUSE_BUTTON_LEFT
	minimap_event.pressed = true
	minimap_event.position = view.minimap.size * 0.5
	view.minimap._gui_input(minimap_event)
	check(view.focus.distance_to(Vector3(31, 0, 23)) < 0.1, "carte recentre la caméra")
	view.focus = Vector3(19, 0, 34)
	view._camera()
	var original_position: Vector2 = soldier.pos
	soldier.pos = camp.pos + Vector2(-4, 0)
	view.sim.update_visibility()
	view._sync_intel()
	view._sync_visuals()
	check(view.visuals[camp.id].node.visible, "reconnaissance révèle le modèle du camp")
	soldier.pos = original_position
	view.sim.update_visibility()
	view._sync_intel()
	view._sync_visuals()
	check(not view.visuals[camp.id].node.visible and view.sim.known_buildings.has(camp.id),
		"modèle caché au retrait, renseignement cartographique conservé")
	view.overlay.effects.clear()
	view.overlay.feedback(Vector3.ZERO, "−10", Color.RED)
	check(view.overlay.effects.size() == 1, "retour visuel de dégâts créé")
	view.overlay.advance(1.0)
	check(view.overlay.effects.is_empty(), "effets temporaires nettoyés")
	view._order_marker(soldier.pos, Color.BLUE)
	check(not view.overlay.effects.is_empty() and view.overlay.effects[0].marker, "ordre confirmé par un marqueur")
	check(Game.stats == campaign, "campagne inchangée après construction, combat et commandes")
	print("Vue RTS : %d/%d vérifications réussies" % [checks - fails, checks])
	if Cli.has("--show"):
		if Cli.has("--combat"):
			var friend := 0
			var foe := 0
			for e in view.sim.entities:
				if e.kind == "soldier":
					e.pos = Vector2(14 + friend % 2, 15 + friend / 2)
					e.path.clear()
					friend += 1
				elif e.kind == "jaffa":
					e.pos = Vector2(18, 14 + foe)
					foe += 1
			view.sim.update_visibility()
			view._sync_intel()
			view._sync_visuals()
			view.focus = Vector3(29, 0, 28)
			view._camera()
		await get_tree().create_timer(10).timeout
	get_tree().quit(1 if fails else 0)
