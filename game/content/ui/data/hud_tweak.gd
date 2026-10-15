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
## Stamina bar (ui_hud v1.4, B4-19): normal fill, and the tint while `exhausted`.
@export var stamina_color: Color = Color(0.95, 0.9, 0.55)
@export var stamina_exhausted_color: Color = Color(1.0, 0.45, 0.25)
@export var delta_better_color: Color = Color(0.35, 0.9, 0.4)
@export var delta_worse_color: Color = Color(1.0, 0.35, 0.3)
## Marked targets (S2.9 marks; the outline shader comes later): diamond above each marked unit.
@export var mark_color: Color = Color(1.0, 0.85, 0.25)
## B5-01 palette colours (HudPalette.apply_to overrides them with the active accessibility palette):
## teammate names (ally marker), active objective rows, carried loot, interaction hold bar.
@export var ally_color: Color = Color(0.36, 0.84, 1.0)
@export var objective_color: Color = Color(0.88, 0.72, 0.29)
@export var loot_color: Color = Color(0.4, 0.88, 0.4)
@export var interaction_color: Color = Color(1.0, 1.0, 1.0)
@export var mark_size_px: float = 14.0
## Height above the marked unit's world_pos (its feet) where the marker is drawn, m.
@export var mark_height_m: float = 2.1
## PO6-20: the pager waypoint sits this far above the guard's origin (EventBus fallback; model rows carry world_pos).
@export var pager_marker_height_m: float = 1.2
## PO6-03 device timer panels (DeviceTimers): hidden past this distance (m); full size up to device_panel_ref_m,
## shrinking with distance down to device_panel_min_scale; the panel floats device_panel_up_m above and
## device_panel_out_m out from a device found by net id (EventBus fallback; the model's rows carry world_pos).
@export var device_panel_max_m: float = 30.0
@export var device_panel_ref_m: float = 4.0
@export var device_panel_min_scale: float = 0.55
@export var device_panel_up_m: float = 0.45
@export var device_panel_out_m: float = 0.25
@export var device_jam_color: Color = Color(0.9, 0.28, 0.3)
## Occlusion ray (camera -> panel) on these physics layers, every device_occlusion_check_s; a hit within
## device_occlusion_slack_m of the panel point is the device itself. Mask 0 = never hidden by walls.
@export_flags_3d_physics var device_occlusion_mask: int = 1
@export var device_occlusion_check_s: float = 0.2
@export var device_occlusion_slack_m: float = 0.6


static func load_default() -> HudTweak:
	var tw: HudTweak = null
	if ResourceLoader.exists(DEFAULT_PATH):
		tw = load(DEFAULT_PATH) as HudTweak
	return tw if tw != null else HudTweak.new()
