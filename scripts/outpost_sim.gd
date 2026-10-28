extends RefCounted
## Simulation de l'escarmouche, indépendante de la campagne et de ses sauvegardes.
## Coordonnées en cases ; la vue 3D les multiplie par deux.

signal notice(text: String)
signal shot(from: Vector2, to: Vector2, enemy: bool)
signal hit(id: int, damage: float, destroyed: bool)
signal phase_changed(phase: String)

const SIZE := Vector2i(32, 24)
const GATE := Vector2(4, 19)
const DEPOSIT := Vector2(16, 12)
const RUINS := Vector2(23, 18)
const HQ_SITE := Vector2(8, 18)
const PROFILES := {
	"balanced": {"name": "SG-1 · Équipe polyvalente", "hp": 90, "damage": 10, "vision": 6, "supplies": 320},
	"assault": {"name": "SG-3 · Assaut", "hp": 110, "damage": 12, "vision": 5, "supplies": 260},
	"recon": {"name": "SG-9 · Reconnaissance", "hp": 80, "damage": 9, "vision": 8, "supplies": 360},
}
## Massifs boisés / rocheux : mêmes obstacles pour la vue, le placement et l'A*.
const TERRAIN := [Rect2i(2, 4, 5, 3), Rect2i(10, 3, 4, 3), Rect2i(7, 9, 2, 3),
	Rect2i(21, 10, 2, 3), Rect2i(26, 20, 4, 3)]
const BUILDINGS := {
	"hq": {"name": "Commandement", "cost": 100, "hp": 600, "time": 12.0, "power": 0},
	"generator": {"name": "Générateur", "cost": 70, "hp": 220, "time": 8.0, "power": -8},
	"turret": {"name": "Tourelle", "cost": 65, "hp": 260, "time": 9.0, "power": 2},
	"infirmary": {"name": "Infirmerie", "cost": 80, "hp": 240, "time": 10.0, "power": 2},
	"lab": {"name": "Laboratoire", "cost": 100, "hp": 240, "time": 12.0, "power": 3},
	"mine": {"name": "Extracteur", "cost": 90, "hp": 260, "time": 12.0, "power": 3},
}
const SPECIALISTS := {
	"medic": {"name": "Médecin", "cost": 55, "hp": 70, "requires": "infirmary"},
	"scientist": {"name": "Scientifique", "cost": 65, "hp": 60, "requires": "lab"},
	"engineer": {"name": "Ingénieur", "cost": 45, "hp": 65, "requires": "hq"},
}

var entities: Array[Dictionary] = []
var supplies := 320.0
var naquadah := 0.0
var elapsed := 0.0
var raid_in := 100.0
var wave := 0
var gate_in := 0.0
var result := ""
var deposit_found := false
var ruins_found := false
var researched := false
var _next_id := 0
var _income_clock := 0.0
var grid := AStarGrid2D.new()
var visible_cells := PackedByteArray()
var explored_cells := PackedByteArray()
## Renseignements mémorisés, sans PV ni position mobile hors du champ de vision.
var known_buildings := {}
var camp_found := false
var vision_revision := 0
var _vision_clock := 0.0
var phase := "arrival" # arrival → recon → deployment → establish → base
var difficulty := "normal"
var profile := "balanced"
var arrival_clock := 0.0
var landing_scanned := false
var gate_hold := 0.0
var gate_job := ""
var _arrival_spawned := 0
var _deployment_arrived := false
var _had_hq := false
var _transit_queue: Array[String] = []
var _transit_clock := 0.0
var squads := {1: [], 2: [], 3: []}
var ruins_study := 0.0
var ruins_studied := false


func _init(options: Dictionary = {}) -> void:
	difficulty = str(options.get("difficulty", "normal"))
	if difficulty not in ["easy", "normal", "hard"]:
		difficulty = "normal"
	profile = str(options.get("profile", "balanced"))
	if not PROFILES.has(profile):
		profile = "balanced"
	supplies = PROFILES[profile].supplies
	raid_in = {"easy": 130.0, "normal": 100.0, "hard": 80.0}[difficulty]
	grid.region = Rect2i(Vector2i.ZERO, SIZE)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for area in TERRAIN:
		for x in range(area.position.x, area.end.x):
			for y in range(area.position.y, area.end.y):
				grid.set_point_solid(Vector2i(x, y), true)
	visible_cells.resize(SIZE.x * SIZE.y)
	explored_cells.resize(SIZE.x * SIZE.y)
	_add("camp", "enemy", Vector2(27, 5))
	for p in [Vector2(25, 8), Vector2(28, 8), Vector2(18, 11)]:
		_add("jaffa", "enemy", p)
	# Only test/preview harnesses may request the former already-established start.
	if options.get("established", false):
		phase = "base"
		_had_hq = true
		_add("hq", "sgc", HQ_SITE)
		for i in 4:
			_add("soldier", "sgc", Vector2(4 + i, 21))
	else:
		for p in [Vector2(11, 17), Vector2(12, 19)]:
			_add("jaffa", "enemy", p)
	update_visibility()


func _phase(next: String) -> void:
	phase = next
	phase_changed.emit(next)


func landing_secure() -> bool:
	if not landing_scanned or count("soldier") == 0:
		return false
	var team_near := false
	for e in entities:
		if e.hp <= 0:
			continue
		if e.side == "enemy" and e.pos.distance_to(HQ_SITE) < 6:
			return false
		if e.kind == "soldier" and e.pos.distance_to(HQ_SITE) < 4:
			team_near = true
	return team_near


func request_deployment() -> bool:
	if result != "" or phase != "recon" or not landing_secure() or gate_busy():
		notice.emit("Reconnaissez la clairière et éliminez les menaces près du futur commandement.")
		return false
	gate_job = "deployment"
	gate_in = 12.0
	_phase("deployment")
	notice.emit("SGC : déploiement autorisé. Deux ingénieurs et le matériel franchiront la porte dans 12 secondes.")
	return true


func gate_busy() -> bool:
	return phase == "arrival" or gate_in > 0 or gate_hold > 0 or not _transit_queue.is_empty()


func gate_open() -> bool:
	return (phase == "arrival" and arrival_clock >= 1.8) or (gate_in > 0 and gate_in <= 3) or gate_hold > 0 or not _transit_queue.is_empty()


func skip_arrival() -> void:
	while phase == "arrival" and result == "":
		tick(0.1)


func convoy_arrived() -> bool:
	return _deployment_arrived


func _arrive_soldier(first_wave: bool = false) -> void:
	var soldier := _add("soldier", "sgc", GATE + Vector2(0, 0.35))
	soldier["first_wave"] = first_wave
	if first_wave:
		soldier["member"] = ["oneill", "carter", "daniel", "tealc"][_arrival_spawned] if profile == "balanced" else ["oneill", "daniel", "carter", "oneill"][_arrival_spawned]
		_route(soldier, GATE + Vector2(_arrival_spawned - 1, 3))
	else:
		_route(soldier, GATE + Vector2(count("soldier") % 3 - 1, 3))


func _tick_arrival(delta: float) -> void:
	arrival_clock += delta
	if _arrival_spawned < 4 and arrival_clock >= 3.2 + _arrival_spawned * 0.7:
		_arrive_soldier(true)
		_arrival_spawned += 1
	for e in entities:
		if e.side == "sgc":
			_step_entity(e, delta)
	if arrival_clock >= 7.5:
		gate_hold = 0.8
		_phase("recon")
		notice.emit("Première équipe arrivée. Reconnaissez la clairière balisée et sécurisez le périmètre avant d'appeler le SGC.")
		update_visibility()


func _tick_gate(delta: float) -> void:
	gate_hold = maxf(0, gate_hold - delta)
	if gate_in > 0:
		gate_in = maxf(0, gate_in - delta)
		if gate_in == 0:
			if SPECIALISTS.has(gate_job):
				_transit_queue.assign([gate_job])
			else:
				_transit_queue.assign(["engineer", "engineer"] if gate_job == "deployment" else ["soldier", "soldier", "soldier"])
			gate_job = ""
			_transit_clock = 0.0
			gate_hold = 5.0
	if not _transit_queue.is_empty():
		_transit_clock -= delta
		if _transit_clock <= 0:
			_transit_clock = 0.7
			var kind: String = _transit_queue.pop_front()
			if kind == "soldier":
				_arrive_soldier()
			elif phase in ["deployment", "establish"] and kind == "engineer":
				_deployment_arrived = true
				var engineer := _add("engineer", "sgc", GATE + Vector2(0, 0.35))
				_route(engineer, HQ_SITE + Vector2(count("engineer") - 1, 2))
			else:
				var specialist := _add(kind, "sgc", GATE + Vector2(0, 0.35))
				_route(specialist, GATE + Vector2(1, 3))
			if _transit_queue.is_empty():
				gate_hold = 2.0
				notice.emit("SGC : personnel et matériel arrivés. Gardez les ingénieurs près du chantier." if phase in ["deployment", "establish"] else "SGC : renforts arrivés par la porte.")


func _cell_index(point: Vector2) -> int:
	var cell := Vector2i(point.round())
	if not grid.is_in_boundsv(cell):
		return -1
	return cell.y * SIZE.x + cell.x


func is_visible(point: Vector2) -> bool:
	var index := _cell_index(point)
	return index >= 0 and visible_cells[index] > 0


func is_explored(point: Vector2) -> bool:
	var index := _cell_index(point)
	return index >= 0 and explored_cells[index] > 0


func entity_visible(e: Dictionary) -> bool:
	return e.hp > 0 and (e.side == "sgc" or is_visible(e.pos))


func update_visibility() -> void:
	visible_cells.fill(0)
	# La porte conserve un petit périmètre surveillé, même sans escouade sur place.
	_reveal(GATE, 4)
	for e in entities:
		if e.hp <= 0 or e.side != "sgc" or e.build > 0:
			continue
		var radius: int = PROFILES[profile].vision if e.kind == "soldier" else (6 if e.kind == "turret" else (8 if e.kind == "hq" else 4))
		_reveal(e.pos, radius)
	for e in entities:
		if e.hp > 0 and e.side == "enemy" and is_building(e) and is_visible(e.pos):
			known_buildings[e.id] = {"kind": e.kind, "pos": e.pos}
			if e.kind == "camp" and not camp_found:
				camp_found = true
				notice.emit("Camp goa'uld localisé. Sa position est enregistrée sur la carte.")
	for id in known_buildings.keys():
		if is_visible(known_buildings[id].pos) and entity(id).is_empty():
			known_buildings.erase(id)
	if not deposit_found and is_visible(DEPOSIT):
		deposit_found = true
		notice.emit("Gisement repéré. Éliminez les gardes puis placez un extracteur.")
	vision_revision += 1


func _reveal(center: Vector2, radius: int) -> void:
	var cell := Vector2i(center.round())
	for x in range(maxi(0, cell.x - radius), mini(SIZE.x, cell.x + radius + 1)):
		for y in range(maxi(0, cell.y - radius), mini(SIZE.y, cell.y + radius + 1)):
			if Vector2(x, y).distance_squared_to(center) <= radius * radius:
				var index := y * SIZE.x + x
				visible_cells[index] = 1
				explored_cells[index] = 1


func terrain_blocked(pos: Vector2, margin: float = 0.0) -> bool:
	for area in TERRAIN:
		var bounds := Rect2(Vector2(area.position) - Vector2.ONE * 0.5, Vector2(area.size))
		if bounds.grow(margin).has_point(pos):
			return true
	return false


func _add(kind: String, side: String, pos: Vector2, construction: float = 0.0) -> Dictionary:
	var hp := 90.0
	if kind == "soldier":
		hp = PROFILES[profile].hp
	elif kind == "engineer":
		hp = 65.0
	if SPECIALISTS.has(kind):
		hp = SPECIALISTS[kind].hp
	if BUILDINGS.has(kind):
		hp = BUILDINGS[kind].hp
	elif kind == "camp":
		hp = 650.0
	elif kind == "jaffa":
		hp = 75.0
	if side == "enemy":
		hp *= {"easy": 0.8, "normal": 1.0, "hard": 1.2}[difficulty]
	var e := {"id": _next_id, "kind": kind, "side": side, "pos": pos,
		"hp": hp, "max_hp": hp, "build": construction, "cooldown": 0.0,
		"target": -1, "goal": pos, "path": [], "moving": false}
	_next_id += 1
	entities.append(e)
	if is_building(e):
		grid.set_point_solid(Vector2i(pos), true)
		_clear_building_cell(Vector2i(pos))
	return e


func _clear_building_cell(cell: Vector2i) -> void:
	# Le chantier automatique peut apparaître sous l'équipe de reconnaissance.
	# Évacuer chaque occupant vers une case libre avant de recalculer ses ordres.
	for unit in entities:
		if unit.hp <= 0 or is_building(unit) or Vector2i(unit.pos.round()) != cell:
			continue
		var destination := Vector2(cell)
		var best := INF
		for x in range(-4, 5):
			for y in range(-4, 5):
				var candidate := cell + Vector2i(x, y)
				if not grid.is_in_boundsv(candidate) or grid.is_point_solid(candidate):
					continue
				var occupied := false
				for other in entities:
					if other.hp > 0 and not is_building(other) and Vector2i(other.pos.round()) == candidate:
						occupied = true
						break
				var distance: float = unit.pos.distance_squared_to(Vector2(candidate))
				if not occupied and distance < best:
					best = distance
					destination = Vector2(candidate)
		if best == INF:
			continue
		var goal: Vector2 = unit.goal
		var had_order: bool = unit.moving or not unit.path.is_empty()
		unit.pos = destination
		if had_order:
			_route(unit, goal)
		else:
			unit.goal = destination
			unit.path.clear()
			unit.moving = false


func entity(id: int) -> Dictionary:
	for e in entities:
		if e.id == id and e.hp > 0:
			return e
	return {}


func is_building(e: Dictionary) -> bool:
	return BUILDINGS.has(e.kind) or e.kind == "camp"


func count(kind: String, complete: bool = true) -> int:
	var n := 0
	for e in entities:
		if e.hp > 0 and e.kind == kind and (not complete or e.build <= 0):
			n += 1
	return n


func power() -> Vector2i:
	var used := 0
	var capacity := 0
	for e in entities:
		if e.hp <= 0 or e.build > 0 or not BUILDINGS.has(e.kind):
			continue
		var p: int = BUILDINGS[e.kind].power
		used += maxi(p, 0)
		capacity += maxi(-p, 0)
	return Vector2i(used, capacity)


func powered() -> bool:
	var p := power()
	return p.y >= p.x


func build_error(kind: String, pos: Vector2) -> String:
	if result != "" or not BUILDINGS.has(kind):
		return "Construction indisponible."
	if phase != "base":
		return "Sécurisez la zone et attendez l'installation du commandement par les ingénieurs."
	if supplies < BUILDINGS[kind].cost:
		return "Ravitaillement insuffisant."
	if kind == "hq" and count("hq", false) > 0:
		return "Le commandement est déjà établi."
	if pos.x < 1 or pos.y < 1 or pos.x >= SIZE.x - 1 or pos.y >= SIZE.y - 1:
		return "En dehors de la zone constructible."
	if not is_visible(pos):
		return "Envoyez des soldats reconnaître cet emplacement."
	if terrain_blocked(pos, 0.8):
		return "Le relief ou la végétation empêche la construction."
	if pos.distance_to(GATE) < 2.5:
		return "Laissez le passage de la porte dégagé."
	for e in entities:
		if e.hp > 0 and not is_building(e) and pos.distance_to(e.pos) < 0.8:
			return "Un soldat occupe cet emplacement."
		if e.hp > 0 and is_building(e) and pos.distance_to(e.pos) < 2.5:
			return "Un bâtiment est trop proche."
		if e.hp > 0 and e.side == "enemy" and entity_visible(e) and pos.distance_to(e.pos) < 5:
			return "Sécurisez d'abord le périmètre."
	if kind == "mine":
		if not deposit_found:
			return "Explorez le gisement avec vos soldats."
		if count("mine", false) > 0 or pos.distance_to(DEPOSIT) > 1.5:
			return "Placez un unique extracteur sur le gisement."
	else:
		if pos.distance_to(DEPOSIT) < 2:
			return "Cet emplacement est réservé à l'extracteur."
		var near_base := pos.distance_to(GATE) <= 7
		for e in entities:
			if e.hp > 0 and e.kind == "hq" and e.build <= 0 and pos.distance_to(e.pos) <= 8:
				near_base = true
		if not near_base:
			return "Construisez à proximité de la porte ou du commandement."
	return ""


func build(kind: String, pos: Vector2) -> bool:
	pos = pos.round()
	var error := build_error(kind, pos)
	if error != "":
		notice.emit(error)
		return false
	supplies -= BUILDINGS[kind].cost
	_add(kind, "sgc", pos, BUILDINGS[kind].time)
	notice.emit("Construction : %s." % BUILDINGS[kind].name)
	return true


func repair_cost(id: int) -> int:
	var e := entity(id)
	if e.is_empty() or e.side != "sgc" or not BUILDINGS.has(e.kind) or e.build > 0:
		return 0
	return ceili((e.max_hp - e.hp) / 5.0)


func squad_members(slot: int) -> Array:
	var alive: Array = []
	for id in squads.get(slot, []):
		if not entity(id).is_empty():
			alive.append(id)
	if squads.has(slot):
		squads[slot] = alive
	return alive.duplicate()


func assign_squad(slot: int, ids: Array) -> void:
	if not squads.has(slot):
		return
	var members: Array = []
	for id in ids:
		var e := entity(id)
		if not e.is_empty() and e.side == "sgc" and not is_building(e) and not members.has(id):
			members.append(id)
	if members.is_empty():
		notice.emit("Sélectionnez des unités pour mémoriser une escouade.")
		return
	squads[slot] = members
	notice.emit("Escouade %d mémorisée · %d membres." % [slot, members.size()])


func recruit_error(kind: String) -> String:
	if not SPECIALISTS.has(kind) or result != "" or phase != "base":
		return "Recrutement indisponible."
	if count("hq") == 0 or count(SPECIALISTS[kind].requires) == 0:
		return "Requiert : %s opérationnel." % BUILDINGS[SPECIALISTS[kind].requires].name
	if gate_busy():
		return "Porte occupée : attendez la fin du convoi."
	if supplies < SPECIALISTS[kind].cost:
		return "Ravitaillement insuffisant."
	if count(kind, false) >= 4:
		return "Maximum : 4 spécialistes de ce type."
	return ""


func recruit(kind: String) -> bool:
	var error := recruit_error(kind)
	if error != "":
		notice.emit(error)
		return false
	supplies -= SPECIALISTS[kind].cost
	gate_job = kind
	gate_in = 10.0
	notice.emit("SGC : %s en préparation · 10 secondes." % SPECIALISTS[kind].name)
	return true


func repair(id: int) -> bool:
	var cost := repair_cost(id)
	if result != "" or phase != "base" or cost <= 0 or supplies < cost:
		notice.emit("Réparation : bâtiment achevé endommagé et ravitaillement suffisant requis.")
		return false
	var e := entity(id)
	supplies -= cost
	e.hp = e.max_hp
	notice.emit("%s réparé · %d ravitaillements." % [BUILDINGS[e.kind].name, cost])
	return true


func reinforce() -> bool:
	if result != "" or phase != "base" or gate_busy() or supplies < 85 or count("hq") == 0 or count("soldier") > 17:
		notice.emit("Renforts : 85 ravitaillement, commandement actif, porte libre et moins de 18 soldats requis.")
		return false
	supplies -= 85
	gate_in = 18.0
	gate_job = "reinforcements"
	notice.emit("SGC : trois soldats en préparation. Arrivée dans 18 secondes.")
	return true


func research() -> bool:
	if result != "" or researched or count("lab") == 0 or not powered() or naquadah < 30:
		notice.emit("Recherche : laboratoire alimenté et 30 naquadah requis.")
		return false
	naquadah -= 30
	researched = true
	notice.emit("Munitions améliorées : dégâts des soldats et tourelles +40 %.")
	return true


func order(ids: Array, point: Vector2, target: int = -1) -> void:
	if result != "" or phase == "arrival":
		return
	if target >= 0:
		var foe := entity(target)
		if foe.is_empty() or foe.side != "enemy" or not entity_visible(foe):
			notice.emit("Cible hors de vue. Envoyez une équipe en reconnaissance.")
			return
	var index := 0
	for id in ids:
		var e := entity(id)
		if e.is_empty() or e.side != "sgc" or is_building(e):
			continue
		e.target = target
		var offset := Vector2(index % 3 - 1, index / 3) if ids.size() > 1 else Vector2.ZERO
		_route(e, point + offset if target < 0 else point)
		index += 1


func _route(e: Dictionary, point: Vector2) -> void:
	var start := Vector2i(e.pos.round()).clamp(Vector2i.ZERO, SIZE - Vector2i.ONE)
	var end := Vector2i(point.round()).clamp(Vector2i.ZERO, SIZE - Vector2i.ONE)
	if grid.is_point_solid(end):
		var best := start
		var distance := INF
		for x in range(-1, 2):
			for y in range(-1, 2):
				var candidate := end + Vector2i(x, y)
				if grid.is_in_boundsv(candidate) and not grid.is_point_solid(candidate):
					var d := Vector2(candidate).distance_to(e.pos)
					if d < distance:
						distance = d
						best = candidate
		end = best
	var path := grid.get_id_path(start, end, true)
	e.path = []
	for i in range(1, path.size()):
		e.path.append(Vector2(path[i]))
	e.goal = Vector2(end)
	e.moving = not e.path.is_empty()


func tick(delta: float) -> void:
	if result != "":
		return
	elapsed += delta
	_vision_clock += delta
	if _vision_clock >= 0.2:
		_vision_clock = 0.0
		update_visibility()
	if phase == "arrival":
		_tick_arrival(delta)
		return
	_tick_gate(delta)
	_income_clock += delta
	if _income_clock >= 1.0:
		_income_clock -= 1.0
		supplies += 4 if count("hq") > 0 else 0
		if powered():
			naquadah += count("mine") * 2
			for e in entities:
				if e.side == "sgc" and not is_building(e) and e.hp > 0:
					for b in entities:
						if b.kind == "infirmary" and b.hp > 0 and b.build <= 0 and e.pos.distance_to(b.pos) < 5:
							e.hp = minf(e.max_hp, e.hp + 5)
	if phase == "base":
		raid_in -= delta
	if phase == "base" and raid_in <= 0 and count("camp") > 0:
		wave += 1
		raid_in = maxf(45, 90 - wave * 5)
		for i in mini(2 + wave, 7):
			var raider := _add("jaffa", "enemy", Vector2(25 + i % 4, 7 + i / 4))
			_route(raider, Vector2(8, 18))
		notice.emit("Alerte : une patrouille jaffa marche sur l'avant-poste !")
	var finished_construction := false
	for e in entities:
		if e.hp <= 0:
			continue
		if e.build > 0:
			if e.kind == "hq" and phase == "establish" and not _engineer_near(3):
				continue
			e.build = maxf(0, e.build - delta)
			if e.build == 0:
				finished_construction = true
				notice.emit("%s opérationnel." % BUILDINGS[e.kind].name)
			continue
		_step_entity(e, delta)
	if phase == "recon":
		for e in entities:
			if e.hp > 0 and e.kind == "soldier" and e.pos.distance_to(HQ_SITE) <= 2.5:
				landing_scanned = true
	if phase == "deployment" and _deployment_arrived and _engineer_near(2.5):
		_add("hq", "sgc", HQ_SITE, BUILDINGS.hq.time)
		_had_hq = true
		_phase("establish")
		notice.emit("Les ingénieurs installent le commandement. Protégez le chantier.")
	if phase == "establish" and count("hq") > 0:
		_phase("base")
		notice.emit("Avant-poste opérationnel. Construction, ravitaillement et renforts militaires disponibles.")
	if finished_construction:
		update_visibility()
	if (_had_hq and count("hq", false) == 0) or (phase != "base" and count("soldier") == 0):
		result = "defeat"
		notice.emit("EXPÉDITION PERDUE · Commandement détruit ou première équipe hors de combat.")
	elif _deployment_arrived and phase in ["deployment", "establish"] and count("engineer") == 0 and _transit_queue.is_empty():
		result = "defeat"
		notice.emit("DÉPLOIEMENT PERDU · Les ingénieurs ont été éliminés avant la fin du chantier.")
	elif count("camp") == 0 and count("mine") > 0:
		result = "victory"
		notice.emit("PLANÈTE SÉCURISÉE · Gisement exploité et camp goa'uld neutralisé !")
	# Retire aussi les entités de la simulation pour éviter une croissance illimitée.
	entities = entities.filter(func(e): return e.hp > 0)


func _engineer_near(radius: float) -> bool:
	for e in entities:
		if e.hp > 0 and e.kind == "engineer" and e.pos.distance_to(HQ_SITE) <= radius:
			return true
	return false


func _step_entity(e: Dictionary, delta: float) -> void:
	e.cooldown = maxf(0, e.cooldown - delta)
	if e.kind in ["soldier", "scientist"]:
		if not ruins_found and e.pos.distance_to(RUINS) < 3:
			ruins_found = true
			naquadah += 30
			supplies += 75
			notice.emit("Ruines explorées : +30 naquadah et +75 ravitaillement.")
	if e.side == "sgc" and e.path.is_empty():
		_specialist_work(e, delta)
	var armed: bool = e.kind in ["soldier", "jaffa", "turret", "camp"]
	if e.kind == "turret" and not powered():
		armed = false
	var reach := 5.5 if e.kind in ["turret", "camp"] else 4.0
	var foe := entity(e.target)
	if foe.is_empty() or foe.side == e.side:
		e.target = -1
		foe = {}
	elif e.side == "sgc" and not entity_visible(foe):
		# On rejoint la dernière position connue sans poursuivre une cible invisible.
		e.target = -1
		foe = {}
	# Un ordre de déplacement garde la priorité ; les soldats tirent en marchant.
	if foe.is_empty() or e.pos.distance_to(foe.pos) > reach:
		var nearest := reach
		for other in entities:
			if other.hp > 0 and other.side != e.side and (e.side == "enemy" or entity_visible(other)):
				var distance: float = e.pos.distance_to(other.pos)
				if distance <= nearest:
					nearest = distance
					foe = other
	var in_range: bool = not foe.is_empty() and e.pos.distance_to(foe.pos) <= reach
	if armed and in_range and e.cooldown <= 0:
		e.cooldown = 0.85 if e.kind == "soldier" else 1.3
		var damage: float = PROFILES[profile].damage if e.kind == "soldier" else 14.0
		if e.side == "enemy":
			damage *= {"easy": 0.75, "normal": 1.0, "hard": 1.25}[difficulty]
		if e.side == "sgc" and researched:
			damage *= 1.4
		foe.hp -= damage
		shot.emit(e.pos, foe.pos, e.side == "enemy")
		hit.emit(foe.id, damage, foe.hp <= 0)
		if foe.hp <= 0 and is_building(foe):
			grid.set_point_solid(Vector2i(foe.pos), false)
			notice.emit("Bâtiment détruit : %s." % ("camp goa'uld" if foe.kind == "camp" else BUILDINGS[foe.kind].name))
	if is_building(e):
		return
	var explicit_target := entity(e.target)
	if not explicit_target.is_empty():
		if e.pos.distance_to(explicit_target.pos) <= reach:
			e.moving = false
			return
		if e.path.is_empty():
			_route(e, explicit_target.pos)
	elif e.side == "enemy" and in_range:
		e.moving = false
		return
	if e.path.is_empty():
		e.moving = false
		return
	var next: Vector2 = e.path[0]
	if grid.is_point_solid(Vector2i(next)):
		_route(e, e.goal)
		return
	e.pos = e.pos.move_toward(next, delta * (2.2 if e.side == "sgc" else 1.6))
	e.moving = true
	if e.pos.distance_to(next) < 0.02:
		e.path.pop_front()


func _specialist_work(e: Dictionary, delta: float) -> void:
	if e.kind == "medic" and e.cooldown <= 0:
		var patient := {}
		var lowest := 1.0
		for unit in entities:
			if unit.side != "sgc" or is_building(unit) or unit.hp <= 0 or e.pos.distance_to(unit.pos) > 3:
				continue
			var ratio: float = unit.hp / unit.max_hp
			if ratio < lowest:
				patient = unit
				lowest = ratio
		if not patient.is_empty():
			patient.hp = minf(patient.max_hp, patient.hp + 6)
			e.cooldown = 1.0
	elif e.kind == "engineer" and supplies > 0:
		for b in entities:
			if b.side == "sgc" and is_building(b) and b.hp > 0 and b.build <= 0 and b.hp < b.max_hp and e.pos.distance_to(b.pos) <= 3:
				var amount: float = minf(minf(5 * delta, b.max_hp - b.hp), supplies * 5)
				b.hp += amount
				supplies = maxf(0, supplies - amount / 5.0)
				break
	elif e.kind == "scientist" and not ruins_studied and e.pos.distance_to(RUINS) < 3:
		# Un seul chercheur fait progresser l'étude, quel que soit l'effectif envoyé.
		for other in entities:
			if other.id < e.id and other.kind == "scientist" and other.side == "sgc" and other.hp > 0 and other.path.is_empty() and other.pos.distance_to(RUINS) < 3:
				return
		ruins_study = minf(12, ruins_study + delta)
		if ruins_study >= 12:
			ruins_studied = true
			naquadah += 50
			supplies += 100
			notice.emit("Étude des Anciens terminée : +50 naquadah et +100 ravitaillement.")
