## Crew (player character) tunables. Owner: ENV A. Data: crew_tweak.tres.
## Fidelity rows: S1.1, S1.2, S1.5, L2.1, L2.2, L2.5-L2.7, S10.1.
class_name CrewTweak
extends Resource

@export_group("Movement")
@export var walk_speed: float = 3.5
@export var sprint_speed: float = 5.75
## PO-4 (PD2 PlayerStandard:_end_action_running, 0.4 s / exit_run_speed_multiplier): pressing fire while sprinting ends
## the sprint and the gun comes up over this long before it can shoot; sprint stays off until it is pressed again.
@export var sprint_exit_fire_s: float = 0.4
@export var crouch_speed: float = 2.25
## A4-04 (PD2 movement STEELSIGHT_MAX 185 / STANDARD_MAX 350): aiming down sights caps the move speed at this share of
## walk_speed (it overrides crouch, as PD2's _get_max_walk_speed). movement.ads_speed_penalty_mult scales the penalty
## (Snap Shot 0.0 = none).
@export var ads_speed_mult: float = 0.53
@export var jump_velocity: float = 4.6
@export var gravity: float = 9.8
@export var acceleration: float = 30.0
## PI-08: grounded braking (wish slower than / against the current velocity) - PD2 stops crisply.
@export var deceleration: float = 50.0
@export var air_control: float = 0.3
## Max yaw/pitch speed is unbounded: intents carry absolute angles.
@export var max_pitch_deg: float = 89.0

@export_group("Ground (P1-01)")
## Tallest lip walked up without jumping, and deepest drop followed down without leaving the floor (m).
## level_standards.md §2.6: stair risers 0.15–0.19 m and curbs/door sills fit with margin; >= the navmesh
## agent_max_climb (0.3 m) so AI crew never stall where their path climbs; < a chair seat (0.45 m), so
## furniture and 0.4 m+ ledges still need a jump.
@export var step_height_m: float = 0.35
## Steepest walkable ramp (deg); steeper is a wall. >= the navmesh agent_max_slope (40 deg).
@export var max_slope_deg: float = 45.0
## D-085: max sideways search (m) for an opening when walking head-on into a wall / frame edge (0 = off).
@export var edge_assist_m: float = 0.45
## PP-P-12: longer reach (m) toward a framed opening (a door / gap with a far jamb within
## edge_assist_frame_search_m), so walking head-on into a door's jamb wall slightly off-centre slides round it
## (PD2). Open edges (pillars, wall ends) keep edge_assist_m: a centred bump into a column still stops.
@export var edge_assist_door_m: float = 0.65
## PP-P-12: how far past the shifted capsule the far jamb may be for the opening to count as framed (m).
## Clear width up to this + capsule diameter (1.5 + 0.7 m covers a 1.8 m double door).
@export var edge_assist_frame_search_m: float = 1.5
## PP-P-12: the sideways search / shift runs this far back off the wall (m), so a door casing or trim proud of
## the wall face (touched first by the round capsule) does not block it.
@export var edge_assist_backoff_m: float = 0.06
## Camera-only smoothing of step-up / step-down height changes (1/s, exponential); gameplay position is exact.
@export var step_smooth_rate: float = 14.0
## PO-4 (PD2 stance TRANSITION_DURATION 0.23 s): camera-only easing of the crouch / stand eye-height change (1/s,
## exponential; 13 = ~95 % in 0.23 s). 0 = instant. Gameplay eye_height() switches at once.
@export var crouch_smooth_rate: float = 13.0
## PO-4 (PD2 use_headbob, default on; Options controls.head_bob, Reduce Motion forces it off): subtle camera-only
## head bob of the local human while walking on the ground. One cycle (two steps) per head_bob_stride_m travelled;
## vertical at twice the lateral frequency; amplitudes at head_bob_ref_mps, scaled by speed, x sprint mult, x ADS mult.
## PO-20 (D-145, "the run is wobbly"): calmer: smaller amplitudes, a sprint cycle of head_bob_sprint_stride_m (longer
## sprint strides: ~2.3 cycles/s at full sprint, was 3.75) and the sprint no bigger than the walk.
@export var head_bob_stride_m: float = 1.6
@export var head_bob_sprint_stride_m: float = 2.6
@export var head_bob_ref_mps: float = 3.5
@export var head_bob_vertical_m: float = 0.004
@export var head_bob_lateral_m: float = 0.003
@export var head_bob_roll_deg: float = 0.15
@export var head_bob_sprint_mult: float = 0.9
@export var head_bob_ads_mult: float = 0.15
@export var head_bob_rate: float = 6.0
## PO-4 (PD2 melee hit shaker): camera-only punch when the local human's melee hit lands: pitch down / roll kick
## through a critically damped spring of melee_punch_hz (peak at 1/w s). 0 = off.
@export var melee_punch_pitch_deg: float = 1.6
@export var melee_punch_roll_deg: float = 1.0
@export var melee_punch_hz: float = 4.0
## D-102 lane (PD2 playercarry.lua target_tilt -5, fpcameraplayerbase.lua math.step 150 deg/s): carrying a bag
## rolls the local human's camera by carry_tilt_deg, easing at carry_tilt_rate_dps, and back on drop. Camera only;
## off with Reduce Motion. 0 = off.
@export var carry_tilt_deg: float = -5.0
@export var carry_tilt_rate_dps: float = 150.0
## P-FP-STATES (CrewFpStates; PD2 L2.5 / L4.3 / L4.4): first-person presentation of the crew states, local human only.
## DOWNED: the eye (and the shot origin) at eye_downed, the camera eased there like a crouch; a small roll; the
## viewmodel lower and canted in. TASED: convulsion jitter (deg, Hz) and a knee buckle (m). CLOAKER_DOWNED: a kick
## punch, then the camera falls to fp_kick_eye_m rolled fp_kick_roll_deg and the viewmodel drops away. Hit punch:
## per hit, pitch (deg; health > armor), roll = pitch x ratio away from the hit's side. ◇ design values.
@export var eye_downed: float = 0.8
@export var fp_down_ease_s: float = 0.35
@export var fp_down_roll_deg: float = 4.0
@export var fp_down_vm_offset: Vector3 = Vector3(-0.03, -0.008, 0.0)
@export var fp_down_vm_rot_deg: Vector3 = Vector3(-2.0, 2.0, 7.0)
@export var fp_tase_ease_s: float = 0.15
@export var fp_tase_shake_deg: float = 1.5
@export var fp_tase_shake_hz: float = 13.0
@export var fp_tase_buckle_m: float = 0.15
@export var fp_tase_vm_mult: float = 1.6
@export var fp_kick_fall_s: float = 0.45
@export var fp_kick_eye_m: float = 0.35
@export var fp_kick_roll_deg: float = 70.0
@export var fp_kick_pitch_deg: float = 15.0
@export var fp_kick_punch_deg: float = 6.0
@export var fp_kick_vm_drop_m: float = 0.45
@export var fp_hit_punch_armor_deg: float = 0.5
@export var fp_hit_punch_health_deg: float = 1.2
@export var fp_hit_roll_ratio: float = 0.6
@export var fp_hit_punch_hz: float = 6.0
## Reduce Motion: the tase jitter is scaled by this (rolls and hit punches are off, heights stay).
@export var fp_reduce_motion_mult: float = 0.25
## PO-4 (PD2): camera-only landing dip of the local human. A landing faster than land_dip_min_mps kicks the eye down
## by (impact - min) x land_dip_gain (m per m/s, capped at land_dip_max_m) through a critically damped spring of
## land_dip_hz, so it dips and recovers in ~0.3 s. 0 gain = off. Gameplay position is unaffected.
@export var land_dip_min_mps: float = 2.0
@export var land_dip_gain: float = 0.012
@export var land_dip_max_m: float = 0.09
@export var land_dip_hz: float = 3.0

@export_group("Ladders (PO-16 / D-145: PD2 free climbing)")
## Human crew climb ladders by walking into them (PD2 PlayerMovement ladder state): no forced animation, full look.
## Bots keep the Ladder prefab's own climb.
@export var ladder_free_climb: bool = true
## Attach when the crew is this close (horizontal) to the ladder's climb line, facing it.
@export var ladder_attach_radius_m: float = 0.55
## Facing cone toward the ladder (deg) for an attach by walking into it.
@export var ladder_attach_cone_deg: float = 70.0
## Climb speed along the ladder (m/s); PD2 climbs at a walk-like pace.
@export var ladder_climb_speed_mps: float = 2.4
## Look pitch below this (deg, negative = down) reverses W/S: look down + forward climbs down (PD2).
@export var ladder_down_pitch_deg: float = -20.0
## Jump lets go: pushed off the ladder (m/s, away from the wall) with this upward speed.
@export var ladder_jump_off_mps: float = 2.5
@export var ladder_jump_off_up_mps: float = 1.5
## Step-off onto the top landing: horizontal speed toward the Top marker once above its height.
@export var ladder_step_off_mps: float = 2.4
## Pull back onto the climb line while attached (1/s).
@export var ladder_snap_rate: float = 8.0

@export_group("Stamina (QB-60, PD2 movement_state.stamina)")
## Pool before movement.stamina_mult x team.stamina_mult x ArmorDef.stamina_mult.
@export var stamina_base: float = 50.0
@export var stamina_drain_per_s: float = 2.0
@export var stamina_regen_per_s: float = 3.0
## D-107 (PD2 REGENERATE_TIME): regeneration starts this long after a sprint stops (or after a jump drain when no
## timer runs) (s).
@export var stamina_regen_delay_s: float = 1.0
## D-107 (PD2 MIN_STAMINA_THRESHOLD): a sprint starts only above this; a run-jump costs only above it.
@export var stamina_min_threshold: float = 4.0
## D-107 (PD2 JUMP_STAMINA_DRAIN): cost of a run-jump (sprinting longer than stamina_run_jump_min_s, moving).
@export var stamina_jump_cost: float = 2.0
@export var stamina_run_jump_min_s: float = 0.4
## D-107 (PD2 _jump_t + 0.55): minimum time between two jumps (s).
@export var jump_cooldown_s: float = 0.55

@export_group("Body")
@export var capsule_radius: float = 0.35
@export var height_standing: float = 1.8
@export var height_crouched: float = 1.2
@export var eye_standing: float = 1.65
@export var eye_crouched: float = 1.05

@export_group("Mask (S1.2)")
@export var mask_up_time_s: float = 1.0
@export var mask_slowmo_duration_s: float = 0.6
@export var mask_slowmo_scale: float = 0.4

@export_group("Survival (L2)")
@export var base_health: float = 230.0
@export var default_armor: float = 20.0
@export var armor_regen_delay_s: float = 3.0
@export var armor_regen_full_time_s: float = 1.0
## Invulnerability after a gated hit: index by Enums.Difficulty.
@export var armor_gate_invuln_s: PackedFloat32Array = PackedFloat32Array([0.45, 0.45, 0.45, 0.45, 0.35, 0.35])
@export var bleedout_time_s: float = 30.0
@export var bleedout_health: float = 100.0
@export var downs_before_custody: int = 3
@export var revive_time_s: float = 6.0
## Health fraction after revive, by Enums.Difficulty (L2.7).
@export var revived_health_frac: PackedFloat32Array = PackedFloat32Array([0.4, 0.4, 0.4, 0.4, 0.1, 0.1])

@export_group("Inventory")
@export var body_bags_base: int = 1
@export var body_bags_cap: int = 2
@export var cable_ties_base: int = 2

@export_group("Bags (S10.1)")
## Index by Enums.LootWeight. D-102: PD2 carrytweakdata.lua types light / medium / heavy / very_heavy.
## move_speed_modifier (also scales the head bob, playercarry.lua _get_walk_headbob).
@export var bag_speed_mult: PackedFloat32Array = PackedFloat32Array([1.0, 0.75, 0.5, 0.25])
## can_run.
@export var bag_can_sprint: Array[bool] = [true, false, false, false]
## jump_modifier: jump velocity x this (playercarry.lua _perform_jump); jumping is never blocked by a bag.
@export var bag_jump_mult: PackedFloat32Array = PackedFloat32Array([1.0, 1.0, 0.5, 0.25])
## throw_distance_multiplier 1 / 1 / 0.5 / 0.3 of a 4 m base.
@export var bag_throw_distance_m: PackedFloat32Array = PackedFloat32Array([4.0, 4.0, 2.0, 1.2])

@export_group("AI teammates (PO6-15, PD2 team AI)")
## PO6-15 (D-114 §6): PD2 bots support, they cannot carry a loud heist. These replace CrewAiTweak's fight values for
## the AI crew (ENV A reads them in CrewAiBrain / CrewWeapons). Measured with tests/p/_review/bot_strength_probe.
## Damage of an AI teammate's bullet x this (PD2 *_crew weapons hit far softer than the player's) ◇.
@export var ai_damage_mult: float = 0.4
## Delay between acquiring a target and the first shot (s; PD2 gang_member focus + aim delay) ◇.
@export var ai_reaction_time_s: float = 0.8
## Minimum time between trigger pulls (s) ◇.
@export var ai_shot_interval_s: float = 0.45
## Chance per shot to aim at the head instead of the chest ◇.
@export_range(0.0, 1.0) var ai_head_aim_chance: float = 0.05
## Aim error radius at the aim point (m) = ai_aim_error_m + ai_aim_error_per_m x target distance (PD2 accuracy
## falloff with range: close shots mostly land, 30 m shots mostly miss) ◇.
@export var ai_aim_error_m: float = 0.15
@export var ai_aim_error_per_m: float = 0.025
## Enemies farther than this are ignored (m) ◇.
@export var ai_engage_range_m: float = 30.0

@export_group("Net")
@export var intent_send_hz: float = 30.0
@export var max_client_speed_slack: float = 1.35
@export var teleport_reject_m: float = 4.0

@export_group("Presentation (QB-47)")
## First-person weapon visual offset under the local human's camera (m, camera space).
@export var viewmodel_offset: Vector3 = Vector3(0.18, -0.2, -0.4)
## D-069: first-person camera near plane (m); 0.05 cut shouldered stocks in ADS.
@export var camera_near_m: float = 0.02
## B5-01: ADS zoom blend rate (1/s); the zoomed FOV = GameSettings.fov() / WeaponStats.magnification.
@export var ads_zoom_rate: float = 8.0
## Capsule placeholder only: `Visual/Head/Socket` offset from the crew origin (assembled characters
## carry their own `Head/Socket`, characters.md v1.2).
@export var placeholder_head_socket: Vector3 = Vector3(0.0, 1.62, -0.3)
## D-073: third-person body per Loadout.heister (B gives every launch slot one); no entry (generic crew) = the
## capsule placeholder.
@export var body_scenes: Dictionary[StringName, PackedScene] = {}
