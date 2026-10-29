extends Node

const Sim = preload("res://scripts/outpost_sim.gd")
const Outpost = preload("res://scripts/outpost.gd")
var checks := 0
var fails := 0


func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		printerr("ÉCHEC SPÉCIALISTES : ", text)


func _ready() -> void:
	var sim := Sim.new({"established": true})
	check(not sim.recruit("medic"), "infirmerie requise")
	check(not sim.recruit("scientist"), "laboratoire requis")
	check(not sim.recruit("unknown"), "type inconnu refusé")
	sim.supplies = 0
	check(not sim.recruit("engineer"), "recrutement sans ressources refusé")
	sim._add("infirmary", "sgc", Vector2(9, 15))
	sim._add("lab", "sgc", Vector2(12, 15))
	for kind in ["medic", "scientist", "engineer"]:
		sim.supplies = 500
		sim.gate_hold = 0
		var before: int = sim.count(kind)
		check(sim.recruit(kind), "recrutement " + kind)
		check(sim.supplies == 500 - Sim.SPECIALISTS[kind].cost, "coût " + kind)
		check(not sim.recruit(kind), "porte occupée " + kind)
		for i in 110:
			sim._tick_gate(0.1)
		check(sim.count(kind) == before + 1, "un seul spécialiste arrive : " + kind)
	check(not sim.convoy_arrived(), "recrutement ne déclenche pas le premier déploiement")
	var medic: Dictionary
	var scientist: Dictionary
	var engineer: Dictionary
	var soldier: Dictionary
	var hq: Dictionary
	for e in sim.entities:
		match e.kind:
			"medic": medic = e
			"scientist": scientist = e
			"engineer": engineer = e
			"soldier": soldier = e
			"hq": hq = e
	medic.pos = Vector2(5, 21)
	medic.path.clear()
	soldier.pos = Vector2(6, 21)
	soldier.hp = 40
	sim._step_entity(medic, 0.1)
	check(soldier.hp == 46, "soin réel à proximité")
	sim._step_entity(medic, 0.1)
	check(soldier.hp == 46, "soin limité par le délai")
	medic.pos = Vector2(15, 21)
	sim._step_entity(medic, 1)
	check(soldier.hp == 46, "pas de soin à distance")
	engineer.pos = hq.pos + Vector2(0, 2)
	engineer.path.clear()
	hq.hp -= 20
	sim.supplies = 1
	sim._step_entity(engineer, 1)
	check(hq.hp == hq.max_hp - 15 and sim.supplies == 0, "réparation progressive payante")
	sim._step_entity(engineer, 1)
	check(hq.hp == hq.max_hp - 15, "réparation arrêtée sans ressources")
	sim.supplies = 0.1
	sim._step_entity(engineer, 1)
	check(is_equal_approx(hq.hp, hq.max_hp - 14.5) and sim.supplies == 0, "réparation proportionnelle au stock")
	scientist.pos = Sim.RUINS
	scientist.path.clear()
	sim._step_entity(scientist, 0.1)
	check(sim.ruins_found and sim.ruins_study > 0, "scientifique reconnaît et étudie les ruines")
	var second: Dictionary = sim._add("scientist", "sgc", Sim.RUINS + Vector2(1, 0))
	sim._step_entity(second, 1)
	check(is_equal_approx(sim.ruins_study, 0.1), "plusieurs chercheurs ne multiplient pas la vitesse")
	var nq: float = sim.naquadah
	var resources: float = sim.supplies
	for i in 120:
		sim._step_entity(scientist, 0.1)
	check(sim.ruins_studied and sim.naquadah == nq + 50 and sim.supplies == resources + 100, "étude récompensée")
	sim._step_entity(scientist, 15)
	check(sim.naquadah == nq + 50, "récompense unique")
	sim.assign_squad(1, [soldier.id, medic.id, scientist.id, medic.id, hq.id, 999])
	check(sim.squad_members(1) == [soldier.id, medic.id, scientist.id], "escouade mixte sans bâtiment ni doublons")
	var copy: Array = sim.squad_members(1)
	copy.clear()
	check(sim.squad_members(1).size() == 3, "rappel indépendant de la sélection")
	medic.hp = 0
	check(sim.squad_members(1) == [soldier.id, scientist.id], "pertes retirées de l'escouade")
	sim.assign_squad(1, [])
	check(sim.squad_members(1).size() == 2, "sélection vide ne détruit pas l'escouade")
	sim.assign_squad(9, [soldier.id])
	check(sim.squad_members(9).is_empty(), "emplacement invalide ignoré")
	var view := Outpost.new()
	view.persistence_enabled = false
	view.sim = Sim.new({"established": true})
	add_child(view)
	await get_tree().process_frame
	view.set_process(false)
	var units: Array = []
	for kind in ["medic", "scientist", "engineer"]:
		var unit: Dictionary = view.sim._add(kind, "sgc", Vector2(7 + units.size(), 21))
		units.append(unit.id)
	view._sync_visuals()
	view.selected = units.duplicate()
	view._update_ui()
	check(view.unit_panel.visible and view.unit_details.text.contains("Médecin"), "fiche des spécialistes")
	check(view.visuals[units[0]].name == "MÉDECIN", "visuel distinct nommé")
	view._select_team()
	check(view.selected.size() == 7, "sélection tactile de toute l'équipe mixte")
	var isolated: Dictionary = view.sim.entity(units[1])
	isolated.pos = Vector2(14, 20)
	view.multi_select = true
	var point: Vector2 = view.cam.unproject_position(view._world(isolated.pos, 1))
	view._tap(point)
	check(not view.selected.has(isolated.id) and view.selected.size() == 6, "toucher multiple retire un membre")
	view._tap(point)
	check(view.selected.has(isolated.id) and view.selected.size() == 7, "toucher multiple ajoute un membre")
	view.multi_select = false
	var key := InputEventKey.new()
	key.keycode = KEY_3
	key.pressed = true
	key.shift_pressed = true
	view._unhandled_input(key)
	check(view.sim.squad_members(3).size() == 7, "Maj+3 mémorise l'équipe")
	view.selected.clear()
	key.shift_pressed = false
	view._unhandled_input(key)
	check(view.selected.size() == 7, "3 rappelle l'équipe")
	view.sim.assign_squad(2, units)
	view.selected.clear()
	view._recall_squad(2)
	check(view.selected == units, "rappel tactile de l'escouade")
	view.sim.order(units, Vector2(12, 18))
	view._halt_units()
	check(units.all(func(id): return view.sim.entity(id).path.is_empty()), "halte pour activer le travail sur place")
	view._toggle_pause()
	var supplies: float = view.sim.supplies
	view._recruit("engineer")
	check(view.sim.supplies == supplies and not view.sim.gate_busy(), "pas de recrutement en pause")
	print("Spécialistes et escouades : %d/%d vérifications réussies" % [checks - fails, checks])
	get_tree().quit(1 if fails else 0)
