extends Node3D
const Assets = preload("res://scripts/imported_assets.gd")
func _ready() -> void:
	for entry in [["rings", "source.glb"], ["replicator", "source.glb"], ["console", "source/ancient-control-panel.glb"]]:
		var base: String = "res://assets/community/" + entry[0] + "/"
		var packed := Assets.prepared(base + entry[1], base + "mobile.scn")
		if packed == null:
			printerr("FAILED ", entry[0]);continue
		var scene := packed.instantiate() as Node3D
		add_child(scene)
		print("ASSET ", entry[0], " BOUNDS ",Assets.bounds(scene))
		if entry[0] == "replicator":
			for name in ["Rep_block_low_007", "Rep_block_low_018", "Rep_block_low_029", "Rep_block_low_037"]:
				var leg := scene.find_child(name, true, false)
				print("LEG ",name," ",leg)
		for player in scene.find_children("*", "AnimationPlayer", true, false):
			for name in player.get_animation_list():
				var clip: Animation = player.get_animation(name)
				print("ANIM ", name, " LENGTH ", clip.length)
				player.play(name)
				for t in [0.0, 1.0, 2.0, 3.0, 4.0, 5.0]:
					player.seek(minf(t,clip.length),true)
					print("TIME ",t," ",Assets.bounds(scene))
				player.stop()
		scene.queue_free()
	get_tree().quit()
