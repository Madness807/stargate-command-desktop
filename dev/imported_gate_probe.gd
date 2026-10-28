extends Node3D
func _ready() -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file("res://assets/stargate/milky_way.glb", state)
	print("IMPORT ", err)
	var scene := doc.generate_scene(state)
	add_child(scene)
	walk(scene)
	get_tree().quit()
func walk(node: Node) -> void:
	if node is MeshInstance3D:
		print("MESH ",node.get_path(), " BOUNDS ",node.global_transform * node.get_aabb()," BLENDS ",node.mesh.get_blend_shape_count())
		for i in node.mesh.get_blend_shape_count():print("  ",i," ",node.mesh.get_blend_shape_name(i))
	for c in node.get_children():walk(c)
