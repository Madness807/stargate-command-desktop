extends Node3D
## Combat de campagne en temps réel : tirs et déplacements simultanés, ordres en pause tactique.
## Les capacités, recharges et étourdissements avancent uniquement avec advance(), en secondes.

signal finished(result: String) # "win", "lose", "flee"

const People = preload("res://scripts/people.gd")
const Data = preload("res://scripts/data.gd")
const Stats = preload("res://scripts/combat_stats.gd")
const LineOfFire = preload("res://scripts/line_of_fire.gd")

var planet: Node3D
var main: Node
var units: Array = []
var active := -1
var target := -1
var mode := "move"
var tier := 1
var lvl := 1
var boss := false
var poi: Dictionary
var hl: MeshInstance3D
var _hl_mat: StandardMaterial3D
var dmg_bonus := 0
var hit_bonus := 0
var armor := 0
var _done := false

var tactical_paused := false
var group_selected := true
var combat_clock := 0.0
var _panel_clock := 0.0
var effects: Node3D
var _sound_at := {}
var _last_actions := ""
var work_kind := ""
var work_progress := 0.0
var retreat_reason := ""
var feedback: Node3D
var random := RandomNumberGenerator.new()
const WORK_SECONDS := 6.0


func _begin_combat() -> void:
	random.seed = randi()
	effects = Node3D.new()
	add_child(effects)
	for i in units.size():
		var u: Dictionary = units[i]
		# Les figurants sont réutilisés quand une intervention impose un repli.
		if u.alive and u.node.get("_dead") == true:
			u.node.set("_dead", false)
			u.node.set("_busy_anim", false)
			u.node.rotation.x = 0
			if u.node.anim:
				u.node.anim.play(u.node.idle_anim)
		u["index"] = i
		u["rt_path"] = []
		u["attack_target"] = -1
		u["queued"] = {}
		u["fire_in"] = 0.8 if u.side == "sg1" else 1.8
		u["repath_in"] = 0.0
		u["move_goal"] = u.tile
		u["has_move_order"] = false
		u.cd = 0.0
		u.stun = 0.0
		if active < 0 and u.side == "sg1" and u.alive:
			active = i
	feedback = preload("res://scripts/combat_feedback.gd").new()
	add_child(feedback)
	_refresh_highlight()
	refresh_panel()


func _process(delta: float) -> void:
	if delta > 1.0:
		_pause_on_interruption()
		return
	var remaining := delta
	while remaining > 0.000001 and not _done and not tactical_paused:
		var step := minf(remaining, 0.1)
		advance(step)
		remaining -= step


func _pause_on_interruption() -> void:
	if effects != null and not _done and not tactical_paused:
		toggle_tactical_pause()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_pause_on_interruption()


func advance(delta: float) -> void:
	if _done or tactical_paused or planet == null:
		return
	combat_clock += delta
	for u in units:
		if not u.alive:
			continue
		u.cd = maxf(0, u.cd - delta)
		u.fire_in = maxf(0, u.fire_in - delta)
		u.repath_in = maxf(0, u.repath_in - delta)
		if u.stun > 0:
			u.stun = maxf(0, u.stun - delta)
			u.node.walking = false
			continue
		_apply_queued(u)
		if not u.alive:
			continue
		var foe := _target_for(u)
		var desired_range: int = u.range
		if not u.queued.is_empty():
			if u.queued.kind == "bratac":
				desired_range = 1
			elif u.queued.kind == "carter":
				desired_range = 5
		var in_range: bool = not foe.is_empty() and _dist(u.tile, foe.tile) <= desired_range and line_of_fire(u, foe)
		if not foe.is_empty() and not in_range and (u.side == "foe" or u.attack_target >= 0) and u.repath_in <= 0:
			u.repath_in = 0.6
			_route_unit(u, foe.tile)
		if in_range and (u.attack_target >= 0 or u.side == "foe"):
			u.rt_path.clear()
			u.has_move_order = false
		elif u.has_move_order and u.rt_path.is_empty() and u.repath_in <= 0:
			u.repath_in = 0.6
			_route_unit(u, u.move_goal)
		if in_range and u.fire_in <= 0 and u.kind != work_kind:
			_fire(u, foe)
		if u.alive:
			_move_step(u, delta)
	_advance_work(delta)
	if _check_end():
		return
	if active >= 0 and not units[active].alive:
		_select_next()
	_panel_clock += delta
	if _panel_clock >= 0.25:
		_panel_clock = 0
		_refresh_highlight()
		refresh_panel()
	if is_instance_valid(feedback):
		feedback.sync(self, false)


func toggle_tactical_pause() -> void:
	if _done:
		return
	tactical_paused = not tactical_paused
	for u in units:
		u.node.process_mode = Node.PROCESS_MODE_DISABLED if tactical_paused else Node.PROCESS_MODE_INHERIT
	effects.process_mode = Node.PROCESS_MODE_DISABLED if tactical_paused else Node.PROCESS_MODE_INHERIT
	refresh_panel()



func select(i: int) -> void:
	if _done or i < 0 or i >= units.size() or units[i].side != "sg1" or not units[i].alive:
		return
	active = i
	target = units[i].attack_target
	group_selected = false
	mode = "move"
	_refresh_highlight()
	refresh_panel()


func _select_next() -> void:
	for n in units.size():
		var i := (maxi(active, 0) + n + 1) % units.size()
		if units[i].side == "sg1" and units[i].alive:
			select(i)
			return


func select_group() -> void:
	if _done:
		return
	group_selected = true
	mode = "move"
	refresh_panel()


func _selected_units() -> Array:
	var selected_units := []
	for u in units:
		if u.side == "sg1" and u.alive and (group_selected or u.index == active):
			selected_units.append(u)
	return selected_units


func on_tap(tile: Vector2i) -> void:
	if _done or active < 0 or not planet.grid.is_in_boundsv(tile):
		return
	var picked := unit_at(tile)
	# Un nouvel ordre au spécialiste annule son intervention ; sélectionner seul ne l'annule pas.
	if not work_kind.is_empty() and (picked < 0 or units[picked].side == "foe"):
		for selected_unit in _selected_units():
			if selected_unit.kind == work_kind:
				work_kind = ""
				work_progress = 0.0
	if mode == "grenade":
		if _dist(units[active].tile, tile) <= 5 and not planet.blocked.has(tile):
			units[active].queued = {"kind": "grenade", "tile": tile}
			mode = "move"
	elif picked >= 0 and units[picked].side == "sg1":
		select(picked)
		return
	elif picked >= 0 and units[picked].side == "foe":
		target = picked
		for u in _selected_units():
			u.attack_target = picked
			_route_unit(u, tile)
	else:
		var taken := {}
		for u in _selected_units():
			var destination := _free_near(tile, taken)
			taken[destination] = true
			u.attack_target = -1
			_route_unit(u, destination)
	_refresh_highlight()
	refresh_panel()


func _route_unit(u: Dictionary, destination: Vector2i) -> void:
	u.move_goal = destination
	u.has_move_order = destination != u.tile
	var path_to := _path(u.tile, destination)
	if path_to.size() > 0:
		path_to.pop_front()
	if not path_to.is_empty() and unit_at(path_to[-1]) >= 0:
		path_to.pop_back()
	u.rt_path = path_to


func _move_step(u: Dictionary, delta: float) -> void:
	if u.rt_path.is_empty():
		u.node.walking = false
		return
	var tile: Vector2i = u.rt_path[0]
	var occupant := unit_at(tile)
	if planet.blocked.has(tile) or (occupant >= 0 and occupant != u.index):
		u.rt_path.clear()
		u.repath_in = 0.3
		u.node.walking = false
		return
	var point: Vector3 = planet.tile_pos(tile)
	var direction: Vector3 = point - u.node.position
	u.node.rotation.y = atan2(direction.x, direction.z)
	u.node.position = u.node.position.move_toward(point, delta * (4.0 if u.side == "sg1" else 3.0))
	u.node.walking = true
	u.tile = planet.pos_tile(u.node.position)
	if u.node.position.distance_to(point) < 0.02:
		u.rt_path.pop_front()
		if u.tile == u.move_goal:
			u.has_move_order = false
	if u.side == "sg1":
		planet.reveal(u.tile, 3)


func _target_for(u: Dictionary) -> Dictionary:
	if u.attack_target >= 0:
		var preferred: Dictionary = units[u.attack_target]
		if preferred.alive and preferred.side != u.side:
			return preferred
		u.attack_target = -1
	var nearest := {}
	var obscured := {}
	var distance := 999 if u.side == "foe" else int(u.range) + 1
	for other in units:
		if other.side == u.side or not other.alive:
			continue
		if u.side == "sg1" and not planet.seen.has(other.tile):
			continue
		var d := _dist(u.tile, other.tile)
		if d < distance:
			if u.side == "sg1" and not line_of_fire(u, other):
				if obscured.is_empty() or d < _dist(u.tile, obscured.tile):
					obscured = other
				continue
			distance = d
			nearest = other
	return obscured if nearest.is_empty() else nearest


func _opaque(tile: Vector2i) -> bool:
	var opacity = planet.get("opaque_tiles")
	return (opacity is Dictionary and opacity.has(tile)) or planet.blocked.get(tile, "") in ["wall", "lair", "gate"]


func line_of_fire(shooter: Dictionary, foe: Dictionary) -> bool:
	return LineOfFire.clear(Vector2(shooter.tile), Vector2(foe.tile), _opaque)


func _fire(u: Dictionary, foe: Dictionary, zat: bool = false) -> void:
	if not line_of_fire(u, foe):
		return
	u.fire_in = 1.3 if u.side == "sg1" else 2.3
	var weapon := "staff" if u.side == "foe" or u.kind in ["tealc", "bratac"] else "gun"
	if zat:
		weapon = "zat"
	if u.side == "foe" and u.range <= 1:
		weapon = "claw"
	var damage := maxi(1, int(u.get("dmg", 6)) - armor) if u.side == "foe" else 6 + lvl - 1 + dmg_bonus
	if u.side == "sg1" and u.kind in ["tealc", "bratac"]:
		damage += 2
	if zat:
		damage = 4
	_shot_effect(u, foe, weapon)
	if random.randi() % 100 < hit_chance(u, foe):
		_damage(foe, damage)
		if zat and foe.alive:
			foe.stun = 3.0
	else:
		_float_text(foe.node.position, "Raté", Color(0.8, 0.85, 0.9))


func _shot_effect(u: Dictionary, foe: Dictionary, weapon: String) -> void:
	var from: Vector3 = u.node.position + Vector3.UP * (0.3 if u.kind in ["replic", "swarm"] else 1.3)
	var to: Vector3 = foe.node.position + Vector3.UP * 1.1
	u.node.rotation.y = atan2(to.x - from.x, to.z - from.z)
	if u.node.has_method("shoot"):
		u.node.shoot()
	if combat_clock - float(_sound_at.get(weapon, -10)) > 0.25:
		_sound_at[weapon] = combat_clock
		_play_sound("hurt" if weapon == "claw" else weapon)
	var bolt := MeshInstance3D.new()
	bolt.mesh = People.box(0.06, 0.06, from.distance_to(to))
	bolt.material_override = People.mat(Color(0.45, 0.75, 1.0) if weapon == "zat" else (Color(1, 0.5, 0.15) if weapon == "staff" else Color(1, 0.85, 0.45)), 0.5, 0, 3)
	effects.add_child(bolt)
	bolt.position = (from + to) * 0.5
	bolt.look_at(to)
	var tween := effects.create_tween()
	tween.tween_interval(0.12)
	tween.tween_callback(bolt.queue_free)


func _damage(u: Dictionary, damage: int) -> void:
	if not u.alive:
		return
	if _abydos_shield(u):
		if combat_clock - float(_sound_at.get("shield", -10)) > 1:
			_sound_at["shield"] = combat_clock
			_float_text(u.node.position, "BOUCLIER · console de Carter", Color(0.4, 0.8, 1.0))
		return
	u.hp = maxi(0, u.hp - damage)
	_float_text(u.node.position, "−%d" % damage, Color(1, 0.4, 0.3) if u.side == "sg1" else Color(1, 0.8, 0.3))
	if u.hp <= 0:
		u.alive = false
		u.rt_path.clear()
		u.has_move_order = false
		u.node.walking = false
		u.node.fall()
	elif u.node.has_method("hurt"):
		u.node.hurt()
	_update_tag(u)
	main.combat_hp_changed()


func _abydos_shield(u: Dictionary) -> bool:
	return planet != null and planet.get("mission") != null and u.side == "foe" and u.get("boss", false) and not planet.mission.shield_disabled


func _work_member() -> String:
	if planet == null or planet.get("mission") == null:
		return ""
	if poi.get("id", "") == "translation" and not planet.mission.translated:
		return "daniel"
	if boss and not planet.mission.shield_disabled:
		return "carter"
	return ""


func begin_work() -> void:
	var member := _work_member()
	if _done or member.is_empty() or not poi.has("console"):
		return
	for u in units:
		if u.side == "sg1" and u.kind == member and u.alive:
			work_kind = member
			work_progress = 0.0
			u.queued = {}
			u.attack_target = -1
			var destination: Vector2i = _free_near(poi.console, {})
			if _dist(u.tile, poi.console) <= 1:
				destination = u.tile
			_route_unit(u, destination)
			select(u.index)
			main.say("SG-1", "Couvrez %s : six secondes à la console sans déplacement ni étourdissement. Un nouvel ordre à ce membre annule l'intervention." % u.name)
			refresh_panel()
			return


func _advance_work(delta: float) -> void:
	if work_kind.is_empty():
		return
	for u in units:
		if u.side != "sg1" or u.kind != work_kind:
			continue
		if not u.alive or u.stun > 0 or not u.rt_path.is_empty() or _dist(u.tile, poi.console) > 1:
			work_progress = 0.0
			return
		work_progress += delta
		if work_progress < WORK_SECONDS:
			return
		var completed := work_kind
		work_kind = ""
		work_progress = 0.0
		if completed == "daniel":
			planet.mission.translated = true
			main.say("DR JACKSON", "Code traduit. Le bouclier de Klorel est commandé par le relais près de la pyramide. Carter pourra le couper sur place.")
			planet.reveal(planet.BOSS_TILE, 4)
		else:
			planet.mission.shield_disabled = true
			main.say("MAJOR CARTER", "Bouclier coupé ! Neutralisez Klorel ; nous devons ramener son hôte vivant.")
		if poi.has("console_node"):
			var panel = poi.console_node
			if panel.has_method("activate"):
				panel.activate()
		if poi.has("console_label"):
			poi.console_label.text = "CODE TRADUIT" if completed == "daniel" else "BOUCLIER COUPÉ"
			poi.console_label.modulate = Color(0.55, 0.95, 0.65)
		main._update_hud()
		refresh_panel()
		return


func _check_end() -> bool:
	var required := _work_member()
	if not required.is_empty():
		var allies_alive := false
		for u in units:
			if u.side == "sg1" and u.alive:
				allies_alive = true
		if not allies_alive:
			return _check_elimination()
		for u in units:
			if u.side == "sg1" and u.kind == required and not u.alive:
				retreat_reason = "%s hors de combat : intervention impossible. Repli vers la porte pour le remettre sur pied. Soignez-le avant de revenir." % u.name
				_finish("flee")
				return true
		if allies_alive:
			return false # Même sans gardes, la traduction reste nécessaire.
	return _check_elimination()


func _float_text(at: Vector3, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.text = text
	label.font_size = 48
	label.pixel_size = 0.009
	label.modulate = color
	label.position = at + Vector3.UP * 2.5
	effects.add_child(label)
	var tween := effects.create_tween()
	tween.tween_property(label, "position:y", label.position.y + 1.1, 0.75)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.75)
	tween.tween_callback(label.queue_free)


func refresh_panel() -> void:
	if _done or active < 0:
		return
	for unit in units:
		_update_tag(unit)
	if is_instance_valid(feedback):
		feedback.sync(self)
	var u: Dictionary = units[active]
	var info := "PV %d/%d · %s · %s" % [u.hp, u.hpmax, "SG-1 entière" if group_selected else "ordre individuel", "PAUSE TACTIQUE" if tactical_paused else "TEMPS RÉEL"]
	if planet.get("mission") != null:
		info = "PV %d/%d · %s" % [u.hp, u.hpmax, "SG-1 entière" if group_selected else "ordre individuel"]
	info += "\n" + targeting_info(u)
	if mode == "grenade":
		info += "\nGrenade : choisissez une case à cinq cases au plus."
	if not u.queued.is_empty():
		info += "\nAction en attente : " + str(u.queued.kind)
	if not work_kind.is_empty() and not is_instance_valid(main.get("_mission_work_bar")):
		info += "\nINTERVENTION %s · %.1f / 6 s · protéger le spécialiste" % [Data.MEMBERS[work_kind].n, work_progress]
	elif not _work_member().is_empty() and not is_instance_valid(main.get("_mission_work_bar")):
		info += "\nOBJECTIF : " + ("traduire la console avec Daniel" if _work_member() == "daniel" else "couper le bouclier avec Carter")
	main.combat_status(u, info)
	var enabled := Color(0.6, 0.8, 1.0)
	var disabled := Color(0.4, 0.4, 0.45)
	var ability := str(Data.MEMBERS[u.kind].ability)
	if u.kind == "daniel":
		ability = "Traduire" if boss else "Diversion"
	var items := [
		["Reprendre" if tactical_paused else "Pause tactique", enabled, toggle_tactical_pause],
		["SG-1 entière", enabled, select_group],
		[ability + (" · %ds" % u.cd if u.cd > 0 else ""), enabled if u.cd <= 0 else disabled, _ability],
		["Tenir la position", enabled, _hold],
	]
	if not _work_member().is_empty():
		items.append(["Daniel · traduire" if _work_member() == "daniel" else "Carter · couper bouclier", enabled if work_kind.is_empty() else disabled, begin_work])
	if Game.stats.kits > 0 and u.hp < u.hpmax:
		items.append(["Trousse · %d" % Game.stats.kits, enabled, _use_kit])
	items.append(["Repli", Color(0.95, 0.45, 0.3), flee])
	var signature := ""
	for item in items:
		signature += str(item[0]) + str(item[1])
	if signature != _last_actions:
		_last_actions = signature
		main.action_grid(items)


func targeting_info(u: Dictionary) -> String:
	if u.kind == work_kind:
		return "Arme suspendue pendant l'intervention · protégez %s" % u.name
	var foe := _target_for(u)
	if foe.is_empty():
		return "Aucune cible à portée · terrain : déplacement · Espace : pause"
	var info: String = "Cible : %s" % foe.name
	if not line_of_fire(u, foe):
		return info + " · TIR BLOQUÉ · contourner l'obstacle"
	if _abydos_shield(foe):
		return info + " · BOUCLIER ACTIF · envoyer Carter au relais"
	if _dist(u.tile, foe.tile) > u.range:
		return info + " · HORS PORTÉE · déplacement nécessaire"
	info += " · tir %d %%" % hit_chance(u, foe)
	info += " · cible à couvert" if _cover(foe.tile, u.tile) else " · cible exposée"
	if _cover(u.tile, foe.tile):
		info += " · votre position est protégée face à cette cible"
	return info


func work_status(compact: bool = false) -> Dictionary:
	var required := _work_member()
	if required.is_empty():
		return {}
	var name: String = Data.MEMBERS[required].n
	if work_kind.is_empty():
		return {"text": name + (" · intervention à lancer" if compact else " · intervention à lancer dans la barre d'actions"), "value": 0.0}
	var status := "INTERVENTION"
	for unit in units:
		if unit.side == "sg1" and unit.kind == work_kind:
			if unit.stun > 0:
				status = "ÉTOURDI · reprise depuis zéro"
			elif not unit.rt_path.is_empty() or _dist(unit.tile, poi.console) > 1:
				status = "APPROCHE DE LA CONSOLE"
	if tactical_paused:
		status = "PAUSE · " + status
	if compact:
		status = "PAUSE" if tactical_paused else ("APPROCHE" if "APPROCHE" in status else ("ÉTOURDI" if "ÉTOURDI" in status else "TRAVAIL"))
	return {"text": "%s · %s · %.1f / 6 s" % [name, status, work_progress], "value": work_progress / WORK_SECONDS * 100.0}


func _update_tag(u: Dictionary) -> void:
	_update_health_tag(u)
	if not u.has("index") or not u.alive:
		return
	if u.side == "sg1" and u.index != active:
		u.tag.text = "%s · %d PV" % [u.name, u.hp]
	if u.side == "foe" and u.index == target:
		u.tag.text = "CIBLE · " + u.tag.text
	if _abydos_shield(u):
		u.tag.text += "\nBOUCLIER ACTIF"
	if u.side == "sg1" and u.kind == work_kind:
		u.tag.text = "%s · %d PV\nINTERVENTION · %d %%" % [u.name, u.hp, int(work_progress / WORK_SECONDS * 100)]
	if u.side == "sg1":
		u.tag.position.y = 2.4 + 0.45 * (int(u.index) % 2)


func _play_sound(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		Audio.play(name)


func _hold() -> void:
	for u in _selected_units():
		if u.kind == work_kind:
			work_kind = ""
			work_progress = 0.0
		u.rt_path.clear()
		u.has_move_order = false
		u.attack_target = -1
		u.queued = {}
	refresh_panel()


func _ability() -> void:
	if _done or active < 0 or not units[active].alive or units[active].cd > 0:
		return
	var u: Dictionary = units[active]
	if u.kind == work_kind:
		return
	if u.kind == "oneill":
		mode = "move" if mode == "grenade" else "grenade"
	else:
		u.queued = {"kind": u.kind, "target": target}
		if u.kind in ["carter", "bratac"] and target >= 0:
			u.attack_target = target
	_refresh_highlight()
	refresh_panel()


func _use_kit() -> void:
	if not _done and active >= 0 and Game.stats.kits > 0:
		units[active].queued = {"kind": "kit"}
		refresh_panel()



func _apply_queued(u: Dictionary) -> void:
	if u.queued.is_empty():
		return
	var action: Dictionary = u.queued
	if action.kind == "kit":
		u.queued = {}
		if Game.stats.kits > 0 and u.hp < u.hpmax:
			Game.stats.kits -= 1
			u.hp = mini(u.hpmax, u.hp + Data.kit_heal(lvl))
			_update_tag(u)
			main.combat_hp_changed()
			_play_sound("heal")
		return
	if u.cd > 0:
		return
	if action.kind == "grenade":
		u.queued = {}
		if _dist(u.tile, action.tile) > 5:
			return
		u.cd = 12.0
		u.fire_in = 1.0
		_play_sound("boom")
		_float_text(planet.tile_pos(action.tile), "GRENADE", Color(1, 0.6, 0.2))
		for other in units:
			if other.alive and _dist(other.tile, action.tile) <= 1:
				_damage(other, 12 + lvl)
		return
	if action.kind == "tealc":
		u.queued = {}
		u.cd = 18.0
		u.hp = mini(u.hpmax, u.hp + int(u.hpmax * 0.4))
		_update_tag(u)
		main.combat_hp_changed()
		_play_sound("heal")
		return
	if action.kind == "daniel":
		u.queued = {}
		u.cd = 15.0
		for other in units:
			if other.side == "foe" and other.alive:
				if boss and other.get("boss", false):
					if not other.get("translation_applied", false):
						other.dmg = maxi(1, roundi(other.dmg * 0.75))
						other["translation_applied"] = true
				else:
					other.stun = 3.0
		_float_text(u.node.position, "Traduction" if boss else "Diversion · 3 s", Color(0.7, 0.6, 1.0))
		return
	var target_index := int(action.get("target", -1))
	if target_index < 0 or target_index >= units.size() or not units[target_index].alive:
		u.queued = {}
		return
	var foe: Dictionary = units[target_index]
	if _dist(u.tile, foe.tile) > u.range or u.fire_in > 0 or not line_of_fire(u, foe):
		return
	if action.kind == "carter" and _dist(u.tile, foe.tile) > 5:
		return
	if action.kind == "bratac" and _dist(u.tile, foe.tile) > 1:
		return
	u.queued = {}
	if action.kind == "carter":
		u.cd = 8.0
		_fire(u, foe, true)
	elif action.kind == "bratac" and _dist(u.tile, foe.tile) <= 1:
		u.cd = 8.0
		_damage(foe, 16 + 2 * lvl + dmg_bonus)
		foe.stun = 2.0



func _finish(result: String) -> void:
	if _done:
		return
	_done = true
	work_kind = ""
	work_progress = 0.0
	hl.mesh = null
	if is_instance_valid(feedback):
		feedback.hide()
	for u in units:
		u.node.walking = false
		u.node.process_mode = Node.PROCESS_MODE_INHERIT
		if u.has("tag"):
			u.tag.queue_free()
		if u.side == "sg1" and not u.alive and result != "lose":
			u.alive = true
			u.hp = maxi(1, int(u.hpmax * 0.25))
			if u.node.has_method("act"):
				u.node.set("_dead", false)
				u.node.set("_busy_anim", false)
				if u.node.anim:
					u.node.anim.play(u.node.idle_anim)
			var tween := create_tween()
			tween.tween_property(u.node, "rotation:x", 0.0, 0.5)
	finished.emit(result)


# ---------- Unités, terrain, précision et résolution ----------

func start(p_planet: Node3D, p_main: Node, p: Dictionary, members: Array, hp: Dictionary, level: int, planet_tier: int, gear: Dictionary = {}) -> void:
	dmg_bonus = gear.get("dmg", 0)
	hit_bonus = gear.get("hit", 0)
	armor = gear.get("armor", 0)
	planet = p_planet
	main = p_main
	poi = p
	lvl = level
	tier = planet_tier
	boss = p.k == "boss"
	_hl_mat = StandardMaterial3D.new()
	_hl_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hl_mat.vertex_color_use_as_albedo = true
	_hl_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hl = MeshInstance3D.new()
	hl.material_override = _hl_mat
	add_child(hl)
	# SG-1
	var taken := {}
	for i in members.size():
		var k: String = members[i]
		var node: Node3D = planet.team[i]
		var hpmax := Game.member_max(k, lvl)
		var t := _free_near(planet.pos_tile(node.position), taken)
		taken[t] = true
		var u := {"side": "sg1", "kind": k, "name": Data.MEMBERS[k].n, "node": node, "hp": clamp(int(hp.get(k, hpmax)), 0, hpmax),
			"hpmax": hpmax, "tile": t, "cd": 0, "stun": 0, "range": Data.MEMBERS[k].range}
		u["alive"] = u.hp > 0
		units.append(u)
		_place(u)
		if not u.alive:
			node.rotation.x = -PI / 2.0
	# Les ennemis : les figurants du lieu deviennent des combattants
	var d: Dictionary = planet.data
	for a in p.actors:
		var k: String = a.kind
		var is_boss: bool = boss and k == d.boss.a
		var st := _enemy_stats(k, is_boss)
		var gp: Vector3 = a.global_position
		var t := _free_near(planet.pos_tile(gp), taken)
		taken[t] = true
		var u := {"side": "foe", "kind": k, "name": d.boss.n if is_boss else _foe_name(k), "node": a, "hp": st.hp, "hpmax": st.hp,
			"tile": t, "dmg": st.dmg, "range": st.range, "stun": 0, "alive": true, "boss": is_boss}
		units.append(u)
		a.reparent(planet)
		_place(u)
	for u in units:
		_make_tag(u)
	planet.focus(planet.tile_pos(units[0].tile).lerp(planet.tile_pos(p.tile), 0.5), 0.6)
	_begin_combat()


func _foe_name(k: String) -> String:
	return {"serpent": "Garde Serpent", "beast": "Mastadge", "jaffa": "Jaffa", "priest": "Prêtre jaffa", "jaffa2": "Jaffa d'Heru'ur",
		"horus": "Garde Horus", "prisoner": "Prisonnier", "brute": "Garde de Bynarr", "replic": "Réplicateur",
		"swarm": "Essaim", "kull": "Guerrier Kull", "jaffa3": "Jaffa d'Anubis"}.get(k, "Ennemi")


func _free_near(t: Vector2i, taken: Dictionary) -> Vector2i:
	for r in 4:
		for x in range(-r, r + 1):
			for y in range(-r, r + 1):
				var c := t + Vector2i(x, y)
				if c.x < 0 or c.y < 0 or c.x >= planet.n_tiles or c.y >= planet.n_tiles:
					continue
				if planet.blocked.has(c) or taken.has(c) or unit_at(c) >= 0:
					continue
				return c
	return t


func unit_at(t: Vector2i) -> int:
	for i in units.size():
		if units[i].alive and units[i].tile == t:
			return i
	return -1


func _place(u: Dictionary) -> void:
	u.node.position = planet.tile_pos(u.tile)


func _dist(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))


func _path(from: Vector2i, to: Vector2i) -> Array:
	var g: AStarGrid2D = planet.grid
	var solid := []
	for u in units:
		if u.alive and u.tile != from and u.tile != to:
			if not g.is_point_solid(u.tile):
				g.set_point_solid(u.tile, true)
				solid.append(u.tile)
	var ids := g.get_id_path(from, to)
	for t in solid:
		g.set_point_solid(t, false)
	return Array(ids)


func _cover(target_tile: Vector2i, from: Vector2i) -> bool:
	var dx := signi(from.x - target_tile.x)
	var dy := signi(from.y - target_tile.y)
	for c in [Vector2i(dx, dy), Vector2i(dx, 0), Vector2i(0, dy)]:
		if c != Vector2i.ZERO and planet.blocked.get(target_tile + c, "") in ["obj", "lair", "gate", "dhd", "wall", "console"]:
			return true
	return false


func hit_chance(a: Dictionary, d: Dictionary) -> int:
	var dist := _dist(a.tile, d.tile)
	var c: int = 85 - 5 * max(0, dist - 3)
	if _cover(d.tile, a.tile):
		c -= 30
	if a.side == "sg1":
		c += 2 * (lvl - 1) + hit_bonus
	return clamp(c, 10, 95)


func _make_tag(u: Dictionary) -> void:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.006
	l.font_size = 52
	l.outline_size = 14
	l.position = Vector3(0, 1.0 if u.kind in ["replic", "swarm"] else (2.4 if not u.get("boss", false) else 2.9), 0)
	u.node.add_child(l)
	u["tag"] = l
	_update_tag(u)


func _update_health_tag(u: Dictionary) -> void:
	var l: Label3D = u.tag
	var n := int(round(8.0 * u.hp / max(1, u.hpmax)))
	l.text = "%s\n%s %d" % [u.name, "■".repeat(n) + "□".repeat(8 - n), u.hp]
	l.modulate = Color(0.55, 0.95, 0.45) if u.side == "sg1" else Color(1.0, 0.45, 0.35)
	l.visible = u.alive


func _quad(st: SurfaceTool, t: Vector2i, c: Color, inset: float = 0.08) -> void:
	var p: Vector3 = planet.tile_pos(t) + Vector3(0, 0.06, 0)
	var h: float = planet.tile_size / 2.0 - inset
	var v := [p + Vector3(-h, 0, -h), p + Vector3(h, 0, -h), p + Vector3(h, 0, h), p + Vector3(-h, 0, h)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_color(c)
		st.add_vertex(v[i])


func _refresh_highlight() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	if not _done and active >= 0:
		var u: Dictionary = units[active]
		if mode == "grenade":
			for x in range(-5, 6):
				for y in range(-5, 6):
					var t: Vector2i = u.tile + Vector2i(x, y)
					if t.x >= 0 and t.y >= 0 and t.x < planet.n_tiles and t.y < planet.n_tiles and not planet.blocked.has(t):
						_quad(st, t, Color(1.0, 0.6, 0.2, 0.22))
						any = true
		_quad(st, u.tile, Color(1.0, 0.85, 0.3, 0.55), 0.02)
		any = true
	for i in units.size():
		var e: Dictionary = units[i]
		if e.side == "foe" and e.alive:
			_quad(st, e.tile, Color(1.0, 0.25, 0.2, 0.55 if i == target else 0.25), 0.02)
			any = true
	hl.mesh = st.commit() if any else null


func _check_elimination() -> bool:
	var sg1 := false
	var foes := false
	for u in units:
		if u.alive and u.side == "sg1":
			sg1 = true
		if u.alive and u.side == "foe":
			foes = true
	if not sg1:
		_finish("lose")
		return true
	if not foes:
		_finish("win")
		return true
	return false


func flee() -> void:
	_finish("flee")


func member_hp() -> Dictionary:
	var d := {}
	for u in units:
		if u.side == "sg1":
			d[u.kind] = u.hp
	return d


func _enemy_stats(kind: String, is_boss: bool) -> Dictionary:
	return Stats.enemy(kind, is_boss, tier, Settings.value("difficulty"))


func snapshot() -> Dictionary:
	var saved_units := []
	for unit in units:
		var data: Dictionary = unit.duplicate(true)
		data.erase("node")
		data.erase("tag")
		data["position"] = unit.node.position
		data["rotation"] = unit.node.rotation
		saved_units.append(data)
	return {"units": saved_units, "active": active, "target": target, "mode": mode, "group": group_selected,
		"clock": combat_clock, "work_kind": work_kind, "work_progress": work_progress, "level": lvl,
		"gear": {"dmg": dmg_bonus, "hit": hit_bonus, "armor": armor}, "rng_seed": random.seed, "rng": random.state}


func restore_snapshot(state: Dictionary) -> void:
	for i in units.size():
		var unit: Dictionary = units[i]
		var saved: Dictionary = state.units[i]
		for key in saved:
			if key not in ["position", "rotation"]:
				unit[key] = saved[key]
		unit.node.position = saved.position
		unit.node.rotation = saved.rotation
		if not unit.alive:
			unit.node.fall()
	active = state.active
	target = state.target
	mode = state.mode
	group_selected = state.group
	combat_clock = state.clock
	work_kind = state.work_kind
	work_progress = state.work_progress
	random.seed = state.rng_seed
	random.state = state.rng
	if not tactical_paused:
		toggle_tactical_pause()
	refresh_panel()
