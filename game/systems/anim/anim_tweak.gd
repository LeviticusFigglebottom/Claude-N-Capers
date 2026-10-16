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
	&"mug_carry_walk": 1.3, &"walk_text": 1.2, &"run_l": 3.5, &"run_r": 3.5, &"run_b": 3.5,
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
## Strafe and walk_back below this speed; above it (up to run_sprint_split_mps) run_l / run_r / run_b.
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
## v1.10: a death hit this far to the side (|dir . right|) plays death_side.
@export var death_side_dot: float = 0.8
## PO6-18 / D-114 §7: death clip by the pose the body held when it died (never stand a body up). A pose
## missing here dies with the hit-direction set; a mapped clip the rig lacks holds the pose's current
## frame instead (the body dies in place).
@export var death_by_pose: Dictionary = {
	&"kneel_cuffed": &"death_kneel_cuffed", &"tied": &"death_kneel_cuffed", &"surrender": &"death_kneel",
	&"cower": &"death_crouch", &"crouch_idle": &"death_crouch", &"crouch_walk": &"death_crouch",
	&"lie_down": &"death_prone", &"downed": &"death_downed", &"downed_crawl": &"death_downed",
}
## v1.10: two hit reacts on one body at least this far apart (s); in between the current one plays on.
@export var hit_react_min_gap_s: float = 0.35
## Aim pose for NPCs whose weapon has no WeaponDef, by role (&"pistol" / &"rifle"); default pistol.
@export var npc_weapon_anim_by_role: Dictionary = {&"police": &"rifle", &"special": &"rifle"}
## Seconds a standing crew member keeps the aim pose after its last shot.
@export var aim_hold_s: float = 1.5
## Position-delta speeds above this (m/s) are teleports, not motion.
@export var teleport_speed_mps: float = 15.0

@export_group("Shield carry")
## While the body carries a raised BulwarkShield (guard up, not dropped), these clips play the shield set
## instead (characters.md: shield_idle* blends with shield_walk frame 0; the left hand stays on the grip,
## so BulwarkShield's Visual follows HandL/Socket). Value = clip family: every library clip named
## `<family>`, `<family>_*` or `<family><digit>*` is a variant (one per body, by net id). A family the rig
## lacks keeps the original clip. Runs stay runs (lead ruling: no sped-up walk); death, stun, poses,
## hit_react and melee are never remapped; shield_bang comes from the brain's anim_hint.
@export var shield_clips: Dictionary = {
	&"idle": &"shield_idle", &"idle_alert": &"shield_idle", &"aim_pistol": &"shield_idle",
	&"aim_rifle": &"shield_idle", &"fire_pistol": &"shield_idle", &"fire_rifle": &"shield_idle",
	&"turn_l": &"shield_idle", &"turn_r": &"shield_idle", &"investigate_look": &"shield_idle",
	&"walk": &"shield_walk", &"strafe_l": &"shield_walk", &"strafe_r": &"shield_walk",
	&"walk_back": &"shield_walk",
}

@export_group("Blending")
@export var blend_s: float = 0.2
@export var oneshot_blend_s: float = 0.08
@export var death_blend_s: float = 0.1
## Exponential smoothing rate (1/s) of the velocity estimate from position deltas (clients).
@export var velocity_smoothing: float = 12.0


@export_group("Weapon gadgets (D-118, visual_slots v1.3)")
## Fallbacks when the resolved weapon params lack them (the contract defaults; B owns the real values).
@export var gadget_laser_color: Color = Color(1.0, 0.05, 0.05)
@export var gadget_laser_range_m: float = 50.0
@export var gadget_light_range_m: float = 25.0
@export var gadget_light_angle_deg: float = 30.0
@export var gadget_light_energy: float = 2.0
## Third-person beam thickness (m), hit dot radius (m) and emission multiplier.
@export var gadget_beam_width_m: float = 0.006
@export var gadget_dot_radius_m: float = 0.015
@export var gadget_laser_emission: float = 4.0
## Laser dot pulled this far off the hit surface (m) so it does not z-fight.
@export var gadget_dot_offset_m: float = 0.01

@export_group("Hard-hat hand lift (D-115 R1)")
## Hands-on-head clips during which the hands are lifted over the hat shell.
@export var hard_hat_lift_clips: Array[StringName] = [&"surrender", &"hands_up", &"cower", &"cower_seated",
	&"cower_stand", &"kneel_cuffed"]
## Lift (m) of a hand resting on the head: the shell stands ~2.4 cm off the skull (ENV D audit R1).
@export var hard_hat_hand_lift_m: float = 0.03
## A hand within this distance (m) of the head bone counts as resting on it.
@export var hard_hat_near_head_m: float = 0.32
## Influence blend rate (1/s) in and out of the lift clips.
@export var hard_hat_lift_rate: float = 6.0


static func data() -> AnimTweak:
	if _cached == null:
		_cached = load(PATH) as AnimTweak
		if _cached == null:
			_cached = AnimTweak.new()
	return _cached
