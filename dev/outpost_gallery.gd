extends Node3D
## ./start.sh res://dev/outpost_gallery.tscn -- --asset=hq --shot=/path.png@3 --quit=4
## Without --asset, show the complete kit. Wheel: zoom. Left/right: orbit.

const Assets = preload("res://scripts/outpost_assets.gd")
const T = preload("res://scripts/ui_theme.gd")
const Cli = preload("res://scripts/cli.gd")
const Harness = preload("res://scripts/debug_harness.gd")
var cam: Camera3D
var angle := 0.65
var distance := 10.0
var target := Vector3(0, 1.4, 0)
var models: Array[Node3D] = []
var clock := 0.0


func _ready() -> void:
	add_child(Harness.new(self))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("17222c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("bac6d0")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_color = Color("fff1d8")
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	var floor_node := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	floor_node.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("3d4546")
	mat.roughness = 0.9
	floor_node.material_override = mat
	floor_node.position.y = -0.25
	add_child(floor_node)
	cam = Camera3D.new()
	cam.fov = 42
	cam.far = 160
	add_child(cam)
	cam.current = true
	var kind := Cli.value("--asset")
	if kind == "":
		for i in Assets.KINDS.size():
			var model := Assets.make(Assets.KINDS[i])
			model.position = Vector3((i % 4 - 1.5) * 7.5, 0, (i / 4 - 1.5) * 7.5)
			add_child(model)
			models.append(model)
			var label := Label3D.new()
			label.text = String(Assets.KINDS[i]).to_upper()
			label.position = model.position + Vector3(0, -0.05, 3)
			label.font_size = 40
			label.pixel_size = 0.016
			label.modulate = T.TEXT
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			add_child(label)
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 43
		distance = 52
		target = Vector3(0, 0, 0)
	else:
		var model := Assets.make(kind)
		add_child(model)
		models.append(model)
		var bounds := Assets.bounds(model)
		target.y = bounds.size.y * 0.45
		distance = maxf(8, bounds.size.length() * 1.7)
	_camera()
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := T.label("ASSETS // " + (kind.to_upper() if kind != "" else "AVANT-POSTE · KIT DE TERRAIN"), "Section", T.AMBER)
	title.position = Vector2(24, 20)
	title.theme = T.make()
	layer.add_child(title)
	var hint := T.label("MODÈLES ORIGINAUX · ATLAS PBR PARTAGÉ · TOUCHER UN MODÈLE POUR LE VOIR", "Caption", T.DIM)
	hint.theme = title.theme
	hint.position = Vector2(24, 54)
	layer.add_child(hint)
	var controls := HBoxContainer.new()
	controls.theme = title.theme
	controls.position = Vector2(24, 90)
	layer.add_child(controls)
	controls.add_child(T.button("←", func(): angle -= 0.3; _camera(), "Ghost"))
	controls.add_child(T.button("→", func(): angle += 0.3; _camera(), "Ghost"))
	controls.add_child(T.button("Vue d'ensemble", _overview, "Ghost"))
	controls.add_child(T.button("Retour au menu", _menu, "Ghost"))


func _menu() -> void:
	get_tree().change_scene_to_file.call_deferred("res://main.tscn")


func _overview() -> void:
	if models.size() > 1:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 43
		distance = 52
		target = Vector3.ZERO
		_camera()


func _camera() -> void:
	cam.look_at_from_position(target + Vector3(sin(angle), 0.7, cos(angle)).normalized() * distance, target)


func _process(delta: float) -> void:
	clock += delta
	for model in models:
		var rotor := model.find_child("Rotor", true, false) as Node3D
		if rotor:
			rotor.rotation.y = clock * 7
		var drill := model.find_child("Drill", true, false) as Node3D
		if drill:
			drill.rotation.y = clock * 1.4


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		if e.keycode == KEY_ESCAPE:
			_menu()
		elif e.keycode in [KEY_LEFT, KEY_RIGHT]:
			angle += 0.15 if e.keycode == KEY_RIGHT else -0.15
			_camera()
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_LEFT:
			var nearest := 100.0
			var picked: Node3D
			for model in models:
				var center := model.position + Assets.bounds(model).get_center()
				var screen := cam.unproject_position(center)
				var d: float = e.position.distance_to(screen)
				if d < nearest:
					nearest = d
					picked = model
			if picked:
				var bounds := Assets.bounds(picked)
				target = picked.position + bounds.get_center()
				distance = maxf(8, bounds.size.length() * 1.7)
				cam.projection = Camera3D.PROJECTION_PERSPECTIVE
				_camera()
		elif e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			distance = clampf(distance + (1 if e.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 5, 80)
			cam.size = clampf(cam.size + (1 if e.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 10, 50)
			_camera()
