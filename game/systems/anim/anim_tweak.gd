## Third-person animation tunables for AnimDriver (characters.md v1.3, D-041). Owner: ENV A.
## Data: anim_tweak.tres. Presentation only: nothing here changes gameplay timing or movement.
## Clip speeds / event frames are ENV D's facts (char_anim_humanoid/SOURCE.txt); the rest are ◇
## presentation values.
class_name AnimTweak
extends Resource

const PATH: String = "res://systems/anim/anim_tweak.tres"
## ENV D's third-person rig SOURCE.txt: clip event frames (`clip.<name>: ... events=a@F,...`) at SOURCE_FPS.
const CHAR_SOURCE: String = "res://assets/characters/char_anim_humanoid/SOURCE.txt"
const SOURCE_FPS: float = 30.0
## reload_done_s key -> third-person reload clip.
const RELOAD_CLIPS: Dictionary = {
	&"pistol": &"reload_pistol", &"rifle": &"reload_rifle", &"akimbo": &"reload_akimbo",
	&"downed_reload": &"downed_reload",
	# D-116 police_combat class reloads (CombatClips.RELOAD_BY_CLASS).
	&"smg": &"reload_smg", &"shotgun": &"reload_shotgun", &"lmg": &"reload_lmg", &"sniper": &"reload_sniper",
}

static var _cached: AnimTweak = null

@export_group("Clip facts (characters.md v1.3 / v1.4)")
## Root speed of each locomotion clip at 1.78 m (m/s). speed_scale = v / (clip speed x motion_scale).
@export var clip_speeds: Dictionary = {
	&"walk": 1.6, &"run": 3.5, &"sprint": 5.75, &"crouch_walk": 1.5, &"strafe_l": 1.2, &"strafe_r": 1.2,
	&"walk_back": 1.3, &"flee": 4.0, &"flee_b": 4.0, &"flee_c": 4.0, &"carry_bag_walk": 2.4, &"shield_walk": 1.6, &"dozer_walk": 1.6,
	&"mug_carry_walk": 1.3, &"walk_text": 1.2, &"run_l": 3.5, &"run_r": 3.5, &"run_b": 3.5,
}
## Seconds from clip start to the reload `done` event (SOURCE.txt: pistol done@34, rifle done@58, 30 fps).
## The reload clip is sped up/slowed so `done` lands when the gameplay reload finishes.
## v1.21: reload_akimbo done@46, downed_reload done@34. D-116 police_combat: reload_smg done@44, reload_shotgun done@74,
## reload_lmg done@106, reload_sniper done@66.
@export var reload_done_s: Dictionary = {
	&"pistol": 1.1333, &"rifle": 1.9333, &"akimbo": 1.5333, &"downed_reload": 1.1333,
	&"smg": 1.4667, &"shotgun": 2.4667, &"lmg": 3.5333, &"sniper": 2.2,
}
## Turn-in-place clip: the root yaws this many degrees over `turn_time_s`.
@export var turn_clip_deg: float = 90.0
@export var turn_time_s: float = 0.8
## D-116 turn_l_45 / turn_r_45 (ENV D, 12 f, root_turn 45 deg at turn_l's 112.5 deg/s): their own turn (TurnInPlace).
@export var turn_45_clip_deg: float = 45.0
## Yaw change (degrees) from which turn_l / turn_r (90) play; below it (down to turn_threshold_deg) turn_*_45.
@export var turn_90_min_deg: float = 67.5
## Turn clip speed_scale = clip deg / yaw change, clamped to this range (TurnInPlace).
@export var turn_speed_min: float = 0.75
@export var turn_speed_max: float = 1.5
## Below turn_threshold_deg no clip plays: the rig snaps to the body over this many seconds.
@export var turn_snap_s: float = 0.15
## D-116 door_kick_<fam> `impact` (s; SOURCE.txt first): the clip is scaled so it lands on npc_door_breach_s.
@export var door_kick_impact_s: float = 2.5

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
## Idle yaw change (degrees) that plays a turn clip (turn_*_45 / turn_l / turn_r) instead of sliding the feet.
@export var turn_threshold_deg: float = 20.0
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
	&"cower": &"death_crouch", &"cower_b": &"death_crouch", &"crouch_idle": &"death_crouch", &"crouch_walk": &"death_crouch",
	&"lie_down": &"death_prone", &"downed": &"death_downed", &"downed_crawl": &"death_downed",
	# characters.md v1.18 variants: every surrender* / surrender_idle* kneels (death_kneel starts on their chain
	# frame), kneel_cuffed_b/_c share kneel_cuffed's frame 0 (death_kneel_cuffed).
	&"surrender_b": &"death_kneel", &"surrender_c": &"death_kneel", &"surrender_idle": &"death_kneel",
	&"surrender_idle_b": &"death_kneel", &"surrender_idle_c": &"death_kneel",
	&"kneel_cuffed_b": &"death_kneel_cuffed", &"kneel_cuffed_c": &"death_kneel_cuffed",
}
## v1.10: two hit reacts on one body at least this far apart (s); in between the current one plays on.
@export var hit_react_min_gap_s: float = 0.35
## Aim pose for NPCs whose weapon has no WeaponDef, by role (&"pistol" / &"rifle"); default pistol.
@export var npc_weapon_anim_by_role: Dictionary = {&"police": &"rifle", &"special": &"rifle"}
## Seconds a standing crew member keeps the aim pose after its last shot.
@export var aim_hold_s: float = 1.5
## Position-delta speeds above this (m/s) are teleports, not motion.
@export var teleport_speed_mps: float = 15.0

@export_group("Cover poses (D-116 police_combat, CombatClips)")
## ◇ On the brain's cover post when the body stands within this flat distance of it (m; PoliceTweak.arrive_m 0.8).
@export var cover_post_m: float = 0.9
## ◇ Re-classify the post (low / corner side) this often while on it (s).
@export var cover_probe_interval_s: float = 0.5
## ◇ Probe heights above the feet at 1.78 m (m, x motion_scale): below a counter / table top, and at the chest.
@export var cover_probe_low_m: float = 0.6
@export var cover_probe_high_m: float = 1.4
## ◇ Probe lengths (m): the low-cover ray ahead, and the corner rays to each side / front diagonal.
@export var cover_probe_front_m: float = 1.2
@export var cover_probe_side_m: float = 0.9

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
	&"turn_l": &"shield_idle", &"turn_r": &"shield_idle", &"turn_l_45": &"shield_idle", &"turn_r_45": &"shield_idle",
	&"investigate_look": &"shield_idle", &"door_kick_rifle": &"shield_bang", &"door_kick_pistol": &"shield_bang",
	&"walk": &"shield_walk", &"strafe_l": &"shield_walk", &"strafe_r": &"shield_walk",
	&"walk_back": &"shield_walk",
}

@export_group("Blending")
@export var blend_s: float = 0.2
@export var oneshot_blend_s: float = 0.08
@export var death_blend_s: float = 0.1
## characters.md v1.18 hit-zone flinches (SOURCE hit_zones: fade in 0.03 s, out 0.12 s).
@export var hit_zone_blend_in_s: float = 0.03
@export var hit_zone_blend_out_s: float = 0.12
## characters.md v1.19 (SOURCE weapon_holds): the crew upper-body hold layer blends in / out over this (s).
@export var hold_layer_blend_s: float = 0.2
## characters.md v1.22 (D c885e144): Back/Socket is the carried bag's pivot, so an identity attach seats a MEDIUM bag;
## the other sizes shift along the socket's local Y by Enums.LootWeight (VERY_HEAVY rides like HEAVY).
@export var carried_bag_offset_by_weight: Dictionary = {
	Enums.LootWeight.LIGHT: Vector3(0.0, 0.05, 0.0), Enums.LootWeight.MEDIUM: Vector3.ZERO,
	Enums.LootWeight.HEAVY: Vector3(0.0, -0.05, 0.0), Enums.LootWeight.VERY_HEAVY: Vector3(0.0, -0.05, 0.0),
}
## characters.md v1.21 crew-state event times (SOURCE, 30 fps): downed_arrested disarm@6 (the weapon goes), crew_cuffed_free
## free@8 (the weapon comes back); downed_getup crossfades into the current hold over getup_blend_s.
@export var arrest_disarm_s: float = 0.2
@export var cuffed_free_s: float = 0.2667
@export var getup_blend_s: float = 0.2
## characters.md D-116 crew_actions (SOURCE, 30 fps): mask_on mask_on@18 (the mask appears on the face; the clip plays
## when the replicated `masked` turns true, the weapon holstered throughout), throw_grenade release@11 (re-timed so
## it lands on the gameplay release, CombatTweak.throw_windup_s after the pin).
@export var mask_on_event_s: float = 0.6
@export var throw_release_event_s: float = 0.3667
## Lead ruling (b): a hit-zone flinch on a moving body is an upper-body layer at this weight (SOURCE hit_zones 0.7,
## hit_head 0.9).
@export var hit_zone_layer_weight: float = 0.7
@export var hit_zone_layer_head_weight: float = 0.9
## Lead ruling (c): the third-person left-hand IK blends in / out at this rate (1/s).
@export var left_hand_ik_rate: float = 8.0
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
@export var hard_hat_lift_clips: Array[StringName] = [&"surrender", &"surrender_b", &"surrender_c",
	&"surrender_idle", &"surrender_idle_b", &"surrender_idle_c", &"hands_up", &"hands_up_b", &"hands_up_c",
	&"cower", &"cower_b", &"cower_seated", &"cower_stand", &"kneel_cuffed", &"kneel_cuffed_b", &"kneel_cuffed_c"]
## Lift (m) of a hand resting on the head: the shell stands ~2.4 cm off the skull (ENV D audit R1).
@export var hard_hat_hand_lift_m: float = 0.03
## A hand within this distance (m) of the head bone counts as resting on it.
@export var hard_hat_near_head_m: float = 0.32
## Influence blend rate (1/s) in and out of the lift clips.
@export var hard_hat_lift_rate: float = 6.0

@export_group("Animation LOD (D-132, AnimLod)")
## Off: every NPC AnimDriver updates every frame at any distance (pre-D-132).
@export var anim_lod_enabled: bool = true
## Distance from the local camera (m): full rate below near; near..far on screen every `anim_lod_near_cadence`
## frames (left-hand IK off); beyond far or off screen every `anim_lod_far_cadence` frames (hold layer off); off
## screen and beyond far: paused (time banked, caught up when it is due again).
@export var anim_lod_near_m: float = 15.0
@export var anim_lod_far_m: float = 30.0
@export var anim_lod_near_cadence: int = 2
@export var anim_lod_far_cadence: int = 4
## On-screen test: a sphere of this radius (m) around the body at anim_lod_center_y_m against the camera frustum.
@export var anim_lod_radius_m: float = 1.2
@export var anim_lod_center_y_m: float = 0.9
## Never LOD an NPC within this distance (m) of a crew member's aim ray (the player / a teammate aiming at it).
@export var anim_lod_aim_radius_m: float = 2.0


## Seconds from the start of third-person clip `clip_id` to `event`, read from the rig's SOURCE.txt (so a D
## retime needs no tweak change); `fallback` (the hand-copied tweak value) while the clip or event is missing.
static func clip_event_s(clip_id: StringName, event: StringName, fallback: float) -> float:
	var ev: Dictionary = FpViewmodelTweak.source_events(CHAR_SOURCE).get(clip_id, {})
	return float(ev[event]) / SOURCE_FPS if ev.has(event) else fallback


## Reload `done` time for a reload_done_s key (SOURCE.txt first, then the tweak table, then the rifle's).
func reload_done(key: StringName, fallback_key: StringName = &"rifle") -> float:
	var fb: float = float(reload_done_s.get(key, reload_done_s.get(fallback_key, 1.0)))
	return clip_event_s(RELOAD_CLIPS.get(key, &""), &"done", fb)


## downed_arrested `disarm` (the weapon goes) and crew_cuffed_free `free` (it comes back), SOURCE.txt first.
func disarm_s() -> float:
	return clip_event_s(&"downed_arrested", &"disarm", arrest_disarm_s)


func free_s() -> float:
	return clip_event_s(&"crew_cuffed_free", &"free", cuffed_free_s)


## mask_on `mask_on` (the mask shows at Head/Socket) and throw_grenade `release` (the grenade leaves the hand), SOURCE first.
func mask_on_s() -> float:
	return clip_event_s(&"mask_on", &"mask_on", mask_on_event_s)


func throw_release_s() -> float:
	return clip_event_s(&"throw_grenade", &"release", throw_release_event_s)


static func data() -> AnimTweak:
	if _cached == null:
		_cached = load(PATH) as AnimTweak
		if _cached == null:
			_cached = AnimTweak.new()
	return _cached
