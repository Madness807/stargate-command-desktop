extends "res://scripts/main.gd"
## Captures sans achats, soins ou écriture de sauvegarde. Nécessite un affichage.
## godot --path . res://dev/sgc_visual.tscn
var _prefix := "sgc-"


func capture(label: String) -> void:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "/tmp/opencode/" + _prefix + label + ".png"
	get_viewport().get_texture().get_image().save_png(path)
	print("SCREENSHOT ", path, " · UI ", sgc.size)


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Les captures SGC nécessitent un affichage graphique.")
		get_tree().quit(1)
		return
	super._ready()
	_leave_title()
	sgc.set_process(false)
	await get_tree().create_timer(1.0).timeout
	if Cli.has("--compact"):
		get_tree().root.content_scale_factor = 1.5
		_prefix = "sgc-compact-"
	if Settings._fps_label != null:
		Settings._fps_label.hide()
	await capture("commandement-27-28")
	sgc.toggle_overview()
	await capture("plan-global")
	sgc.toggle_overview()
	sgc.navigate("briefing", false)
	sgc.advance(3.2)
	await capture("escalier")
	sgc.advance(20)
	await capture("briefing-27")
	sgc.navigate("infirmary", false)
	sgc.advance(25)
	await capture("medical-21")
	sgc.interact()
	await capture("soins-21")
	return_to_sgc()
	sgc.navigate("malp", false)
	sgc.advance(25)
	await capture("malp-24")
	sgc.navigate("team", false)
	sgc.advance(25)
	await capture("quartiers-25")
	sgc.prepared_mission = 0
	sgc.navigate("gate", false)
	sgc.advance(25)
	sgc.interact()
	await capture("depart")
	get_tree().quit()
