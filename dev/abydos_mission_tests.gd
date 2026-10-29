extends "res://scripts/main.gd"
## Parcours réel, sauvegarde isolée. --visual capture les étapes sans toucher aux réglages.
var checks := 0
var fails := 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		printerr("ÉCHEC ABYDOS : ", description)

func _debug_jumps() -> void:
	_close_title()

func encounter(id: String) -> Dictionary:
	for p in planet.pois:
		if p.get("id", "") == id:
			return p
	return {}

func shot(label: String) -> void:
	if not Cli.has("--visual"):
		return
	for i in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/sg1-abydos-" + label + ".png")

func deploy(p: Dictionary) -> void:
	var start: Vector2i = planet._nearest_free(p.tile + Vector2i(-3, 0))
	for member in planet.team:
		member.position = planet.tile_pos(start)
	planet.reveal(p.tile, 5)
	_on_poi(p)
	if planet.combat:
		planet.combat.set_process(false)

func ready_worker(c: Node) -> Dictionary:
	c.begin_work()
	for u in c.units:
		if u.side == "sg1" and u.kind == c.work_kind:
			u.rt_path.clear()
			u.has_move_order = false
			u.tile = planet._nearest_free(c.poi.console + Vector2i(-1, 0))
			u.node.position = planet.tile_pos(u.tile)
			return u
	return {}

func clear_guards(c: Node) -> void:
	for u in c.units:
		if u.side == "foe" and not u.get("boss", false):
			c._damage(u, 9999)

func readability_layout() -> void:
	var root := get_tree().root
	var previous_size := root.size
	var previous_scale_size := root.content_scale_size
	for dimensions in [Vector2i(1600, 900), Vector2i(1067, 600), Vector2i(853, 480)]:
		root.content_scale_size = dimensions
		root.size = dimensions
		for i in 6:
			await get_tree().process_frame
		_fit_mission_ui()
		var bounds := get_viewport().get_visible_rect().grow(1)
		check(bounds.encloses(_mission_objective_panel.get_global_rect()), "objectif et progression dans l'écran " + str(dimensions))
		check(not _mission_objective_panel.get_global_rect().intersects(bottom.get_global_rect()), "objectif séparé des commandes " + str(dimensions))
		await shot("layout-%d" % dimensions.x)
	root.content_scale_size = previous_scale_size
	root.size = previous_size
	for i in 6:
		await get_tree().process_frame

func _ready() -> void:
	check(Data.mission_loss(100, 120, "easy") == 0, "facile protège tous les gains")
	check(Data.mission_loss(100, 123, "normal") == 5, "normal ne taxe que les gains et arrondit au-dessous")
	check(Data.mission_loss(100, 123, "hard") == 11, "difficile ne taxe que les gains")
	check(Data.mission_loss(100, 80, "hard") == 0, "aucune perte supplémentaire sans gain")
	var original_save := Game.save_path
	var original_stats: Dictionary = Game.stats.duplicate(true)
	var original_team: Array = Game.team.duplicate()
	var saved_text := FileAccess.get_file_as_string(original_save) if FileAccess.file_exists(original_save) else ""
	Game.save_path = "user://abydos_mission_test.json"
	Game.stats = Game._fresh()
	Game.refresh_team()
	super._ready()
	current = 0
	planet = PlanetScript.new()
	add_child(planet)
	planet.setup(0, Game.team, 42)
	planet.input_locked = false
	planet.set_process(false)
	planet.poi_reached.connect(_on_poi)
	planet.gate_near.connect(_on_gate_near)
	planet.cam.current = true
	_planet_env(Data.PLANETS[0])
	_build_hud()
	room.hide()
	gate.hide()
	sgc.close()
	hub.close()
	check(planet.mission != null and planet.mission.next_id() == "kasuf", "nouvelle opération : contacter Kasuf")
	check(planet.pois.size() == 5, "carte d'Abydos scénarisée")
	for p in planet.pois:
		check(not planet.grid.get_id_path(planet.START, p.tile).is_empty(), "objectif accessible : " + p.id)
	_on_poi(encounter("klorel"))
	check(planet.combat == null and not planet.mission.recovered, "Klorel inaccessible avant traduction")
	_on_poi(encounter("translation"))
	check(planet.combat == null, "Kasuf requis avant l'intervention")
	_on_poi(encounter("kasuf"))
	check(planet.mission.contacted and encounter("kasuf").done, "contact déterministe de Kasuf")
	check(planet.mission.next_id() == "translation", "objectif Daniel affiché")
	await shot("01-contact")
	deploy(encounter("translation"))
	var c = planet.combat
	check(c != null and c._work_member() == "daniel", "rencontre de traduction réelle")
	for u in c.units:
		if u.side == "sg1" and u.kind == "daniel":
			c._damage(u, 9999)
	c._check_end()
	check(planet.combat == null and not planet.mission.translated and not encounter("translation").done, "Daniel KO : repli sans valider la traduction")
	check(Game.stats.hp.daniel > 0 and planet.leader_tile == planet.START, "spécialiste remis debout près de la porte")
	deploy(encounter("translation"))
	c = planet.combat
	var worker := ready_worker(c)
	check(not worker.is_empty(), "ordre d'intervention à Daniel")
	c.toggle_tactical_pause()
	c.advance(10)
	check(c.work_progress == 0 and not planet.mission.translated, "pause : aucune progression du spécialiste")
	c.toggle_tactical_pause()
	c._advance_work(3)
	check(is_equal_approx(c.work_progress, 3), "progression partielle de traduction")
	c.refresh_panel()
	check(is_equal_approx(_mission_work_bar.value, 50) and _mission_work_bar.max_value == 100, "barre d'intervention à mi-parcours")
	worker.stun = 1.0
	c._advance_work(1)
	check(c.work_progress == 0, "étourdissement : intervention interrompue")
	check("ÉTOURDI" in c.work_status().text and c.work_status().value == 0, "interruption expliquée au joueur")
	worker.stun = 0.0
	c._hold()
	check(c.work_kind.is_empty(), "halte annule le travail")
	worker = ready_worker(c)
	c.on_tap(planet._nearest_free(worker.tile + Vector2i(2, 0)))
	check(c.work_kind.is_empty(), "nouvel ordre de déplacement annule l'intervention")
	worker = ready_worker(c)
	clear_guards(c)
	check(not c._check_end() and planet.combat != null, "gardes vaincus : traduction toujours requise")
	c._advance_work(6.1)
	check(planet.mission.translated and planet.mission.next_id() == "klorel", "traduction terminée : relais de Klorel révélé")
	c._check_end()
	check(planet.combat == null and encounter("translation").done, "retour à l'exploration après traduction")
	deploy(encounter("klorel"))
	c = planet.combat
	check(c != null and c._work_member() == "carter", "affrontement de Klorel : intervention de Carter")
	var boss_unit := {}
	for u in c.units:
		if u.get("boss", false):
			boss_unit = u
	var hp_before := int(boss_unit.hp)
	c._damage(boss_unit, 9999)
	check(boss_unit.hp == hp_before, "bouclier bloque les dégâts directs")
	check(c.feedback.shields[boss_unit.index].visible, "bouclier de Klorel visible avant coupure")
	worker = ready_worker(c)
	c._advance_work(2)
	c.toggle_tactical_pause()
	check("PAUSE" in _mission_work_status.text and is_equal_approx(_mission_work_bar.value, 100.0 / 3), "pause visible et progression conservée")
	check("Arme suspendue" in c.targeting_info(worker), "spécialiste : arme suspendue clairement annoncée")
	await readability_layout()
	await shot("02-intervention")
	c.select(0)
	c.on_tap(boss_unit.tile)
	check("BOUCLIER ACTIF" in c.targeting_info(c.units[0]), "cible protégée : aucune probabilité trompeuse")
	await shot("02a-cible")
	c.select(worker.index)
	c.advance(10)
	check(is_equal_approx(c.work_progress, 2), "pause de Carter : progression figée")
	c.toggle_tactical_pause()
	c._advance_work(4.1)
	check(planet.mission.shield_disabled, "Carter coupe le bouclier après six secondes")
	check("Bouclier coupé" in planet.mission.objective() and encounter("klorel").console_label.text == "BOUCLIER COUPÉ", "objectif et relais reflètent la réussite de Carter")
	check(not c.feedback.shields[boss_unit.index].visible, "enveloppe du bouclier retirée dès sa coupure")
	c.select(0)
	c.on_tap(boss_unit.tile)
	check("tir " in c.targeting_info(c.units[0]) and "BOUCLIER ACTIF" not in c.targeting_info(c.units[0]), "cible vulnérable : précision affichée")
	await shot("02b-vulnerable")
	c._damage(boss_unit, 1)
	check(boss_unit.hp == hp_before - 1, "Klorel vulnérable après intervention")
	clear_guards(c)
	c._damage(boss_unit, 9999)
	c._check_end()
	check(planet.mission.recovered and Game.stats.done == 0, "Skaara récupéré : aucune libération avant extraction")
	await shot("03-extraction")
	planet.leader_tile = Vector2i(4, 3)
	planet.input_locked = true
	leave_planet()
	check(Game.stats.done == 0, "extraction refusée pendant une transition")
	planet.input_locked = false
	planet.leader_tile = Vector2i(9, 9)
	leave_planet()
	check(Game.stats.done == 0, "extraction refusée loin du DHD")
	planet.leader_tile = Vector2i(4, 3)
	leave_planet() # Le préambule valide puis lance l'animation ; on nettoie la scène juste après.
	check(planet.mission.extracted and Game.stats.done == 1, "extraction au DHD débloque Chulak")
	_end_planet()
	Game.save_path = original_save
	Game.stats = original_stats
	Game.team = original_team
	check((FileAccess.get_file_as_string(original_save) if FileAccess.file_exists(original_save) else "") == saved_text, "sauvegarde utilisateur intacte")
	print("Mission Abydos : %d/%d vérifications réussies" % [checks - fails, checks])
	get_tree().quit(1 if fails else 0)
