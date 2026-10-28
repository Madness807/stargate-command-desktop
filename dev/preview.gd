extends Node3D
## Planche de prévisualisation des personnages (outil de développement)
## godot --path . res://dev/preview.tscn -- out.png anim "corps,tenue,cheveux;corps2,…"
const Rig = preload("res://scripts/rig.gd")
const Cast = preload("res://scripts/cast.gd")

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var anim: String = args[1]
	var sets: Array = Array(args[2].split(";"))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.25, 0.3, 0.38)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.65, 0.75)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	floor.mesh = pm
	add_child(floor)
	var x := -(sets.size() - 1) * 0.6
	for s in sets:
		var parts: Array = Array(s.split(","))
		var c: Node3D = Cast.build(s.substr(1)) if s.begins_with("@") else Rig.make(parts)
		c.position.x = x
		if args.size() > 3:
			c.rotation_degrees.y = float(args[3])
		add_child(c)
		x += 1.2
		var aabb := AABB()
		for m in Rig.meshes(c):
			aabb = aabb.merge(m.global_transform * m.get_aabb())
		print(parts, " h=", snapped(aabb.size.y, 0.01))
		var ap := c.get_node("Anim") as AnimationPlayer
		if ap.has_animation(anim):
			ap.play(anim)
		else:
			print("pas d'anim ", anim)
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 35
	cam.look_at_from_position(Vector3(0, 1.3, 2.2 + sets.size() * 1.1), Vector3(0, 0.95, 0))
	await get_tree().create_timer(1.5).timeout
	get_viewport().get_texture().get_image().save_png(out)
	print("shot ", out)
	get_tree().quit()
