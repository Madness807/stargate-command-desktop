extends Node3D
## Combat tactique au tour par tour sur la carte de la planète.
## SG-1 : 2 actions par membre (se déplacer, tirer, capacité). Les ennemis jouent ensuite.

signal finished(result: String)        # "win", "lose", "flee", "talk"

const People = preload("res://scripts/people.gd")
const Data = preload("res://scripts/data.gd")

const MOVE := 4

var planet: Node3D
## L'interface de mission (main.gd) : say, clear_actions, action_grid, combat_status, combat_hp_changed
var main: Node
var units: Array = []
var turn := "player"
var active := -1
var target := -1
var mode := "move"
var busy := false
var tier := 1
var lvl := 1
var boss := false
var poi: Dictionary
var hl: MeshInstance3D
var _hl_mat: StandardMaterial3D
var reach := {}
# L'équipement acheté à l'armurerie : dégâts et précision en plus, dégâts reçus en moins
var dmg_bonus := 0
var hit_bonus := 0
var armor := 0


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
			"hpmax": hpmax, "tile": t, "ap": 2, "cd": 0, "stun": 0, "range": Data.MEMBERS[k].range}
		u["alive"] = u.hp > 0
		units.append(u)
		_place(u)
		if not u.alive:
			node.rotation.x = -PI / 2.0
	# Les ennemis : les figurants du lieu deviennent des combattants
	var d: Dictionary = planet.data
	var foe_kind: String = d.boss.a if boss else d.foes[p.f].a
	for a in p.actors:
		var k: String = a.kind
		var is_boss: bool = boss and k == d.boss.a
		var st := _enemy_stats(k, is_boss)
		var gp: Vector3 = a.global_position
		var t := _free_near(planet.pos_tile(gp), taken)
		taken[t] = true
		var u := {"side": "foe", "kind": k, "name": d.boss.n if is_boss else _foe_name(k), "node": a, "hp": st.hp, "hpmax": st.hp,
			"tile": t, "ap": 2, "dmg": st.dmg, "range": st.range, "move": st.move, "stun": 0, "alive": true, "boss": is_boss}
		units.append(u)
		a.reparent(planet)
		_place(u)
	for u in units:
		_make_tag(u)
	planet.focus(planet.tile_pos(units[0].tile).lerp(planet.tile_pos(p.tile), 0.5), 0.6)
	start_player_turn()


func _foe_name(k: String) -> String:
	return {"serpent": "Garde Serpent", "beast": "Mastadge", "jaffa": "Jaffa", "priest": "Prêtre jaffa", "jaffa2": "Jaffa d'Heru'ur",
		"horus": "Garde Horus", "prisoner": "Prisonnier", "brute": "Garde de Bynarr", "replic": "Réplicateur",
		"swarm": "Essaim", "kull": "Guerrier Kull", "jaffa3": "Jaffa d'Anubis"}.get(k, "Ennemi")


## Les caractéristiques d'un ennemi, ajustées à la difficulté choisie dans les options
func _enemy_stats(k: String, is_boss: bool) -> Dictionary:
	var st := _base_stats(k, is_boss)
	var m: Dictionary = Data.DIFFICULTY[Settings.value("difficulty")]
	st.hp = maxi(1, roundi(st.hp * m.hp))
	st.dmg = maxi(1, roundi(st.dmg * m.dmg))
	return st


func _base_stats(k: String, is_boss: bool) -> Dictionary:
	if is_boss:
		return {"hp": 30 + 18 * tier, "dmg": 6 + 3 * tier, "range": 6, "move": 2}
	match k:
		"beast":
			return {"hp": 10 + 4 * tier, "dmg": 5 + 2 * tier, "range": 1, "move": 5}
		"replic":
			return {"hp": 8 + 4 * tier, "dmg": 4 + 2 * tier, "range": 1, "move": 4}
		"swarm":
			return {"hp": 14 + 5 * tier, "dmg": 5 + 2 * tier, "range": 1, "move": 4}
		"kull":
			return {"hp": 20 + 6 * tier, "dmg": 6 + 2 * tier, "range": 6, "move": 3}
		"prisoner":
			return {"hp": 10 + 4 * tier, "dmg": 4 + 2 * tier, "range": 1, "move": 4}
	return {"hp": 12 + 5 * tier, "dmg": 4 + 2 * tier, "range": 6, "move": 3}


# ---------- Cases ----------

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


func _compute_reach(u: Dictionary) -> void:
	reach.clear()
	if u.ap <= 0:
		return
	for x in range(-MOVE, MOVE + 1):
		for y in range(-MOVE, MOVE + 1):
			var t: Vector2i = u.tile + Vector2i(x, y)
			if t.x < 0 or t.y < 0 or t.x >= planet.n_tiles or t.y >= planet.n_tiles or planet.blocked.has(t) or unit_at(t) >= 0:
				continue
			var p := _path(u.tile, t)
			if p.size() >= 2 and p.size() - 1 <= MOVE:
				reach[t] = p


## Couvert : un obstacle entre la cible et le tireur, sur la case voisine de la cible
func _cover(target_tile: Vector2i, from: Vector2i) -> bool:
	var dx := signi(from.x - target_tile.x)
	var dy := signi(from.y - target_tile.y)
	for c in [Vector2i(dx, dy), Vector2i(dx, 0), Vector2i(0, dy)]:
		if c != Vector2i.ZERO and planet.blocked.get(target_tile + c, "") in ["obj", "lair", "gate", "dhd"]:
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


# ---------- Affichage ----------

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


func _update_tag(u: Dictionary) -> void:
	var l: Label3D = u.tag
	var n := int(round(8.0 * u.hp / max(1, u.hpmax)))
	l.text = "%s\n%s %d" % [u.name, "■".repeat(n) + "□".repeat(8 - n), u.hp]
	l.modulate = Color(0.55, 0.95, 0.45) if u.side == "sg1" else Color(1.0, 0.45, 0.35)
	l.visible = u.alive


func _float_text(at: Vector3, text: String, c: Color) -> void:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.009
	l.font_size = 64
	l.outline_size = 16
	l.text = text
	l.modulate = c
	l.position = at + Vector3(0, 2.0, 0)
	planet.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y + 1.6, 1.0)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tw.tween_callback(l.queue_free)


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
	if turn == "player" and active >= 0:
		var u: Dictionary = units[active]
		if mode == "grenade":
			for x in range(-5, 6):
				for y in range(-5, 6):
					var t: Vector2i = u.tile + Vector2i(x, y)
					if t.x >= 0 and t.y >= 0 and t.x < planet.n_tiles and t.y < planet.n_tiles and not planet.blocked.has(t):
						_quad(st, t, Color(1.0, 0.6, 0.2, 0.22))
						any = true
		else:
			for t in reach:
				_quad(st, t, Color(0.3, 0.7, 1.0, 0.42))
				any = true
		_quad(st, u.tile, Color(1.0, 0.85, 0.3, 0.55), 0.02)
		any = true
	for i in units.size():
		var e: Dictionary = units[i]
		if e.side == "foe" and e.alive:
			_quad(st, e.tile, Color(1.0, 0.25, 0.2, 0.55 if i == target else 0.25), 0.02)
			any = true
	hl.mesh = st.commit() if any else null


# ---------- Tour de SG-1 ----------

func start_player_turn() -> void:
	turn = "player"
	for u in units:
		if u.side == "sg1" and u.alive:
			u.ap = 2
			u.cd = max(0, u.cd - 1)
	active = -1
	_select_next()


func _select_next() -> void:
	target = -1
	mode = "move"
	for k in units.size():
		var i := (active + 1 + k) % units.size()
		var u: Dictionary = units[i]
		if u.side == "sg1" and u.alive and u.ap > 0:
			select(i)
			return
	enemy_turn()


func select(i: int) -> void:
	active = i
	target = -1
	mode = "move"
	_compute_reach(units[i])
	_refresh_highlight()
	refresh_panel()


func refresh_panel() -> void:
	if active < 0 or turn != "player":
		return
	var u: Dictionary = units[active]
	var pips := "●".repeat(u.ap) + "○".repeat(2 - u.ap)
	var info := "PV %d/%d · actions %s" % [u.hp, u.hpmax, pips]
	if mode == "grenade":
		info += "\nTouchez une case à 5 cases au plus pour lancer la grenade."
	elif target >= 0:
		var e: Dictionary = units[target]
		info += "\nCible : %s (%d PV) · %d %% de chances%s" % [e.name, e.hp, hit_chance(u, e), " · à couvert" if _cover(e.tile, u.tile) else ""]
		if _dist(u.tile, e.tile) > u.range:
			info += " · hors de portée"
	else:
		info += "\nTouchez une case bleue pour avancer, un ennemi pour le viser."
	main.combat_status(u, info)
	var items := []
	if target >= 0 and _dist(u.tile, units[target].tile) <= u.range:
		items.append(["Tirer (%d %%)" % hit_chance(u, units[target]), Color(0.95, 0.5, 0.3), func(): _player_shoot(false)])
	var ab: String = Data.MEMBERS[u.kind].ability
	if u.kind == "daniel" and boss:
		ab = "Traduire"
	var ab_ok: bool = u.cd == 0 and (u.kind != "carter" or (target >= 0 and _dist(u.tile, units[target].tile) <= 5))
	if u.kind == "bratac":
		ab_ok = u.cd == 0 and target >= 0 and _dist(u.tile, units[target].tile) <= 1
	items.append([ab + ("" if u.cd == 0 else " (%d)" % u.cd), Color(0.75, 0.45, 0.95) if ab_ok else Color(0.4, 0.4, 0.45), func(): _ability()])
	if Game.stats.kits > 0 and u.hp < u.hpmax:
		items.append(["Trousse (%d)" % Game.stats.kits, Color(0.45, 0.85, 0.4), func(): _use_kit()])
	items.append(["Membre suivant", Color(0.4, 0.8, 1.0), func(): _select_next()])
	items.append(["Fin du tour", Color(0.6, 0.65, 0.75), func(): enemy_turn()])
	main.action_grid(items)


func on_tap(t: Vector2i) -> void:
	if busy or turn != "player" or active < 0:
		return
	var i := unit_at(t)
	var u: Dictionary = units[active]
	if mode == "grenade":
		if _dist(u.tile, t) <= 5 and not planet.blocked.has(t):
			_grenade(t)
		return
	if i >= 0 and units[i].side == "sg1":
		if units[i].ap > 0:
			select(i)
		return
	if i >= 0 and units[i].side == "foe":
		target = i
		_refresh_highlight()
		refresh_panel()
		return
	if reach.has(t):
		_move(u, reach[t])


func _move(u: Dictionary, p: Array) -> void:
	busy = true
	main.clear_actions()
	var node: Node3D = u.node
	node.walking = true
	for k in range(1, p.size()):
		var pos: Vector3 = planet.tile_pos(p[k])
		var dv := pos - node.position
		node.rotation.y = atan2(dv.x, dv.z)
		var tw := create_tween()
		tw.tween_property(node, "position", pos, 0.22)
		await tw.finished
	node.walking = false
	u.tile = p[p.size() - 1]
	planet.reveal(u.tile, 3)
	u.ap -= 1
	busy = false
	_after_action()


func _after_action() -> void:
	if _check_end():
		return
	if active >= 0 and units[active].ap > 0:
		select(active)
	else:
		_select_next()


func _player_shoot(zat: bool) -> void:
	if busy:
		return
	var u: Dictionary = units[active]
	var e: Dictionary = units[target]
	busy = true
	main.clear_actions()
	var weapon := "zat" if zat else ("staff" if u.kind in ["tealc", "bratac"] else "gun")
	var dmg_lo := 5 + lvl - 1 + dmg_bonus
	var dmg_hi := 8 + lvl - 1 + dmg_bonus
	if u.kind in ["tealc", "bratac"]:
		dmg_lo += 2
		dmg_hi += 3
	elif u.kind == "daniel":
		dmg_lo -= 1
		dmg_hi -= 1
	if zat:
		dmg_lo = 3
		dmg_hi = 5
	await _shoot(u, e, weapon, randi_range(dmg_lo, dmg_hi), zat)
	u.ap = 0
	if zat:
		u.cd = 3
	busy = false
	_after_action()


func _ability() -> void:
	if busy:
		return
	var u: Dictionary = units[active]
	if u.cd > 0:
		return
	match u.kind:
		"oneill":
			mode = "grenade" if mode != "grenade" else "move"
			_refresh_highlight()
			refresh_panel()
		"carter":
			if target >= 0 and _dist(u.tile, units[target].tile) <= 5:
				_player_shoot(true)
		"bratac":
			if target >= 0 and _dist(u.tile, units[target].tile) <= 1:
				_lance_strike()
		"tealc":
			var h := int(u.hpmax * 0.4)
			u.hp = min(u.hpmax, u.hp + h)
			u.cd = 3
			u.ap = 0
			_update_tag(u)
			_float_text(u.node.position, "+%d" % h, Color(0.5, 1.0, 0.5))
			Audio.play("heal")
			_after_action()
		"daniel":
			u.cd = 3
			u.ap = 0
			Audio.play("press")
			if boss:
				for e in units:
					if e.side == "foe" and e.get("boss", false):
						e.dmg = int(e.dmg * 0.75)
						_float_text(e.node.position, "Affaibli", Color(0.8, 0.6, 1.0))
				_after_action()
			elif randf() < min(0.85, 0.35 + 0.06 * lvl):
				busy = true
				main.say("DR JACKSON", "« Kree ! Shal kek nem ron. » Les ennemis baissent leurs armes et s'éloignent.")
				for e in units:
					if e.side == "foe" and e.alive:
						var tw := create_tween()
						tw.tween_property(e.node, "position", e.node.position + Vector3(6, 0, 6), 1.5)
						tw.tween_callback(e.node.hide)
						e.alive = false
						_update_tag(e)
				await get_tree().create_timer(1.6, false).timeout
				_finish("talk")
			else:
				_float_text(u.node.position, "Refus", Color(0.8, 0.8, 0.8))
				_after_action()


func _grenade(t: Vector2i) -> void:
	var u: Dictionary = units[active]
	busy = true
	mode = "move"
	main.clear_actions()
	var to: Vector3 = planet.tile_pos(t)
	var dv: Vector3 = to - u.node.position
	u.node.rotation.y = atan2(dv.x, dv.z)
	if u.node.has_method("act"):
		u.node.act("OverhandThrow")
		await get_tree().create_timer(0.45, false).timeout
	var from: Vector3 = u.node.position + Vector3(0, 1.6, 0)
	var g := MeshInstance3D.new()
	g.mesh = People.ball(0.1)
	g.material_override = People.mat(Color(0.2, 0.25, 0.15))
	planet.add_child(g)
	var tw := create_tween()
	tw.tween_method(func(k: float):
		g.position = from.lerp(to, k) + Vector3(0, sin(k * PI) * 3.0, 0), 0.0, 1.0, 0.7)
	await tw.finished
	g.queue_free()
	Audio.play("boom")
	_explosion(to, 2.2)
	for e in units:
		if e.alive and _dist(e.tile, t) <= 1:
			await _damage(e, randi_range(10, 14) + lvl)
	u.cd = 3
	u.ap = 0
	busy = false
	_after_action()


func _explosion(at: Vector3, size: float) -> void:
	var b := MeshInstance3D.new()
	b.mesh = People.ball(0.5)
	b.material_override = People.mat(Color(1.0, 0.55, 0.15), 0.5, 0.0, 6.0)
	b.position = at + Vector3(0, 0.6, 0)
	planet.add_child(b)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.2)
	light.light_energy = 8.0
	light.omni_range = 8.0
	light.position = at + Vector3(0, 1.5, 0)
	planet.add_child(light)
	var tw := create_tween()
	tw.tween_property(b, "scale", Vector3.ONE * size * 2.0, 0.35)
	tw.parallel().tween_property(b, "transparency", 1.0, 0.45)
	tw.parallel().tween_property(light, "light_energy", 0.0, 0.45)
	tw.tween_callback(b.queue_free)
	tw.tween_callback(light.queue_free)


# ---------- Tirs et dégâts ----------

func _shoot(a: Dictionary, d: Dictionary, weapon: String, dmg: int, stun: bool) -> void:
	var an: Node3D = a.node
	var dn: Node3D = d.node
	var dv := dn.position - an.position
	an.rotation.y = atan2(dv.x, dv.z)
	var hit := randi() % 100 < hit_chance(a, d)
	var from := an.position + Vector3(0, 1.3, 0) + dv.normalized() * 0.5
	var to := dn.position + Vector3(0, 1.1, 0)
	if not hit:
		to += Vector3(randf_range(-1.2, 1.2), randf_range(0.3, 1.0), randf_range(-1.2, 1.2))
	if an.has_method("shoot") and weapon != "claw":
		an.shoot()
		await get_tree().create_timer(0.15, false).timeout
	Audio.play({"gun": "gun", "staff": "staff", "zat": "zat", "claw": "hurt"}[weapon])
	var shots := 3 if weapon == "gun" else 1
	for s in shots:
		var bolt := MeshInstance3D.new()
		if weapon == "gun":
			bolt.mesh = People.box(0.04, 0.04, 0.5)
			bolt.material_override = People.mat(Color(1.0, 0.85, 0.3), 0.5, 0.0, 6.0)
		elif weapon == "staff":
			bolt.mesh = People.ball(0.16)
			bolt.material_override = People.mat(Color(1.0, 0.5, 0.15), 0.5, 0.0, 7.0)
		elif weapon == "zat":
			bolt.mesh = People.ball(0.14)
			bolt.material_override = People.mat(Color(0.4, 0.7, 1.0), 0.5, 0.0, 7.0)
		else:
			bolt.mesh = People.box(0.02, 0.02, 0.02)
		planet.add_child(bolt)
		bolt.position = from
		bolt.look_at_from_position(from, to)
		var tw := create_tween()
		tw.tween_property(bolt, "position", to, 0.22 if weapon != "claw" else 0.05)
		tw.tween_callback(bolt.queue_free)
		await get_tree().create_timer(0.08, false).timeout
	await get_tree().create_timer(0.18, false).timeout
	if hit:
		await _damage(d, dmg)
		if stun and d.alive:
			d.stun = 1
			_float_text(dn.position + Vector3(0, 0.6, 0), "Étourdi", Color(0.5, 0.8, 1.0))
	else:
		_float_text(dn.position, "Raté", Color(0.85, 0.85, 0.85))
	await get_tree().create_timer(0.3, false).timeout


func _damage(u: Dictionary, dmg: int) -> void:
	u.hp = max(0, u.hp - dmg)
	_float_text(u.node.position, "-%d" % dmg, Color(1.0, 0.85, 0.3) if u.side == "foe" else Color(1.0, 0.35, 0.3))
	if u.side == "sg1":
		Audio.play("hurt")
	if u.hp <= 0:
		u.alive = false
		u.node.fall()
	elif u.node.has_method("hurt"):
		u.node.hurt()
	_update_tag(u)
	main.combat_hp_changed()


# ---------- Tour ennemi ----------

func enemy_turn() -> void:
	if _check_end():
		return
	turn = "foe"
	active = -1
	target = -1
	reach.clear()
	_refresh_highlight()
	main.clear_actions()
	main.say("TOUR ENNEMI", "Les ennemis passent à l'attaque !")
	busy = true
	for e in units:
		if e.side != "foe" or not e.alive:
			continue
		if e.stun > 0:
			e.stun -= 1
			_float_text(e.node.position, "Étourdi", Color(0.5, 0.8, 1.0))
			await get_tree().create_timer(0.5, false).timeout
			continue
		var tgt := _nearest_member(e)
		if tgt.is_empty():
			break
		planet.focus(e.node.position.lerp(tgt.node.position, 0.5), 0.4)
		if _dist(e.tile, tgt.tile) > e.range:
			# S'approcher jusqu'à être à portée
			var p := _path(e.tile, tgt.tile)
			if p.size() >= 2:
				var steps: int = min(e.move, p.size() - 2) if e.range <= 1 else min(e.move, p.size() - 1)
				var stop := 0
				for k in range(1, steps + 1):
					if unit_at(p[k]) >= 0:
						break
					stop = k
					if _dist(p[k], tgt.tile) <= e.range:
						break
				if stop > 0:
					e.node.walking = true
					for k in range(1, stop + 1):
						var pos: Vector3 = planet.tile_pos(p[k])
						var dv: Vector3 = pos - e.node.position
						e.node.rotation.y = atan2(dv.x, dv.z)
						var tw := create_tween()
						tw.tween_property(e.node, "position", pos, 0.22)
						await tw.finished
					e.node.walking = false
					e.tile = p[stop]
		if _dist(e.tile, tgt.tile) <= e.range:
			var weapon := "claw" if e.range <= 1 else "staff"
			await _shoot(e, tgt, weapon, max(1, randi_range(e.dmg - 2, e.dmg + 2) - armor), false)
			if _check_end():
				busy = false
				return
		await get_tree().create_timer(0.25, false).timeout
	busy = false
	if not _check_end():
		start_player_turn()


func _nearest_member(e: Dictionary) -> Dictionary:
	var best := {}
	var bd := 999
	for u in units:
		if u.side == "sg1" and u.alive:
			var d := _dist(e.tile, u.tile)
			if d < bd:
				bd = d
				best = u
	return best


# ---------- Fin du combat ----------

func _check_end() -> bool:
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


var _done := false

func _finish(result: String) -> void:
	if _done:
		return
	_done = true
	turn = "over"
	hl.mesh = null
	for u in units:
		if u.has("tag"):
			u.tag.queue_free()
		if u.side == "sg1" and not u.alive and result != "lose":
			u.alive = true
			u.hp = max(1, int(u.hpmax * 0.25))
			var tw := create_tween()
			tw.tween_property(u.node, "rotation:x", 0.0, 0.5)
	finished.emit(result)


func member_hp() -> Dictionary:
	var d := {}
	for u in units:
		if u.side == "sg1":
			d[u.kind] = u.hp
	return d


## Bra'tac frappe au corps à corps avec sa lance : gros dégâts, et l'ennemi est sonné
func _lance_strike() -> void:
	var u: Dictionary = units[active]
	var e: Dictionary = units[target]
	busy = true
	main.clear_actions()
	var n: Node3D = u.node
	var dv: Vector3 = e.node.position - n.position
	n.rotation.y = atan2(dv.x, dv.z)
	var home := n.position
	if n.has_method("act"):
		n.act("Sword_Attack")
	var tw := create_tween()
	tw.tween_property(n, "position", home + dv * 0.45, 0.15)
	tw.tween_property(n, "position", home, 0.2)
	Audio.play("staff")
	await get_tree().create_timer(0.15, false).timeout
	_explosion(e.node.position, 0.8)
	await _damage(e, randi_range(14, 18) + 2 * lvl + dmg_bonus)
	if e.alive:
		e.stun = 1
		_float_text(e.node.position + Vector3(0, 0.6, 0), "Sonné", Color(0.5, 0.8, 1.0))
	await get_tree().create_timer(0.4, false).timeout
	u.cd = 2
	u.ap = 0
	busy = false
	_after_action()


## Une trousse de soins : une action
func _use_kit() -> void:
	var u: Dictionary = units[active]
	if busy or Game.stats.kits <= 0:
		return
	Game.stats.kits -= 1
	var h := Data.kit_heal(lvl)
	u.hp = min(u.hpmax, u.hp + h)
	u.ap -= 1
	_update_tag(u)
	_float_text(u.node.position, "+%d" % h, Color(0.5, 1.0, 0.5))
	Audio.play("heal")
	main.combat_hp_changed()
	_after_action()
