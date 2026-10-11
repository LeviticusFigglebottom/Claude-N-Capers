## One accessibility colour palette for the HUD (B5-01). Owner: ENV B. Entries live in
## res://content/data/ui/hud_palettes.tres (HudPaletteSet); ids are the `accessibility/palette`
## setting's options: default, deuteranopia, protanopia, tritanopia, high_contrast.
## Schema: content/docs/options.md. Paired states stay apart under simulated colour-vision deficiency
## (test_options_palettes.gd, Machado 2009 + CIE76).
class_name HudPalette
extends Resource

## Colour fields in schema order (tests and docs iterate them).
const FIELDS: Array[StringName] = [
	&"detection_suspicious", &"detection_alert", &"detection_detected",
	&"health", &"armor", &"low_health",
	&"ally_marker", &"enemy_marker",
	&"objective", &"loot_highlight", &"interaction_highlight",
]

@export var id: StringName = &"default"
@export var name_key: StringName = &""
## Detection meter: below HudTweak.detection_orange_from, from it, and at 1.0 (detected).
@export var detection_suspicious: Color = Color(0.35, 0.65, 1.0)
@export var detection_alert: Color = Color(1.0, 0.6, 0.15)
@export var detection_detected: Color = Color(1.0, 0.2, 0.2)
@export var health: Color = Color(0.85, 0.95, 0.85)
@export var armor: Color = Color(0.6, 0.8, 1.0)
## Low-health bar tint and warning text (state / blocked labels): body-text contrast.
@export var low_health: Color = Color(1.0, 0.3, 0.3)
@export var ally_marker: Color = Color(0.36, 0.84, 1.0)
@export var enemy_marker: Color = Color(1.0, 0.85, 0.25)
@export var objective: Color = Color(0.88, 0.72, 0.29)
@export var loot_highlight: Color = Color(0.4, 0.88, 0.4)
@export var interaction_highlight: Color = Color(1.0, 1.0, 1.0)


## A copy of `base` with this palette's colours (base stays untouched).
func apply_to(base: HudTweak) -> HudTweak:
	var t: HudTweak = (base if base != null else HudTweak.new()).duplicate() as HudTweak
	t.detection_blue = detection_suspicious
	t.detection_orange = detection_alert
	t.detection_red = detection_detected
	t.health_color = health
	t.armor_color = armor
	t.low_health_color = low_health
	t.ally_color = ally_marker
	t.mark_color = enemy_marker
	t.objective_color = objective
	t.loot_color = loot_highlight
	t.interaction_color = interaction_highlight
	return t


func color(field: StringName) -> Color:
	return get(field) as Color
