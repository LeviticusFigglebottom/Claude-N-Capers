## Stealth tunables: detection (S2), outcomes (S3), stimuli (S4), pagers (S5), civilians (S7).
## Owner: ENV A. Data: stealth_tweak.tres. Rows marked ◇ in pd2_fidelity.md are design choices.
class_name StealthTweak
extends Resource

@export_group("Detection (S2)")
## D-128: PAYDAY 2's detection model (pd2_fidelity S2). Sources: PD2's decompiled Lua (community mirror
## steam-test1/Payday-2-LuaJIT-Complete, lib/): tweak_data/charactertweakdata.lua presets.detection,
## units/enemies/cop/logics/coplogicbase.lua _upd_attention_obj_detection, units/props/securitycamera.lua,
## units/editor/securitycameraelement.lua, tweak_data/attentiontweakdata.lua _init_player,
## units/beings/player/playerbase.lua, managers/blackmarketmanager.lua, tweak_data/weapontweakdata.lua.
## Observer presets by kind. NPCs (in stealth PD2 uses the `ntl` preset): far = dis_max (m), fov_deg =
## 2 x angle_max (deg; the half angle is angle_max), delay_min / delay_max (s, the `delay` pair), attention =
## which player attention class the observer reads (&"combatant": guards, police, gangsters, cameras;
## &"non_combatant": civilians). Cameras: far = detection_range, fov_deg = the full cone, delay pair =
## the ElementSecurityCamera editor defaults {2, 3} x 0.8 (D-130 PO: cameras ~20 % faster, ◇; PD2 sets them per
## camera; SecurityCamera.detection_overrides()
## supplies fov_deg / far). gadget_time: D-118 gadget base fill time (s, ◇; PD2 ignores flashlights/lasers).
@export var observer_presets: Dictionary = {
	&"guard": {"far": 40.0, "fov_deg": 120.0, "delay_min": 0.2, "delay_max": 2.0, "attention": &"combatant",
		"gadget_time": 1.0},
	&"civilian": {"far": 20.0, "fov_deg": 120.0, "delay_min": 0.2, "delay_max": 3.0, "attention": &"non_combatant",
		"gadget_time": 1.4},
	&"camera": {"far": 15.0, "fov_deg": 60.0, "delay_min": 1.6, "delay_max": 2.4, "attention": &"combatant",
		"gadget_time": 2.0},
	&"police": {"far": 40.0, "fov_deg": 120.0, "delay_min": 0.2, "delay_max": 2.0, "attention": &"combatant",
		"gadget_time": 0.6},
}
## D-128 PD2 masked-player attention settings (attentiontweakdata pl_mask_on_foe_<class>_whisper_mode_<stance>),
## keyed "<class>_<stance>": max_range (m, caps the preset far; < 0 = no cap), notice_delay_mul (scales
## delay_min), uncover_range (m: an NPC notices instantly inside it while within uncover_angle_deg of its
## facing; cameras have no uncover). Crouching is PD2's own crouch effect (S2.5).
@export var attention_settings: Dictionary = {
	&"combatant_stand": {"max_range": 20.0, "notice_delay_mul": 2.0, "uncover_range": 2.0},
	&"combatant_crouch": {"max_range": 12.0, "notice_delay_mul": 2.0, "uncover_range": 2.0},
	&"non_combatant_stand": {"max_range": -1.0, "notice_delay_mul": 1.5, "uncover_range": 5.5},
	&"non_combatant_crouch": {"max_range": 15.0, "notice_delay_mul": 3.0, "uncover_range": 2.0},
}
## D-128 PD2 NPC view cone: the half angle is 180 deg (all round) within npc_all_round_m and narrows linearly
## to fov_deg / 2 over the next npc_angle_narrow_m (coplogicbase _angle_and_dis_chk: 150 cm, 700 cm).
@export var npc_all_round_m: float = 1.5
@export var npc_angle_narrow_m: float = 7.0
## D-128 PD2 uncover: inside the attention uncover_range and under this angle off the NPC's facing, instant.
@export var uncover_angle_deg: float = 55.0
## D-128 PD2 delay lerp: delay = lerp(delay_min x notice_delay_mul x conceal_mult, delay_max,
## dis_weight x d / range + angle_weight x min(angle / angle_ref, 1)), range = min(far, max_range) x
## sqrt(1 / conceal_mult). NPC angle_ref = fov_deg / 2; camera angle_ref = fov_deg (securitycamera.lua
## divides by the full cone).
@export var npc_dis_weight: float = 0.75
@export var npc_angle_weight: float = 0.25
@export var camera_dis_weight: float = 0.85
@export var camera_angle_weight: float = 0.15
## D-128 PD2 drain while not noticeable (no sight, out of view or range): NPCs lose npc_decay_per_s progress
## per second (coplogicbase: dt x -0.125); cameras lose 1 / delay_max per second (securitycamera:
## -dt / det_delay[2]). Progress below 0 clears the meter.
@export var npc_decay_per_s: float = 0.125
## S2.3: DR -> concealment multiplier (PD2 tweak_data.weapon.stats.concealment through the suspicion offset,
## interpolated). x = DR, y = mult. PD2: delay_min x mult, detection range x sqrt(1 / mult).
@export var dr_table: PackedVector2Array = PackedVector2Array([
	Vector2(3, 1.55), Vector2(7, 1.475), Vector2(10, 1.425), Vector2(16, 1.325), Vector2(20, 1.25),
	Vector2(26, 1.15), Vector2(35, 1.0), Vector2(43, 0.85), Vector2(52, 0.7), Vector2(63, 0.5), Vector2(75, 0.3),
])
## DR used when a crew member has no resolved loadout.
@export var default_detection_risk: int = 35
## S4.1 ◇ stimulus meters (bodies, bags...) decay per second out of view; crew meters use the PD2 drain.
@export var decay_per_s: float = 0.25
## D-118 ◇ gadget-only distance falloff floor and near distance (m); body detection has no floor (D-128).
@export var dist_factor_min: float = 0.1
@export var gadget_near_m: float = 2.0
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

@export_group("Weapon gadgets (D-118)")
## D-118 correction (pd2_fidelity S4.2): PD2 guards and cameras IGNORE flashlights and lasers, so these are 0 by
## default. Above 0, a masked crew member's switched-on flashlight / laser fills the S2.1 meter of an observer that
## sees the light even when the body is hidden: base_rate (preset min_time) x these multipliers (x difficulty,
## x stealth.detection_rate_mult; DR does not apply: it is the gadget that is seen). 0 = no gadget stimulus.
@export var gadget_light_detect_mult: float = 0.0
@export var gadget_laser_detect_mult: float = 0.0
## D-118 ◇: a laser beam passing within this distance (m) of an observer's eye, at a point it can see.
@export var gadget_laser_near_m: float = 1.0
## D-118 ◇: "roughly inside the cone": the flashlight cone half angle is scaled by this for detection.
@export var gadget_light_cone_mult: float = 1.25
## D-118: fallbacks when the resolved weapon params lack them (visual_slots.md v1.3 defaults).
@export var gadget_laser_range_m: float = 50.0
@export var gadget_light_range_m: float = 25.0
@export var gadget_light_angle_deg: float = 30.0
## D-118: LOS rays to a beam point / laser dot stop this far short of it (m).
@export var gadget_los_pullback_m: float = 0.05

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
## `los: false` (drills, saws) lets NPCs notice it in range without sight; cameras always need it inside
## their cone with a clear ray (PO6-04, D-114 §1: cameras react only to what they see).
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
## PO6-20: the answer prompt follows the body (its `hips` bone, height pager_prompt_up_m) and is aimable
## anywhere within pager_aim_radius_m of it, so a body that fell 1-2 m from its root is easy to answer.
@export var pager_aim_radius_m: float = 0.9
@export var pager_prompt_up_m: float = 0.25

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
## OF-A4 ◇ (D-136 §3b.4) CivilianRoute: a stop counts as reachable when the navmesh path toward it ends within this
## of it (no navmesh: same floor, civilian_wander_floor_dy_m), and a routed civilian that stops farther than this from
## its stop (a locked door) gives it up; either way it goes on to the next stop (logged once).
@export var civilian_route_reach_m: float = 1.0
## PO6-06 ◇ S7.5: a civilian whose idle activity is a seated loop (keys) sits only on a seat (the clips put the
## root under the seat centre, characters.md npc_seat): a seating prop's `Seat` marker within
## civilian_seat_radius_m (horizontal) of its root, on its floor (CivilianTargets.seat_near). With no seat it
## does the standing activity (value) instead: a seated pose on thin air reads as a hostage crouched on the floor.
## X-5: the seated aliases too (`desk` = the desk_work clip, D-115; desk_type / sit_chair / sit_chair_watch are seated
## rig clips, anim_humanoid.py). The standing desk clip is teller_count (`teller`), standing hands-on-counter.
@export var civilian_unseated_activity: Dictionary = {&"desk_work": &"teller", &"phone_seated": &"phone", &"sit": &"queue",
	&"desk": &"teller", &"desk_type": &"teller", &"sit_chair": &"queue", &"sit_chair_watch": &"idle"}
@export var civilian_seat_radius_m: float = 0.45
## X-5 ◇ (PD2: staff hold their post): a CALM IDLE civilian whose activity keeps it on its spawn mark (not a wander
## activity: a teller, a desk clerk, a seated customer) that is off the mark (a crew yield, a drift while alerted)
## and standing still for civilian_mark_return_s goes back: within civilian_mark_settle_m it slides straight onto
## the mark at npc_mark_settle_speed (NpcMotor.mark_anchor), farther it walks there first. It then faces its
## spawn facing again.
@export var civilian_mark_return_s: float = 1.0
@export var civilian_mark_settle_m: float = 0.8
@export var npc_mark_settle_speed: float = 1.0
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
