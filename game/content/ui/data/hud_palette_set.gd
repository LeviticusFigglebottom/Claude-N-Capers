## Every HUD accessibility palette (data: res://content/data/ui/hud_palettes.tres). Owner: ENV B.
## `active()` = the palette of GameSettings.current()'s `accessibility/palette`; `active_tweak()` =
## HudTweak.load_default() recoloured by it (what the HUD widgets read).
class_name HudPaletteSet
extends Resource

const DEFAULT_PATH: String = "res://content/data/ui/hud_palettes.tres"
const DEFAULT_ID: StringName = &"default"

static var _cached: HudPaletteSet = null

@export var palettes: Array[HudPalette] = []


static func load_default() -> HudPaletteSet:
	if _cached == null:
		if ResourceLoader.exists(DEFAULT_PATH):
			_cached = load(DEFAULT_PATH) as HudPaletteSet
		if _cached == null:
			Log.error(&"ui", "missing %s" % DEFAULT_PATH)
			_cached = HudPaletteSet.new()
	return _cached


## The palette `palette_id` (the default one, or a built-in default, when unknown).
func find(palette_id: StringName) -> HudPalette:
	var fallback: HudPalette = null
	for p: HudPalette in palettes:
		if p.id == palette_id:
			return p
		if p.id == DEFAULT_ID:
			fallback = p
	return fallback if fallback != null else HudPalette.new()


func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for p: HudPalette in palettes:
		out.append(p.id)
	return out


## The palette selected in `s` (default GameSettings.current()).
static func active(s: GameSettings = null) -> HudPalette:
	var gs: GameSettings = s if s != null else GameSettings.current()
	return load_default().find(StringName(gs.get_value(GameSettings.ACCESSIBILITY, &"palette")))


## HudTweak.load_default() recoloured by the active palette.
static func active_tweak(s: GameSettings = null) -> HudTweak:
	return active(s).apply_to(HudTweak.load_default())
