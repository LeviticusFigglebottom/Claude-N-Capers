## Crew (player character) tunables. Owner: ENV A. Data: crew_tweak.tres.
## Fidelity rows: S1.1, S1.2, S1.5, L2.1, L2.2, L2.5-L2.7, S10.1.
class_name CrewTweak
extends Resource

@export_group("Movement")
@export var walk_speed: float = 3.5
@export var sprint_speed: float = 5.75
@export var crouch_speed: float = 2.25
@export var jump_velocity: float = 4.6
@export var gravity: float = 9.8
@export var acceleration: float = 30.0
@export var air_control: float = 0.3
## Max yaw/pitch speed is unbounded: intents carry absolute angles.
@export var max_pitch_deg: float = 89.0

@export_group("Stamina (QB-60, PD2 movement_state.stamina)")
## Pool before movement.stamina_mult x team.stamina_mult x ArmorDef.stamina_mult.
@export var stamina_base: float = 50.0
@export var stamina_drain_per_s: float = 2.0
@export var stamina_regen_per_s: float = 3.0
## Regeneration starts this long after the last drain (s).
@export var stamina_regen_delay_s: float = 3.0
## Needed to jump, and to sprint again after running dry.
@export var stamina_min_threshold: float = 4.0
@export var stamina_jump_cost: float = 2.0

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
## Index by Enums.LootWeight.
@export var bag_speed_mult: PackedFloat32Array = PackedFloat32Array([0.95, 0.85, 0.75, 0.6])
@export var bag_can_sprint: Array[bool] = [true, true, false, false]
@export var bag_can_jump: Array[bool] = [true, false, false, false]
@export var bag_throw_distance_m: PackedFloat32Array = PackedFloat32Array([4.0, 3.5, 3.0, 2.0])

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
