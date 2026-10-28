extends "res://scripts/main.gd"
## Contrôle visuel du modèle d'après les deux références fournies.
func shot(label: String) -> void:
	await get_tree().create_timer(0.8).timeout
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/sg1-reference-" + label + ".png")

func _ready() -> void:
	super._ready()
	await get_tree().create_timer(18.0).timeout
	await shot("menu")
	set_process(false)
	ui.hide()
	if Settings._fps_label:
		Settings._fps_label.hide()
	cam.look_at_from_position(Vector3(0, RoomScript.GATE_Y, 10), Vector3(0, RoomScript.GATE_Y, 0))
	cam.fov = 43
	await shot("front")
	cam.look_at_from_position(Vector3(6.8, 5.8, 8.0), Vector3(0, RoomScript.GATE_Y, 0))
	await shot("profile")
	get_tree().quit()
