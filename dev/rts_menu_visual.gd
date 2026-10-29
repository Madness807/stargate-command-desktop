extends Node
## Captures des menus natifs, sans écriture de sauvegarde.
var menu: Control

func shot(label: String) -> void:
	for i in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/sg1-" + label + ".png")

func _ready() -> void:
	menu = load("res://outpost_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().create_timer(1).timeout
	await shot("briefing")
	menu._show_page("forces")
	menu._choose_profile("recon")
	await shot("equipe")
	menu._show_page("rules")
	await shot("engagement")
	menu._controls()
	await shot("commandes")
	menu._options()
	await shot("options")
	menu._sub.close()
	menu.queue_free()
	await get_tree().process_frame
	var terrain = load("res://scripts/outpost.gd").new()
	terrain.persistence_enabled = false
	add_child(terrain)
	await get_tree().create_timer(2).timeout
	terrain._menu()
	await shot("pause-rts")
	get_tree().quit()
