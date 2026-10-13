## PO-4: builds the shared Theme (caper_theme.tres) from UiTokens, so every screen inherits one look
## and nothing styles itself ad hoc. Owner: ENV B. Regenerate the .tres after a token change:
##   /opt/godot/godot --headless --path game --script res://content/ui/theme/build_theme.gd
## (test_ui_theme checks the saved theme still matches build()).
## Variations kept for existing callers: HeaderLabel, SubheaderLabel, DimLabel, HudLabel, HudBigLabel,
## HudPanel, BannerPanel, PrimaryButton, StationButton. New: CaptionLabel, DisplayLabel, MoneyLabel,
## KeyCap, GhostButton, TabButton, MenuItemButton, CardPanel, ScrimPanel, AlertPanel.
class_name UiThemeFactory
extends RefCounted

const T := preload("res://content/ui/theme/ui_tokens.gd")


static func build() -> Theme:
	var th: Theme = Theme.new()
	th.default_font = T.font_body()
	th.default_font_size = T.FONT_BODY
	_labels(th)
	_buttons(th)
	_panels(th)
	_fields(th)
	_bars(th)
	_screen(th)
	return th


# --- StyleBox helpers ------------------------------------------------------------------------------

## A chamfered box: top-left and bottom-right corners cut by `cut` (corner_detail 1 = a straight cut).
static func box(bg: Color, border: Color = Color(0, 0, 0, 0), width: int = 0, cut: int = T.CUT,
		pad: Vector2 = Vector2(T.S4, T.S3)) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.corner_radius_top_left = cut
	sb.corner_radius_bottom_right = cut
	sb.corner_detail = 1
	sb.anti_aliasing_size = 0.6
	sb.content_margin_left = pad.x
	sb.content_margin_right = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_bottom = pad.y
	return sb


## The cyan focus ring (drawn outside the control, so layouts never shift on focus).
static func focus_ring(cut: int = T.CUT) -> StyleBoxFlat:
	var sb: StyleBoxFlat = box(Color(0, 0, 0, 0), T.CYAN, 2, cut + 2, Vector2.ZERO)
	sb.draw_center = false
	sb.expand_margin_left = 4
	sb.expand_margin_right = 4
	sb.expand_margin_top = 4
	sb.expand_margin_bottom = 4
	return sb


# --- Sections -------------------------------------------------------------------------------------

static func _labels(th: Theme) -> void:
	th.set_color(&"font_color", &"Label", T.PAPER)
	th.set_color(&"font_shadow_color", &"Label", Color(0, 0, 0, 0))
	_label(th, &"HeaderLabel", T.PAPER, T.FONT_H1, T.font_heading())
	_label(th, &"SubheaderLabel", T.PAPER, T.FONT_H2, T.font_heading())
	_label(th, &"DimLabel", T.PAPER_DIM, T.FONT_SMALL)
	_label(th, &"CaptionLabel", T.PAPER_DIM, T.FONT_CAPTION, T.font_caps())
	_label(th, &"DisplayLabel", T.PAPER, T.FONT_DISPLAY, T.font_display())
	_label(th, &"MoneyLabel", T.BRASS_HI, T.FONT_H2, T.font_heading())
	_label(th, &"HudLabel", T.PAPER, T.FONT_HUD)
	th.set_color(&"font_outline_color", &"HudLabel", Color(T.INK_0, 1.0))
	th.set_constant(&"outline_size", &"HudLabel", 6)
	_label(th, &"HudBigLabel", T.PAPER, T.FONT_HUD_BIG, T.font_heading())
	th.set_color(&"font_outline_color", &"HudBigLabel", Color(T.INK_0, 1.0))
	th.set_constant(&"outline_size", &"HudBigLabel", 8)
	th.set_color(&"font_color", &"TooltipLabel", T.PAPER)
	th.set_font_size(&"font_size", &"TooltipLabel", T.FONT_SMALL)


static func _label(th: Theme, type: StringName, color: Color, size: int, font: Font = null) -> void:
	th.set_type_variation(type, &"Label")
	th.set_color(&"font_color", type, color)
	th.set_font_size(&"font_size", type, size)
	if font != null:
		th.set_font(&"font", type, font)


static func _buttons(th: Theme) -> void:
	var pad: Vector2 = Vector2(T.S4, T.S2 + 2)
	var normal: StyleBoxFlat = box(T.INK_2, T.LINE, 1, T.CUT_SMALL, pad)
	normal.border_width_bottom = 2
	normal.border_color = T.LINE_STRONG
	var hover: StyleBoxFlat = box(T.INK_3, T.PAPER_DIM, 1, T.CUT_SMALL, pad)
	hover.border_width_bottom = 2
	var pressed: StyleBoxFlat = box(T.INK_3, T.CYAN, 0, T.CUT_SMALL, pad)
	pressed.border_width_left = 4  # toggled / selected: a cyan tab edge, not a colour flood
	var disabled: StyleBoxFlat = box(Color(T.INK_1, 0.9), T.LINE, 1, T.CUT_SMALL, pad)
	for type: StringName in [&"Button", &"OptionButton", &"CheckButton", &"CheckBox", &"MenuButton"]:
		th.set_stylebox(&"normal", type, normal)
		th.set_stylebox(&"hover", type, hover)
		th.set_stylebox(&"pressed", type, pressed)
		th.set_stylebox(&"hover_pressed", type, pressed)
		th.set_stylebox(&"disabled", type, disabled)
		th.set_stylebox(&"focus", type, focus_ring(T.CUT_SMALL))
		th.set_color(&"font_color", type, T.PAPER)
		th.set_color(&"font_hover_color", type, Color.WHITE)
		th.set_color(&"font_focus_color", type, Color.WHITE)
		th.set_color(&"font_pressed_color", type, Color.WHITE)
		th.set_color(&"font_hover_pressed_color", type, Color.WHITE)
		th.set_color(&"font_disabled_color", type, T.PAPER_MUTE)
		th.set_font_size(&"font_size", type, T.FONT_BODY)
	# Primary: the screen's one forward action (Launch, Continue, Take). Brass edge, brass flood on hover.
	th.set_type_variation(&"PrimaryButton", &"Button")
	var p_normal: StyleBoxFlat = box(T.BRASS_INK, T.BRASS, 1, T.CUT_SMALL, pad)
	p_normal.border_width_bottom = 3
	var p_hover: StyleBoxFlat = box(T.BRASS, T.BRASS_HI, 1, T.CUT_SMALL, pad)
	p_hover.border_width_bottom = 3
	th.set_stylebox(&"normal", &"PrimaryButton", p_normal)
	th.set_stylebox(&"hover", &"PrimaryButton", p_hover)
	th.set_stylebox(&"pressed", &"PrimaryButton", p_hover)
	th.set_stylebox(&"hover_pressed", &"PrimaryButton", p_hover)
	th.set_color(&"font_color", &"PrimaryButton", T.BRASS_HI)
	th.set_color(&"font_focus_color", &"PrimaryButton", T.BRASS_HI)
	th.set_color(&"font_hover_color", &"PrimaryButton", T.INK_0)
	th.set_color(&"font_pressed_color", &"PrimaryButton", T.INK_0)
	th.set_color(&"font_hover_pressed_color", &"PrimaryButton", T.INK_0)
	th.set_font(&"font", &"PrimaryButton", T.font_caps())
	# Ghost: tertiary actions (Back, Reset): no fill until hovered.
	th.set_type_variation(&"GhostButton", &"Button")
	var g_normal: StyleBoxFlat = box(Color(0, 0, 0, 0), T.LINE, 1, T.CUT_SMALL, pad)
	th.set_stylebox(&"normal", &"GhostButton", g_normal)
	th.set_color(&"font_color", &"GhostButton", T.PAPER_DIM)
	# Tab: a flat caps label with a cyan underline when selected.
	th.set_type_variation(&"TabButton", &"Button")
	var t_normal: StyleBoxFlat = box(Color(0, 0, 0, 0), T.LINE, 0, 0, Vector2(T.S4, T.S2))
	t_normal.border_width_bottom = 2
	var t_hover: StyleBoxFlat = t_normal.duplicate() as StyleBoxFlat
	t_hover.border_color = T.PAPER_DIM
	var t_on: StyleBoxFlat = t_normal.duplicate() as StyleBoxFlat
	t_on.border_color = T.CYAN
	t_on.border_width_bottom = 3
	th.set_stylebox(&"normal", &"TabButton", t_normal)
	th.set_stylebox(&"hover", &"TabButton", t_hover)
	th.set_stylebox(&"pressed", &"TabButton", t_on)
	th.set_stylebox(&"hover_pressed", &"TabButton", t_on)
	th.set_stylebox(&"focus", &"TabButton", focus_ring(0))
	var t_off: StyleBoxFlat = t_normal.duplicate() as StyleBoxFlat
	t_off.border_color = Color(T.LINE, 0.5)
	th.set_stylebox(&"disabled", &"TabButton", t_off)
	th.set_font(&"font", &"TabButton", T.font_caps())
	th.set_color(&"font_color", &"TabButton", T.PAPER_DIM)
	# MenuItem: the main menu's big caps entries; a cyan bar on the left when focused / hovered.
	th.set_type_variation(&"MenuItemButton", &"Button")
	var m_normal: StyleBoxFlat = box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, Vector2(T.S4, T.S2))
	var m_hover: StyleBoxFlat = box(Color(T.INK_2, 0.8), T.CYAN, 0, 0, Vector2(T.S4, T.S2))
	m_hover.border_width_left = 4
	th.set_stylebox(&"normal", &"MenuItemButton", m_normal)
	th.set_stylebox(&"hover", &"MenuItemButton", m_hover)
	th.set_stylebox(&"pressed", &"MenuItemButton", m_hover)
	th.set_stylebox(&"hover_pressed", &"MenuItemButton", m_hover)
	th.set_stylebox(&"focus", &"MenuItemButton", m_hover)
	th.set_font(&"font", &"MenuItemButton", T.font_caps())
	th.set_font_size(&"font_size", &"MenuItemButton", T.FONT_H2)
	th.set_color(&"font_color", &"MenuItemButton", T.PAPER_DIM)
	th.set_constant(&"h_separation", &"MenuItemButton", T.S3)
	# Station: the hub's big cards.
	th.set_type_variation(&"StationButton", &"Button")
	var st: StyleBoxFlat = box(T.INK_1, T.LINE, 1, T.CUT, Vector2(T.S4, T.S3))
	st.border_width_left = 3
	var st_hover: StyleBoxFlat = box(T.INK_2, T.BRASS, 1, T.CUT, Vector2(T.S4, T.S3))
	st_hover.border_width_left = 3
	th.set_stylebox(&"normal", &"StationButton", st)
	th.set_stylebox(&"hover", &"StationButton", st_hover)
	th.set_stylebox(&"pressed", &"StationButton", st_hover)
	th.set_stylebox(&"hover_pressed", &"StationButton", st_hover)
	th.set_stylebox(&"disabled", &"StationButton", st)
	th.set_stylebox(&"focus", &"StationButton", focus_ring(T.CUT))
	# Popups (OptionButton lists).
	th.set_stylebox(&"panel", &"PopupMenu", box(T.INK_2, T.LINE_STRONG, 1, 0, Vector2(T.S1, T.S1)))
	var ph: StyleBoxFlat = box(T.INK_3, T.CYAN, 0, 0, Vector2(T.S2, T.S1))
	ph.border_width_left = 3
	th.set_stylebox(&"hover", &"PopupMenu", ph)
	th.set_color(&"font_color", &"PopupMenu", T.PAPER)
	th.set_color(&"font_hover_color", &"PopupMenu", Color.WHITE)
	th.set_color(&"font_disabled_color", &"PopupMenu", T.PAPER_MUTE)
	th.set_font_size(&"font_size", &"PopupMenu", T.FONT_BODY)


static func _panels(th: Theme) -> void:
	th.set_stylebox(&"panel", &"PanelContainer", box(Color(T.INK_1, 0.97), T.LINE, 1, T.CUT, Vector2(T.S4, T.S4 - 4)))
	th.set_stylebox(&"panel", &"Panel", box(Color(T.INK_1, 0.97), T.LINE, 1, T.CUT, Vector2.ZERO))
	th.set_type_variation(&"CardPanel", &"PanelContainer")
	th.set_stylebox(&"panel", &"CardPanel", box(T.INK_2, T.LINE, 1, T.CUT, Vector2(T.S3, T.S3)))
	th.set_type_variation(&"HudPanel", &"PanelContainer")
	var hud: StyleBoxFlat = box(Color(T.INK_0, T.HUD_PANEL_ALPHA), Color(0, 0, 0, 0), 0, T.CUT_SMALL, Vector2(T.S3, T.S2 + 2))
	th.set_stylebox(&"panel", &"HudPanel", hud)
	th.set_type_variation(&"BannerPanel", &"PanelContainer")
	var banner: StyleBoxFlat = box(Color(T.ALERT_INK, 0.9), T.ALERT, 0, T.CUT_SMALL, Vector2(T.S5, T.S2))
	banner.border_width_top = 2
	banner.border_width_bottom = 2
	th.set_stylebox(&"panel", &"BannerPanel", banner)
	th.set_type_variation(&"AlertPanel", &"PanelContainer")
	var alert: StyleBoxFlat = box(Color(T.ALERT_INK, 0.92), T.ALERT, 0, T.CUT_SMALL, Vector2(T.S3, T.S2))
	alert.border_width_left = 4
	th.set_stylebox(&"panel", &"AlertPanel", alert)
	th.set_type_variation(&"ScrimPanel", &"PanelContainer")
	th.set_stylebox(&"panel", &"ScrimPanel", box(T.SCRIM, Color(0, 0, 0, 0), 0, 0, Vector2.ZERO))
	# KeyCap: the key / button glyph in prompts ("[F] Pick the lock").
	th.set_type_variation(&"KeyCap", &"PanelContainer")
	var cap: StyleBoxFlat = box(Color(T.INK_0, 0.85), T.PAPER, 2, 4, Vector2(T.S2 + 2, 0))
	cap.border_width_bottom = 3
	th.set_stylebox(&"panel", &"KeyCap", cap)
	th.set_stylebox(&"panel", &"TooltipPanel", box(T.INK_2, T.LINE_STRONG, 1, 0, Vector2(T.S2 + 2, T.S1 + 2)))
	var sep: StyleBoxLine = StyleBoxLine.new()
	sep.color = T.LINE
	sep.thickness = 1
	th.set_stylebox(&"separator", &"HSeparator", sep)
	var vsep: StyleBoxLine = sep.duplicate() as StyleBoxLine
	vsep.vertical = true
	th.set_stylebox(&"separator", &"VSeparator", vsep)
	th.set_stylebox(&"panel", &"ScrollContainer", StyleBoxEmpty.new())
	var track: StyleBoxFlat = box(Color(T.INK_0, 0.6), Color(0, 0, 0, 0), 0, 0, Vector2(2, 2))
	var grab: StyleBoxFlat = box(T.LINE_STRONG, Color(0, 0, 0, 0), 0, 0, Vector2.ZERO)
	var grab_hl: StyleBoxFlat = box(T.PAPER_DIM, Color(0, 0, 0, 0), 0, 0, Vector2.ZERO)
	for type: StringName in [&"VScrollBar", &"HScrollBar"]:
		th.set_stylebox(&"scroll", type, track)
		th.set_stylebox(&"grabber", type, grab)
		th.set_stylebox(&"grabber_highlight", type, grab_hl)
		th.set_stylebox(&"grabber_pressed", type, grab_hl)
	th.set_stylebox(&"panel", &"ItemList", box(T.INK_1, T.LINE, 1, 0, Vector2(T.S1, T.S1)))
	var sel: StyleBoxFlat = box(T.INK_3, T.CYAN, 0, 0, Vector2(T.S2, T.S1))
	sel.border_width_left = 3
	th.set_stylebox(&"selected", &"ItemList", sel)
	th.set_stylebox(&"selected_focus", &"ItemList", sel)
	th.set_stylebox(&"focus", &"ItemList", focus_ring(0))
	th.set_color(&"font_color", &"ItemList", T.PAPER)
	th.set_color(&"font_selected_color", &"ItemList", Color.WHITE)


static func _fields(th: Theme) -> void:
	var f: StyleBoxFlat = box(T.INK_0, T.LINE_STRONG, 1, 0, Vector2(T.S3, T.S2))
	var ff: StyleBoxFlat = f.duplicate() as StyleBoxFlat
	ff.border_color = T.CYAN
	th.set_stylebox(&"normal", &"LineEdit", f)
	th.set_stylebox(&"focus", &"LineEdit", ff)
	th.set_stylebox(&"read_only", &"LineEdit", f)
	th.set_color(&"font_color", &"LineEdit", T.PAPER)
	th.set_color(&"font_placeholder_color", &"LineEdit", T.PAPER_MUTE)
	th.set_color(&"caret_color", &"LineEdit", T.CYAN)
	th.set_color(&"selection_color", &"LineEdit", Color(T.CYAN, 0.3))
	var rail: StyleBoxFlat = box(T.LINE, Color(0, 0, 0, 0), 0, 0, Vector2(0, 2))
	var fill: StyleBoxFlat = box(T.PAPER_DIM, Color(0, 0, 0, 0), 0, 0, Vector2(0, 2))
	var fill_hl: StyleBoxFlat = box(T.CYAN, Color(0, 0, 0, 0), 0, 0, Vector2(0, 2))
	th.set_stylebox(&"slider", &"HSlider", rail)
	th.set_stylebox(&"grabber_area", &"HSlider", fill)
	th.set_stylebox(&"grabber_area_highlight", &"HSlider", fill_hl)
	th.set_stylebox(&"focus", &"HSlider", focus_ring(0))


static func _bars(th: Theme) -> void:
	th.set_stylebox(&"background", &"ProgressBar", box(Color(T.INK_0, 0.85), Color(0, 0, 0, 0), 0, 0, Vector2.ZERO))
	th.set_stylebox(&"fill", &"ProgressBar", box(T.PAPER, Color(0, 0, 0, 0), 0, 0, Vector2.ZERO))
	th.set_font_size(&"font_size", &"ProgressBar", T.FONT_SMALL)


static func _screen(th: Theme) -> void:
	th.set_color(&"background", &"Screen", T.INK_0)
	th.set_color(&"accent", &"Screen", T.BRASS)
	th.set_color(&"highlight", &"Screen", T.CYAN)
	th.set_color(&"alert", &"Screen", T.ALERT)
	th.set_color(&"ok", &"Screen", T.OK)
	th.set_color(&"line", &"Screen", T.LINE)
