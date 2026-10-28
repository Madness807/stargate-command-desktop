extends Control
## Carte stratégique : cliquer ou toucher recentre la caméra, sans donner d'ordre.

const Sim = preload("res://scripts/outpost_sim.gd")
const T = preload("res://scripts/ui_theme.gd")
var view: Node3D


func _draw() -> void:
	if not is_instance_valid(view):
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("080f18"))
	var scale_map := size / Vector2(Sim.SIZE)
	for y in Sim.SIZE.y:
		for x in Sim.SIZE.x:
			var index: int = y * Sim.SIZE.x + x
			if view.sim.explored_cells[index] == 0:
				continue
			var color := Color("344d3b") if view.sim.visible_cells[index] else Color("1c2831")
			if view.sim.terrain_blocked(Vector2(x, y)):
				color = color.darkened(0.4)
			draw_rect(Rect2(Vector2(x, y) * scale_map, scale_map + Vector2(0.2, 0.2)), color)
	for landmark in [[Sim.GATE, T.BLUE], [Sim.DEPOSIT, T.GREEN], [Sim.RUINS, T.AMBER]]:
		if view.sim.is_explored(landmark[0]):
			draw_circle((landmark[0] + Vector2.ONE * 0.5) * scale_map, 4, landmark[1])
	for known in view.sim.known_buildings.values():
		if not view.sim.is_visible(known.pos):
			var p: Vector2 = (known.pos + Vector2.ONE * 0.5) * scale_map
			draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), Color(T.RED, 0.5), false, 1.5)
	for e in view.sim.entities:
		if not view.sim.entity_visible(e):
			continue
		var p: Vector2 = (e.pos + Vector2.ONE * 0.5) * scale_map
		var c: Color = T.BLUE if e.side == "sgc" else T.RED
		if view.sim.is_building(e):
			draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), c)
		else:
			draw_circle(p, 2.5, c)
	var center: Vector2 = (Vector2(view.focus.x, view.focus.z) / 2 + Vector2.ONE * 0.5) * scale_map
	draw_arc(center, 9, 0, TAU, 24, Color.WHITE, 1.5)
	draw_rect(Rect2(Vector2.ZERO, size), T.LINE, false, 1)


func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (
		e is InputEventMouseMotion and e.button_mask & MOUSE_BUTTON_MASK_LEFT):
		var point: Vector2 = (e.position / size * Vector2(Sim.SIZE) - Vector2.ONE * 0.5) * 2
		view.focus = Vector3(point.x, 0, point.y)
		view._camera()
		queue_redraw()
		accept_event()
