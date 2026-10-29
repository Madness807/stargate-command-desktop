extends Node
## Arrival, reconnaissance, engineering convoy, menu and campaign isolation.

const Sim = preload("res://scripts/outpost_sim.gd")
const Outpost = preload("res://scripts/outpost.gd")
const Menu = preload("res://scripts/outpost_menu.gd")
var checks := 0
var fails := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		printerr("ÉCHEC EXPÉDITION : ", what)


func advance(s: RefCounted, seconds: float) -> void:
	for i in int(seconds * 10):
		s.tick(0.1)


func clear_landing(s: RefCounted) -> void:
	for e in s.entities:
		if e.side == "enemy" and e.pos.distance_to(Sim.HQ_SITE) < 6:
			e.hp = 0
		elif e.kind == "soldier":
			e.path.clear()
			e.pos = Sim.HQ_SITE + Vector2(0, 1)
	s.tick(1.0)
	s.update_visibility()


func _ready() -> void:
	var campaign: Dictionary = Game.stats.duplicate(true)
	_test_arrival()
	_test_deployment()
	_test_loss()
	_test_occupied_hq()
	_test_profiles()
	_test_landscape()
	await _test_menu()
	await _test_view()
	await _test_compact_controls()
	check(Game.stats == campaign, "campagne inchangée par l'expédition et son menu")
	print("Expédition : %d/%d vérifications réussies" % [checks - fails, checks])
	get_tree().quit(1 if fails else 0)


func _test_arrival() -> void:
	var s := Sim.new()
	check(s.phase == "arrival" and s.count("soldier") == 0 and s.count("hq", false) == 0,
		"aucune troupe ni base téléportée au lancement")
	check(not s.build("generator", Vector2(8, 18)) and not s.reinforce(), "construction et renforts bloqués avant le déploiement")
	advance(s, 1.7)
	check(not s.gate_open() and s.count("soldier") == 0, "composition avant ouverture de la porte")
	advance(s, 1.7)
	check(s.gate_open() and s.count("soldier") == 1, "premier membre après stabilisation du vortex")
	var first := {}
	for e in s.entities:
		if e.kind == "soldier":
			first = e
	var goal: Vector2 = first.goal
	s.order([first.id], Vector2(20, 20))
	check(first.goal == goal, "pas d'ordre pendant la courte mise en scène")
	advance(s, 5)
	check(s.phase == "recon" and s.count("soldier") == 4 and s.count("hq", false) == 0,
		"contrôle de la première équipe avant toute base")
	var names := []
	for e in s.entities:
		if e.kind == "soldier":
			names.append(e.member)
	check(names == ["oneill", "carter", "daniel", "tealc"], "SG-1 franchit la porte dans l'ordre")
	check(not s.request_deployment(), "pas de convoi avant reconnaissance et sécurisation")
	var resources: float = s.supplies
	var raid: float = s.raid_in
	advance(s, 60)
	check(s.supplies == resources and s.raid_in == raid and s.wave == 0,
		"pas de revenu ni de vagues avant l'installation")


func _test_deployment() -> void:
	var s := Sim.new()
	s.skip_arrival()
	var ids := []
	for e in s.entities:
		if e.kind == "soldier":
			ids.append(e.id)
	s.order(ids, Sim.HQ_SITE + Vector2(0, 1))
	advance(s, 18)
	check(s.landing_scanned and s.landing_secure(), "l'équipe atteint la clairière et élimine les gardes en temps réel")
	if not s.landing_secure():
		printerr("État de la clairière : ", s.phase, " / ", s.result)
		for e in s.entities:
			printerr(e.kind, " ", e.pos, " PV ", e.hp)
		return
	check(s.count("hq", false) == 0, "la sécurisation ne crée pas encore de commandement")
	check(s.request_deployment() and s.phase == "deployment" and s.gate_job == "deployment", "demande explicite de déploiement")
	check(not s.request_deployment() and not s.reinforce(), "convoi unique, pas de renfort militaire prématuré")
	advance(s, 11)
	check(s.gate_open() and s.count("engineer") == 0 and s.count("hq", false) == 0, "porte prête avant le franchissement du convoi")
	advance(s, 5)
	check(s.count("engineer") == 2 and s.convoy_arrived(), "deux ingénieurs traversent la porte")
	check(s.phase == "establish" and s.count("hq", false) == 1 and s.count("hq") == 0, "chantier installé après arrivée physique des ingénieurs")
	var hq := {}
	for e in s.entities:
		if e.kind == "hq":
			hq = e
	var remaining: float = hq.build
	for e in s.entities:
		if e.kind == "engineer":
			e.pos = Vector2(2, 22)
			e.path.clear()
	advance(s, 2)
	check(is_equal_approx(hq.build, remaining), "chantier suspendu si les ingénieurs sont éloignés")
	for e in s.entities:
		if e.kind == "engineer":
			e.pos = Sim.HQ_SITE + Vector2(0, 2)
	advance(s, 15)
	check(s.phase == "base" and s.count("hq") == 1, "avant-poste opérationnel après construction")
	check(s.build("generator", Vector2(11, 18)), "construction débloquée après installation")
	check(s.reinforce(), "renforts militaires débloqués après installation")
	var soldiers := s.count("soldier")
	advance(s, 19)
	check(s.count("soldier") > soldiers and s.gate_busy(), "renforts sortent progressivement de la porte")
	advance(s, 4)
	check(s.count("soldier") == soldiers + 3 and not s.gate_busy(), "porte libérée après sortie du dernier renfort")


func _test_loss() -> void:
	var s := Sim.new()
	s.skip_arrival()
	for e in s.entities:
		if e.kind == "soldier":
			e.hp = 0
	s.tick(0.1)
	check(s.result == "defeat", "défaite si la première équipe est perdue avant la base")
	var convoy := Sim.new()
	convoy.skip_arrival()
	clear_landing(convoy)
	check(convoy.request_deployment(), "convoi de test autorisé")
	advance(convoy, 17)
	for e in convoy.entities:
		if e.kind == "engineer":
			e.hp = 0
	convoy.tick(0.1)
	check(convoy.result == "defeat", "perte des ingénieurs : pas de chantier bloqué indéfiniment")


func _test_occupied_hq() -> void:
	var s := Sim.new()
	s.skip_arrival()
	clear_landing(s)
	var ids := []
	for e in s.entities:
		if e.kind == "soldier":
			e.pos = Sim.HQ_SITE
			ids.append(e.id)
	check(s.request_deployment(), "convoi autorisé avec l'équipe sur le futur chantier")
	advance(s, 30)
	check(s.phase == "base", "chantier terminé malgré les occupants initiaux")
	var cells := {}
	for id in ids:
		var unit: Dictionary = s.entity(id)
		var cell := Vector2i(unit.pos.round())
		check(not s.grid.is_point_solid(cell) and not cells.has(cell), "occupant évacué vers une case libre distincte")
		cells[cell] = true
		var before: Vector2 = unit.pos
		s.order([id], Vector2(13, 20))
		advance(s, 0.5)
		check(unit.pos.distance_to(before) > 0.1, "soldat évacué encore déplaçable")


func _test_profiles() -> void:
	var s := Sim.new({"established": true, "profile": "assault", "difficulty": "hard"})
	check(s.supplies == 260 and s.difficulty == "hard", "dotation et difficulté appliquées")
	for e in s.entities:
		if e.kind == "soldier":
			check(e.max_hp == 110, "profil assaut : protection renforcée")
	var fallback := Sim.new({"profile": "invalid", "difficulty": "invalid"})
	check(fallback.profile == "balanced" and fallback.difficulty == "normal", "options inconnues bornées")


func _test_landscape() -> void:
	var landscape = preload("res://scripts/outpost_landscape.gd")
	for point in [Vector2(-1, -1), Vector2(63, 47), Vector2(31, 23), Vector2(8, 38)]:
		check(is_equal_approx(landscape.height_at(point), -0.05), "zone jouable conservée plane")
	check(landscape.height_at(Vector2(-50, 23)) > 1, "relief présent hors de la grille")
	var ground := landscape.build(null)
	var bounds := ground.mesh.get_aabb()
	check(bounds.position.x < -150 and bounds.end.x > 200 and bounds.position.z < -150 and bounds.end.z > 200,
		"paysage étendu au-delà des positions extrêmes de caméra")
	ground.free()
	var s := Sim.new()
	check(s.grid.region == Rect2i(Vector2i.ZERO, Sim.SIZE), "paysage sans agrandissement de la grille de simulation")


func _test_menu() -> void:
	var original := Expedition.options()
	var menu := Menu.new()
	add_child(menu)
	await get_tree().process_frame
	check(menu.get_global_rect().encloses(menu.panel.get_global_rect()), "panneau de préparation contenu dans l'écran")
	menu._show_page("forces")
	menu._choose_profile("recon")
	check(Expedition.profile == "recon" and menu.details.text.contains("80 PV"), "choix d'équipe reflété dans le briefing")
	var previous: String = Expedition.difficulty
	menu._cycle_difficulty()
	check(Expedition.difficulty != previous, "difficulté modifiable dans le menu RTS")
	menu._show_page("rules")
	check("après la mise en service du commandement" in menu._difficulty.text and "arrêté pendant" in menu._difficulty.text, "annonce exacte du départ du compte à rebours")
	menu._show_page("briefing")
	check(menu._page == "briefing" and menu._content.get_child_count() > 3, "rapport de reconnaissance consultable")
	var configured := Sim.new(Expedition.options())
	check(configured.profile == "recon" and configured.difficulty == Expedition.difficulty, "préparation transmise à l'expédition")
	Expedition.profile = original.profile
	Expedition.difficulty = original.difficulty
	menu.free()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1100, 600)
	add_child(viewport)
	var compact := Menu.new()
	viewport.add_child(compact)
	await get_tree().process_frame
	check(compact.get_global_rect().encloses(compact.panel.get_global_rect()), "briefing défilable sans débordement à grande échelle d'interface")
	viewport.free()


func _test_view() -> void:
	var view := Outpost.new()
	view.persistence_enabled = false
	view.sim = Sim.new()
	add_child(view)
	view.set_process(false)
	await get_tree().process_frame
	check(view.selected.is_empty() and not view.cargo.visible, "pas d'équipe ni de caisses préinstallées dans la vue")
	check(view.skip_button.visible and view.reinforcements.disabled and view.build_buttons.generator.disabled,
		"interface adaptée à l'arrivée")
	view.sim.skip_arrival()
	view._sync_visuals()
	view._update_gate()
	view._update_ui()
	check(view.selected.size() == 4 and view.site_marker.visible and not view.skip_button.visible,
		"équipe sélectionnée et objectif de reconnaissance visible après le passage")
	clear_landing(view.sim)
	view._update_ui()
	check(not view.deployment_button.disabled, "appel SGC accessible après sécurisation")
	view.deployment_button.pressed.emit()
	check(view.sim.phase == "deployment", "bouton d'appel déclenche le convoi")
	advance(view.sim, 17)
	view._sync_visuals()
	view._update_gate()
	check(view.cargo.visible and view.sim.count("engineer") == 2, "ingénieurs et cargaison visibles après franchissement")
	view.free()


func _test_compact_controls() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1067, 600)
	add_child(viewport)
	var view := Outpost.new()
	view.persistence_enabled = false
	view.sim = Sim.new({"established": true})
	viewport.add_child(view)
	view.set_process(false)
	await get_tree().process_frame
	await get_tree().process_frame
	var ancestor := view.research_button.get_parent()
	while not ancestor is ScrollContainer and ancestor != null:
		ancestor = ancestor.get_parent()
	var scroll := ancestor as ScrollContainer
	scroll.ensure_control_visible(view.research_button)
	await get_tree().process_frame
	check(Rect2(Vector2.ZERO, Vector2(viewport.size)).encloses(view.research_button.get_global_rect()), "recherche accessible par défilement sur écran compact")
	check(scroll.get_global_rect().encloses(view.research_button.get_global_rect()), "bouton de recherche entièrement dans la zone défilante")
	view.selected.clear()
	view.pause_button.grab_focus()
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	viewport.push_input(key, true)
	key = key.duplicate()
	key.pressed = false
	viewport.push_input(key, true)
	await get_tree().process_frame
	check(view.selected.size() == 4 and not view.paused, "Espace sélectionne sans activer le bouton Pause focalisé")
	var clock: float = view.sim.elapsed
	for i in 50:
		view._process(0.2)
	check(is_equal_approx(view.sim.elapsed - clock, 10.0), "5 FPS : dix secondes réelles donnent dix secondes simulées")
	view.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	clock = view.sim.elapsed
	view._process(0.2)
	check(view.paused and view.sim.elapsed == clock, "perte de focus : simulation RTS en pause")
	view.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	check(view.paused, "retour au jeu sans reprise automatique du combat")
	view._toggle_pause()
	view._process(5.0)
	check(view.paused and view.sim.elapsed == clock, "longue interruption sans rattrapage de combat")
	viewport.free()
