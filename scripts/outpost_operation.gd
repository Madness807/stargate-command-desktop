extends RefCounted
## Mission originale du SGC, située après « Learning Curve ».
## État sérialisable ; toutes les décisions passent par la simulation RTS.
const RESCUE := Vector2(4, 1)
const RELAYS := [Vector2(18, 5), Vector2(28, 16)]
const RELAY_TIME := 45.0
const STUDY_TIME := 60.0
const TRANSFER_TIME := 90.0
const RELAY_COST := 40
const STAGES := ["archives", "relays", "assault", "transfer", "return", "ready", "evacuation", "complete"]

static func fresh() -> Dictionary:
	return {"id": "last_watch", "stage": "archives", "study": 0.0,
		"relays": [0.0, 0.0], "charged": [false, false], "transfer": 0.0,
		"base_time": 0.0, "backup": 0.0, "warning": "", "raid_target": -1,
		"raid_point": Vector2.ZERO, "raid_number": 0, "final_raids": 0,
		"evacuated": 0, "scientists_out": 0, "soldiers_out": 0, "initial_evac": 0,
		"blocked": "", "history": [], "outbound_clock": 0.0,
		"rescue_released": false, "rescue_returned": false, "rescue_lost": false, "rescued_out": 0}

static func valid(state: Dictionary) -> bool:
	if not state.has_all(fresh().keys()) or state.id != "last_watch" or state.stage not in STAGES:
		return false
	return state.relays is Array and state.relays.size() == 2 and state.charged is Array and state.charged.size() == 2 and state.raid_point is Vector2 and state.history is Array

static func mark(s, text: String) -> void:
	s.operation.history.append({"time": s.elapsed, "text": text})
	s.notice.emit(text)

static func transition(s, stage: String, text: String) -> void:
	s.operation.stage = stage
	s.operation.blocked = ""
	mark(s, text)

static func near(s, kind: String, point: Vector2, radius: float = 2.5) -> bool:
	for e in s.entities:
		if e.hp > 0 and e.side == "sgc" and e.kind == kind and e.path.is_empty() and e.pos.distance_to(point) <= radius:
			return true
	return false

static func contested(s, point: Vector2) -> bool:
	for e in s.entities:
		if e.hp > 0 and e.side == "enemy" and e.pos.distance_to(point) < 5:
			return true
	return false

static func work_error(s, kind: String, point: Vector2) -> String:
	if not near(s, kind, point):
		return "Scientifique à l'arrêt requis sur le site." if kind == "scientist" else "Ingénieur à l'arrêt requis sur le relais."
	if contested(s, point):
		return "Site contesté : repoussez les Jaffas à plus de 5 cases."
	if not s.powered() or (s.count("generator") == 0 and s.operation.backup <= 0):
		return "Alimentation de la base interrompue."
	return ""

static func action_error(s, action: String) -> String:
	var o: Dictionary = s.operation
	if s.result != "" or s.phase != "base":
		return "Attendez la mise en service du commandement."
	if action == "backup":
		if o.stage in ["evacuation", "complete"]:
			return "Rapatriement en cours."
		if o.backup > 0:
			return "Alimentation de secours déjà active."
		return "25 naquadah conditionnés requis." if s.naquadah < 25 else ""
	if action.begins_with("relay_"):
		var index := 0 if action == "relay_0" else 1
		if o.stage != "relays":
			return "Déchiffrez d'abord les archives."
		if o.charged[index]:
			return "Relais déjà équipé : laissez l'ingénieur travailler."
		if s.naquadah < RELAY_COST:
			return "40 naquadah conditionnés requis pour le générateur de terrain."
		return work_error(s, "engineer", RELAYS[index])
	if action == "evacuate":
		if o.stage != "ready":
			return "Rapportez d'abord les données au commandement."
		if s.gate_busy():
			return "Attendez la fin de la liaison entrante du SGC."
		if not near(s, "scientist", s.GATE, 4):
			return "Amenez un scientifique à l'arrêt près de la porte avant la composition sortante."
		return ""
	return "Action inconnue."

static func act(s, action: String) -> bool:
	var error := action_error(s, action)
	if error != "":
		s.notice.emit(error)
		return false
	var o: Dictionary = s.operation
	if action == "backup":
		s.naquadah -= 25
		o.backup = 45.0
		mark(s, "Carter : alimentation de secours engagée. +8 énergie pendant 45 secondes.")
	elif action.begins_with("relay_"):
		var index := 0 if action == "relay_0" else 1
		s.naquadah -= RELAY_COST
		o.charged[index] = true
		mark(s, "Générateur de terrain déployé sur le relais %s. Protégez l'ingénieur pendant 45 secondes." % ("nord" if index == 0 else "est"))
	elif action == "evacuate":
		o.initial_evac = mobile_count(s)
		transition(s, "evacuation", "SGC : composition vers la Terre engagée. Tous les survivants rejoignent la porte. Aucun renfort entrant pendant le rapatriement.")
		for e in s.entities:
			if e.hp > 0 and e.side == "sgc" and not s.is_building(e):
				e.target = -1
				s._route(e, s.GATE)
	return true

static func mobile_count(s) -> int:
	var total := 0
	for e in s.entities:
		if e.hp > 0 and e.side == "sgc" and not s.is_building(e):
			total += 1
	return total

static func target_for(s, kind: String) -> Dictionary:
	for e in s.entities:
		if e.hp > 0 and e.side == "sgc" and e.kind == kind:
			return e
	return {}

static func prepare_raid(s) -> void:
	var o: Dictionary = s.operation
	var intents := ["generator", "mine", "hq", "scientist"]
	var kind: String = intents[o.raid_number % intents.size()]
	var target := target_for(s, kind)
	if target.is_empty():
		target = target_for(s, "hq")
	o.raid_target = target.get("id", -1)
	o.raid_point = Vector2(30, 2) if o.raid_number % 2 == 0 else Vector2(30, 22)
	var names := {"generator": "le générateur", "mine": "l'extracteur", "hq": "le commandement", "scientist": "l'équipe scientifique"}
	var label: String = names.get(target.get("kind", "hq"), "l'avant-poste")
	o.warning = "AXE %s → %s" % ["NORD" if o.raid_number % 2 == 0 else "EST", label]
	mark(s, "Renseignement : %s. Entrée dans le secteur dans %d secondes. Interceptez la colonne ou défendez sa cible." % [o.warning, ceili(s.raid_in)])

static func raid_tick(s, delta: float) -> void:
	var o: Dictionary = s.operation
	# Après la chute du camp, deux colonnes de la réserve régionale couvrent le repli.
	if s.count("camp") == 0 and o.final_raids >= 2:
		o.warning = ""
		return
	s.raid_in -= delta
	if s.raid_in <= (50 if o.rescue_returned else 30) and o.warning == "":
		prepare_raid(s)
	if s.raid_in > 0:
		return
	if o.warning == "":
		prepare_raid(s)
	var target: Dictionary = s.entity(o.raid_target)
	var destination: Vector2 = target.get("pos", s.HQ_SITE)
	var number: int = mini(3 + s.wave / 2, 6)
	if o.relays[0] >= RELAY_TIME:
		number = maxi(2, number - 1)
	for i in number:
		var point: Vector2 = Vector2(30 + i % 2, o.raid_point.y - i / 2 if o.raid_point.y > 12 else o.raid_point.y + i / 2)
		var raider: Dictionary = s._add("jaffa", "enemy", point)
		raider.target = target.get("id", -1)
		s._route(raider, destination)
	s.wave += 1
	o.raid_number += 1
	if s.count("camp") == 0:
		o.final_raids += 1
	mark(s, "Colonne ennemie engagée : %s · %d Jaffas." % [o.warning, number])
	o.warning = ""
	s.raid_in = {"easy": 140.0, "normal": 115.0, "hard": 95.0}[s.difficulty]

static func tick(s, delta: float) -> void:
	var o: Dictionary = s.operation
	o.backup = maxf(0, o.backup - delta)
	if s.phase != "base" or s.result != "":
		return
	if o.base_time == 0:
		mark(s, "Hammond : opération Dernière Veille engagée. Établissez un laboratoire, exploitez le gisement et escortez un scientifique vers les ruines à l'est. Une balise SG-11 émet au nord-ouest : sauvetage facultatif, renseignements radio à récupérer.")
	o.base_time += delta
	rescue_tick(s)
	o.blocked = ""
	match o.stage:
		"archives":
			o.blocked = work_error(s, "scientist", s.RUINS)
			if s.count("lab") == 0:
				o.blocked = "Laboratoire opérationnel requis pour analyser les relevés."
			if o.blocked == "":
				o.study = minf(STUDY_TIME, o.study + delta)
				s.ruins_study = o.study
			if o.study >= STUDY_TIME:
				s.ruins_studied = true
				transition(s, "relays", "Jackson : les archives décrivent deux relais récupérés par les Goa'ulds. Coupez-les avec nos générateurs de terrain. Nord : réduit les renforts ; est : retarde les colonnes et affaiblit l'armement du camp.")
		"relays":
			for i in 2:
				if not o.charged[i] or o.relays[i] >= RELAY_TIME:
					continue
				var error := work_error(s, "engineer", RELAYS[i])
				if error == "":
					o.relays[i] = minf(RELAY_TIME, o.relays[i] + delta * (1.25 if s.researched else 1.0))
					if o.relays[i] >= RELAY_TIME:
						if i == 1:
							s.raid_in += 45.0
						mark(s, "Relais %s neutralisé. %s" % ["nord" if i == 0 else "est", "Les colonnes perdent un renfort." if i == 0 else "Prochaine colonne retardée de 45 s ; armement du camp affaibli de 40 %."])
				else:
					o.blocked = error
			if o.relays[0] >= RELAY_TIME and o.relays[1] >= RELAY_TIME:
				transition(s, "assault", "Carter : bouclier du camp coupé. Lancez l'assaut ; gardez une défense et un scientifique en vie pour récupérer les archives.")
		"assault":
			if s.count("camp") == 0:
				s.raid_in = 45.0
				o.warning = ""
				transition(s, "transfer", "Camp neutralisé. Les réserves du secteur convergent : deux dernières colonnes. Ramenez un scientifique aux ruines et protégez la transmission pendant 90 secondes.")
		"transfer":
			o.blocked = work_error(s, "scientist", s.RUINS)
			if s.count("lab") == 0:
				o.blocked = "Reconstruisez le laboratoire pour reprendre la transmission."
			if o.blocked == "":
				o.transfer = minf(TRANSFER_TIME, o.transfer + delta)
			if o.transfer >= TRANSFER_TIME:
				transition(s, "return", "Archives copiées sur les terminaux de terrain. Escortez un scientifique jusqu'au commandement pour valider les données et préparer le retour.")
		"return":
			if near(s, "scientist", s.HQ_SITE, 3):
				transition(s, "ready", "Données validées. Rassemblez le personnel près de la porte puis ouvrez une liaison sortante vers le SGC. Les installations resteront sur place.")
		"evacuation":
			o.outbound_clock += delta
			if o.outbound_clock < 4.0:
				return
			for e in s.entities:
				if e.hp <= 0 or e.side != "sgc" or s.is_building(e):
					continue
				if e.pos.distance_to(s.GATE) <= 1.5:
					o.evacuated += 1
					if e.get("rescued", false):
						o.rescued_out += 1
					if e.kind == "scientist":
						o.scientists_out += 1
					elif e.kind == "soldier":
						o.soldiers_out += 1
					e.hp = 0 # Retiré par transport, aucun événement de destruction.
				elif e.path.is_empty():
					e.target = -1
					s._route(e, s.GATE)
			if s.count("scientist") == 0 and o.scientists_out == 0:
				s.result = "defeat"
				mark(s, "RAPATRIEMENT PERDU · Aucun scientifique n'a pu franchir la porte.")
			elif mobile_count(s) == 0:
				if o.soldiers_out == 0:
					s.result = "defeat"
					mark(s, "RAPATRIEMENT PERDU · Aucun militaire n'a pu rentrer au SGC.")
				else:
					o.stage = "complete"
					s.result = "victory"
					mark(s, "DERNIÈRE VEILLE ACCOMPLIE · Archives récupérées, bouclier neutralisé et %d personnes rapatriées au SGC." % o.evacuated)

static func objective(s) -> String:
	var o: Dictionary = s.operation
	var titles := {"archives": "3/7 · LES ARCHIVES", "relays": "4/7 · DEUX RELAIS", "assault": "5/7 · LE CAMP GOA'ULD", "transfer": "6/7 · TRANSMISSION", "return": "7/7 · RETOUR AU SGC", "ready": "7/7 · RETOUR AU SGC", "evacuation": "7/7 · RAPATRIEMENT", "complete": "OPÉRATION ACCOMPLIE"}
	var body := ""
	match o.stage:
		"archives": body = "Laboratoire + scientifique aux ruines.\nAnalyse : %d/%d s\nInstallez un extracteur et préparez une escorte." % [o.study, STUDY_TIME]
		"relays": body = "Ingénieurs à l'arrêt sur chaque relais ; 40 N par générateur de terrain.\nNord : %d/%d s · Est : %d/%d s\nNord : moins de renforts. Est : répit de 45 s et camp affaibli." % [o.relays[0], RELAY_TIME, o.relays[1], RELAY_TIME]
		"assault": body = "Bouclier coupé : détruisez le camp au nord-est. Gardez votre scientifique et une défense de base."
		"transfer": body = "Scientifique aux ruines, laboratoire alimenté.\nCopie : %d/%d s\nSécurisez le site et les accès." % [o.transfer, TRANSFER_TIME]
		"return": body = "Escortez un scientifique au commandement. Les relevés sont partagés entre les terminaux : un remplaçant peut reprendre."
		"ready": body = "Rassemblez les survivants près de la porte. Un scientifique doit être présent. La liaison sortante bloque tous les renforts entrants."
		"evacuation": body = "%d rapatriés · %d encore sur place.\nCouvrez leur approche de la porte." % [o.evacuated, mobile_count(s)]
		"complete": body = "%d personnes rapatriées. Archives remises au SGC." % o.evacuated
	if o.blocked != "" and o.stage in ["archives", "relays", "transfer"]:
		body += "\n" + o.blocked
	return titles[o.stage] + "\n" + body

static func focus_point(s) -> Vector2:
	match s.operation.stage:
		"archives", "transfer": return s.RUINS
		"relays": return RELAYS[0] if s.operation.relays[0] < RELAY_TIME else RELAYS[1]
		"assault": return Vector2(27, 5)
		"return": return s.HQ_SITE
	return s.GATE


static func rescue_tick(s) -> void:
	var o: Dictionary = s.operation
	if not o.rescue_released:
		if near(s, "soldier", RESCUE, 3) and not contested(s, RESCUE):
			o.rescue_released = true
			for i in 2:
				var survivor: Dictionary = s._add("scientist" if i == 0 else "engineer", "sgc", RESCUE + Vector2(i, 1))
				survivor["rescued"] = true
				survivor["role_name"] = "SG-11 · SCIENTIFIQUE" if i == 0 else "SG-11 · INGÉNIEUR"
			mark(s, "SG-11 retrouvée : deux survivants rejoignent votre commandement. Escortez-les au QG ; leurs relevés radio permettront d'anticiper les colonnes 50 secondes à l'avance.")
	elif not o.rescue_returned and not o.rescue_lost:
		var alive := false
		for e in s.entities:
			if e.hp <= 0 or not e.get("rescued", false):
				continue
			alive = true
			if e.pos.distance_to(s.HQ_SITE) <= 3:
				o.rescue_returned = true
				mark(s, "SG-11 au commandement. Fréquences ennemies identifiées : alerte raid portée de 30 à 50 secondes. Protégez les survivants jusqu'au retour sur Terre.")
				break
		if not alive:
			o.rescue_lost = true
			mark(s, "SG-11 perdue avant le retour au commandement. L'opération principale reste réalisable.")

static func rescue_text(s) -> String:
	var o: Dictionary = s.operation
	if o.rescue_lost:
		return "SG-11 : sauvetage perdu."
	if o.rescue_returned:
		return "SG-11 secourue · alerte raid 50 s."
	if o.rescue_released:
		return "Facultatif : escortez les survivants SG-11 au QG."
	return "Facultatif : balise SG-11 au nord-ouest. Secourez l'équipe pour mieux anticiper les raids."
