extends Node3D
## Personnages Quaternius animés et Réplicateurs de TaurWing avec démarche procédurale.
## Les bêtes et Thor conservent leur géométrie simple.

const ReplicatorVisual = preload("res://scripts/replicator_visual.gd")
var _imported_replicators: Array = []

const Cast = preload("res://scripts/cast.gd")

static var _mats := {}

var kind := ""
var walking := false
var legs: Array[Node3D] = []
var arms: Array[Node3D] = []
var body: Node3D
var _phase := 0.0
var anim: AnimationPlayer
var idle_anim := "Idle_Loop"
var _dead := false
var _busy_anim := false


static func mat(c: Color, rough: float = 0.7, metal: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
	var key := "%s/%s/%s/%s" % [c.to_html(), rough, metal, glow]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		m.metallic = metal
		if glow > 0.0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = glow
		_mats[key] = m
	return _mats[key]


func _part(mesh: Mesh, m: Material, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	(parent if parent else body).add_child(mi)
	return mi


static func box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


static func ball(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	return s


static func cyl(r_top: float, r_bot: float, h: float, seg: int = 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


## Construit le personnage. Sortes : oneill, carter, daniel, tealc, jaffa, jaffa2, horus, serpent,
## priest, prisoner, brute, kull, jaffa3, klorel, apophis, heruur, sokar, cinq, anubis, thor, nox, tokra, replic, beast
func build(k: String) -> Node3D:
	kind = k
	if Cast.has(k):
		body = Cast.build(k)
		add_child(body)
		anim = body.get_node("Anim") as AnimationPlayer
		# Les porteurs de lance gardent l'arme prête ; les autres se tiennent au repos
		idle_anim = "Pistol_Idle_Loop" if Cast.SPEC[k][7] in ["staff", "kull"] else ("Idle_FoldArms_Loop" if k == "nox" else "Idle_Loop")
		anim.animation_finished.connect(func(_n):
			_busy_anim = false
			if not _dead:
				anim.play(idle_anim, 0.2))
		anim.play(idle_anim)
		anim.seek(randf() * 1.5)
		return self
	body = Node3D.new()
	add_child(body)
	if k == "replic" or k == "swarm":
		_build_replicator(k == "swarm")
		return self
	if k == "beast":
		_build_beast()
		return self
	if k == "thor":
		_build_thor()
		return self

	var skin := Color(0.91, 0.71, 0.55)
	var top := Color(0.42, 0.48, 0.27)        # treillis vert olive
	var vest := Color(0.25, 0.29, 0.17)
	var pants := Color(0.36, 0.4, 0.23)
	var boots := Color(0.12, 0.12, 0.12)
	var robe := false
	var weapon := "p90"
	match k:
		"tealc":
			skin = Color(0.42, 0.27, 0.19)
		"bratac":
			skin = Color(0.4, 0.27, 0.19)
			top = Color(0.42, 0.3, 0.18)
			vest = Color(0.28, 0.2, 0.12)
			pants = Color(0.3, 0.22, 0.14)
			boots = Color(0.18, 0.12, 0.08)
			weapon = "staff"
		"jaffa", "serpent", "jaffa2", "horus", "brute", "jaffa3", "kull", "prisoner":
			skin = Color(0.48, 0.31, 0.2) if k != "prisoner" else Color(0.75, 0.6, 0.48)
			top = {"jaffa": Color(0.55, 0.57, 0.6), "serpent": Color(0.62, 0.64, 0.68), "jaffa2": Color(0.62, 0.53, 0.32),
				"horus": Color(0.72, 0.58, 0.2), "brute": Color(0.35, 0.12, 0.12), "jaffa3": Color(0.24, 0.24, 0.3),
				"kull": Color(0.1, 0.1, 0.12), "prisoner": Color(0.4, 0.33, 0.25)}[k]
			vest = top.darkened(0.25)
			pants = top.darkened(0.4)
			weapon = "staff" if k != "prisoner" else "club"
		"priest", "klorel", "apophis", "heruur", "sokar", "anubis", "nox", "tokra":
			robe = true
			weapon = "none" if k in ["nox", "tokra", "anubis"] else "hand"
			top = {"priest": Color(0.45, 0.13, 0.12), "klorel": Color(0.18, 0.3, 0.55), "apophis": Color(0.08, 0.08, 0.1),
				"heruur": Color(0.62, 0.47, 0.13), "sokar": Color(0.48, 0.05, 0.05), "anubis": Color(0.05, 0.05, 0.06),
				"nox": Color(0.42, 0.55, 0.3), "tokra": Color(0.4, 0.32, 0.55)}[k]
			vest = Color(0.83, 0.66, 0.2)
			skin = Color(0.62, 0.42, 0.3) if k != "nox" else Color(0.92, 0.82, 0.7)
		"cinq":
			skin = Color(0.88, 0.76, 0.66)
			top = Color(0.38, 0.45, 0.52)
			vest = Color(0.3, 0.75, 0.95)
			pants = Color(0.3, 0.34, 0.4)
			weapon = "none"

	# Jambes, articulées à la hanche
	for side in [-1, 1]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.12, 0.9, 0)
		body.add_child(hip)
		if not robe:
			_part(box(0.19, 0.8, 0.22), mat(pants), Vector3(0, -0.4, 0), hip)
			_part(box(0.21, 0.14, 0.32), mat(boots), Vector3(0, -0.84, 0.05), hip)
		legs.append(hip)
	if robe:
		_part(cyl(0.3, 0.5, 1.15, 12), mat(top), Vector3(0, 0.58, 0))
		_part(box(0.12, 1.0, 0.05), mat(vest, 0.4, 0.6), Vector3(0, 0.75, 0.3))
	# Torse et gilet
	_part(box(0.52, 0.64, 0.3), mat(top), Vector3(0, 1.22, 0))
	_part(box(0.54, 0.38, 0.32), mat(vest, 0.6, 0.3 if robe else 0.0), Vector3(0, 1.3, 0))
	# Bras, articulés à l'épaule
	for side in [-1, 1]:
		var sh := Node3D.new()
		sh.position = Vector3(side * 0.34, 1.5, 0)
		body.add_child(sh)
		_part(box(0.15, 0.6, 0.17), mat(top), Vector3(0, -0.3, 0), sh)
		_part(ball(0.08), mat(skin), Vector3(0, -0.64, 0), sh)
		arms.append(sh)
	# Tête
	var head_y := 1.72
	_part(ball(0.16), mat(skin), Vector3(0, head_y, 0))
	_part(box(0.04, 0.03, 0.02), mat(Color(0.05, 0.05, 0.05)), Vector3(-0.06, head_y + 0.02, 0.15))
	_part(box(0.04, 0.03, 0.02), mat(Color(0.05, 0.05, 0.05)), Vector3(0.06, head_y + 0.02, 0.15))
	match k:
		"oneill":
			_part(cyl(0.17, 0.17, 0.1), mat(Color(0.33, 0.38, 0.2)), Vector3(0, head_y + 0.12, 0))
			_part(box(0.24, 0.03, 0.16), mat(Color(0.3, 0.35, 0.18)), Vector3(0, head_y + 0.08, 0.17))
		"carter":
			_part(ball(0.17), mat(Color(0.92, 0.8, 0.45)), Vector3(0, head_y + 0.05, -0.03))
		"daniel":
			_part(ball(0.17), mat(Color(0.45, 0.3, 0.17)), Vector3(0, head_y + 0.05, -0.04))
			_part(box(0.26, 0.05, 0.02), mat(Color(0.75, 0.88, 0.95), 0.1, 0.5), Vector3(0, head_y + 0.02, 0.16))
		"tealc":
			_part(box(0.07, 0.07, 0.02), mat(Color(0.85, 0.65, 0.15), 0.3, 0.8), Vector3(0, head_y + 0.08, 0.15))
		"bratac":
			# Le tatouage doré, les cheveux ras et la barbe blanche du vieux maître
			_part(box(0.07, 0.07, 0.02), mat(Color(0.85, 0.65, 0.15), 0.3, 0.8), Vector3(0, head_y + 0.08, 0.15))
			var white := mat(Color(0.9, 0.9, 0.86))
			_part(ball(0.165), white, Vector3(0, head_y + 0.04, -0.05))
			_part(box(0.2, 0.16, 0.1), white, Vector3(0, head_y - 0.12, 0.1))
		"jaffa", "jaffa2", "brute", "jaffa3":
			_part(box(0.07, 0.07, 0.02), mat(Color(0.85, 0.65, 0.15), 0.3, 0.8), Vector3(0, head_y + 0.08, 0.15))
		"serpent":
			_part(cyl(0.12, 0.2, 0.42), mat(top, 0.3, 0.8), Vector3(0, head_y + 0.12, 0))
			_part(box(0.1, 0.1, 0.36), mat(top, 0.3, 0.8), Vector3(0, head_y + 0.3, 0.1))
			_part(ball(0.035), mat(Color(1.0, 0.65, 0.1), 0.3, 0.0, 4.0), Vector3(-0.07, head_y + 0.05, 0.17))
			_part(ball(0.035), mat(Color(1.0, 0.65, 0.1), 0.3, 0.0, 4.0), Vector3(0.07, head_y + 0.05, 0.17))
		"horus":
			_part(cyl(0.12, 0.2, 0.42), mat(top, 0.3, 0.8), Vector3(0, head_y + 0.12, 0))
			_part(box(0.08, 0.06, 0.3), mat(top, 0.3, 0.8), Vector3(0, head_y + 0.05, 0.25))
			_part(ball(0.035), mat(Color(1.0, 0.65, 0.1), 0.3, 0.0, 4.0), Vector3(-0.07, head_y + 0.08, 0.17))
			_part(ball(0.035), mat(Color(1.0, 0.65, 0.1), 0.3, 0.0, 4.0), Vector3(0.07, head_y + 0.08, 0.17))
		"kull":
			_part(ball(0.19), mat(top, 0.3, 0.6), Vector3(0, head_y + 0.02, 0))
			_part(box(0.28, 0.05, 0.04), mat(Color(1.0, 0.15, 0.1), 0.3, 0.0, 5.0), Vector3(0, head_y + 0.03, 0.17))
		"prisoner":
			_part(ball(0.17), mat(Color(0.3, 0.22, 0.15)), Vector3(0, head_y + 0.04, -0.03))
		"klorel", "apophis", "heruur", "sokar", "priest":
			_part(cyl(0.2, 0.16, 0.18), mat(Color(0.85, 0.66, 0.2), 0.3, 0.8), Vector3(0, head_y + 0.16, 0))
			_part(ball(0.03), mat(Color(1.0, 0.8, 0.3), 0.3, 0.0, 6.0), Vector3(-0.06, head_y + 0.02, 0.15))
			_part(ball(0.03), mat(Color(1.0, 0.8, 0.3), 0.3, 0.0, 6.0), Vector3(0.06, head_y + 0.02, 0.15))
		"anubis":
			_part(cyl(0.12, 0.26, 0.55), mat(top), Vector3(0, head_y + 0.05, -0.02))
			_part(ball(0.035), mat(Color(1.0, 0.1, 0.05), 0.3, 0.0, 6.0), Vector3(-0.06, head_y, 0.15))
			_part(ball(0.035), mat(Color(1.0, 0.1, 0.05), 0.3, 0.0, 6.0), Vector3(0.06, head_y, 0.15))
		"cinq":
			_part(ball(0.165), mat(Color(0.2, 0.18, 0.16)), Vector3(0, head_y + 0.05, -0.03))
		"nox":
			_part(ball(0.18), mat(Color(0.85, 0.8, 0.6)), Vector3(0, head_y + 0.05, -0.04))
		"tokra":
			_part(ball(0.17), mat(Color(0.35, 0.25, 0.18)), Vector3(0, head_y + 0.05, -0.04))

	# Arme, dans la main droite
	var hand: Node3D = arms[1]
	match weapon:
		"p90":
			_part(box(0.09, 0.13, 0.48), mat(Color(0.16, 0.16, 0.17), 0.5, 0.3), Vector3(0, -0.6, 0.2), hand)
		"staff":
			var s := _part(cyl(0.025, 0.025, 2.0, 6), mat(Color(0.55, 0.45, 0.28), 0.4, 0.6), Vector3(0, -0.55, 0.12), hand)
			s.rotation.x = 0.15
			_part(ball(0.06), mat(Color(0.85, 0.7, 0.3), 0.3, 0.8), Vector3(0, 0.45, 0.27), hand)
		"club":
			_part(cyl(0.04, 0.05, 0.7, 6), mat(Color(0.35, 0.25, 0.15)), Vector3(0, -0.8, 0.1), hand)
		"hand":
			_part(ball(0.06), mat(Color(0.95, 0.75, 0.3), 0.3, 0.0, 3.0), Vector3(0, -0.66, 0.08), hand)
	return self


func _build_replicator(swarm: bool) -> void:
	var count_imported := 4 if swarm else 1
	for n in count_imported:
		var model := ReplicatorVisual.new()
		if not model.setup(0.67 if swarm else 1.15):
			model.free()
			break
		model.position = Vector3((n % 2) * 0.72 - 0.36, 0, (n / 2) * 0.72 - 0.36) if swarm else Vector3.ZERO
		body.add_child(model)
		_imported_replicators.append(model)
	if not _imported_replicators.is_empty():
		return
	var m := mat(Color(0.55, 0.6, 0.66), 0.35, 0.8)
	var count := 4 if swarm else 1
	for n in count:
		var o := Vector3((n % 2) * 0.7 - 0.35, 0, (n / 2) * 0.7 - 0.35) if swarm else Vector3.ZERO
		_part(box(0.5, 0.22, 0.6), m, o + Vector3(0, 0.38, 0))
		_part(ball(0.05), mat(Color(0.3, 0.8, 1.0), 0.3, 0.0, 5.0), o + Vector3(-0.1, 0.45, 0.3))
		_part(ball(0.05), mat(Color(0.3, 0.8, 1.0), 0.3, 0.0, 5.0), o + Vector3(0.1, 0.45, 0.3))
		for i in 6:
			var side := -1 if i < 3 else 1
			var leg := _part(box(0.04, 0.4, 0.04), m, o + Vector3(side * 0.32, 0.2, (i % 3) * 0.22 - 0.22))
			leg.rotation.z = side * 0.6
			legs.append(leg)


func _build_beast() -> void:
	var fur := mat(Color(0.5, 0.38, 0.26))
	_part(box(0.7, 0.7, 1.5), fur, Vector3(0, 1.1, 0))
	_part(box(0.5, 0.5, 0.6), fur, Vector3(0, 1.35, 0.9))
	_part(box(0.12, 0.25, 0.12), mat(Color(0.9, 0.85, 0.7)), Vector3(-0.15, 1.2, 1.2))
	for p in [Vector3(-0.25, 0, 0.5), Vector3(0.25, 0, 0.5), Vector3(-0.25, 0, -0.5), Vector3(0.25, 0, -0.5)]:
		var hip := Node3D.new()
		hip.position = p + Vector3(0, 0.8, 0)
		body.add_child(hip)
		_part(box(0.18, 0.8, 0.18), fur, Vector3(0, -0.4, 0), hip)
		legs.append(hip)


func _build_thor() -> void:
	var grey := mat(Color(0.72, 0.75, 0.78), 0.5)
	_part(box(0.3, 0.5, 0.2), grey, Vector3(0, 0.75, 0))
	_part(cyl(0.05, 0.05, 0.5, 6), grey, Vector3(-0.08, 0.25, 0))
	_part(cyl(0.05, 0.05, 0.5, 6), grey, Vector3(0.08, 0.25, 0))
	_part(ball(0.3), grey, Vector3(0, 1.25, 0))
	_part(ball(0.08), mat(Color(0.02, 0.02, 0.02), 0.1), Vector3(-0.11, 1.27, 0.24))
	_part(ball(0.08), mat(Color(0.02, 0.02, 0.02), 0.1), Vector3(0.11, 1.27, 0.24))


func _process(delta: float) -> void:
	if not _imported_replicators.is_empty():
		for model in _imported_replicators:
			model.walking = walking and not _dead
			model.dead = _dead
		return
	if anim:
		if _dead or _busy_anim:
			return
		var want := "Walk_Loop" if walking else idle_anim
		if anim.current_animation != want:
			anim.play(want, 0.2)
		return
	if walking:
		_phase += delta * 9.0
	else:
		_phase = lerp(_phase, round(_phase / PI) * PI, min(1.0, delta * 10.0))
	var s := sin(_phase)
	for i in legs.size():
		legs[i].rotation.x = s * 0.55 * (1 if i % 2 == 0 else -1)
	for i in arms.size():
		arms[i].rotation.x = -s * 0.45 * (1 if i % 2 == 0 else -1)
	if body:
		body.position.y = abs(s) * 0.05


## Tombe à la renverse, vaincu
func fall() -> void:
	walking = false
	_dead = true
	if anim:
		_dead = true
		anim.play("Death01", 0.15)
		return
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "rotation:x", -PI / 2.0, 0.6)
	tw.tween_property(self, "scale", Vector3(1, 1, 1) * 0.98, 0.1)


## Une action jouée une fois, puis retour au repos (tir, impact, lancer, coup de lance…)
func act(name: String) -> void:
	if not anim or _dead or not anim.has_animation(name):
		return
	_busy_anim = true
	anim.play(name, 0.1)


func shoot() -> void:
	act("Spell_Simple_Shoot" if kind in ["klorel", "apophis", "heruur", "sokar", "priest", "anubis"] else "Pistol_Shoot")


func hurt() -> void:
	act("Hit_Chest")
