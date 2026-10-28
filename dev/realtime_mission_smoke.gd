extends "res://scripts/main.gd"
## Exercise the actual Abydos scene, HUD, pause and campaign reward callback.
## --show leaves a few seconds for screenshots. The real save is never written.

var _original_stats := {}
var _original_team: Array = []
var _original_save := ""
var _original_contents := ""
var _checks := 0
var _fails := 0


func check(ok: bool, text: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		printerr("ÉCHEC MISSION TEMPS RÉEL : ", text)


func _ready() -> void:
	_original_stats = Game.stats.duplicate(true)
	_original_team = Game.team.duplicate()
	_original_save = Game.save_path
	_original_contents = FileAccess.get_file_as_string(_original_save) if FileAccess.file_exists(_original_save) else ""
	Game.save_path = "user://test_rt_mission_unused.json"
	Game.stats = Game._fresh()
	Game.refresh_team()
	Game.heal_all()
	super._ready()
	while planet and planet.input_locked:
		await get_tree().process_frame
	var poi := {}
	for p in planet.pois:
		if p.k == "combat" and p.f == 0:
			poi = p
			break
	check(not poi.is_empty(), "rencontre d'Abydos disponible")
	if poi.is_empty():
		_finish_test()
		return
	var start: Vector2i = planet._nearest_free(poi.tile + Vector2i(-3, 0))
	for member in planet.team:
		member.position = planet.tile_pos(start)
	planet.reveal(poi.tile, 5)
	start_combat(poi, 0, 0)
	var c = planet.combat
	check(c != null and c.get_script() == RealtimeCombat, "Abydos instancie le moteur de combat temps réel")
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	_input(key)
	check(title_lbl.text.contains("PAUSE TACTIQUE"), "HUD de mission affiche la pause tactique")
	var clock: float = c.combat_clock
	c.advance(2)
	check(c.combat_clock == clock, "combat de campagne gelé sans bloquer le HUD")
	var destination := Vector2i(-1, -1)
	for x in planet.n_tiles:
		for y in planet.n_tiles:
			var tile := Vector2i(x, y)
			if not planet.blocked.has(tile) and c.unit_at(tile) < 0 and tile != c.units[0].tile:
				destination = tile
				break
		if destination.x >= 0:
			break
	c.on_tap(destination)
	check(c.units[0].has_move_order, "ordres possibles pendant la pause dans la vraie carte")
	c._hold()
	_input(key)
	check(title_lbl.text.contains("TEMPS RÉEL"), "HUD de mission affiche la reprise")
	await get_tree().create_timer(1.2, false).timeout
	check(planet.combat != null and c.combat_clock > 0, "simulation réelle avance dans la scène")
	if Cli.has("--show"):
		await get_tree().create_timer(3.0, false).timeout
	if planet.combat:
		c = planet.combat
		for u in c.units:
			if u.side == "foe":
				c._damage(u, 9999)
		c.advance(0.1)
	check(poi.done and planet.combat == null, "victoire rend la main à l'exploration et résout le lieu")
	check(Game.stats.lvl == 1 and Game.stats.naq == Data.START_NAQ, "récompenses du test isolées sans progression indue")
	_finish_test()


func _debug_jumps() -> void:
	_close_title()
	hub.close()
	Audio.loop_stop("theme", 0)
	Audio.loop_stop("horizon", 0)
	current = 0
	start_planet()


func _finish_test() -> void:
	_end_planet()
	Game.save_path = _original_save
	Game.stats = _original_stats
	Game.team = _original_team
	var contents := FileAccess.get_file_as_string(_original_save) if FileAccess.file_exists(_original_save) else ""
	check(contents == _original_contents, "vraie sauvegarde inchangée")
	print("Mission temps réel : %d/%d vérifications réussies" % [_checks - _fails, _checks])
	get_tree().quit(1 if _fails else 0)
