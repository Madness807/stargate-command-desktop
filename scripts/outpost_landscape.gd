extends RefCounted
## Paysage uniquement visuel : la grille RTS reste strictement inchangée.
const CENTER := Vector2(31, 23)
const EXTENT := Vector2(240, 232)
const STEP := 4.0


static func height_at(point: Vector2) -> float:
	var outside := maxf(absf(point.x - CENTER.x) - 32, absf(point.y - CENTER.y) - 24)
	var ramp := smoothstep(0.0, 28.0, outside)
	var hills := 7.0 + sin(point.x * 0.035 + point.y * 0.019) * 3.0
	hills += sin(point.y * 0.068 - point.x * 0.027) * 2.5
	return -0.05 + ramp * hills


static func build(material: Material) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns := int(EXTENT.x * 2 / STEP)
	var rows := int(EXTENT.y * 2 / STEP)
	for x in columns + 1:
		for z in rows + 1:
			var point := CENTER - EXTENT + Vector2(x, z) * STEP
			surface.set_uv(point)
			surface.add_vertex(Vector3(point.x, height_at(point), point.y))
	for x in columns:
		for z in rows:
			var a := x * (rows + 1) + z
			var b := a + rows + 1
			for index in [a, b, a + 1, b, b + 1, a + 1]:
				surface.add_index(index)
	surface.generate_normals()
	var ground := MeshInstance3D.new()
	ground.name = "ContinuousLandscape"
	ground.mesh = surface.commit()
	ground.material_override = material
	return ground
