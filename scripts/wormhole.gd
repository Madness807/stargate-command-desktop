extends Node3D
## Le trou de ver : un long tunnel animé par un shader, que la caméra parcourt.

var cam_anchor: Node3D


func _ready() -> void:
	var tube := CylinderMesh.new()
	tube.top_radius = 5.0
	tube.bottom_radius = 5.0
	tube.height = 400.0
	tube.radial_segments = 64
	tube.rings = 1
	tube.cap_top = false
	tube.cap_bottom = false
	var mi := MeshInstance3D.new()
	mi.mesh = tube
	mi.rotation_degrees.x = 90
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/wormhole.gdshader")
	mi.material_override = mat
	add_child(mi)
	# Lumière blanche au bout du tunnel
	var end := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 3.0
	sp.height = 6.0
	end.mesh = sp
	var em := StandardMaterial3D.new()
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	em.albedo_color = Color(1, 1, 1)
	em.emission_enabled = true
	em.emission = Color(0.9, 0.97, 1.0)
	em.emission_energy_multiplier = 8.0
	end.material_override = em
	end.position = Vector3(0, 0, -190)
	add_child(end)
	cam_anchor = Node3D.new()
	cam_anchor.position = Vector3(0, 0, 150)
	add_child(cam_anchor)
