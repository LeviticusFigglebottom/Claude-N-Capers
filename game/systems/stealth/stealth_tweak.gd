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

@export_group("Stimuli (S4.1, S4.4, S6.3)")
## kind -> {range (m), los (bool), fill_time (s), guard (reaction), civilian (reaction), camera (bool)}
## Reactions: &"alarm" (guard -> ALARMED), &"investigate", &"panic", &"ignore".
@export var stimuli: Dictionary = {
	&"corpse": {"range": 25.0, "los": true, "fill_time": 0.8, "guard": &"alarm", "civilian": &"panic", "camera": true},
	&"body_bag": {"range": 19.0, "los": true, "fill_time": 1.2, "guard": &"investigate", "civilian": &"ignore", "camera": true},
	&"bag": {"range": 18.0, "los": true, "fill_time": 1.5, "guard": &"investigate", "civilian": &"ignore", "camera": true},
	&"broken_glass": {"range": 15.0, "los": true, "fill_time": 1.5, "guard": &"investigate", "civilian": &"ignore", "camera": true},
	&"drill": {"range": 25.0, "los": false, "fill_time": 1.0, "guard": &"investigate", "civilian": &"ignore", "camera": true},
	&"alerted_npc": {"range": 20.0, "los": true, "fill_time": 1.0, "guard": &"investigate", "civilian": &"panic", "camera": true},
	&"restrained": {"range": 15.0, "los": true, "fill_time": 1.0, "guard": &"alarm", "civilian": &"panic", "camera": true},
	&"open_door": {"range": 10.0, "los": true, "fill_time": 2.0, "guard": &"investigate", "civilian": &"ignore", "camera": false},
}

@export_group("Noise (S4.3)")
## Radius multiplier when the listener has no LOS to the source (◇ generalised from drills).
@export var noise_no_los_mult: float = 0.5
@export var gunshot_player_radius_m: float = 45.0
@export var gunshot_npc_radius_m: float = 25.0
@export var glass_break_radius_m: float = 15.0
@export var drill_radius_m: float = 25.0
## Noise kinds and the reaction they cause. Guards: &"alarm" or &"investigate"; civilians: &"panic"/&"ignore".
@export var noise_reactions: Dictionary = {
	&"gunshot": {"guard": &"alarm", "civilian": &"panic"},
	&"explosion": {"guard": &"alarm", "civilian": &"panic"},
	&"glass": {"guard": &"investigate", "civilian": &"panic"},
	&"drill": {"guard": &"investigate", "civilian": &"ignore"},
	&"alarm": {"guard": &"alarm", "civilian": &"panic"},
	&"loud": {"guard": &"investigate", "civilian": &"ignore"},
	&"quiet": {"guard": &"investigate", "civilian": &"ignore"},
}

@export_group("Pagers (S5.2-S5.5)")
@export var pager_delay_min_s: float = 2.0
@export var pager_delay_max_s: float = 4.0
@export var pager_window_s: float = 12.0
@export var pager_answer_s: float = 10.0
@export var pager_max_answers: int = 4

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
## A1-06 ◇ S7.5 wander: CALM civilians walk to a random civilian/staff PatrolPoint within
## `civilian_wander_radius_m` every [min, max] s.
@export var civilian_wander_interval_s: Vector2 = Vector2(15.0, 40.0)
@export var civilian_wander_radius_m: float = 15.0
## A1-06 ◇: distance at which a panicked civilian reaches a guard to alert them (m).
@export var civilian_guard_reach_m: float = 1.5
## A1-06 ◇ loud (S11.2): panicked civilians run this far from the nearest crew member, then cower.
@export var civilian_flee_distance_m: float = 10.0
