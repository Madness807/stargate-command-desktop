extends RefCounted
## Préparation et partage des modèles fournis, sans modifier leurs fichiers d'origine.
static var _scenes := {}

static func prepared(source_path: String, cache_path: String) -> PackedScene:
	var packed: PackedScene = _scenes.get(cache_path)
	if packed:
		return packed
	if FileAccess.file_exists(cache_path):
		packed = load(cache_path) as PackedScene
		if packed:
			_scenes[cache_path] = packed
			return packed
	if not FileAccess.file_exists(source_path):
		return null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(source_path, state) != OK:
		return null
	var scene := document.generate_scene(state)
	if scene == null:
		return null
	# Textures mobiles : le GLB original reste intact. On limite les cartes à 2K
	# et on ne garde pas un second jeu de textures 4K dans les matériaux de la scène.
	var textures := {}
	var materials := {}
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		for surface in node.mesh.get_surface_count():
			var mat: Material = node.mesh.surface_get_material(surface)
			if not mat is StandardMaterial3D or materials.has(mat.get_instance_id()):
				continue
			materials[mat.get_instance_id()] = true
			for property in ["albedo_texture", "normal_texture", "metallic_texture", "roughness_texture", "ao_texture", "emission_texture"]:
				var texture: Texture2D = mat.get(property)
				if texture == null:
					continue
				var limit: int = 2048 if property == "albedo_texture" else 1024
				var key := str(texture.get_instance_id()) + ":" + str(limit)
				if not textures.has(key):
					var img: Image = texture.get_image()
					if max(img.get_width(), img.get_height()) > limit:
						var factor: float = float(limit) / maxf(img.get_width(), img.get_height())
						img.resize(roundi(img.get_width() * factor), roundi(img.get_height() * factor), Image.INTERPOLATE_LANCZOS)
						img.generate_mipmaps()
						textures[key] = ImageTexture.create_from_image(img)
					else:
						textures[key] = texture
				mat.set(property, textures[key])
	packed = PackedScene.new()
	if packed.pack(scene) != OK:
		packed = null
	if packed:
		var saved := ResourceSaver.save(packed, cache_path, ResourceSaver.FLAG_COMPRESS)
		if saved != OK:
			push_warning("Cache du modèle non enregistré : %d" % saved)
	scene.free()
	if packed:
		_scenes[cache_path] = packed
	return packed


static func bounds(node: Node3D) -> AABB:
	var result: Array = [AABB(), false]
	_bounds_walk(node, Transform3D.IDENTITY, result)
	return result[0]

static func _bounds_walk(node: Node, parent: Transform3D, result: Array) -> void:
	var pose := parent
	if node is Node3D:
		pose = parent * node.transform
	if node is MeshInstance3D:
		var box: AABB = pose * node.get_aabb()
		result[0] = result[0].merge(box) if result[1] else box
		result[1] = true
	for child in node.get_children():
		_bounds_walk(child, pose, result)

static func normalized(source: String, cache: String, span: float, use_height: bool = false) -> Node3D:
	var packed := prepared(source, cache)
	if packed == null:
		return null
	var holder := Node3D.new()
	var model := packed.instantiate() as Node3D
	holder.add_child(model)
	var box := bounds(model)
	var extent := box.size.y if use_height else maxf(box.size.x, box.size.z)
	if extent <= 0.00001:
		holder.free()
		return null
	model.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
	holder.scale = Vector3.ONE * (span / extent)
	return holder
