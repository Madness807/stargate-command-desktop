extends "res://scripts/main.gd"

const DEST := "res://dev/audit-2026-10-29/captures/"

func shot(label: String) -> void:
	for i in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(DEST + label + ".png")
	print("AUDIT CAPTURE ", label)

func _ready() -> void:
	Game.save_path = "user://audit_2026_10_29_isolated.json"
	Game.stats = Game._fresh()
	Game.refresh_team()
	super._ready()
	await get_tree().create_timer(3).timeout
	await shot("01-accueil")
	_leave_title()
	await get_tree().create_timer(1).timeout
	await shot("02-sgc")
	show_menu("briefing")
	await shot("03-briefing-campagne")
	hub.close()
	current = 0
	start_planet()
	while planet.input_locked:
		await get_tree().process_frame
	await get_tree().create_timer(1).timeout
	await shot("04a-exploration")
	var encounter := {}
	for p in planet.pois:
		if p.k == "combat":
			encounter = p
			break
	var start: Vector2i = planet._nearest_free(encounter.tile + Vector2i(-3, 0))
	for member in planet.team:
		member.position = planet.tile_pos(start)
	planet.reveal(encounter.tile, 5)
	start_combat(encounter, 0, 0)
	planet.combat.toggle_tactical_pause()
	await get_tree().create_timer(1).timeout
	await shot("04b-combat")
	_end_planet()
	get_tree().quit()
