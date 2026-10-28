extends Node
## Validate the source GLBs, shared textures, scale, budgets and independent pivots.

const Assets = preload("res://scripts/outpost_assets.gd")
var checks := 0
var fails := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		printerr("ÉCHEC ASSET : ", what)


func _ready() -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(Assets.ROOT + "manifest.json"))
	check(manifest is Dictionary and manifest.models.size() == Assets.KINDS.size(), "manifest complet")
	var shared := Assets.material()
	for kind in Assets.KINDS:
		var model := Assets.make(kind)
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		check(not meshes.is_empty(), "%s contient des maillages de rendu" % kind)
		var triangles := 0
		var surfaces := 0
		var materials_shared := true
		for mi in meshes:
			for i in mi.mesh.get_surface_count():
				var arrays: Array = mi.mesh.surface_get_arrays(i)
				triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
				surfaces += 1
				materials_shared = materials_shared and mi.mesh.surface_get_material(i) == shared
		check(triangles == int(manifest.models[kind].triangles), "%s géométrie conforme au manifeste" % kind)
		check(triangles < 3000 and surfaces <= 3, "%s budget mobile : %d triangles / %d surfaces" % [kind, triangles, surfaces])
		check(materials_shared, "%s utilise le matériau atlas commun" % kind)
		var icon := Assets.icon(kind)
		check(icon != null and icon.get_size() == Vector2(192, 192), "%s miniature disponible" % kind)
		var bounds := Assets.bounds(model)
		check(bounds.size.y > 0.3 and bounds.position.y > -0.3, "%s origine au sol et échelle en mètres" % kind)
		if kind in ["hq", "generator", "turret", "infirmary", "lab", "mine"]:
			check(bounds.size.x < 4.2 and bounds.size.z < 4.2, "%s respecte son emprise RTS" % kind)
		var damage := model.find_child("Damage", true, false) as Node3D
		if damage:
			check(not damage.visible, "%s débris de dégâts masqués sur le modèle intact" % kind)
		model.free()
	var turret := Assets.make("turret")
	var copy := Assets.make("turret")
	var original_bounds := Assets.bounds(copy)
	copy.position = Vector3(14, 0, 20)
	check(Assets.bounds(copy).is_equal_approx(original_bounds), "emprise locale stable après placement")
	var aim := turret.find_child("Aim", true, false) as Node3D
	var other_aim := copy.find_child("Aim", true, false) as Node3D
	check(aim != null and other_aim != null, "pivot de tourelle présent")
	if aim and other_aim:
		aim.rotation.y = 1.2
		check(is_zero_approx(other_aim.rotation.y), "pivots indépendants entre deux instances")
	turret.free()
	copy.free()
	for pair in [["generator", "Rotor"], ["mine", "Drill"]]:
		var model := Assets.make(pair[0])
		check(model.find_child(pair[1], true, false) is Node3D, "%s possède son mécanisme animé" % pair[0])
		model.free()
	check(shared.albedo_texture.get_width() == 1024 and shared.albedo_texture.get_image().has_mipmaps(), "atlas partagé et mipmaps disponibles")
	check(shared.emission_operator == BaseMaterial3D.EMISSION_OP_MULTIPLY, "émission limitée aux zones lumineuses de l'atlas")
	var gallery_script = load("res://dev/outpost_gallery.gd")
	var gallery: Node3D = gallery_script.new()
	add_child(gallery)
	check(gallery.models.size() == Assets.KINDS.size(), "galerie complète disponible")
	var picked: Node3D = gallery.models[0]
	var center := picked.position + Assets.bounds(picked).get_center()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = gallery.cam.unproject_position(center)
	gallery._unhandled_input(event)
	check(gallery.cam.projection == Camera3D.PROJECTION_PERSPECTIVE and gallery.target.distance_to(center) < 0.01,
		"toucher un modèle ouvre sa vue rapprochée")
	gallery._overview()
	check(gallery.cam.projection == Camera3D.PROJECTION_ORTHOGONAL and gallery.target == Vector3.ZERO,
		"retour à la vue d'ensemble")
	gallery.free()
	print("Assets RTS : %d/%d vérifications réussies" % [checks - fails, checks])
	get_tree().quit(1 if fails else 0)
