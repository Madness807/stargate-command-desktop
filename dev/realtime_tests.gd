extends Node
## Deterministic clock/command tests without terrain imports or campaign saves.

const Combat = preload("res://scripts/combat_realtime.gd")
const Data = preload("res://scripts/data.gd")
var checks := 0
var fails := 0

class Person extends Node3D:
	var walking := false
	var kind := "serpent"
	func shoot() -> void:
		pass
	func hurt() -> void:
		pass
	func fall() -> void:
		walking = false

class Planet extends Node3D:
	var data: Dictionary = preload("res://scripts/data.gd").PLANETS[0]
	var team: Array = []
	var n_tiles := 16
	var tile_size := 2.0
	var blocked := {}
	var seen := {}
	var grid := AStarGrid2D.new()
	func _init() -> void:
		grid.region = Rect2i(0, 0, 16, 16)
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		grid.update()
		for x in 16:
			for y in 16:
				seen[Vector2i(x, y)] = true
	func tile_pos(tile: Vector2i) -> Vector3:
		return Vector3(tile.x * 2, 0, tile.y * 2)
	func pos_tile(point: Vector3) -> Vector2i:
		return Vector2i(roundi(point.x / 2), roundi(point.z / 2))
	func focus(_at: Vector3, _duration: float) -> void:
		pass
	func reveal(tile: Vector2i, _radius: int) -> void:
		seen[tile] = true

class Interface extends Node:
	var hp_events := 0
	var items: Array = []
	var info := ""
	func combat_status(_unit: Dictionary, text: String) -> void:
		info = text
	func action_grid(actions: Array) -> void:
		items = actions
	func combat_hp_changed() -> void:
		hp_events += 1
	func clear_actions() -> void:
		items.clear()
	func say(_who: String, _text: String) -> void:
		pass


func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		printerr("ÉCHEC TEMPS RÉEL : ", text)


func fixture() -> Dictionary:
	var planet := Planet.new()
	var interface := Interface.new()
	add_child(planet)
	add_child(interface)
	for i in Data.CORE_TEAM.size():
		var member := Person.new()
		member.kind = Data.CORE_TEAM[i]
		member.position = planet.tile_pos(Vector2i(2 + i % 2, 3 + i / 2))
		planet.add_child(member)
		planet.team.append(member)
	var poi_root := Node3D.new()
	planet.add_child(poi_root)
	var actors := []
	for i in 2:
		var enemy := Person.new()
		enemy.position = planet.tile_pos(Vector2i(7, 3 + i))
		poi_root.add_child(enemy)
		actors.append(enemy)
	var poi := {"k": "combat", "f": 0, "tile": Vector2i(7, 3), "actors": actors}
	var combat := Combat.new()
	planet.add_child(combat)
	combat.start(planet, interface, poi, Data.CORE_TEAM, {"oneill": 30, "carter": 26, "daniel": 24, "tealc": 36}, 1, 1)
	combat.set_process(false)
	for u in combat.units:
		u.hp = 1000
		u.hpmax = 1000
	return {"planet": planet, "interface": interface, "combat": combat}


func dispose(f: Dictionary) -> void:
	f.interface.free()
	f.planet.free()


func advance(combat: Node, seconds: float) -> void:
	for i in int(seconds * 10):
		combat.advance(0.1)


func _ready() -> void:
	seed(23991)
	var campaign: Dictionary = Game.stats.duplicate(true)
	_test_simultaneous()
	_test_pause_orders()
	_test_kit()
	_test_grenade()
	_test_skills()
	_test_blocked_orders()
	_test_results()
	_test_mutual_kill()
	_test_frame_timing()
	_test_targeting_info()
	_test_line_of_fire()
	Game.stats = campaign
	print("Temps réel : %d/%d vérifications réussies" % [checks - fails, checks])
	get_tree().quit(1 if fails else 0)


func _test_targeting_info() -> void:
	var f := fixture()
	var c: Node = f.combat
	c.select(0)
	c.units[0].attack_target = 4
	check("cible exposée" in c.targeting_info(c.units[0]), "cible sans couvert annoncée exposée")
	f.planet.blocked[Vector2i(6, 3)] = "obj"
	var info: String = c.targeting_info(c.units[0])
	check("cible à couvert" in info and ("tir %d %%" % c.hit_chance(c.units[0], c.units[4])) in info, "couvert et probabilité affichés selon les règles de tir")
	c.units[0].range = 1
	info = c.targeting_info(c.units[0])
	check("HORS PORTÉE" in info and "tir " not in info, "pas de pourcentage de tir pour une cible hors portée")
	dispose(f)


func _test_line_of_fire() -> void:
	var ray = preload("res://scripts/line_of_fire.gd")
	var walls := {Vector2i(4, 3): true}
	var opaque := func(tile: Vector2i): return walls.has(tile)
	check(not ray.clear(Vector2(2, 3), Vector2(7, 3), opaque) and not ray.clear(Vector2(7, 3), Vector2(2, 3), opaque), "mur : blocage symétrique")
	check(ray.clear(Vector2(2, 2), Vector2(7, 2), opaque), "ligne dégagée à côté du mur")
	var corner := func(tile: Vector2i): return tile == Vector2i(3, 2)
	check(not ray.clear(Vector2(2, 2), Vector2(3, 3), corner) and not ray.clear(Vector2(3, 3), Vector2(2, 2), corner), "pas de tir diagonal au travers d'un coin opaque")
	check(ray.clear(Vector2(2, 2), Vector2(3, 2), corner), "la cible peut occuper une case de bâtiment")
	var f := fixture()
	var c: Node = f.combat
	c.select(0)
	c.units[0].attack_target = 4
	f.planet.blocked[Vector2i(4, 3)] = "wall"
	f.planet.grid.set_point_solid(Vector2i(4, 3), true)
	var player_hp: int = c.units[0].hp
	var enemy_hp: int = c.units[4].hp
	var shots: int = c.effects.get_child_count()
	c._fire(c.units[0], c.units[4])
	c._fire(c.units[4], c.units[0])
	check(c.units[0].hp == player_hp and c.units[4].hp == enemy_hp and c.effects.get_child_count() == shots, "mur : aucun dégât ni projectile des deux camps")
	check("TIR BLOQUÉ" in c.targeting_info(c.units[0]) and "tir " not in c.targeting_info(c.units[0]), "obstacle bloquant annoncé sans probabilité trompeuse")
	f.planet.blocked[Vector2i(4, 3)] = "obj"
	check(c.line_of_fire(c.units[0], c.units[4]), "couvert bas : le tir reste possible")
	f.planet.blocked[Vector2i(4, 3)] = "wall"
	c.on_tap(c.units[4].tile)
	for u in c.units:
		if u.side == "foe":
			u.stun = 20.0
	advance(c, 6)
	check(c.units[0].node.position.distance_to(f.planet.tile_pos(Vector2i(2, 3))) > 0.1 and c.line_of_fire(c.units[0], c.units[4]), "ordre d'attaque : contourne le mur pour retrouver un tir")
	dispose(f)


func _test_simultaneous() -> void:
	var f := fixture()
	var c: Node = f.combat
	check(c.group_selected and c.active >= 0, "SG-1 sélectionnée au début")
	advance(c, 4)
	var ally_hurt := false
	var foe_hurt := false
	for u in c.units:
		if u.side == "sg1":
			ally_hurt = ally_hurt or u.hp < u.hpmax
			check(not u.has("ap") and not u.has("move"), "unité sans réserve d'actions ni quota de déplacement")
		else:
			foe_hurt = foe_hurt or u.hp < u.hpmax
	check(ally_hurt and foe_hurt, "les deux camps tirent sans aucune fin de tour")
	check(f.interface.hp_events > 0 and f.interface.info.contains("TEMPS RÉEL"), "HUD actualisé pendant les échanges")
	check(not f.interface.items.any(func(item): return str(item[0]).contains("Fin du tour")), "aucun bouton de tour résiduel")
	dispose(f)


func _test_pause_orders() -> void:
	var f := fixture()
	var c: Node = f.combat
	c.toggle_tactical_pause()
	var clock: float = c.combat_clock
	var position: Vector3 = c.units[0].node.position
	c.on_tap(Vector2i(5, 8))
	check(not c.units[0].rt_path.is_empty(), "ordre de déplacement accepté pendant la pause")
	advance(c, 3)
	check(c.combat_clock == clock and c.units[0].node.position == position, "simulation gelée pendant la pause tactique")
	check(c.units[0].node.process_mode == Node.PROCESS_MODE_DISABLED and c.effects.process_mode == Node.PROCESS_MODE_DISABLED,
		"animations et effets liés au combat gelés")
	c.toggle_tactical_pause()
	advance(c, 0.5)
	check(c.units[0].node.position.distance_to(position) > 0.1, "ordres exécutés à la reprise")
	c.select(1)
	check(not c.group_selected and c.active == 1, "sélection individuelle possible")
	c.select_group()
	check(c.group_selected, "retour à la sélection de groupe")
	dispose(f)


func _test_kit() -> void:
	var f := fixture()
	var c: Node = f.combat
	Game.stats.kits = 2
	c.units[0].hp = 5
	c.select(0)
	c.toggle_tactical_pause()
	c._use_kit()
	c._use_kit()
	advance(c, 2)
	check(c.units[0].hp == 5 and Game.stats.kits == 2, "soin préparé, pas appliqué pendant la pause")
	c.toggle_tactical_pause()
	c.advance(0.1)
	check(c.units[0].hp == 5 + Data.kit_heal(1) and Game.stats.kits == 1, "une seule trousse consommée à la reprise")
	c.advance(0.1)
	check(Game.stats.kits == 1, "action préparée exécutée une seule fois")
	dispose(f)


func _test_grenade() -> void:
	var f := fixture()
	var c: Node = f.combat
	c.select(0)
	c.toggle_tactical_pause()
	c._ability()
	check(c.mode == "grenade", "capacité d'O'Neill passe en ciblage de grenade")
	c.on_tap(Vector2i(7, 3))
	var hp: int = c.units[4].hp
	advance(c, 2)
	check(c.units[4].hp == hp and not c.units[0].queued.is_empty(), "grenade conservée comme ordre pendant la pause")
	c.toggle_tactical_pause()
	c.advance(0.1)
	check(c.units[4].hp == hp - 13 and c.units[0].cd > 0, "zone de dégâts et recharge en secondes à la reprise")
	var cooldown: float = c.units[0].cd
	c.toggle_tactical_pause()
	advance(c, 3)
	check(c.units[0].cd == cooldown, "recharge gelée pendant la pause")
	c.toggle_tactical_pause()
	advance(c, 1)
	check(c.units[0].cd < cooldown, "recharge avance en temps réel")
	dispose(f)


func _test_skills() -> void:
	var f := fixture()
	var c: Node = f.combat
	c.select(1)
	c.target = 4
	c.units[1].fire_in = 0.0
	c.toggle_tactical_pause()
	c._ability()
	check(c.units[1].cd == 0 and c.units[1].queued.kind == "carter", "zat préparé sans recharge consommée pendant la pause")
	c.toggle_tactical_pause()
	c.advance(0.1)
	check(c.units[1].cd > 0 and c.units[1].queued.is_empty(), "tir de zat exécuté à la reprise")
	c.select(3)
	c.units[3].hp = 100
	c._ability()
	c.advance(0.1)
	check(c.units[3].hp == 500 and c.units[3].cd > 0, "Kel'no'reem rend 40 % des PV avec recharge")
	c.select(2)
	c._ability()
	c.advance(0.1)
	check(c.units[4].stun > 2.5 and c.units[5].stun > 2.5, "diversion de Daniel exprimée en secondes")
	c.toggle_tactical_pause()
	c.select(0)
	c.units[0].queued = {"kind": "grenade", "tile": Vector2i(7, 3)}
	c._hold()
	check(c.units[0].queued.is_empty(), "tenir la position annule aussi l'action préparée")
	dispose(f)
	var boss_fixture := fixture()
	boss_fixture.combat.boss = true
	boss_fixture.combat.units[4].boss = true
	var before: int = boss_fixture.combat.units[4].dmg
	boss_fixture.combat.select(2)
	boss_fixture.combat._ability()
	boss_fixture.combat.advance(0.1)
	check(boss_fixture.combat.units[4].dmg < before, "traduction de Daniel affaiblit un boss")
	var weakened: int = boss_fixture.combat.units[4].dmg
	for repeat in 4:
		boss_fixture.combat.units[2].cd = 0.0
		boss_fixture.combat._ability()
		boss_fixture.combat.advance(0.1)
	check(weakened == maxi(1, roundi(before * 0.75)) and boss_fixture.combat.units[4].dmg == weakened, "traductions répétées : réduction unique de 25 %")
	dispose(boss_fixture)


func _test_blocked_orders() -> void:
	var f := fixture()
	var c: Node = f.combat
	for tile in [Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(1, 3), Vector2i(1, 4)]:
		f.planet.blocked[tile] = "obj"
		f.planet.grid.set_point_solid(tile, true)
	c.toggle_tactical_pause()
	c.on_tap(Vector2i(5, 6))
	var position: Vector3 = c.units[0].node.position
	check(c.units[0].has_move_order, "ordre conservé même si les alliés bloquent d'abord le passage")
	c.toggle_tactical_pause()
	advance(c, 3)
	check(c.units[0].node.position.distance_to(position) > 0.1, "chemin recalculé lorsque les autres membres libèrent le passage")
	dispose(f)


func _test_results() -> void:
	var f := fixture()
	var c: Node = f.combat
	var results := []
	c.finished.connect(func(result): results.append(result))
	for u in c.units:
		if u.side == "foe":
			c._damage(u, 9999)
	c.advance(0.1)
	check(results == ["win"] and c._done, "victoire émise une fois après élimination")
	var clock: float = c.combat_clock
	c.advance(10)
	check(c.combat_clock == clock and results.size() == 1, "aucun tir ou résultat après fin du combat")
	dispose(f)
	var lost := fixture()
	var losses := []
	lost.combat.finished.connect(func(result): losses.append(result))
	for u in lost.combat.units:
		if u.side == "sg1":
			lost.combat._damage(u, 9999)
	lost.combat.advance(0.1)
	check(losses == ["lose"], "équipe entière à terre : défaite")
	dispose(lost)
	var retreat := fixture()
	var escaped := []
	retreat.combat.finished.connect(func(result): escaped.append(result))
	retreat.combat.toggle_tactical_pause()
	retreat.combat.flee()
	check(escaped == ["flee"] and retreat.combat.units[0].node.process_mode == Node.PROCESS_MODE_INHERIT,
		"repli depuis la pause : acteurs rendus à l'exploration")
	dispose(retreat)


func _test_mutual_kill() -> void:
	var f := fixture()
	var c: Node = f.combat
	var results := []
	c.finished.connect(func(result): results.append(result))
	for u in c.units:
		u.hp = 1
		u.fire_in = 999.0
		u.tile = Vector2i(5, 5)
		u.node.position = f.planet.tile_pos(u.tile)
	for i in [1, 2, 3, 5]:
		c.units[i].alive = false
		c.units[i].hp = 0
	c.units[0].queued = {"kind": "grenade", "tile": Vector2i(5, 5)}
	c.advance(0.1)
	check(results == ["lose"], "élimination mutuelle par grenade : défaite")
	check(c.units[0].hp == 0 and not c.units[0].alive, "aucune résurrection après élimination mutuelle")
	dispose(f)


func _test_frame_timing() -> void:
	var f := fixture()
	var c: Node = f.combat
	for i in 50:
		c._process(0.2)
	check(is_equal_approx(c.combat_clock, 10.0), "horloge temps réel indépendante des images à 5 FPS")
	c.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	c._process(0.2)
	check(c.tactical_paused and is_equal_approx(c.combat_clock, 10.0), "combat gelé à la perte de focus")
	c.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	check(c.tactical_paused, "reprise manuelle après interruption")
	c.toggle_tactical_pause()
	c._process(5.0)
	check(c.tactical_paused and is_equal_approx(c.combat_clock, 10.0), "pas de rattrapage des dégâts après suspension")
	dispose(f)
