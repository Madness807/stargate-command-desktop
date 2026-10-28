extends RefCounted
## Décors et objets des planètes, construits en formes simples.

const P = preload("res://scripts/people.gd")


static func _mi(mesh: Mesh, m: Material, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


## Obstacle d'une case, selon la planète : rock, tree, pine, lava, block, column
static func obstacle(kind: String, rnd: float) -> Node3D:
	var n := Node3D.new()
	match kind:
		"rock":
			var r := _mi(P.box(1.3 + rnd * 0.4, 0.9 + rnd * 0.8, 1.2), P.mat(Color(0.66, 0.47, 0.28), 0.95), Vector3(0, 0.5, 0), n)
			r.rotation = Vector3(0.2, rnd * 3.0, 0.15)
			var r2 := _mi(P.box(0.8, 0.6, 0.7), P.mat(Color(0.58, 0.4, 0.24), 0.95), Vector3(0.6, 0.3, 0.4), n)
			r2.rotation.y = rnd * 2.0
		"tree":
			_mi(P.cyl(0.14, 0.2, 1.6, 8), P.mat(Color(0.32, 0.22, 0.13)), Vector3(0, 0.8, 0), n)
			_mi(P.ball(0.95 + rnd * 0.3), P.mat(Color(0.2, 0.42, 0.18)), Vector3(0, 2.2 + rnd * 0.3, 0), n)
			_mi(P.ball(0.7), P.mat(Color(0.25, 0.5, 0.22)), Vector3(0.35, 2.8, 0.2), n)
		"pine":
			_mi(P.cyl(0.1, 0.14, 0.8, 6), P.mat(Color(0.3, 0.2, 0.12)), Vector3(0, 0.4, 0), n)
			_mi(P.cyl(0.0, 0.85, 1.6, 8), P.mat(Color(0.16, 0.3, 0.22)), Vector3(0, 1.4, 0), n)
			_mi(P.cyl(0.0, 0.62, 1.3, 8), P.mat(Color(0.18, 0.34, 0.25)), Vector3(0, 2.2, 0), n)
			_mi(P.cyl(0.0, 0.3, 0.5, 8), P.mat(Color(0.95, 0.97, 1.0)), Vector3(0, 2.75, 0), n)
		"lava":
			# Une mare de lave ronde qui bouillonne, cernée de roche noire
			var pool := _mi(P.cyl(0.85 + rnd * 0.15, 0.85 + rnd * 0.15, 0.04, 20), lava_mat(), Vector3(0, 0.08, 0), n)
			pool.rotation.y = rnd
			var rim := _mi(P.cyl(1.0 + rnd * 0.15, 1.08 + rnd * 0.15, 0.12, 14), P.mat(Color(0.08, 0.06, 0.06), 0.95), Vector3(0, 0.0, 0), n)
			rim.rotation.y = rnd * 2.0
		"block":
			var h := 1.2 + rnd * 2.0
			_mi(P.box(1.5, h, 1.5), P.mat(Color(0.42, 0.45, 0.52), 0.4, 0.7), Vector3(0, h / 2.0, 0), n)
			_mi(P.box(1.52, 0.08, 1.52), P.mat(Color(0.3, 0.75, 0.95), 0.4, 0.0, 2.0), Vector3(0, h * 0.7, 0), n)
		"column":
			var h := 3.0 + rnd * 1.5
			_mi(P.cyl(0.38, 0.42, h, 12), P.mat(Color(0.8, 0.66, 0.46)), Vector3(0, h / 2.0, 0), n)
			_mi(P.box(1.1, 0.3, 1.1), P.mat(Color(0.7, 0.56, 0.38)), Vector3(0, h, 0), n)
			_mi(P.box(1.1, 0.25, 1.1), P.mat(Color(0.7, 0.56, 0.38)), Vector3(0, 0.12, 0), n)
	return n


static var _lava: ShaderMaterial

static func lava_mat() -> ShaderMaterial:
	if _lava == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode unshaded;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz * 2.0;
	float n = noise(p + vec2(TIME * 0.3, TIME * 0.17)) * 0.6 + noise(p * 2.3 - TIME * 0.4) * 0.4;
	vec3 hot = vec3(1.0, 0.55, 0.12);
	vec3 cool = vec3(0.35, 0.03, 0.0);
	ALBEDO = mix(cool, hot, smoothstep(0.4, 0.85, n)) * 0.85;
}
"""
		_lava = ShaderMaterial.new()
		_lava.shader = sh
	return _lava


## Le repaire du gardien
static func lair(kind: String) -> Node3D:
	var n := Node3D.new()
	match kind:
		"pyramid":
			var py := _mi(P.cyl(0.0, 4.6, 5.5, 4), P.mat(Color(0.78, 0.6, 0.38)), Vector3(0, 2.75, 0), n)
			py.rotation.y = PI / 4.0
			_mi(P.box(1.2, 1.6, 0.6), P.mat(Color(0.2, 0.15, 0.1)), Vector3(0, 0.8, 3.0), n)
		"temple", "temple2":
			var stone := P.mat(Color(0.75, 0.62, 0.44) if kind == "temple2" else Color(0.6, 0.55, 0.48))
			_mi(P.box(5.5, 0.5, 4.5), stone, Vector3(0, 0.25, 0), n)
			for x in [-2.2, -0.75, 0.75, 2.2]:
				_mi(P.cyl(0.3, 0.32, 3.2, 10), stone, Vector3(x, 2.1, 1.6), n)
			_mi(P.box(5.5, 0.5, 4.5), stone, Vector3(0, 3.9, 0), n)
			var roof := _mi(P.cyl(0.0, 3.6, 1.4, 4), stone, Vector3(0, 4.85, 0), n)
			roof.rotation.y = PI / 4.0
			roof.scale = Vector3(1.1, 1, 0.9)
			_mi(P.box(4.0, 3.0, 2.0), P.mat(Color(0.25, 0.2, 0.15)), Vector3(0, 2.0, -0.6), n)
		"camp":
			for i in 3:
				var t := _mi(P.cyl(0.0, 1.5, 2.0, 6), P.mat(Color(0.55, 0.42, 0.22)), Vector3(i * 2.4 - 2.4, 1.0, (i % 2) * 1.5), n)
				t.rotation.y = i
			_mi(P.cyl(0.25, 0.4, 5.0, 4), P.mat(Color(0.8, 0.65, 0.25), 0.3, 0.8), Vector3(0, 2.5, -1.5), n)
		"fortress":
			var dark := P.mat(Color(0.16, 0.1, 0.09), 0.9)
			_mi(P.box(5.0, 3.5, 4.0), dark, Vector3(0, 1.75, 0), n)
			for x in [-2.3, 2.3]:
				_mi(P.box(1.2, 5.0, 1.2), dark, Vector3(x, 2.5, 1.6), n)
			_mi(P.box(1.4, 2.0, 0.2), P.mat(Color(1.0, 0.4, 0.05), 0.5, 0.0, 4.0), Vector3(0, 1.0, 2.05), n)
		"tower":
			_mi(P.box(3.0, 7.0, 3.0), P.mat(Color(0.4, 0.44, 0.52), 0.35, 0.8), Vector3(0, 3.5, 0), n)
			for y in [1.5, 3.5, 5.5]:
				_mi(P.box(3.05, 0.12, 3.05), P.mat(Color(0.3, 0.75, 0.95), 0.4, 0.0, 3.0), Vector3(0, y, 0), n)
	return n


## Le DHD : socle et dôme rouge
static func dhd() -> Node3D:
	var n := Node3D.new()
	_mi(P.cyl(0.35, 0.55, 0.9, 12), P.mat(Color(0.45, 0.42, 0.38), 0.6, 0.4), Vector3(0, 0.45, 0), n)
	var top := _mi(P.cyl(0.75, 0.6, 0.25, 18), P.mat(Color(0.5, 0.47, 0.42), 0.5, 0.5), Vector3(0, 1.0, 0), n)
	top.rotation.x = -0.35
	var dome := _mi(P.ball(0.22), P.mat(Color(0.9, 0.15, 0.08), 0.2, 0.0, 1.5), Vector3(0, 1.18, 0.05), n)
	dome.scale = Vector3(1, 0.6, 1)
	dome.name = "Dome"
	return n


## Caisse de naquadah, ruine des Anciens, allié, gardien… : le marqueur d'un lieu
static func crate() -> Node3D:
	var n := Node3D.new()
	_mi(P.box(1.0, 0.6, 0.7), P.mat(Color(0.45, 0.33, 0.18)), Vector3(0, 0.3, 0), n)
	_mi(P.box(1.02, 0.08, 0.72), P.mat(Color(0.8, 0.65, 0.25), 0.3, 0.8), Vector3(0, 0.62, 0), n)
	_mi(P.ball(0.12), P.mat(Color(0.3, 0.9, 1.0), 0.2, 0.0, 6.0), Vector3(0.2, 0.75, 0), n)
	_mi(P.ball(0.09), P.mat(Color(0.3, 0.9, 1.0), 0.2, 0.0, 6.0), Vector3(-0.15, 0.72, 0.1), n)
	return n


static func ancient() -> Node3D:
	var panel := preload("res://scripts/ancient_console.gd").new()
	if panel.build():
		return panel
	panel.free()
	var n := Node3D.new()
	var stone := P.mat(Color(0.62, 0.62, 0.56), 0.9)
	_mi(P.box(1.4, 0.4, 1.4), stone, Vector3(0, 0.2, 0), n)
	_mi(P.cyl(0.35, 0.45, 1.3, 8), stone, Vector3(0, 1.05, 0), n)
	var orb := _mi(P.ball(0.28), P.mat(Color(0.5, 0.85, 1.0), 0.1, 0.0, 6.0), Vector3(0, 1.95, 0), n)
	orb.name = "Orb"
	for i in 3:
		var p := _mi(P.box(0.3, 2.2, 0.3), stone, Vector3(cos(i * TAU / 3.0) * 1.4, 1.1, sin(i * TAU / 3.0) * 1.4), n)
		p.rotation.y = i
	return n


static func question() -> Node3D:
	var n := Node3D.new()
	var m := P.mat(Color(0.5, 0.85, 1.0), 0.3, 0.0, 4.0)
	_mi(P.cyl(0.0, 0.25, 0.5, 4), m, Vector3(0, 1.6, 0), n)
	var b := _mi(P.cyl(0.25, 0.0, 0.5, 4), m, Vector3(0, 2.1, 0), n)
	b.name = "Gem"
	_mi(P.cyl(0.6, 0.6, 0.04, 20), P.mat(Color(0.5, 0.85, 1.0), 0.3, 0.0, 1.5), Vector3(0, 0.03, 0), n)
	return n


## Un planeur de la mort
static func glider() -> Node3D:
	var n := Node3D.new()
	var hull := P.mat(Color(0.5, 0.5, 0.48), 0.4, 0.6)
	_mi(P.box(0.9, 0.6, 2.6), hull, Vector3.ZERO, n)
	for side in [-1, 1]:
		var w := _mi(P.box(3.2, 0.12, 1.4), hull, Vector3(side * 1.9, 0.3, -0.3), n)
		w.rotation.z = side * 0.5
		var tip := _mi(P.box(0.2, 1.4, 1.6), hull, Vector3(side * 3.3, 1.0, -0.3), n)
		tip.rotation.z = side * 0.3
	_mi(P.ball(0.25), P.mat(Color(1.0, 0.6, 0.1), 0.3, 0.0, 5.0), Vector3(0, 0, 1.35), n)
	return n


## Un anneau de transport goa'uld
static func transport_ring() -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = 1.9
	t.outer_radius = 2.3
	t.rings = 32
	t.ring_segments = 8
	var mi := MeshInstance3D.new()
	mi.mesh = t
	mi.material_override = P.mat(Color(0.85, 0.68, 0.28), 0.25, 0.9)
	return mi
