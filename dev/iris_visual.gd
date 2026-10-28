extends Node3D
func _ready() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.025, 0.035, 0.05)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.7, 0.8, 1.0)
	environment.environment.ambient_light_energy = 0.65
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-25, -25, 0)
	light.light_energy = 2.0
	add_child(light)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 0, 11)
	camera.fov = 42
	var gate := preload("res://scripts/gate.gd").new()
	add_child(gate)
	for n in 3:
		await gate.engage_chevron(n).finished
	for amount in [1.0, 0.5, 0.0]:
		gate._set_iris_visible(true)
		gate._place_iris(amount)
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/sg1-iris-%s.png" % str(amount))
	get_tree().quit()
