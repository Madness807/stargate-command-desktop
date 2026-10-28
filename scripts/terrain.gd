extends RefCounted
## Le sol des planètes : un relief continu (l'aire de jeu au fond d'un vallon, dunes ou collines autour),
## deux textures réalistes (Poly Haven, CC0) mêlées par taches, et la végétation low-poly de Quaternius
## (CC0) : obstacles sur les cases, petits décors sur le terrain, forêts et rochers à l'horizon.

const SIZE := 220.0
const STEP := 2.0
const BOARD := 16.0          # demi-côté de l'aire de jeu (16 cases de 2 m)

# Par planète : textures (base, taches), échelles, teinte, relief autour, obstacles, décors, horizon
const LOOK := {
	"Abydos": {"tex": ["aerial_sand", "coast_sand_rocks_02"], "sc": [0.09, 0.12], "tint": Color(1.0, 0.9, 0.74), "hills": 9.0, "dunes": true,
		"obj": {"Rock_1": 1.5, "Rock_2": 1.4, "Rock_3": 1.6, "Rock_4": 1.3, "Rock_5": 1.5},
		"deco": {"Rock_6": 0.22, "Rock_7": 0.18}, "deco_n": 0.3,
		"far": {"Rock_3": 3.5, "Rock_1": 4.0, "PalmTree_1": 6.0, "PalmTree_2": 5.5}, "far_n": 60, "rock_tint": Color(0.6, 0.45, 0.32)},
	"Chulak": {"tex": ["leafy_grass", "rocky_terrain_02"], "sc": [0.12, 0.1], "tint": Color(0.95, 1.0, 0.9), "hills": 7.0, "dunes": false,
		"obj": {"CommonTree_1": 5.0, "CommonTree_2": 5.5, "CommonTree_3": 4.8, "CommonTree_4": 5.2, "Rock_Moss_1": 1.5, "Rock_Moss_2": 1.4},
		"deco": {"Grass": 0.45, "Grass_Short": 0.3, "Flowers": 0.35, "Bush_1": 0.7, "Plant_1": 0.5}, "deco_n": 1.1,
		"far": {"CommonTree_1": 6.0, "CommonTree_2": 6.5, "CommonTree_3": 5.5, "CommonTree_4": 6.0, "Bush_2": 1.5}, "far_n": 260},
	"Cimmeria": {"tex": ["snow_02", "rocky_terrain"], "sc": [0.1, 0.1], "tint": Color(1, 1, 1), "hills": 12.0, "dunes": false,
		"obj": {"PineTree_Snow_1": 5.5, "PineTree_Snow_2": 6.0, "PineTree_Snow_3": 5.0, "Rock_Snow_1": 1.5, "Rock_Snow_2": 1.4},
		"deco": {"Bush_Snow_1": 0.6, "Bush_Snow_2": 0.55, "Rock_Snow_3": 0.35}, "deco_n": 0.45,
		"far": {"PineTree_Snow_1": 7.0, "PineTree_Snow_2": 7.5, "PineTree_Snow_3": 6.5, "PineTree_Snow_4": 7.0}, "far_n": 300},
	"Netu": {"tex": ["burned_ground_01", "aerial_rocks_04"], "sc": [0.1, 0.08], "tint": Color(0.8, 0.6, 0.55), "hills": 10.0, "dunes": false, "lava": 1.0,
		"obj": {}, "deco": {"Rock_6": 0.3, "Rock_7": 0.28}, "deco_n": 0.4,
		"far": {"Rock_1": 5.0, "Rock_3": 6.0, "Rock_5": 4.5, "CommonTree_Dead_1": 4.0}, "far_n": 90, "rock_tint": Color(0.16, 0.13, 0.13)},
	"Hala": {"tex": ["metal_plate", "concrete_floor_01"], "sc": [0.08, 0.1], "tint": Color(0.85, 0.9, 1.0), "hills": 3.0, "dunes": false, "metal": 1.0,
		"obj": {}, "deco": {}, "deco_n": 0.0, "far": {}, "far_n": 0},
	"Dakara": {"tex": ["coast_sand_01", "cracked_red_ground"], "sc": [0.1, 0.09], "tint": Color(1.0, 0.86, 0.72), "hills": 8.0, "dunes": true,
		"obj": {}, "deco": {"Rock_6": 0.25, "Rock_7": 0.22, "Cactus_3": 0.6}, "deco_n": 0.35,
		"far": {"Rock_1": 4.5, "Rock_2": 5.0, "Rock_3": 4.0, "Cactus_1": 3.0}, "far_n": 70, "rock_tint": Color(0.75, 0.55, 0.38)},
}

const GROUND_SHADER := """
shader_type spatial;
uniform sampler2D a_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D a_nor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D b_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D b_nor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float a_sc = 0.1;
uniform float b_sc = 0.1;
uniform vec4 tint : source_color = vec4(1.0);
uniform float lava = 0.0;
uniform float metal = 0.0;
// Le brouillard de guerre : une case par pixel (bord compris), lissé par le filtrage
uniform sampler2D seen_tex : filter_linear, repeat_disable;
uniform float board_half = 16.0;
uniform float tile = 2.0;
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 uv = wpos.xz;
	float n = noise(uv * 0.045) * 0.6 + noise(uv * 0.13) * 0.3 + noise(uv * 0.5) * 0.1;
	// Les pentes et les taches prennent la seconde texture
	float m = clamp(smoothstep(0.42, 0.62, n) + COLOR.r, 0.0, 1.0);
	// Deux échelles de la même texture pour casser la répétition
	vec3 ca = mix(texture(a_alb, uv * a_sc).rgb, texture(a_alb, uv * a_sc * 0.31 + 0.37).rgb, 0.45);
	vec3 cb = texture(b_alb, uv * b_sc).rgb;
	vec3 c = mix(ca, cb, m) * tint.rgb;
	c *= 0.72 + 0.45 * noise(uv * 0.018) + 0.15 * (noise(uv * 0.09) - 0.5);
	NORMAL_MAP = mix(texture(a_nor, uv * a_sc).rgb, texture(b_nor, uv * b_sc).rgb, m);
	NORMAL_MAP_DEPTH = 1.2;
	ROUGHNESS = mix(0.93, 0.45, metal);
	METALLIC = metal * 0.55;
	if (lava > 0.0) {
		// Les fissures de lave de Netu, qui luisent
		float k = abs(noise(uv * 0.22) - 0.5) + abs(noise(uv * 0.6 + 3.0) - 0.5) * 0.4;
		float crack = smoothstep(0.09, 0.0, k) * lava;
		c = mix(c, vec3(0.05, 0.02, 0.01), crack);
		EMISSION = vec3(1.0, 0.32, 0.05) * crack * (2.5 + sin(TIME * 1.5 + uv.x) * 0.6);
	}
	vec2 suv = (wpos.xz + board_half + tile) / (2.0 * (board_half + tile));
	float seen = texture(seen_tex, suv).r;
	float g = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 hidden = mix(vec3(g), c, 0.35) * vec3(0.3, 0.32, 0.4);
	ALBEDO = mix(hidden, c, smoothstep(0.15, 0.85, seen));
	EMISSION *= seen;
}
"""

static var _meshes := {}
static var _tex := {}


static func look(planet_name: String) -> Dictionary:
	return LOOK.get(planet_name, LOOK["Abydos"])


## Le maillage d'un modèle de la nature (et sa hauteur d'origine)
static func model(name: String) -> Array:
	if not _meshes.has(name):
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		doc.append_from_file(ProjectSettings.globalize_path("res://assets/nature/%s.glb" % name), st)
		var root := doc.generate_scene(st)
		var mesh: Mesh = null
		var xf := Transform3D()
		for c in root.find_children("*", "", true, false):
			if c is ImporterMeshInstance3D or c is MeshInstance3D:
				mesh = (c as ImporterMeshInstance3D).mesh.get_mesh() if c is ImporterMeshInstance3D else (c as MeshInstance3D).mesh
				# La rotation et l'échelle des nœuds parents (modèles exportés en Z vers le haut)
				var n: Node = c
				while n and n != root:
					xf = (n as Node3D).transform * xf
					n = n.get_parent()
				break
		root.free()
		_meshes[name] = [mesh, xf * mesh.get_aabb() if mesh else AABB(), xf]
	return _meshes[name]


static func _texture(name: String) -> Texture2D:
	if not _tex.has(name):
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/ground/%s.jpg" % name))
		img.generate_mipmaps()
		_tex[name] = ImageTexture.create_from_image(img)
	return _tex[name]


## Hauteur du sol : presque plat sur l'aire de jeu, relief qui monte tout autour
static func height(x: float, z: float, lk: Dictionary, noise: FastNoiseLite) -> float:
	var d: float = max(abs(x), abs(z)) - BOARD
	var ramp := smoothstep(1.0, 22.0, d)
	var h := noise.get_noise_2d(x * 0.6, z * 0.6) * 0.06
	var hills: float = lk.hills
	if lk.dunes:
		var w := noise.get_noise_2d(x * 0.35, z * 0.35)
		h += ramp * hills * (0.55 + 0.45 * (1.0 - abs(sin(x * 0.07 + z * 0.03 + w * 3.0)))) * (0.6 + 0.4 * noise.get_noise_2d(z, x))
	else:
		h += ramp * hills * (0.5 + 0.5 * noise.get_noise_2d(x * 1.2, z * 1.2) + 0.25 * noise.get_noise_2d(x * 4.0, z * 4.0))
	return h


static func build_ground(parent: Node3D, planet_name: String, seed_value: int) -> ShaderMaterial:
	var lk := look(planet_name)
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := int(SIZE / STEP)
	var o := -SIZE / 2.0
	for i in n + 1:
		for j in n + 1:
			var x := o + i * STEP
			var z := o + j * STEP
			var hh := height(x, z, lk, noise)
			# Le rouge du sommet pousse vers la texture de roche sur les hauteurs
			st.set_color(Color(clamp(hh / max(1.0, lk.hills) - 0.35, 0.0, 1.0), 0, 0))
			st.set_uv(Vector2(x, z))
			st.add_vertex(Vector3(x, hh, z))
	for i in n:
		for j in n:
			var a := i * (n + 1) + j
			var b := a + n + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(a + 1)
			st.add_index(b)
			st.add_index(b + 1)
			st.add_index(a + 1)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = GROUND_SHADER
	mat.shader = sh
	mat.set_shader_parameter("a_alb", _texture(lk.tex[0] + "_diff"))
	mat.set_shader_parameter("a_nor", _texture(lk.tex[0] + "_nor"))
	mat.set_shader_parameter("b_alb", _texture(lk.tex[1] + "_diff"))
	mat.set_shader_parameter("b_nor", _texture(lk.tex[1] + "_nor"))
	mat.set_shader_parameter("a_sc", lk.sc[0])
	mat.set_shader_parameter("b_sc", lk.sc[1])
	mat.set_shader_parameter("tint", lk.tint)
	mat.set_shader_parameter("lava", lk.get("lava", 0.0))
	mat.set_shader_parameter("metal", lk.get("metal", 0.0))
	mi.material_override = mat
	parent.add_child(mi)
	parent.set_meta("ground_noise", noise)
	return mat


## Un obstacle de la nature, à la taille voulue (hauteur en mètres)
static func obstacle(planet_name: String, rng: RandomNumberGenerator) -> Node3D:
	var lk := look(planet_name)
	var objs: Dictionary = lk.obj
	if objs.is_empty():
		return null
	var keys := objs.keys()
	var k: String = keys[rng.randi() % keys.size()]
	var m: Array = model(k)
	var mi := MeshInstance3D.new()
	mi.mesh = m[0]
	var s: float = float(objs[k]) / max(0.01, (m[1] as AABB).size.y) * rng.randf_range(0.85, 1.15)
	mi.transform = Transform3D(Basis().scaled(Vector3.ONE * s), Vector3(0, -(m[1] as AABB).position.y * s - 0.05, 0)) * (m[2] as Transform3D)
	if lk.has("rock_tint") and k.begins_with("Rock"):
		mi.material_override = _rock_mat(lk.rock_tint)
	var n := Node3D.new()
	n.add_child(mi)
	return n


static func _rock_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.95
	return m


## Les décors : petits éléments sur l'aire de jeu (hors cases occupées) et ceinture lointaine
static func scatter(parent: Node3D, planet_name: String, rng: RandomNumberGenerator, free_tiles: Array, tile_pos: Callable) -> void:
	var lk := look(planet_name)
	var noise: FastNoiseLite = parent.get_meta("ground_noise")
	# Sur l'aire de jeu
	var deco: Dictionary = lk.deco
	if not deco.is_empty():
		var lists := {}
		for k in deco:
			lists[k] = []
		var keys := deco.keys()
		for t in free_tiles:
			var count := int(lk.deco_n) + (1 if rng.randf() < fmod(float(lk.deco_n), 1.0) else 0)
			for c in count:
				var k: String = keys[rng.randi() % keys.size()]
				var p: Vector3 = tile_pos.call(t) + Vector3(rng.randf_range(-0.95, 0.95), 0, rng.randf_range(-0.95, 0.95))
				lists[k].append([p, float(deco[k]) * rng.randf_range(0.7, 1.3)])
		for k in lists:
			_multimesh(parent, k, lists[k], rng, false, lk)
	# À l'horizon, hors de l'aire de jeu
	var far: Dictionary = lk.far
	if far.is_empty():
		return
	var flists := {}
	for k in far:
		flists[k] = []
	var fkeys := far.keys()
	var placed := 0
	var tries := 0
	while placed < int(lk.far_n) and tries < 5000:
		tries += 1
		var x := rng.randf_range(-75.0, 75.0)
		var z := rng.randf_range(-75.0, 75.0)
		if max(abs(x), abs(z)) < BOARD + 3.0:
			continue
		# Par bosquets : la densité suit un bruit
		if noise.get_noise_2d(x * 2.0, z * 2.0) < -0.05:
			continue
		var k: String = fkeys[rng.randi() % fkeys.size()]
		flists[k].append([Vector3(x, height(x, z, lk, noise), z), float(far[k]) * rng.randf_range(0.7, 1.35)])
		placed += 1
	for k in flists:
		_multimesh(parent, k, flists[k], rng, true, lk)


static func _multimesh(parent: Node3D, k: String, items: Array, rng: RandomNumberGenerator, far: bool, lk: Dictionary) -> void:
	if items.is_empty():
		return
	var m: Array = model(k)
	var aabb: AABB = m[1]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = m[0]
	mm.instance_count = items.size()
	for i in items.size():
		var p: Vector3 = items[i][0]
		var s: float = float(items[i][1]) / max(0.01, aabb.size.y)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
		mm.set_instance_transform(i, Transform3D(b, p + Vector3(0, -aabb.position.y * s - 0.03, 0)) * (m[2] as Transform3D))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	# Les décors lointains et les petits détails ne projettent pas d'ombre (performances)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if far or float(items[0][1]) < 1.0 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if lk.has("rock_tint") and k.begins_with("Rock"):
		mmi.material_override = _rock_mat(lk.rock_tint)
	parent.add_child(mmi)
