extends Node3D
## Console de merlincodes ; les touches s'enfoncent lors de son utilisation.
const Assets = preload("res://scripts/imported_assets.gd")
var model: Node3D
var activated := false
var buttons: Array[Node3D] = []

func build() -> bool:
	name = "AncientControlPanel"
	model = Assets.normalized("res://assets/community/console/source/ancient-control-panel.glb", "res://assets/community/console/mobile.scn", 1.35, true)
	if model == null:
		return false
	add_child(model)
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var material: Material = mesh.mesh.surface_get_material(0)
		if material and material.resource_name == "buttons":
			buttons.append(mesh)
	return true

func activate() -> void:
	if activated:
		return
	activated = true
	var tween := create_tween().set_parallel()
	for button in buttons:
		tween.tween_property(button, "position:y", button.position.y - 0.045, 0.3).set_trans(Tween.TRANS_SINE)
