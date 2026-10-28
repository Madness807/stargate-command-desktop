extends Node3D
const People = preload("res://scripts/people.gd")
const Props = preload("res://scripts/props.gd")
const Rings = preload("res://scripts/transport_rings.gd")
var cam: Camera3D
func shot(name: String) -> void:
	await get_tree().create_timer(0.8).timeout
	if Settings._fps_label:
		Settings._fps_label.hide()
	for i in 8: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/sg1-asset-" + name + ".png")
func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_SKY
	env.environment.background_color = Color(0.08, 0.10, 0.12)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.78, 0.84, 0.90)
	env.environment.ambient_light_energy = 0.7
	add_child(env)
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.5, 0.6, 0.75)
	sky_material.sky_horizon_color = Color(0.8, 0.85, 0.9)
	sky.sky_material = sky_material
	env.environment.sky = sky
	if Settings._fps_label:
		Settings._fps_label.hide()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	ground.mesh = PlaneMesh.new()
	ground.mesh.size = Vector2(120, 24)
	ground.position.x = 20
	ground.material_override = People.mat(Color(0.27, 0.29, 0.3), 0.9)
	add_child(ground)
	cam = Camera3D.new()
	cam.fov = 43
	add_child(cam)
	var rings := Rings.new()
	add_child(rings)
	rings.start_transport()
	rings.player.seek(rings.transfer_at, true)
	rings.player.pause()
	cam.look_at_from_position(Vector3(7.2, 5.5, 8), Vector3(0, 1.0, 0))
	await shot("anneaux")
	var console := Props.ancient()
	console.position.x = 20
	add_child(console)
	cam.look_at_from_position(Vector3(23.1, 2.6, 3.5), Vector3(20, 0.65, 0))
	await shot("console")
	var replicator := People.new()
	replicator.build("replic")
	replicator.position.x = 40
	add_child(replicator)
	replicator.walking = true
	cam.look_at_from_position(Vector3(41.3, 0.9, 1.5), Vector3(40, 0.22, 0))
	await shot("replicateur")
	get_tree().quit()
