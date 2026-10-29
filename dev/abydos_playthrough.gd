extends "res://scripts/main.gd"
## Simulation du parcours avec déplacements, tirs et interventions réels, niveau 1 sans équipement.
## Ne force ni les PV, ni les dégâts, ni les morts, ni la progression des interventions.

func _debug_jumps() -> void:
	_close_title()

func _ready() -> void:
	var original_save := Game.save_path
	var original_stats: Dictionary = Game.stats.duplicate(true)
	var original_team: Array = Game.team.duplicate()
	var difficulty: String = Settings._values.difficulty
	Game.save_path = "user://abydos_playthrough_test.json"
	Settings._values.difficulty = "normal"
	Game.stats = Game._fresh()
	Game.refresh_team()
	seed(742)
	super._ready()
	current = 0
	planet = PlanetScript.new()
	add_child(planet)
	planet.setup(0, Game.team, 742)
	planet.input_locked = false
	planet.set_process(false)
	planet.poi_reached.connect(_on_poi)
	planet.gate_near.connect(_on_gate_near)
	_build_hud()
	var seconds := 0.0
	var next_order := ""
	var repli := 0
	var previous_combat: Node
	while seconds < 300 and planet.mission.recovered == false:
		var c = planet.combat
		if c != null:
			c.set_process(false)
			if c != previous_combat:
				print("SIM contact ", c.poi.id, " t=", snappedf(seconds, 0.1), " PV=", Game.stats.hp)
				previous_combat = c
				c.begin_work()
				for u in c.units:
					if u.side != "sg1" or u.kind == c.work_kind:
						continue
					for enemy in c.units:
						if enemy.side == "foe" and not enemy.get("boss", false):
							u.attack_target = enemy.index
							break
				# Le commandant emploie les capacités disponibles, pas seulement le tir automatique.
				for u in c.units:
					if u.side != "sg1" or not u.alive or u.kind == c.work_kind:
						continue
					if u.kind == "daniel" and c.boss:
						c.select(u.index)
						c._ability()
					elif u.kind == "oneill":
						c.select(u.index)
						c._ability()
						c.on_tap(c.poi.tile)
			for u in c.units:
				if u.side == "sg1" and u.kind == c.work_kind and u.hp <= u.hpmax * 0.5 and Game.stats.kits > 0:
					c.select(u.index)
					c._use_kit()
			c.advance(0.1)
			if planet.combat == null:
				print("SIM résultat ", c.poi.id, " résolu=", c.poi.done, " traduction=", planet.mission.translated, " bouclier coupé=", planet.mission.shield_disabled, " t=", snappedf(seconds, 0.1))
				next_order = ""
				previous_combat = null
				if not c.poi.done:
					repli += 1
		else:
			var next: String = planet.mission.next_id()
			if next != next_order or not planet.moving:
				next_order = next
				planet.walk_to(planet.objective_tile())
			planet._process(0.1)
		seconds += 0.1
		if repli >= 3:
			break
	var rescued: bool = planet.mission.recovered
	if rescued:
		planet.walk_to(planet.objective_tile())
		while seconds < 330 and planet._cheb(planet.leader_tile, planet.DHD_TILE) > 2:
			planet._process(0.1)
			seconds += 0.1
		leave_planet()
	var success: bool = Game.stats.done == 1 and rescued
	print("Parcours Abydos niveau 1 : succès=", success, " durée simulée=", snappedf(seconds, 0.1), "s replis=", repli, " PV=", Game.stats.hp)
	_end_planet()
	Game.save_path = original_save
	Game.stats = original_stats
	Game.team = original_team
	Settings._values.difficulty = difficulty
	get_tree().quit(0 if success else 1)
