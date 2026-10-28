extends Node3D
const Gate = preload("res://scripts/gate.gd")
var checks := 0
var fails := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		printerr("ÉCHEC MODÈLE IMPORTÉ : ", message)
func local_center(gate: Node3D, mesh: MeshInstance3D) -> Vector3:
	return ((gate.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()).get_center()
func _ready() -> void:
	var gate := Gate.new()
	gate.position = Vector3(7, 4, -2)
	gate.scale = Vector3.ONE * 0.62
	add_child(gate)
	check(is_instance_valid(gate.imported_model), "modèle GLB fourni chargé")
	check(gate.chevron_lights.size() == 9, "neuf chevrons identifiés")
	check(local_center(gate, gate.chevron_lights[0]).y > 3, "chevron principal en haut")
	check(local_center(gate, gate.chevron_lights[1]).x > 0 and local_center(gate, gate.chevron_lights[8]).x < 0, "ordre droite et gauche correct après conversions FBX")
	var frame := gate.imported_model.find_child("0", true, false) as MeshInstance3D
	var frame_box: AABB = (gate.global_transform.affine_inverse() * frame.global_transform) * frame.get_aabb()
	check(abs(frame_box.size.y - 6.7) < 0.02, "diamètre de 6,70 m à l'échelle locale")
	var ring := gate.inner.find_child("Ring_Glyphs_0", true, false) as MeshInstance3D
	var origin := gate.inner.find_child("GizaPoO", true, false) as Node3D
	var before := origin.global_position
	var fixed := frame.global_transform
	gate._set_ring(90)
	check(origin.global_position.distance_to(before) > 1, "point d'origine tourne avec l'anneau")
	check(frame.global_transform.is_equal_approx(fixed), "bâti immobile pendant la composition")
	gate._set_ring(0)
	check(origin.global_position.is_equal_approx(before), "retour précis à l'orientation d'origine")
	gate._set_master_amount(1)
	check(gate._imported_morphs.size() == 2, "morphs du boîtier et de la lumière détectés")
	for mesh in gate._imported_morphs:
		check(mesh.get_blend_shape_value(0) > 0.99, "mécanisme du modèle actionné")
	gate.reset_mechanism()
	check(gate._imported_morphs[0].get_blend_shape_value(0) == 0, "annulation remet le mécanisme au repos")
	gate.reset_chevrons()
	gate.light_chevron(0)
	check(gate.chevron_lights[1].material_override == gate.chevron_lit_mat, "premier chevron à droite allumé")
	check(gate.chevron_lights[8].material_override == gate.chevron_off_mat, "chevron opposé reste éteint")
	var texture_ok := true
	for mesh in [frame, ring]:
		var material := mesh.mesh.surface_get_material(0) as StandardMaterial3D
		check(material != null and material.albedo_texture != null, "matériaux et textures du créateur conservés")
		if material and material.albedo_texture:
			texture_ok = texture_ok and material.albedo_texture.get_width() <= 2048
	check(texture_ok, "textures limitées à 2K pour le téléphone")
	var other := Gate.new()
	add_child(other)
	check(other.chevron_lights[0].mesh == gate.chevron_lights[0].mesh, "maillages partagés entre les portes")
	check(other.chevron_lights[1].material_override != gate.chevron_lights[1].material_override, "états lumineux indépendants")
	print("Modèle importé : %d/%d vérifications réussies" % [checks - fails, checks])
	get_tree().quit(1 if fails else 0)
