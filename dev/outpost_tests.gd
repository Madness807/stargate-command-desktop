extends Node
## godot --headless --path . res://dev/outpost_tests.tscn
## La simulation n'utilise aucune sauvegarde ni aucun réglage utilisateur.

const Sim = preload("res://scripts/outpost_sim.gd")
var checks := 0
var fails := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		printerr("ÉCHEC RTS : ", message)


func advance(s: RefCounted, seconds: float) -> void:
	for i in int(seconds * 10):
		s.tick(0.1)


func find(s: RefCounted, kind: String) -> Dictionary:
	for e in s.entities:
		if e.kind == kind and e.hp > 0:
			return e
	return {}


func established() -> RefCounted:
	return Sim.new({"established": true})


func _ready() -> void:
	_test_buildings()
	_test_exploration()
	_test_orders()
	_test_gate()
	_test_combat()
	_test_results()
	_test_visibility()
	_test_terrain()
	print("RTS : %d/%d vérifications réussies" % [checks - fails, checks])
	get_tree().quit(1 if fails else 0)


func _test_buildings() -> void:
	var s := established()
	check(s.count("soldier") == 4 and s.count("hq") == 1, "équipe et commandement initiaux")
	check(s.build("generator", Vector2(11, 18)), "placement près du commandement")
	check(s.supplies == 250 and s.count("generator") == 0, "prix débité, chantier pas encore actif")
	check(s.grid.is_point_solid(Vector2i(11, 18)), "chantier obstacle de navigation")
	check(not s.build("turret", Vector2(11, 18)) and s.supplies == 250, "chevauchement refusé sans débit")
	check(not s.build("turret", Sim.GATE), "passage de la porte protégé")
	check(not s.build("turret", Vector2(30, 22)), "construction éloignée refusée")
	check(not s.build("turret", Vector2(-2, 18)), "hors carte refusé")
	check(not s.build("turret", Vector2(4, 21)), "pas de construction sur un soldat")
	advance(s, 9)
	check(s.count("generator") == 1 and s.power() == Vector2i(0, 8), "générateur actif après construction")
	check(s.build("turret", Vector2(11, 14)), "tourelle constructible")
	advance(s, 10)
	check(s.power() == Vector2i(2, 8) and s.powered(), "consommation énergétique")
	find(s, "generator").hp = 0
	check(not s.powered(), "panne si générateur détruit")
	s.supplies = 0
	check(not s.build("lab", Vector2(8, 14)), "pas de construction sans ressources")


func _test_exploration() -> void:
	var s := established()
	check(not s.build("mine", Sim.DEPOSIT), "gisement à reconnaître avant exploitation")
	var soldier := find(s, "soldier")
	soldier.pos = Sim.DEPOSIT + Vector2(-3, 0)
	s.update_visibility()
	s.tick(0.1)
	check(s.deposit_found, "reconnaissance du gisement par proximité")
	check(not s.build("mine", Sim.DEPOSIT), "garde jaffa à éliminer avant construction")
	for e in s.entities:
		if e.kind == "jaffa":
			e.hp = 0
	check(s.build("mine", Sim.DEPOSIT), "extracteur sur gisement sécurisé")
	check(not s.build("mine", Sim.DEPOSIT + Vector2(0, 1)), "pas de double exploitation")
	advance(s, 13)
	check(s.naquadah == 0, "extracteur inactif sans énergie")
	check(s.build("generator", Vector2(11, 18)), "alimentation de l'extracteur")
	advance(s, 12)
	check(s.naquadah > 0, "production de naquadah")
	soldier.pos = Sim.RUINS
	s.tick(0.1)
	var reward: float = s.naquadah
	s.tick(0.1)
	check(s.ruins_found and s.naquadah == reward and reward >= 30, "ruines récompensées une seule fois")
	check(not s.research(), "recherche impossible sans laboratoire")
	s.supplies = 300
	check(s.build("lab", Vector2(8, 14)), "laboratoire constructible")
	advance(s, 13)
	var before: float = s.naquadah
	check(s.research() and s.researched and s.naquadah == before - 30, "recherche consomme le naquadah")
	check(not s.research(), "recherche non répétable")


func _test_orders() -> void:
	var s := established()
	var unit := find(s, "soldier")
	s.order([unit.id], Vector2(10, 18))
	check(not unit.path.is_empty(), "ordre crée un chemin")
	var avoids := true
	for p in unit.path:
		if s.grid.is_point_solid(Vector2i(p)):
			avoids = false
	check(avoids, "chemin contourne le commandement")
	advance(s, 8)
	check(unit.pos.distance_to(Vector2(10, 18)) < 0.1, "arrivée à destination")
	s.order([unit.id], Vector2(8, 18))
	advance(s, 4)
	check(unit.pos.distance_to(Vector2(8, 18)) >= 1, "ordre sur bâtiment aboutit à une case voisine")


func _test_gate() -> void:
	var s := established()
	check(s.reinforce() and s.supplies == 235 and s.gate_in == 18, "renforts payés et mis en attente")
	check(not s.reinforce() and s.supplies == 235, "porte occupée : deuxième commande refusée")
	advance(s, 17)
	check(s.count("soldier") == 4, "pas de renforts avant la fin du délai")
	advance(s, 4)
	check(s.count("soldier") == 7 and s.gate_in == 0, "trois soldats arrivent par la porte")
	s.supplies = 0
	check(not s.reinforce(), "renforts sans ravitaillement refusés")
	s.supplies = 999
	for i in 11:
		s._add("soldier", "sgc", Vector2(3, 22))
	check(not s.reinforce(), "limite d'effectifs respectée")


func _test_combat() -> void:
	var s := established()
	var soldier := find(s, "soldier")
	var jaffa := find(s, "jaffa")
	soldier.pos = Vector2(14, 16)
	jaffa.pos = Vector2(16, 16)
	s.update_visibility()
	s.tick(0.1)
	check(jaffa.hp < jaffa.max_hp and soldier.hp < soldier.max_hp, "combat automatique réciproque")
	var target := find(s, "camp")
	soldier.pos = target.pos + Vector2(-5, 0)
	s.update_visibility()
	s.order([soldier.id], target.pos, target.id)
	check(soldier.target == target.id and not soldier.path.is_empty(), "ordre explicite d'attaque")
	var raids := established()
	raids.raid_in = 0.1
	raids.tick(0.2)
	check(raids.wave == 1 and raids.count("jaffa") == 6, "première patrouille produite")
	var moving := 0
	for e in raids.entities:
		if e.kind == "jaffa" and not e.path.is_empty():
			moving += 1
	check(moving == 3, "patrouille en marche vers la base")
	advance(raids, 180)
	check(find(raids, "hq").is_empty() or find(raids, "hq").hp < 600, "les assauts atteignent et endommagent la base")


func _test_results() -> void:
	var s := established()
	find(s, "camp").hp = 0
	s.tick(0.1)
	check(s.result == "", "camp seul insuffisant pour gagner")
	s._add("mine", "sgc", Sim.DEPOSIT)
	s.tick(0.1)
	check(s.result == "victory", "victoire avec extracteur et camp détruit")
	var before: float = s.elapsed
	s.tick(10)
	check(s.elapsed == before and not s.reinforce(), "simulation et commandes arrêtées après victoire")
	var lost := established()
	find(lost, "hq").hp = 0
	lost.tick(0.1)
	check(lost.result == "defeat", "défaite si commandement perdu")


func _test_visibility() -> void:
	var s := established()
	check(s.is_visible(Sim.GATE) and s.is_explored(Vector2(8, 18)), "base et porte reconnues au départ")
	check(not s.is_explored(Vector2(27, 5)) and not s.camp_found, "camp caché en début de partie")
	check(not s.is_visible(Vector2(-1, 3)) and not s.is_explored(Vector2(32, 24)), "vision hors carte refusée")
	var camp := find(s, "camp")
	var scout := find(s, "soldier")
	s.order([scout.id], camp.pos, camp.id)
	check(scout.target == -1 and scout.path.is_empty(), "cible invisible non attaquable par identifiant")
	s.order([scout.id], Vector2(28, 5))
	check(not scout.path.is_empty(), "déplacement dans l'inconnu autorisé")
	scout.path.clear()
	scout.pos = Vector2(23, 5)
	s.update_visibility()
	check(s.entity_visible(camp) and s.camp_found, "éclaireur révèle le camp")
	check(s.known_buildings.has(camp.id), "position du camp mémorisée")
	var intel: Dictionary = s.known_buildings[camp.id]
	check(not intel.has("hp") and not intel.has("target"), "renseignements mémorisés sans état caché")
	s.order([scout.id], camp.pos, camp.id)
	check(scout.target == camp.id, "cible visible attaquable")
	scout.pos = Vector2(4, 21)
	s.update_visibility()
	check(not s.entity_visible(camp) and s.is_explored(camp.pos), "terrain découvert conservé mais ennemi hors vue masqué")
	check(s.known_buildings.has(camp.id), "dernière position connue du bâtiment conservée")
	s.tick(0.1)
	check(scout.target == -1, "perte de contact annule le suivi automatique")
	camp.hp = 0
	s.update_visibility()
	check(s.known_buildings.has(camp.id), "destruction hors vue non révélée")
	scout.pos = Vector2(23, 5)
	s.update_visibility()
	check(not s.known_buildings.has(camp.id), "nouvelle reconnaissance retire le renseignement périmé")
	var moving_enemy := find(s, "jaffa")
	moving_enemy.pos = Vector2(12, 18)
	s.update_visibility()
	check(s.entity_visible(moving_enemy), "ennemi entrant dans le périmètre détecté")
	moving_enemy.pos = Vector2(30, 1)
	s.update_visibility()
	check(not s.entity_visible(moving_enemy) and not s.known_buildings.has(moving_enemy.id), "aucune mémoire de position mobile hors vue")
	var frontier := established()
	frontier.supplies = 999
	frontier.deposit_found = true
	for e in frontier.entities:
		if e.side == "enemy":
			e.hp = 0
	check(not frontier.build("mine", Sim.DEPOSIT), "pas de construction dans une zone hors vue")
	var scouts := []
	for e in frontier.entities:
		if e.kind == "soldier":
			scouts.append(e)
	scouts[0].pos = Sim.DEPOSIT + Vector2(-2, 0)
	frontier.update_visibility()
	check(frontier.build("mine", Sim.DEPOSIT), "construction après reconnaissance")
	scouts[0].pos = Vector2(4, 21)
	frontier.update_visibility()
	check(not frontier.is_visible(Sim.DEPOSIT), "chantier ne révèle pas la carte à distance")
	advance(frontier, 13)
	check(frontier.is_visible(Sim.DEPOSIT), "bâtiment achevé surveille son périmètre")
	var placement := established()
	var hidden := find(placement, "jaffa")
	hidden.pos = Vector2(18, 18)
	placement.update_visibility()
	check(not placement.entity_visible(hidden) and placement.build_error("generator", Vector2(14, 18)) == "",
		"aperçu de construction ne détecte pas les ennemis cachés")
	find(placement, "soldier").pos = Vector2(12, 18)
	placement.update_visibility()
	check(placement.entity_visible(hidden) and placement.build_error("generator", Vector2(14, 18)) != "",
		"périmètre ennemi bloquant une fois reconnu")


func _test_terrain() -> void:
	var s := established()
	var blocked := Vector2i(7, 10)
	check(s.grid.is_point_solid(blocked) and s.terrain_blocked(Vector2(blocked)), "massifs communs à la navigation et au terrain")
	var scout := find(s, "soldier")
	scout.pos = Vector2(7, 13)
	s.update_visibility()
	check(not s.build("turret", Vector2(7, 11)), "construction dans une forêt refusée")
	s.order([scout.id], Vector2(7, 7))
	var avoids: bool = not scout.path.is_empty()
	for point in scout.path:
		avoids = avoids and not s.terrain_blocked(point)
	check(avoids, "chemin contourne les massifs")
	var hits := []
	s.hit.connect(func(id, damage, destroyed): hits.append([id, damage, destroyed]))
	var enemy := find(s, "jaffa")
	enemy.pos = scout.pos + Vector2(1, 0)
	enemy.hp = 1
	s.update_visibility()
	s.tick(0.1)
	check(hits.any(func(event): return event[0] == enemy.id and event[2]), "signal de dégâts avec destruction")
