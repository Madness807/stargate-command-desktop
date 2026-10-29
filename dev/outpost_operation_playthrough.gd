extends Node
## Parcours sans création d'unités, dégâts forcés ou modification de ressources.
## L'agent n'utilise que les ordres et actions disponibles au joueur.
const Sim = preload("res://scripts/outpost_sim.gd")
const Op = preload("res://scripts/outpost_operation.gd")
const Cli = preload("res://scripts/cli.gd")
var sim: RefCounted
var transitions := []
var events := []
var checks := 0
var failures := 0
var _last_stage := ""
var _decide_in := 0.0
var resumed := false
var progress_in := 0.0
var build_issue := ""
var defenders: Array = []
var rescue_route := false

func allies(kind: String) -> Array:
	return sim.entities.filter(func(e): return e.hp > 0 and e.side == "sgc" and e.kind == kind)

func halt_near(units: Array, point: Vector2, radius: float) -> void:
	for e in units:
		if e.pos.distance_to(point) <= radius:
			e.path.clear()
			e.target = -1
			e.moving = false
		elif e.goal.distance_to(point) > 0.1 or e.path.is_empty():
			sim.order([e.id], point)

func army(point: Vector2) -> void:
	var troops := allies("soldier")
	if troops.is_empty(): return
	if sim.phase == "base" and troops.size() >= 8:
		defenders = defenders.filter(func(id): return not sim.entity(id).is_empty())
		for e in troops:
			if defenders.size() >= 3: break
			if not defenders.has(e.id): defenders.append(e.id)
		for id in defenders:
			halt_near([sim.entity(id)], Vector2(8, 15), 1)
		troops = troops.filter(func(e): return not defenders.has(e.id))
	var target := {}
	var distance := INF
	for enemy in sim.entities:
		if enemy.hp <= 0 or enemy.side != "enemy" or not sim.entity_visible(enemy): continue
		if enemy.kind == "camp" and sim.operation.stage in ["archives", "relays"]: continue
		if sim.phase == "base" and enemy.pos.distance_to(point) > 9: continue
		for soldier in troops:
			var d: float = soldier.pos.distance_to(enemy.pos)
			if d < 6.0 and d < distance:
				target = enemy
				distance = d
	for e in troops:
		if not target.is_empty():
			if e.target != target.id or (e.path.is_empty() and not sim.line_of_fire(e.pos, target.pos)):
				sim.order([e.id], target.pos, target.id)
		elif e.pos.distance_to(point) > 1.5 and (e.goal.distance_to(point) > 0.1 or e.path.is_empty()):
			sim.order([e.id], point)
	for medic in allies("medic"):
		var lowest: Dictionary = troops[0]
		for e in troops:
			if e.hp / e.max_hp < lowest.hp / lowest.max_hp:
				lowest = e
		halt_near([medic], lowest.pos, 2.0)

func build_next() -> bool:
	var plan := [["generator", Vector2(5, 15)], ["turret", Vector2(11, 16)], ["infirmary", Vector2(5, 22)], ["lab", Vector2(12, 21)], ["generator", Vector2(2, 15)], ["turret", Vector2(11, 12)], ["turret", Vector2(14, 16)]]
	for item in plan:
		var exists: bool = sim.entities.any(func(e): return e.hp > 0 and e.kind == item[0] and e.pos == item[1])
		if exists: continue
		# Un seul chantier commandé à la fois : l'ingénieur n'est pas rappelé ailleurs.
		if sim.entities.any(func(e): return e.hp > 0 and e.side == "sgc" and e.build > 0): return true
		build_issue = item[0] + " : " + sim.build_error(item[0], item[1])
		if sim.build_error(item[0], item[1]) == "":
			sim.build(item[0], item[1])
		return true
	return false

func decide() -> void:
	if sim.phase == "arrival": return
	if sim.phase == "recon":
		army(Sim.HQ_SITE + Vector2(0, 1))
		if sim.landing_secure(): sim.request_deployment()
		return
	if sim.phase != "base":
		army(Sim.HQ_SITE + Vector2(0, 2))
		return
	var o: Dictionary = sim.operation
	if o.stage == "evacuation": return
	var preparing := build_next() if o.stage not in ["ready", "return"] else false
	for e in sim.entities:
		if e.side == "sgc" and sim.is_building(e) and e.build <= 0 and e.hp < e.max_hp * 0.6 and sim.supplies > 150:
			sim.repair(e.id)
	if sim.count("engineer") < 2 and sim.recruit_error("engineer") == "": sim.recruit("engineer")
	if sim.count("medic") < 1 and sim.recruit_error("medic") == "" and sim.supplies > 100: sim.recruit("medic")
	if sim.count("scientist") == 0 and sim.recruit_error("scientist") == "" and sim.supplies > 100: sim.recruit("scientist")
	if sim.count("soldier") < 10 and sim.supplies >= (250 if preparing else 120) and not sim.gate_busy(): sim.reinforce()
	if not sim.powered() and sim.operation_error("backup") == "": sim.operation_action("backup")
	if o.stage == "archives":
		if rescue_route and not preparing and not o.rescue_returned and not o.rescue_lost:
			army(Op.RESCUE)
			for e in sim.entities:
				if e.hp > 0 and e.get("rescued", false):
					halt_near([e], Sim.HQ_SITE + Vector2(0, 1), 1)
		elif preparing:
			army(Sim.HQ_SITE + Vector2(2, -1))
		elif sim.count("mine", false) == 0:
			army(Sim.DEPOSIT + Vector2(0, 1))
			if sim.build_error("mine", Sim.DEPOSIT) == "": sim.build("mine", Sim.DEPOSIT)
		else:
			army(Sim.RUINS + Vector2(-1, 0))
			halt_near(allies("scientist"), Sim.RUINS, 2)
	elif o.stage == "relays":
		var index := 0 if o.relays[0] < Op.RELAY_TIME else 1
		var point: Vector2 = Op.RELAYS[index]
		army(point + Vector2(0, 1))
		var engineers := allies("engineer")
		if not engineers.is_empty(): halt_near([engineers[-1]], point, 2)
		if sim.operation_error("relay_" + str(index)) == "": sim.operation_action("relay_" + str(index))
		if sim.count("mine") == 0 and sim.build_error("mine", Sim.DEPOSIT) == "": sim.build("mine", Sim.DEPOSIT)
	elif o.stage == "assault":
		army(Vector2(27, 8))
	elif o.stage == "transfer":
		army(Sim.RUINS + Vector2(0, -1))
		halt_near(allies("scientist"), Sim.RUINS, 2)
	elif o.stage == "return":
		army(Sim.HQ_SITE + Vector2(0, 1))
		halt_near(allies("scientist"), Sim.HQ_SITE + Vector2(1, 0), 1)
	elif o.stage == "ready":
		army(Sim.GATE + Vector2(0, 2))
		for kind in ["scientist", "engineer", "medic"]: halt_near(allies(kind), Sim.GATE + Vector2(0, 2), 1)
		if sim.operation_error("evacuate") == "": sim.operation_action("evacuate")

func _ready() -> void:
	var difficulty := Cli.value("--difficulty", "normal")
	rescue_route = Cli.has("--rescue")
	sim = Sim.new({"difficulty": difficulty, "operation": true})
	sim.notice.connect(func(message): events.append({"time": snappedf(sim.elapsed, 0.1), "text": message}))
	var max_time := 2400.0
	while sim.result == "" and sim.elapsed < max_time:
		_decide_in -= 0.1
		if _decide_in <= 0:
			_decide_in = 1.0
			decide()
		sim.tick(0.1)
		progress_in -= 0.1
		if progress_in <= 0:
			progress_in = 120
			print("SITUATION ", int(sim.elapsed), " ", sim.operation.stage, " R", int(sim.supplies), " soldats", sim.count("soldier"), " étude", sim.operation.study, " N", sim.naquadah, " chantier ", build_issue)
		var stage: String = sim.phase + "/" + sim.operation.stage
		if stage != _last_stage:
			_last_stage = stage
			transitions.append({"time": snappedf(sim.elapsed, 0.1), "stage": stage, "soldiers": sim.count("soldier"), "supplies": int(sim.supplies)})
			print("PARCOURS ", transitions[-1])
			var saved: Dictionary = sim.snapshot()
			var restored = Sim.from_snapshot(saved)
			checks += 1
			if restored == null or restored.operation != sim.operation:
				failures += 1
			# Reprise réelle de la simulation à mi-intervention, sans redistribuer les unités.
		if not resumed and sim.operation.stage == "relays" and sim.operation.relays[0] > 15:
			sim = Sim.from_snapshot(sim.snapshot())
			sim.notice.connect(func(message): events.append({"time": snappedf(sim.elapsed, 0.1), "text": message}))
			resumed = true
	checks += 1
	if sim.result != "victory": failures += 1
	if rescue_route:
		checks += 1
		if not sim.operation.rescue_returned or sim.operation.rescued_out < 1: failures += 1
	var report := {"difficulty": difficulty, "result": sim.result, "seconds": snappedf(sim.elapsed, 0.1), "resumed": resumed, "rescue_route": rescue_route, "checks": checks, "failures": failures, "transitions": transitions, "events": events, "operation": sim.operation, "remaining": sim.entities}
	var output := Cli.value("--output", "/tmp/sg1-last-watch-" + difficulty + ".json")
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("PARCOURS FINAL ", sim.result, " · ", sim.elapsed, " s · ", checks - failures, "/", checks, " · ", output)
	get_tree().quit(1 if failures else 0)
