extends Node3D
## Vue et commandes du prototype RTS. Aucun accès à Game : la campagne reste intacte.

const Sim = preload("res://scripts/outpost_sim.gd")
const People = preload("res://scripts/people.gd")
const Gate = preload("res://scripts/gate.gd")
const T = preload("res://scripts/ui_theme.gd")
const DebugHarness = preload("res://scripts/debug_harness.gd")
const Minimap = preload("res://scripts/outpost_minimap.gd")
const Overlay = preload("res://scripts/outpost_overlay.gd")
const Terrain = preload("res://scripts/terrain.gd")
const Assets = preload("res://scripts/outpost_assets.gd")
const Data = preload("res://scripts/data.gd")
const Cli = preload("res://scripts/cli.gd")
const Landscape = preload("res://scripts/outpost_landscape.gd")
const AncientConsole = preload("res://scripts/ancient_console.gd")
var ancient_console: Node3D

const SettingsMenu = preload("res://scripts/settings_menu.gd")

var sim: Sim
var cam: Camera3D
var focus := Vector3(19, 0, 34)
var distance := 38.0
var visuals := {}
var selected: Array = []
var build_kind := ""
var ghost: MeshInstance3D
var gate: Node3D
var ui: Control
var stats: Label
var objective: Label
var info: Label
var log_label: Label
var status: Label
var reinforcements: Button
var research_button: Button
var minimap: Control
var pause_button: Button
var build_buttons := {}
var logs: Array[String] = []
var paused := false
var pointer_start := Vector2.ZERO
var pointer_down := false
var dragging := false
var drag_select := false
var selection_rect: Panel
var _ui_clock := 0.0
var overlay: Control
var ground_material: ShaderMaterial
var intel_image: Image
var intel_texture: ImageTexture
var _intel_revision := -1
var decorations: Array[Dictionary] = []
var landmarks: Array[Dictionary] = []
var _last_gun := -10.0
var _last_staff := -10.0
var _last_attack_notice := -10.0
var deployment_button: Button
var skip_button: Button
var site_marker: Node3D
var cargo: Node3D
var malp: Node3D
var _gate_was_open := false
var _gate_opened_at := 0.0
var _lit_chevrons := 0
var _camera_motion: Tween
var building_panel: VBoxContainer
var construction_panel: VBoxContainer
var building_title: Label
var building_details: Label
var building_action: Button
var repair_button: Button
var recruit_buttons := {}
var squad_buttons := {}
var unit_panel: VBoxContainer
var unit_details: Label
var multi_select := false
var command_pages := {}
var command_tabs := {}
var command_tab := "base"
var recruit_reasons := {}
var pause_overlay: Control
var pause_body: VBoxContainer
var _pause_was_active := false
var _menu_page := ""
var _menu_dialog: Control
var _result_shown := false
var _undo_squads := {}
var multi_indicator: Label


func _ready() -> void:
	if sim == null:
		var options: Dictionary = Expedition.options()
		options["established"] = Cli.has("--rts-established")
		sim = Sim.new(options)
	add_child(DebugHarness.new(self))
	_build_world()
	_build_ui()
	sim.notice.connect(_notice)
	sim.shot.connect(_shot)
	sim.hit.connect(_hit)
	sim.phase_changed.connect(_on_phase)
	_select_all()
	_notice("SGC : composition de P3X-742. Première équipe autorisée à franchir la porte. Aucun avant-poste n'est encore installé." if sim.phase == "arrival" else "Avant-poste opérationnel. Le SGC fournit 4 ravitaillements par seconde.")
	_sync_visuals()
	_update_ui()


func _world(p: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(p.x * 2, y, p.y * 2)


func _mesh(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = People.mat(color)
	m.position = pos
	parent.add_child(m)
	return m


func _label3d(parent: Node3D, text: String, pos: Vector3, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = 36
	l.pixel_size = 0.013
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = color
	l.no_depth_test = true
	parent.add_child(l)
	return l


func _build_world() -> void:
	var we := WorldEnvironment.new()
	we.add_to_group("world_env")
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("819dba")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b2c5d3")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("819dba")
	env.fog_density = 0.0012
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.add_to_group("sun")
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.3
	add_child(sun)
	ground_material = ShaderMaterial.new()
	ground_material.shader = preload("res://shaders/outpost_ground.gdshader")
	ground_material.set_shader_parameter("grass_tex", _ground_texture("leafy_grass"))
	ground_material.set_shader_parameter("dirt_tex", _ground_texture("coast_sand_01"))
	add_child(Landscape.build(ground_material))
	intel_image = Image.create_empty(Sim.SIZE.x, Sim.SIZE.y, false, Image.FORMAT_RGBA8)
	intel_texture = ImageTexture.create_from_image(intel_image)
	ground_material.set_shader_parameter("intel_tex", intel_texture)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7319
	for i in 240:
		var near_border := i < 100
		var p := Vector3(rng.randf_range(-22, 84) if near_border else rng.randf_range(-100, 162), 0,
			rng.randf_range(-22, 68) if near_border else rng.randf_range(-100, 146))
		# Décor hors de l'aire jouable : ne gêne ni les déplacements ni le placement.
		if p.x > -5 and p.x < 67 and p.z > -5 and p.z < 51:
			continue
		# Garder dégagé le champ de la caméra rapprochée pendant le franchissement.
		if Vector2(p.x, p.z).distance_to(Vector2(15, 52)) < 20:
			continue
		_nature("Rock_Moss_1" if i % 5 == 0 else "CommonTree_2", rng.randf_range(2, 4) if i % 5 == 0 else rng.randf_range(5, 9), Vector2(p.x, p.z) / 2, rng, true)
	# Ces forêts et rochers bloquent réellement les déplacements, contrairement aux herbes.
	for area in Sim.TERRAIN:
		for x in range(area.position.x, area.end.x):
			for y in range(area.position.y, area.end.y):
				if (x + y) % 2 != 0:
					continue
				var rocky: bool = area.position.x >= 21
				_nature("Rock_Moss_1" if rocky else "CommonTree_2", 2.3 if rocky else 4.5,
					Vector2(x, y), rng)
	for i in 90:
		var p := Vector2(rng.randf_range(1, 30), rng.randf_range(1, 22))
		if sim.terrain_blocked(p) or p.distance_to(Sim.GATE) < 4 or p.distance_to(Vector2(8, 18)) < 3:
			continue
		_nature("Grass_Short" if i % 3 else "Bush_1", 0.25 if i % 3 else 0.55, p, rng)
	var platform := Assets.make("gate_platform")
	platform.position = _world(Sim.GATE)
	add_child(platform)
	cargo = Assets.make("supplies")
	cargo.position = _world(Sim.GATE + Vector2(-2, 2.5))
	cargo.visible = sim.phase == "base"
	add_child(cargo)
	gate = Gate.new()
	gate.position = _world(Sim.GATE, 3.6)
	add_child(gate)
	gate.set_iris(false, 0)
	_label3d(self, "PORTE · LIAISON SGC", _world(Sim.GATE, 8), T.BLUE)
	malp = _make_malp()
	add_child(malp)
	malp.visible = sim.phase != "arrival"
	malp.position = _world(Sim.GATE + Vector2(-2.4, 0.8))
	site_marker = Node3D.new()
	site_marker.position = _world(Sim.HQ_SITE, 0.03)
	add_child(site_marker)
	var ring := _mesh(site_marker, Gate.ring_mesh(4.4, 4.5, 0, -0.02, 48), T.AMBER, Vector3.ZERO)
	ring.rotation.x = -PI / 2
	_label3d(site_marker, "CLAIRIÈRE · SÉCURISER LE PÉRIMÈTRE", Vector3.UP * 3, T.AMBER)
	var deposit := Assets.make("deposit")
	deposit.position = _world(Sim.DEPOSIT)
	add_child(deposit)
	landmarks.append({"node": deposit, "pos": Sim.DEPOSIT})
	_label3d(deposit, "GISEMENT DE NAQUADAH", Vector3.UP * 4, T.GREEN)
	var ruins := Assets.make("ruins")
	ruins.position = _world(Sim.RUINS)
	add_child(ruins)
	ancient_console = AncientConsole.new()
	if ancient_console.build():
		ancient_console.position = Vector3(0, 0, 3.1)
		ruins.add_child(ancient_console)
	else:
		ancient_console.free()
		ancient_console = null
	landmarks.append({"node": ruins, "pos": Sim.RUINS})
	_label3d(ruins, "RUINES ANCIENNES", Vector3.UP * 4.6, T.AMBER)
	cam = Camera3D.new()
	cam.fov = 50
	cam.far = 230
	add_child(cam)
	cam.current = true
	_camera()
	ghost = _mesh(self, People.box(3.2, 0.1, 3.2), T.GREEN, Vector3.ZERO)
	ghost.visible = false
	_sync_intel()
	if sim.phase == "arrival" and DisplayServer.get_name() != "headless":
		Audio.loop_play("dial", -18)


func _make_malp() -> Node3D:
	var rover := Node3D.new()
	_mesh(rover, People.box(0.9, 0.35, 1.15), Color("626d5e"), Vector3(0, 0.38, 0))
	for x in [-0.5, 0.5]:
		for z in [-0.4, 0.4]:
			var wheel := _mesh(rover, People.cyl(0.23, 0.23, 0.17, 12), Color("252d30"), Vector3(x, 0.23, z))
			wheel.rotation.z = PI / 2
	_mesh(rover, People.cyl(0.035, 0.04, 0.9, 8), Color("929e9b"), Vector3(0, 0.95, 0))
	_mesh(rover, People.box(0.3, 0.22, 0.3), Color("38474d"), Vector3(0, 1.42, 0))
	_mesh(rover, People.ball(0.065), T.BLUE, Vector3(0, 1.42, 0.17))
	_label3d(rover, "MALP", Vector3.UP * 1.9, T.DIM)
	return rover


func _on_phase(next: String) -> void:
	if next == "recon":
		_select_all()
		var start_position := cam.position
		var start_target := _world(Sim.GATE, 2.5)
		var end_position := focus + Vector3(0.35, 0.85, 0.65).normalized() * distance
		_camera_motion = create_tween()
		_camera_motion.tween_method(func(t: float):
			cam.look_at_from_position(start_position.lerp(end_position, t), start_target.lerp(focus, t)), 0.0, 1.0, 1.0)
	_update_ui()


func _update_gate() -> void:
	var open := sim.gate_open() and sim.result == ""
	if sim.phase == "arrival" and not open:
		var n := mini(7, int(sim.arrival_clock / 0.24))
		if n > _lit_chevrons:
			for i in range(_lit_chevrons, n):
				gate.light_chevron(i)
			_lit_chevrons = n
			if DisplayServer.get_name() != "headless":
				Audio.play("lock")
	if open and not _gate_was_open:
		_gate_opened_at = sim.elapsed
		Audio.loop_stop("dial", 0.1)
		if DisplayServer.get_name() != "headless":
			Audio.play("kawoosh")
			Audio.loop_play("horizon", -20)
		for i in 7:
			gate.light_chevron(i)
	elif not open and _gate_was_open:
		Audio.loop_stop("horizon", 0.2)
		if DisplayServer.get_name() != "headless":
			Audio.play("close")
		gate.reset_chevrons()
	_gate_was_open = open
	gate.set_horizon(clampf((sim.elapsed - _gate_opened_at) / 1.2, 0, 1) if open else 0.0, 1.0 if open else 0.0)
	gate.set_ripple(0.4 if open else 0.0)
	if sim.phase == "arrival":
		malp.visible = sim.arrival_clock >= 3.0
		malp.position = _world(Sim.GATE).lerp(_world(Sim.GATE + Vector2(-2.4, 0.8)), clampf((sim.arrival_clock - 3.0) / 1.8, 0, 1))
	cargo.visible = sim.convoy_arrived() or sim.phase == "base"
	site_marker.visible = sim.phase != "base" and sim.result == ""


func _exit_tree() -> void:
	if _camera_motion:
		_camera_motion.kill()
		_camera_motion = null
	Audio.loop_stop("dial", 0.0)
	Audio.loop_stop("horizon", 0.0)


func _ground_texture(kind: String) -> ImageTexture:
	# Les textures liées en code ne déclenchent pas toujours la détection 3D de l'importeur.
	# Les mipmaps évitent le scintillement du sol en vue tactique.
	var image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/ground/%s_diff.jpg" % kind))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _nature(kind: String, height: float, point: Vector2, rng: RandomNumberGenerator, always_visible: bool = false) -> void:
	var model: Array = Terrain.model(kind)
	var bounds: AABB = model[1]
	var scale_model := height / maxf(bounds.size.y, 0.01)
	var root := Node3D.new()
	root.position = _world(point)
	if always_visible:
		root.position.y = Landscape.height_at(point * 2)
	root.rotation.y = rng.randf_range(0, TAU)
	add_child(root)
	var mi := MeshInstance3D.new()
	mi.mesh = model[0]
	if always_visible and point.distance_to(Vector2(15.5, 11.5)) > 35:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = Transform3D(Basis().scaled(Vector3.ONE * scale_model),
		Vector3(0, -bounds.position.y * scale_model, 0)) * (model[2] as Transform3D)
	root.add_child(mi)
	decorations.append({"node": root, "pos": point, "always_visible": always_visible})


func _sync_intel() -> void:
	if _intel_revision == sim.vision_revision:
		return
	_intel_revision = sim.vision_revision
	for y in Sim.SIZE.y:
		for x in Sim.SIZE.x:
			var index := y * Sim.SIZE.x + x
			intel_image.set_pixel(x, y, Color(sim.explored_cells[index], sim.visible_cells[index], 0))
	intel_texture.update(intel_image)
	for item in decorations:
		item.node.visible = item.always_visible or sim.is_explored(item.pos)
	for item in landmarks:
		item.node.visible = sim.is_explored(item.pos)


func _camera() -> void:
	if overlay != null:
		overlay.queue_redraw()
	if _camera_motion:
		_camera_motion.kill()
	if sim.phase == "arrival":
		cam.look_at_from_position(_world(Sim.GATE) + Vector3(7, 5, 14), _world(Sim.GATE, 2.5))
		return
	focus.x = clampf(focus.x, 0, 62)
	focus.z = clampf(focus.z, 0, 46)
	cam.look_at_from_position(focus + Vector3(0.35, 0.85, 0.65).normalized() * distance, focus)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = T.make()
	layer.add_child(ui)
	overlay = Overlay.new()
	overlay.view = self
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)
	var top := PanelContainer.new()
	top.theme_type_variation = "Bar"
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	ui.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	top.add_child(row)
	row.add_child(T.label("P3X-742", "Section", T.AMBER))
	stats = T.wrap(T.label("", "Mono"))
	stats.add_theme_font_size_override("font_size", 18)
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(stats)
	pause_button = T.button("PAUSE", _menu, "Ghost")
	row.add_child(pause_button)
	row.add_child(T.button("MENU", _menu, "Ghost"))
	var left_panel := PanelContainer.new()
	left_panel.position = Vector2(16, 84)
	left_panel.anchor_bottom = 1
	left_panel.offset_bottom = -174
	left_panel.offset_right = 286
	ui.add_child(left_panel)
	var left_scroll := ScrollContainer.new()
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_scroll.follow_focus = true
	left_panel.add_child(left_scroll)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	left_scroll.add_child(left)
	left.add_child(T.label("OPÉRATION IMPLANTATION", "Section"))
	objective = T.wrap(T.label("", "Body"))
	left.add_child(objective)
	left.add_child(T.label("TRANSMISSIONS", "Section"))
	log_label = T.wrap(T.label("", "Body"))
	log_label.add_theme_font_size_override("font_size", 19)
	left.add_child(log_label)
	var right_panel := PanelContainer.new()
	right_panel.add_theme_stylebox_override("panel", T.box(T.BG, T.LINE, 10, 1, 10))
	right_panel.anchor_left = 1
	right_panel.anchor_right = 1
	right_panel.offset_left = -286
	right_panel.offset_right = -16
	right_panel.offset_top = 84
	right_panel.anchor_bottom = 1
	right_panel.offset_bottom = -354
	ui.add_child(right_panel)
	var right_frame := VBoxContainer.new()
	right_panel.add_child(right_frame)
	var tabs := HFlowContainer.new()
	right_frame.add_child(tabs)
	for entry in [["base", "BASE"], ["sgc", "SGC"], ["selection", "UNITÉS"]]:
		var key: String = entry[0]
		var tab_button := T.button(entry[1], func(): _show_command_tab(key), "Ghost")
		tab_button.toggle_mode = true
		tab_button.add_theme_font_size_override("font_size", 17)
		tab_button.custom_minimum_size.y = 44
		tabs.add_child(tab_button)
		command_tabs[key] = tab_button
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.follow_focus = true
	right_frame.add_child(scroll)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	scroll.add_child(right)
	var phase_commands := VBoxContainer.new()
	right.add_child(phase_commands)
	for key in ["base", "sgc", "selection"]:
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 6)
		right.add_child(page)
		command_pages[key] = page
	var selection_page: VBoxContainer = command_pages.selection
	var sgc_page: VBoxContainer = command_pages.sgc
	var squad_section := VBoxContainer.new()
	squad_section.visible = false
	var squad_toggle := T.button("ESCOUADES ▸", func(): squad_section.visible = not squad_section.visible, "Ghost")
	squad_toggle.toggle_mode = true
	selection_page.add_child(squad_toggle)
	selection_page.add_child(squad_section)
	var multi_button := CheckButton.new()
	multi_button.text = "Sélection multiple"
	multi_button.add_theme_font_size_override("font_size", 19)
	multi_button.toggled.connect(func(enabled: bool): multi_select = enabled)
	squad_section.add_child(multi_button)
	squad_section.add_child(T.button("Toute l'équipe", _select_team, "Ghost"))
	for slot in [1, 2, 3]:
		var number: int = slot
		var squad_row := HBoxContainer.new()
		squad_section.add_child(squad_row)
		var recall := T.button("", func(): _recall_squad(number), "Ghost")
		recall.add_theme_font_size_override("font_size", 18)
		recall.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		squad_row.add_child(recall)
		squad_buttons[number] = recall
		var save := T.button("Mémoriser", func(): _save_squad(number), "Ghost")
		save.add_theme_font_size_override("font_size", 17)
		squad_row.add_child(save)
	squad_section.add_child(T.button("Annuler la dernière affectation", _undo_squad, "Ghost"))
	unit_panel = VBoxContainer.new()
	unit_panel.add_theme_constant_override("separation", 6)
	selection_page.add_child(unit_panel)
	unit_panel.add_child(T.label("ÉQUIPE AU SOL", "Section", T.AMBER))
	unit_details = T.wrap(T.label("", "Body"))
	unit_details.add_theme_font_size_override("font_size", 18)
	unit_panel.add_child(unit_details)
	unit_panel.add_child(T.button("Halte / travailler ici", _halt_units, "Ghost"))
	building_panel = VBoxContainer.new()
	building_panel.add_theme_constant_override("separation", 8)
	selection_page.add_child(building_panel)
	building_title = T.label("", "Section", T.AMBER)
	building_panel.add_child(building_title)
	building_details = T.wrap(T.label("", "Body"))
	building_details.add_theme_font_size_override("font_size", 19)
	building_panel.add_child(building_details)
	building_action = T.button("", _building_action, "Accent")
	building_action.add_theme_font_size_override("font_size", 19)
	building_panel.add_child(building_action)
	repair_button = T.button("", _repair_building)
	repair_button.add_theme_font_size_override("font_size", 19)
	building_panel.add_child(repair_button)
	building_panel.add_child(T.button("Centrer ce bâtiment", _center_building, "Ghost"))
	building_panel.add_child(T.button("Constructions", func(): _show_command_tab("base"), "Ghost"))
	construction_panel = VBoxContainer.new()
	construction_panel.add_theme_constant_override("separation", 6)
	command_pages.base.add_child(construction_panel)
	construction_panel.add_child(T.label("CONSTRUCTION", "Section"))
	for kind in ["generator", "turret", "infirmary", "lab", "mine"]:
		var key: String = kind
		var d: Dictionary = Sim.BUILDINGS[key]
		var b := T.button("%s · %d R" % [d.name, d.cost], func(): _choose_build(key))
		b.add_theme_font_size_override("font_size", 19)
		b.icon = Assets.icon(key)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 32)
		b.tooltip_text = "Durée : %d s · Énergie : %s" % [d.time, "+8" if d.power < 0 else str(-d.power)]
		construction_panel.add_child(b)
		build_buttons[key] = b
	construction_panel.add_child(T.button("Annuler le placement", _cancel_build, "Ghost"))
	sgc_page.add_child(T.label("LIAISON SGC", "Section"))
	skip_button = T.button("Passer la mise en scène", func(): sim.skip_arrival(), "Ghost")
	skip_button.add_theme_font_size_override("font_size", 19)
	phase_commands.add_child(skip_button)
	deployment_button = T.button("Appeler le déploiement", func(): sim.request_deployment(), "Accent")
	deployment_button.add_theme_font_size_override("font_size", 19)
	phase_commands.add_child(deployment_button)
	reinforcements = T.button("3 soldats · 85 R", func(): sim.reinforce())
	sgc_page.add_child(reinforcements)
	research_button = T.button("Munitions +40 % · 30 N", func(): sim.research())
	research_button.add_theme_font_size_override("font_size", 20)
	command_pages.base.add_child(research_button)
	sgc_page.add_child(T.label("SPÉCIALISTES", "Section"))
	var requirements := T.wrap(T.label("Médecin : infirmerie\nScientifique : laboratoire\nIngénieur : commandement", "Body", T.DIM))
	requirements.add_theme_font_size_override("font_size", 17)
	sgc_page.add_child(requirements)
	for kind in Sim.SPECIALISTS:
		var key: String = kind
		var spec: Dictionary = Sim.SPECIALISTS[key]
		var recruit_button := T.button("%s · %d R" % [spec.name, spec.cost], func(): _recruit(key))
		recruit_button.add_theme_font_size_override("font_size", 19)
		sgc_page.add_child(recruit_button)
		recruit_buttons[key] = recruit_button
		var reason := T.wrap(T.label("", "Body", T.DIM))
		reason.add_theme_font_size_override("font_size", 17)
		sgc_page.add_child(reason)
		recruit_reasons[key] = reason
	var map_panel := PanelContainer.new()
	map_panel.anchor_left = 1
	map_panel.anchor_right = 1
	map_panel.anchor_top = 1
	map_panel.anchor_bottom = 1
	map_panel.offset_left = -286
	map_panel.offset_right = -16
	map_panel.offset_top = -342
	map_panel.offset_bottom = -174
	ui.add_child(map_panel)
	minimap = Minimap.new()
	minimap.view = self
	minimap.custom_minimum_size = Vector2(220, 128)
	minimap.mouse_filter = Control.MOUSE_FILTER_STOP
	map_panel.add_child(minimap)
	var bottom := PanelContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_top = -12
	bottom.offset_left = 16
	bottom.offset_right = -16
	bottom.offset_bottom = -12
	ui.add_child(bottom)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 4)
	bottom.add_child(bv)
	status = T.wrap(T.label("", "Section"))
	bv.add_child(status)
	info = T.wrap(T.label("", "Body"))
	info.add_theme_font_size_override("font_size", 18)
	bv.add_child(info)
	var commands := HFlowContainer.new()
	commands.add_theme_constant_override("h_separation", 10)
	commands.add_theme_constant_override("v_separation", 6)
	bv.add_child(commands)
	commands.add_child(T.button("Tous les soldats", _select_all))
	commands.add_child(T.button("Repli à la porte", func(): sim.order(selected, Sim.GATE + Vector2(1, 3))))
	command_pages.base.add_child(T.button("Centrer la base", func(): focus = _world(Vector2(9, 17)); _camera(), "Ghost"))
	commands.add_child(T.button("+", func(): _zoom(-5), "Ghost"))
	commands.add_child(T.button("−", func(): _zoom(5), "Ghost"))
	multi_indicator = T.wrap(T.label("", "Body", T.AMBER))
	multi_indicator.add_theme_font_size_override("font_size", 17)
	bv.add_child(multi_indicator)
	selection_rect = Panel.new()
	selection_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection_rect.add_theme_stylebox_override("panel", T.box(Color(T.BLUE, 0.12), T.BLUE, 0, 1, 0))
	selection_rect.visible = false
	ui.add_child(selection_rect)
	var fit := func():
		var footer_height := bottom.size.y
		var compact := ui.size.y < 650
		var map_height := 120 if compact else 144
		map_panel.anchor_left = 0 if compact else 1
		map_panel.anchor_right = 0 if compact else 1
		map_panel.offset_left = 16 if compact else -286
		map_panel.offset_right = 286 if compact else -16
		map_panel.offset_bottom = -footer_height - 24
		map_panel.offset_top = map_panel.offset_bottom - map_height
		right_panel.offset_bottom = map_panel.offset_bottom if compact else map_panel.offset_top - 12
		left_panel.offset_bottom = map_panel.offset_top - 12 if compact else map_panel.offset_bottom
		minimap.custom_minimum_size.y = map_height - 36
	bottom.resized.connect(fit)
	ui.resized.connect(fit)
	fit.call_deferred()
	_show_command_tab("base")


func _panel(pos: Vector2, minimum: Vector2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.custom_minimum_size = minimum
	ui.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	return v


func _notice(text: String) -> void:
	logs.append(text)
	while logs.size() > 4:
		logs.pop_front()
	log_label.text = "\n\n".join(logs)


func _selected_building() -> Dictionary:
	if selected.size() != 1:
		return {}
	var e := sim.entity(selected[0])
	if e.is_empty() or e.side != "sgc" or not Sim.BUILDINGS.has(e.kind):
		return {}
	return e


func _recruit(kind: String) -> void:
	if not paused:
		sim.recruit(kind)
		_update_ui()


func _show_command_tab(tab: String) -> void:
	command_tab = tab
	for key in command_pages:
		command_pages[key].visible = key == tab
		command_tabs[key].set_pressed_no_signal(key == tab)
		command_tabs[key].theme_type_variation = "Accent" if key == tab else "Ghost"
	construction_panel.visible = tab == "base"
	# Le tactile ne doit jamais rester en mode ajout après avoir quitté les unités.
	if tab != "selection":
		multi_select = false
		for check_button in command_pages.selection.find_children("*", "CheckButton", true, false):
			check_button.set_pressed_no_signal(false)
	if is_instance_valid(multi_indicator):
		multi_indicator.text = ""


func _save_squad(slot: int) -> void:
	if selected.is_empty():
		sim.assign_squad(slot, selected)
		return
	_undo_squads = {"slot": slot, "members": sim.squad_members(slot)}
	sim.assign_squad(slot, selected)
	_update_ui()


func _undo_squad() -> void:
	if _undo_squads.is_empty():
		_notice("Aucune affectation à annuler.")
		return
	sim.squads[_undo_squads.slot] = _undo_squads.members.duplicate()
	_undo_squads.clear()
	_notice("Affectation d'escouade annulée.")
	_update_ui()


func _recall_squad(slot: int) -> void:
	var members := sim.squad_members(slot)
	if not members.is_empty():
		selected = members
		_cancel_build()
		_show_command_tab("selection")
	_update_ui()


func _select_team() -> void:
	selected.clear()
	for e in sim.entities:
		if e.side == "sgc" and e.hp > 0 and not sim.is_building(e):
			selected.append(e.id)
	_cancel_build()


func _halt_units() -> void:
	if paused or sim.result != "":
		return
	for id in selected:
		var e := sim.entity(id)
		if not e.is_empty() and e.side == "sgc" and not sim.is_building(e):
			e.path.clear()
			e.goal = e.pos
			e.target = -1
			e.moving = false
	_update_ui()


func _update_unit_panel() -> void:
	var lines: Array[String] = []
	var roles := {
		"soldier": "Soldat · combat et reconnaissance",
		"engineer": "Ingénieur · répare à 3 cases : 5 PV/s pour 1 R/s, à l'arrêt",
		"medic": "Médecin · soigne à 3 cases : 6 PV/s, à l'arrêt",
		"scientist": "Scientifique · étudie les ruines en 12 s, à l'arrêt",
	}
	var counts := {}
	for id in selected:
		var e := sim.entity(id)
		if not e.is_empty() and roles.has(e.kind):
			counts[e.kind] = counts.get(e.kind, 0) + 1
	for kind in counts:
		lines.append("%d × %s" % [counts[kind], roles[kind]])
	if counts.has("scientist"):
		lines.append("Étude terminée ✓" if sim.ruins_studied else "Étude des Anciens : %d / 12 s" % sim.ruins_study)
	unit_panel.visible = not lines.is_empty()
	unit_details.text = "\n\n".join(lines)
	multi_indicator.text = "SÉLECTION MULTIPLE ACTIVE · touchez une unité pour l'ajouter / la retirer" if multi_select else ""
	multi_indicator.visible = multi_select
	for slot in squad_buttons:
		var members := sim.squad_members(slot)
		squad_buttons[slot].text = "SG-%d · %d" % [slot, members.size()]
		squad_buttons[slot].disabled = members.is_empty()
	for kind in recruit_buttons:
		var error: String = sim.recruit_error(kind)
		recruit_buttons[kind].disabled = paused or error != ""
		recruit_buttons[kind].tooltip_text = error if error != "" else "Arrivée par la porte en 10 secondes."
		recruit_reasons[kind].text = error if error != "" else "Porte : arrivée en 10 s"


func _update_building_panel() -> void:
	var e := _selected_building()
	building_panel.visible = not e.is_empty()
	construction_panel.visible = command_tab == "base"
	if e.is_empty():
		return
	var descriptions := {
		"hq": "Liaison SGC : +4 ravitaillements/s. Permet l'arrivée des renforts par la porte.",
		"generator": "Production automatique : +8 énergie. Alimente les installations de la base.",
		"turret": "Défense automatique : ouvre le feu sur les ennemis à portée. Consomme 2 énergie.",
		"infirmary": "Soins automatiques : +5 PV/s aux soldats et ingénieurs à moins de 5 cases. Consomme 2 énergie.",
		"lab": "Recherche : améliore de 40 % les dégâts des soldats et tourelles. Consomme 3 énergie.",
		"mine": "Extraction automatique : +2 naquadah/s. Consomme 3 énergie.",
	}
	var operational: bool = e.build <= 0 and (Sim.BUILDINGS[e.kind].power <= 0 or sim.powered())
	var state := "OPÉRATIONNEL" if operational else "ÉNERGIE INSUFFISANTE"
	if e.build > 0:
		state = "CONSTRUCTION · %d %% · %ds" % [100 * (1.0 - e.build / Sim.BUILDINGS[e.kind].time), ceili(e.build)]
	building_title.text = Sim.BUILDINGS[e.kind].name.to_upper()
	building_details.text = "%d / %d PV\n%s\n\n%s" % [e.hp, e.max_hp, state, descriptions[e.kind]]
	var blocked := paused or sim.result != "" or not operational
	building_action.visible = e.kind in ["hq", "lab", "infirmary"]
	building_action.disabled = blocked
	match e.kind:
		"hq":
			building_action.text = "Convoi en cours…" if sim.gate_busy() else "3 soldats · 85 R"
			building_action.disabled = blocked or sim.gate_busy() or sim.supplies < 85 or sim.count("soldier") > 17 or sim.phase != "base"
		"lab":
			building_action.text = "Munitions améliorées ✓" if sim.researched else "Munitions +40 % · 30 N"
			building_action.disabled = blocked or sim.researched or sim.naquadah < 30
		"infirmary":
			building_action.text = "Rappeler les blessés"
			building_action.disabled = blocked or _wounded_units().is_empty()
	var cost := sim.repair_cost(e.id)
	repair_button.text = "Réparer · %d R" % cost if cost > 0 else ("Réparation après chantier" if e.build > 0 else "Bâtiment intact ✓")
	repair_button.disabled = paused or sim.result != "" or sim.phase != "base" or cost <= 0 or sim.supplies < cost


func _wounded_units() -> Array:
	var ids: Array = []
	for e in sim.entities:
		if e.side == "sgc" and not sim.is_building(e) and e.hp > 0 and e.hp < e.max_hp:
			ids.append(e.id)
	return ids


func _building_action() -> void:
	var e := _selected_building()
	if e.is_empty() or paused or sim.result != "" or e.build > 0:
		return
	match e.kind:
		"hq": sim.reinforce()
		"lab": sim.research()
		"infirmary":
			if sim.powered():
				sim.order(_wounded_units(), e.pos + Vector2(0, 2))
				_notice("Les blessés rejoignent l'infirmerie pour recevoir des soins.")
	_update_ui()


func _repair_building() -> void:
	var e := _selected_building()
	if not e.is_empty() and not paused:
		sim.repair(e.id)
		_update_ui()


func _center_building() -> void:
	var e := _selected_building()
	if not e.is_empty():
		focus = _world(e.pos)
		_camera()


func _choose_build(kind: String) -> void:
	if sim.phase != "base" or paused:
		return
	build_kind = kind
	_show_command_tab("base")
	_notice("%s : touchez un emplacement près de la base%s." % [Sim.BUILDINGS[kind].name,
		" (sur le gisement pour l'extracteur)" if kind == "mine" else ""])
	_update_ui()


func _cancel_build() -> void:
	build_kind = ""
	ghost.visible = false
	_update_ui()


func _select_all() -> void:
	selected.clear()
	for e in sim.entities:
		if e.kind == "soldier" and e.hp > 0:
			selected.append(e.id)
	build_kind = ""


func _toggle_pause() -> void:
	paused = not paused
	if _camera_motion and _camera_motion.is_valid():
		if paused:
			_camera_motion.pause()
		else:
			_camera_motion.play()
	pause_button.text = "REPRENDRE" if paused else "PAUSE"
	_update_ui()


func _menu() -> void:
	if is_instance_valid(pause_overlay):
		return
	_pause_was_active = paused
	if not paused:
		_toggle_pause()
	pointer_down = false
	selection_rect.visible = false
	pause_overlay = Control.new()
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(pause_overlay)
	var veil := ColorRect.new()
	veil.color = Color(0.01, 0.02, 0.03, 0.9)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.add_child(veil)
	pause_body = T.modal(pause_overlay, 660)
	_menu_main()


func _menu_clear(page: String) -> void:
	_menu_page = page
	for child in pause_body.get_children():
		pause_body.remove_child(child)
		child.queue_free()


func _menu_main() -> void:
	_menu_clear("main")
	var ended := sim.result != ""
	pause_body.add_child(T.label("VICTOIRE" if sim.result == "victory" else ("EXPÉDITION PERDUE" if ended else "OPÉRATION SUSPENDUE"), "Heading"))
	if ended:
		pause_body.add_child(T.wrap(T.label("Durée : %d min %02d s · Vagues : %d\nSurvivants : %d soldats, %d spécialistes\nStocks : %d ravitaillements · %d naquadah" % [int(sim.elapsed) / 60, int(sim.elapsed) % 60, sim.wave, sim.count("soldier"), sim.count("medic") + sim.count("scientist") + sim.count("engineer"), sim.supplies, sim.naquadah], "Body")))
	else:
		pause_body.add_child(T.wrap(T.label("Opération P3X-742 · Simulation suspendue. Partie non sauvegardée.", "Body", T.DIM)))
	var resume := T.button("Observer le terrain" if ended else "Reprendre", _close_menu, "Accent")
	pause_body.add_child(resume)
	resume.grab_focus()
	pause_body.add_child(T.button("Options", _menu_options, "Nav"))
	pause_body.add_child(T.button("Commandes", _menu_controls, "Nav"))
	pause_body.add_child(T.button("Recommencer", _restart, "Ghost"))
	pause_body.add_child(T.button("Quitter l'expédition", _confirm_quit, "Danger"))


func _close_menu() -> void:
	if not is_instance_valid(pause_overlay):
		return
	pause_overlay.queue_free()
	pause_overlay = null
	_menu_dialog = null
	if not _pause_was_active and paused:
		_toggle_pause()
	_update_ui()


func _menu_options() -> void:
	_menu_page = "options"
	pause_body.get_parent().get_parent().hide()
	_menu_dialog = SettingsMenu.new()
	_menu_dialog.closed.connect(func():
		_menu_dialog = null
		pause_body.get_parent().get_parent().show()
		_menu_main())
	pause_overlay.add_child(_menu_dialog)


func _menu_controls() -> void:
	_menu_clear("controls")
	pause_body.add_child(T.label("COMMANDES RTS", "Heading"))
	pause_body.add_child(T.wrap(T.label("TACTILE\nTouchez une unité, puis le terrain pour avancer ou un ennemi pour attaquer. Glissez pour déplacer la caméra ; utilisez + / − pour zoomer. La mini-carte reste accessible.\n\nBASE / SGC / UNITÉS\nConstruction, recrutement par la porte, puis options de la sélection et escouades. Dans UNITÉS, activez Sélection multiple pour composer une équipe. Mémorisez-la dans SG-1, SG-2 ou SG-3.\n\nSPÉCIALISTES\nMédecin : soins à proximité. Ingénieur : réparation avec du ravitaillement. Scientifique : étude des ruines. Placez-les à portée, puis « Halte / travailler ici ».\n\nSOURIS ET CLAVIER\nGlisser gauche : sélectionner · clic droit : ordre · milieu : caméra · molette : zoom.\nFlèches / ZQSD / WASD : caméra · 1–3 : escouades · Maj+1–3 : mémoriser · Espace : soldats · Échap : menu ou annulation du placement.", "Body")))
	pause_body.add_child(T.button("Retour", _menu_main, "Ghost"))


func _confirm_quit() -> void:
	_menu_clear("confirm")
	pause_body.add_child(T.label("QUITTER L'EXPÉDITION ?", "Section"))
	pause_body.add_child(T.wrap(T.label("Cette opération n'est pas sauvegardée. Quitter abandonne la base et les unités déployées.", "Body")))
	pause_body.add_child(T.button("Retour à la préparation", func(): get_tree().change_scene_to_file.call_deferred("res://outpost_menu.tscn"), "Danger"))
	var cancel := T.button("Annuler", _menu_main, "Ghost")
	pause_body.add_child(cancel)
	cancel.grab_focus()


func _restart() -> void:
	_menu()
	_menu_clear("confirm")
	pause_body.add_child(T.label("RECOMMENCER ?", "Heading"))
	pause_body.add_child(T.wrap(T.label("Cette expédition sera remplacée par une nouvelle partie depuis l'arrivée de l'équipe SG.", "Body")))
	pause_body.add_child(T.button("Recommencer", func(): get_tree().reload_current_scene.call_deferred(), "Danger"))
	var cancel := T.button("Annuler", _menu_main, "Ghost")
	pause_body.add_child(cancel)
	cancel.grab_focus()


func _zoom(amount: float) -> void:
	distance = clampf(distance + amount, 22, 80)
	_camera()


func _process(delta: float) -> void:
	# Une suspension ne doit pas rattraper des secondes de combat à la reprise.
	if delta > 1.0 and not paused:
		_toggle_pause()
	if not paused:
		var remaining := delta
		while remaining > 0.000001 and not paused:
			var step := minf(remaining, 0.1)
			sim.tick(step)
			overlay.advance(step)
			remaining -= step
	_sync_intel()
	if pointer_down and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		pointer_down = false
		selection_rect.visible = false
	_sync_visuals()
	var direction := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_Q):
		direction.x -= 1
	if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		direction.x += 1
	if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_Z):
		direction.z -= 1
	if Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S):
		direction.z += 1
	if direction != Vector3.ZERO and not is_instance_valid(pause_overlay):
		focus += direction.normalized() * delta * 24 * Settings.value("cam_speed") / 100.0
		_camera()
	_ui_clock += delta
	if _ui_clock > 0.2:
		_ui_clock = 0
		_update_ui()
	ghost.visible = build_kind != "" and not paused and sim.result == ""
	ground_material.set_shader_parameter("show_grid", ghost.visible)
	if ghost.visible:
		var p := _ground(get_viewport().get_mouse_position()).round()
		ghost.position = _world(p, 0.08)
		ghost.material_override = People.mat(T.GREEN if sim.build_error(build_kind, p) == "" else T.RED)
	_update_gate()


func _update_ui() -> void:
	if is_instance_valid(ancient_console) and sim.ruins_studied:
		ancient_console.activate()
	minimap.queue_redraw()
	var p := sim.power()
	stats.text = "R %d   N %d   ÉNERGIE %d/%d   %s" % [sim.supplies, sim.naquadah, p.x, p.y, "RAID %ds" % maxf(0, sim.raid_in) if sim.phase == "base" else "DÉPLOIEMENT SG"]
	stats.add_theme_color_override("font_color", T.TEXT if sim.powered() else T.RED)
	objective.text = "%s Alimenter la base\n%s %s\n%s %s" % [
		"✓" if sim.count("generator") > 0 else "○", "✓" if sim.count("mine") > 0 else "○",
		"Exploiter le gisement" if sim.deposit_found else "Reconnaître le nord-est",
		"✓" if sim.count("camp") == 0 else "○", "Neutraliser le camp goa'uld" if sim.camp_found else "Localiser le camp goa'uld"]
	if sim.phase == "arrival":
		objective.text = "1 / 4 · PREMIER FRANCHISSEMENT\nComposition, activation de la porte, MALP puis première équipe SG.\nAucune base n'est encore installée."
	elif sim.phase == "recon":
		objective.text = "2 / 4 · TÊTE DE PONT\n%s Reconnaître la clairière balisée\n%s Sécuriser le périmètre\nPuis appeler le déploiement du SGC." % ["✓" if sim.landing_scanned else "○", "✓" if sim.landing_secure() else "○"]
	elif sim.phase in ["deployment", "establish"]:
		objective.text = "3 / 4 · INSTALLATION\nProtégez le passage et les ingénieurs.\nGardez-les près du chantier jusqu'à la mise en service du commandement."
	selected = selected.filter(func(id): return not sim.entity(id).is_empty())
	if selected.is_empty() and command_tab == "selection":
		_show_command_tab("base")
	var soldiers := 0
	var engineers := 0
	var health := 0
	for id in selected:
		var e := sim.entity(id)
		if e.kind == "soldier":
			soldiers += 1
			health += int(e.hp)
		elif e.kind == "engineer":
			engineers += 1
			health += int(e.hp)
	info.text = "%d soldats sélectionnés · %d PV cumulés · %d soldats sur la planète" % [soldiers, health, sim.count("soldier")]
	if engineers > 0:
		info.text = "%d soldats · %d ingénieurs sélectionnés · %d PV · Les ingénieurs construisent le premier poste." % [soldiers, engineers, health]
	if selected.any(func(id): return Sim.SPECIALISTS.has(sim.entity(id).kind)):
		var total_hp := 0
		for id in selected:
			total_hp += int(sim.entity(id).hp)
		info.text = "%d unités sélectionnées · %d PV · Rôles et ordres dans le panneau de droite" % [selected.size(), total_hp]
	if selected.size() == 1:
		var e := sim.entity(selected[0])
		if sim.is_building(e):
			info.text = "%s · %d/%d PV%s" % [Sim.BUILDINGS[e.kind].name, e.hp, e.max_hp,
				" · Chantier : %ds" % e.build if e.build > 0 else ""]
	var ended := sim.result != ""
	if ended and not _result_shown:
		_result_shown = true
		_menu.call_deferred()
	status.text = "VICTOIRE · PLANÈTE SÉCURISÉE" if sim.result == "victory" else (
		"DÉFAITE · EXPÉDITION PERDUE" if ended else ("PAUSE" if paused else (
		"PLACEMENT : %s" % Sim.BUILDINGS[build_kind].name.to_upper() if build_kind != "" else "COMMANDEMENT TACTIQUE · PROTOTYPE")))
	if not sim.powered() and not ended:
		status.text += " · ÉNERGIE INSUFFISANTE : installations arrêtées"
	if not ended and not paused and sim.phase != "base":
		status.text = {"arrival": "ARRIVÉE PAR LA PORTE · PREMIÈRE ÉQUIPE", "recon": "RECONNAISSANCE · PAS ENCORE D'AVANT-POSTE", "deployment": "DÉPLOIEMENT DU SGC", "establish": "PROTÉGEZ LE CHANTIER"}[sim.phase]
	skip_button.visible = sim.phase == "arrival"
	skip_button.disabled = paused
	deployment_button.visible = sim.phase != "base"
	deployment_button.disabled = paused or ended or sim.phase != "recon" or not sim.landing_secure() or sim.gate_busy()
	deployment_button.text = "Convoi : %ds" % sim.gate_in if sim.phase == "deployment" and sim.gate_in > 0 else ("Installation du poste…" if sim.phase == "establish" else "Appeler le déploiement")
	reinforcements.text = "Porte occupée · %ds" % sim.gate_in if sim.gate_in > 0 else "3 soldats · 85 R"
	reinforcements.disabled = paused or ended or sim.phase != "base" or sim.gate_busy() or sim.supplies < 85 or sim.count("soldier") > 17
	research_button.text = "Munitions améliorées ✓" if sim.researched else "Munitions +40 % · 30 N"
	research_button.disabled = paused or ended or sim.researched or sim.count("lab") == 0 or sim.naquadah < 30 or not sim.powered()
	for key in build_buttons:
		build_buttons[key].disabled = paused or ended or sim.phase != "base" or sim.supplies < Sim.BUILDINGS[key].cost
	_update_building_panel()
	_update_unit_panel()


func _sync_visuals() -> void:
	var live := {}
	for e in sim.entities:
		live[e.id] = true
		if not visuals.has(e.id):
			_create_visual(e)
		var v: Dictionary = visuals[e.id]
		var node: Node3D = v.node
		node.visible = sim.entity_visible(e)
		node.process_mode = Node.PROCESS_MODE_DISABLED if paused or sim.result != "" else Node.PROCESS_MODE_INHERIT
		var destination := _world(e.pos)
		if not sim.is_building(e) and e.pos.distance_to(Sim.GATE) < 1.5:
			destination.y = 0.23
		var movement := destination - node.position
		if not sim.is_building(e):
			if movement.length_squared() > 0.0001:
				node.rotation.y = atan2(movement.x, movement.z)
			node.walking = e.moving and not paused and sim.result == ""
		node.position = destination
		v.ring.visible = selected.has(e.id)
		var label: Label3D = v.label
		label.text = "%s%s" % [v.name, "\nChantier : %ds" % e.build if e.build > 0 else ""]
		label.visible = sim.is_building(e) or selected.has(e.id) or e.side == "enemy"
		label.modulate = T.RED if v.hit_until > sim.elapsed else (T.BLUE if e.side == "sgc" else T.RED)
		if sim.is_building(e):
			v.model.visible = e.build <= 0
			if v.site:
				v.site.visible = e.build > 0
			if v.damage:
				v.damage.visible = e.build <= 0 and e.hp < e.max_hp * 0.5
			if e.build <= 0 and sim.powered():
				if v.rotor:
					v.rotor.rotation.y = sim.elapsed * 7
				if v.drill:
					v.drill.rotation.y = sim.elapsed * 1.4
	for id in visuals.keys():
		if not live.has(id):
			var v: Dictionary = visuals[id]
			if v.node.visible and v.destroyed:
				v.label.visible = false
				v.ring.visible = false
				if v.node.has_method("fall"):
					v.node.fall()
				var tween := create_tween()
				tween.tween_interval(0.6)
				tween.tween_property(v.node, "scale", Vector3.ONE * 0.01, 0.3)
				tween.tween_callback(v.node.queue_free)
			else:
				v.node.queue_free()
			visuals.erase(id)


func _create_visual(e: Dictionary) -> void:
	var node: Node3D
	var caption := ""
	var color := T.BLUE if e.side == "sgc" else T.RED
	var aim: Node3D
	var model: Node3D
	var site: Node3D
	var damage: Node3D
	var rotor: Node3D
	var drill: Node3D
	var label_height := 2.8
	if not sim.is_building(e):
		node = People.new()
		add_child(node)
		var uniform: String = e.get("member", ["oneill", "daniel", "carter"][int(e.id) % 3]) if e.side == "sgc" else "jaffa"
		node.build(uniform)
		caption = Sim.SPECIALISTS[e.kind].name.to_upper() if Sim.SPECIALISTS.has(e.kind) else ("SGC" if e.kind == "soldier" else "JAFFA")
		if e.get("first_wave", false) and sim.profile == "balanced":
			caption = Data.MEMBERS[e.member].n.to_upper()
		if e.kind == "engineer":
			_mesh(node, People.box(0.4, 0.5, 0.22), Color("8e8058"), Vector3(0, 1.05, -0.25))
		elif e.kind == "medic":
			_mesh(node, People.box(0.45, 0.5, 0.25), Color("e2e9e8"), Vector3(0, 1.05, -0.28))
			_mesh(node, People.box(0.3, 0.09, 0.02), T.RED, Vector3(0, 1.05, -0.42))
			_mesh(node, People.box(0.09, 0.3, 0.02), T.RED, Vector3(0, 1.05, -0.43))
		elif e.kind == "scientist":
			_mesh(node, People.box(0.44, 0.5, 0.25), T.BLUE, Vector3(0, 1.05, -0.28))
			_mesh(node, People.box(0.28, 0.18, 0.05), T.AMBER, Vector3(0.35, 0.9, 0.1))
	else:
		node = Node3D.new()
		add_child(node)
		caption = "CAMP GOA'ULD" if e.kind == "camp" else Sim.BUILDINGS[e.kind].name.to_upper()
		model = Assets.make(e.kind)
		node.add_child(model)
		label_height = model.get_meta("label_height", 5.0)
		aim = model.find_child("Aim", true, false) as Node3D
		damage = model.find_child("Damage", true, false) as Node3D
		rotor = model.find_child("Rotor", true, false) as Node3D
		drill = model.find_child("Drill", true, false) as Node3D
		if e.kind != "camp":
			site = Assets.make("construction")
			node.add_child(site)
			site.visible = e.build > 0
	node.position = _world(e.pos)
	var radius := 1.9 if sim.is_building(e) else 0.85
	var ring := _mesh(node, Gate.ring_mesh(radius - 0.09, radius, 0, -0.025, 32), color, Vector3(0, 0.06, 0))
	ring.rotation.x = -PI / 2
	var label := _label3d(node, caption, Vector3(0, label_height, 0), color)
	visuals[e.id] = {"node": node, "ring": ring, "label": label, "name": caption,
		"aim": aim, "model": model, "site": site, "damage": damage, "rotor": rotor,
		"drill": drill, "hit_until": 0.0, "destroyed": false}


func _shot(from: Vector2, to: Vector2, enemy: bool) -> void:
	if not sim.is_visible(from):
		return
	for e in sim.entities:
		if e.side == ("enemy" if enemy else "sgc") and e.pos.distance_squared_to(from) < 0.01 and visuals.has(e.id):
			var v: Dictionary = visuals[e.id]
			if v.node.has_method("shoot"):
				v.node.rotation.y = atan2(to.x - from.x, to.y - from.y)
				v.node.shoot()
			if v.aim:
				v.aim.rotation.y = atan2(from.x - to.x, from.y - to.y)
			break
	var a := _world(from, 1.5)
	var b := _world(to, 1.3)
	var beam := _mesh(self, People.box(0.08, 0.08, a.distance_to(b)), T.AMBER if enemy else T.BLUE, (a + b) * 0.5)
	beam.material_override = People.mat(T.AMBER if enemy else T.BLUE, 0.5, 0, 2)
	beam.look_at(b)
	var impact := _mesh(self, People.ball(0.18), T.AMBER if enemy else T.BLUE, b)
	var tw := create_tween()
	tw.tween_interval(0.09)
	tw.tween_callback(beam.queue_free)
	tw.tween_callback(impact.queue_free)
	if DisplayServer.get_name() != "headless" and not cam.is_position_behind(a) and get_viewport().get_visible_rect().has_point(cam.unproject_position(a)):
		if enemy and sim.elapsed - _last_staff > 0.3:
			_last_staff = sim.elapsed
			Audio.play("staff")
		elif not enemy and sim.elapsed - _last_gun > 0.3:
			_last_gun = sim.elapsed
			Audio.play("gun")


func _hit(id: int, damage: float, destroyed: bool) -> void:
	var target := {}
	for e in sim.entities:
		if e.id == id:
			target = e
			break
	if target.is_empty() or (target.side == "enemy" and not sim.is_visible(target.pos)):
		return
	if visuals.has(id):
		var v: Dictionary = visuals[id]
		v.hit_until = sim.elapsed + 0.22
		v.destroyed = destroyed
		if v.node.has_method("hurt") and not destroyed:
			v.node.hurt()
	overlay.feedback(_world(target.pos, 3), "−%d" % damage, T.RED if target.side == "sgc" else T.AMBER)
	if target.side == "sgc" and sim.is_building(target) and sim.elapsed - _last_attack_notice > 8:
		_last_attack_notice = sim.elapsed
		_notice("Sous le feu : %s !" % Sim.BUILDINGS[target.kind].name)
	if destroyed and sim.is_building(target) and DisplayServer.get_name() != "headless":
		Audio.play("boom")


func _ground(screen: Vector2) -> Vector2:
	var origin := cam.project_ray_origin(screen)
	var ray := cam.project_ray_normal(screen)
	if ray.y >= -0.001:
		return Vector2(-100, -100)
	var hit := origin + ray * (-origin.y / ray.y)
	return Vector2(hit.x, hit.z) / 2.0


func _pick(screen: Vector2) -> Dictionary:
	var best := 38.0
	var found := {}
	for e in sim.entities:
		if not sim.entity_visible(e):
			continue
		var point := _world(e.pos, 1)
		if cam.is_position_behind(point):
			continue
		var d := cam.unproject_position(point).distance_to(screen)
		if d < best:
			best = d
			found = e
	# Le toit et les côtés doivent aussi répondre au toucher, pas seulement le pied.
	if found.is_empty():
		var ground := _ground(screen)
		for e in sim.entities:
			if not sim.entity_visible(e) or not sim.is_building(e):
				continue
			var roof := _world(e.pos, 3)
			if cam.is_position_behind(roof):
				continue
			if ground.distance_to(e.pos) < 1.4 or cam.unproject_position(roof).distance_to(screen) < 38:
				found = e
				break
	return found


func _tap(screen: Vector2, order_only: bool = false) -> void:
	if paused or sim.result != "" or sim.phase == "arrival":
		return
	var p := _ground(screen)
	if build_kind != "":
		if sim.build(build_kind, p):
			_cancel_build()
		return
	var picked := _pick(screen)
	if not picked.is_empty() and picked.side == "sgc" and not order_only:
		if Input.is_key_pressed(KEY_SHIFT) or multi_select:
			if selected.has(picked.id):
				selected.erase(picked.id)
			else:
				selected.append(picked.id)
		else:
			selected = [picked.id]
		_show_command_tab("selection")
	elif not picked.is_empty() and picked.side == "enemy":
		sim.order(selected, picked.pos, picked.id)
		_order_marker(picked.pos, T.RED)
	else:
		sim.order(selected, p)
		_order_marker(p, T.BLUE)
	_update_ui()


func _order_marker(point: Vector2, color: Color) -> void:
	if point.x < 0 or point.y < 0 or point.x >= Sim.SIZE.x or point.y >= Sim.SIZE.y:
		return
	for id in selected:
		var e := sim.entity(id)
		if not e.is_empty() and e.side == "sgc" and not sim.is_building(e):
			overlay.feedback(_world(point, 0.1), "", color, true)
			return


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED] and is_node_ready():
		pointer_down = false
		selection_rect.visible = false
		if not paused:
			_toggle_pause()


func _input(e: InputEvent) -> void:
	# Intercepter avant les boutons : Espace n'active jamais le bouton focalisé.
	if is_instance_valid(pause_overlay):
		return
	if e is InputEventKey and e.keycode == KEY_SPACE:
		if e.pressed and not e.echo:
			_select_all()
		get_viewport().set_input_as_handled()


func _unhandled_input(e: InputEvent) -> void:
	if is_instance_valid(pause_overlay):
		if e.is_action_pressed("ui_cancel") and _menu_page != "options":
			if _menu_page == "main":
				_close_menu()
			else:
				_menu_main()
			get_viewport().set_input_as_handled()
		return
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_1, KEY_2, KEY_3:
				var slot: int = e.keycode - KEY_1 + 1
				if e.shift_pressed:
					_save_squad(slot)
				else:
					_recall_squad(slot)
				_update_ui()
			KEY_ESCAPE:
				if build_kind != "":
					_cancel_build()
				else:
					_menu()
			KEY_C:
				focus = _world(Sim.GATE)
				_camera()
			_:
				return
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
			_zoom(-3)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
			_zoom(3)
		elif e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
			if build_kind != "":
				_cancel_build()
			else:
				_tap(e.position, true)
		elif e.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
			if e.pressed:
				pointer_down = true
				pointer_start = e.position
				dragging = false
				# Les événements émulés depuis le tactile doivent faire glisser la caméra.
				drag_select = e.button_index == MOUSE_BUTTON_LEFT and e.device != InputEvent.DEVICE_ID_EMULATION and build_kind == ""
			else:
				if pointer_down and not dragging and e.button_index == MOUSE_BUTTON_LEFT:
					_tap(e.position)
				elif pointer_down and dragging and drag_select:
					selected.clear()
					var rect := Rect2(pointer_start, e.position - pointer_start).abs()
					for unit in sim.entities:
						if unit.side == "sgc" and not sim.is_building(unit) and unit.hp > 0 and rect.has_point(cam.unproject_position(_world(unit.pos, 1))):
							selected.append(unit.id)
				pointer_down = false
				selection_rect.visible = false
	elif e is InputEventMouseMotion and pointer_down:
		if e.position.distance_to(pointer_start) > 12:
			dragging = true
		if dragging:
			if drag_select:
				var rect := Rect2(pointer_start, e.position - pointer_start).abs()
				selection_rect.position = rect.position
				selection_rect.size = rect.size
				selection_rect.visible = true
			else:
				var shift := _ground(e.position - e.relative) - _ground(e.position)
				focus += Vector3(shift.x * 2, 0, shift.y * 2) * Settings.value("cam_speed") / 100.0
				_camera()
