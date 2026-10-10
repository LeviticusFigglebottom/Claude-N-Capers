## AssaultDirector tunables (L1.1 phases, L1.4 spawning). Owner: ENV A. Data: director_tweak.tres.
## ◇ = design value (PD2-shaped). A3-03 adds drama (L1.2), escalation (L1.3), factions (L1.5) and
## special caps (L4.11); A3-02 adds Commander Brandt + Aegis squad (L4.9).
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
## ... or drama < drama_fade_level for drama_fade_window_s (L1.2) ... or, as a hard safety cap,
## this many seconds past the sustain timer (◇; never while Brandt locks the assault).
@export var fade_wait_cap_s: float = 60.0
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

@export_group("Drama (L1.2)")
## Drama 0..1 decays this much per second.
@export var drama_decay_per_s: float = 0.05
## Drama per display unit of damage a crew member takes (armor + health) (◇).
@export var drama_per_damage: float = 0.003
## Drama when a crew member goes down (◇).
@export var drama_per_down: float = 0.25
## Drama per shot fired (by anyone) within drama_combat_radius_m of a non-custody crew member (◇).
@export var drama_per_nearby_shot: float = 0.003
## Drama per kill within drama_combat_radius_m of a non-custody crew member (◇).
@export var drama_per_nearby_kill: float = 0.02
@export var drama_combat_radius_m: float = 15.0
## BUILD/SUSTAIN spawn rate x (1 - drama_spawn_scale * drama).
@export var drama_spawn_scale: float = 0.5
## After the sustain timer: FADE once drama stayed below drama_fade_level for drama_fade_window_s.
@export var drama_fade_level: float = 0.2
@export var drama_fade_window_s: float = 30.0

@export_group("Escalation (L1.3)")
## BUILD/SUSTAIN spawn rate multiplier by stage index (◇; "later waves -> more units").
@export var stage_spawn_rate_mult: PackedFloat32Array = PackedFloat32Array([1.0, 1.15, 1.3])
## CONTROL between waves (wave >= 2): every control_special_interval_s, with control_special_chance,
## one group from control_special_groups (weights by difficulty x stage; Phantoms weigh more).
@export var control_special_groups: Array[SpawnGroupDef] = []
@export var control_special_interval_s: float = 20.0
@export var control_special_chance: float = 0.5

@export_group("Factions (L1.5)")
## Faction id per Enums.Difficulty (ROUTINE..CATACLYSM). The faction remaps every role id to
## systems/ai/data/enemies/<faction suffix>/<role>.tres when that file exists (groups.md: reskins
## keep the role id), and filters SpawnGroupDef.factions.
@export var faction_by_difficulty: Array[StringName] = [
	&"faction.tac", &"faction.tac", &"faction.frd", &"faction.frd", &"faction.sentinel", &"faction.zero"]

@export_group("Special caps (L4.11)")
## Ids whose variants share one DifficultyDef.special_limits key (D-022: every enemy.wrecker_*).
@export var shared_limit_prefixes: Array[StringName] = [&"enemy.wrecker"]
## Limit for a special whose key is missing from special_limits (-1 = unlimited; Longshots are
## limited by free SNIPER_PERCH points instead).
@export var special_limit_default: int = -1

@export_group("Commander Brandt + Aegis (L4.9)")
## Minimum Enums.Difficulty (PD2 Very Hard+ = HAZARDOUS). D-015: also in solo.
@export var captain_min_difficulty: int = 2
## First assault wave the captain may join, and the chance per eligible wave (rolled at BUILD).
@export var captain_min_wave: int = 2
@export var captain_chance: float = 0.5
## Seconds after BUILD starts before he arrives (if a valid spawn point exists).
@export var captain_delay_s: float = 20.0
@export var captain_def: EnemyDef
## Aegis shields: enemy.bulwark when its EnemyDef exists (flagged aegis), else this placeholder.
@export var aegis_def: EnemyDef
@export var aegis_shields: int = 10
@export var aegis_spread_m: float = 1.4
## Without a defensive destination he counts as "in position" this long after arriving (◇).
@export var captain_settle_s: float = 2.0
## Destination (L4.9 "in position"): a TacticalPoint tagged captain_position_tag (nearest the crew
## centroid), else the COVER / SHIELD_ANCHOR point whose distance to the crew centroid is in
## [min, max] and closest to pref (m). The squad moves there in formation; resistance starts when
## Brandt is within captain_position_arrive_m of it, or after captain_position_timeout_s (fallback).
@export var captain_position_tag: StringName = &"captain_position"
@export var captain_position_min_m: float = 8.0
@export var captain_position_pref_m: float = 15.0
@export var captain_position_max_m: float = 35.0
@export var captain_position_arrive_m: float = 1.5
@export var captain_position_timeout_s: float = 30.0
## Damage resistance for every enemy while he is in position: base, +step every step_s, up to max.
@export var aegis_resist_base: float = 0.10
@export var aegis_resist_step: float = 0.05
@export var aegis_resist_step_s: float = 5.0
@export var aegis_resist_max: float = 0.50
## Brandt and his shields take at most this fraction of max HP per hit (x explosive mult).
@export var captain_hit_cap_frac: float = 0.10
@export var captain_explosive_cap_mult: float = 6.0
## Retreat at this HP fraction, or when this many shields (or fewer) remain.
@export var captain_retreat_hp_frac: float = 0.20
@export var captain_retreat_shields: int = 3
## Brandt leaves the map this long after retreating (◇); remaining shields break up into normal units.
@export var captain_despawn_s: float = 4.0
