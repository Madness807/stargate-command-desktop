extends Node3D
## Réplicateur de TaurWing : géométrie d'origine, quatre pattes animées en code.
const Assets = preload("res://scripts/imported_assets.gd")
const SOURCE := "res://assets/community/replicator/source.glb"
const MOBILE := "res://assets/community/replicator/mobile.scn"
const RIGGED := "res://assets/community/replicator/rigged.scn"
const LEG_NAMES := ["Rep_block_low_007", "Rep_block_low_018", "Rep_block_low_029", "Rep_block_low_037"]
static var _packed: PackedScene
var walking := false
var dead := false
var joints: Array = []
var _phase := 0.0
var _rest_y := 0.0
var _feet: Array = []

static func _pose(node: Node3D, parent: Node3D) -> Transform3D:
	var pose := node.transform
	var cursor := node.get_parent()
	while cursor != parent and cursor != null:
		if cursor is Node3D:
			pose = cursor.transform * pose
		cursor = cursor.get_parent()
	return pose

static func _merge(meshes: Array, parent: Node3D) -> void:
	var groups := {}
	for mesh in meshes:
		for surface in mesh.mesh.get_surface_count():
			var material: Material = mesh.mesh.surface_get_material(surface)
			if not groups.has(material):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[material] = tool
			groups[material].append_from(mesh.mesh, surface, _pose(mesh, parent))
	for material in groups:
		var merged := MeshInstance3D.new()
		merged.mesh = groups[material].commit()
		merged.material_override = material
		merged.name = "ReplicatorBlocks"
		parent.add_child(merged)
	for mesh in meshes:
		mesh.free()

static func _model() -> PackedScene:
	if _packed:
		return _packed
	if FileAccess.file_exists(RIGGED):
		_packed = load(RIGGED) as PackedScene
		return _packed
	var source := Assets.prepared(SOURCE, MOBILE)
	if source == null:
		return null
	var scene := source.instantiate() as Node3D
	var root := scene.find_child("RootNode", true, false) as Node3D
	if root == null:
		scene.free()
		return null
	for name in LEG_NAMES:
		var leg := root.find_child(name, true, false) as Node3D
		if leg:
			_merge(leg.find_children("*", "MeshInstance3D", true, false), leg)
	var center: Array = []
	for child in root.get_children():
		if str(child.name) not in LEG_NAMES:
			center.append_array(child.find_children("*", "MeshInstance3D", true, false))
	_merge(center, root)
	# Les nouveaux maillages doivent être inclus dans la scène sauvegardée.
	for mesh in scene.find_children("*", "MeshInstance3D", true, false):
		mesh.owner = scene
	_packed = PackedScene.new()
	_packed.pack(scene)
	ResourceSaver.save(_packed, RIGGED, ResourceSaver.FLAG_COMPRESS)
	scene.free()
	return _packed

func setup(span: float) -> bool:
	var packed := _model()
	if packed == null:
		return false
	var model := packed.instantiate() as Node3D
	model.name = "TaurWingReplicator"
	add_child(model)
	var box := Assets.bounds(model)
	model.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
	scale = Vector3.ONE * (span / maxf(box.size.x, box.size.z))
	for name in LEG_NAMES:
		var joint := model.find_child(name, true, false) as Node3D
		if joint:
			joints.append({"node": joint, "basis": joint.basis})
			var meshes := joint.find_children("*", "MeshInstance3D", true, false)
			if not meshes.is_empty():
				var mesh: MeshInstance3D = meshes[0]
				var pose := _pose(mesh, self)
				var lowest := Vector3.ZERO
				var height := INF
				for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
					var point: Vector3 = pose * vertex
					if point.y < height:
						height = point.y
						lowest = vertex
				_feet.append({"mesh": mesh, "point": lowest})
	_phase = float(get_instance_id() % 70) * 0.1
	return true

func _ready() -> void:
	_rest_y = position.y

func _process(delta: float) -> void:
	if dead:
		return
	_phase += delta * (14.0 if walking else 0.0)
	for i in joints.size():
		var stride := sin(_phase + (0 if i in [0, 2] else PI)) * 0.17 if walking else 0.0
		joints[i].node.basis = joints[i].basis * Basis(Vector3.RIGHT, stride)
	position.y = _rest_y
	if not _feet.is_empty() and is_inside_tree():
		var lowest := INF
		for foot in _feet:
			var point: Vector3 = foot.mesh.global_transform * foot.point
			lowest = minf(lowest, point.y)
		var parent := get_parent() as Node3D
		var parent_scale: float = parent.global_basis.y.length()
		var ground: float = parent.global_position.y + _rest_y * parent_scale
		position.y -= (lowest - ground) / maxf(0.0001, parent_scale)
