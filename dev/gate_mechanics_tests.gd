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
		await gate.engage_chevron(n).finished
		for i in 9:
			var expected := 1.0 if i in Gate.LOCK_ORDER.slice(0, n + 1) else 0.0
			check(is_equal_approx(gate.chevron_amounts[i], expected), "état individuel chevron %d après symbole %d" % [i, n])
			for mesh in gate.chevron_mechanisms[i]:
				check(is_equal_approx(mesh.get_blend_shape_value(0), expected), "morph indépendant %d" % i)
			check(gate.chevron_mechanisms[i][0].mesh.get_surface_count() > 0, "boîtier visible %d" % i)
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
