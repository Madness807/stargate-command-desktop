extends Node
var checks := 0
var fails := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		printerr("ÉCHEC PORTE ACCUEIL : ", message)

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _ready() -> void:
	var original := Game.stats.duplicate(true)
	Engine.time_scale = 10.0
	var main = load("res://main.tscn").instantiate()
	add_child(main)
	await wait(0.2)
	check(main.gate.horizon_mat.get_shader_parameter("open") == 0.0, "composition commence porte fermée")
	await wait(3.0)
	check(main.gate.ring_angle != 0.0, "anneau de glyphes tourne")
	check(main.title_screen._glyphs.size() == 7, "sept glyphes réels dans le moniteur de liaison")
	check("Chevron" in main.title_screen._link_status.text, "moniteur décrit la composition en cours")
	main._leave_title()
	await wait(2.0)
	check(main.sgc.visible and not main.gate.visible, "continuer rejoint la base pendant la composition")
	check(main.gate.master.position.y == 0.0, "chevron arrêté en position neutre")
	check(main._title_timer.is_stopped(), "horloge du menu stoppée en campagne")
	check(not Audio._loops.has("dial"), "son de composition arrêté en campagne")
	main.show_title()
	await wait(20.0)
	check(main.gate.horizon_mat.get_shader_parameter("open") == 1.0, "composition ouvre le vortex")
	check(main.gate.horizon_glow.light_energy > 0, "vortex éclaire la salle")
	check(main.title_screen._link_status.text.contains("Liaison établie"), "moniteur confirme la liaison après le kawoosh")
	var lit := 0
	for chevron in main.gate.chevron_lights:
		if chevron.material_override == main.gate.chevron_lit_mat:
			lit += 1
	check(lit == 7, "sept chevrons allumés, deux chevrons intergalactiques éteints")
	check(is_instance_valid(main.gate.imported_model), "le modèle fourni est utilisé par le menu")
	var faces: PackedVector3Array = main.gate.chevron_lights[0].mesh.get_faces()
	if not is_instance_valid(main.gate.imported_model):
		var center_exists := false
		for i in range(0, faces.size(), 3):
			if Geometry3D.ray_intersects_triangle(Vector3(0, 0, 2), Vector3.FORWARD, faces[i], faces[i + 1], faces[i + 2]) != null:
				center_exists = true
		check(center_exists, "le cœur triangulaire procédural est présent dans les faces rendues")
	else:
		check(faces.size() > 0, "maillage lumineux du modèle importé présent")

	check(not Audio._loops.has("dial") and Audio._loops.has("horizon"), "son du vortex remplace le moteur de l'anneau")
	main._leave_title()
	await wait(40.0)
	check(main.gate.horizon_mat.get_shader_parameter("open") == 0.0, "ancienne séquence ne rouvre pas la porte après retour au SGC")
	check(main.sgc.visible, "base toujours accessible après annulation")
	check(Game.stats == original, "aucune modification de progression")
	print("Porte accueil : %d/%d vérifications réussies" % [checks - fails, checks])
	Engine.time_scale = 1.0
	get_tree().quit(1 if fails else 0)
