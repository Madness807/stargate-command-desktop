extends RefCounted
## Le casting : chaque personnage du jeu sur les modèles Quaternius (corps + tenue + cheveux),
## avec ses couleurs (treillis, armures jaffas, robes goa'uld) et ses accessoires attachés aux os.

const Rig = preload("res://scripts/rig.gd")

const OLIVE := Color(0.33, 0.37, 0.24)
const SKIN_DARK := Color(0.5, 0.36, 0.28)
const GOLD := Color(0.95, 0.72, 0.25)
# Orientation d'une arme dans la main droite : le long de l'axe de visée des animations de tir
const AIM := Basis(Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0))

const BOOTS := ["Feet", "Belt"]
const DARK_MAIL := Color(0.3, 0.31, 0.33)

# corps, tenue, cheveux, teinte de peau, couleur de tenue, couleur de cheveux, capuche, arme,
# couleur du corps sous le cou (treillis, cotte, robe ; transparent = peau nue), pièces de tenue gardées
const SPEC := {
	"oneill": ["Superhero_Male", "Male_Ranger", "Hair_Buzzed", Color(1, 1, 1), Color(0.2, 0.2, 0.19), Color(0.55, 0.53, 0.5), false, "p90", OLIVE, BOOTS],
	"carter": ["Superhero_Female", "Female_Ranger", "Hair_BuzzedFemale", Color(1, 0.96, 0.94), Color(0.2, 0.2, 0.19), Color(0.95, 0.8, 0.45), false, "p90", OLIVE, BOOTS],
	"daniel": ["Superhero_Male", "Male_Ranger", "Hair_SimpleParted", Color(1, 1, 1), Color(0.2, 0.2, 0.19), Color(0.45, 0.32, 0.2), false, "p90", OLIVE, BOOTS],
	"tealc": ["Superhero_Male", "Male_Ranger", "", SKIN_DARK, Color(0.2, 0.2, 0.19), Color(0, 0, 0), false, "staff", OLIVE, BOOTS],
	"bratac": ["Superhero_Male", "Male_Ranger", "Hair_Beard", SKIN_DARK, Color(0.55, 0.4, 0.26), Color(0.92, 0.92, 0.88), false, "staff", Color(0.3, 0.22, 0.15), []],
	"jaffa": ["Superhero_Male", "Male_Ranger", "", SKIN_DARK, Color(0.62, 0.64, 0.68), Color(0, 0, 0), false, "staff", DARK_MAIL, []],
	"serpent": ["Superhero_Male", "Male_Ranger", "", SKIN_DARK, Color(0.7, 0.72, 0.76), Color(0, 0, 0), false, "staff", DARK_MAIL, []],
	"jaffa2": ["Superhero_Male", "Male_Ranger", "", SKIN_DARK, Color(0.72, 0.6, 0.35), Color(0, 0, 0), false, "staff", Color(0.35, 0.3, 0.22), []],
	"horus": ["Superhero_Male", "Male_Ranger", "", SKIN_DARK, Color(0.85, 0.68, 0.25), Color(0, 0, 0), false, "staff", Color(0.35, 0.3, 0.2), []],
	"jaffa3": ["Superhero_Male", "Male_Ranger", "", SKIN_DARK, Color(0.22, 0.22, 0.26), Color(0, 0, 0), false, "staff", Color(0.12, 0.12, 0.14), []],
	"kull": ["Superhero_Male", "Male_Ranger", "", Color(0.2, 0.2, 0.22), Color(0.12, 0.12, 0.14), Color(0, 0, 0), true, "kull", Color(0.08, 0.08, 0.09), []],
	"brute": ["Superhero_Male", "Male_Ranger", "", Color(0.85, 0.7, 0.6), Color(0.45, 0.14, 0.12), Color(0, 0, 0), false, "staff", Color(0.2, 0.1, 0.08), []],
	"prisoner": ["Superhero_Male", "Male_Peasant", "Hair_Long", Color(0.9, 0.78, 0.7), Color(0.45, 0.37, 0.28), Color(0.25, 0.18, 0.12), false, "club", Color(0.38, 0.31, 0.24), []],
	"priest": ["Superhero_Male", "Male_Ranger", "", SKIN_DARK, Color(0.6, 0.16, 0.14), Color(0, 0, 0), true, "hand", Color(0.45, 0.1, 0.09), []],
	"klorel": ["Superhero_Male", "Male_Ranger", "Hair_SimpleParted", Color(0.85, 0.65, 0.5), Color(0.2, 0.35, 0.7), Color(0.12, 0.08, 0.05), false, "hand", Color(0.12, 0.2, 0.42), []],
	"apophis": ["Superhero_Male", "Male_Ranger", "", Color(0.8, 0.6, 0.48), Color(0.1, 0.1, 0.12), Color(0, 0, 0), false, "hand", Color(0.08, 0.08, 0.1), []],
	"heruur": ["Superhero_Male", "Male_Ranger", "", Color(0.75, 0.55, 0.42), GOLD, Color(0, 0, 0), false, "hand", Color(0.5, 0.38, 0.12), []],
	"sokar": ["Superhero_Male", "Male_Ranger", "", Color(0.6, 0.45, 0.4), Color(0.5, 0.06, 0.06), Color(0, 0, 0), true, "hand", Color(0.3, 0.03, 0.03), []],
	"anubis": ["Superhero_Male", "Male_Ranger", "", Color(0.05, 0.05, 0.06), Color(0.06, 0.06, 0.07), Color(0, 0, 0), true, "none", Color(0.04, 0.04, 0.05), []],
	"cinq": ["Superhero_Male", "Male_Peasant", "Hair_SimpleParted", Color(0.95, 0.88, 0.82), Color(0.4, 0.48, 0.56), Color(0.15, 0.12, 0.1), false, "none", Color(0.3, 0.36, 0.42), []],
	"nox": ["Superhero_Female", "Female_Peasant", "Hair_Long", Color(1, 0.92, 0.85), Color(0.42, 0.52, 0.3), Color(0.8, 0.72, 0.5), false, "none", Color(0.36, 0.44, 0.26), []],
	"tokra": ["Superhero_Male", "Male_Peasant", "Hair_SimpleParted", Color(0.9, 0.75, 0.62), Color(0.55, 0.45, 0.6), Color(0.3, 0.2, 0.12), false, "none", Color(0.45, 0.36, 0.5), []],
}

const BODY_SHADER := """
shader_type spatial;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec4 skin : source_color = vec4(1.0);
uniform vec4 cloth : source_color = vec4(0.5);
uniform bool camo = false;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec4 t = texture(tex, UV);
	float l = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	float m = COLOR.r;
	vec3 c = cloth.rgb;
	if (camo) {
		// Le camouflage « woodland » du treillis BDU : taches vert, brun et noir
		float n1 = noise(UV * 38.0) * 0.65 + noise(UV * 90.0) * 0.35;
		float n2 = noise(UV * 52.0 + 7.3) * 0.7 + noise(UV * 120.0 + 3.1) * 0.3;
		c = mix(c, vec3(0.3, 0.24, 0.15), step(0.58, n1));
		c = mix(c, vec3(0.1, 0.11, 0.08), step(0.66, n2));
		c = mix(c, vec3(0.42, 0.44, 0.3), step(0.7, 1.0 - n1) * 0.6);
	}
	// Le tissu garde le relief du corps (plis, muscles) mais prend la couleur de la tenue
	ALBEDO = mix(t.rgb * skin.rgb, c * (0.75 + 0.5 * l), m);
	ROUGHNESS = mix(0.65, 0.9, m);
}
"""

static var _gray := {}
static var _mats := {}


static func has(kind: String) -> bool:
	return SPEC.has(kind)


static func mat(c: Color, rough: float = 0.6, metal: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
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


## La texture en niveaux de gris éclaircis : la teinte donne alors la couleur voulue
static func _grayscale(tex: Texture2D) -> Texture2D:
	if _gray.has(tex):
		return _gray[tex]
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var l: float = clamp(c.get_luminance() * 1.5 + 0.12, 0.0, 1.0)
			img.set_pixel(x, y, Color(l, l, l, c.a))
	img.generate_mipmaps()
	var out := ImageTexture.create_from_image(img)
	_gray[tex] = out
	return out


## Recolore les surfaces dont le matériau contient `name`
static func _paint(root: Node3D, name: String, color: Color, gray: bool, rough: float, metal: float) -> void:
	for m in Rig.meshes(root):
		for s in m.mesh.get_surface_count():
			var src: Material = m.mesh.surface_get_material(s)
			if src == null or not src.resource_name.contains(name):
				continue
			var nm := StandardMaterial3D.new()
			var tex: Texture2D = (src as BaseMaterial3D).albedo_texture if src is BaseMaterial3D else null
			if tex:
				nm.albedo_texture = _grayscale(tex) if gray else tex
			nm.albedo_color = color
			nm.roughness = rough
			nm.metallic = metal
			m.set_surface_override_material(s, nm)


static func build(kind: String) -> Node3D:
	var sp: Array = SPEC[kind]
	var parts := [sp[0], sp[1]]
	if sp[2] != "":
		parts.append(sp[2])
	if kind == "bratac":
		parts.append("Hair_Buzzed")
	var root := Rig.make(parts)
	var skel := root.get_node("Armature/Skeleton3D") as Skeleton3D
	# La capuche du rôdeur ne reste que pour les silhouettes encapuchonnées ; certains ne gardent
	# de la tenue que les bottes et la ceinture
	var keep: Array = sp[9]
	for m in Rig.meshes(root):
		var outfit: bool = m.name.begins_with(sp[1])
		if outfit and ((m.name.contains("Hood") and not sp[6]) or (keep.size() > 0 and not keep.any(func(k): return m.name.contains(k)))):
			m.get_parent().remove_child(m)
			m.free()
	var skin: Color = sp[3]
	_clothe(root, skel, skin, sp[8])
	_paint(root, "MI_Regular", skin, false, 0.7, 0.0)
	var jaffa_like: bool = sp[1].contains("Ranger") and kind not in ["klorel", "priest", "sokar", "anubis"]
	_paint(root, "MI_Peasant", sp[4], true, 0.85, 0.0)
	_paint(root, "MI_Ranger", sp[4], true, 0.45 if jaffa_like else 0.75, 0.55 if jaffa_like else 0.05)
	_paint(root, "MI_Hair", sp[5], true, 0.8, 0.0)
	_props(root, skel, kind, sp[7])
	return root


## Le corps nu des modèles devient habillé : sous le cou, sauf les mains, la peau prend la couleur
## du tissu. Le masque est calculé une fois sur la pose de repos et rangé dans les couleurs de sommets.
static var _clothed := {}

static func _clothe(root: Node3D, skel: Skeleton3D, skin: Color, cloth: Color) -> void:
	var neck_y: float = _rest_pos(skel, "neck_01").y + 0.01
	# Chaque main : du poignet (au-delà de l'avant-bras) jusqu'au bout des doigts
	var hands := [[_rest_pos(skel, "lowerarm_l"), _rest_pos(skel, "hand_l")], [_rest_pos(skel, "lowerarm_r"), _rest_pos(skel, "hand_r")]]
	var feet := []
	var sh := Shader.new()
	sh.code = BODY_SHADER
	for m in Rig.meshes(root):
		var mesh: Mesh = m.mesh
		for s in mesh.get_surface_count():
			var src: Material = mesh.surface_get_material(s)
			if src == null or not src.resource_name.contains("MI_Superhero"):
				continue
			var key := mesh.get_rid().get_id()
			if not _clothed.has(key):
				_clothed[key] = _masked(mesh, neck_y, hands, feet)
			m.mesh = _clothed[key]
			var mat := ShaderMaterial.new()
			mat.shader = sh
			mat.set_shader_parameter("tex", (src as BaseMaterial3D).albedo_texture)
			mat.set_shader_parameter("skin", skin)
			mat.set_shader_parameter("cloth", cloth if cloth.a > 0.0 else skin)
			mat.set_shader_parameter("camo", cloth == OLIVE)
			m.set_surface_override_material(s, mat)
			return


static func _masked(mesh: Mesh, neck_y: float, hands: Array, feet: Array) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var cols := PackedColorArray()
		cols.resize(verts.size())
		for i in verts.size():
			var v: Vector3 = verts[i]
			var bare: bool = v.y > neck_y
			for h in hands:
				var d: Vector3 = h[1] - h[0]
				var t: float = (v - h[0]).dot(d) / d.length_squared()
				if t > 0.93 and (v - (h[0] + d * clamp(t, 0.0, 2.0))).length() < 0.12:
					bare = true
			cols[i] = Color(0, 0, 0) if bare else Color(1, 1, 1)
		arr[Mesh.ARRAY_COLOR] = cols
		# Les canaux personnalisés exigeraient leur format exact : inutiles ici
		for c in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
			arr[c] = null
		var flags := 0
		var w = arr[Mesh.ARRAY_WEIGHTS]
		if w != null and verts.size() > 0 and w.size() == verts.size() * 8:
			flags |= Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
		out.surface_set_material(s, mesh.surface_get_material(s))
	return out


# ---------- Accessoires attachés aux os ----------

## Attache `node` à l'os `bone` en le plaçant en `at` (repère du personnage, en mètres, au repos)
static func _attach(root: Node3D, skel: Skeleton3D, bone: String, node: Node3D, at: Transform3D) -> void:
	var b := skel.find_bone(bone)
	if b < 0:
		return
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	skel.add_child(ba)
	var holder := skel.get_parent() as Node3D
	var in_skel := holder.transform.affine_inverse() * at
	node.transform = skel.get_bone_global_rest(b).affine_inverse() * in_skel
	ba.add_child(node)


static func _rest_pos(skel: Skeleton3D, bone: String) -> Vector3:
	var holder := skel.get_parent() as Node3D
	return holder.transform * skel.get_bone_global_rest(skel.find_bone(bone)).origin


static func _mesh(mesh: Mesh, m: Material, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	return mi


static func box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


static func cyl(r_top: float, r_bot: float, h: float, seg: int = 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


static func ball(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	return s


static func _props(root: Node3D, skel: Skeleton3D, kind: String, weapon: String) -> void:
	var head := _rest_pos(skel, "Head")
	var chest := _rest_pos(skel, "spine_03")
	var hand := _rest_pos(skel, "hand_r")
	var top := head + Vector3(0, 0.16, 0)
	var face := head + Vector3(0, 0.08, 0.1)

	# Le gilet tactique et la ceinture de SG-1
	if kind in ["oneill", "carter", "daniel", "tealc"]:
		var vest := Node3D.new()
		var vm := mat(Color(0.28, 0.31, 0.2), 0.9)
		vest.add_child(_mesh(box(0.3, 0.24, 0.035), vm, Vector3(0, 0, 0.095)))
		vest.add_child(_mesh(box(0.3, 0.26, 0.03), vm, Vector3(0, 0.01, -0.1)))
		for x in [-0.085, 0.0, 0.085]:
			vest.add_child(_mesh(box(0.065, 0.08, 0.035), mat(Color(0.24, 0.27, 0.17), 0.9), Vector3(x, -0.06, 0.125)))
		_attach(root, skel, "spine_03", vest, Transform3D(Basis(), chest + Vector3(0, -0.04, 0)))
	match kind:
		"oneill":
			var cap := Node3D.new()
			cap.add_child(_mesh(cyl(0.115, 0.125, 0.09, 16), mat(Color(0.32, 0.36, 0.22), 0.9)))
			cap.add_child(_mesh(box(0.2, 0.015, 0.13), mat(Color(0.3, 0.34, 0.2), 0.9), Vector3(0, -0.035, 0.12)))
			_attach(root, skel, "Head", cap, Transform3D(Basis(), top + Vector3(0, -0.02, 0.0)))
		"daniel":
			var g := Node3D.new()
			var gm := mat(Color(0.15, 0.15, 0.16), 0.3, 0.6)
			for x in [-0.035, 0.035]:
				g.add_child(_mesh(cyl(0.022, 0.022, 0.008, 12), mat(Color(0.8, 0.9, 1.0, 0.35), 0.05, 0.3), Vector3(x, 0, 0), Vector3(90, 0, 0)))
			g.add_child(_mesh(box(0.13, 0.008, 0.008), gm))
			_attach(root, skel, "Head", g, Transform3D(Basis(), face + Vector3(0, 0.0, 0.0)))
		"tealc", "bratac", "jaffa", "jaffa2", "brute":
			# Le tatouage doré du front (Apophis, puis l'emblème de Bra'tac)
			var t := _mesh(box(0.045, 0.045, 0.01), mat(GOLD, 0.3, 0.8, 0.6))
			_attach(root, skel, "Head", t, Transform3D(Basis(), face + Vector3(0, 0.05, 0.0)))
		"serpent", "horus":
			# Le casque de garde : tête de serpent d'Apophis ou de faucon d'Heru'ur, yeux brillants
			var h := Node3D.new()
			var hm := mat(Color(0.72, 0.74, 0.78) if kind == "serpent" else GOLD, 0.3, 0.85)
			var dome := _mesh(ball(0.14), hm, Vector3(0, 0.0, -0.02))
			dome.scale = Vector3(0.95, 1.1, 1.25)
			h.add_child(dome)
			if kind == "serpent":
				# Tête de cobra : museau allongé vers l'avant, collerette sur la nuque
				var snout := _mesh(ball(0.09), hm, Vector3(0, 0.02, 0.17))
				snout.scale = Vector3(0.85, 0.6, 1.7)
				h.add_child(snout)
				var hood := _mesh(ball(0.16), hm, Vector3(0, -0.04, -0.07))
				hood.scale = Vector3(1.35, 1.0, 0.45)
				h.add_child(hood)
			else:
				h.add_child(_mesh(box(0.06, 0.05, 0.22), hm, Vector3(0, 0.02, 0.18), Vector3(15, 0, 0)))
				for x in [-0.12, 0.12]:
					h.add_child(_mesh(box(0.02, 0.22, 0.12), hm, Vector3(x, 0.08, -0.02)))
			for x in [-0.055, 0.055]:
				h.add_child(_mesh(ball(0.022), mat(Color(1.0, 0.6, 0.1), 0.3, 0.0, 5.0), Vector3(x, 0.05, 0.19 if kind == "serpent" else 0.14)))
			_attach(root, skel, "Head", h, Transform3D(Basis(), head + Vector3(0, 0.1, 0)))
		"kull":
			var v := _mesh(box(0.2, 0.035, 0.03), mat(Color(1.0, 0.12, 0.08), 0.3, 0.0, 5.0))
			_attach(root, skel, "Head", v, Transform3D(Basis(), face + Vector3(0, 0.02, 0.02)))
		"klorel", "apophis", "heruur", "priest", "sokar":
			# Coiffe dorée et yeux qui s'illuminent
			var c := Node3D.new()
			c.add_child(_mesh(cyl(0.13, 0.11, 0.1, 16), mat(GOLD, 0.25, 0.9)))
			if kind == "apophis":
				c.add_child(_mesh(box(0.05, 0.12, 0.05), mat(GOLD, 0.25, 0.9), Vector3(0, 0.07, 0.1)))
			_attach(root, skel, "Head", c, Transform3D(Basis(), top + Vector3(0, -0.01, 0)))
			_eyes(root, skel, face, Color(1.0, 0.85, 0.4))
		"anubis":
			_eyes(root, skel, face, Color(1.0, 0.15, 0.05))

	# L'arme, dans la main droite (axe du canon le long de l'avant-bras)
	match weapon:
		"p90":
			var g := Node3D.new()
			var gm := mat(Color(0.12, 0.12, 0.13), 0.5, 0.3)
			g.add_child(_mesh(box(0.06, 0.1, 0.4), gm, Vector3(0, 0.02, 0.08)))
			g.add_child(_mesh(box(0.05, 0.03, 0.22), mat(Color(0.2, 0.2, 0.22), 0.4, 0.5), Vector3(0, 0.08, 0.06)))
			_attach(root, skel, "hand_r", g, Transform3D(AIM, hand))
		"staff":
			var s := Node3D.new()
			var sm := mat(Color(0.6, 0.5, 0.32), 0.35, 0.7)
			s.add_child(_mesh(cyl(0.02, 0.02, 1.9, 8), sm, Vector3(0, 0, 0), Vector3(90, 0, 0)))
			s.add_child(_mesh(cyl(0.035, 0.05, 0.22, 8), mat(GOLD, 0.25, 0.9), Vector3(0, 0, 0.85), Vector3(90, 0, 0)))
			s.add_child(_mesh(ball(0.025), mat(Color(1.0, 0.7, 0.2), 0.3, 0.0, 4.0), Vector3(0, 0, 0.97)))
			s.position.z = 0.25
			var holder := Node3D.new()
			holder.add_child(s)
			_attach(root, skel, "hand_r", holder, Transform3D(AIM, hand))
		"hand":
			var r := _mesh(ball(0.05), mat(Color(1.0, 0.75, 0.3), 0.3, 0.0, 3.0))
			_attach(root, skel, "hand_r", r, Transform3D(Basis(), hand + Vector3(0, 0, 0.03)))
		"club":
			var c := _mesh(cyl(0.03, 0.045, 0.6, 6), mat(Color(0.35, 0.25, 0.15)), Vector3.ZERO, Vector3(90, 0, 0))
			_attach(root, skel, "hand_r", c, Transform3D(Basis(), hand))
		"kull":
			var k := _mesh(box(0.08, 0.1, 0.3), mat(Color(0.15, 0.15, 0.17), 0.4, 0.6))
			_attach(root, skel, "hand_r", k, Transform3D(Basis(), hand))


static func _eyes(root: Node3D, skel: Skeleton3D, face: Vector3, c: Color) -> void:
	var e := Node3D.new()
	for x in [-0.035, 0.035]:
		e.add_child(_mesh(ball(0.014), mat(c, 0.3, 0.0, 6.0), Vector3(x, 0.0, 0.0)))
	_attach(root, skel, "Head", e, Transform3D(Basis(), face + Vector3(0, 0.0, 0.0)))
