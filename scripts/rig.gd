extends RefCounted
## Personnages Quaternius (rig « Universal », CC0) : un corps, une tenue et des cheveux posés sur
## un même squelette, animés par la Universal Animation Library (clips partagés, os ciblés par nom).

const DIR := "res://assets/chars/%s.glb"

static var _scenes := {}
static var _lib: AnimationLibrary


## Chaque glTF est lu une fois puis gardé en PackedScene : regénérer depuis le même GLTFState
## renommerait les os (upperarm_l2…) et casserait les animations
static func _scene(name: String) -> Node3D:
	if not _scenes.has(name):
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		st.handle_binary_image = GLTFState.HANDLE_BINARY_EMBED_AS_UNCOMPRESSED
		if doc.append_from_file(ProjectSettings.globalize_path(DIR % name), st) != OK:
			push_error("glTF illisible : " + name)
		var root := doc.generate_scene(st)
		for n in root.find_children("*", "", true, false):
			n.owner = root
		var ps := PackedScene.new()
		ps.pack(root)
		root.free()
		_scenes[name] = ps
	return (_scenes[name] as PackedScene).instantiate() as Node3D


## Les clips de UAL1 et UAL2, réécrits pour viser « Skeleton3D:os » depuis la racine du personnage
static func library() -> AnimationLibrary:
	if _lib:
		return _lib
	_lib = AnimationLibrary.new()
	for src in ["UAL1", "UAL2"]:
		var root := _scene(src)
		var ap := root.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		for lname in ap.get_animation_library_list():
			var l := ap.get_animation_library(lname)
			for an in l.get_animation_list():
				if _lib.has_animation(an):
					continue
				var a: Animation = l.get_animation(an).duplicate(true)
				for t in range(a.get_track_count() - 1, -1, -1):
					var p := a.track_get_path(t)
					if p.get_subname_count() == 0:
						a.remove_track(t)
						continue
					a.track_set_path(t, NodePath("Skeleton3D:" + p.get_concatenated_subnames()))
				var loop := an.ends_with("_Loop") or an in ["Sword_Idle", "Pistol_Idle_Loop"]
				a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
				_lib.add_animation(an, a)
		root.free()
	return _lib


static func _meshes(n: Node) -> Array:
	var out := []
	for c in n.find_children("*", "", true, false):
		if c is MeshInstance3D or c is ImporterMeshInstance3D:
			out.append(c)
	return out


## Assemble un personnage. parts = [corps, tenue, cheveux…] ; hide = noms de maillages du corps à masquer
## (sous la tenue). Renvoie un Node3D avec un enfant « Skeleton3D » et un AnimationPlayer « Anim ».
static func make(parts: Array, hide: Array = []) -> Node3D:
	var root := Node3D.new()
	var base := _scene(parts[0])
	var skel := base.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var arm := skel.get_parent() as Node3D
	# On garde la transformation de l'armature (échelle, rotation) sur un nœud intermédiaire
	var holder := Node3D.new()
	holder.name = "Armature"
	holder.transform = arm.global_transform if arm.is_inside_tree() else _world(arm)
	root.add_child(holder)
	for n in skel.find_children("*", "", true, false):
		n.owner = null
	skel.owner = null
	skel.get_parent().remove_child(skel)
	skel.name = "Skeleton3D"
	holder.add_child(skel)
	for m in _meshes(skel):
		_adopt(m, skel, m.name in hide)
	base.free()
	for i in range(1, parts.size()):
		var extra := _scene(parts[i])
		var es := extra.find_children("*", "Skeleton3D", true, false)
		for m in _meshes(es[0] if es.size() > 0 else extra):
			_adopt(m, skel, false)
		extra.free()
	var ap := AnimationPlayer.new()
	ap.name = "Anim"
	root.add_child(ap)
	ap.root_node = NodePath("../Armature")
	ap.add_animation_library("", library())
	return root


## Pose un maillage sur le squelette commun ; les ImporterMeshInstance3D (chargement hors éditeur)
## deviennent de vrais MeshInstance3D
static func _adopt(m: Node, skel: Skeleton3D, drop: bool) -> void:
	m.owner = null
	if m.get_parent():
		m.get_parent().remove_child(m)
	if drop:
		m.free()
		return
	var mi: MeshInstance3D
	if m is ImporterMeshInstance3D:
		mi = MeshInstance3D.new()
		mi.name = m.name
		mi.mesh = (m as ImporterMeshInstance3D).mesh.get_mesh()
		mi.skin = (m as ImporterMeshInstance3D).skin
		mi.transform = (m as ImporterMeshInstance3D).transform
		m.free()
	else:
		mi = m as MeshInstance3D
	skel.add_child(mi)
	mi.skeleton = NodePath("..")


static func _world(n: Node3D) -> Transform3D:
	var t := n.transform
	var p := n.get_parent()
	while p is Node3D:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


## Les MeshInstance3D d'un personnage assemblé
static func meshes(root: Node3D) -> Array:
	return root.find_children("*", "MeshInstance3D", true, false)


## Teinte un matériau (par son nom de ressource) sur tout le personnage
static func tint(root: Node3D, mat_name: String, color: Color, keep_texture: bool = true, rough: float = 0.8) -> void:
	for m in meshes(root):
		var mesh: Mesh = m.mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			if mat and mat.resource_name.contains(mat_name):
				var nm := StandardMaterial3D.new()
				if keep_texture and mat is BaseMaterial3D:
					nm.albedo_texture = (mat as BaseMaterial3D).albedo_texture
				nm.albedo_color = color
				nm.roughness = rough
				m.set_surface_override_material(s, nm)


## Les noms de matériaux d'un personnage (pour régler les teintes)
static func material_names(root: Node3D) -> Array:
	var out := []
	for m in meshes(root):
		for s in m.mesh.get_surface_count():
			var mat: Material = m.mesh.surface_get_material(s)
			out.append("%s/%s" % [m.name, mat.resource_name if mat else "-"])
	return out
