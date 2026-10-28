extends Node3D
## Une planète en vue tactique : terrain en diorama, obstacles, lieux à explorer, brouillard de guerre,
## SG-1 qui se déplace en formation, caméra RTS au doigt, porte et DHD (ou anneaux de transport sur Netu).

signal poi_reached(poi: Dictionary)
signal gate_near(near: bool)

const Data = preload("res://scripts/data.gd")
const People = preload("res://scripts/people.gd")
const Props = preload("res://scripts/props.gd")
const GateScript = preload("res://scripts/gate.gd")
const TransportRings = preload("res://scripts/transport_rings.gd")
const Terrain = preload("res://scripts/terrain.gd")

const N := 16
const T := 2.0
const GATE_TILE := Vector2i(2, 2)
const DHD_TILE := Vector2i(4, 1)
const START := Vector2i(4, 4)
const LAIR_TILE := Vector2i(13, 13)
const BOSS_TILE := Vector2i(11, 11)
const FORMATION := [Vector3(0, 0, 0), Vector3(-1.0, 0, -1.0), Vector3(1.0, 0, -1.0), Vector3(-0.9, 0, -2.2), Vector3(0.9, 0, -2.2)]

var idx := 0
var n_tiles := N
var tile_size := T
var combat: Node = null
var data: Dictionary
var rng := RandomNumberGenerator.new()
var grid := AStarGrid2D.new()
var blocked := {}
var tile_nodes := {}          # case -> obstacle
var pois: Array = []          # {tile, k, f, done, node, actors}
var seen := {}
var fog: MeshInstance3D
var ground_mat: ShaderMaterial
var _seen_img: Image
var _seen_tex: ImageTexture
var fog_mat: StandardMaterial3D

var team: Array = []
var leader_tile := START
var path: Array = []
var moving := false
var input_locked := true

var gate: Node3D
var dhd: Node3D
var ring_pad: Node3D

var cam_pivot: Node3D
var cam: Camera3D
var yaw := 225.0
var pitch := 52.0
var dist := 24.0
var _touches := {}
var _touch_seen := false
var _tap_start := Vector2.ZERO
var _tap_moved := false
var _multi := false
var _pinch_d := 0.0
var _pinch_a := 0.0
var _mouse_down := false
var _mouse_turn := false
var _t := 0.0
var fx_node: GPUParticles3D


static func tile_pos(t: Vector2i) -> Vector3:
	return Vector3((t.x - N / 2.0 + 0.5) * T, 0, (t.y - N / 2.0 + 0.5) * T)


static func pos_tile(p: Vector3) -> Vector2i:
	return Vector2i(int(floor(p.x / T + N / 2.0)), int(floor(p.z / T + N / 2.0)))


func setup(planet_index: int, members: Array, seed_value: int) -> void:
	idx = planet_index
	data = Data.PLANETS[idx]
	rng.seed = seed_value
	for attempt in 30:
		if _generate():
			break
	_build_terrain()
	_build_props()
	_build_team(members)
	_build_camera()
	_build_fog()
	_build_fx()
	reveal(START, 3)
	if not data.gate:
		reveal(GATE_TILE, 2)


# ---------- Génération ----------

func _cheb(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))


func _reserved(t: Vector2i) -> bool:
	if t.x <= 3 and t.y <= 3:
		return true
	if _cheb(t, START) <= 1 or t == DHD_TILE:
		return true
	if _cheb(t, LAIR_TILE) <= 2 or _cheb(t, BOSS_TILE) <= 1:
		return true
	return false


func _generate() -> bool:
	blocked.clear()
	pois.clear()
	# La porte (ou la plateforme des anneaux) et le DHD
	if data.gate:
		for t in [GATE_TILE, GATE_TILE + Vector2i(-1, 1), GATE_TILE + Vector2i(1, -1), GATE_TILE + Vector2i(-1, 0), GATE_TILE + Vector2i(0, -1)]:
			blocked[t] = "gate"
		blocked[DHD_TILE] = "dhd"
	# Le repaire du gardien
	for x in range(-1, 2):
		for y in range(-1, 2):
			blocked[LAIR_TILE + Vector2i(x, y)] = "lair"
	# Les lieux : 3 combats, 1 caisse, 1 ruine, 1 allié, 1 piège, et le gardien
	var kinds := ["combat", "combat", "combat", "tresor", "ruines", "allie", "piege"]
	var free := []
	for x in N:
		for y in N:
			var t := Vector2i(x, y)
			if not _reserved(t) and _cheb(t, START) >= 4:
				free.append(t)
	var picked := []
	for k in kinds:
		for tries in 200:
			var t: Vector2i = free[rng.randi() % free.size()]
			var ok := true
			for p in picked:
				if _cheb(p, t) < 3:
					ok = false
			if ok:
				picked.append(t)
				pois.append({"tile": t, "k": k, "f": picked.size() % 2, "done": false})
				break
	pois.append({"tile": BOSS_TILE, "k": "boss", "f": 0, "done": false})
	# Les obstacles
	for x in N:
		for y in N:
			var t := Vector2i(x, y)
			if blocked.has(t) or _reserved(t):
				continue
			var near_poi := false
			for p in pois:
				if _cheb(p.tile, t) <= 1:
					near_poi = true
			if not near_poi and rng.randf() < 0.16:
				blocked[t] = "obj"
	# Tout doit rester accessible
	_setup_grid()
	for p in pois:
		if grid.get_id_path(START, p.tile).is_empty():
			return false
	if data.gate and grid.get_id_path(START, Vector2i(3, 3)).is_empty():
		return false
	return true


func _setup_grid() -> void:
	grid = AStarGrid2D.new()
	grid.region = Rect2i(0, 0, N, N)
	grid.cell_size = Vector2(1, 1)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for t in blocked:
		grid.set_point_solid(t, true)


# ---------- Construction ----------

func _build_terrain() -> void:
	ground_mat = Terrain.build_ground(self, data.n, rng.randi())


func _build_props() -> void:
	for t in blocked:
		var kind: String = blocked[t]
		if kind == "obj":
			var o: Node3D = Terrain.obstacle(data.n, rng)
			if o == null:
				o = Props.obstacle(data.obj, rng.randf())
			o.position = tile_pos(t)
			o.rotation.y = rng.randf() * TAU
			add_child(o)
			tile_nodes[t] = o
	var l := Props.lair(data.lair)
	l.position = tile_pos(LAIR_TILE)
	l.rotation.y = PI / 4.0 + PI
	add_child(l)
	if data.gate:
		gate = GateScript.new()
		gate.scale = Vector3.ONE * 0.62
		gate.position = tile_pos(GATE_TILE) + Vector3(0, GateScript.R_OUT * 0.62 + 0.15, 0)
		gate.rotation.y = PI / 4.0
		add_child(gate)
		var base := MeshInstance3D.new()
		base.mesh = People.box(4.8, 0.3, 1.6)
		base.material_override = People.mat(Color(0.45, 0.42, 0.38), 0.8)
		base.position = tile_pos(GATE_TILE) + Vector3(0, 0.15, 0)
		base.rotation.y = PI / 4.0
		add_child(base)
		dhd = Props.dhd()
		dhd.position = tile_pos(DHD_TILE)
		dhd.rotation.y = -PI / 4.0
		add_child(dhd)
	else:
		ring_pad = TransportRings.new()
		ring_pad.position = tile_pos(Vector2i(3, 3))
		add_child(ring_pad)
	for p in pois:
		_build_poi(p)
	# Les petits décors, hors des cases occupées et loin des lieux à visiter
	var free := []
	for x in N:
		for y in N:
			var t := Vector2i(x, y)
			if blocked.has(t) or (t.x <= 4 and t.y <= 4):
				continue
			var near := false
			for p in pois:
				if _cheb(p.tile, t) <= 1:
					near = true
			if not near:
				free.append(t)
	Terrain.scatter(self, data.n, rng, free, tile_pos)


func _build_poi(p: Dictionary) -> void:
	var node := Node3D.new()
	node.position = tile_pos(p.tile)
	add_child(node)
	p["node"] = node
	p["actors"] = []
	var face := (tile_pos(START) - node.position).normalized()
	var ang := atan2(face.x, face.z)
	match p.k:
		"combat":
			var foe: Dictionary = data.foes[p.f]
			var count: int = 1 if foe.a in ["beast", "swarm"] else 2 + (p.tile.x % 2)
			for i in count:
				var e := People.new()
				e.build(foe.a)
				e.position = Vector3((i - (count - 1) / 2.0) * 1.0, 0, (i % 2) * 0.6)
				e.rotation.y = ang
				node.add_child(e)
				p.actors.append(e)
		"boss":
			var b: Dictionary = data.boss
			var boss := People.new()
			boss.build(b.a)
			boss.scale = Vector3.ONE * 1.25
			boss.rotation.y = ang
			node.add_child(boss)
			p.actors.append(boss)
			for side in [-1, 1]:
				var gd := People.new()
				gd.build(b.guard)
				gd.position = Vector3(side * 1.3, 0, -0.6)
				gd.rotation.y = ang
				node.add_child(gd)
				p.actors.append(gd)
		"tresor":
			node.add_child(Props.crate())
		"ruines":
			node.add_child(Props.ancient())
		"allie":
			node.add_child(Props.question())
		"piege":
			pass


func _build_team(members: Array) -> void:
	for i in members.size():
		var c := People.new()
		c.build(members[i])
		c.position = tile_pos(START) + FORMATION[i].rotated(Vector3.UP, PI / 4.0)
		c.rotation.y = PI / 4.0
		add_child(c)
		team.append(c)


func _build_camera() -> void:
	cam_pivot = Node3D.new()
	cam_pivot.position = tile_pos(START)
	add_child(cam_pivot)
	cam = Camera3D.new()
	cam.fov = 55.0
	cam.far = 300.0
	add_child(cam)
	_update_cam()


func _build_fog() -> void:
	fog_mat = StandardMaterial3D.new()
	fog_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fog_mat.albedo_color = Color(0.02, 0.02, 0.04, 0.82)
	fog_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fog = MeshInstance3D.new()
	fog.material_override = fog_mat
	add_child(fog)


func _build_fx() -> void:
	if data.fx == "":
		return
	fx_node = GPUParticles3D.new()
	fx_node.amount = 400
	fx_node.lifetime = 6.0
	fx_node.preprocess = 6.0
	fx_node.visibility_aabb = AABB(Vector3(-25, -5, -25), Vector3(50, 25, 50))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(18, 0.5, 18)
	if data.fx == "snow":
		pm.direction = Vector3(0.2, -1, 0)
		pm.initial_velocity_min = 1.5
		pm.initial_velocity_max = 2.5
		pm.gravity = Vector3(0, -0.3, 0)
		fx_node.position = Vector3(0, 12, 0)
	else:
		pm.direction = Vector3(0, 1, 0)
		pm.initial_velocity_min = 0.8
		pm.initial_velocity_max = 2.0
		pm.gravity = Vector3(0, 0.4, 0)
		fx_node.position = Vector3(0, 0, 0)
	fx_node.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	# Des flocons et des braises ronds et doux plutôt que des carrés
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 32
	gt.height = 32
	qm.albedo_texture = gt
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.albedo_color = Color(1, 1, 1) if data.fx == "snow" else Color(1.0, 0.5, 0.1)
	if data.fx != "snow":
		qm.emission_enabled = true
		qm.emission = Color(1.0, 0.45, 0.1)
		qm.emission_energy_multiplier = 1.6
		q.size = Vector2(0.05, 0.05)
	q.material = qm
	fx_node.draw_pass_1 = q
	add_child(fx_node)


# ---------- Brouillard de guerre ----------

func reveal(center: Vector2i, r: int) -> void:
	var changed := false
	for x in range(center.x - r, center.x + r + 1):
		for y in range(center.y - r, center.y + r + 1):
			var t := Vector2i(x, y)
			if x < 0 or y < 0 or x >= N or y >= N or seen.has(t):
				continue
			if Vector2(t - center).length() > r + 0.5:
				continue
			seen[t] = true
			changed = true
	if changed:
		_update_fog()


func _update_fog() -> void:
	# Une image de (N+2)² pixels : les cases vues à 1, l'inconnu à 0, le pourtour à demi
	if _seen_img == null:
		_seen_img = Image.create(N + 2, N + 2, false, Image.FORMAT_L8)
		_seen_img.fill(Color(0.55, 0.55, 0.55))
	for x in N:
		for y in N:
			var v := 1.0 if seen.has(Vector2i(x, y)) else 0.0
			_seen_img.set_pixel(x + 1, y + 1, Color(v, v, v))
	if _seen_tex == null:
		_seen_tex = ImageTexture.create_from_image(_seen_img)
		if ground_mat:
			ground_mat.set_shader_parameter("seen_tex", _seen_tex)
	else:
		_seen_tex.update(_seen_img)
	for t in tile_nodes:
		tile_nodes[t].visible = seen.has(t)
	for p in pois:
		if p.node:
			p.node.visible = seen.has(p.tile) or p.k == "boss"


# ---------- Caméra et toucher ----------

func _update_cam() -> void:
	var off := Vector3(sin(deg_to_rad(yaw)), 0, cos(deg_to_rad(yaw))) * dist * cos(deg_to_rad(pitch))
	off.y = dist * sin(deg_to_rad(pitch))
	cam.look_at_from_position(cam_pivot.position + off, cam_pivot.position)


func zoom(f: float) -> void:
	dist = clamp(dist * f, 10.0, 46.0)
	_update_cam()


func turn(deg: float) -> void:
	yaw = fposmod(yaw + deg, 360.0)
	_update_cam()


func recenter() -> void:
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cam_pivot, "position", team[0].position, 0.5)
	tw.parallel().tween_method(func(_v): _update_cam(), 0.0, 1.0, 0.5)


func focus(p: Vector3, seconds: float) -> Tween:
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cam_pivot, "position", p, seconds)
	tw.parallel().tween_method(func(_v): _update_cam(), 0.0, 1.0, seconds)
	return tw


## Le réglage « Vitesse de la caméra » (1.0 = 100 %)
func _cam_speed() -> float:
	return Settings.value("cam_speed") / 100.0


func _pan(rel: Vector2) -> void:
	var right := cam.global_basis.x
	right.y = 0
	var fwd := -cam.global_basis.z
	fwd.y = 0
	var k := dist * 0.0022 * _cam_speed()
	cam_pivot.position -= (right.normalized() * rel.x - fwd.normalized() * rel.y) * k
	var lim := N * T / 2.0 + 4.0
	cam_pivot.position.x = clamp(cam_pivot.position.x, -lim, lim)
	cam_pivot.position.z = clamp(cam_pivot.position.z, -lim, lim)
	_update_cam()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		_touch_seen = true
		if e.pressed:
			_touches[e.index] = e.position
			if _touches.size() == 1:
				_tap_start = e.position
				_tap_moved = false
				_multi = false
			elif _touches.size() == 2:
				_multi = true
				_pinch_start()
		else:
			_touches.erase(e.index)
			if _touches.is_empty() and not _tap_moved and not _multi:
				tap(e.position)
	elif e is InputEventScreenDrag:
		_touches[e.index] = e.position
		if _touches.size() == 1 and not _multi:
			if e.position.distance_to(_tap_start) > 24.0:
				_tap_moved = true
			if _tap_moved:
				_pan(e.relative)
		elif _touches.size() >= 2:
			_pinch_move()
	# Une vraie souris (pas celle que Godot émule à partir du tactile)
	elif e is InputEventMouseButton and e.device != InputEvent.DEVICE_ID_EMULATION:
		if e.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_turn = e.pressed
		elif e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_mouse_down = true
				_tap_start = e.position
				_tap_moved = false
			else:
				_mouse_down = false
				if not _tap_moved:
					tap(e.position)
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
			zoom(0.9)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
			zoom(1.1)
	elif e is InputEventMouseMotion and e.device != InputEvent.DEVICE_ID_EMULATION and _mouse_turn:
		turn(-e.relative.x * 0.3 * _cam_speed())
	elif e is InputEventMouseMotion and e.device != InputEvent.DEVICE_ID_EMULATION and _mouse_down:
		if e.position.distance_to(_tap_start) > 24.0:
			_tap_moved = true
		if _tap_moved:
			_pan(e.relative)


## Clavier : ZQSD / WASD ou flèches pour déplacer, A/E (ou Q/E en QWERTY) pour tourner, +/- pour zoomer
func _keyboard_cam(delta: float) -> void:
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v.y += 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.y -= 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v.x += 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x -= 1
	if v != Vector2.ZERO:
		_pan(v * 900.0 * delta)
	if Input.is_physical_key_pressed(KEY_Q):
		turn(-90.0 * delta * _cam_speed())
	if Input.is_physical_key_pressed(KEY_E):
		turn(90.0 * delta * _cam_speed())
	if Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_KP_ADD) or Input.is_key_pressed(KEY_PLUS):
		zoom(1.0 - 1.2 * delta)
	if Input.is_key_pressed(KEY_MINUS) or Input.is_key_pressed(KEY_KP_SUBTRACT):
		zoom(1.0 + 1.2 * delta)


func _pinch_start() -> void:
	var k := _touches.keys()
	var a: Vector2 = _touches[k[0]]
	var b: Vector2 = _touches[k[1]]
	_pinch_d = a.distance_to(b)
	_pinch_a = (b - a).angle()


func _pinch_move() -> void:
	var k := _touches.keys()
	var a: Vector2 = _touches[k[0]]
	var b: Vector2 = _touches[k[1]]
	var d := a.distance_to(b)
	var ang := (b - a).angle()
	if _pinch_d > 0.0 and d > 0.0:
		dist = clamp(dist * _pinch_d / d, 10.0, 46.0)
	turn(rad_to_deg(ang - _pinch_a))
	_pinch_d = d
	_pinch_a = ang


func tap(screen: Vector2) -> void:
	if input_locked:
		return
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	if abs(d.y) < 0.001:
		return
	var p := o + d * (-o.y / d.y)
	var t := pos_tile(p)
	if t.x < 0 or t.y < 0 or t.x >= N or t.y >= N:
		return
	if combat:
		combat.on_tap(t)
		return
	if blocked.get(t, "") in ["gate", "dhd"] or (not data.gate and _cheb(t, Vector2i(3, 3)) <= 1):
		if _cheb(leader_tile, DHD_TILE if data.gate else Vector2i(3, 3)) <= 2:
			gate_near.emit(true)
			return
		t = Vector2i(4, 3) if data.gate else Vector2i(4, 4)
	if blocked.has(t):
		t = _nearest_free(t)
	walk_to(t)


func _nearest_free(t: Vector2i) -> Vector2i:
	var best := leader_tile
	var bd := 999.0
	for x in range(-2, 3):
		for y in range(-2, 3):
			var c := t + Vector2i(x, y)
			if c.x < 0 or c.y < 0 or c.x >= N or c.y >= N or blocked.has(c):
				continue
			var dd := Vector2(c - t).length() + Vector2(c - leader_tile).length() * 0.01
			if dd < bd:
				bd = dd
				best = c
	return best


# ---------- Déplacement de l'équipe ----------

func walk_to(t: Vector2i) -> void:
	var ids := grid.get_id_path(leader_tile, t)
	if ids.size() < 2:
		return
	path = []
	for i in range(1, ids.size()):
		path.append(ids[i])
	moving = true
	gate_near.emit(false)


func _process(delta: float) -> void:
	_t += delta
	_keyboard_cam(delta)
	for p in pois:
		if p.node and not p.done:
			var gem: Node3D = p.node.find_child("Gem", true, false)
			if gem:
				gem.get_parent().rotation.y += delta * 1.5
				gem.get_parent().position.y = sin(_t * 2.0) * 0.12
	if team.is_empty() or combat:
		return
	var leader: Node3D = team[0]
	if moving and not path.is_empty():
		var target := tile_pos(path[0])
		var to := target - leader.position
		to.y = 0
		var step := 4.2 * delta
		if to.length() <= step:
			leader.position = target
			leader_tile = path.pop_front()
			reveal(leader_tile, 3)
			if _check_arrival():
				path.clear()
				if combat:
					return
		else:
			leader.position += to.normalized() * step
			leader.rotation.y = lerp_angle(leader.rotation.y, atan2(to.x, to.z), min(1.0, delta * 10.0))
		if path.is_empty():
			moving = false
	leader.walking = moving
	# Le reste de l'équipe suit en formation
	for i in range(1, team.size()):
		var m: Node3D = team[i]
		var goal: Vector3 = leader.position + Basis(Vector3.UP, leader.rotation.y) * FORMATION[i]
		var dv := goal - m.position
		dv.y = 0
		if dv.length() > 0.08:
			var sp: float = min(dv.length(), 5.0 * delta * (1.0 + dv.length() * 0.3))
			m.position += dv.normalized() * sp
			m.rotation.y = lerp_angle(m.rotation.y, atan2(dv.x, dv.z), min(1.0, delta * 8.0))
			m.walking = true
		else:
			m.walking = false
			m.rotation.y = lerp_angle(m.rotation.y, leader.rotation.y, min(1.0, delta * 4.0))


func _check_arrival() -> bool:
	for p in pois:
		if p.done:
			continue
		var r := 2 if p.k in ["combat", "boss"] else (1 if p.k == "ruines" else 0)
		if _cheb(p.tile, leader_tile) <= r:
			moving = false
			if p.node and p.k in ["combat", "boss"]:
				for a in p.actors:
					var dv: Vector3 = team[0].position - (p.node.position + a.position)
					a.rotation.y = atan2(dv.x, dv.z)
			poi_reached.emit(p)
			return true
	var home := DHD_TILE if data.gate else Vector2i(3, 3)
	gate_near.emit(_cheb(leader_tile, home) <= 2)
	return false


## Un lieu est réglé : ennemis à terre, objet ramassé, piège déclenché
func resolve(p: Dictionary, won: bool) -> void:
	p.done = won or not (p.k in ["combat", "boss"])
	if not p.done:
		return
	if p.k in ["combat", "boss"]:
		for a in p.actors:
			a.fall()
		var tw := create_tween()
		tw.tween_interval(2.5)
		tw.tween_property(p.node, "scale", Vector3.ONE * 0.01, 0.4)
		tw.tween_callback(p.node.hide)
	elif p.k == "ruines" and p.node and p.node.find_child("AncientControlPanel", true, false):
		p.node.find_child("AncientControlPanel", true, false).activate()
	elif p.node:
		var tw := create_tween()
		tw.tween_property(p.node, "scale", Vector3.ONE * 0.01, 0.35)
		tw.tween_callback(p.node.hide)


## Repli vers la porte après une fuite
func retreat() -> void:
	path.clear()
	moving = false
	leader_tile = START
	for i in team.size():
		team[i].position = tile_pos(START) + FORMATION[i].rotated(Vector3.UP, PI / 4.0)
	focus(tile_pos(START), 0.6)


## Un allié apparaît à la place du marqueur
func show_ally(p: Dictionary, k: String) -> void:
	for c in p.node.get_children():
		c.queue_free()
	var a := People.new()
	a.build(k)
	var dv: Vector3 = team[0].position - p.node.position
	a.rotation.y = atan2(dv.x, dv.z)
	p.node.add_child(a)


# ---------- Arrivée et départ ----------

func arrive() -> void:
	input_locked = true
	# Vue de face sur la porte pendant l'arrivée, puis la caméra pivote vers la carte
	cam_pivot.position = tile_pos(GATE_TILE) + Vector3(2.5, 0, 2.5)
	yaw = 45.0
	dist = 17.0
	_update_cam()
	if data.gate:
		for m in team:
			m.visible = false
		for n in 7:
			gate.light_chevron(n)
		await gate.kawoosh(1.6).finished
		for i in team.size():
			var m: Node3D = team[i]
			m.position = gate.position - Vector3(0, gate.position.y, 0)
			m.rotation.y = PI / 4.0
			m.visible = true
			m.walking = true
			var tw := create_tween()
			tw.tween_property(m, "position", tile_pos(START) + FORMATION[i].rotated(Vector3.UP, PI / 4.0), 1.6)
			tw.tween_callback(func(): m.walking = false)
			await get_tree().create_timer(0.35, false).timeout
		await get_tree().create_timer(1.6, false).timeout
		await gate.shutdown(0.8).finished
	else:
		await _rings(true)
	var tw2 := focus(tile_pos(START) + Vector3(3, 0, 3), 1.6)
	tw2.parallel().tween_method(func(v: float):
		yaw = v
		dist = lerp(17.0, 24.0, (v - 45.0) / 180.0)
		_update_cam(), 45.0, 225.0, 1.6)
	await tw2.finished
	input_locked = false


func leave() -> void:
	input_locked = true
	path.clear()
	moving = false
	gate_near.emit(false)
	if data.gate:
		await focus(tile_pos(Vector2i(3, 3)), 0.8).finished
		var dome: MeshInstance3D = dhd.find_child("Dome", true, false)
		dome.material_override = People.mat(Color(1.0, 0.3, 0.1), 0.2, 0.0, 6.0)
		for n in 7:
			gate.light_chevron(n)
			await get_tree().create_timer(0.3, false).timeout
		await gate.kawoosh(1.6).finished
		for i in team.size():
			var m: Node3D = team[i]
			m.walking = true
			var tw := create_tween()
			tw.tween_property(m, "position", gate.position - Vector3(0, gate.position.y, 0), 1.4)
			tw.tween_callback(m.hide)
			await get_tree().create_timer(0.3, false).timeout
		await get_tree().create_timer(1.5, false).timeout
	else:
		await _rings(false)


## Les anneaux de transport : ils descendent du ciel, éclair, puis remontent
func _rings(arriving: bool) -> void:
	if not is_instance_valid(ring_pad) or not ring_pad.get("available"):
		await _rings_legacy(arriving)
		return
	var center := tile_pos(Vector2i(3, 3))
	if arriving:
		for member in team:
			member.visible = false
	await focus(center, 0.6).finished
	if not arriving:
		for i in team.size():
			team[i].walking = true
			create_tween().tween_property(team[i], "position", center + FORMATION[i] * 0.6, 0.8)
		await get_tree().create_timer(0.9, false).timeout
	for member in team:
		member.walking = false
		member.visible = not arriving
	Audio.play("rings")
	ring_pad.start_transport()
	await get_tree().create_timer(ring_pad.transfer_at, false).timeout
	var flash := OmniLight3D.new()
	flash.position = center + Vector3.UP * 1.5
	flash.light_color = Color(0.65, 0.85, 1.0)
	flash.light_energy = 10.0
	flash.omni_range = 7.0
	add_child(flash)
	for i in team.size():
		team[i].visible = arriving
		if arriving:
			team[i].position = center + FORMATION[i] * 0.6
	await get_tree().create_timer(0.35, false).timeout
	flash.queue_free()
	await ring_pad.player.animation_finished
	if arriving:
		for i in team.size():
			team[i].walking = true
			create_tween().tween_property(team[i], "position", tile_pos(START) + FORMATION[i].rotated(Vector3.UP, PI / 4.0), 1.2)
		await get_tree().create_timer(1.25, false).timeout
		for member in team:
			member.walking = false


func _rings_legacy(arriving: bool) -> void:
	var center := tile_pos(Vector2i(3, 3))
	await focus(center, 0.6).finished
	var rings: Array = []
	for i in 5:
		var r := Props.transport_ring()
		r.position = center + Vector3(0, 14 + i * 0.6, 0)
		add_child(r)
		rings.append(r)
	if not arriving:
		for i in team.size():
			team[i].walking = true
			create_tween().tween_property(team[i], "position", center + FORMATION[i] * 0.6, 0.8)
		await get_tree().create_timer(0.9, false).timeout
		for m in team:
			m.walking = false
	elif arriving:
		for m in team:
			m.visible = false
	Audio.play("rings")
	var tw := create_tween().set_parallel()
	for i in 5:
		tw.tween_property(rings[i], "position:y", 0.3 + i * 0.5, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	var flash := OmniLight3D.new()
	flash.position = center + Vector3(0, 1.5, 0)
	flash.light_energy = 12.0
	flash.omni_range = 10.0
	add_child(flash)
	for i in team.size():
		team[i].visible = arriving
		if arriving:
			team[i].position = center + FORMATION[i] * 0.6
	await get_tree().create_timer(0.35, false).timeout
	flash.queue_free()
	tw = create_tween().set_parallel()
	for i in 5:
		tw.tween_property(rings[i], "position:y", 14 + i * 0.6, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	for r in rings:
		r.queue_free()
	if arriving:
		for i in team.size():
			team[i].walking = true
			create_tween().tween_property(team[i], "position", tile_pos(START) + FORMATION[i].rotated(Vector3.UP, PI / 4.0), 1.2)
		await get_tree().create_timer(1.25, false).timeout
		for m in team:
			m.walking = false


## Un planeur de la mort passe en rase-mottes et mitraille l'équipe
func glider_strafe() -> void:
	var g := Props.glider()
	var target: Vector3 = team[0].position
	var dir := Vector3(1, 0, -0.4).normalized()
	g.position = target - dir * 40 + Vector3(0, 7, 0)
	g.look_at_from_position(g.position, target + dir * 40 + Vector3(0, 7, 0))
	add_child(g)
	var tw := create_tween()
	tw.tween_property(g, "position", target + dir * 40 + Vector3(0, 7, 0), 2.2)
	tw.tween_callback(g.queue_free)
	await get_tree().create_timer(1.0, false).timeout
	for i in 4:
		var boom := MeshInstance3D.new()
		boom.mesh = People.ball(0.6)
		boom.material_override = People.mat(Color(1.0, 0.55, 0.15), 0.5, 0.0, 6.0)
		boom.position = target + Vector3(randf_range(-2.5, 2.5), 0.5, randf_range(-2.5, 2.5))
		add_child(boom)
		var bt := create_tween()
		bt.tween_property(boom, "scale", Vector3.ONE * 3.0, 0.35)
		bt.parallel().tween_property(boom, "transparency", 1.0, 0.35)
		bt.tween_callback(boom.queue_free)
		await get_tree().create_timer(0.12, false).timeout


## Après un combat : l'équipe se regroupe derrière le premier membre debout
func end_combat() -> void:
	combat = null
	leader_tile = pos_tile(team[0].position)
	path.clear()
	moving = false
