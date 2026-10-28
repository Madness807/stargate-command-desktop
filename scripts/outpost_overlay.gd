extends Control
## Jauges et retours d'ordres en taille écran, lisibles même en dézoomant.

const T = preload("res://scripts/ui_theme.gd")
var view: Node3D
var effects: Array[Dictionary] = []


func feedback(pos: Vector3, text: String, color: Color, marker: bool = false) -> void:
	if effects.size() >= 40:
		effects.pop_front()
	effects.append({"pos": pos, "text": text, "color": color, "marker": marker, "life": 0.9})
	queue_redraw()


func advance(delta: float) -> void:
	for effect in effects:
		effect.life -= delta
	effects = effects.filter(func(effect): return effect.life > 0)
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(view):
		return
	for e in view.sim.entities:
		if not view.sim.entity_visible(e) or (e.hp >= e.max_hp and not view.selected.has(e.id) and e.build <= 0):
			continue
		var height := 2.3
		if view.visuals.has(e.id):
			height = view.visuals[e.id].label.position.y - 0.4
		var world: Vector3 = view._world(e.pos, height)
		if view.cam.is_position_behind(world):
			continue
		var point: Vector2 = view.cam.unproject_position(world)
		var ratio: float = clampf(e.hp / e.max_hp, 0, 1)
		var color: Color = T.GREEN if e.side == "sgc" else T.RED
		if e.build > 0:
			ratio = 1.0 - e.build / view.sim.BUILDINGS[e.kind].time
			color = T.AMBER
		draw_rect(Rect2(point - Vector2(30, 0), Vector2(60, 8)), Color("101922"))
		draw_rect(Rect2(point - Vector2(29, -1), Vector2(58 * ratio, 6)), color)
	for effect in effects:
		if view.cam.is_position_behind(effect.pos):
			continue
		var point: Vector2 = view.cam.unproject_position(effect.pos)
		var color: Color = effect.color
		color.a *= minf(1, effect.life * 2)
		if effect.marker:
			draw_arc(point, 10 + (0.9 - effect.life) * 20, 0, TAU, 24, color, 2)
			draw_line(point - Vector2(6, 0), point + Vector2(6, 0), color, 2)
			draw_line(point - Vector2(0, 6), point + Vector2(0, 6), color, 2)
		else:
			point.y -= (0.9 - effect.life) * 45
			draw_string(T.font("Rajdhani-Bold"), point + Vector2(-10, 0), effect.text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 24, color)
