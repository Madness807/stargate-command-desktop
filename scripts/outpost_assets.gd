extends RefCounted
## Original textured GLB kit. Import once, share mesh resources and one PBR atlas.

const ROOT := "res://assets/outpost/"
const KINDS := ["hq", "generator", "infirmary", "lab", "turret", "mine", "camp",
	"supplies", "barrier", "construction", "deposit", "ruins", "gate_platform"]
static var _scenes := {}
static var _heights := {}
static var _material: StandardMaterial3D
static var _icons := {}


static func icon(kind: String) -> Texture2D:
	if not _icons.has(kind):
		var path := ProjectSettings.globalize_path(ROOT + "icons/%s.png" % kind)
		if not FileAccess.file_exists(path):
			return null
		var image := Image.load_from_file(path)
		image.generate_mipmaps()
		_icons[kind] = ImageTexture.create_from_image(image)
	return _icons[kind]


static func _texture(kind: String) -> ImageTexture:
	var image := Image.load_from_file(ProjectSettings.globalize_path(ROOT + "textures/field_%s.png" % kind))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.resource_name = "Outpost · shared PBR atlas"
		_material.albedo_texture = _texture("albedo")
		_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		var orm := _texture("orm")
		_material.metallic = 1
		_material.metallic_texture = orm
		_material.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
		_material.roughness_texture = orm
		_material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		_material.normal_enabled = true
		_material.normal_texture = _texture("normal")
		_material.normal_scale = 0.3
		_material.emission_enabled = true
		_material.emission = Color.WHITE
		_material.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		_material.emission_texture = _texture("emission")
		_material.emission_energy_multiplier = 0.8
	return _material


static func make(kind: String) -> Node3D:
	if not KINDS.has(kind):
		push_error("Unknown outpost asset: " + kind)
		return Node3D.new()
	if not _scenes.has(kind):
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var error := document.append_from_file(ProjectSettings.globalize_path(ROOT + "models/%s.glb" % kind), state)
		if error != OK:
			push_error("Outpost asset %s: %s" % [kind, error_string(error)])
			return Node3D.new()
		var source := document.generate_scene(state)
		for child in source.find_children("*", "", true, false):
			child.owner = source
			if child is MeshInstance3D and child.mesh:
				for surface in child.mesh.get_surface_count():
					child.mesh.surface_set_material(surface, material())
		var damage := source.find_child("Damage", true, false) as Node3D
		if damage:
			damage.visible = false
		_heights[kind] = bounds(source).end.y + 0.6
		var packed := PackedScene.new()
		error = packed.pack(source)
		source.free()
		if error != OK:
			push_error("Cannot pack outpost asset: " + kind)
			return Node3D.new()
		_scenes[kind] = packed
	var model: Node3D = _scenes[kind].instantiate()
	model.name = kind.capitalize().replace(" ", "")
	model.set_meta("label_height", _heights[kind])
	return model


static func bounds(root: Node3D) -> AABB:
	# Local bounds remain stable after placing a model in the game or gallery.
	return _bounds(root, root.transform.affine_inverse())


static func _bounds(node: Node3D, parent_transform: Transform3D) -> AABB:
	var transform := parent_transform * node.transform
	var result := AABB()
	if not node.visible:
		return result
	if node is MeshInstance3D and node.mesh:
		result = transform * node.mesh.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var next := _bounds(child, transform)
			if next.size != Vector3.ZERO:
				result = next if result.size == Vector3.ZERO else result.merge(next)
	return result
