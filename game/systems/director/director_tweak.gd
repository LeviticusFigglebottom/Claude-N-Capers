## AssaultDirector tunables (L1.1 phases, L1.4 spawning). Owner: ENV A. Data: director_tweak.tres.
## ◇ = design value (PD2-shaped). Drama (L1.2) is P3 and has no numbers here yet.
class_name DirectorTweak
extends Resource

@export_group("Phases (L1.1)")
## First CONTROL after the alarm (first responders).
@export var first_control_s: float = 20.0
## CONTROL between waves (after FADE).
@export var control_between_waves_s: float = 40.0
@export var anticipation_s: float = 30.0
## Added once (not per hostage) when hostages > 0 during ANTICIPATION.
@export var anticipation_hostage_bonus_s: float = 30.0
@export var build_s: float = 35.0
## Sustain seconds by stage index (0 = 50%, 1 = 75%, 2 = 100%); PD2 sustain_duration {40, 120, 160}.
@export var sustain_by_stage_s: PackedFloat32Array = PackedFloat32Array([40.0, 120.0, 160.0])
## Sustain multiplier by crew count 1..4 (PD2 sustain_duration_balance_mul).
@export var sustain_crew_mult: PackedFloat32Array = PackedFloat32Array([1.0, 1.1, 1.2, 1.3])
## Stage index per wave (wave 1 -> 50%, wave 2 -> 75%, wave 3+ -> 100%; L1.3).
@export var wave_stage: PackedInt32Array = PackedInt32Array([0, 1, 2])
## After the sustain timer: FADE when alive police < fade_threshold[difficulty] ...
@export var fade_threshold: PackedInt32Array = PackedInt32Array([8, 10, 12, 14, 16, 18])
## ... or after this many seconds past the sustain timer (stands in for the P3 drama window).
@export var fade_wait_cap_s: float = 30.0
## FADE length (no spawning) before CONTROL starts again.
@export var fade_s: float = 15.0

@export_group("Spawning (L1.4)")
## A spawn point is valid only if every non-custody crew member is at least this far away...
@export var min_crew_distance_m: float = 15.0
## ... and has no LOS (eye -> point + this height).
@export var los_check_height_m: float = 1.6
## Units spawned one at a time from the queue (re-validated at spawn time).
@export var unit_spawn_interval_s: float = 0.5
## Lateral spread between units of one group at the same point.
@export var unit_spread_m: float = 0.9
## First CONTROL: group spawned first_responder_groups times, every interval.
@export var first_responder_group: SpawnGroupDef
@export var first_responder_groups: int = 2
@export var first_responder_interval_s: float = 6.0
## CONTROL between waves: a group every interval while fewer than control_alive_max police live.
@export var control_group_interval_s: float = 20.0
@export var control_alive_max: int = 4
## BUILD / SUSTAIN: a group every interval / DifficultyDef.assault_intensity, up to enemy_cap alive.
@export var assault_group_interval_s: float = 5.0
@export var assault_groups: Array[SpawnGroupDef] = []
## Spawning with no valid point is retried after this delay.
@export var no_point_retry_s: float = 1.0
