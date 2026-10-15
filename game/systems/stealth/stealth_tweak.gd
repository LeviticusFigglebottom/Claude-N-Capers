## Stealth tunables: detection (S2), outcomes (S3), stimuli (S4), pagers (S5), civilians (S7).
## Owner: ENV A. Data: stealth_tweak.tres. Rows marked ◇ in pd2_fidelity.md are design choices.
class_name StealthTweak
extends Resource

@export_group("Detection (S2)")
## Observer presets by kind (S2.2): near/far (m), fov_deg (full angle), min_time (s to fill at
## point-blank, dead centre, DR 35).
@export var observer_presets: Dictionary = {
	&"guard": {"near": 2.0, "far": 30.0, "fov_deg": 120.0, "min_time": 1.0},
	&"civilian": {"near": 2.0, "far": 24.0, "fov_deg": 140.0, "min_time": 1.4},
	&"camera": {"near": 2.0, "far": 20.0, "fov_deg": 60.0, "min_time": 2.0},
	&"police": {"near": 2.0, "far": 40.0, "fov_deg": 140.0, "min_time": 0.6},
}
## S2.3: DR -> concealment time multiplier (PD2 table, interpolated). x = DR, y = mult.
@export var dr_table: PackedVector2Array = PackedVector2Array([
	Vector2(3, 1.55), Vector2(7, 1.475), Vector2(10, 1.425), Vector2(16, 1.325), Vector2(20, 1.25),
	Vector2(26, 1.15), Vector2(35, 1.0), Vector2(43, 0.85), Vector2(52, 0.7), Vector2(63, 0.5), Vector2(75, 0.3),
])
## DR used when a crew member has no resolved loadout.
@export var default_detection_risk: int = 35
## S2.1 ◇ decay per second without LOS.
@export var decay_per_s: float = 0.25
## S2.2 factors.
@export var dist_factor_min: float = 0.1
@export var angle_factor_edge: float = 0.45
## S2.5 ◇ crouch multiplier (not applied to cameras).
@export var crouch_rate_mult: float = 0.75
## S1.1 ◇ casing: fill only in RESTRICTED or within this distance of a guard, at this rate.
@export var casing_too_close_m: float = 3.0
@export var casing_rate_mult: float = 0.35
## S1.1 ◇ (open question for the lead): whether the "too close to a guard" rule also applies while
## the unmasked crew member stands in a PUBLIC zone. false = PUBLIC is always safe while unmasked.
@export var casing_too_close_applies_in_public: bool = false
## Height above the crew member's feet used for zone lookups (m).
@export var zone_probe_height_m: float = 0.9
## Height above a stimulus source's origin used for its LOS ray (m).
@export var stimulus_los_height_m: float = 0.3
## Max seconds integrated in one staggered observer update (guards against hitches).
@export var max_tick_dt_s: float = 0.4
## Below this change a detection_progress update is not re-sent.
@export var progress_send_epsilon: float = 0.005
## Detection tick rate (architecture.md §10: 10 Hz staggered).
@export var tick_hz: float = 10.0
## Points on the crew body tested for LOS (heights above feet, m).
@export var los_heights: PackedFloat32Array = PackedFloat32Array([1.6, 1.0])

@export_group("Outcomes (S3)")
@export var guard_radio_call_s: float = 2.0
@export var investigate_budget_s: float = 20.0
@export var civilian_call_s: float = 3.0
## S3.5 camera alarm countdown (P2 row; numbers here so P1 cameras use them).
@export var camera_alarm_delay_s: float = 7.0

@export_group("Cameras (S8.1, S8.2)")
## S8.1: cameras are Titan (indestructible) from this difficulty (Enums.Difficulty.LETHAL ~ Mayhem).
@export var camera_titan_min_difficulty: int = Enums.Difficulty.LETHAL
## S8.1 ◇: after a camera is destroyed in a staffed room the operator dispatches the nearest guard
## to investigate it with this chance (rolled on GameRng &"cameras"), after this delay.
@export var camera_dispatch_chance: float = 0.3
@export var camera_dispatch_delay_s: float = 10.0
## Visual: pitch (degrees) a destroyed camera head droops by.
@export var camera_broken_droop_deg: float = 35.0

@export_group("Stimuli (S4.1, S4.4, S6.3)")
## kind -> {range (m), los (bool), fill_time (s), guard (reaction), civilian (reaction), camera (bool)}
## (+ optional camera_alarm (bool, default true): a camera confirming it starts the S3.5 countdown.)
## Reactions: &"alarm" (guard -> ALARMED), &"investigate", &"panic", &"ignore".
@export var stimuli: Dictionary = {
	&"corpse": {"range": 25.0, "los": true, "fill_time": 0.8, "guard": &"alarm", "civilian": &"panic", "camera": true},
	&"body_bag": {"range": 19.0, "los": true, "fill_time": 1.2, "guard": &"investigate", "civilian": &"ignore", "camera": true},
	&"bag": {"range": 18.0, "los": true, "fill_time": 1.5, "guard": &"investigate", "civilian": &"ignore", "camera": true},
	&"broken_glass": {"range": 15.0, "los": true, "fill_time": 1.5, "guard": &"investigate", "civilian": &"ignore", "camera": true},
	&"drill": {"range": 25.0, "los": false, "fill_time": 1.0, "guard": &"investigate", "civilian": &"ignore", "camera": true},
	&"alerted_npc": {"range": 20.0, "los": true, "fill_time": 1.0, "guard": &"investigate", "civilian": &"panic", "camera": true},
	&"restrained": {"range": 15.0, "los": true, "fill_time": 1.0, "guard": &"alarm", "civilian": &"panic", "camera": true},
	&"hostage": {"range": 15.0, "los": true, "fill_time": 1.0, "guard": &"alarm", "civilian": &"panic", "camera": true},
	&"open_door": {"range": 10.0, "los": true, "fill_time": 2.0, "guard": &"investigate", "civilian": &"ignore", "camera": false},
	# A2-04 S4.1: a saw cutting within 10 m (on top of the 25 m `drill` stimulus of any running device).
	&"saw": {"range": 10.0, "los": false, "fill_time": 0.8, "guard": &"investigate", "civilian": &"ignore", "camera": true},
	# A2-02 S8.1/S4.4: a destroyed camera (guards investigate it, other cameras see it).
	&"broken_camera": {"range": 15.0, "los": true, "fill_time": 1.5, "guard": &"investigate", "civilian": &"ignore", "camera": true},
}

@export_group("Noise (S4.3)")
## Radius multiplier when the listener has no LOS to the source (◇ generalised from drills).
@export var noise_no_los_mult: float = 0.5
@export var gunshot_player_radius_m: float = 45.0
@export var gunshot_npc_radius_m: float = 25.0
@export var glass_break_radius_m: float = 15.0
@export var drill_radius_m: float = 25.0
## A2-04 S4.3/S9.4 ◇: saws are as loud as drills.
@export var saw_radius_m: float = 25.0
## Noise kinds and the reaction they cause. Guards: &"alarm" or &"investigate"; civilians: &"panic"/&"ignore".
@export var noise_reactions: Dictionary = {
	&"gunshot": {"guard": &"alarm", "civilian": &"panic"},
	&"explosion": {"guard": &"alarm", "civilian": &"panic"},
	&"glass": {"guard": &"investigate", "civilian": &"panic"},
	&"drill": {"guard": &"investigate", "civilian": &"ignore"},
	&"alarm": {"guard": &"alarm", "civilian": &"panic"},
	&"loud": {"guard": &"investigate", "civilian": &"ignore"},
	&"quiet": {"guard": &"investigate", "civilian": &"ignore"},
	&"saw": {"guard": &"investigate", "civilian": &"ignore"},
}

@export_group("Pagers (S5.2-S5.5)")
@export var pager_delay_min_s: float = 2.0
@export var pager_delay_max_s: float = 4.0
@export var pager_window_s: float = 12.0
@export var pager_answer_s: float = 10.0
@export var pager_max_answers: int = 4
## PO6-08 (D-114 §4, amended by the PO): the response window freezes while anyone holds the answer.
## When the last holder lets go early the pager fails with the alarm (S5.4), unless within
## pager_juggle_window_s the same player starts answering ANOTHER live pager (a juggle): then the
## released pager resumes its remaining window and must still be answered. true = never alarm on an
## early release, always resume (pre-amendment PO6-08 behaviour; tests / options).
@export var pager_release_resumes: bool = false
## PO6-08 juggle grace (s): how long a released pager waits for its answerer to pick up another pager.
@export var pager_juggle_window_s: float = 0.5

@export_group("Civilians (S3.1, S7)")
@export var intimidate_duration_s: float = 45.0
@export var shout_range_m: float = 12.0
@export var shout_cone_deg: float = 30.0
@export var shout_all_within_m: float = 6.0
@export var fleeing_shout_chance: float = 0.5
@export var cable_tie_s: float = 2.0
## A1-06 ◇: one shout per crew member per this many seconds.
@export var shout_cooldown_s: float = 0.8
## A1-06 ◇ civilian locomotion (m/s).
@export var civilian_walk_speed: float = 1.3
@export var civilian_run_speed: float = 4.0
## A1-06 ◇ S7.5 wander: CALM civilians walk to a random PatrolPoint within `civilian_wander_radius_m`
## every [min, max] s: customers to public `civilian` points, staff to `staff` points of their own area
## (PO-5, CivilianTargets.wander_options).
@export var civilian_wander_interval_s: Vector2 = Vector2(15.0, 40.0)
@export var civilian_wander_radius_m: float = 15.0
## A1-06 ◇: distance at which a panicked civilian reaches a guard to alert them (m).
@export var civilian_guard_reach_m: float = 1.5
## A1-06 ◇ loud (S11.2): panicked civilians run this far from the nearest crew member, then cower.
@export var civilian_flee_distance_m: float = 10.0
## PO-5 ◇: a fleeing civilian that moves less than civilian_flee_stall_m in civilian_flee_stall_s
## (blocked doorway, unreachable point) cowers where it is instead of running in place forever.
@export var civilian_flee_stall_s: float = 2.0
@export var civilian_flee_stall_m: float = 0.3
## PO-5 ◇ S7.5: wander points must be within civilian_wander_radius_m of navmesh path (no navmesh: straight
## line and within this height difference, i.e. the same floor). Also the height window for a staff
## civilian's home point (nearest `staff` point to its spawn, whose `staff_*` area tags it keeps to).
@export var civilian_wander_floor_dy_m: float = 1.5
## PO-5 ◇: a walking/running civilian (WANDER, RUN_TO_CALL) that moves less than civilian_walk_stall_m in
## civilian_walk_stall_s re-paths to its target; stalling again it gives that target up (wander: picks
## another point later; call: the next-cheapest call point or guard, else flees).
@export var civilian_walk_stall_s: float = 2.5
@export var civilian_walk_stall_m: float = 0.3
## PO-5 ◇ S7.1: the all-round shout (shout_all_within_m) reaches only civilians on the shouter's floor
## (height difference <= shout_floor_dy_m) that can hear it: clear line of sight, or a navmesh path no
## longer than shout_all_within_m x shout_path_mult (around a counter or a doorway, not through a wall).
@export var shout_floor_dy_m: float = 2.5
@export var shout_path_mult: float = 1.3

@export_group("Calm NPC yield (PO-5)")
## PO-5 ◇: a CALM NPC (idle/wandering civilian, patrolling/posted guard) that a crew member keeps pressing
## into (within npc_yield_reach_m, horizontal speed <= npc_yield_press_speed, move input held, facing it
## within npc_yield_face_deg) for npc_yield_press_s steps npc_yield_step_m aside (lateral first, else
## back) at npc_yield_speed. Once no crew is within npc_yield_clear_m for npc_yield_hold_s (or after
## npc_yield_max_s) it resumes: an NPC that was standing returns to its spot. PD2 NPCs never wall you in.
@export var npc_yield_reach_m: float = 0.8
@export var npc_yield_press_s: float = 1.5
@export var npc_yield_press_speed: float = 0.6
@export var npc_yield_face_deg: float = 50.0
@export var npc_yield_step_m: float = 1.0
@export var npc_yield_speed: float = 1.4
@export var npc_yield_clear_m: float = 1.3
@export var npc_yield_hold_s: float = 1.5
@export var npc_yield_max_s: float = 8.0

@export_group("NPC personal space (PO-10)")
## PO-10 ◇ (PD2: NPCs keep personal space, never stack): NPC bodies do not collide with each other
## (NpcBase MASK_WORLD), so NpcMotor steers. A moving NPC is pushed away from every other live NPC of its
## heist within npc_separation_radius_m (horizontal; |dy| < npc_separation_dy_m), weighted by closeness and
## scaled by npc_separation_gain; when the push opposes its heading it veers to its own right so two NPCs
## meeting head-on pass instead of stalling. Speed never exceeds the brain's.
@export var npc_separation_radius_m: float = 1.0
@export var npc_separation_gain: float = 1.5
@export var npc_separation_dy_m: float = 1.0
## PO-10 ◇: a standing CALM NPC closer than npc_separation_idle_m to another (spawned stacked, pushed in)
## drifts apart at npc_separation_idle_speed (m/s).
@export var npc_separation_idle_m: float = 0.6
@export var npc_separation_idle_speed: float = 0.6
## PO-10 ◇: a moving NPC whose target is already held by a standing NPC (within npc_crowd_occupied_m of it)
## counts as arrived once within npc_crowd_arrive_m of the target (it waits beside it, not inside it).
@export var npc_crowd_arrive_m: float = 1.2
@export var npc_crowd_occupied_m: float = 0.6
## PO-10 ◇ S7.5: a wander point is not offered to a civilian while another NPC is heading to it (its
## motor's target, until it arrives or goes elsewhere) or stands within civilian_wander_taken_m of it.
@export var civilian_wander_taken_m: float = 0.8

@export_group("Heist mode (S11.3)")
## STEALTH_ONLY heists: seconds between the alarm (Mercer abort line) and heist_ended(failed).
@export var stealth_only_abort_s: float = 5.0

@export_group("P2 guards (S3.2 cuffs, S3.7 misfire, S2.9 marking)")
## S3.2 (P2): a guard reaching "!" on a crew member yells, pauses, walks over and cuffs them.
## false = the P1 simplification (radio call straight away).
@export var guard_cuffs_enabled: bool = true
## S3.2: yell + pause before walking over (s).
@export var cuff_pause_s: float = 5.0
## S3.2: moving farther than this (horizontal, m) from where the crew member was spotted makes the
## guard open fire (alarm).
@export var cuff_move_tolerance_m: float = 1.7
## S3.2 ◇: the guard cuffs from this distance (m) after holding still next to the target (s).
@export var cuff_reach_m: float = 1.2
@export var cuff_action_s: float = 1.0
## S3.2 ◇: the walk over gives up after this long (s) and the guard radios the alarm instead.
@export var cuff_approach_timeout_s: float = 20.0
## S3.2: a crew member cannot be cuffed again for this long after being cuffed (s, 4 min).
@export var cuff_cooldown_s: float = 240.0
## S3.2: a cuffed crew member breaks free by themselves after this (s); a teammate frees them by
## holding interact for `uncuff_s` ◇.
@export var cuff_self_free_s: float = 60.0
@export var uncuff_s: float = 2.0
## S3.2: voice line requested when the guard yells (speaker = EnemyDef.voice, else &"guard").
@export var cuff_yell_line: StringName = &"vo.guard.cuff_warning"
## S3.7: chance that a non-head, non-shotgun bullet kill makes the guard's gun go off (NPC gunshot
## noise, gunshot_npc_radius_m), rolled on GameRng &"misfire".
@export var misfire_chance: float = 0.1
## S2.9 ◇: mark durations (s, × stealth.mark_duration_mult of the marker).
@export var mark_duration_guard_s: float = 4.5
@export var mark_duration_camera_s: float = 8.0
@export var mark_duration_special_s: float = 4.5
## S2.9 ◇: a shout marks the markable target nearest the aim line within this half-angle (deg) and range (m).
@export var mark_cone_half_deg: float = 8.0
@export var mark_range_m: float = 40.0
## S2.9 Sixth Sense (stealth.sixth_sense): standing still this long (s, horizontal speed below
## sixth_sense_still_speed m/s) in stealth marks every enemy within sixth_sense_radius_m, repeating.
@export var sixth_sense_still_s: float = 3.5
@export var sixth_sense_radius_m: float = 10.0
@export var sixth_sense_still_speed: float = 0.1

@export_group("Guard domination (S5.8)")
## S5.8: a shout from crew with `stealth.can_dominate_guards` within this many seconds after a
## guard's "!" makes him kneel and cuff himself (100% inside the window). His pager still fires.
@export var guard_dominate_window_s: float = 1.5
## S5.8 / D-079: the shout reaches the guard nearest the aim line within guard_dominate_range_m (10 m),
## x guard_dominate_skill_range_mult (1.5) with the domination skill (`ability.intimidate_cops`, the
## Dominator analog) x ability.shout_range_mult (Crew Chief 1.25), multiplicative, with line of sight.
@export var guard_dominate_range_m: float = 10.0
@export var guard_dominate_skill_range_mult: float = 1.5
## D-079 aim cone half-angle (deg): max(min, linear from near_deg at 0 m to far_deg at far_m).
@export var guard_dominate_cone_near_deg: float = 90.0
@export var guard_dominate_cone_far_deg: float = 30.0
@export var guard_dominate_cone_far_m: float = 12.0
@export var guard_dominate_cone_min_deg: float = 8.0
