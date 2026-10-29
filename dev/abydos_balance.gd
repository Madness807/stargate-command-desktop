extends "res://scripts/main.gd"
## Comparaison de politiques automatiques ; ce n'est pas un test de plaisir ou de durée humaine.
var trial_failed := false
var retreats := 0
var boss_hp_ratio := 0.0
var battle_count := 0

func _debug_jumps() -> void:
	_close_title()

func _update_hud() -> void:
	pass

func banner(_title: String, _sub: String = "", _color: Color = T.AMBER) -> void:
	pass

func _hide_fallen(foes: Array) -> void:
	for foe in foes:
		foe.hide()

func _evacuate() -> void:
	trial_failed = true # Arrêter la mesure à la défaite, sans chronométrer le rapatriement animé.

func _on_combat_end(result: String) -> void:
	if planet.combat.boss and result == "win":
		var hp := 0.0
		var maximum := 0.0
		for u in planet.combat.units:
			if u.side == "sg1":
				hp += u.hp
				maximum += u.hpmax
		boss_hp_ratio = hp / maximum
	if result == "flee":
		retreats += 1
	super._on_combat_end(result)

func _ready() -> void:
	Game.save_path = "user://test_balance_unused.json"
	Game.mission_capture = Callable()
	Game.mission_state = {}
	Game._save_depth = 1 # Éviter les écritures disque pendant les essais ; aucune donnée utilisateur.
	super._ready()
	set_process(false)
	var results := []
	var count := int(Cli.number("--samples", 5))
	for difficulty in ["easy", "normal", "hard"]:
		Settings._values.difficulty = difficulty
		for policy in ["automatic", "focus", "abilities", "cover"]:
			for sample in count:
				results.append(run_trial(difficulty, policy, 742 + sample))
				await get_tree().process_frame
			print("BALANCE ", difficulty, " / ", policy, " terminé")
	var output := Cli.value("--output", "/tmp/sg1-abydos-balance.json")
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"samples": count, "trials": results}, "\t"))
	file.close()
	print("BALANCE OUTPUT ", output)
	get_tree().quit()

func run_trial(difficulty: String, policy: String, trial_seed: int) -> Dictionary:
	Game.stats = Game._fresh()
	Game.refresh_team()
	seed(trial_seed)
	trial_failed = false
	retreats = 0
	boss_hp_ratio = 0
	battle_count = 0
	current = 0
	planet = PlanetScript.new()
	add_child(planet)
	planet.setup(0, Game.team, trial_seed)
	planet.input_locked = false
	planet.set_process(false)
	planet.poi_reached.connect(_on_poi)
	planet.gate_near.connect(_on_gate_near)
	var seconds := 0.0
	var policy_in := 0.0
	var previous: Node
	while seconds < 180 and not trial_failed and retreats < 2 and not planet.mission.recovered:
		var c = planet.combat
		if c:
			c.set_process(false)
			if c != previous:
				previous = c
				battle_count += 1
				c.begin_work()
				if policy == "cover":
					order_cover(c)
				policy_in = 0
			policy_in -= 0.1
			if policy_in <= 0:
				policy_in = 1.0
				issue_orders(c, policy)
			c.advance(0.1)
		else:
			previous = null
			if not planet.moving:
				planet.walk_to(planet.objective_tile())
			planet._process(0.1)
		seconds += 0.1
	var recovered: bool = planet.mission.recovered
	if recovered:
		planet.walk_to(planet.objective_tile())
		while seconds < 200 and planet._cheb(planet.leader_tile, planet.DHD_TILE) > 2 and not trial_failed:
			planet._process(0.1)
			seconds += 0.1
	var success: bool = recovered and planet._cheb(planet.leader_tile, planet.DHD_TILE) <= 2
	var outcome := {"difficulty": difficulty, "policy": policy, "seed": trial_seed, "success": success,
		"seconds": snappedf(seconds, 0.1), "retreats": retreats, "battles": battle_count,
		"kits_used": Data.START_KITS - int(Game.stats.kits), "boss_hp_ratio": boss_hp_ratio,
		"reason": "extracted" if success else ("defeat" if trial_failed else ("retreats" if retreats >= 2 else "timeout"))}
	_end_planet()
	return outcome

func issue_orders(c: Node, policy: String) -> void:
	var target_unit := {}
	for enemy in c.units:
		if enemy.side == "foe" and enemy.alive:
			if target_unit.is_empty() or (target_unit.get("boss", false) and not enemy.get("boss", false)):
				target_unit = enemy
	if policy != "automatic" and not target_unit.is_empty():
		for u in c.units:
			if u.side == "sg1" and u.alive and u.kind != c.work_kind and not (policy == "cover" and u.has_move_order):
				c.select(u.index)
				c.on_tap(target_unit.tile)
	if policy in ["abilities", "cover"]:
		for u in c.units:
			if u.side != "sg1" or not u.alive or u.kind == c.work_kind or u.cd > 0 or not u.queued.is_empty():
				continue
			if u.kind == "daniel" or (u.kind == "tealc" and u.hp < u.hpmax * 0.65):
				c.select(u.index)
				c._ability()
			elif u.kind == "oneill" and not target_unit.is_empty() and c._dist(u.tile, target_unit.tile) <= 5:
				var friendly_fire := false
				for ally in c.units:
					if ally.side == "sg1" and ally.alive and c._dist(ally.tile, target_unit.tile) <= 1:
						friendly_fire = true
				if not friendly_fire:
					c.select(u.index)
					c._ability()
					c.on_tap(target_unit.tile)
	var patient := {}
	for u in c.units:
		if u.side == "sg1" and u.alive and u.hp < u.hpmax * 0.55:
			if patient.is_empty() or float(u.hp) / u.hpmax < float(patient.hp) / patient.hpmax:
				patient = u
	if not patient.is_empty() and Game.stats.kits > 0:
		c.select(patient.index)
		c._use_kit()

func order_cover(c: Node) -> void:
	var foe := {}
	for enemy in c.units:
		if enemy.side == "foe" and enemy.alive and not enemy.get("boss", false):
			foe = enemy
			break
	if foe.is_empty():
		return
	var taken := {}
	for u in c.units:
		if u.side != "sg1" or not u.alive or u.kind == c.work_kind:
			continue
		var best: Vector2i = u.tile
		var cost := 999
		for x in range(-3, 4):
			for y in range(-3, 4):
				var tile: Vector2i = u.tile + Vector2i(x, y)
				if not planet.grid.is_in_boundsv(tile) or planet.blocked.has(tile) or taken.has(tile) or c.unit_at(tile) >= 0:
					continue
				if c._dist(tile, foe.tile) > u.range or not c._cover(tile, foe.tile):
					continue
				if not c.LineOfFire.clear(Vector2(tile), Vector2(foe.tile), c._opaque):
					continue
				var path: Array = c._path(u.tile, tile)
				if path.size() > 1 and path.size() < cost:
					best = tile
					cost = path.size()
		taken[best] = true
		if best != u.tile:
			c.select(u.index)
			c.on_tap(best)
