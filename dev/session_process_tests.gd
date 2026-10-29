extends "res://scripts/main.gd"
## Exécuter --write-fixture puis --read-fixture dans deux processus séparés.
var checks := 0
var fails := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		printerr("ÉCHEC PROCESSUS : ", message)

func _debug_jumps() -> void:
	_close_title()

func _ready() -> void:
	Game.save_path = "user://test_process_campaign.json"
	Expedition.save_path = "user://test_process_expedition.json"
	Game.mission_capture = Callable()
	if Cli.has("--write-fixture"):
		Game.new_game()
	else:
		Game.load_game()
	super._ready()
	set_process(false)
	if Cli.has("--write-fixture"):
		current = 0
		planet = PlanetScript.new()
		add_child(planet)
		planet.setup(0, Game.team, 742)
		planet.input_locked = false
		planet.set_process(false)
		_build_hud()
		Game.mission_capture = Callable(self, "capture_mission")
		planet.mission.contacted = true
		planet.mission.translated = true
		planet.pois[0].done = true
		planet.pois[2].done = true
		var boss_poi: Dictionary = planet.pois[4]
		start_combat(boss_poi, 30, 35)
		var c = planet.combat
		c.set_process(false)
		c.begin_work()
		for u in c.units:
			if u.side == "sg1" and u.kind == "carter":
				u.rt_path.clear()
				u.tile = Vector2i(9, 10)
				u.node.position = planet.tile_pos(u.tile)
		c._advance_work(2.25)
		Game.stats.naq = 77
		check(save_checkpoint(), "écriture de campagne avant fermeture")
		var sim := preload("res://scripts/outpost_sim.gd").new({"established": true})
		sim._add("mine", "sgc", sim.DEPOSIT, 5.25)
		sim.extracted_naquadah = 12
		sim.gate_in = 3.75
		sim.gate_job = "medic"
		check(Expedition.save_session({"version": 1, "simulation": sim.snapshot(), "view": {"focus": Vector3(19, 0, 34), "distance": 38.0, "selected": [], "tab": "base", "logs": []}}), "écriture d'expédition avant fermeture")
	else:
		check(Game.stats.naq == 77 and not Game.mission_state.is_empty(), "progression et mission chargées dans un nouveau processus")
		_continue_campaign()
		check(planet != null and planet.combat != null and planet.combat.tactical_paused, "combat repris en pause après redémarrage")
		if planet and planet.combat:
			check(planet.combat.work_kind == "carter" and planet.combat.work_progress == 2.25 and not planet.mission.shield_disabled, "intervention de Carter et bouclier restaurés après redémarrage")
		var state := Expedition.load_session()
		var sim = preload("res://scripts/outpost_sim.gd").from_snapshot(state.simulation)
		check(sim != null and sim.gate_in == 3.75 and sim.gate_job == "medic" and sim.extracted_naquadah == 12, "convoi et ressources restaurés après redémarrage")
		if Cli.has("--visual"):
			await capture("combat")
			open_pause()
			await capture("pause")
			pause_menu.close()
			_end_planet(false)
			show_title()
			await capture("accueil")
			_close_title()
			ui.hide()
			var menu = load("res://scripts/outpost_menu.gd").new()
			add_child(menu)
			await capture("expedition")
			menu.free()
	print("Reprise interprocessus : %d/%d vérifications réussies" % [checks - fails, checks])
	get_tree().quit(1 if fails else 0)

func capture(label: String) -> void:
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/sg1-reprise-" + label + ".png")
