## PO-4 design tokens: the single source of every colour, size, spacing step, font style and motion
## time the UI uses (spec: docs/design/ui/style.md, "Case File"). Owner: ENV B.
## UiThemeFactory turns these into caper_theme.tres; screens and HUD widgets read tokens or theme
## variations, never their own literals. Units are 1920x1080 canvas units (canvas_items stretch), so
## 1 unit = 0.667 px at 1280x720.
class_name UiTokens
extends RefCounted

# --- Colour -------------------------------------------------------------------------------------
## Ink: cool blue-black surfaces, darkest first.
const INK_0: Color = Color("0b0d10")  ## app background
const INK_1: Color = Color("12161b")  ## panel
const INK_2: Color = Color("1a2027")  ## raised: button, field
const INK_3: Color = Color("232b34")  ## hover
const LINE: Color = Color("2c3540")  ## hairline rules, panel edges
const LINE_STRONG: Color = Color("46525f")  ## field edges, idle button bottom edge
## Paper: text.
const PAPER: Color = Color("ece7dd")  ## primary text
const PAPER_DIM: Color = Color("a8a296")  ## secondary text (>= 7:1 on INK_1)
const PAPER_MUTE: Color = Color("6c6961")  ## disabled
## Brass: the house colour. Brand, money, the screen's one primary action.
const BRASS: Color = Color("c9a227")
const BRASS_HI: Color = Color("e6c65c")
const BRASS_INK: Color = Color("2a2310")  ## primary button fill
## Cyan (style_guide.md §3): reserved for "this is what you act on": focus, selection, interact prompts.
const CYAN: Color = Color("4fd1e8")
## Signals.
const ALERT: Color = Color("e5484d")  ## loud, assault, danger, failure
const ALERT_INK: Color = Color("3a1214")
const WARN: Color = Color("f0a13a")  ## warnings, detection orange
const OK: Color = Color("5bc08a")  ## done, success, secured
## HUD panels sit on the world: ink at this alpha.
const HUD_PANEL_ALPHA: float = 0.62
## Full-screen dimmer behind modal screens over the HUD (pause, payday).
const SCRIM: Color = Color(0.043, 0.051, 0.063, 0.82)

# --- Type (canvas units; 21 = 14 px at 720p, the readability floor PQ-B-14) -----------------------
const FONT_CAPTION: int = 21  ## tracked caps labels ("SECONDARY", "OBJECTIVE")
const FONT_SMALL: int = 21
const FONT_BODY: int = 24
const FONT_LEAD: int = 28
const FONT_H2: int = 32
const FONT_H1: int = 48
const FONT_DISPLAY: int = 88  ## title wordmark, payday total
const FONT_HUD: int = 24
const FONT_HUD_BIG: int = 44
## Letter spacing (extra px per glyph) for tracked caps.
const TRACK_CAPS: int = 2
const TRACK_DISPLAY: int = 6

# --- Space (8-unit steps) -------------------------------------------------------------------------
const S1: int = 4
const S2: int = 8
const S3: int = 16
const S4: int = 24
const S5: int = 32
const S6: int = 48
const S7: int = 64
## Screen safe margin (left / right / top / bottom) and column gutter.
const MARGIN: int = 72
const GUTTER: int = 24
## The chamfer: every panel and button cuts its top-left and bottom-right corners by this much.
const CUT: int = 10
const CUT_SMALL: int = 6
## Standard control heights.
const BUTTON_H: int = 52
const FIELD_H: int = 48

# --- Motion (seconds; ease-out cubic in, ease-in quad out) ----------------------------------------
const T_FAST: float = 0.12  ## hover, focus
const T_BASE: float = 0.2  ## panel in / out, toasts
const T_SLOW: float = 0.35  ## screen change
const SLIDE: float = 24.0  ## screen-in slide distance

static var _fonts: Dictionary = {}


## False when the player turned on accessibility/reduce_motion (fades / slides are skipped; state
## changes still happen at once).
static func motion_ok() -> bool:
	return not bool(GameSettings.current().get_value(GameSettings.ACCESSIBILITY, &"reduce_motion"))


## Tracked uppercase caption font (FontVariation over the engine default font, no font files).
static func font_caps() -> FontVariation:
	return _variation(&"caps", 0.35, TRACK_CAPS)


## Heavy, wide-tracked display font (title wordmark, big numbers).
static func font_display() -> FontVariation:
	return _variation(&"display", 0.9, TRACK_DISPLAY)


## Semi-heavy heading font.
static func font_heading() -> FontVariation:
	return _variation(&"heading", 0.45, 1)


## Body font: the engine default with tabular figures so numbers in columns line up.
static func font_body() -> FontVariation:
	return _variation(&"body", 0.0, 0)


static func _variation(id: StringName, embolden: float, spacing: int) -> FontVariation:
	if _fonts.has(id):
		return _fonts[id] as FontVariation
	var f: FontVariation = FontVariation.new()
	f.resource_name = "caper_%s" % id
	f.variation_embolden = embolden
	f.spacing_glyph = spacing
	f.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("tnum"): 1}
	_fonts[id] = f
	return f
