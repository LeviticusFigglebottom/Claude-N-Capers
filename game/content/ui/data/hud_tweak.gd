## HUD presentation tuning (data: res://content/data/ui/hud_tweak.tres). Owner: ENV B.
## pd2_fidelity S2.1: blue below 0.5, orange from 0.5, red "!" at 1.0.
class_name HudTweak
extends Resource

const DEFAULT_PATH: String = "res://content/data/ui/hud_tweak.tres"

@export var detection_orange_from: float = 0.5
@export var detection_red_at: float = 1.0
@export var detection_blue: Color = Color(0.35, 0.65, 1.0)
@export var detection_orange: Color = Color(1.0, 0.6, 0.15)
@export var detection_red: Color = Color(1.0, 0.2, 0.2)
## Chevron ring radius and size in px at the 1920x1080 base resolution (canvas_items stretch scales).
@export var chevron_radius_px: float = 96.0
@export var chevron_size_px: float = 22.0
## Chevrons below this value are not drawn (meter just started / decayed).
@export var detection_min_visible: float = 0.01
@export var health_color: Color = Color(0.85, 0.95, 0.85)
@export var armor_color: Color = Color(0.6, 0.8, 1.0)
@export var low_health_frac: float = 0.25
@export var low_health_color: Color = Color(1.0, 0.3, 0.3)
@export var pager_color: Color = Color(1.0, 0.75, 0.2)
@export var assault_color: Color = Color(1.0, 0.25, 0.2)
## Captain widget (ui_hud v1.3): Commander Brandt's name and Aegis resistance bar.
@export var captain_color: Color = Color(0.95, 0.55, 0.95)
@export var delta_better_color: Color = Color(0.35, 0.9, 0.4)
@export var delta_worse_color: Color = Color(1.0, 0.35, 0.3)
## Marked targets (S2.9 marks; the outline shader comes later): diamond above each marked unit.
@export var mark_color: Color = Color(1.0, 0.85, 0.25)
@export var mark_size_px: float = 14.0
## Height above the marked unit's world_pos (its feet) where the marker is drawn, m.
@export var mark_height_m: float = 2.1


static func load_default() -> HudTweak:
	var tw: HudTweak = null
	if ResourceLoader.exists(DEFAULT_PATH):
		tw = load(DEFAULT_PATH) as HudTweak
	return tw if tw != null else HudTweak.new()
