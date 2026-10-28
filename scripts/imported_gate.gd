extends RefCounted
## Adaptateur du modèle d'Anquietas System. La scène et ses textures sont partagées
## entre les portes ; seuls les états de chevrons et les morphs sont propres à chaque porte.
const PATH := "res://assets/stargate/milky_way.glb"
const CACHE := "res://assets/stargate/mobile.scn"

static func _scene() -> PackedScene:
	return preload("res://scripts/imported_assets.gd").prepared(PATH, CACHE)

static var _housing_parts: Array[ArrayMesh] = []
static var _light_parts: Array[ArrayMesh] = []

# Transpose la déformation du haut dans le repère de chaque chevron.
# Les sommets fixes restent fixes ; seule la mâchoire mobile suit le morph.
static func _retarget(source: Mesh, source_pose: Transform3D, target: Mesh, target_pose: Transform3D, sector: int, selected: PackedInt32Array = PackedInt32Array()) -> ArrayMesh:
	var result := ArrayMesh.new()
	result.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
	result.add_blend_shape("ChevronLock")
	var rotation := Basis(Vector3.BACK, -TAU * sector / 9.0)
	var source_arrays := source.surface_get_arrays(0)
	var source_vertices: PackedVector3Array = source_arrays[Mesh.ARRAY_VERTEX]
	var source_blend: PackedVector3Array = source.surface_get_blend_shape_arrays(0)[0][Mesh.ARRAY_VERTEX]
	var reference: Array[Vector3] = []
	var offsets: Array[Vector3] = []
	for i in source_vertices.size():
		var point := source_pose * source_vertices[i]
		if absf(atan2(point.x, point.y)) > PI / 9.0:
			continue
		reference.append(rotation * point)
		offsets.append(target_pose.basis.inverse() * rotation * source_pose.basis * (source_blend[i] - source_vertices[i]))
	for surface in target.get_surface_count():
		var arrays := target.surface_get_arrays(surface)
		for custom in range(Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM3 + 1):
			arrays[custom] = null
		if not selected.is_empty():
			arrays[Mesh.ARRAY_INDEX] = selected
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var morphed := vertices.duplicate()
		var used := {}
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for i in vertices.size():
				indices.append(i)
		for i in indices:
			if used.has(i):
				continue
			used[i] = true
			var point := target_pose * vertices[i]
			var nearest := 0
			var distance := INF
			for j in reference.size():
				var candidate := point.distance_squared_to(reference[j])
				if candidate < distance:
					distance = candidate
					nearest = j
			morphed[i] += offsets[nearest]
		var blend := []
		blend.resize(Mesh.ARRAY_MAX)
		blend[Mesh.ARRAY_VERTEX] = morphed
		blend[Mesh.ARRAY_NORMAL] = arrays[Mesh.ARRAY_NORMAL]
		blend[Mesh.ARRAY_TANGENT] = arrays[Mesh.ARRAY_TANGENT]
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [blend])
		result.surface_set_material(surface, target.surface_get_material(surface))
	return result

static func attach(host: Node3D, radius: float) -> Dictionary:
	var packed := _scene()
	if packed == null:
		return {}
	var visual := Node3D.new()
	visual.name = "ImportedStargate"
	host.add_child(visual)
	var model := packed.instantiate() as Node3D
	visual.add_child(model)
	var frame := model.find_child("0", true, false) as MeshInstance3D
	var ring := model.find_child("Ring", true, false) as Node3D
	if frame == null or ring == null:
		visual.free()
		return {}
	var local := host.global_transform.affine_inverse() * frame.global_transform
	var bounds := local * frame.get_aabb()
	visual.scale = Vector3.ONE * (radius * 2.0 / bounds.size.y)
	# Rotation autour de l'axe de la porte, indépendante des conversions FBX/glTF.
	var inner := Node3D.new()
	inner.name = "RotatingGlyphRing"
	host.add_child(inner)
	ring.reparent(inner, true)
	var lights: Array[MeshInstance3D] = []
	lights.resize(9)
	var morphs: Array[MeshInstance3D] = []
	for node in model.find_children("*", "MeshInstance3D", true, false):
		if node.name == "2" or node.name == "3":
			morphs.append(node)
		if not str(node.name).is_valid_int() or int(str(node.name)) < 3:
			continue
		var box: AABB = (host.global_transform.affine_inverse() * node.global_transform) * node.get_aabb()
		var center := box.get_center()
		var index := posmod(roundi(atan2(center.x, center.y) * 9.0 / TAU), 9)
		lights[index] = node
	for light in lights:
		if light == null:
			inner.free()
			visual.free()
			return {}
	# Le boîtier source rassemble les neuf mécanismes : séparer ses triangles
	# permet de piloter chaque morph sans déformer les huit autres chevrons.
	var housing := model.find_child("2", true, false) as MeshInstance3D
	if _housing_parts.is_empty():
		var transform := host.global_transform.affine_inverse() * housing.global_transform
		for sector in 9:
			var part := ArrayMesh.new()
			part.blend_shape_mode = housing.mesh.blend_shape_mode
			for b in housing.mesh.get_blend_shape_count():
				part.add_blend_shape(housing.mesh.get_blend_shape_name(b))
			for surface in housing.mesh.get_surface_count():
				var arrays := housing.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var source: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				if source.is_empty():
					for v in vertices.size():
						source.append(v)
				var selected := PackedInt32Array()
				for t in range(0, source.size(), 3):
					var center := transform * ((vertices[source[t]] + vertices[source[t + 1]] + vertices[source[t + 2]]) / 3.0)
					if posmod(roundi(atan2(center.x, center.y) * 9.0 / TAU), 9) == sector:
						selected.append_array(source.slice(t, t + 3))
				if selected.is_empty():
					continue
				for custom in range(Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM3 + 1):
					arrays[custom] = null
				arrays[Mesh.ARRAY_INDEX] = selected
				part.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, housing.mesh.surface_get_blend_shape_arrays(surface))
				part.surface_set_material(part.get_surface_count() - 1, housing.mesh.surface_get_material(surface))
			if sector != 0:
				part = _retarget(housing.mesh, transform, part, transform, sector)
			_housing_parts.append(part)
	if _light_parts.is_empty():
		var source_pose := host.global_transform.affine_inverse() * lights[0].global_transform
		_light_parts.append(lights[0].mesh)
		for i in range(1, 9):
			var target_pose := host.global_transform.affine_inverse() * lights[i].global_transform
			_light_parts.append(_retarget(lights[0].mesh, source_pose, lights[i].mesh, target_pose, i))
	var mechanisms: Array[Array] = []
	for i in 9:
		var piece := MeshInstance3D.new()
		piece.name = "ChevronMechanism%d" % i
		piece.mesh = _housing_parts[i]
		housing.get_parent().add_child(piece)
		piece.transform = housing.transform
		mechanisms.append([piece, lights[i]])
		lights[i].mesh = _light_parts[i]
	housing.hide()
	morphs.assign(mechanisms[0])
	for player in model.find_children("*", "AnimationPlayer", true, false):
		player.stop()
	return {"visual": visual, "inner": inner, "lights": lights, "morphs": morphs, "mechanisms": mechanisms}
