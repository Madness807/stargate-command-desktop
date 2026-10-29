extends Node

const Outpost = preload("res://scripts/outpost.gd")
const Sim = preload("res://scripts/outpost_sim.gd")
var checks := 0
var fails := 0


func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		printerr("ÉCHEC INTERFACE BÂTIMENT : ", text)


func _ready() -> void:
	var view := Outpost.new()
	view.persistence_enabled = false
	view.sim = Sim.new({"established": true})
	add_child(view)
	await get_tree().process_frame
	view.set_process(false)
	var sim = view.sim
	check(not view.building_panel.visible and view.construction_panel.visible, "construction sans bâtiment sélectionné")
	var hq: Dictionary
	for e in sim.entities:
		if e.kind == "hq":
			hq = e
	view._tap(view.cam.unproject_position(view._world(hq.pos, 3)))
	check(view.selected == [hq.id] and view.building_panel.visible, "toucher le toit ouvre les options")
	check(not view.construction_panel.visible and view.building_action.text.contains("85 R"), "options du commandement")
	view._building_action()
	check(sim.gate_job == "reinforcements" and view.building_action.disabled, "commande de renforts et blocage du double achat")
	var index := 0
	for kind in ["generator", "turret", "infirmary", "lab", "mine"]:
		var e: Dictionary = sim._add(kind, "sgc", Vector2(12 + index * 3, 20))
		view.selected = [e.id]
		view._update_ui()
		check(view.building_title.text == Sim.BUILDINGS[kind].name.to_upper(), "fiche " + kind)
		check(view.repair_button.disabled, "bâtiment intact : " + kind)
		e.hp -= 50
		sim.supplies = 100
		view._update_ui()
		check(not view.repair_button.disabled and sim.repair_cost(e.id) == 10, "coût réparation : " + kind)
		view._repair_building()
		check(e.hp == e.max_hp and sim.supplies == 90, "réparation réelle : " + kind)
		if kind == "infirmary":
			var soldier := sim.entity(4)
			for unit in sim.entities:
				if unit.kind == "soldier":
					soldier = unit
					break
			soldier.hp -= 20
			view._update_ui()
			check(not view.building_action.disabled, "rappel des blessés disponible")
			view._building_action()
			check(not soldier.path.is_empty(), "ordre de retour aux soins")
		if kind == "lab":
			sim.naquadah = 30
			view._update_ui()
			view._building_action()
			check(sim.researched and sim.naquadah == 0 and view.building_action.disabled, "recherche depuis le laboratoire")
		index += 1
	var site: Dictionary = sim._add("lab", "sgc", Vector2(10, 14), 5)
	view.selected = [site.id]
	view._update_ui()
	check(view.building_details.text.contains("CONSTRUCTION") and view.building_action.disabled and view.repair_button.disabled, "chantier : actions bloquées")
	check(not sim.repair(site.id), "simulation refuse la réparation du chantier")
	view.selected = [hq.id]
	hq.hp -= 100
	sim.supplies = 0
	view._update_ui()
	check(view.repair_button.disabled and not sim.repair(hq.id), "réparation impossible sans ressources")
	sim.supplies = 100
	view._toggle_pause()
	view._repair_building()
	check(hq.hp < hq.max_hp and view.repair_button.disabled, "pause protège les actions")
	view._toggle_pause()
	hq.hp = 0
	view._update_ui()
	check(not view.building_panel.visible and view.construction_panel.visible, "destruction ferme la fiche")
	print("Interface bâtiments : %d/%d vérifications réussies" % [checks - fails, checks])
	get_tree().quit(1 if fails else 0)
