## Interaction framework tunables (S9.1-S9.3, S10.3, S6.2, S7.2). Owner: ENV A.
class_name InteractionTweak
extends Resource

## Server aim resolution: ray length and assist cone (crew_intent.md).
@export var reach_m: float = 2.0
@export var assist_cone_deg: float = 10.0
## Explicit-target interactions (bots/AI) allow a slightly longer reach.
@export var explicit_reach_m: float = 2.5
## S9.1: moving further than this from the start position cancels.
@export var cancel_move_m: float = 0.5
## S9.1: looking away more than this (aimed interactions only) cancels.
@export var cancel_look_deg: float = 40.0

@export_group("Default durations (s)")
@export var lockpick_door_s: float = 8.0
@export var keycard_s: float = 1.0
@export var drill_place_s: float = 3.0
@export var drill_fix_s: float = 2.0
@export var body_bag_s: float = 3.0
@export var cable_tie_s: float = 2.0
@export var small_loot_s: float = 0.75
@export var bag_loot_s: float = 1.0
@export var pager_answer_s: float = 10.0
@export var item_pickup_s: float = 0.5
@export var door_open_s: float = 0.0
@export var revive_s: float = 6.0
## A1-03 prefab defaults (◇ unless cited).
@export var keypad_s: float = 2.0
@export var read_note_s: float = 1.0
@export var camera_loop_s: float = 5.0
@export var display_case_open_s: float = 2.0
@export var window_open_s: float = 1.0
@export var zipline_attach_s: float = 1.0
@export var safe_open_s: float = 1.0

@export_group("Devices (S9.3, S9.4)")
@export var drill_duration_s: float = 180.0
@export var thermal_duration_s: float = 360.0
@export var saw_duration_s: float = 180.0

@export_group("Doors")
## Leaf rotation when open (degrees).
@export var door_open_angle_deg: float = 90.0

@export_group("Noise radii (S4.3)")
## noise profile id -> radius in m. "silent" = 0.
@export var noise_profiles: Dictionary = {&"silent": 0.0, &"quiet": 5.0, &"loud": 25.0}

@export_group("Device jams (S9.3)")
## Jams rolled at placement: randi_range(min, max) candidates, each kept with probability
## clamp(interaction.device_jam_chance_mult, 0, 1), placed uniformly in this progress range.
@export var device_jams_min: int = 1
@export var device_jams_max: int = 3
@export var device_jam_progress_range: Vector2 = Vector2(0.15, 0.9)
## Auto-restart delay range (s) after a jam when the restart roll succeeds.
@export var device_restart_delay_s: Vector2 = Vector2(5.0, 10.0)
## Seconds between NoiseEvents of a running device in stealth (S4.3).
@export var device_noise_interval_s: float = 2.0
## Safe drill time by Safe.Size (SMALL, MEDIUM, LARGE) ◇.
@export var safe_drill_duration_s: PackedFloat32Array = PackedFloat32Array([60.0, 120.0, 180.0])
## Safe door swing when opened (degrees).
@export var safe_door_open_deg: float = 100.0

@export_group("Glass (S9.9)")
## Hold time to smash a display case / window by hand (0 = instant) ◇.
@export var glass_break_s: float = 0.0
## How far an openable window sash slides up (m).
@export var window_sash_open_m: float = 0.6

@export_group("Safes, saws, C4, time locks (A2-04: S9.4, S9.8)")
## S9.8 ◇ hold to lockpick a SMALL safe (× interaction.lockpick_speed_mult; needs
## interaction.can_lockpick_safes).
@export var safe_lockpick_s: float = 10.0
## S9.4 saw run time on a safe by Safe.Size (SMALL, MEDIUM, LARGE): "same as drills" ◇.
@export var safe_saw_duration_s: PackedFloat32Array = PackedFloat32Array([60.0, 120.0, 180.0])
## ◇ C4 on a safe: hold to place, fuse, explosion noise radius (S4.3 explosion).
@export var c4_place_s: float = 2.0
@export var c4_fuse_s: float = 5.0
@export var c4_noise_radius_m: float = 45.0
## ◇ C4 blast on a safe (L3.6, `Explosion.apply` at the lock): radius (m) and centre damage (PD2
## display units, falloff (1 - d/r)^0.1). Crew-placed, so it never hurts the crew (no friendly fire).
@export var c4_blast_radius_m: float = 3.0
@export var c4_blast_damage: float = 300.0
## S9.8 ◇ vault time lock: hold to start the timer at the panel once the lock is beaten.
@export var time_lock_start_s: float = 2.0

@export_group("Hand saw targets (QC-37, D-057 G.SAW_TARGET)")
## Seconds of cutting with the handheld saw weapon (SpecialWeapons saw ticks call saw_cut) until each
## prefab opens (◇; Night Deposit doc: deposit boxes 6 s).
@export var hand_saw_deposit_box_s: float = 6.0
@export var hand_saw_padlock_s: float = 2.0
## Safes with &"saw" in `methods`, by Safe.Size (SMALL, MEDIUM, LARGE).
@export var hand_saw_safe_s: PackedFloat32Array = PackedFloat32Array([20.0, 40.0, 80.0])
## A SAW drill_point (cage gate, depository) cut by hand: x its device run time.
@export var hand_saw_drill_point_mult: float = 1.0

@export_group("Lasers, zipline, ladder (A2-04: S9.10, S9.11)")
## Thickness of a laser beam's detection box across the beam (m) ◇.
@export var laser_beam_thickness_m: float = 0.03
## Bag zipline travel speed (m/s) ◇.
@export var zipline_speed_mps: float = 6.0
## Ladder climb speed (m/s) ◇ and how close to the Bottom/Top marker a crew member must stand (m).
@export var ladder_climb_speed_mps: float = 2.0
@export var ladder_grab_radius_m: float = 0.7
## Moving forward into a ladder (instead of holding interact) starts a climb when the crew faces it
## within this angle (degrees) ◇.
@export var ladder_forward_cone_deg: float = 60.0

@export_group("NPC doors (A2-01, D-032 QA-11)")
## Delay before a closed door an NPC / AI teammate is passing through opens (s): the stealth door
## animation (0.6 s, QA-11) and instantly in loud.
@export var npc_door_open_stealth_s: float = 0.6
@export var npc_door_open_loud_s: float = 0.0
## NpcMotor looks this far ahead along its path for closed doors (m), every check interval (s).
@export var npc_door_lookahead_m: float = 4.0
@export var npc_door_check_interval_s: float = 0.1
## Distance from the doorway plane at which an NPC stops and opens (or is blocked by) a door (m).
@export var npc_door_reach_m: float = 0.9
## ◇ A locked door opened by an authorised guard (keycard post) closes again after this (s); 0 = stays open.
@export var npc_locked_door_close_s: float = 4.0
## Half length of the door's NavigationLink3D through the doorway (m, each side of the leaf).
@export var door_nav_link_half_m: float = 0.6

@export_group("Bag lift, hack terminal (A3-09: QC-11, QC-12)")
## ◇ Hold at a bag_lift landing panel to send / call the car (s).
@export var bag_lift_send_s: float = 1.0
## ◇ Car door slide (m per leaf, along the car's X) when open, for every lift without its own
## `door_open_m`. 0 = from the car: car_size_m.x / 2 - bag_lift_door_margin_m (0.45 m for 1.2 m).
@export var bag_lift_door_open_m: float = 0.0
## ◇ Door edge left covering the opening at full slide (m).
@export var bag_lift_door_margin_m: float = 0.15
## ◇ `door_fold` lifts: open leaves shrink to this fraction of their width (outer edge fixed).
@export var bag_lift_door_fold_scale: float = 0.2
## ◇ Shaft: a loose bag this far below the car floor inside the car's column has fallen in (m); it
## goes back bag_lift_return_front_m in front of the car at its landing. Column depth below the
## lowest landing (m) and check interval (s).
@export var bag_lift_fall_m: float = 0.5
@export var bag_lift_return_front_m: float = 0.6
@export var bag_lift_pit_depth_m: float = 4.0
@export var bag_lift_shaft_check_s: float = 0.2
## ◇ hack_terminal: hold to start the hack / to restart it after an interruption (s).
@export var hack_start_s: float = 2.0
@export var hack_restart_s: float = 2.0
## Night Deposit server hack: 3 × 20 s = 60 s run time (s), interruptions rolled in [x, y] (D-040).
@export var hack_duration_s: float = 60.0
@export var hack_interruptions: Vector2i = Vector2i(2, 2)
## Interruption k of n sits at progress (k + 1) / (n + 1) ± this fraction of one segment (GameRng
## &"devices"), so the run splits into n + 1 roughly equal parts (3 × 20 s for n = 2).
@export var hack_interruption_jitter: float = 0.25
