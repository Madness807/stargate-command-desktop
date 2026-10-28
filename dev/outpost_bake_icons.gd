extends Node
## Bake actual 3D kit thumbnails, not unrelated UI artwork.
## ./start.sh res://dev/outpost_bake_icons.tscn

const Assets = preload("res://scripts/outpost_assets.gd")


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Icon baking needs a rendering display.")
		get_tree().quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(192, 192)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("bac6d0")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 1.4
	world.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	world.add_child(cam)
	cam.current = true
	var folder := ProjectSettings.globalize_path(Assets.ROOT + "icons")
	DirAccess.make_dir_recursive_absolute(folder)
	for kind in Assets.KINDS:
		var model := Assets.make(kind)
		world.add_child(model)
		var bounds := Assets.bounds(model)
		var center := bounds.get_center()
		cam.size = maxf(bounds.size.y, maxf(bounds.size.x, bounds.size.z)) * 1.45
		cam.look_at_from_position(center + Vector3(5, 4.8, 6), center)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		var error := image.save_png(folder + "/%s.png" % kind)
		if error != OK:
			printerr("Cannot write icon: ", kind)
			get_tree().quit(1)
			return
		print("icon ", kind)
		world.remove_child(model)
		model.free()
	get_tree().quit()
