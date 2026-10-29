extends "res://scripts/main.gd"
## Sauvegardes réelles sur disque, chemins isolés ; aucune écriture dans les parties utilisateur.
const Store = preload("res://scripts/session_save.gd")
const OutpostSim = preload("res://scripts/outpost_sim.gd")
var checks := 0
var fails := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		printerr("ÉCHEC REPRISE : ", message)

func _debug_jumps() -> void:
	_close_title()

func settle() -> void:
	for i in 4:
		await get_tree().process_frame

func poi(id: String) -> Dictionary:
	for p in planet.pois:
		if p.get("id", "") == id:
			return p
	return {}

func _ready() -> void:
	var original_path := Game.save_path
	var original_exp_path := Expedition.save_path
	var campaign_bytes := FileAccess.get_file_as_bytes(original_path) if FileAccess.file_exists(original_path) else PackedByteArray()
	var expedition_bytes := FileAccess.get_file_as_bytes(original_exp_path) if FileAccess.file_exists(original_exp_path) else PackedByteArray()
	Game.save_path = "user://test_session_campaign.json"
	Expedition.save_path = "user://test_session_expedition.json"
	Game.mission_capture = Callable()
	Game.new_game()
	super._ready()
	set_process(false)
	# Compatibilité avec une sauvegarde ne contenant que la progression de campagne.
	var old := Game._fresh()
	old.version = 1
	old.naq = 123
	Store.write(Game.save_path, old)
	Game.load_game()
	check(Game.stats.naq == 123 and Game.mission_state.is_empty(), "ancienne sauvegarde de campagne conservée")
	Game.new_game()
	current = 0
	planet = PlanetScript.new()
	add_child(planet)
	planet.setup(0, Game.team, 742)
	planet.input_locked = false
	planet.set_process(false)
	planet.poi_reached.connect(_on_poi)
	planet.gate_near.connect(_on_gate_near)
	_build_hud()
	hub.close()
	sgc.close()
	_mission_entry_naq = 17
	Game.mission_capture = Callable(self, "capture_mission")
	_on_poi(poi("kasuf"))
	_on_poi(poi("translation"))
	var combat = planet.combat
	combat.set_process(false)
	combat.begin_work()
	var worker := {}
	for unit in combat.units:
		if unit.kind == "daniel" and unit.side == "sg1":
			worker = unit
	worker.rt_path.clear()
	worker.tile = Vector2i(5, 11)
	worker.node.position = planet.tile_pos(worker.tile)
	combat._advance_work(2.5)
	combat.units[0].cd = 4.2
	combat.units[0].queued = {"kind": "grenade", "tile": Vector2i(7, 10)}
	combat.units[-1].hp = 7
	combat.units[-1].stun = 1.2
	combat.combat_clock = 8.75
	_process(5.1)
	check(Store.unpack(Store.read(Game.save_path).mission).combat.work_progress == 2.5, "sauvegarde automatique après cinq secondes")
	combat.units[0].cd = 3.9
	_notification(NOTIFICATION_APPLICATION_PAUSED)
	check(is_equal_approx(Store.unpack(Store.read(Game.save_path).mission).combat.units[0].cd, 3.9), "mise en arrière-plan enregistrée immédiatement")
	combat.units[0].cd = 4.2
	check(save_checkpoint(), "sauvegarde du combat sur disque")
	var expected: Dictionary = combat.snapshot()
	var next_random: int = combat.random.randi()
	var before := FileAccess.get_file_as_string(Game.save_path)
	_end_planet(false)
	await settle()
	Game.stats = Game._fresh()
	Game.mission_state = {}
	Game.load_game()
	_continue_campaign()
	combat = planet.combat
	combat.set_process(false)
	planet.set_process(false)
	check(_mission_entry_naq == 17, "réserve initiale préservée à la reprise pour calculer la perte")
	check(combat != null and combat.tactical_paused, "reprise de la mission en pause tactique")
	check(planet.mission.contacted and not planet.mission.translated and poi("kasuf").done, "objectifs et lieux déjà résolus restaurés")
	check(combat.work_kind == "daniel" and is_equal_approx(combat.work_progress, 2.5), "traduction partielle restaurée")
	check(combat.units[-1].hp == 7 and is_equal_approx(combat.units[-1].stun, 1.2), "PV et étourdissement ennemi restaurés")
	check(is_equal_approx(combat.units[0].cd, 4.2) and combat.units[0].queued == expected.units[0].queued, "recharge et ordre préparé restaurés")
	check(combat.units[2].node.position == expected.units[2].position and is_equal_approx(combat.combat_clock, 8.75), "position et horloge restaurées")
	check(combat.random.randi() == next_random, "séquence aléatoire conservée : pas de nouveau tirage à la reprise")
	combat.advance(10)
	check(combat.work_progress == 2.5 and combat.combat_clock == 8.75, "reprise gelée jusqu'à l'ordre du joueur")
	# Résolution et gain : un seul enregistrement cohérent.
	combat._advance_work(3.6)
	for unit in combat.units:
		if unit.side == "foe":
			combat._damage(unit, 9999)
	combat._check_end()
	check(planet.combat == null and poi("translation").done, "résolution de la rencontre après reprise")
	var earned: Dictionary = Game.stats.duplicate(true)
	var saved := Store.read(Game.save_path)
	var state := Store.unpack(saved.mission)
	check(saved.naq == earned.naq and state.world.resolved[2] and state.combat.is_empty(), "récompense et lieu terminé écrits atomiquement")
	_end_planet(false)
	await settle()
	Game.load_game()
	_continue_campaign()
	planet.set_process(false)
	check(pause_menu.visible and get_tree().paused, "reprise de l'exploration en pause")
	pause_menu.close()
	planet.leader_tile = poi("translation").tile
	planet._check_arrival()
	check(Game.stats.naq == earned.naq and Game.stats.xp == earned.xp and poi("translation").done, "revisiter un lieu terminé ne redonne pas sa récompense")
	_on_poi(poi("klorel"))
	combat = planet.combat
	combat.set_process(false)
	combat.begin_work()
	for unit in combat.units:
		if unit.side == "sg1" and unit.kind == "carter":
			unit.rt_path.clear()
			unit.tile = Vector2i(9, 10)
			unit.node.position = planet.tile_pos(unit.tile)
	combat._advance_work(2)
	save_checkpoint()
	_end_planet(false)
	await settle()
	Game.load_game()
	_continue_campaign()
	combat = planet.combat
	combat.set_process(false)
	planet.set_process(false)
	check(combat.work_kind == "carter" and combat.work_progress == 2 and not planet.mission.shield_disabled, "Carter reprend son intervention partielle avec le bouclier encore actif")
	combat._advance_work(4.1)
	for unit in combat.units:
		if unit.side == "foe":
			combat._damage(unit, 9999)
	combat._check_end()
	var rescued_state := Store.unpack(Store.read(Game.save_path).mission)
	check(rescued_state.world.operation.recovered and Game.stats.done == 0 and rescued_state.world.resolved[4], "Skaara récupéré et boss résolu sauvegardés ensemble, avant extraction")
	# Une erreur d'écriture doit laisser la partie et le dernier fichier valides.
	var valid_path := Game.save_path
	var valid_contents := FileAccess.get_file_as_string(valid_path)
	Game.save_path = "user://missing-session-test-folder/save.json"
	check(not save_checkpoint() and planet != null, "échec d'écriture : la partie reste ouverte")
	Game.save_path = valid_path
	check(FileAccess.get_file_as_string(valid_path) == valid_contents, "dernier fichier valide conservé après échec")
	_end_planet(false)
	await settle()
	await _test_expedition()
	# Une transaction ne publie pas un gain avant son objectif.
	Game.mission_capture = Callable()
	Game.mission_state = {}
	Game.save_game()
	before = FileAccess.get_file_as_string(Game.save_path)
	Game.begin_transaction()
	Game.add_naq(15)
	Game.save_game()
	check(FileAccess.get_file_as_string(Game.save_path) == before, "transaction : état intermédiaire non publié")
	Game.end_transaction()
	check(Store.read(Game.save_path).naq == Game.stats.naq, "transaction : publication à la fin")
	# La sortie est enregistrée avant la traversée : aucune mission terminée ne réapparaît.
	Game.mission_state = rescued_state
	_continue_campaign()
	pause_menu.close()
	planet.leader_tile = Vector2i(4, 3)
	leave_planet()
	check(Store.read(Game.save_path).done == 1 and Store.read(Game.save_path).mission == "", "extraction : progression validée et reprise de mission supprimée atomiquement")
	_end_planet()
	check((FileAccess.get_file_as_bytes(original_path) if FileAccess.file_exists(original_path) else PackedByteArray()) == campaign_bytes, "sauvegarde campagne utilisateur intacte")
	check((FileAccess.get_file_as_bytes(original_exp_path) if FileAccess.file_exists(original_exp_path) else PackedByteArray()) == expedition_bytes, "sauvegarde expédition utilisateur intacte")
	print("Sauvegarde et reprise : %d/%d vérifications réussies" % [checks - fails, checks])
	get_tree().quit(1 if fails else 0)

func _test_expedition() -> void:
	var sim := OutpostSim.new({"established": true, "profile": "recon", "difficulty": "hard"})
	sim._add("generator", "sgc", Vector2(10, 18))
	var construction := sim._add("mine", "sgc", sim.DEPOSIT, 4.5)
	sim.extracted_naquadah = 12
	sim.raid_in = 17.25
	sim.gate_in = 4.5
	sim.gate_job = "reinforcements"
	sim.supplies = 234.5
	sim.naquadah = 9.5
	sim.squads[2] = [1, 2]
	var soldier: Dictionary = sim.entities.filter(func(e): return e.kind == "soldier")[0]
	soldier.hp = 31.5
	sim.order([soldier.id], Vector2(15, 15))
	var view_state := {"focus": Vector3(19, 0, 34), "distance": 38.0, "selected": [soldier.id], "tab": "base", "logs": ["État de test"]}
	check(Expedition.save_session({"version": 1, "simulation": sim.snapshot(), "view": view_state}), "expédition écrite sur disque")
	var saved := Expedition.load_session()
	var preparation = load("res://scripts/outpost_menu.gd").new()
	add_child(preparation)
	var preserved := FileAccess.get_file_as_string(Expedition.save_path)
	preparation._launch()
	check(preparation._page == "replace" and FileAccess.get_file_as_string(Expedition.save_path) == preserved, "nouvelle expédition : confirmation avant remplacement d'une sauvegarde")
	preparation.free()
	var restored = OutpostSim.from_snapshot(saved.simulation)
	check(restored != null and restored.profile == "recon" and restored.difficulty == "hard", "profil et difficulté d'expédition restaurés")
	check(restored.entity(soldier.id).pos == soldier.pos and restored.entity(soldier.id).path == soldier.path and restored.entity(soldier.id).hp == 31.5, "positions, chemins et blessures RTS restaurés")
	check(restored.entity(construction.id).build == 4.5 and restored.grid.is_point_solid(Vector2i(sim.DEPOSIT)), "chantier et occupation de la grille restaurés")
	check(restored.gate_in == 4.5 and restored.gate_job == "reinforcements" and restored.raid_in == 17.25, "convoi et prochain raid restaurés")
	check(restored.extracted_naquadah == 12 and restored.supplies == 234.5 and restored.naquadah == 9.5 and restored.squads[2] == [1, 2], "économie et escouades restaurées")
	for i in 30:
		sim.tick(0.1)
		restored.tick(0.1)
	check(restored.entities == sim.entities and restored.extracted_naquadah == sim.extracted_naquadah, "les simulations originale et rechargée évoluent de façon identique")
	var arrival := OutpostSim.new()
	for i in 36:
		arrival.tick(0.1)
	var next_arrival = OutpostSim.from_snapshot(Store.unpack(Store.pack(arrival.snapshot())))
	check(next_arrival._arrival_spawned == arrival._arrival_spawned and next_arrival.arrival_clock == arrival.arrival_clock, "franchissement partiel restauré sans dupliquer l'équipe")
	Expedition.resume_pending = true
	var view = load("res://scripts/outpost.gd").new()
	view.persistence_enabled = false
	add_child(view)
	view.set_process(false)
	await settle()
	check(view.paused and is_instance_valid(view.pause_overlay) and view.sim.supplies == 234.5, "la vue reprend l'expédition en pause")
	view.persistence_enabled = true
	view.sim.supplies = 111.0
	view._process(5.1)
	check(Expedition.load_session().simulation.supplies == 111.0, "sauvegarde automatique RTS en pause")
	view._close_menu()
	check(not view.paused, "Reprendre relance réellement la simulation RTS")
	view._notification(NOTIFICATION_APPLICATION_PAUSED)
	check(view.paused and Expedition.load_session().simulation.supplies == 111.0, "arrière-plan RTS : pause et sauvegarde immédiates")
	view.free()
	var file := FileAccess.open(Expedition.save_path, FileAccess.WRITE)
	file.store_string("fichier interrompu")
	file.close()
	check(Expedition.load_session().is_empty() and not Expedition.last_error.is_empty(), "fichier corrompu refusé avec explication")
	check(FileAccess.get_file_as_string(Expedition.save_path) == "fichier interrompu", "fichier illisible conservé sans remplacement silencieux")
