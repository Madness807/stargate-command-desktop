extends Node3D
## La salle d'embarquement du SGC, niveau 28 : une salle carrée au fond de l'ancien silo,
## la porte sur son socle, la rampe, la baie vitrée de la salle de contrôle et les gyrophares.

const GATE_Y := 3.95            # centre de la porte (socle de 0,6 m + rayon 3,35 m)

var beacons: Array[OmniLight3D] = []
var beacon_on := false
var _t := 0.0
var _beacon_mat: StandardMaterial3D


func _mat(c: Color, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


# Les boîtes fixes sont regroupées par matériau en un seul maillage chacun :
# quelques appels de dessin au lieu de plusieurs centaines.
var _batches := {}


func _box(size: Vector3, pos: Vector3, mat: Material, rot_x: float = 0.0) -> void:
	var b := BoxMesh.new()
	b.size = size
	if not _batches.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_batches[mat] = st
	_batches[mat].append_from(b, 0, Transform3D(Basis(Vector3.RIGHT, rot_x), pos))


func _flush() -> void:
	for mat in _batches:
		var mi := MeshInstance3D.new()
		mi.mesh = _batches[mat].commit()
		mi.material_override = mat
		add_child(mi)
	_batches.clear()


func _ready() -> void:
	var concrete := _surface("res://assets/sgc/bunker", Color(0.46, 0.48, 0.48), 0.0, 0.34)
	var panel := _surface("res://assets/sgc/bunker", Color(0.41, 0.43, 0.43), 0.0, 0.34)
	var panel_dark := _mat(Color(0.16, 0.18, 0.18), 0.85, 0.15)
	var steel := _surface("res://assets/ground/metal_plate", Color(0.43, 0.45, 0.44), 0.75, 1.1)
	var grate := _surface("res://assets/ground/metal_plate", Color(0.24, 0.26, 0.27), 0.7, 2.0)

	# Sol en béton, avec un quadrillage de joints
	_box(Vector3(26, 0.2, 30), Vector3(0, -0.1, 6), concrete)
	for i in range(-6, 7):
		_box(Vector3(0.04, 0.01, 30), Vector3(i * 2.0, 0.005, 6), panel_dark)
	for j in range(-4, 11):
		_box(Vector3(26, 0.01, 0.04), Vector3(0, 0.005, j * 2.0), panel_dark)

	# Mur du fond, panneaux sur deux niveaux, et murs latéraux
	_box(Vector3(26, 13, 0.4), Vector3(0, 6.5, -3.2), concrete)
	# Grands voiles de béton brut avec joints et piliers, plutôt qu'un damier de panneaux.
	for x in range(-6, 7):
		_box(Vector3(0.025, 12.6, 0.02), Vector3(x * 2.0, 6.4, -2.98), panel_dark)
	for y in [3.2, 6.4, 9.6]:
		_box(Vector3(26, 0.025, 0.025), Vector3(0, y, -2.97), panel_dark)
	for side in [-1, 1]:
		_box(Vector3(0.5, 12.8, 0.65), Vector3(side * 5.2, 6.4, -2.6), panel)
		_box(Vector3(1.5, 2.2, 0.18), Vector3(side * 4.0, 3.0, -2.82), panel_dark)
		for i in 12:
			_box(Vector3(1.35, 0.045, 0.1), Vector3(side * 4.0, 2.0 + i * 0.17, -2.65), steel)

	for side in [-1, 1]:
		_box(Vector3(0.4, 13, 30), Vector3(side * 12.6, 6.5, 6), concrete)
		for z in range(-1, 8):
			_box(Vector3(0.08, 2.8, 1.8), Vector3(side * 12.36, 1.6, z * 2.0), panel_dark)
			_box(Vector3(0.08, 2.8, 1.8), Vector3(side * 12.36, 4.6, z * 2.0), panel)
		# Passerelle de l'étage
		_box(Vector3(2.4, 0.15, 26), Vector3(side * 11.2, 6.6, 6), grate)
		_box(Vector3(0.06, 1.0, 26), Vector3(side * 10.05, 7.2, 6), steel)
	# Plafond sombre et poutres
	_box(Vector3(26, 0.4, 30), Vector3(0, 13, 6), _mat(Color(0.12, 0.12, 0.14)))
	for z in range(-1, 10, 2):
		_box(Vector3(26, 0.5, 0.4), Vector3(0, 12.6, z * 1.5), steel)

	# Socle de la porte
	_box(Vector3(7.6, 0.6, 2.4), Vector3(0, 0.3, 0), _mat(Color(0.3, 0.31, 0.33), 0.6, 0.4))
	_box(Vector3(8.2, 0.12, 2.8), Vector3(0, 0.06, 0), panel_dark)

	# La rampe, en caillebotis, qui descend de la porte vers la salle
	var slope := atan2(0.6, 7.0)
	# Caillebotis ajouré : les barres portent réellement la passerelle.
	for side in [-1, 1]:
		_box(Vector3(0.12, 0.18, 7.2), Vector3(side * 1.6, 0.3, 4.6), panel_dark, slope)
	for i in 18:
		_box(Vector3(3.4, 0.03, 0.05), Vector3(0, 0.66 - i * 0.034, 1.3 + i * 0.4), steel, slope)
	for side in [-1, 1]:
		_box(Vector3(0.07, 0.07, 7.2), Vector3(side * 1.75, 1.35, 4.6), steel, slope)
		for i in 5:
			_box(Vector3(0.06, 1.0, 0.06), Vector3(side * 1.75, 0.85 - i * 0.12, 1.4 + i * 1.6), steel)

	# Caillebotis longitudinal et tubes lumineux intégrés aux garde-corps.
	for i in range(-16, 17):
		_box(Vector3(0.018, 0.025, 7.1), Vector3(i * 0.1, 0.41, 4.6), steel, slope)
	var tube := _emissive(Color(0.78, 0.88, 1.0), 1.6)
	for side in [-1, 1]:
		_box(Vector3(0.08, 0.12, 6.8), Vector3(side * 1.75, 1.39, 4.6), tube, slope)
		# Berceaux mécaniques de la porte, au-dessus des chevrons latéraux.
		_box(Vector3(0.24, 3.8, 0.32), Vector3(side * 3.9, 5.6, -0.65), steel)
		for y in [4.6, 6.25]:
			_box(Vector3(1.15, 0.22, 0.6), Vector3(side * 3.5, y, -0.15), panel_dark)
			_box(Vector3(0.24, 0.48, 0.45), Vector3(side * 3.2, y, -0.50), steel)
		for j in 3:
			_cable(PackedVector3Array([Vector3(side * (3.65 + j * 0.12), 7.2, -0.5), Vector3(side * (4.1 + j * 0.12), 6.4, -0.7), Vector3(side * (4.35 + j * 0.12), 3.5, -0.9), Vector3(side * (4.15 + j * 0.12), 0.4, -0.8)]), panel_dark)
		for z in [4.0]:
			var rail_light := OmniLight3D.new()
			rail_light.position = Vector3(side * 1.8, 1.35, z)
			rail_light.light_color = Color(0.7, 0.82, 1.0)
			rail_light.light_energy = 0.35
			rail_light.omni_range = 3.5
			add_child(rail_light)

	# Traverses de maintenance, conduits et accès blindés du fond de salle.
	var safety := _mat(Color(0.65, 0.46, 0.12), 0.7, 0.1)
	for side in [-1, 1]:
		_box(Vector3(2.5, 3.7, 0.22), Vector3(side * 7.1, 1.9, -2.8), panel_dark)
		for j in 9:
			_box(Vector3(2.12, 0.34, 0.18), Vector3(side * 7.1, 0.4 + j * 0.36, -2.64), steel)
		_box(Vector3(2.7, 0.18, 0.45), Vector3(side * 7.1, 3.75, -2.6), panel)
		_box(Vector3(0.08, 3.35, 0.05), Vector3(side * 8.35, 1.9, -2.4), safety)
		for j in 2:
			_cable(PackedVector3Array([Vector3(side * (5.65 + j * 0.18), 0.3, -2.5), Vector3(side * (5.65 + j * 0.18), 8.5, -2.5), Vector3(side * 3.7, 8.5 + j * 0.18, -2.5)]), steel)
	_box(Vector3(10.6, 0.24, 0.65), Vector3(0, 8.6, -2.45), panel_dark)
	for x in [-4.7, 4.7]:
		_box(Vector3(0.48, 0.18, 0.24), Vector3(x, 6.25, -2.3), tube)
	# Repère de sécurité au pied de la rampe, avec espaces entre les bandes.
	for i in range(-9, 10):
		_box(Vector3(0.18, 0.014, 0.35), Vector3(i * 0.3, 0.012, 8.35), safety)

	# Le mur de la salle de contrôle, face à la porte, avec sa baie vitrée en hauteur
	_box(Vector3(26, 5.9, 0.4), Vector3(0, 2.95, 13.4), concrete)
	_box(Vector3(26, 3.8, 0.4), Vector3(0, 11.1, 13.4), concrete)
	for side in [-1, 1]:
		_box(Vector3(5.6, 3.3, 0.4), Vector3(side * 10.2, 7.55, 13.4), concrete)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.45, 0.65, 0.85, 0.12)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	_box(Vector3(14.8, 3.3, 0.04), Vector3(0, 7.55, 13.25), glass)
	for i in [-3, -2, 2, 3]:
		_box(Vector3(0.14, 3.4, 0.14), Vector3(i * 2.4, 7.55, 13.2), steel)
	_box(Vector3(15, 0.16, 0.2), Vector3(0, 9.2, 13.2), steel)
	_box(Vector3(15, 0.3, 0.5), Vector3(0, 5.95, 13.3), steel)
	# Gyrophares rouges sur le mur du fond
	_beacon_mat = _emissive(Color(1.0, 0.1, 0.05), 0.0)
	for side in [-1, 1]:
		_box(Vector3(0.35, 0.35, 0.35), Vector3(side * 5.2, 7.5, -2.8), _beacon_mat)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.12, 0.05)
		l.light_energy = 0.0
		l.omni_range = 14.0
		l.position = Vector3(side * 5.2, 7.5, -2.2)
		add_child(l)
		beacons.append(l)

	# Éclairage : projecteurs sur la porte et lumière d'ambiance
	for side in [-1, 1]:
		var sp := SpotLight3D.new()
		sp.position = Vector3(side * 6.0, 11.5, 8.0)
		sp.light_energy = 2.8
		sp.spot_range = 22.0
		sp.spot_angle = 32.0
		sp.light_color = Color(1.0, 0.95, 0.85)
		sp.shadow_enabled = false
		add_child(sp)
		sp.look_at(Vector3(0, GATE_Y, 0))
	_flush()
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 9.0, 9.0)
	fill.light_energy = 0.8
	fill.omni_range = 24.0
	fill.light_color = Color(0.75, 0.82, 1.0)
	add_child(fill)


func _surface(prefix: String, tint: Color, metal: float, scale_uv: float) -> StandardMaterial3D:
	var mat := _mat(tint, 0.78, metal)
	mat.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(prefix + "_diff.jpg")))
	mat.normal_enabled = true
	mat.normal_texture = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(prefix + "_nor.jpg")))
	if FileAccess.file_exists(prefix + "_rough.jpg"):
		mat.roughness_texture = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(prefix + "_rough.jpg")))
	mat.normal_scale = 0.45
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * scale_uv
	return mat


func _cable(points: PackedVector3Array, mat: Material) -> void:
	for i in points.size() - 1:
		var axis := points[i + 1] - points[i]
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.045
		mesh.bottom_radius = 0.045
		mesh.height = axis.length()
		mesh.radial_segments = 6
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.position = (points[i] + points[i + 1]) * 0.5
		mi.basis = Basis(Quaternion(Vector3.UP, axis.normalized()))
		add_child(mi)


func _emissive(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


func set_beacons(on: bool) -> void:
	beacon_on = on
	if not on:
		for l in beacons:
			l.light_energy = 0.0
		_beacon_mat.emission_energy_multiplier = 0.0


func _process(delta: float) -> void:
	if beacon_on:
		_t += delta
		var pulse: float = max(0.0, sin(_t * 7.0))
		for l in beacons:
			l.light_energy = 3.0 * pulse
		_beacon_mat.emission_energy_multiplier = 6.0 * pulse
