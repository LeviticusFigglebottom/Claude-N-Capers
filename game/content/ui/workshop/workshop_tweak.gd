## Workshop presentation tuning (B4-17, pd2_fidelity P6). Owner: ENV B.
## Data: res://content/data/ui/workshop_tweak.tres. Camera, studio lights, backdrop and gizmo of the
## WorkshopStage; no balance numbers (prices live on WeaponDef / WeaponModDef).
class_name WorkshopTweak
extends Resource

const DEFAULT_PATH: String = "res://content/data/ui/workshop_tweak.tres"

@export_group("Camera")
@export var fov_deg: float = 30.0
## Overview framing: camera distance = bounding radius / sin(fov / 2) x this.
@export var frame_margin: float = 0.7
## Overview start angle (degrees). Yaw 0 looks at the weapon's right side (+X); positive pitch looks down.
@export var start_yaw_deg: float = -28.0
@export var start_pitch_deg: float = 12.0
@export var pitch_limit_deg: float = 70.0
## Zoom limits as a multiple of the overview distance.
@export var zoom_min_mult: float = 0.18
@export var zoom_max_mult: float = 1.8
## Each wheel notch / key press multiplies the distance by this (or its inverse).
@export var zoom_step_mult: float = 1.12
## Gamepad triggers: zoom speed (distance multiplier per second at full pull).
@export var zoom_trigger_rate: float = 1.8
@export var drag_deg_per_px: float = 0.35
## Mouse pan: meters per pixel at 1 m camera distance.
@export var pan_m_per_px: float = 0.0016
@export var stick_deg_s: float = 120.0
## Gamepad / keyboard pan: fraction of the camera distance per second.
@export var pan_rate: float = 0.6
@export var key_deg_s: float = 90.0
@export var stick_deadzone: float = 0.2
## Pan never moves the orbit target farther than this many bounding radii from the weapon centre.
@export var pan_limit_radii: float = 1.2
## Seconds without input before the overview turntable spin resumes.
@export var idle_spin_after_s: float = 3.0
@export var idle_spin_deg_s: float = 10.0
## Camera follow sharpness (1/s): higher snaps faster to the goal.
@export var follow_rate: float = 9.0

@export_group("Slot focus")
## Focus distance = overview distance x this, never below `focus_min_distance_m` and never above the
## overview distance x `focus_max_overview_frac` (small pistols still zoom in).
@export var focus_distance_mult: float = 0.55
@export var focus_min_distance_m: float = 0.3
@export var focus_max_overview_frac: float = 0.85
## Focus view angles (degrees): pitch for parts above / below the weapon centre (added to start_pitch),
## extra yaw toward the stock for rear parts, and the yaw used for parts on the left (-X) side.
@export var focus_pitch_above_deg: float = 18.0
@export var focus_pitch_below_deg: float = -4.0
@export var focus_rear_yaw_deg: float = 20.0
@export var focus_left_yaw_deg: float = -155.0
## Gizmo (attach-marker preview): ring radius and axis length, as a fraction of the focus distance.
@export var gizmo_ring_frac: float = 0.05
@export var gizmo_axis_frac: float = 0.07
@export var gizmo_color: Color = Color(0.31, 0.82, 0.91, 1.0)

@export_group("Studio")
## Gradient backdrop (procedural sky): top, horizon and floor colours, and its brightness.
@export var backdrop_top: Color = Color(0.36, 0.35, 0.33, 1.0)
@export var backdrop_horizon: Color = Color(0.2, 0.195, 0.185, 1.0)
@export var backdrop_floor: Color = Color(0.07, 0.068, 0.064, 1.0)
@export var backdrop_energy: float = 1.0
@export var ambient_energy: float = 0.6
## Key / fill / rim light: colour, energy and direction (elevation above the horizon, azimuth from the
## camera's side; 180 = from behind the weapon), in degrees. The lights turn with the camera, so the
## studio look stays the same from every angle (a turntable under fixed lights).
@export var key_color: Color = Color(1.0, 0.95, 0.88, 1.0)
@export var key_energy: float = 2.8
@export var key_angles_deg: Vector2 = Vector2(40.0, 40.0)
@export var fill_color: Color = Color(0.78, 0.84, 1.0, 1.0)
@export var fill_energy: float = 1.0
@export var fill_angles_deg: Vector2 = Vector2(12.0, -60.0)
@export var rim_color: Color = Color(0.92, 0.95, 1.0, 1.0)
@export var rim_energy: float = 2.6
@export var rim_angles_deg: Vector2 = Vector2(30.0, 160.0)
## Turntable disc under the weapon: colour, roughness, radius as a multiple of the bounding radius,
## and its gap below the weapon (m).
@export var turntable_color: Color = Color(0.045, 0.043, 0.041, 1.0)
@export var turntable_roughness: float = 0.9
@export var turntable_radius_mult: float = 0.8
@export var turntable_gap_m: float = 0.035


static func load_default() -> WorkshopTweak:
	var t: WorkshopTweak = load(DEFAULT_PATH) as WorkshopTweak
	return t if t != null else WorkshopTweak.new()
