extends Control
## Le poste du SGC façon jeu PC : barre d'état en haut, navigation à gauche
## (briefing, armurerie, équipe) et un grand panneau central. Souris, clavier et tactile.

const T = preload("res://scripts/ui_theme.gd")
const Data = preload("res://scripts/data.gd")
const People = preload("res://scripts/people.gd")

const TOP_H := 64
const NAV_W := 260
const TABS := [["briefing", "BRIEFING", "1"], ["armory", "ARMURERIE", "2"], ["team", "ÉQUIPE", "3"], ["infirmary", "INFIRMERIE", "4"]]

var main: Node
var tab := "briefing"
var sel := -1
var nav := {}
var stats_box: HFlowContainer
var crew_box: VBoxContainer
var content: Control
var location_label: Label
var notice_lbl: Label
var _notice := ""
var _header: PanelContainer
var _side: PanelContainer
var _armory_scroll := 0


func _init(m: Node) -> void:
	main = m


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_frame()
	resized.connect(_resize_content)
	_fit_frame()


# ---------- Le cadre : barre du haut et navigation ----------

func _build_frame() -> void:
	var bar := PanelContainer.new()
	_header = bar
	bar.theme_type_variation = "Bar"
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = TOP_H
	add_child(bar)
	var rows := VBoxContainer.new()
	bar.add_child(rows)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	rows.add_child(row)
	var brand := HBoxContainer.new()
	brand.add_theme_constant_override("separation", 12)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(brand)
	var logo := T.label("SGC", "Body", T.AMBER)
	logo.add_theme_font_override("font", T.font("PressStart2P"))
	logo.add_theme_font_size_override("font_size", 20)
	brand.add_child(logo)
	location_label = T.label("STARGATE COMMAND  //  NIVEAU 27", "Caption")
	location_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	location_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	brand.add_child(location_label)
	brand.alignment = BoxContainer.ALIGNMENT_CENTER
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	stats_box = HFlowContainer.new()
	stats_box.add_theme_constant_override("h_separation", 20)
	rows.add_child(stats_box)
	var menu := T.button("RETOUR AU SGC", main.return_to_sgc, "Ghost", "Revenir au couloir · Échap")
	menu.custom_minimum_size = Vector2(120, 44)
	row.add_child(menu)

	var side := PanelContainer.new()
	_side = side
	side.add_theme_stylebox_override("panel", _side_style())
	side.anchor_bottom = 1.0
	side.offset_top = TOP_H
	side.offset_right = NAV_W
	add_child(side)
	var side_scroll := ScrollContainer.new()
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_scroll.follow_focus = true
	side.add_child(side_scroll)
	var sv := VBoxContainer.new()
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sv.add_theme_constant_override("separation", 6)
	side_scroll.add_child(sv)
	sv.add_child(T.wrap(T.label("POSTE DE COMMANDEMENT", "Caption")))
	sv.add_child(_gap(6))
	var group := ButtonGroup.new()
	for t in TABS:
		var b := Button.new()
		b.text = t[1]
		b.theme_type_variation = "Nav"
		b.toggle_mode = true
		b.button_group = group
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 56)
		b.tooltip_text = "Raccourci : %s" % t[2]
		var key: String = t[0]
		b.pressed.connect(func(): open(key))
		sv.add_child(b)
		nav[key] = b
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sv.add_child(fill)
	sv.add_child(T.label("SG-1", "Caption"))
	crew_box = VBoxContainer.new()
	crew_box.add_theme_constant_override("separation", 8)
	sv.add_child(crew_box)
	sv.add_child(_gap(10))
	var gate_state := T.wrap(T.label("PORTE : AU REPOS  ·  IRIS FERMÉ", "Caption"))
	gate_state.add_theme_font_size_override("font_size", 14)
	sv.add_child(gate_state)

	content = Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = NAV_W + 24
	content.offset_top = TOP_H + 22
	content.offset_right = -24
	content.offset_bottom = -22
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	bar.resized.connect(_fit_frame)


func _fit_frame() -> void:
	if not is_instance_valid(content):
		return
	var nav_width := 210 if size.x < 1250 else NAV_W
	_side.offset_right = nav_width
	_side.offset_top = _header.size.y
	content.offset_left = nav_width + 16
	content.offset_top = _header.size.y + 16


func _resize_content() -> void:
	_fit_frame()
	if visible:
		open.call_deferred(tab)


func _side_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.02, 0.03, 0.05, 0.9)
	s.border_color = Color(T.LINE, 0.9)
	s.border_width_right = 1
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 22
	s.content_margin_bottom = 20
	return s


func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _refresh_frame() -> void:
	for c in stats_box.get_children():
		stats_box.remove_child(c)
		c.queue_free()
	var s: Dictionary = Game.stats
	var done := int(s.done)
	for it in [["NIVEAU", str(s.lvl)], ["EXPÉRIENCE", "%d / %d" % [s.xp, Game.xp_to_next()]], ["NAQUADAH", str(s.naq)],
			["TROUSSES", "%d / %d" % [s.kits, Data.KIT_MAX]], ["MISSIONS", "%d / %d" % [mini(done, Data.PLANETS.size()), Data.PLANETS.size()]]]:
		var b := HBoxContainer.new()
		b.add_theme_constant_override("separation", 8)
		b.alignment = BoxContainer.ALIGNMENT_CENTER
		var c := T.label(it[0], "Caption")
		c.add_theme_font_size_override("font_size", 15)
		b.add_child(c)
		var v := T.label(it[1], "Mono", T.AMBER if it[0] == "NAQUADAH" else T.TEXT)
		b.add_child(v)
		stats_box.add_child(b)
	for c in crew_box.get_children():
		crew_box.remove_child(c)
		c.queue_free()
	for k in Game.team:
		var hp := int(s.hp[k])
		var mx: int = Game.hp_max(k)
		var r := HBoxContainer.new()
		var n := T.label(Data.MEMBERS[k].n, "Body")
		n.add_theme_font_size_override("font_size", 19)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(n)
		var v := T.label("%d/%d" % [hp, mx], "Mono", T.DIM)
		v.add_theme_font_size_override("font_size", 16)
		r.add_child(v)
		crew_box.add_child(r)
		crew_box.add_child(T.gauge(hp, mx, T.hp_color(float(hp) / mx), 5))


# ---------- Les onglets ----------

func open(t: String) -> void:
	tab = t
	location_label.text = "STARGATE COMMAND  //  NIVEAU %d" % {"briefing": 27, "armory": 28, "team": 25, "infirmary": 21}.get(t, 27)
	visible = true
	for key in nav:
		nav[key].set_pressed_no_signal(key == t)
	_refresh_frame()
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	content.modulate.a = 0.0
	content.create_tween().tween_property(content, "modulate:a", 1.0, 0.18)
	match t:
		"briefing":
			_briefing()
		"armory":
			_armory()
		"team":
			_team()
		"infirmary":
			_infirmary()


func close() -> void:
	visible = false


func notice(text: String) -> void:
	_notice = text
	if is_instance_valid(notice_lbl):
		notice_lbl.text = text


func _fill(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(c)
	return c


# ---------- Briefing : liste des destinations et fiche de mission ----------

func _unlocked(i: int) -> bool:
	return Game.unlocked(i)


func _briefing() -> void:
	var n: int = Data.PLANETS.size()
	if sel < 0 or sel >= n or not _unlocked(sel):
		sel = mini(int(Game.stats.done), n - 1)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_fill(scroll)
	var h := VBoxContainer.new()
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 20)
	scroll.add_child(h)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(330, 0)
	left.add_theme_constant_override("separation", 10)
	h.add_child(left)
	left.add_child(T.label("DESTINATIONS", "Section"))
	var destinations := HFlowContainer.new()
	destinations.add_theme_constant_override("h_separation", 10)
	destinations.add_theme_constant_override("v_separation", 10)
	left.add_child(destinations)
	var group := ButtonGroup.new()
	for i in n:
		var p: Dictionary = Data.PLANETS[i]
		var b := Button.new()
		b.theme_type_variation = "Row"
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(330, 58)
		b.button_pressed = i == sel
		b.disabled = not _unlocked(i)
		var r := HBoxContainer.new()
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		r.offset_left = 14
		r.offset_right = -14
		r.add_theme_constant_override("separation", 14)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(r)
		var num := T.label("%02d" % (i + 1), "Mono", T.DIM)
		num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(num)
		var nm := T.label(p.n.to_upper() if _unlocked(i) else "CLASSIFIÉ", "Body", T.TEXT if _unlocked(i) else T.DIM)
		nm.add_theme_font_override("font", T.font("Rajdhani-Bold"))
		nm.add_theme_font_size_override("font_size", 24)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(nm)
		var st := "ACCOMPLIE" if i < int(Game.stats.done) else ("EN COURS" if _unlocked(i) else "VERROUILLÉE")
		var sc := T.label(st, "Caption", T.GREEN if i < int(Game.stats.done) else (T.AMBER if _unlocked(i) else T.DIM))
		sc.add_theme_font_size_override("font_size", 14)
		sc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(sc)
		var idx := i
		b.pressed.connect(func():
			Audio.play("press")
			sel = idx
			open("briefing"))
		destinations.add_child(b)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(fill)
	var ham := PanelContainer.new()
	ham.theme_type_variation = "Card"
	var hv := VBoxContainer.new()
	ham.add_child(hv)
	hv.add_child(T.label("GÉNÉRAL HAMMOND", "Section"))
	var said := "SG-1, vous partez dès que vous êtes prêts." if int(Game.stats.done) < n else "Toutes les menaces sont écartées. Beau travail, SG-1."
	notice_lbl = T.wrap(T.label(_notice if _notice != "" else said, "Body"))
	_notice = ""
	hv.add_child(notice_lbl)
	left.add_child(ham)

	# La fiche ne prend que sa hauteur : la salle de la porte reste visible dessous
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	_mission_sheet(v, sel)


func _mission_sheet(v: VBoxContainer, i: int) -> void:
	var p: Dictionary = Data.PLANETS[i]
	var done := i < int(Game.stats.done)
	var outer := v
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	outer.add_child(top)
	v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(v)
	if content.size.x >= 1100:
		top.add_child(_globe(p))
	var head := VBoxContainer.new()
	v.add_child(head)
	var title := T.wrap(T.label(p.n.to_upper(), "Heading"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var chip := T.label("MISSION ACCOMPLIE" if done else "MISSION %02d · PRIORITÉ ALPHA" % (i + 1), "Caption", T.GREEN if done else T.AMBER)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(chip)

	v.add_child(T.label("ADRESSE", "Section"))
	if p.gate:
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 8)
		var adr: Array = p.adr + [1]
		for k in adr.size():
			var cell := PanelContainer.new()
			cell.add_theme_stylebox_override("panel", T.box(Color(0.02, 0.03, 0.05, 0.9), Color(T.AMBER, 0.45), 6, 1, 6))
			var cv := VBoxContainer.new()
			cv.add_theme_constant_override("separation", 2)
			cell.add_child(cv)
			var tr := TextureRect.new()
			tr.texture = T.glyph(adr[k])
			tr.custom_minimum_size = Vector2(62, 62)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.modulate = T.AMBER
			cv.add_child(tr)
			var lbl := T.label("%d" % (k + 1) if k < 6 else "ORIG.", "Mono", T.DIM)
			lbl.add_theme_font_size_override("font_size", 14)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cv.add_child(lbl)
			cell.tooltip_text = "Chevron %d · %s · symbole %d" % [k + 1, Data.GLYPH_NAMES[adr[k]], adr[k]]
			row.add_child(cell)
		v.add_child(row)
	else:
		v.add_child(T.wrap(T.label("Hors du réseau des portes. Accès par Tel'tak tok'ra puis anneaux de transport.", "Body", T.DIM)))

	v.add_child(T.label("RAPPORT", "Section"))
	v.add_child(T.wrap(T.label(p.brief, "Body", T.TEXT)))
	v.add_child(T.wrap(T.label("COMMANDEMENT EN TEMPS RÉEL · Déplacements et tirs simultanés dans toutes les missions. Sélectionnez un membre ou SG-1 entière, puis donnez un ordre sur le terrain ou sur un ennemi. Espace : pause tactique / reprise.", "Body", T.BLUE)))
	v = outer

	var cols := VBoxContainer.new()
	cols.add_theme_constant_override("separation", 30)
	v.add_child(cols)
	var threats := VBoxContainer.new()
	threats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(threats)
	threats.add_child(T.label("MENACES", "Section"))
	for f in p.foes:
		threats.add_child(_kv(f.n, "PUISS. %d" % f.pow))
	var boss := VBoxContainer.new()
	boss.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(boss)
	boss.add_child(T.label("CIBLE PRINCIPALE", "Section"))
	boss.add_child(_kv(p.boss.n, "PUISS. %d" % p.boss.pow, T.RED))
	var q := T.wrap(T.label("« %s »" % p.boss.q, "Body", T.DIM))
	q.add_theme_font_size_override("font_size", 19)
	boss.add_child(q)

	v.add_child(T.label("RÉCOMPENSE", "Section"))
	v.add_child(T.wrap(T.label("%d XP  ·  %d naquadah pour la cible, plus le butin trouvé sur place" % [p.boss.xp, p.boss.naq], "Mono")))

	v.add_child(_gap(6))
	var foot := VBoxContainer.new()
	foot.add_theme_constant_override("separation", 16)
	v.add_child(foot)
	var g: Dictionary = Game.gear()
	var info := T.wrap(T.label("%s · %s · %d trousse(s)" % [Data.WEAPONS[Game.stats.weapon].n, Data.ARMORS[Game.stats.armor].n, Game.stats.kits], "Body", T.DIM))
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.tooltip_text = "Dégâts +%d · précision +%d %% · armure %d" % [g.dmg, g.hit, g.armor]
	foot.add_child(info)
	var label := "PRÉPARER LE DÉPART"
	var go := T.button(label, launch, "Accent", "Entrée")
	go.custom_minimum_size = Vector2(320, 62)
	go.add_theme_font_size_override("font_size", 24)
	foot.add_child(go)


## La planète en petit globe qui tourne, aux couleurs de son sol et de son ciel
func _globe(p: Dictionary) -> Control:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = Vector2(250, 250)
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_2X
	box.add_child(vp)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.3, 0.4)
	env.ambient_light_energy = 0.4
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-20, -60, 0)
	sun.light_color = p.sun
	sun.light_energy = 1.6
	vp.add_child(sun)
	var ground := StandardMaterial3D.new()
	var noise := FastNoiseLite.new()
	noise.seed = hash(p.n)
	noise.frequency = 0.012
	noise.fractal_octaves = 5
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	var ramp := Gradient.new()
	ramp.set_color(0, p.far.darkened(0.3))
	ramp.set_color(1, p.sky_hz)
	ramp.add_point(0.45, p.ground[0])
	ramp.add_point(0.62, p.ground[1])
	ramp.add_point(0.78, p.far)
	tex.color_ramp = ramp
	ground.albedo_texture = tex
	ground.roughness = 0.9
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radial_segments = 48
	sm.rings = 24
	ball.mesh = sm
	ball.material_override = ground
	ball.rotation_degrees.z = 18
	vp.add_child(ball)
	var air := MeshInstance3D.new()
	var am := SphereMesh.new()
	am.radius = 0.54
	am.height = 1.08
	air.mesh = am
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode unshaded, blend_add, cull_back;\nuniform vec4 c : source_color;\nvoid fragment() {\n\tfloat f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);\n\tALBEDO = c.rgb * f * 1.6;\n}\n"
	var am_mat := ShaderMaterial.new()
	am_mat.shader = sh
	am_mat.set_shader_parameter("c", p.sky_top.lerp(p.sky_hz, 0.4))
	air.material_override = am_mat
	vp.add_child(air)
	var cam := Camera3D.new()
	cam.fov = 30
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 0, 2.3), Vector3.ZERO)
	var tw := ball.create_tween().set_loops()
	tw.tween_property(ball, "rotation:y", TAU, 60.0).from(0.0)
	return box


func _kv(k: String, val: String, color: Color = T.TEXT) -> HBoxContainer:
	var r := HBoxContainer.new()
	var a := T.label(k, "Body", color)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(a)
	r.add_child(T.label(val, "Mono", T.DIM))
	return r


func launch() -> void:
	if not visible or tab != "briefing" or not _unlocked(sel):
		return
	Audio.play("press")
	main.prepare_mission(sel)


func _infirmary() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_fill(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 16)
	scroll.add_child(box)
	box.add_child(T.label("INFIRMERIE · DR JANET FRAISER", "Heading"))
	box.add_child(T.wrap(T.label("Les soins au SGC sont gratuits. Les trousses emportées en mission restent limitées et s'achètent à l'armurerie.", "Body", T.DIM)))
	for key in Game.team:
		box.add_child(_kv(Data.MEMBERS[key].n, "%d / %d PV" % [Game.stats.hp[key], Game.hp_max(key)]))
		box.add_child(T.gauge(Game.stats.hp[key], Game.hp_max(key), T.hp_color(float(Game.stats.hp[key]) / Game.hp_max(key)), 8))
	var heal := T.button("SOIGNER SG-1 · GRATUIT", func():
		Game.heal_all()
		Game.save_game()
		open("infirmary"); notice("SG-1 est entièrement soignée."), "Accent")
	heal.disabled = Game.most_wounded() == ""
	box.add_child(heal)


# ---------- Armurerie ----------

func _armory() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_fill(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 16)
	scroll.add_child(v)

	var s: Dictionary = Game.stats
	var g: Dictionary = Game.gear()
	var sum := PanelContainer.new()
	v.add_child(sum)
	var sh := HFlowContainer.new()
	sh.add_theme_constant_override("h_separation", 20)
	sh.add_theme_constant_override("v_separation", 12)
	sum.add_child(sh)
	var who := VBoxContainer.new()
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.add_child(who)
	who.add_child(T.label("ARMURERIE · SERGENT SILER", "Section"))
	notice_lbl = T.wrap(T.label(_notice if _notice != "" else "Tout ce qui est acheté équipe toute l'équipe, lances comprises.", "Body"))
	_notice = ""
	who.add_child(notice_lbl)
	for it in [["DÉGÂTS", "+%d" % g.dmg], ["PRÉCISION", "+%d %%" % g.hit], ["ARMURE", "-%d" % g.armor], ["NAQUADAH", str(s.naq)]]:
		var c := VBoxContainer.new()
		c.add_child(T.label(it[0], "Caption"))
		var val := T.label(it[1], "Mono", T.AMBER if it[0] == "NAQUADAH" else T.TEXT)
		val.add_theme_font_size_override("font_size", 30)
		c.add_child(val)
		sh.add_child(c)

	var cols: BoxContainer = VBoxContainer.new() if content.size.x < 1050 else HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	v.add_child(cols)
	for kind in [["ARMEMENT", Data.WEAPONS, "weapon"], ["PROTECTIONS", Data.ARMORS, "armor"]]:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 10)
		cols.add_child(col)
		col.add_child(T.label(kind[0], "Section"))
		var items: Array = kind[1]
		for i in items.size():
			col.add_child(_item_card(items[i], i, int(s[kind[2]]), kind[2]))

	v.add_child(T.label("INFIRMERIE", "Section"))
	var kit := PanelContainer.new()
	kit.theme_type_variation = "Card"
	v.add_child(kit)
	var kh := HBoxContainer.new()
	kh.add_theme_constant_override("separation", 20)
	kit.add_child(kh)
	var kv := VBoxContainer.new()
	kv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kh.add_child(kv)
	kv.add_child(_title_line("Trousses de soins", "%d / %d" % [s.kits, Data.KIT_MAX]))
	kv.add_child(T.wrap(T.label("Une action en combat ou ✚ sur la carte : +%d PV." % Data.kit_heal(int(s.lvl)), "Body", T.DIM)))
	if int(s.kits) < Data.KIT_MAX:
		kh.add_child(_buy_button(Data.KIT_PRICE, func(): _buy("kits", int(s.kits) + 1, Data.KIT_PRICE)))
	else:
		kh.add_child(_status("STOCK PLEIN", T.DIM))
	scroll.set_deferred("scroll_vertical", _armory_scroll)
	scroll.get_v_scroll_bar().value_changed.connect(func(value: float): _armory_scroll = int(value))


func _title_line(name: String, right: String) -> HBoxContainer:
	var r := HBoxContainer.new()
	var n := T.label(name, "Body", T.TEXT)
	n.add_theme_font_override("font", T.font("Rajdhani-Bold"))
	n.add_theme_font_size_override("font_size", 25)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(n)
	if right != "":
		r.add_child(T.label(right, "Mono", T.AMBER))
	return r


func _status(text: String, color: Color) -> Label:
	var l := T.label(text, "Caption", color)
	l.custom_minimum_size = Vector2(170, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


func _buy_button(price: int, cb: Callable) -> Button:
	var ok: bool = int(Game.stats.naq) >= price
	var b := T.button("ACHETER · %d" % price, cb, "Accent", "" if ok else "Il manque %d naquadah" % (price - int(Game.stats.naq)))
	b.custom_minimum_size = Vector2(170, 50)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not ok:
		b.theme_type_variation = "Ghost"
		b.disabled = true
		b.text = "MANQUE %d N" % (price - int(Game.stats.naq))
	return b


func _item_card(item: Dictionary, i: int, owned: int, what: String) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = "CardOn" if i == owned else "Card"
	card.modulate = Color(1, 1, 1, 0.55) if i < owned else Color(1, 1, 1)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	card.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	v.add_child(_title_line(item.n, ""))
	var line: String
	if what == "weapon":
		line = "DÉGÂTS +%d   PRÉCISION +%d %%" % [item.dmg, item.hit]
	else:
		line = "ARMURE -%d PAR TIR" % item.armor
	v.add_child(T.label(line, "Mono", T.BLUE))
	v.add_child(T.wrap(T.label(item.txt, "Body", T.DIM)))
	if i == owned:
		h.add_child(_status("ÉQUIPÉ", T.GREEN))
	elif i < owned:
		h.add_child(_status("REMPLACÉ", T.DIM))
	elif int(Game.stats.done) < int(item.req):
		var l := _status("VERROUILLÉ", T.RED)
		l.tooltip_text = "Libérez d'abord %s." % Data.PLANETS[item.req - 1].n
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		h.add_child(l)
		v.add_child(T.label("Après la libération de %s." % Data.PLANETS[item.req - 1].n, "Body", T.RED))
	else:
		h.add_child(_buy_button(item.c, func(): _buy(what, i, item.c)))
	return card


## Un achat à l'armurerie : what = "weapon", "armor" ou "kits"
func _buy(what: String, value: int, price: int) -> void:
	if not Game.buy(what, value, price):
		notice("Pas assez de naquadah : il en faut %d, vous en avez %d." % [price, Game.stats.naq])
		return
	Audio.play("found")
	notice("C'est équipé. Il vous reste %d naquadah." % Game.stats.naq)
	open("armory")


# ---------- Équipe ----------

func _team() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_fill(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 16)
	scroll.add_child(v)
	var s: Dictionary = Game.stats
	var head := PanelContainer.new()
	v.add_child(head)
	var hh := VBoxContainer.new()
	hh.add_theme_constant_override("separation", 30)
	head.add_child(hh)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(hv)
	hv.add_child(T.label("SG-1 · NIVEAU %d" % s.lvl, "Section"))
	hv.add_child(T.gauge(int(s.xp), Game.xp_to_next(), T.BLUE, 8))
	hv.add_child(T.wrap(T.label("%d / %d XP avant le niveau %d : +%d PV par membre et plus de précision." % [s.xp, Game.xp_to_next(), int(s.lvl) + 1, Data.HP_PER_LEVEL], "Body", T.DIM)))
	if not Game.team.has("bratac"):
		var tip := T.wrap(T.label("Maître Bra'tac rejoindra l'équipe après la libération de Chulak.", "Body", T.AMBER))
		tip.custom_minimum_size = Vector2(300, 0)
		hh.add_child(tip)

	var row := GridContainer.new()
	row.columns = maxi(1, int(content.size.x / 290))
	row.add_theme_constant_override("h_separation", 14)
	row.add_theme_constant_override("v_separation", 14)
	v.add_child(row)
	for k in Game.team:
		row.add_child(_member_card(k))


func _member_card(k: String) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	v.add_child(portrait(k))
	var n := T.label(String(Data.MEMBERS[k].n).to_upper(), "Heading")
	n.add_theme_font_size_override("font_size", 30)
	v.add_child(n)
	v.add_child(T.wrap(T.label(Data.MEMBERS[k].role, "Caption")))
	var hp := int(Game.stats.hp[k])
	var mx: int = Game.hp_max(k)
	v.add_child(_kv("Points de vie", "%d / %d" % [hp, mx]))
	v.add_child(T.gauge(hp, mx, T.hp_color(float(hp) / mx), 6))
	v.add_child(_kv("Arme", Data.MEMBERS[k].arm))
	v.add_child(T.label(String(Data.MEMBERS[k].ability).to_upper(), "Section"))
	v.add_child(T.wrap(T.label(Data.MEMBERS[k].skill, "Body", T.DIM)))
	return card


## Un buste du personnage, rendu une fois dans sa petite scène 3D ; face = gros plan sur le visage
static func portrait(k: String, min_size: Vector2 = Vector2(0, 230), face: bool = false) -> Control:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = min_size
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_2X
	# Les grands portraits s'animent (respiration) ; les visages du HUD sont rendus une fois
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE if face else SubViewport.UPDATE_ALWAYS
	box.add_child(vp)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.62, 0.75)
	env.ambient_light_energy = 0.6
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, -35, 0)
	sun.light_energy = 1.3
	vp.add_child(sun)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.2, 2.2, -1.0)
	rim.light_color = Color(0.45, 0.75, 1.0)
	rim.light_energy = 2.0
	rim.omni_range = 4.0
	vp.add_child(rim)
	var who := People.new()
	who.build(k)
	who.rotation_degrees.y = 20
	vp.add_child(who)
	var cam := Camera3D.new()
	cam.fov = 30
	vp.add_child(cam)
	if face:
		cam.look_at_from_position(Vector3(0, 1.82, 1.25), Vector3(0, 1.68, 0))
	else:
		cam.look_at_from_position(Vector3(0, 1.6, 2.1), Vector3(0, 1.42, 0))
	if face:
		# Rendu une fois la pose de repos appliquée par l'animation, puis à chaque redimensionnement
		var viewport_ref: WeakRef = weakref(vp)
		var refresh := func():
			var viewport = viewport_ref.get_ref()
			if viewport != null:
				viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		box.resized.connect(refresh)
		box.tree_entered.connect(func(): box.get_tree().create_timer(0.3).timeout.connect(refresh), CONNECT_ONE_SHOT)
	return box


# ---------- Clavier ----------

func _unhandled_input(e: InputEvent) -> void:
	if not visible or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	match e.keycode:
		KEY_1, KEY_KP_1:
			open("briefing")
		KEY_2, KEY_KP_2:
			open("armory")
		KEY_3, KEY_KP_3:
			open("team")
		KEY_4, KEY_KP_4:
			open("infirmary")
		KEY_ESCAPE:
			main.return_to_sgc()
		KEY_ENTER, KEY_KP_ENTER:
			launch()
		KEY_UP, KEY_DOWN:
			if tab == "briefing":
				var d := -1 if e.keycode == KEY_UP else 1
				var j := sel + d
				if j >= 0 and j < Data.PLANETS.size() and _unlocked(j):
					sel = j
					Audio.play("press")
					open("briefing")
		_:
			return
	get_viewport().set_input_as_handled()
