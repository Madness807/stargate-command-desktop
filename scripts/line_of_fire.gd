extends RefCounted
## Traversée des cases entre deux centres ; les coins touchés sont vérifiés des deux côtés.
## Les cases de départ et d'arrivée sont exclues pour permettre d'attaquer un bâtiment.

static func clear(from: Vector2, to: Vector2, opaque: Callable) -> bool:
	var cell := Vector2i((from + Vector2.ONE * 0.5).floor())
	var last := Vector2i((to + Vector2.ONE * 0.5).floor())
	var first := cell
	var direction := to - from
	var step := Vector2i(signi(last.x - cell.x), signi(last.y - cell.y))
	var stride := Vector2(INF if direction.x == 0 else absf(1.0 / direction.x), INF if direction.y == 0 else absf(1.0 / direction.y))
	var next := Vector2(INF, INF)
	if step.x != 0:
		next.x = (cell.x + 0.5 * step.x - from.x) / direction.x
	if step.y != 0:
		next.y = (cell.y + 0.5 * step.y - from.y) / direction.y
	while cell != last:
		if is_equal_approx(next.x, next.y):
			for side in [cell + Vector2i(step.x, 0), cell + Vector2i(0, step.y)]:
				if side != first and side != last and opaque.call(side):
					return false
			cell += step
			next += stride
		elif next.x < next.y:
			cell.x += step.x
			next.x += stride.x
		else:
			cell.y += step.y
			next.y += stride.y
		if cell != last and opaque.call(cell):
			return false
	return true
