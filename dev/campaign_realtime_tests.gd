extends "res://scripts/main.gd"
## Chaque planète, toutes les familles de rencontres et tous les gardiens.
## Les sauvegardes de campagne sont redirigées vers un fichier de test.
var checks := 0
var fails := 0
var _stats := {}
var _team: Array = []
var _save := ""
var _saved_contents := ""

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		printerr("ÉCHEC CAMPAGNE RTS : ", message)

func settle() -> void:
	for i in 3:
		await get_tree().process_frame

func _debug_jumps() -> void:
	_close_title()
	Audio.loop_stop("theme", 0)
	Audio.loop_stop("horizon", 0)

func _ready() -> void:
	_stats = Game.stats.duplicate(true)
	_team = Game.team.duplicate()
	_save = Game.save_path
	_saved_contents = FileAccess.get_file_as_string(_save) if FileAccess.file_exists(_save) else ""
	Game.save_path = "user://test_all_campaign_rt.json"
	super._ready()
	for index in Data.PLANETS.size():
		current = index
		Game.stats = Game._fresh()
		Game.stats.done = index
		Game.stats.lvl = 10
		Game.refresh_team()
		Game.heal_all()
		planet = PlanetScript.new()
		add_child(planet)
		planet.setup(index, Game.team, 734 + index)
		planet.input_locked = false
		planet.set_process(false)
		planet.reveal(Vector2i(8, 8), 20)
		_build_hud()
		for poi in planet.pois:
			if poi.k not in ["combat", "boss"]:
				continue
			await _encounter(poi)
		_end_planet()
		await settle()
	Game.save_path = _save
	Game.stats = _stats
	Game.team = _team
	var contents := FileAccess.get_file_as_string(_save) if FileAccess.file_exists(_save) else ""
	check(contents == _saved_contents, "sauvegarde utilisateur intacte")
	print("Campagne RTS : %d/%d vérifications réussies" % [checks - fails, checks])
	get_tree().quit(1 if fails else 0)

func _encounter(poi: Dictionary) -> void:
	var label: String = "%s / %s" % [Data.PLANETS[current].n, poi.k]
	# Les règles de sauvetage sont vérifiées dans abydos_mission_tests ; ici, intégration moteur.
	if planet.mission != null:
		planet.mission.contacted = true
		planet.mission.translated = true
		planet.mission.shield_disabled = true
	# Le déclencheur réellement utilisé par la marche, pas une fabrique de combat de test.
	_on_poi(poi)
	var combat = planet.combat
	check(combat != null and combat.get_script() == RealtimeCombat, label + " : temps réel dès le contact")
	if combat == null or combat.get_script() != RealtimeCombat:
		return
	combat.set_process(false)
	check(actions_box.get_child_count() == 0, label + " : aucun dialogue d'engagement bloquant")
	for button in combat_bar.get_children():
		check(not button.text.contains("FIN DU TOUR"), label + " : pas de fin de tour")
	check(title_lbl.text.contains("TEMPS RÉEL"), label + " : HUD temps réel")
	combat.toggle_tactical_pause()
	var clock: float = combat.combat_clock
	combat.advance(1)
	check(combat.combat_clock == clock, label + " : pause tactique réelle")
	var destination := Vector2i(-1, -1)
	for x in planet.n_tiles:
		for y in planet.n_tiles:
			var tile := Vector2i(x, y)
			if not planet.blocked.has(tile) and combat.unit_at(tile) < 0 and combat._dist(combat.units[0].tile, tile) > 4 and combat._path(combat.units[0].tile, tile).size() > 5:
				destination = tile
				break
		if destination.x >= 0:
			break
	combat.select(0)
	combat.on_tap(destination)
	check(destination.x >= 0 and combat.units[0].rt_path.size() > 4, label + " : déplacement sans quota d'actions, ordre pendant pause")
	combat._hold()
	combat.select(1)
	_squad_pick(combat.units[0].kind)
	check(combat.active == 0, label + " : changement de membre immédiat")
	combat.toggle_tactical_pause()
	for unit in combat.units:
		unit.hp = 1000
		unit.hpmax = 1000
		unit.range = 100
		unit.fire_in = 0.0
	# Isoler le contrôle d'horloge des nouveaux obstacles : un duel sur deux cases libres.
	var shooter: Dictionary = combat.units[0]
	var opponent := {}
	for unit in combat.units:
		if unit.side == "foe":
			opponent = unit
			break
	shooter.tile = Vector2i(0, 0)
	opponent.tile = Vector2i(0, 1)
	shooter.node.position = planet.tile_pos(shooter.tile)
	opponent.node.position = planet.tile_pos(opponent.tile)
	check(combat.line_of_fire(shooter, opponent), label + " : duel de contrôle sur une ligne dégagée")
	combat.advance(0.2)
	var player_fired := false
	var enemy_fired := false
	for unit in combat.units:
		if unit.fire_in > 0:
			if unit.side == "sg1": player_fired = true
			else: enemy_fired = true
	check(player_fired and enemy_fired and combat.combat_clock > clock, label + " : les deux camps tirent sur la même horloge")
	check(_can_abandon(), label + " : abandon disponible pendant les échanges")
	for unit in combat.units:
		if unit.side == "foe":
			combat._damage(unit, 99999)
	combat.advance(0.1)
	check(planet.combat == null and poi.done, label + " : victoire, récompenses et retour à l'exploration")
	if poi.k == "boss":
		if planet.mission != null:
			check(planet.mission.recovered and Game.stats.done == 0, label + " : Skaara récupéré, progression en attente d'extraction")
		else:
			check(Game.stats.done >= current + 1, label + " : progression de campagne conservée")
	await settle()
