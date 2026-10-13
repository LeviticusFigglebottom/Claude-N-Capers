## B4-07: GSR theme pass + per-heist accents. Accent data follows style_guide.md §3; the theme's
## text colours keep WCAG body-text contrast (>= 4.5:1) on the surfaces they sit on; accent-coloured
## text is lifted to 4.5:1; screens apply the heist accent (briefing, pre-planning, Board card, HUD).
extends TestCase

const BODY_TEXT: float = 4.5
const NON_TEXT: float = 3.0

var _theme: Theme


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()
	_theme = UiBuild.theme()


func after_all() -> void:
	SaveService.delete_profile(0)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func _bg(type: StringName, style: StringName, under: Color) -> Color:
	var sb: StyleBoxFlat = _theme.get_stylebox(style, type) as StyleBoxFlat
	assert_true(sb != null, "%s/%s is a StyleBoxFlat" % [type, style])
	return UiAccent.over(sb.bg_color, under) if sb != null else under


func _font(type: StringName, color_name: StringName = &"font_color") -> Color:
	assert_true(_theme.has_color(color_name, type), "%s/%s set" % [type, color_name])
	return _theme.get_color(color_name, type)


## Colours equal to about 1/255 per channel (hex values are written to .tres with 4 digits).
static func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.003 and absf(a.g - b.g) < 0.003 and absf(a.b - b.b) < 0.003


func _check(fg: Color, bg: Color, minimum: float, what: String) -> void:
	var r: float = UiAccent.contrast_ratio(fg, bg)
	assert_true(r >= minimum, "%s contrast %.2f < %.1f" % [what, r, minimum])


func test_contrast_math() -> void:
	assert_near(UiAccent.contrast_ratio(Color.WHITE, Color.BLACK), 21.0, 0.01)
	assert_near(UiAccent.contrast_ratio(Color(0.5, 0.5, 0.5), Color(0.5, 0.5, 0.5)), 1.0, 0.0001)
	assert_near(UiAccent.relative_luminance(Color.WHITE), 1.0, 0.0001)
	assert_eq(UiAccent.over(Color(1, 1, 1, 0.5), Color.BLACK), Color(0.5, 0.5, 0.5, 1))


func test_theme_text_contrast() -> void:
	var app: Color = UiAccent.app_bg()
	var panel: Color = UiAccent.panel_bg()
	assert_true(UiAccent.relative_luminance(app) < 0.02, "dark app background")
	assert_true(app.b >= app.r, "PO-4 Case File: cool ink dark (blue >= red)")
	for t: StringName in [&"Label", &"HeaderLabel", &"SubheaderLabel", &"DimLabel"]:
		_check(_font(t), app, BODY_TEXT, "%s on app background" % t)
		_check(_font(t), panel, BODY_TEXT, "%s on panel" % t)
	var btn_font: Color = _font(&"Button")
	for under: Color in [app, panel]:
		_check(btn_font, _bg(&"Button", &"normal", under), BODY_TEXT, "Button normal")
		_check(_font(&"Button", &"font_hover_color"), _bg(&"Button", &"hover", under), BODY_TEXT, "Button hover")
		_check(_font(&"Button", &"font_focus_color"), _bg(&"Button", &"normal", under), BODY_TEXT, "Button focus")
		_check(_font(&"Button", &"font_pressed_color"), _bg(&"Button", &"pressed", under), BODY_TEXT, "Button pressed")
		_check(_font(&"Button", &"font_hover_pressed_color"), _bg(&"Button", &"hover_pressed", under), BODY_TEXT,
				"Button hover+pressed")
		_check(_font(&"PrimaryButton"), _bg(&"PrimaryButton", &"normal", under), BODY_TEXT, "Primary normal")
		_check(_font(&"PrimaryButton", &"font_hover_color"), _bg(&"PrimaryButton", &"hover", under), BODY_TEXT, "Primary hover")
		_check(_font(&"SubheaderLabel"), _bg(&"StationButton", &"normal", under), BODY_TEXT, "station title")
		_check(_font(&"DimLabel"), _bg(&"StationButton", &"hover", under), BODY_TEXT, "station desc (hover)")
	_check(_font(&"PopupMenu"), _bg(&"PopupMenu", &"panel", app), BODY_TEXT, "dropdown items")
	_check(_font(&"PopupMenu", &"font_hover_color"), _bg(&"PopupMenu", &"hover", _bg(&"PopupMenu", &"panel", app)),
			BODY_TEXT, "dropdown hover item")
	_check(_font(&"TooltipLabel"), _bg(&"TooltipPanel", &"panel", app), BODY_TEXT, "tooltip")
	# HUD text over its translucent panel on a dark scene (outlined too).
	_check(_font(&"HudLabel"), _bg(&"HudPanel", &"panel", Color(0.2, 0.2, 0.2)), BODY_TEXT, "HUD label")


func test_focus_ring_is_the_interactable_accent() -> void:
	var focus: StyleBoxFlat = _theme.get_stylebox(&"focus", &"Button") as StyleBoxFlat
	var cyan: Color = Color("#4FD1E8")
	assert_true(_near(focus.border_color, cyan), "style guide §3: UI highlight = #4FD1E8")
	_check(focus.border_color, _bg(&"Button", &"normal", UiAccent.panel_bg()), NON_TEXT, "focus ring")
	assert_true(_near(_theme.get_color(&"highlight", &"Screen"), cyan))


func test_chamfered_corners() -> void:
	for pair: Array in [[&"Button", &"normal"], [&"PanelContainer", &"panel"], [&"StationButton", &"normal"]]:
		var sb: StyleBoxFlat = _theme.get_stylebox(StringName(pair[1]), StringName(pair[0])) as StyleBoxFlat
		assert_eq(sb.corner_detail, 1, "%s: straight chamfer" % pair[0])
		assert_true(sb.corner_radius_top_left > 0 and sb.corner_radius_bottom_right > 0, "%s chamfered" % pair[0])


func test_accents_follow_the_style_guide() -> void:
	assert_true(_near(UiAccent.for_heist(&"glasshouse"), Color("#C9A227")), "brass")
	assert_true(_near(UiAccent.for_heist(&"night_deposit"), Color("#9E2B25")), "bank red")
	assert_true(_near(UiAccent.for_heist(&"dockside_burn"), Color("#FF6B1A")), "flare orange")
	assert_eq(UiAccent.for_heist(&"no_such_heist"), UiAccent.table().fallback, "fallback")
	for id: StringName in HeistCatalog.ids():
		assert_true(UiAccent.table().accents.has(id), "every listed heist has an accent: %s" % id)


func test_accent_text_is_readable() -> void:
	var ids: Array = UiAccent.table().accents.keys()
	ids.append(&"no_such_heist")
	for id: Variant in ids:
		for bg: Color in [UiAccent.panel_bg(), UiAccent.app_bg()]:
			_check(UiAccent.text_color(StringName(id), bg), bg, BODY_TEXT, "accent text %s" % id)
	assert_eq(UiAccent.readable(Color.WHITE, Color.BLACK, 4.5), Color.WHITE, "already readable: unchanged")
	assert_true(UiAccent.contrast_ratio(UiAccent.readable(Color(0.2, 0.0, 0.0), Color.BLACK, 4.5), Color.BLACK) >= 4.5)


func test_accent_panel_and_strip() -> void:
	var p: PanelContainer = UiBuild.panel(Label.new())
	p.theme = _theme
	add_child(p)
	UiAccent.accent_panel(p, Color.RED, 5)
	var sb: StyleBoxFlat = p.get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_eq(sb.border_width_left, 5)
	assert_true(_near(sb.border_color, Color.RED))
	var theme_sb: StyleBoxFlat = _theme.get_stylebox(&"panel", &"PanelContainer") as StyleBoxFlat
	assert_ne(theme_sb.border_width_left, 5, "the shared theme box is not modified")
	var s: ColorRect = UiAccent.strip(Color.BLUE, 8.0)
	assert_eq(s.color, Color.BLUE)
	assert_eq(s.custom_minimum_size.x, 8.0)
	s.free()
	p.queue_free()
	await wait_frames(1)


func test_briefing_and_preplanning_use_the_accent() -> void:
	var b: BriefingScreen = (load("res://content/ui/briefing/briefing_screen.tscn") as PackedScene).instantiate() as BriefingScreen
	b.setup(&"night_deposit", Enums.Difficulty.ROUTINE)
	add_child(b)
	await wait_frames(1)
	assert_eq(b.accent_strip.color, UiAccent.for_heist(&"night_deposit"))
	var c: Color = b.heist_label.get_theme_color(&"font_color")
	_check(c, UiAccent.app_bg(), BODY_TEXT, "briefing heist name")
	assert_true(c.r > c.b, "reads as the red accent")
	b.setup(&"glasshouse", Enums.Difficulty.ROUTINE)
	assert_eq(b.accent_strip.color, UiAccent.for_heist(&"glasshouse"), "follows setup()")
	b.queue_free()
	var p: PreplanningScreen = (load("res://content/ui/preplanning/preplanning_screen.tscn") as PackedScene).instantiate() as PreplanningScreen
	p.save_on_confirm = false
	p.setup(&"night_deposit", Enums.Difficulty.ROUTINE, PlayerProfile.new_default())
	add_child(p)
	await wait_frames(1)
	assert_eq(p.accent_strip.color, UiAccent.for_heist(&"night_deposit"))
	p.queue_free()
	await wait_frames(1)


func test_board_card_and_hud_objectives_use_the_accent() -> void:
	var bs: BoardScreen = (load("res://content/ui/board/board_screen.tscn") as PackedScene).instantiate() as BoardScreen
	bs.save_on_buy = false
	bs.setup(PlayerProfile.new_default())
	add_child(bs)
	await wait_frames(1)
	if not bs.contracts.is_empty():
		bs.select_slot(0)
		var id: StringName = StringName(bs.selected_contract()["heist_id"])
		var sb: StyleBoxFlat = bs.card_panel.get_theme_stylebox(&"panel") as StyleBoxFlat
		assert_true(_near(sb.border_color, UiAccent.for_heist(id)), "card edge = heist accent")
		_check(bs.heist_label.get_theme_color(&"font_color"), UiAccent.panel_bg(), BODY_TEXT, "card heist name")
	bs.queue_free()
	var hud: Hud = (load("res://content/ui/hud/hud.tscn") as PackedScene).instantiate() as Hud
	hud.auto_find_model = false
	hud.heist_id = &"night_deposit"
	add_child(hud)
	await wait_frames(1)
	assert_eq(hud.objectives.accent, UiAccent.for_heist(&"night_deposit"))
	var hsb: StyleBoxFlat = hud.objectives.panel.get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_eq(hsb.border_width_left, 3, "objective accent edge (PO-4 hairline, frameless HUD)")
	hud.queue_free()
	await wait_frames(1)
