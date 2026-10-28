extends Control
## L'écran des options, construit à partir de Settings.SCHEMA : un onglet par catégorie,
## une ligne par réglage. Tactile : ◀ ▶ ou le curseur. Clavier : ↑ ↓ pour la ligne, ← → pour la valeur,
## Échap pour revenir. Il fonctionne aussi pendant la pause.

const T = preload("res://scripts/ui_theme.gd")

signal closed

const CONTROL_W := 400

var tab: String = Settings.TABS[0][0]
var _tabs := {}
var _rows := {}
var _list: VBoxContainer
var _help: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := ColorRect.new()
	veil.color = Color(0.0, 0.01, 0.02, 0.8)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(veil)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", T.box(Color(0.03, 0.045, 0.07, 0.97), T.LINE, 16, 1, 26))
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -520
	panel.offset_right = 520
	panel.offset_top = 40
	panel.offset_bottom = -40
	add_child(panel)
	var fit := func():
		var half := minf(520, maxf(150, (size.x - 32) / 2))
		panel.offset_left = -half
		panel.offset_right = half
		panel.offset_top = 16
		panel.offset_bottom = -16
	resized.connect(fit)
	fit.call()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)

	var head := T.label("OPTIONS", "Heading")
	v.add_child(head)
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	v.add_child(tabs)
	var group := ButtonGroup.new()
	for t in Settings.TABS:
		var b := Button.new()
		b.text = t[1]
		b.theme_type_variation = "Tab"
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 50)
		var key: String = t[0]
		b.pressed.connect(func():
			Audio.play("press")
			show_tab(key))
		tabs.add_child(b)
		_tabs[key] = b

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	_help = T.wrap(T.label("", "Body", T.DIM))
	_help.custom_minimum_size = Vector2(0, 56)
	_help.add_theme_font_size_override("font_size", 19)
	v.add_child(_help)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	v.add_child(foot)
	var reset := T.button("PAR DÉFAUT", func():
		Audio.play("press")
		_confirm_reset(), "Ghost", "Rétablir tous les réglages d'origine")
	reset.focus_mode = Control.FOCUS_NONE
	foot.add_child(reset)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(spacer)
	var back := T.button("RETOUR", close, "Accent", "Échap")
	back.focus_mode = Control.FOCUS_NONE
	back.custom_minimum_size = Vector2(220, 56)
	foot.add_child(back)

	Settings.changed.connect(_on_changed)
	show_tab(tab)
	resized.connect(func(): show_tab.call_deferred(tab))


func _confirm_reset() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Réinitialiser les options"
	dialog.dialog_text = "Rétablir tous les réglages d'origine, dans toutes les catégories ?"
	dialog.ok_button_text = "Réinitialiser"
	dialog.cancel_button_text = "Annuler"
	dialog.confirmed.connect(func(): Settings.reset_defaults(); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()


func close() -> void:
	Audio.play("press")
	closed.emit()
	queue_free()


func show_tab(t: String) -> void:
	tab = t
	_tabs[t].set_pressed_no_signal(true)
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_rows.clear()
	if t == "game":
		_list.add_child(T.wrap(T.label("La difficulté de campagne se règle ici. Pour une expédition RTS indépendante, utilisez Engagement avant le déploiement.", "Body", T.DIM)))
	for key in Settings.keys_of(t):
		_list.add_child(_row(key))
	_refresh()
	if _list.get_child_count() > 0:
		for child in _list.get_children():
			if child is Button:
				child.grab_focus()
				break


# ---------- Une ligne ----------

func _row(key: String) -> Control:
	var s: Dictionary = Settings.spec(key)
	var row := Button.new()
	row.theme_type_variation = "SettingRow"
	var compact := size.x < 950
	row.custom_minimum_size = Vector2(0, 110 if compact else 62)
	row.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	var h: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 16
	h.offset_right = -10
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(h)
	var name := T.wrap(T.label(s.label, "Body", T.TEXT))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(name)
	var ctl := HBoxContainer.new()
	ctl.custom_minimum_size = Vector2(minf(CONTROL_W, maxf(150, size.x - 120)), 0)
	ctl.add_theme_constant_override("separation", 8)
	ctl.alignment = BoxContainer.ALIGNMENT_END
	h.add_child(ctl)
	var r := {"row": row, "name": name}

	if s.kind == "range":
		var sl := HSlider.new()
		sl.min_value = s.min
		sl.max_value = s.max
		sl.step = s.step
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sl.custom_minimum_size = Vector2(0, 40)
		sl.focus_mode = Control.FOCUS_NONE
		sl.value_changed.connect(func(x: float): Settings.set_value(key, x))
		ctl.add_child(sl)
		var val := T.label("", "Mono", T.AMBER)
		val.custom_minimum_size = Vector2(80, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ctl.add_child(val)
		r["slider"] = sl
		r["value"] = val
	else:
		var prev := _arrow("◀", func(): _step(key, -1))
		ctl.add_child(prev)
		var val := T.label("", "Body", T.AMBER)
		val.add_theme_font_override("font", T.font("Rajdhani-Bold"))
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ctl.add_child(val)
		var next := _arrow("▶", func(): _step(key, 1))
		ctl.add_child(next)
		r["value"] = val
		r["arrows"] = [prev, next]
		# Un toucher ou Entrée sur la ligne avance d'un cran (pratique pour Oui / Non)
		row.pressed.connect(func(): _step(key, 1))

	row.gui_input.connect(func(e: InputEvent): _row_input(key, e))
	row.focus_entered.connect(func(): _show_help(key))
	row.mouse_entered.connect(func(): _show_help(key))
	_rows[key] = r
	return row


func _arrow(text: String, cb: Callable) -> Button:
	var b := T.button(text, cb, "Ghost")
	b.custom_minimum_size = Vector2(56, 46)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", ThemeDB.fallback_font)
	b.add_theme_font_size_override("font_size", 18)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


func _step(key: String, dir: int) -> void:
	if not Settings.is_active(key):
		return
	Audio.play("press")
	Settings.step(key, dir)


func _row_input(key: String, e: InputEvent) -> void:
	if e.is_action_pressed("ui_left", true):
		_step(key, -1)
		accept_event()
	elif e.is_action_pressed("ui_right", true):
		_step(key, 1)
		accept_event()


func _show_help(key: String) -> void:
	var s: Dictionary = Settings.spec(key)
	var text: String = s.get("tip", "")
	if not Settings.is_active(key):
		text = "Sans effet pour l'instant. " + text
	_help.text = text


# ---------- Mise à jour ----------

func _on_changed(_key: String) -> void:
	_refresh()


func _refresh() -> void:
	for key in _rows:
		var r: Dictionary = _rows[key]
		var on := Settings.is_active(key)
		r.value.text = Settings.display(key)
		if key == "upscaler" and not on:
			r.value.text = "Bilinéaire · mobile"
		if r.has("slider"):
			r.slider.set_value_no_signal(Settings.value(key))
			r.slider.editable = on
		for a in r.get("arrows", []):
			a.disabled = not on
		r.row.modulate = Color(1, 1, 1, 1.0 if on else 0.45)


func _input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_TAB]:
		# Tab : onglet suivant (Maj+Tab : précédent)
		var i := 0
		for j in Settings.TABS.size():
			if Settings.TABS[j][0] == tab:
				i = j
		i = posmod(i + (-1 if e.shift_pressed else 1), Settings.TABS.size())
		Audio.play("press")
		show_tab(Settings.TABS[i][0])
		get_viewport().set_input_as_handled()
