extends RefCounted
## Le thème « écrans du SGC » : panneaux sombres, filets fins, coins coupés, ambre et bleu.

const BG := Color(0.03, 0.045, 0.07, 0.9)
const BG2 := Color(0.055, 0.08, 0.115, 0.94)
const BG3 := Color(0.08, 0.115, 0.16, 0.96)
const LINE := Color(0.24, 0.36, 0.5, 0.8)
const AMBER := Color(1.0, 0.7, 0.28)
const BLUE := Color(0.42, 0.78, 1.0)
const TEXT := Color(0.86, 0.9, 0.95)
const DIM := Color(0.52, 0.6, 0.7)
const GREEN := Color(0.45, 0.9, 0.5)
const RED := Color(1.0, 0.42, 0.34)

static var fonts := {}


static func font(n: String) -> Font:
	if fonts.is_empty():
		for k in ["Rajdhani-Medium", "Rajdhani-SemiBold", "Rajdhani-Bold", "ShareTechMono-Regular", "PressStart2P"]:
			var f := FontFile.new()
			f.load_dynamic_font(ProjectSettings.globalize_path("res://assets/fonts/%s.ttf" % k))
			fonts[k] = f
		# Les légendes en capitales espacées
		var cap := FontVariation.new()
		cap.base_font = fonts["Rajdhani-Bold"]
		cap.spacing_glyph = 2
		fonts["caption"] = cap
	return fonts[n]


## Un cadre à coins coupés (en haut à gauche et en bas à droite)
static func box(bg: Color, border: Color = LINE, cut: int = 12, bw: int = 1, margin: int = 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw if border.a > 0 else 0)
	sb.corner_detail = 1
	sb.corner_radius_top_left = cut
	sb.corner_radius_bottom_right = cut
	sb.set_content_margin_all(margin)
	sb.anti_aliasing = true
	return sb


static func _button_styles(t: Theme, type: String, base: Color, accent: Color) -> void:
	# Fonds opaques (teintés) : les boutons restent lisibles sur la 3D
	var n := box(Color(BG2.lerp(base, 0.16), 0.95), Color(accent, 0.55), 10, 1, 10)
	n.content_margin_left = 18
	n.content_margin_right = 18
	t.set_stylebox("normal", type, n)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(BG2.lerp(base, 0.3), 0.96)
	h.border_color = accent
	t.set_stylebox("hover", type, h)
	var p := n.duplicate() as StyleBoxFlat
	p.bg_color = Color(BG2.lerp(base, 0.45), 0.97)
	p.border_color = accent
	t.set_stylebox("pressed", type, p)
	t.set_stylebox("hover_pressed", type, p)
	var d := n.duplicate() as StyleBoxFlat
	d.bg_color = Color(0.07, 0.08, 0.1, 0.9)
	d.border_color = Color(0.35, 0.38, 0.42, 0.5)
	t.set_stylebox("disabled", type, d)
	var f := StyleBoxFlat.new()
	f.draw_center = false
	f.border_color = Color(accent, 0.9)
	f.set_border_width_all(2)
	f.corner_detail = 1
	f.corner_radius_top_left = 10
	f.corner_radius_bottom_right = 10
	f.expand_margin_left = 3
	f.expand_margin_right = 3
	f.expand_margin_top = 3
	f.expand_margin_bottom = 3
	t.set_stylebox("focus", type, f)
	t.set_color("font_color", type, TEXT)
	t.set_color("font_hover_color", type, Color(1, 1, 1))
	t.set_color("font_pressed_color", type, Color(1, 1, 1))
	t.set_color("font_hover_pressed_color", type, Color(1, 1, 1))
	t.set_color("font_focus_color", type, TEXT)
	t.set_color("font_disabled_color", type, DIM)
	t.set_font("font", type, font("Rajdhani-Bold"))
	t.set_font_size("font_size", type, 22)


static func make() -> Theme:
	var t := Theme.new()
	t.default_font = font("Rajdhani-SemiBold")
	t.default_font_size = 22

	_button_styles(t, "Button", BLUE, BLUE)
	t.set_constant("h_separation", "Button", 10)
	for v in [["Accent", AMBER, AMBER], ["Danger", RED, RED], ["Ghost", Color(0.5, 0.6, 0.7), Color(0.4, 0.5, 0.62)]]:
		t.set_type_variation(v[0], "Button")
		_button_styles(t, v[0], v[1], v[2])

	# La navigation de gauche : à plat, liseré ambre sur l'onglet actif
	t.set_type_variation("Nav", "Button")
	var nn := StyleBoxFlat.new()
	nn.bg_color = Color(0, 0, 0, 0)
	nn.content_margin_left = 20
	nn.content_margin_top = 10
	nn.content_margin_bottom = 10
	t.set_stylebox("normal", "Nav", nn)
	var nh := nn.duplicate() as StyleBoxFlat
	nh.bg_color = Color(BLUE, 0.1)
	t.set_stylebox("hover", "Nav", nh)
	var np := nn.duplicate() as StyleBoxFlat
	np.bg_color = Color(AMBER, 0.14)
	np.border_color = AMBER
	np.border_width_left = 4
	t.set_stylebox("pressed", "Nav", np)
	t.set_stylebox("hover_pressed", "Nav", np)
	t.set_stylebox("focus", "Nav", box(Color(BLUE, 0.06), BLUE, 4, 2, 10))
	t.set_color("font_color", "Nav", DIM)
	t.set_color("font_hover_color", "Nav", TEXT)
	t.set_color("font_pressed_color", "Nav", AMBER)
	t.set_color("font_hover_pressed_color", "Nav", AMBER)
	t.set_font("font", "Nav", font("caption"))
	t.set_font_size("font_size", "Nav", 22)

	# Les lignes de liste (planètes) : sélection en bleu
	t.set_type_variation("Row", "Button")
	var rn := box(Color(BG2, 0.7), Color(LINE, 0.5), 8, 1, 12)
	t.set_stylebox("normal", "Row", rn)
	var rh := rn.duplicate() as StyleBoxFlat
	rh.border_color = BLUE
	t.set_stylebox("hover", "Row", rh)
	var rp := rn.duplicate() as StyleBoxFlat
	rp.bg_color = Color(BLUE, 0.16)
	rp.border_color = BLUE
	rp.border_width_left = 4
	t.set_stylebox("pressed", "Row", rp)
	t.set_stylebox("hover_pressed", "Row", rp)
	t.set_stylebox("focus", "Row", box(Color(BLUE, 0.06), BLUE, 4, 2, 10))
	t.set_color("font_color", "Row", TEXT)
	t.set_color("font_pressed_color", "Row", Color(1, 1, 1))
	t.set_color("font_hover_pressed_color", "Row", Color(1, 1, 1))
	t.set_color("font_disabled_color", "Row", DIM)
	t.set_font("font", "Row", font("Rajdhani-Bold"))
	t.set_font_size("font_size", "Row", 24)

	# Les onglets horizontaux (options) : liseré ambre sous l'onglet actif
	t.set_type_variation("Tab", "Button")
	var tn := StyleBoxFlat.new()
	tn.bg_color = Color(0, 0, 0, 0)
	tn.border_color = Color(LINE, 0.6)
	tn.border_width_bottom = 1
	tn.content_margin_left = 22
	tn.content_margin_right = 22
	tn.content_margin_top = 8
	tn.content_margin_bottom = 8
	t.set_stylebox("normal", "Tab", tn)
	var th := tn.duplicate() as StyleBoxFlat
	th.bg_color = Color(BLUE, 0.1)
	t.set_stylebox("hover", "Tab", th)
	var tp := tn.duplicate() as StyleBoxFlat
	tp.bg_color = Color(AMBER, 0.12)
	tp.border_color = AMBER
	tp.border_width_bottom = 3
	t.set_stylebox("pressed", "Tab", tp)
	t.set_stylebox("hover_pressed", "Tab", tp)
	t.set_stylebox("focus", "Tab", box(Color(BLUE, 0.06), BLUE, 4, 2, 10))
	t.set_color("font_color", "Tab", DIM)
	t.set_color("font_hover_color", "Tab", TEXT)
	t.set_color("font_pressed_color", "Tab", AMBER)
	t.set_color("font_hover_pressed_color", "Tab", AMBER)
	t.set_font("font", "Tab", font("caption"))
	t.set_font_size("font_size", "Tab", 20)

	# Une ligne de réglage : toute la ligne prend le focus, gauche et droite changent la valeur
	t.set_type_variation("SettingRow", "Button")
	var sn := box(Color(BG2, 0.55), Color(0, 0, 0, 0), 8, 0, 10)
	t.set_stylebox("normal", "SettingRow", sn)
	t.set_stylebox("pressed", "SettingRow", sn)
	t.set_stylebox("disabled", "SettingRow", sn)
	var sh := box(Color(BLUE, 0.1), Color(0, 0, 0, 0), 8, 0, 10)
	t.set_stylebox("hover", "SettingRow", sh)
	t.set_stylebox("hover_pressed", "SettingRow", sh)
	var sf := box(Color(0, 0, 0, 0), AMBER, 8, 2, 10)
	sf.draw_center = false
	t.set_stylebox("focus", "SettingRow", sf)

	# Les curseurs (volumes, échelles)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.1)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	var filled := track.duplicate() as StyleBoxFlat
	filled.bg_color = Color(BLUE, 0.75)
	t.set_stylebox("grabber_area", "HSlider", filled)
	var filled_h := track.duplicate() as StyleBoxFlat
	filled_h.bg_color = BLUE
	t.set_stylebox("grabber_area_highlight", "HSlider", filled_h)
	t.set_icon("grabber", "HSlider", _dot(26, TEXT))
	t.set_icon("grabber_highlight", "HSlider", _dot(26, Color(1, 1, 1)))
	t.set_icon("grabber_disabled", "HSlider", _dot(26, DIM))

	t.set_stylebox("panel", "PanelContainer", box(BG, LINE, 14, 1, 18))
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", box(BG2, Color(LINE, 0.6), 10, 1, 14))
	t.set_type_variation("CardOn", "PanelContainer")
	t.set_stylebox("panel", "CardOn", box(Color(0.06, 0.12, 0.09, 0.94), Color(GREEN, 0.75), 10, 1, 14))
	t.set_type_variation("Bar", "PanelContainer")
	var bar := box(Color(0.02, 0.03, 0.05, 0.92), Color(0, 0, 0, 0), 0, 0, 0)
	bar.border_color = Color(LINE, 0.9)
	bar.border_width_bottom = 1
	bar.content_margin_left = 22
	bar.content_margin_right = 14
	bar.content_margin_top = 8
	bar.content_margin_bottom = 8
	t.set_stylebox("panel", "Bar", bar)

	t.set_color("font_color", "Label", TEXT)
	t.set_type_variation("Caption", "Label")
	t.set_font("font", "Caption", font("caption"))
	t.set_font_size("font_size", "Caption", 17)
	t.set_color("font_color", "Caption", DIM)
	t.set_type_variation("Heading", "Label")
	t.set_font("font", "Heading", font("Rajdhani-Bold"))
	t.set_font_size("font_size", "Heading", 40)
	t.set_color("font_color", "Heading", Color(1, 1, 1))
	t.set_type_variation("Section", "Label")
	t.set_font("font", "Section", font("caption"))
	t.set_font_size("font_size", "Section", 19)
	t.set_color("font_color", "Section", AMBER)
	t.set_type_variation("Body", "Label")
	t.set_font("font", "Body", font("Rajdhani-Medium"))
	t.set_font_size("font_size", "Body", 22)
	t.set_color("font_color", "Body", Color(0.75, 0.8, 0.87))
	t.set_type_variation("Mono", "Label")
	t.set_font("font", "Mono", font("ShareTechMono-Regular"))
	t.set_font_size("font_size", "Mono", 20)
	t.set_color("font_color", "Mono", TEXT)

	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(1, 1, 1, 0.08)
	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = GREEN
	t.set_stylebox("background", "ProgressBar", pb_bg)
	t.set_stylebox("fill", "ProgressBar", pb_fill)
	t.set_font_size("font_size", "ProgressBar", 1)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.05)
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	t.set_stylebox("scroll", "VScrollBar", sb)
	var gr := StyleBoxFlat.new()
	gr.bg_color = Color(BLUE, 0.4)
	gr.content_margin_left = 3
	gr.content_margin_right = 3
	t.set_stylebox("grabber", "VScrollBar", gr)
	var grh := gr.duplicate() as StyleBoxFlat
	grh.bg_color = Color(BLUE, 0.7)
	t.set_stylebox("grabber_highlight", "VScrollBar", grh)
	t.set_stylebox("grabber_pressed", "VScrollBar", grh)

	t.set_stylebox("panel", "TooltipPanel", box(Color(0.02, 0.03, 0.05, 0.97), BLUE, 6, 1, 10))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font("font", "TooltipLabel", font("Rajdhani-Medium"))
	t.set_font_size("font_size", "TooltipLabel", 20)
	return t


## Un disque plein, pour la poignée des curseurs
static func _dot(d: int, c: Color) -> ImageTexture:
	var img := Image.create_empty(d, d, false, Image.FORMAT_RGBA8)
	var r := d / 2.0
	for y in d:
		for x in d:
			var a := clampf(r - Vector2(x + 0.5, y + 0.5).distance_to(Vector2(r, r)), 0.0, 1.0)
			img.set_pixel(x, y, Color(c, c.a * a))
	return ImageTexture.create_from_image(img)


static var _glyphs := {}


## Le symbole k (1 à 39) de la porte des étoiles ; 1 est le point d'origine de la Terre
static func glyph(k: int) -> Texture2D:
	if not _glyphs.has(k):
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/glyphs/g%02d.png" % k))
		_glyphs[k] = ImageTexture.create_from_image(img)
	return _glyphs[k]


static func label(text: String, variation: String = "Body", color: Color = Color(0, 0, 0, 0)) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	if color.a > 0:
		l.add_theme_color_override("font_color", color)
	return l


static func wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, cb: Callable, variation: String = "", tip: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(0, 52)
	b.pressed.connect(cb)
	return b


## Fenêtre centrée et défilable : aucune action ne sort de l'écran à grande échelle.
static func modal(parent: Control, width: float = 640) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	panel.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	var owner_ref: WeakRef = weakref(parent)
	var scroll_ref: WeakRef = weakref(scroll)
	var body_ref: WeakRef = weakref(body)
	var fit := func():
		var owner: Control = owner_ref.get_ref()
		var scroller: ScrollContainer = scroll_ref.get_ref()
		var content: VBoxContainer = body_ref.get_ref()
		if owner == null or scroller == null or content == null:
			return
		var available := owner.size - Vector2(48, 48)
		var w := minf(width, maxf(240, available.x))
		scroller.custom_minimum_size = Vector2(maxf(1, w - 36), minf(maxf(80, available.y - 36), content.get_combined_minimum_size().y))
	parent.resized.connect(fit)
	body.minimum_size_changed.connect(fit)
	fit.call_deferred()
	return body


## Une barre de progression fine et colorée
static func gauge(value: float, max_value: float, color: Color, height: int = 8) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = max_value
	b.value = value
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, height)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	b.add_theme_stylebox_override("fill", fill)
	return b


static func hp_color(ratio: float) -> Color:
	return GREEN if ratio > 0.5 else (AMBER if ratio > 0.25 else RED)
