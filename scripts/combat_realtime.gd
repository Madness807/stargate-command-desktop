extends "res://scripts/combat.gd"
## Toutes les missions de campagne : déplacements et tirs simultanés, pause tactique avec ordres.
## Réutilise les personnages, stats, couverts, récompenses et transitions de campagne.
## Aucun timer asynchrone ne décide des dégâts : toute la logique avance avec advance().

var tactical_paused := false
var group_selected := true
var combat_clock := 0.0
var _panel_clock := 0.0
var effects: Node3D
var _sound_at := {}
var _last_actions := ""


func start_player_turn() -> void:
	turn = "player" # Compatibilité du HUD ; il n'y a plus d'alternance de tours.
	effects = Node3D.new()
	add_child(effects)
	for i in units.size():
		var u: Dictionary = units[i]
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
		u.ap = 1
		if active < 0 and u.side == "sg1" and u.alive:
			active = i
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
			elif u.queued.kind in ["carter", "zat"]:
				desired_range = 5
		var in_range: bool = not foe.is_empty() and _dist(u.tile, foe.tile) <= desired_range
		if not foe.is_empty() and not in_range and (u.side == "foe" or u.attack_target >= 0) and u.repath_in <= 0:
			u.repath_in = 0.6
			_route_unit(u, foe.tile)
		if in_range and (u.attack_target >= 0 or u.side == "foe"):
			u.rt_path.clear()
			u.has_move_order = false
		elif u.has_move_order and u.rt_path.is_empty() and u.repath_in <= 0:
			u.repath_in = 0.6
			_route_unit(u, u.move_goal)
		if in_range and u.fire_in <= 0:
			_fire(u, foe)
		if u.alive:
			_move_step(u, delta)
	if _check_end():
		return
	if active >= 0 and not units[active].alive:
		_select_next()
	_panel_clock += delta
	if _panel_clock >= 0.25:
		_panel_clock = 0
		_refresh_highlight()
		refresh_panel()


func toggle_tactical_pause() -> void:
	if _done:
		return
	tactical_paused = not tactical_paused
	for u in units:
		u.node.process_mode = Node.PROCESS_MODE_DISABLED if tactical_paused else Node.PROCESS_MODE_INHERIT
	effects.process_mode = Node.PROCESS_MODE_DISABLED if tactical_paused else Node.PROCESS_MODE_INHERIT
	refresh_panel()


func _compute_reach(_unit: Dictionary) -> void:
	reach.clear() # Toutes les cases accessibles sont autorisées, pas de quota de déplacement.


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
	var distance := 999 if u.side == "foe" else int(u.range) + 1
	for other in units:
		if other.side == u.side or not other.alive:
			continue
		if u.side == "sg1" and not planet.seen.has(other.tile):
			continue
		var d := _dist(u.tile, other.tile)
		if d < distance:
			distance = d
			nearest = other
	return nearest


func _fire(u: Dictionary, foe: Dictionary, zat: bool = false) -> void:
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
	if randi() % 100 < hit_chance(u, foe):
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
	var u: Dictionary = units[active]
	var info := "PV %d/%d · %s · %s" % [u.hp, u.hpmax, "SG-1 entière" if group_selected else "ordre individuel", "PAUSE TACTIQUE" if tactical_paused else "TEMPS RÉEL"]
	info += "\nTouchez le terrain pour avancer, un ennemi pour concentrer les tirs. Espace : pause / reprise."
	if mode == "grenade":
		info += "\nGrenade : choisissez une case à cinq cases au plus."
	if not u.queued.is_empty():
		info += "\nAction en attente : " + str(u.queued.kind)
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
	if Game.stats.kits > 0 and u.hp < u.hpmax:
		items.append(["Trousse · %d" % Game.stats.kits, enabled, _use_kit])
	items.append(["Repli", Color(0.95, 0.45, 0.3), flee])
	var signature := ""
	for item in items:
		signature += str(item[0]) + str(item[1])
	if signature != _last_actions:
		_last_actions = signature
		main.action_grid(items)


func _play_sound(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		Audio.play(name)


func _hold() -> void:
	for u in _selected_units():
		u.rt_path.clear()
		u.has_move_order = false
		u.attack_target = -1
		u.queued = {}
	refresh_panel()


func _ability() -> void:
	if _done or active < 0 or not units[active].alive or units[active].cd > 0:
		return
	var u: Dictionary = units[active]
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


func _player_shoot(zat: bool) -> void:
	if not _done and active >= 0 and target >= 0:
		units[active].queued = {"kind": "zat" if zat else "shot", "target": target}


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
					other.dmg = maxi(1, int(other.dmg * 0.75))
				else:
					other.stun = 3.0
		_float_text(u.node.position, "Traduction" if boss else "Diversion · 3 s", Color(0.7, 0.6, 1.0))
		return
	var target_index := int(action.get("target", -1))
	if target_index < 0 or target_index >= units.size() or not units[target_index].alive:
		u.queued = {}
		return
	var foe: Dictionary = units[target_index]
	if _dist(u.tile, foe.tile) > u.range or u.fire_in > 0:
		return
	if action.kind in ["carter", "zat"] and _dist(u.tile, foe.tile) > 5:
		return
	if action.kind == "bratac" and _dist(u.tile, foe.tile) > 1:
		return
	u.queued = {}
	if action.kind in ["carter", "zat"]:
		u.cd = 8.0
		_fire(u, foe, true)
	elif action.kind == "bratac" and _dist(u.tile, foe.tile) <= 1:
		u.cd = 8.0
		_damage(foe, 16 + 2 * lvl + dmg_bonus)
		foe.stun = 2.0
	else:
		_fire(u, foe)


func enemy_turn() -> void:
	pass # Ancien point d'entrée du mode démonstration ; aucune fin de tour en temps réel.


func _finish(result: String) -> void:
	if _done:
		return
	for u in units:
		u.node.walking = false
		u.node.process_mode = Node.PROCESS_MODE_INHERIT
		if u.side == "sg1" and not u.alive and result != "lose" and u.node.has_method("act"):
			u.node.set("_dead", false)
			u.node.set("_busy_anim", false)
			if u.node.anim:
				u.node.anim.play(u.node.idle_anim)
	super._finish(result)
