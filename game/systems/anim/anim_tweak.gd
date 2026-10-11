## Third-person animation tunables for AnimDriver (characters.md v1.3, D-041). Owner: ENV A.
## Data: anim_tweak.tres. Presentation only: nothing here changes gameplay timing or movement.
## Clip speeds / event frames are ENV D's facts (char_anim_humanoid/SOURCE.txt); the rest are ◇
## presentation values.
class_name AnimTweak
extends Resource

const PATH: String = "res://systems/anim/anim_tweak.tres"

static var _cached: AnimTweak = null

@export_group("Clip facts (characters.md v1.3 / v1.4)")
## Root speed of each locomotion clip at 1.78 m (m/s). speed_scale = v / (clip speed x motion_scale).
@export var clip_speeds: Dictionary = {
	&"walk": 1.6, &"run": 3.5, &"sprint": 5.75, &"crouch_walk": 1.5, &"strafe_l": 1.2, &"strafe_r": 1.2,
	&"walk_back": 1.3, &"flee": 4.0, &"carry_bag_walk": 2.4, &"shield_walk": 1.6, &"dozer_walk": 1.6,
	&"mug_carry_walk": 1.3,
}
## Seconds from clip start to the reload `done` event (SOURCE.txt: pistol done@34, rifle done@58, 30 fps).
## The reload clip is sped up/slowed so `done` lands when the gameplay reload finishes.
@export var reload_done_s: Dictionary = {&"pistol": 1.1333, &"rifle": 1.9333}
## Turn-in-place clip: the root yaws this many degrees over `turn_time_s`.
@export var turn_clip_deg: float = 90.0
@export var turn_time_s: float = 0.8

@export_group("Selection")
## Horizontal speed (m/s) under which a body counts as standing.
@export var move_threshold_mps: float = 0.2
## Above this speed (and below the run/sprint midpoint) walk becomes run; midpoints by default.
@export var walk_run_split_mps: float = 2.55
@export var run_sprint_split_mps: float = 4.6
## Strafe / walk-back pick (dot of the move direction with the body's right / forward axis).
@export var strafe_side_dot: float = 0.7
@export var walk_back_dot: float = -0.5
## Strafe and walk_back only below this speed (faster sideways motion plays run).
@export var strafe_max_mps: float = 2.2
## speed_scale clamp for locomotion clips.
@export var speed_scale_min: float = 0.4
@export var speed_scale_max: float = 2.0
## Idle yaw change (degrees) that plays turn_l / turn_r instead of sliding the feet.
@export var turn_threshold_deg: float = 60.0
## Interaction clip by the interactable's height above the feet (m): low below, high above.
@export var interact_low_max_m: float = 0.7
@export var interact_high_min_m: float = 1.5
## dot(hit direction, facing) above this = shot from behind = death_front (falls face down).
@export var death_front_dot: float = 0.0
## Aim pose for NPCs whose weapon has no WeaponDef, by role (&"pistol" / &"rifle"); default pistol.
@export var npc_weapon_anim_by_role: Dictionary = {&"police": &"rifle", &"special": &"rifle"}
## Seconds a standing crew member keeps the aim pose after its last shot.
@export var aim_hold_s: float = 1.5
## Position-delta speeds above this (m/s) are teleports, not motion.
@export var teleport_speed_mps: float = 15.0

@export_group("Blending")
@export var blend_s: float = 0.2
@export var oneshot_blend_s: float = 0.08
@export var death_blend_s: float = 0.1
## Exponential smoothing rate (1/s) of the velocity estimate from position deltas (clients).
@export var velocity_smoothing: float = 12.0


static func data() -> AnimTweak:
	if _cached == null:
		_cached = load(PATH) as AnimTweak
		if _cached == null:
			_cached = AnimTweak.new()
	return _cached
