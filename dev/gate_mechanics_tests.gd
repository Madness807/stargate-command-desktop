extends Node3D
const Gate = preload("res://scripts/gate.gd")
var fails := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		fails += 1
		printerr(message)
func _ready() -> void:
	var gate := Gate.new()
	add_child(gate)
	for n in 7:
		var index: int = Gate.LOCK_ORDER[n]
		var moving = gate.chevron_mechanisms[index][1]
		var rest: Vector3 = moving.position
		var animation := gate.engage_chevron(n)
		animation.pause()
		animation.custom_step(0.22)
		check(is_equal_approx(gate.chevron_amounts[index], 1.0), "course atteinte")
		for mesh in gate.chevron_mechanisms[index]:
			var arrays = mesh.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var blend: PackedVector3Array = mesh.mesh.surface_get_blend_shape_arrays(0)[0][Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var moved := 0
			var fixed := 0
			var maximum := 0.0
			for v in indices:
				var delta := vertices[v].distance_to(blend[v])
				maximum = maxf(maximum, delta)
				if delta > 0.001:
					moved += 1
				else:
					fixed += 1
			check(moved > 0 and maximum > 0.05, "déformation réelle du chevron %d" % index)
			if mesh == gate.chevron_mechanisms[index][0]:
				check(fixed > 0, "parties fixes du boîtier conservées %d" % index)
			check(mesh.get_blend_shape_value(0) > 0.99, "morph actionné")

		for i in 9:
			if i != index:
				check(gate.chevron_amounts[i] == 0.0, "les autres mécanismes restent au repos")
		animation.custom_step(1.0)
		check(is_zero_approx(gate.chevron_amounts[index]), "retour mécanique")
		check(moving.position.is_equal_approx(rest), "retour sans dérive")
		check(moving.material_override == gate.chevron_lit_mat, "verrouillage lumineux conservé")
		animation.kill()
	gate.reset_chevrons()
	for amount in gate.chevron_amounts:
		check(amount == 0.0, "réinitialisation mécanique")
	check(gate.iris_pivots.size() == 20, "vingt lames")
	await gate.set_iris(true, 0.05).finished
	check(is_equal_approx(gate._iris_amount, 1.0), "fermeture complète")
	gate.set_iris(false, 1.0)
	await get_tree().create_timer(0.15).timeout
	var before: float = gate._iris_amount
	var close := gate.set_iris(true, 0.05)
	check(is_equal_approx(gate._iris_amount, before), "inversion sans saut")
	await close.finished
	await gate.set_iris(false, 0.05).finished
	check(not gate.iris_pivots[0].visible, "lames rangées après ouverture")
	print("Mécanismes porte : ", "OK" if fails == 0 else str(fails) + " échecs")
	get_tree().quit(1 if fails else 0)
