extends Control
## SGC en coupe : navigation 2D et ascenseur. Les services restent dans hub.gd.

signal room_requested(room_id: String)
signal launch_requested(mission: int)
signal outpost_requested
signal menu_requested

const T = preload("res://scripts/ui_theme.gd")
const Data = preload("res://scripts/data.gd")
const Layout = preload("res://scripts/sgc_layout.gd")
const WORLD = Layout.WORLD
const LIFT_X = Layout.LIFT_X
const FLOORS = Layout.FLOORS
const FLOOR_NUMBERS = Layout.FLOOR_NUMBERS
const ROOMS = Layout.ROOMS

var player := Layout.SPAWN
var level := Layout.GATE_LEVEL
var prepared_mission := -1
var route: Array[Vector2] = []
var destination_room := ""
var auto_interact := false
var cabin_y := Layout.SPAWN.y
var overview := false
var view_button: Button
var _left := false
var _right := false
var _walking := false
var _clock := 0.0
var _scale := 1.0
var _origin := Vector2.ZERO
var _modal: Control
var status: Label
var resources: Label
var interact_button: Button
var floor_buttons: Array[Button] = []
var footer: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = T.make()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	resized.connect(_fit)
	_fit()
	visible = false


func _build_ui() -> void:
	var header := PanelContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 16
	header.offset_right = -16
	header.offset_top = 12
	add_child(header)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	header.add_child(row)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(titles)
	titles.add_child(T.wrap(T.label("STARGATE COMMAND // CHEYENNE MOUNTAIN", "Section", T.AMBER)))
	resources = T.wrap(T.label("", "Body"))
	resources.add_theme_font_size_override("font_size", 19)
	titles.add_child(resources)
	view_button = T.button("PLAN GLOBAL", toggle_overview, "Ghost")
	row.add_child(view_button)
	row.add_child(T.button("MENU", func(): menu_requested.emit(), "Ghost"))
	footer = PanelContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	footer.offset_left = 16
	footer.offset_right = -16
	footer.offset_top = -158
	footer.offset_bottom = -12
	add_child(footer)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	footer.add_child(box)
	status = T.wrap(T.label("", "Body"))
	box.add_child(status)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("separation", 10)
	box.add_child(actions)
	interact_button = T.button("INTERAGIR", interact, "Accent")
	interact_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(interact_button)
	for i in FLOORS.size():
		var floor_index: int = i
		var button := T.button("N%d" % FLOOR_NUMBERS[i], func(): travel_floor(floor_index), "Ghost")
		button.add_theme_font_size_override("font_size", 19)
		button.tooltip_text = "Rejoindre le niveau %d par l'ascenseur" % FLOOR_NUMBERS[i]
		actions.add_child(button)
		floor_buttons.append(button)
	var help := T.wrap(T.label("Toucher une salle : entrer · ←/→ ou Q/D : marcher · ↑/↓ : changer de niveau · E : interagir · Plan global : toutes les salles · Coupe adaptée, niveaux intermédiaires omis", "Body", T.DIM))
	help.add_theme_font_size_override("font_size", 17)
	box.add_child(help)


func _fit() -> void:
	var area := Vector2(maxf(1, size.x - 32), maxf(1, size.y - 270))
	_scale = minf(area.x / WORLD.x, area.y / (WORLD.y if overview else 560.0))
	var half := minf(WORLD.y / 2, area.y / (2 * _scale))
	var focus_y := WORLD.y / 2 if overview else clampf(player.y - 170, half, WORLD.y - half)
	_origin = Vector2((size.x - WORLD.x * _scale) / 2, 100 + area.y / 2 - focus_y * _scale)
	queue_redraw()


func toggle_overview() -> void:
	overview = not overview
	view_button.text = "SUIVRE O'NEILL" if overview else "PLAN GLOBAL"
	_fit()


func open() -> void:
	visible = true
	stop()
	_fit()
	_refresh()
	queue_redraw()


func close() -> void:
	stop()
	_close_modal()
	visible = false


func reset_visit() -> void:
	close()
	level = Layout.GATE_LEVEL
	player = Layout.SPAWN
	cabin_y = player.y
	prepared_mission = -1


func stop() -> void:
	route.clear()
	destination_room = ""
	auto_interact = false
	_left = false
	_right = false
	_walking = false
	# Ne pas laisser le personnage suspendu entre deux étages si l'écran se ferme.
	if not is_equal_approx(player.y, FLOORS[level]):
		player.y = FLOORS[level]
		cabin_y = player.y


func room_rect(room_id: String) -> Rect2:
	var data: Dictionary = ROOMS[room_id]
	var height: float = data.get("height", 176.0)
	return Rect2(data.left, FLOORS[data.level] - height, data.width, height)


func navigate(room_id: String, enter: bool = true) -> bool:
	if not ROOMS.has(room_id) or not visible or _modal != null:
		return false
	var data: Dictionary = ROOMS[room_id]
	_plan(Vector2(data.x, FLOORS[data.level]))
	destination_room = room_id
	auto_interact = enter
	_refresh()
	return true


func _plan(target: Vector2, via_lift: bool = false) -> void:
	stop()
	if not is_equal_approx(player.y, target.y):
		# L'escalier relie réellement le briefing et le contrôle, sans ascenseur.
		if not via_lift and level == Layout.GATE_LEVEL and is_equal_approx(target.y, FLOORS[Layout.BRIEFING_LEVEL]):
			route.append(Layout.STAIR_BOTTOM)
			route.append(Layout.STAIR_LANDING)
			route.append(Layout.STAIR_TOP)
		elif not via_lift and level == Layout.BRIEFING_LEVEL and is_equal_approx(target.y, FLOORS[Layout.GATE_LEVEL]):
			route.append(Layout.STAIR_TOP)
			route.append(Layout.STAIR_LANDING)
			route.append(Layout.STAIR_BOTTOM)
		else:
			route.append(Vector2(LIFT_X, player.y))
			route.append(Vector2(LIFT_X, target.y))
	route.append(target)


func travel_floor(index: int) -> void:
	if index < 0 or index >= FLOORS.size() or not visible or _modal != null:
		return
	_plan(Vector2(LIFT_X, FLOORS[index]), true)
	_refresh()


func advance(delta: float, axis: float = 0.0) -> void:
	if not visible or _modal != null or delta <= 0:
		return
	_clock += delta
	_walking = false
	var on_floor := is_equal_approx(player.y, FLOORS[level])
	if axis != 0 and on_floor:
		route.clear()
		destination_room = ""
		auto_interact = false
		player.x = clampf(player.x + axis * delta * 230, LIFT_X, Layout.walk_limit(level))
		_walking = true
	else:
		var remaining := delta
		while not route.is_empty() and remaining > 0:
			var target := route[0]
			var vertical := not is_equal_approx(player.y, target.y)
			var speed := 180.0 if vertical else 230.0
			var distance := player.distance_to(target)
			var used := minf(remaining, distance / speed)
			player = player.move_toward(target, used * speed)
			remaining -= used
			_walking = absf(target.x - player.x) > 0.01 and distance > 0.01
			if is_equal_approx(player.x, LIFT_X):
				cabin_y = player.y
			if player.distance_to(target) < 0.01:
				player = target
				for i in FLOORS.size():
					if is_equal_approx(player.y, FLOORS[i]):
						level = i
				route.pop_front()
			else:
				break
		if route.is_empty() and destination_room != "":
			var arrived := destination_room
			var enter := auto_interact
			destination_room = ""
			auto_interact = false
			if enter:
				_activate(arrived)
	_refresh()
	_fit()


func _process(delta: float) -> void:
	if delta > 1.0:
		_left = false
		_right = false
		return
	advance(delta, float(_right) - float(_left))


func nearest_room() -> String:
	if not is_equal_approx(player.y, FLOORS[level]):
		return ""
	var nearest := ""
	var best := INF
	for key in ROOMS:
		var data: Dictionary = ROOMS[key]
		var distance := absf(player.x - data.x)
		if data.level == level and distance <= minf(190, data.width * 0.4) and distance < best:
			nearest = key
			best = distance
	return nearest


func interact() -> void:
	if not visible or _modal != null or not route.is_empty():
		return
	var key := nearest_room()
	if key != "":
		_activate(key)


func _activate(key: String) -> void:
	_left = false
	_right = false
	if key in ["control", "gate"]:
		_gate_dialog(key)
	elif key in ["briefing", "team", "armory", "infirmary"]:
		room_requested.emit(key)
	else:
		_room_dialog(key)


func _refresh() -> void:
	if resources == null:
		return
	resources.text = "Niveau %d · %d naquadah · SG-1 %d membres · %d/%d missions" % [FLOOR_NUMBERS[level], Game.stats.naq, Game.team.size(), Game.stats.done, Data.PLANETS.size()]
	var key := nearest_room()
	interact_button.disabled = key == "" or not route.is_empty()
	interact_button.text = "ENTRER · " + str(ROOMS[key].name) if key != "" else "REJOINDRE UNE SALLE"
	if destination_room != "":
		status.text = "En route vers %s · niveau %d" % [ROOMS[destination_room].name, FLOOR_NUMBERS[ROOMS[destination_room].level]]
	elif not route.is_empty():
		status.text = "Transfert entre niveaux · escalier N27–28 / ascenseur"
	else:
		status.text = "O'Neill · %s" % (str(ROOMS[key].name) if key != "" else "Couloir / ascenseur")
	if prepared_mission >= 0:
		status.text += " · Destination préparée : " + str(Data.PLANETS[prepared_mission].n)
	for i in floor_buttons.size():
		floor_buttons[i].theme_type_variation = "Accent" if i == level else "Ghost"


func _close_modal() -> void:
	if _modal != null:
		_modal.queue_free()
		_modal = null


func _dialog_box(heading: String) -> VBoxContainer:
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_modal)
	var veil := ColorRect.new()
	veil.color = Color(0.01, 0.02, 0.03, 0.8)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(veil)
	var box := T.modal(_modal, 640)
	box.add_child(T.label(heading, "Section"))
	return box


func _gate_dialog(key: String) -> void:
	var box := _dialog_box("HARRIMAN // CONTRÔLE N28" if key == "control" else "SALLE DE LA PORTE // NIVEAUX 27–28")
	var description := "Aucune destination préparée. Passez au briefing avant d'autoriser un départ."
	if prepared_mission >= 0:
		description = "Destination : %s\n%s" % [Data.PLANETS[prepared_mission].n, "Adresse prête. La séquence 3D de composition et de franchissement prendra le relais." if Data.PLANETS[prepared_mission].gate else "Transfert par Tel'tak disponible pour cette mission."]
	box.add_child(T.wrap(T.label(description, "Body")))
	if prepared_mission >= 0:
		box.add_child(T.button("Autoriser le départ", func():
			var mission := prepared_mission
			_close_modal()
			launch_requested.emit(mission), "Accent"))
	box.add_child(T.button("Aller au briefing", func(): _close_modal(); navigate("briefing"), "Ghost"))
	if key == "control":
		box.add_child(T.button("Programme avant-poste · RTS", func(): outpost_requested.emit(), "Ghost"))
	box.add_child(T.button("Retour au couloir", _close_modal, "Ghost"))


func _room_dialog(key: String) -> void:
	var descriptions := {
		"office": "Général Hammond : le briefing est adjacent à mon bureau, au niveau 27. L'escalier descend directement à la salle de contrôle.",
		"daniel": "Laboratoire de Daniel Jackson · niveau 18. Artefacts, traductions et recherches sur les peuples rencontrés par SG-1. Espace de visite, sans bonus de recherche dans cette version.",
		"archives": "Archives et traductions du laboratoire de Daniel. Cette annexe est une adaptation de jeu ; sa position précise n'est pas établie par les plans consultés.",
		"isolation": "Zone médicale du niveau 21. Chambres d'observation et d'isolement, sous la responsabilité du Dr Fraiser.",
		"mess": "Mess du niveau 22. Lieu de détente entre deux missions. Les repas n'ajoutent pas de bonus dans cette version.",
		"kitchen": "Cuisine desservant le mess. Sa disposition dans cette coupe est simplifiée pour la navigation.",
		"malp": "Atelier du niveau 24 : stockage et maintenance des sondes MALP et UAV. Le programme avant-poste reste accessible depuis la salle de contrôle.",
		"storage": "Réserves logistiques associées à l'atelier. Annexe de jeu : cette visite ne crée ni ressources ni équipement.",
		"lockers": "Vestiaires du niveau 25. Préparation de l'équipe avant de retirer ses armes au niveau 28 et de rejoindre la porte.",
	}
	var box := _dialog_box("%s // N%d" % [ROOMS[key].name, FLOOR_NUMBERS[ROOMS[key].level]])
	box.add_child(T.wrap(T.label(descriptions.get(key, "Zone de soutien du SGC."), "Body")))
	if key == "office":
		box.add_child(T.button("Rejoindre le briefing", func(): _close_modal(); navigate("briefing"), "Accent"))
	elif key == "lockers":
		box.add_child(T.button("Rejoindre les quartiers SG-1", func(): _close_modal(); navigate("team"), "Accent"))
	box.add_child(T.button("Retour au couloir", _close_modal, "Ghost"))


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		stop()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey:
		return
	if event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		if _modal != null:
			_close_modal()
		else:
			menu_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if _modal != null:
		return
	match event.keycode:
		KEY_LEFT, KEY_Q, KEY_A:
			_left = event.pressed
		KEY_RIGHT, KEY_D:
			_right = event.pressed
		KEY_UP, KEY_Z, KEY_W:
			if event.pressed and not event.echo:
				travel_floor(maxi(0, level - 1))
		KEY_DOWN, KEY_S:
			if event.pressed and not event.echo:
				travel_floor(mini(FLOORS.size() - 1, level + 1))
		KEY_E, KEY_ENTER, KEY_KP_ENTER:
			if event.pressed and not event.echo:
				interact()
		_:
			return
	get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if _modal != null or not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var point: Vector2 = (event.position - _origin) / _scale
	if event.position.y < 100 or event.position.y > size.y - 170:
		return
	for key in ROOMS:
		if room_rect(key).has_point(point):
			navigate(key)
			accept_event()
			return
	if point.x > LIFT_X - 45 and point.x < LIFT_X + 45:
		for i in FLOORS.size():
			if absf(point.y - (FLOORS[i] - 85)) < 95:
				travel_floor(i)
				accept_event()
				return


func _text(at: Vector2, text: String, color: Color, font_size: int = 24) -> void:
	draw_string(T.font("Rajdhani-Bold"), at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("080f17"))
	draw_set_transform(_origin, 0, Vector2.ONE * _scale)
	# Coupe adaptée : les vrais numéros d'étage sont conservés, pas leur profondeur.
	draw_rect(Rect2(50, 5, 1460, WORLD.y - 15), Color("20282b"))
	for i in 29:
		var x := 55.0 + i * 51
		draw_line(Vector2(x, 5), Vector2(x + 20, WORLD.y - 10), Color("2a3436"), 3)
	draw_rect(Rect2(65, 28, 90, WORLD.y - 52), Color("0b141d"))
	for x in [73, 147]:
		draw_line(Vector2(x, 28), Vector2(x, WORLD.y - 35), Color("536575"), 3)
	for i in FLOORS.size():
		_text(Vector2(7, FLOORS[i] - 75), "%d" % FLOOR_NUMBERS[i], Color("a9bac5"), 32)
		draw_line(Vector2(65, FLOORS[i]), Vector2(210, FLOORS[i]), Color("53606a"), 9)
		draw_line(Vector2(155, FLOORS[i]), Vector2(Layout.walk_limit(i), FLOORS[i]), Color("53606a"), 4)
		if i > 0 and FLOOR_NUMBERS[i] - FLOOR_NUMBERS[i - 1] > 1:
			_text(Vector2(91, FLOORS[i] - 180), "···", Color("8ba1ad"), 25)
	for key in ROOMS:
		_draw_room(key)
	_draw_stairs()
	# Cabine et câbles restent à leur dernier niveau quand O'Neill en sort.
	draw_line(Vector2(LIFT_X, 28), Vector2(LIFT_X, cabin_y - 94), Color("71838c"), 2)
	draw_rect(Rect2(70, cabin_y - 94, 80, 94), Color("253746"))
	draw_rect(Rect2(76, cabin_y - 88, 68, 82), Color("111e2b"))
	draw_line(Vector2(70, cabin_y), Vector2(150, cabin_y), Color("e1bc76"), 5)
	_person(player, Color("79866e"), true)
	draw_set_transform(Vector2.ZERO)
	# Masquer les étages hors champ sans qu'ils débordent derrière les commandes.
	draw_rect(Rect2(0, 0, size.x, 100), Color("080f17"))
	draw_rect(Rect2(0, size.y - 170, size.x, 170), Color("080f17"))


func _draw_room(key: String) -> void:
	var data: Dictionary = ROOMS[key]
	var rect := room_rect(key)
	var x: float = data.left
	var y: float = FLOORS[data.level]
	var width: float = data.width
	var color: Color = data.color
	draw_rect(rect, Color("15232e"))
	for column in int(width / 80):
		draw_rect(Rect2(x + 8 + column * 80, rect.position.y + 18, 72, rect.size.y - 34), Color("1c2c38"))
	draw_rect(Rect2(x, rect.position.y, width, 9), Color("455763"))
	draw_rect(Rect2(x, y, width, 13), Color("53606a"))
	draw_line(Vector2(x, y + 14), Vector2(x + width, y + 14), Color("111921"), 3)
	draw_rect(Rect2(x + 18, rect.position.y + 19, width - 36, 4), color.darkened(0.15))
	_text(Vector2(x + 18, rect.position.y + 48), data.name, color, 23 if width < 400 else 27)
	if key == "briefing":
		draw_rect(Rect2(x + 20, y - 111, 90, 43), Color("08121c"))
		_text(Vector2(x + 26, y - 86), "MISSION", color, 16)
		for i in 4:
			draw_rect(Rect2(x + 60 + i * 47, y - 36, 26, 32), Color("394e5c"))
		draw_rect(Rect2(x + 40, y - 48, 220, 12), Color("8b8069"))
	elif key == "office":
		draw_rect(Rect2(x + 20, y - 102, 56, 43), Color("43515b"))
		draw_rect(Rect2(x + 30, y - 95, 36, 28), Color("547a91"))
		draw_rect(Rect2(x + 45, y - 46, 135, 16), Color("8b8069"))
		draw_line(Vector2(x + 60, y - 30), Vector2(x + 60, y), Color("596b77"), 8)
	elif key == "team":
		for i in 3:
			var bx := x + 60 + i * 140
			draw_rect(Rect2(bx, y - 76, 110, 68), Color("304350"))
			draw_rect(Rect2(bx + 6, y - 70, 98, 20), Color("708878"))
			draw_rect(Rect2(bx + 6, y - 33, 98, 20), Color("708878"))
	elif key in ["armory", "lockers"]:
		for i in int((width - 80) / 55):
			var bx := x + 50 + i * 60
			draw_rect(Rect2(bx, y - 102, 44, 90), Color("35444d"))
			if key == "armory":
				draw_line(Vector2(bx + 12, y - 30), Vector2(bx + 28, y - 84), Color("0b1419"), 7)
				draw_rect(Rect2(bx + 20, y - 71, 23, 7), Color("101b23"))
	elif key in ["infirmary", "isolation"]:
		for i in (3 if key == "infirmary" else 2):
			var bx := x + 50 + i * 145
			draw_rect(Rect2(bx, y - 36, 106, 16), Color("93afb6"))
			draw_rect(Rect2(bx + 4, y - 46, 26, 10), Color("d7e1db"))
			for leg in [8, 94]:
				draw_line(Vector2(bx + leg, y - 20), Vector2(bx + leg, y), Color("718c99"), 4)
		draw_rect(Rect2(x + width - 145, y - 105, 52, 70), Color("d3ddda"))
		draw_rect(Rect2(x + width - 123, y - 94, 9, 32), Color("b65c57"))
		draw_rect(Rect2(x + width - 134, y - 83, 31, 9), Color("b65c57"))
	elif key == "control":
		for i in 3:
			var bx := x + 12 + i * 92
			draw_rect(Rect2(bx, y - 99, 78, 43), Color("08131e"))
			draw_rect(Rect2(bx + 5, y - 94, 68, 33), Color("24546b"))
			for j in 3:
				draw_line(Vector2(bx + 10, y - 86 + j * 9), Vector2(bx + 38 + sin(_clock + i + j) * 20, y - 86 + j * 9), Color("78c8c1"), 2)
			draw_rect(Rect2(bx - 3, y - 47, 84, 20), Color("4a5e69"))
	elif key == "gate":
		var center := Vector2(x + 330, y - 112)
		draw_circle(center, 110, Color("586c78"))
		draw_circle(center, 94, Color("243440"))
		for i in 15:
			var line_y := center.y - 84 + i * 12
			var half := sqrt(maxf(0, 91 * 91 - pow(line_y - center.y, 2)))
			draw_line(Vector2(center.x - half, line_y), Vector2(center.x + half, line_y), Color("536775"), 3)
		for i in 7:
			var angle := -PI + i * TAU / 7
			var p := center + Vector2(cos(angle), sin(angle)) * 104
			draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), Color("dbb87b"))
		draw_colored_polygon(PackedVector2Array([Vector2(x + 20, y), Vector2(x + 240, y - 14), Vector2(x + 440, y - 14), Vector2(x + 440, y)]), Color("687b84"))
		_text(Vector2(x + 22, rect.position.y + 76), "DOUBLE HAUTEUR · N27–28", color.darkened(0.1), 19)
		# Les baies donnent réellement sur le même volume, sans plancher fictif au 27.
		for floor_y in [FLOORS[Layout.BRIEFING_LEVEL], y]:
			draw_rect(Rect2(x - 26, floor_y - 114, 28, 70), Color("55849b"))
			draw_line(Vector2(x - 26, floor_y - 44), Vector2(x + 12, floor_y - 44), Color("9fb8c6"), 4)
		draw_line(Vector2(x + 250, rect.position.y + 92), Vector2(x + 400, rect.position.y + 92), Color("647581"), 6)
		draw_line(Vector2(x + 330, rect.position.y + 92), Vector2(x + 330, rect.position.y + 140), Color("647581"), 2)
	elif key in ["mess", "kitchen"]:
		for i in 3:
			var bx := x + 38 + i * (width - 70) / 3
			draw_rect(Rect2(bx, y - 47, 105, 12), Color("8b917e"))
			for side in [12, 88]:
				draw_line(Vector2(bx + side, y - 35), Vector2(bx + side, y), Color("596b77"), 5)
	elif key == "malp":
		for i in 2:
			var bx := x + 100 + i * 260
			draw_rect(Rect2(bx, y - 58, 126, 38), Color("7d8b77"))
			for wheel in [12, 60, 108]:
				draw_circle(Vector2(bx + wheel, y - 14), 14, Color("101a20"))
			draw_line(Vector2(bx + 68, y - 58), Vector2(bx + 68, y - 100), Color("b5c4c5"), 4)
			draw_rect(Rect2(bx + 53, y - 110, 30, 18), Color("386b84"))
	else:
		for i in 4:
			var bx := x + 32 + i * (width - 60) / 4
			draw_rect(Rect2(bx, y - 102, (width - 90) / 4, 90), Color("4a4c42"))
			for shelf in [32, 58, 86]:
				draw_line(Vector2(bx + 3, y - shelf), Vector2(bx + (width - 90) / 4 - 3, y - shelf), Color("a08e68"), 4)
	if data.npc != "":
		_person(Vector2(x + width - 48, y), Color("b2c2bb") if key == "infirmary" else Color("677e77"), false)
		_text(Vector2(x + width - 108, y - 75), data.npc, Color("91a8b6"), 16)
	if destination_room == key or (nearest_room() == key and route.is_empty()):
		draw_line(Vector2(data.x - 38, y - 2), Vector2(data.x + 38, y - 2), T.AMBER, 5)
		_text(Vector2(data.x - 29, y + 34), "ENTRÉE", T.AMBER, 18)


func _draw_stairs() -> void:
	var points := [Layout.STAIR_BOTTOM, Layout.STAIR_LANDING, Layout.STAIR_TOP]
	for i in 2:
		for step in 11:
			var point: Vector2 = points[i].lerp(points[i + 1], step / 11.0)
			draw_line(point - Vector2(9, 0), point + Vector2(9, 0), Color("a3b1b6"), 4)
		draw_line(points[i] - Vector2(0, 43), points[i + 1] - Vector2(0, 43), Color("687e8d"), 3)
	_text(Vector2(520, 1203), "ESCALIER", Color("8ba1ad"), 17)


func _person(at: Vector2, uniform: Color, controlled: bool) -> void:
	var stride := sin(_clock * 14) * 7 if controlled and _walking else 0.0
	draw_ellipse_shadow(at)
	for side in [-1, 1]:
		var foot := at + Vector2(side * 7 + stride * side, -3)
		draw_line(at + Vector2(side * 6, -25), foot, uniform.darkened(0.3), 8)
		draw_line(foot - Vector2(3, 0), foot + Vector2(6, 0), Color("101820"), 6)
	draw_rect(Rect2(at + Vector2(-13, -49), Vector2(26, 27)), uniform)
	draw_rect(Rect2(at + Vector2(-9, -43), Vector2(18, 17)), uniform.darkened(0.25))
	draw_line(at + Vector2(-16, -44), at + Vector2(-17 - stride * 0.4, -25), uniform, 7)
	draw_line(at + Vector2(16, -44), at + Vector2(17 + stride * 0.4, -25), uniform, 7)
	draw_circle(at + Vector2(0, -57), 9, Color("c9aa89"))
	draw_rect(Rect2(at + Vector2(-10, -66), Vector2(20, 7)), Color("697d6c") if controlled else uniform.darkened(0.2))
	if controlled:
		_text(at + Vector2(-34, -86), "O'NEILL", T.AMBER, 21)
		draw_colored_polygon(PackedVector2Array([at + Vector2(-5, -81), at + Vector2(5, -81), at + Vector2(0, -73)]), T.AMBER)


func draw_ellipse_shadow(at: Vector2) -> void:
	draw_rect(Rect2(at + Vector2(-20, -2), Vector2(40, 4)), Color(0, 0, 0, 0.3))
