extends Node
const Sim = preload("res://scripts/outpost_sim.gd")
const Op = preload("res://scripts/outpost_operation.gd")
const Store = preload("res://scripts/session_save.gd")
const View = preload("res://scripts/outpost.gd")
var checks := 0
var fails := 0

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		printerr("ÉCHEC OPÉRATION : ", text)

func step(s, seconds: float) -> void:
	for i in roundi(seconds * 10):
		s.tick(0.1)

func peaceful():
	var s := Sim.new({"established": true, "operation": true})
	for e in s.entities:
		if e.side == "enemy" and e.kind != "camp":
			e.hp = 0
	s._add("generator", "sgc", Vector2(5, 15))
	s._add("lab", "sgc", Vector2(9, 15))
	s.raid_in = 9999
	return s

func _ready() -> void:
	check(not Sim.new(Expedition.options()).operation.is_empty(), "nouvelle expédition démarre la mission longue")
	var s = peaceful()
	check(s.operation.stage == "archives", "aucune phase sautée")
	var camp: Dictionary = Op.target_for(s, "camp") # Camp ennemi : recherche explicite ci-dessous.
	for e in s.entities:
		if e.kind == "camp": camp = e
	var attacker: Dictionary = s._add("soldier", "sgc", Vector2(27, 8))
	s.update_visibility()
	var hp: float = camp.hp
	s._step_entity(attacker, 0.1)
	check(camp.hp == hp, "bouclier bloque réellement les tirs avant les relais")
	attacker.hp = 0
	var scientist: Dictionary = s._add("scientist", "sgc", Sim.RUINS)
	step(s, 10)
	check(s.operation.study > 9 and s.operation.study < 11, "analyse progresse avec scientifique et laboratoire alimenté")
	var threat: Dictionary = s._add("jaffa", "enemy", Sim.RUINS + Vector2(4.5, 0))
	var progress: float = s.operation.study
	step(s, 2)
	check(s.operation.study == progress, "présence hostile suspend l'étude sans effacer les données")
	threat.hp = 0
	var generator: Dictionary = Op.target_for(s, "generator")
	generator.hp = 0
	step(s, 1)
	check(s.operation.study == progress, "panne suspend l'analyse")
	s.naquadah = 25
	check(s.operation_action("backup"), "secours payé avec le stock réel")
	check(s.naquadah == 0 and s.powered(), "secours fournit réellement de l'énergie")
	check(not s.operation_action("backup"), "secours non cumulable")
	s._add("generator", "sgc", Vector2(5, 15))
	step(s, 51)
	check(s.operation.stage == "relays" and s.ruins_studied, "étude complète révèle la seconde phase")
	check(s.naquadah == 0, "aucune ressource créée par les ruines")
	var engineer: Dictionary = s._add("engineer", "sgc", Op.RELAYS[0])
	s.naquadah = 39
	check(not s.operation_action("relay_0"), "générateur de terrain exige le coût complet")
	s.naquadah = 160
	check(s.operation_action("relay_0") and s.naquadah == 120, "relais nord payé une fois")
	check(not s.operation_action("relay_0") and s.naquadah == 120, "double activation ne dépense rien")
	step(s, 20)
	var partial: float = s.operation.relays[0]
	engineer.pos = Sim.HQ_SITE
	step(s, 1)
	check(s.operation.relays[0] == partial, "ingénieur parti : intervention suspendue")
	var restored = Sim.from_snapshot(s.snapshot())
	check(restored != null and restored.operation == s.operation, "toutes les données de mission survivent à la sauvegarde")
	var path := "user://test_last_watch_roundtrip.tmp"
	check(Store.write(path, {"mission": Store.pack(s.snapshot())}), "checkpoint de mission écrit sur disque isolé")
	var disk = Sim.from_snapshot(Store.unpack(Store.read(path).mission))
	check(disk != null and disk.operation == s.operation and disk.entities == s.entities, "état complet relu depuis le disque")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check(not restored.operation_action("relay_0") and restored.naquadah == s.naquadah, "reprise sans double paiement")
	engineer.pos = Op.RELAYS[0]
	step(s, 26)
	check(s.operation.relays[0] == Op.RELAY_TIME, "premier relais neutralisé")
	engineer.pos = Op.RELAYS[1]
	check(s.operation_action("relay_1"), "deuxième relais accepte un ingénieur")
	check(s.research() and s.naquadah == 0, "80 N concurrencent les générateurs de terrain")
	check(s.power().y == 12, "recherche améliore l'énergie plutôt que les dégâts")
	step(s, 37)
	check(s.operation.stage == "assault", "deux relais ouvrent le camp")
	attacker = s._add("soldier", "sgc", Vector2(27, 8))
	hp = camp.hp
	s.update_visibility()
	s._step_entity(attacker, 0.1)
	check(camp.hp == hp - 10, "camp vulnérable après sabotage ; recherche sans bonus de dégâts")
	attacker.hp = 0
	camp.hp = 0
	s.grid.set_point_solid(Vector2i(camp.pos), false)
	step(s, 0.2)
	check(s.operation.stage == "transfer" and s.result == "", "détruire le camp ne donne pas la victoire")
	# Pas de forçage de résultat dans le test de parcours séparé ; ici on isole chaque règle.
	s.raid_in = 31
	step(s, 1.1)
	check(s.operation.warning != "" and s.operation.raid_target >= 0, "intention annoncée avant apparition d'une colonne")
	var raid_state = Sim.from_snapshot(s.snapshot())
	check(raid_state.operation.warning == s.operation.warning and is_equal_approx(raid_state.raid_in, s.raid_in), "axe, cible et compte à rebours conservés à la reprise")
	# Avance du travail sans menace, pour contrôler les seuils exacts.
	for i in 900:
		Op.tick(s, 0.1)
	check(s.operation.stage == "return" and s.result == "", "90 secondes de copie ne terminent pas la mission")
	scientist.pos = Sim.HQ_SITE + Vector2(1, 0)
	Op.tick(s, 0.1)
	check(s.operation.stage == "ready", "données remises au commandement")
	check(not s.operation_action("evacuate"), "scientifique doit rejoindre la porte avant départ")
	scientist.pos = Sim.GATE + Vector2(0, 1)
	s.gate_hold = 0
	s.gate_in = 0
	s._transit_queue.clear()
	check(s.operation_action("evacuate"), "liaison sortante engagée explicitement")
	check(s.gate_busy() and not s.recruit("scientist") and not s.reinforce(), "pas de transport entrant dans une connexion sortante")
	check(not s.gate_open(), "composition avant ouverture sortante")
	Op.tick(s, 2.1)
	check(s.gate_open() and s.operation.evacuated == 0, "ouverture avant franchissement")
	for e in s.entities:
		if e.side == "sgc" and not s.is_building(e):
			e.pos = Sim.GATE + Vector2(0, 0.8)
	Op.tick(s, 2.0)
	check(s.result == "victory" and s.operation.scientists_out == 1 and s.operation.soldiers_out > 0, "victoire seulement après rapatriement du personnel")
	var economy = peaceful()
	economy._add("mine", "sgc", Sim.DEPOSIT)
	step(economy, 1.1)
	check(economy.naquadah == 1 and economy.extracted_naquadah == 1, "conditionnement à 1 N/s : production réelle et cumul synchronisés")
	var capped = peaceful()
	for i in 7: capped._add("soldier", "sgc", Vector2(4 + i, 21))
	var funds: float = capped.supplies
	check(not capped.reinforce() and capped.supplies == funds, "capacité de 12 militaires : aucun convoi au-delà de la limite")
	var east = peaceful()
	east.operation.stage = "relays"
	east.operation.charged[1] = true
	east.operation.relays[1] = 44.9
	east._add("engineer", "sgc", Op.RELAYS[1])
	var before_raid: float = east.raid_in
	Op.tick(east, 0.2)
	check(east.operation.relays[0] == 0 and east.raid_in == before_raid + 45, "relais est en premier : répit immédiat, sans forcer le nord")
	Op.tick(east, 1)
	check(east.raid_in == before_raid + 45, "bonus de répit accordé une seule fois")
	var reserve = peaceful()
	for e in reserve.entities:
		if e.kind == "camp": e.hp = 0
	for i in 3:
		reserve.raid_in = 0
		Op.raid_tick(reserve, 0.1)
	check(reserve.operation.final_raids == 2 and reserve.wave == 2, "réserves finales limitées à deux colonnes")
	check(reserve.entities.filter(func(e): return e.side == "enemy" and e.hp > 0).all(func(e): return not reserve.terrain_blocked(e.pos)), "colonnes apparaissent sur des cases praticables")
	var rescue = peaceful()
	var escort: Dictionary = rescue._add("soldier", "sgc", Op.RESCUE)
	Op.rescue_tick(rescue)
	check(rescue.operation.rescue_released and rescue.count("scientist") == 1 and rescue.count("engineer") == 1, "refuge sécurisé : deux survivants rejoignent l'équipe")
	Op.rescue_tick(rescue)
	check(rescue.count("scientist") == 1, "aucun survivant dupliqué")
	var survivor: Dictionary = Op.target_for(rescue, "scientist")
	survivor.pos = Sim.HQ_SITE + Vector2(0, 1)
	Op.rescue_tick(rescue)
	check(rescue.operation.rescue_returned, "renseignements acquis seulement après retour au QG")
	rescue.raid_in = 49
	Op.raid_tick(rescue, 0.1)
	check(rescue.operation.warning != "", "SG-11 donne une alerte anticipée réelle")
	var lost = peaceful()
	lost.operation.stage = "evacuation"
	lost.operation.outbound_clock = 5
	Op.tick(lost, 0.1)
	check(lost.result == "defeat", "scientifique perdu au départ : échec explicite")
	var legacy := Sim.new({"established": true}).snapshot()
	legacy.erase("operation")
	check(Sim.from_snapshot(legacy) != null and Sim.from_snapshot(legacy).operation.is_empty(), "anciennes expéditions conservées sans migration forcée")
	var broken := s.snapshot()
	broken.operation.stage = "invalid"
	check(Sim.from_snapshot(broken) == null, "checkpoint de mission invalide refusé")
	await view_checks()
	print("Dernière Veille : %d/%d vérifications réussies" % [checks - fails, checks])
	get_tree().quit(1 if fails else 0)

func view_checks() -> void:
	var view := View.new()
	view.persistence_enabled = false
	view.sim = peaceful()
	add_child(view)
	view.set_process(false)
	for dimensions in [Vector2i(1600, 900), Vector2i(853, 480)]:
		get_tree().root.content_scale_size = dimensions
		get_tree().root.size = dimensions
		for stage in Op.STAGES:
			view.sim.operation.stage = stage
			view._update_ui()
			for i in 3:
				await get_tree().process_frame
			check(layout_issues(view.ui).is_empty(), "commandes dans leurs panneaux " + stage + " " + str(dimensions))
			check(view.objective.text != "" and not view.objective.text.contains("1 / 4"), "objectif affiché " + stage + " " + str(dimensions))
			check(view.operation_buttons.evacuate.visible == (stage == "ready"), "action de départ contextuelle " + stage)
	view.sim.operation.stage = "relays"
	view.sim.update_visibility()
	view._sync_visuals()
	view._update_ui()
	check(view.relay_markers.size() == 2 and view.operation_buttons.relay_0.visible, "relais et commandes reliés à la mission")
	view.queue_free()
	await get_tree().process_frame


func layout_issues(root: Node) -> Array[String]:
	var issues: Array[String] = []
	if root is Control and not root.is_visible_in_tree():
		return issues
	if root is Button or root is Label:
		var rect: Rect2 = root.get_global_rect()
		var ancestor := root.get_parent()
		var scroll: ScrollContainer
		while ancestor != null:
			if ancestor is ScrollContainer:
				scroll = ancestor
				break
			ancestor = ancestor.get_parent()
		if scroll == null:
			if not get_viewport().get_visible_rect().grow(1).encloses(rect):
				issues.append(root.text.left(30))
		elif rect.position.x < scroll.global_position.x - 1 or rect.end.x > scroll.get_global_rect().end.x + 1:
			issues.append(root.text.left(30))
	for child in root.get_children():
		issues.append_array(layout_issues(child))
	return issues
