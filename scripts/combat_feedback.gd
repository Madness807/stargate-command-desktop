extends Node3D
## Retours visuels natifs : bouclier, trajet et ligne de visée du membre sélectionné.
## Aucun effet ne décide d'une portée, d'un couvert ou d'un dégât.

var shields := {}
var orders: MeshInstance3D
var _shield_material: ShaderMaterial

func _init() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;
uniform float clock = 0.0;
void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.0);
	float bands = pow(0.5 + 0.5 * sin(VERTEX.y * 14.0 + clock * 2.0), 10.0);
	ALBEDO = vec3(0.18, 0.65, 1.0);
	ALPHA = 0.035 + rim * 0.58 + bands * 0.08;
}
"""
	_shield_material = ShaderMaterial.new()
	_shield_material.shader = shader
	orders = MeshInstance3D.new()
	orders.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	orders.material_override = material
	add_child(orders)

func sync(combat: Node, redraw_orders: bool = true) -> void:
	_shield_material.set_shader_parameter("clock", combat.combat_clock)
	for u in combat.units:
		if u.get("boss", false) and combat.planet.get("mission") != null:
			if not shields.has(u.index):
				var bubble := MeshInstance3D.new()
				var sphere := SphereMesh.new()
				sphere.radius = 1.15
				sphere.height = 2.3
				sphere.radial_segments = 24
				sphere.rings = 12
				bubble.mesh = sphere
				bubble.scale.y = 1.4
				bubble.material_override = _shield_material
				bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(bubble)
				shields[u.index] = bubble
			shields[u.index].position = u.node.position + Vector3.UP * 1.35
			shields[u.index].visible = u.alive and combat._abydos_shield(u) and not combat._done
	if redraw_orders:
		_draw_orders(combat)

func _draw_orders(combat: Node) -> void:
	orders.mesh = null
	if combat._done or combat.active < 0:
		return
	var u: Dictionary = combat.units[combat.active]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 0
	var previous: Vector3 = u.node.position
	for tile in u.rt_path:
		var point: Vector3 = combat.planet.tile_pos(tile)
		segments += _ribbon(surface, previous, point, Color(0.25, 0.8, 1.0))
		previous = point
	var foe: Dictionary = {} if u.kind == combat.work_kind else combat._target_for(u)
	if not foe.is_empty():
		var color := Color(1.0, 0.65, 0.2) if combat._dist(u.tile, foe.tile) <= u.range else Color(0.65, 0.65, 0.65)
		if not combat.line_of_fire(u, foe):
			color = Color(1.0, 0.25, 0.3)
		var start: Vector3 = u.node.position
		var end: Vector3 = foe.node.position
		var count := maxi(1, ceili(start.distance_to(end) / 0.65))
		for i in range(0, count, 2):
			segments += _ribbon(surface, start.lerp(end, float(i) / count), start.lerp(end, float(mini(i + 1, count)) / count), color)
	orders.mesh = surface.commit() if segments > 0 else null

func _ribbon(surface: SurfaceTool, from: Vector3, to: Vector3, color: Color) -> int:
	from.y = 0.11
	to.y = 0.11
	if from.distance_squared_to(to) < 0.001:
		return 0
	var side := (to - from).normalized().cross(Vector3.UP) * 0.055
	for vertex in [from - side, from + side, to + side, from - side, to + side, to - side]:
		surface.set_color(color)
		surface.add_vertex(vertex)
	return 1
