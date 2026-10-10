## Per-heist UI accents (docs/art/style_guide.md §3 "Accent" column; B4-07) and WCAG contrast
## helpers. Owner: ENV B. Data: res://content/data/ui/heist_accents.tres (UiHeistAccents).
##
## Screens call `UiAccent.for_heist(id)` for graphic accents (strips, card edges) and
## `UiAccent.text_color(id)` for accent-coloured TEXT: the accent pulled toward white until it reaches
## the table's `min_text_contrast` (4.5:1) against the theme's panel colour, so a dark accent such as
## Night Deposit's bank red stays readable.
class_name UiAccent
extends RefCounted

static var _table: UiHeistAccents = null


static func table() -> UiHeistAccents:
	if _table == null:
		_table = UiHeistAccents.load_default()
		if _table == null:
			_table = UiHeistAccents.new()
	return _table


## The heist's accent colour; the table's fallback (house brass) for unknown ids.
static func for_heist(heist_id: StringName) -> Color:
	var t: UiHeistAccents = table()
	return t.accents.get(heist_id, t.fallback) as Color


## The heist's accent made readable as text on `bg` (default: the theme's panel colour).
static func text_color(heist_id: StringName, bg: Color = Color(0, 0, 0, 0)) -> Color:
	var back: Color = bg if bg.a > 0.0 else panel_bg()
	return readable(for_heist(heist_id), back, table().min_text_contrast)


## `c` moved toward white (dark `bg`) or black (light `bg`) in small steps until its contrast with
## `bg` is at least `min_ratio`. Returns `c` unchanged when it already passes.
static func readable(c: Color, bg: Color, min_ratio: float) -> Color:
	var target: Color = Color(1, 1, 1, 1) if relative_luminance(bg) < 0.18 else Color(0, 0, 0, 1)
	var out: Color = Color(c, 1.0)
	for i: int in range(21):
		out = Color(c, 1.0).lerp(target, float(i) * 0.05)
		if contrast_ratio(out, bg) >= min_ratio:
			return out
	return out


## WCAG 2.x relative luminance of an sRGB colour (alpha ignored).
static func relative_luminance(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


## WCAG contrast ratio (1..21) between two opaque colours.
static func contrast_ratio(a: Color, b: Color) -> float:
	var la: float = relative_luminance(a)
	var lb: float = relative_luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## `fg` alpha-composited over an opaque `bg`.
static func over(fg: Color, bg: Color) -> Color:
	return Color(bg.lerp(fg, fg.a), 1.0)


## The theme's app background (Screen/colors/background).
static func app_bg() -> Color:
	var th: Theme = UiBuild.theme()
	return th.get_color(&"background", &"Screen") if th.has_color(&"background", &"Screen") else Color(0.07, 0.06, 0.05)


## The theme's PanelContainer colour composited over the app background (what text sits on).
static func panel_bg() -> Color:
	var sb: StyleBoxFlat = UiBuild.theme().get_stylebox(&"panel", &"PanelContainer") as StyleBoxFlat
	return over(sb.bg_color, app_bg()) if sb != null else app_bg()


## A thin vertical accent strip (place it beside a header).
static func strip(color: Color, width: float = 6.0) -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(width, 0)
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Gives `panel` an accent edge: its theme stylebox duplicated with a `width` px left border and a
## thin outline in `color` (a heist card).
static func accent_panel(panel: PanelContainer, color: Color, width: int = 5) -> void:
	var base: StyleBox = panel.get_theme_stylebox(&"panel")
	if base == null:
		base = UiBuild.theme().get_stylebox(&"panel", &"PanelContainer")
	var sb: StyleBoxFlat = (base as StyleBoxFlat).duplicate() as StyleBoxFlat if base is StyleBoxFlat else StyleBoxFlat.new()
	sb.border_color = Color(color, 0.85)
	sb.border_width_left = width
	sb.border_width_top = maxi(sb.border_width_top, 1)
	sb.border_width_right = maxi(sb.border_width_right, 1)
	sb.border_width_bottom = maxi(sb.border_width_bottom, 1)
	panel.add_theme_stylebox_override(&"panel", sb)


static func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
