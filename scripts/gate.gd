class_name Stargate
extends Node3D
## Porte de la Voie lactée : modèle d'Anquietas System et géométrie de secours.
## Anneau extérieur fixe, anneau intérieur gravé des 39 glyphes qui tourne,
## 9 chevrons, horizon des événements (shader du kawoosh) et iris.

const R_HORIZON := 2.50      # bord de l'horizon des événements
const R_LIP := 2.58          # lèvre intérieure
const R_TRACK_OUT := 2.96    # bord extérieur de l'anneau des glyphes
const R_OUT := 3.35          # bord extérieur de la porte
const GLYPH_R := 2.82        # rayon où sont gravés les glyphes
const HALF_DEPTH := 0.615
# Ordre d'allumage des chevrons pour une adresse à 7 symboles : 1-3 à droite, 4-6 à gauche, 7 en haut
const LOCK_ORDER := [1, 2, 3, 6, 7, 8, 0]

var inner: Node3D
var ring_angle := 0.0                 # degrés, 0 = point d'origine (glyphe 1) en haut
var chevron_lights: Array[MeshInstance3D] = []
var chevron_lit_mat: StandardMaterial3D
var chevron_off_mat: StandardMaterial3D
var chevron_bodies: Array[Node3D] = []
var chevron_mechanisms: Array[Array] = []
var chevron_amounts: Array[float] = []
var _iris_amount := 0.0
var _iris_tween: Tween
var master: Node3D                    # référence de compatibilité au chevron supérieur
var horizon_mat: ShaderMaterial
var iris_pivots: Array[Node3D] = []
var iris_closed := true
var chevron_glow: OmniLight3D

var horizon_glow: OmniLight3D
var _surface_clock := 0.0
var _openness := 0.0

var imported_model: Node3D
var _imported_morphs: Array[MeshInstance3D] = []
const ImportedGate = preload("res://scripts/imported_gate.gd")

var _metal: StandardMaterial3D
var _dark: StandardMaterial3D


func _ready() -> void:
	if _build_imported():
		_build_horizon()
		_build_iris()
		return
	_metal = StandardMaterial3D.new()
	_metal.albedo_color = Color(0.32, 0.35, 0.37)
	_metal.metallic = 0.55
	_metal.roughness = 0.58
	_metal.normal_enabled = true
	_metal.normal_scale = 0.18
	_metal.normal_texture = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path("res://assets/ground/metal_plate_nor.jpg")))
	_metal.uv1_triplanar = true
	_metal.uv1_scale = Vector3.ONE * 1.5
	_metal.cull_mode = BaseMaterial3D.CULL_DISABLED
	_dark = StandardMaterial3D.new()
	_dark.albedo_color = Color(0.075, 0.09, 0.10)
	_dark.metallic = 0.6
	_dark.roughness = 0.55
	_dark.cull_mode = BaseMaterial3D.CULL_DISABLED

	_build_frame()
	_build_inner_ring()
	_build_chevrons()
	_build_horizon()
	_build_iris()


func _build_imported() -> bool:
	var result := ImportedGate.attach(self, R_OUT)
	if result.is_empty():
		return false
	imported_model = result.visual
	inner = result.inner
	chevron_lights.assign(result.lights)
	_imported_morphs.assign(result.morphs)
	chevron_mechanisms.assign(result.mechanisms)
	chevron_amounts.assign([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	master = Node3D.new()
	master.name = "MasterChevronMechanism"
	add_child(master)
	chevron_off_mat = StandardMaterial3D.new()
	chevron_off_mat.albedo_color = Color(0.10, 0.035, 0.005)
	chevron_off_mat.roughness = 0.75
	chevron_lit_mat = StandardMaterial3D.new()
	chevron_lit_mat.albedo_color = Color(0.95, 0.32, 0.025)
	chevron_lit_mat.emission_enabled = true
	chevron_lit_mat.emission = Color(1.0, 0.23, 0.008)
	chevron_lit_mat.emission_energy_multiplier = 1.6
	for light in chevron_lights:
		light.material_override = chevron_off_mat
	chevron_glow = OmniLight3D.new()
	chevron_glow.light_color = Color(1.0, 0.45, 0.12)
	chevron_glow.omni_range = 8.0
	chevron_glow.light_energy = 0.0
	chevron_glow.position.z = 1.0
	add_child(chevron_glow)
	return true


func reset_mechanism() -> void:
	for i in 9:
		_set_chevron_amount(0.0, i)


func _set_master_amount(amount: float) -> void:
	_set_chevron_amount(amount, 0)


func _set_chevron_amount(amount: float, index: int) -> void:
	chevron_amounts[index] = amount
	if not chevron_mechanisms.is_empty():
		for mesh in chevron_mechanisms[index]:
			if mesh.mesh.get_blend_shape_count() > 0:
				mesh.set_blend_shape_value(0, amount)
			if mesh.has_meta("lock_travel"):
				mesh.position = mesh.get_meta("rest_position") + mesh.get_meta("lock_travel") * amount
	else:
		chevron_bodies[index].position.y = -0.14 * amount
	if index == 0 and imported_model != null:
		master.position.y = -0.14 * amount


# ---------- Géométrie ----------

static func _pt(r: float, a: float, z: float) -> Vector3:
	return Vector3(sin(a) * r, cos(a) * r, z)


static func _quad(st: SurfaceTool, v: Array, n: Vector3, uv: Array) -> void:
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_normal(n)
		st.set_uv(uv[idx])
		st.add_vertex(v[idx])


## Un anneau épais : faces avant et arrière, parois intérieure et extérieure.
## Si uv_s > 0, la face avant reçoit des UV planes (texture centrée, demi-largeur uv_s).
static func ring_mesh(r0: float, r1: float, zf: float, zb: float, seg: int, uv_s: float = 0.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var f := [_pt(r0, a0, zf), _pt(r1, a0, zf), _pt(r1, a1, zf), _pt(r0, a1, zf)]
		var fuv := []
		for p in f:
			fuv.append(Vector2(p.x / (2.0 * uv_s) + 0.5, 0.5 - p.y / (2.0 * uv_s)) if uv_s > 0.0 else Vector2.ZERO)
		_quad(st, f, Vector3(0, 0, 1), fuv)
		var b := [_pt(r0, a1, zb), _pt(r1, a1, zb), _pt(r1, a0, zb), _pt(r0, a0, zb)]
		_quad(st, b, Vector3(0, 0, -1), [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
		var am := (a0 + a1) / 2.0
		var o := [_pt(r1, a0, zf), _pt(r1, a0, zb), _pt(r1, a1, zb), _pt(r1, a1, zf)]
		_quad(st, o, Vector3(sin(am), cos(am), 0), [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
		var n := [_pt(r0, a1, zf), _pt(r0, a1, zb), _pt(r0, a0, zb), _pt(r0, a0, zf)]
		_quad(st, n, Vector3(-sin(am), -cos(am), 0), [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	return st.commit()


func _mesh(m: Mesh, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _build_frame() -> void:
	# Lèvre intérieure, bande extérieure et plaque arrière
	_mesh(ring_mesh(R_HORIZON, R_LIP, HALF_DEPTH, -HALF_DEPTH, 160), _metal)
	_mesh(ring_mesh(R_TRACK_OUT, R_OUT, HALF_DEPTH, -HALF_DEPTH, 160), _metal)
	_mesh(ring_mesh(R_LIP, R_TRACK_OUT, -0.12, -HALF_DEPTH, 160), _dark)
	# Lèvres usinées et cannelures radiales, regroupées par matériau.
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color(0.44, 0.47, 0.48)
	trim.metallic = 0.65
	trim.roughness = 0.46
	for band in [[2.505, 2.535], [2.56, 2.59], [2.955, 2.99], [3.08, 3.105], [3.30, 3.35]]:
		_mesh(ring_mesh(band[0], band[1], HALF_DEPTH + 0.025, HALF_DEPTH - 0.01, 156), trim)
	# Gorges du profil, lisibles de trois quarts sur l'épaisseur de l'anneau.
	for z in [-0.50, -0.26, 0.0, 0.26, 0.50]:
		_mesh(ring_mesh(R_OUT - 0.035, R_OUT + 0.008, z + 0.018, z - 0.018, 156), trim)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 156:
		var a := TAU * (i + 0.5) / 156.0
		st.append_from(_box(Vector3(0.010, 0.17, 0.018)), 0,
			Transform3D(Basis(Vector3.BACK, -a), _pt(3.20, a, HALF_DEPTH + 0.008)))
	for i in 39:
		var a := TAU * i / 39.0
		st.append_from(_box(Vector3(0.045, 0.075, 0.06)), 0,
			Transform3D(Basis(Vector3.BACK, -a), _pt(3.035, a, HALF_DEPTH + 0.02)))
	for i in 312:
		var a := TAU * i / 312.0
		st.append_from(_box(Vector3(0.012, 0.045, 0.03)), 0, Transform3D(Basis(Vector3.BACK, -a), _pt(2.555, a, HALF_DEPTH + 0.025)))
	# Nervures obliques de la bande extérieure : motif tressé, pas des trous noirs.
	for i in 156:
		var a := TAU * i / 156.0
		for tilt in [-0.32, 0.32]:
			st.append_from(_box(Vector3(0.012, 0.14, 0.022)), 0, Transform3D(Basis(Vector3.BACK, -a + tilt), _pt(3.20, a, HALF_DEPTH + 0.035)))

	_mesh(st.commit(), _dark)


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _build_inner_ring() -> void:
	inner = Node3D.new()
	add_child(inner)
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/glyph_ring.png"))
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/glyph_ring.gdshader")
	mat.set_shader_parameter("glyph_atlas", ImageTexture.create_from_image(img))
	# La texture : rayon des glyphes = 0,787 de la demi-largeur
	_mesh(ring_mesh(R_LIP, R_TRACK_OUT, HALF_DEPTH - 0.055, -HALF_DEPTH + 0.1, 195, GLYPH_R / 0.787), mat, inner)
	# Séparations entre les 39 glyphes
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 39:
		var a := TAU * (i + 0.5) / 39.0
		st.append_from(_box(Vector3(0.03, R_TRACK_OUT - R_LIP, 0.05)), 0,
			Transform3D(Basis(Vector3.BACK, -a), _pt((R_LIP + R_TRACK_OUT) / 2.0, a, HALF_DEPTH - 0.045)))
	_mesh(st.commit(), _dark, inner)


## Extrusion d'une silhouette concave ; conserve la découpe centrale du chevron.
static func _extrude(points: PackedVector2Array, back: float, front: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	var indices := Geometry2D.triangulate_polygon(points)
	for i in range(0, indices.size(), 3):
		for index in [indices[i + 2], indices[i + 1], indices[i]]:
			st.set_normal(Vector3.BACK)
			st.add_vertex(Vector3(points[index].x, points[index].y, front))
		for index in [indices[i], indices[i + 1], indices[i + 2]]:
			st.set_normal(Vector3.FORWARD)
			st.add_vertex(Vector3(points[index].x, points[index].y, back))
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var normal := Vector3(b.y - a.y, a.x - b.x, 0).normalized()
		_quad(st, [Vector3(a.x, a.y, front), Vector3(b.x, b.y, front), Vector3(b.x, b.y, back), Vector3(a.x, a.y, back)], normal, [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	# Tous les éléments regroupés doivent être indexés, y compris les faces planes.
	st.index()
	return st.commit()


func _build_chevrons() -> void:
	chevron_lit_mat = StandardMaterial3D.new()
	chevron_lit_mat.albedo_color = Color(0.92, 0.35, 0.035)
	chevron_lit_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	chevron_lit_mat.emission_enabled = true
	chevron_lit_mat.emission = Color(1.0, 0.28, 0.015)
	chevron_lit_mat.emission_energy_multiplier = 1.6
	chevron_off_mat = StandardMaterial3D.new()
	chevron_off_mat.albedo_color = Color(0.16, 0.065, 0.02)
	chevron_off_mat.roughness = 0.4
	chevron_off_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in 9:
		var a := TAU * i / 9.0
		var holder := Node3D.new()
		holder.position = _pt(R_OUT - 0.26, a, 0.0)
		holder.rotation.z = -a
		add_child(holder)
		var body := Node3D.new()
		holder.add_child(body)
		# Références fournies : cœur triangulaire plein, trois cadres en retrait,
		# ailettes orange latérales et silhouette contenue dans le diamètre extérieur.
		var outline := PackedVector2Array([Vector2(-0.34, 0.255), Vector2(0.34, 0.255), Vector2(0.12, -0.39), Vector2(0.065, -0.47), Vector2(-0.065, -0.47), Vector2(-0.12, -0.39)])
		var shell := _mesh(_extrude(outline, HALF_DEPTH - 0.18, HALF_DEPTH + 0.10), _metal, body)
		shell.name = "ChevronHousing"
		var recess := PackedVector2Array([Vector2(-0.285, 0.24), Vector2(0.285, 0.24), Vector2(0.075, -0.36), Vector2(-0.075, -0.36)])
		_mesh(_extrude(recess, HALF_DEPTH + 0.10, HALF_DEPTH + 0.115), _dark, body)
		var rim := PackedVector2Array([Vector2(-0.255, 0.235), Vector2(-0.215, 0.235), Vector2(0, -0.275), Vector2(0.215, 0.235), Vector2(0.255, 0.235), Vector2(0, -0.35)])
		_mesh(_extrude(rim, HALF_DEPTH + 0.12, HALF_DEPTH + 0.16), _metal, body)
		var luminous := PackedVector2Array([Vector2(-0.185, 0.225), Vector2(0.185, 0.225), Vector2(0, -0.235)])
		var glow_mesh := SurfaceTool.new()
		glow_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Le cœur est posé devant le cadre ; les ailettes restent en retrait.
		var triangle := _extrude(luminous, HALF_DEPTH + 0.18, HALF_DEPTH + 0.20)
		var ribs := SurfaceTool.new()
		ribs.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side in [-1, 1]:
			for j in 7:
				var y := 0.16 - j * 0.064
				var x: float = side * (0.33 - j * 0.017)
				glow_mesh.append_from(_box(Vector3(0.13, 0.021, 0.025)), 0, Transform3D(Basis.IDENTITY, Vector3(x, y, HALF_DEPTH + 0.055)))
				ribs.append_from(_box(Vector3(0.16, 0.022, 0.09)), 0, Transform3D(Basis.IDENTITY, Vector3(x, y - 0.023, HALF_DEPTH + 0.06)))
		glow_mesh.append_from(triangle, 0, Transform3D.IDENTITY)
		var light := _mesh(glow_mesh.commit(), chevron_off_mat, body)
		_mesh(ribs.commit(), _dark, body)

		chevron_lights.append(light)
		chevron_bodies.append(body)
		chevron_amounts.append(0.0)
		if i == 0:
			master = body
	chevron_glow = OmniLight3D.new()
	chevron_glow.light_color = Color(1.0, 0.55, 0.25)
	chevron_glow.light_energy = 0.0
	chevron_glow.omni_range = 9.0
	chevron_glow.position = Vector3(0, 0, 1.5)
	add_child(chevron_glow)


func _build_horizon() -> void:
	# Un disque finement maillé : le shader le déforme pour le kawoosh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 36
	var segs := 96
	for ri in rings:
		var r0 := R_HORIZON * ri / rings
		var r1 := R_HORIZON * (ri + 1) / rings
		for si in segs:
			var a0 := TAU * si / segs
			var a1 := TAU * (si + 1) / segs
			var v := [_pt(r0, a0, 0), _pt(r1, a0, 0), _pt(r1, a1, 0), _pt(r0, a1, 0)]
			var uv := []
			for p in v:
				uv.append(Vector2(p.x / (2.0 * R_HORIZON) + 0.5, 0.5 - p.y / (2.0 * R_HORIZON)))
			_quad(st, v, Vector3(0, 0, 1), uv)
	var mesh := st.commit()
	horizon_mat = ShaderMaterial.new()
	horizon_mat.shader = load("res://shaders/horizon.gdshader")
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.noise = noise
	horizon_mat.set_shader_parameter("water_noise", texture)
	horizon_glow = OmniLight3D.new()
	horizon_glow.position = Vector3(0, 0, 1.4)
	horizon_glow.light_color = Color(0.3, 0.58, 1.0)
	horizon_glow.omni_range = 11.0
	horizon_glow.light_energy = 0.0
	add_child(horizon_glow)
	var mi := _mesh(mesh, horizon_mat)
	mi.extra_cull_margin = 8.0
	set_horizon(0.0, 0.0)


func _build_iris() -> void:
	# Profil en feuille, courbé en spirale. Les lames dépassent légèrement
	# le centre pour fermer sans trou et se rangent derrière la couronne.
	var outline := PackedVector2Array()
	for side in [0, 1]:
		for j in 33:
			var t := float(j if side == 0 else 32 - j) / 32.0
			var radius := lerpf(0.0, R_HORIZON + 0.22, t)
			var angle := 0.48 * (1.0 - t) + (-0.035 if side == 0 else TAU / 20.0 + 0.045)
			var point := Vector2(sin(angle), cos(angle)) * radius
			outline.append(point - Vector2(0, R_HORIZON + 0.10))
	var blade_mesh := _extrude(outline, -0.008, 0.008)
	for i in 20:
		var a := TAU * i / 20.0
		var pivot := Node3D.new()
		pivot.name = "IrisBlade%02d" % i
		pivot.position = _pt(R_HORIZON + 0.10, a, 0.25 + 0.0015 * i)
		add_child(pivot)
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/iris.gdshader")
		mat.set_shader_parameter("shade", 0.43 + 0.025 * (i % 3))
		_mesh(blade_mesh, mat, pivot)
		iris_pivots.append(pivot)
		pivot.set_meta("angle", a)
	_place_iris(0.0)
	_set_iris_visible(false)
	iris_closed = false


# ---------- Commandes ----------

## Tourne l'anneau pour amener le glyphe g (1-39) sous le chevron du haut.
## dir = 1 sens horaire, -1 antihoraire. Retourne le tween à attendre.
func spin_to(g: int, dir: int, seconds_per_turn: float = 4.0) -> Tween:
	var want := fposmod(-(g - 1) * 360.0 / 39.0, 360.0)
	var cur := fposmod(ring_angle, 360.0)
	var delta := fposmod(want - cur, 360.0) if dir > 0 else -fposmod(cur - want, 360.0)
	if abs(delta) < 30.0:
		delta += 360.0 * dir
	var target := ring_angle + delta
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(_set_ring, ring_angle, target, max(0.9, abs(delta) / 360.0 * seconds_per_turn))
	return tw


func _set_ring(deg: float) -> void:
	ring_angle = deg
	inner.rotation.z = deg_to_rad(-deg)


## Course, verrouillage lumineux et retour mécanique du chevron du symbole.
func engage_chevron(n: int) -> Tween:
	var index: int = LOCK_ORDER[n]
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_method(_set_chevron_amount.bind(index), chevron_amounts[index], 1.0, 0.22)
	tw.tween_callback(func(): light_chevron(n))
	tw.tween_interval(0.35)
	tw.tween_method(_set_chevron_amount.bind(index), 1.0, 0.0, 0.25)
	return tw


func engage_master() -> Tween:
	return engage_chevron(6)


## Allume le chevron de rang n (0 à 6).
func light_chevron(n: int) -> void:
	chevron_lights[LOCK_ORDER[n]].material_override = chevron_lit_mat
	if n < 6:
		chevron_lights[0].material_override = chevron_off_mat
	chevron_glow.light_energy = 0.3 + 0.25 * (n + 1)


func reset_chevrons() -> void:
	reset_mechanism()
	for l in chevron_lights:
		l.material_override = chevron_off_mat
	chevron_glow.light_energy = 0.0


## kaw : 0 à 1 le long du kawoosh ; open : 0 fermé à 1 vortex stable.
func set_horizon(kaw: float, open: float) -> void:
	_openness = maxf(open, sin(kaw * PI) * 1.8)
	horizon_mat.set_shader_parameter("kaw", kaw)
	horizon_mat.set_shader_parameter("open", open)


func set_ripple(v: float) -> void:
	horizon_mat.set_shader_parameter("ripple", v)


func kawoosh(duration: float = 1.8, blocked: bool = false) -> Tween:
	horizon_mat.set_shader_parameter("burst", 0.0 if blocked else 1.0)
	var tw := create_tween()
	tw.tween_method(func(k): set_horizon(k, clamp(k * 6.0, 0.0, 1.0)), 0.0, 1.0, duration)
	return tw


func shutdown(duration: float = 0.9) -> Tween:
	var tw := create_tween()
	tw.tween_method(func(o): set_horizon(0.0, o), 1.0, 0.0, duration)
	tw.tween_callback(reset_chevrons)
	return tw


func _place_iris(closed_amount: float) -> void:
	_iris_amount = closed_amount
	for p in iris_pivots:
		var a: float = p.get_meta("angle")
		# Fermé : la lame pointe vers le centre, en biais ; ouvert : elle se range le long du bord
		var turn := deg_to_rad(lerpf(100.0, 0.0, closed_amount))
		p.rotation.z = -a + turn
		(p.get_child(0).material_override as ShaderMaterial).set_shader_parameter("turn", turn)


func _set_iris_visible(v: bool) -> void:
	for p in iris_pivots:
		p.visible = v


func set_iris(closed: bool, duration: float = 0.8) -> Tween:
	iris_closed = closed
	if _iris_tween and _iris_tween.is_valid():
		_iris_tween.kill()
	_set_iris_visible(true)
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_iris_tween = tw
	tw.tween_method(_place_iris, _iris_amount, 1.0 if closed else 0.0, duration)
	if not closed:
		tw.tween_callback(func(): _set_iris_visible(false))
	return tw


func _process(delta: float) -> void:
	_surface_clock += delta
	if is_instance_valid(horizon_glow):
		horizon_glow.light_energy = _openness * (1.3 + sin(_surface_clock * 1.4) * 0.12 + sin(_surface_clock * 3.1) * 0.06)
