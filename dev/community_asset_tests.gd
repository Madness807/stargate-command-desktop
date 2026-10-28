extends Node3D
const People = preload("res://scripts/people.gd")
const Props = preload("res://scripts/props.gd")
const Assets = preload("res://scripts/imported_assets.gd")
const Rings = preload("res://scripts/transport_rings.gd")
const Planet = preload("res://scripts/planet.gd")
var checks := 0
var fails := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		printerr("ÉCHEC ASSETS : ", text)
func _ready() -> void:
	var replicator := People.new()
	replicator.build("replic")
	add_child(replicator)
	check(replicator._imported_replicators.size() == 1, "réplicateur fourni utilisé")
	var visual: Node3D = replicator._imported_replicators[0]
	check(visual.find_children("*", "MeshInstance3D", true, false).size() == 5, "38 morceaux regroupés en cinq maillages avec pattes articulées")
	check(visual.joints.size() == 4, "quatre pattes conservées")
	var box := Assets.bounds(visual)
	check(absf(maxf(box.size.x, box.size.z) - 1.15) < 0.02 and box.position.y > -0.01, "échelle et contact au sol")
	var rest: Basis = visual.joints[0].node.basis
	visual.walking = true
	visual._process(0.15)
	check(not visual.joints[0].node.basis.is_equal_approx(rest), "démarche procédurale")
	visual.walking = false
	visual._process(0.1)
	check(visual.joints[0].node.basis.is_equal_approx(rest), "pattes au repos à l'arrêt")
	replicator.fall()
	replicator._process(0.1)
	check(visual.dead and not visual.walking, "réplicateur vaincu cesse de marcher")
	var swarm := People.new()
	swarm.build("swarm")
	add_child(swarm)
	check(swarm._imported_replicators.size() == 4, "essaim de quatre modèles")
	var console := Props.ancient()
	add_child(console)
	check(console.name == "AncientControlPanel" and console.model != null, "console de Dakara à la place de l'ancien marqueur")
	check(console.buttons.size() > 0, "touches de console identifiées")
	console.activate()
	await get_tree().create_timer(0.4).timeout
	check(console.activated, "console activable")
	var rings := Rings.new()
	add_child(rings)
	check(rings.available and rings.duration > 4, "animation complète des anneaux importée")
	var before := Assets.bounds(rings)
	rings.start_transport()
	rings.player.seek(rings.transfer_at, true)
	var raised := Assets.bounds(rings)
	check(raised.end.y > before.end.y + 2, "anneaux déployés au moment du transfert")
	rings.player.seek(rings.duration, true)
	check(Assets.bounds(rings).end.y < raised.end.y - 2, "anneaux rangés en fin d'animation")
	rings.player.pause()
	# Vraie arrivée et vrai départ sur Netu, sauvegarde inchangée.
	var original := Game.stats.duplicate(true)
	var planet := Planet.new()
	add_child(planet)
	planet.setup(3, Game.team, 624)
	planet.set_process(false)
	Engine.time_scale = 8
	await planet._rings(true)
	check(planet.team.all(func(member): return member.visible and not member.walking), "arrivée : équipe visible après le transport")
	await planet._rings(false)
	check(planet.team.all(func(member): return not member.visible), "départ : équipe transférée")
	check(not planet.ring_pad.player.is_playing(), "animation terminée après le départ")
	Engine.time_scale = 1
	var ruin: Dictionary = {}
	for poi in planet.pois:
		if poi.k == "ruines": ruin = poi; break
	planet.reveal(ruin.tile, 2)
	planet.resolve(ruin, true)
	check(ruin.done and ruin.node.visible and ruin.node.find_child("AncientControlPanel", true, false).activated, "console utilisée reste dans le décor")
	check(Game.stats == original, "progression utilisateur intacte")
	print("Nouveaux assets : %d/%d vérifications réussies" % [checks - fails, checks])
	get_tree().quit(1 if fails else 0)
