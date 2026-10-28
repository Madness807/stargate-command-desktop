extends Node3D
## Anneaux d'Anquietas System : l'animation source ouvre le couvercle, lève
## les cinq anneaux puis les range. Le transfert a lieu quand ils sont déployés.
const Assets = preload("res://scripts/imported_assets.gd")
static var _cover_material: ShaderMaterial
var player: AnimationPlayer
var clip := ""
var available := false
var duration := 0.0
var transfer_at := 1.9

func _ready() -> void:
	var packed := Assets.prepared("res://assets/community/rings/source.glb", "res://assets/community/rings/mobile.scn")
	if packed == null:
		return
	var model := packed.instantiate() as Node3D
	model.name = "AnquietasTransportRings"
	model.scale = Vector3.ONE * 1.05
	model.position.y = -0.12
	add_child(model)
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material: Material = mesh.mesh.surface_get_material(surface)
			if material is StandardMaterial3D and material.resource_name == "Ring_Cover":
				if _cover_material == null:
					_cover_material = ShaderMaterial.new()
					_cover_material.shader = load("res://shaders/ring_cover.gdshader")
					_cover_material.set_shader_parameter("color_map", material.albedo_texture)
					_cover_material.set_shader_parameter("data_map", material.roughness_texture)
					_cover_material.set_shader_parameter("normal_map", material.normal_texture)
				mesh.set_surface_override_material(surface, _cover_material)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	player = players[0]
	for name in player.get_animation_list():
		if name != "RESET":
			clip = name
			break
	if clip == "":
		return
	var animation := player.get_animation(clip)
	animation.loop_mode = Animation.LOOP_NONE
	duration = animation.length
	player.play(clip)
	player.seek(0, true)
	player.pause()
	available = true

func start_transport() -> void:
	if available:
		player.play(clip)
		player.seek(0, true)
