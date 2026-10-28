extends RefCounted
## Adaptateur du modèle d'Anquietas System. La scène et ses textures sont partagées
## entre les portes ; seuls les états de chevrons et les morphs sont propres à chaque porte.
const PATH := "res://assets/stargate/milky_way.glb"
const CACHE := "res://assets/stargate/mobile.scn"

static func _scene() -> PackedScene:
	return preload("res://scripts/imported_assets.gd").prepared(PATH, CACHE)

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
	for player in model.find_children("*", "AnimationPlayer", true, false):
		player.stop()
	return {"visual": visual, "inner": inner, "lights": lights, "morphs": morphs}
