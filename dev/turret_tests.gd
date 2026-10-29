extends Node
const Sim = preload("res://scripts/outpost_sim.gd")
const View = preload("res://scripts/outpost.gd")
const Cli = preload("res://scripts/cli.gd")
var checks := 0
var fails := 0

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		printerr("ÉCHEC TOURELLE : ", text)

func _ready() -> void:
	if Cli.has("--inspect"):
		var session := Expedition.load_session()
		if session.is_empty():
			print("Pas de sauvegarde RTS lisible.")
		else:
			var saved = Sim.from_snapshot(session.simulation)
			if saved != null:
				print("INSPECTION énergie ", saved.power(), " phase ", saved.phase)
				for e in saved.entities:
					if e.kind == "turret":
						print("TOURELLE ", e.pos, " construction ", e.build, " hp ", e.hp)
						for foe in saved.entities:
							if foe.side == "enemy" and saved.entity_visible(foe):
								print("  ennemi visible ", foe.kind, " distance ", e.pos.distance_to(foe.pos), " ligne libre ", saved.line_of_fire(e.pos, foe.pos))
		get_tree().quit()
		return
	var sim := Sim.new({"established": true, "operation": true})
	for e in sim.entities:
		e.hp = 0
		if sim.is_building(e): sim.grid.set_point_solid(Vector2i(e.pos), false)
	var turret: Dictionary = sim._add("turret", "sgc", Vector2(12, 16))
	var enemy: Dictionary = sim._add("jaffa", "enemy", Vector2(16, 16))
	sim.update_visibility()
	var before: float = enemy.hp
	sim._step_entity(turret, 0.1)
	check(enemy.hp == before, "aucun tir sans énergie")
	check(sim.turret_status(turret).state == "power", "panne explicitement signalée")
	var generator: Dictionary = sim._add("generator", "sgc", Vector2(4, 15))
	sim.update_visibility()
	sim._step_entity(turret, 0.1)
	check(enemy.hp == before - 14, "tir automatique inflige des dégâts sans ordre manuel")
	check(sim.turret_status(turret).state == "target", "cible acquise affichée pendant la recharge")
	before = enemy.hp
	sim._step_entity(turret, 0.5)
	check(enemy.hp == before, "cadence respectée")
	sim._step_entity(turret, 0.9)
	check(enemy.hp == before - 14, "nouveau tir après recharge")
	enemy.pos = Vector2(18, 16)
	sim.update_visibility()
	turret.cooldown = 0
	before = enemy.hp
	sim._step_entity(turret, 0.1)
	check(enemy.hp == before, "pas de tir au-delà de 5,5 cases")
	check(sim.turret_status(turret).state == "range", "ennemi visible mais hors portée distingué")
	enemy.pos = Vector2(16, 16)
	var wall: Dictionary = sim._add("generator", "sgc", Vector2(14, 16))
	sim.update_visibility()
	sim._step_entity(turret, 0.1)
	check(enemy.hp == before, "bâtiment intermédiaire bloque le tir")
	check(sim.turret_status(turret).state == "blocked", "obstacle signalé au lieu de paraître inactif")
	wall.hp = 0
	sim.grid.set_point_solid(Vector2i(wall.pos), false)
	sim._step_entity(turret, 0.1)
	check(enemy.hp == before - 14, "tir reprend quand la ligne est libérée")
	generator.hp = 0
	before = enemy.hp
	sim._step_entity(turret, 2)
	check(enemy.hp == before, "perte d'alimentation arrête le tir")
	var copy = Sim.from_snapshot(sim.snapshot())
	check(copy != null and copy.turret_status(copy.entity(turret.id)).state == "power", "diagnostic fonctionne sur une sauvegarde reprise")
	generator.hp = generator.max_hp
	var view := View.new()
	view.persistence_enabled = false
	view.sim = sim
	add_child(view)
	view.set_process(false)
	view.selected = [turret.id]
	view._show_command_tab("selection")
	view._update_ui()
	check(view.building_details.text.contains("CIBLE ACQUISE"), "état détaillé de la tourelle sélectionnée")
	var visual: Dictionary = view.visuals[turret.id]
	check(visual.muzzle != null, "point de départ au bout des canons")
	view._shot(turret.pos, enemy.pos, false)
	var muzzle: Vector3 = visual.muzzle.global_position
	check(muzzle.distance_to(view._world(turret.pos, 1.52)) > 1.7, "tir déporté du centre vers la bouche des canons")
	var forward: Vector3 = -visual.aim.global_basis.z
	var direction: Vector3 = (view._world(enemy.pos) - view._world(turret.pos)).normalized()
	check(forward.dot(direction) > 0.99, "canons orientés vers la cible")
	var flash_found := false
	for child in view.get_children():
		if child is MeshInstance3D and child.position.is_equal_approx(muzzle):
			flash_found = true
	check(flash_found, "éclair de bouche créé à la sortie du canon")
	check(view.visuals[turret.id].label.text.contains("CIBLE ACQUISE"), "activité lisible sur la tourelle dans le monde")
	view.queue_free()
	await get_tree().process_frame
	print("Tourelles : %d/%d vérifications réussies" % [checks - fails, checks])
	get_tree().quit(1 if fails else 0)
