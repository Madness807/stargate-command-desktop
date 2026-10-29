extends Node

class QuietCombat extends "res://scripts/combat_realtime.gd":
	func _float_text(_at: Vector3, _text: String, _color: Color) -> void:
		pass

func _ready() -> void:
	var combat := QuietCombat.new()
	combat.boss = true
	var daniel := {"queued": {}, "cd": 0.0, "node": Node3D.new()}
	var enemy := {"side": "foe", "alive": true, "boss": true, "dmg": 24}
	combat.units = [enemy]
	var damage_history := [enemy.dmg]
	for i in 5:
		daniel.cd = 0.0 # Équivalent à attendre la fin des 15 secondes de recharge.
		daniel.queued = {"kind": "daniel"}
		combat._apply_queued(daniel)
		damage_history.append(enemy.dmg)
	print("DANIEL successive translations boss damage: ", damage_history)
	daniel.node.free()
	combat.free()
	var sim = load("res://scripts/outpost_sim.gd").new({"established": true})
	for entity in sim.entities:
		if entity.kind == "camp":
			entity.hp = 0
	sim._add("mine", "sgc", sim.DEPOSIT)
	sim.tick(0.1)
	print("EXPEDITION rule probe (camp removed, completed mine, no generator): result=", sim.result, " powered=", sim.powered(), " naquadah=", sim.naquadah)
	print("NOTE: isolated rule probes, not demonstrations of a natural full playthrough.")
	get_tree().quit()
