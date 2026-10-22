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
## PO6-16 ◇ (D-114 §5 horde pacing, L1.1 SUSTAIN / L1.4 groups; PD2 group AI re-spawns whenever the force is
## under the task's force): while alive police < police_budget() in BUILD / SUSTAIN, the next group comes after
## this interval instead (same / (intensity x stage x drama) scaling), so losses are replaced within seconds
## and the force stays near its cap. 0 = off (assault_group_interval_s always).
@export var assault_refill_interval_s: float = 1.5
@export var assault_groups: Array[SpawnGroupDef] = []
## Spawning with no valid point is retried after this delay.
@export var no_point_retry_s: float = 1.0

@export_group("Assault force (L1.1/L1.3, PO-5.4)")
## Alive police the director fills to (AssaultDirector.force_cap) = DifficultyDef.enemy_cap (the
## full-crew number) x force_crew_mult[force crew - 1] x stage_force_mult[stage], at least force_min,
## never above enemy_cap. PD2 besiege.assault.force_balance_mul {1, 2, 3, 4} (Normal..Overkill)
## normalised to 4 crew; Mayhem+ scaling lives in the larger enemy_cap of those difficulties.
@export var force_crew_mult: PackedFloat32Array = PackedFloat32Array([0.25, 0.5, 0.75, 1.0])
## PD2 GroupAIStateBase:_get_balancing_multiplier: the force crew count is the humans plus
## max(1, floor(bots / 2)) when any AI teammate is present (bots count half). Crew in custody
## do not count (PD2: criminals with a status) (◇: downed crew still count, so the cap does not
## flicker while a teammate is revived).
@export var bots_count_half: bool = true
## ◇ L1.3 "wave 1 = 50%, wave 2 = 75%, wave 3+ = 100%" applied to the alive force by stage index.
@export var stage_force_mult: PackedFloat32Array = PackedFloat32Array([0.5, 0.75, 1.0])
## ◇ Lower bound of force_cap (a solo crew still meets an assault).
@export var force_min: int = 4
## Per-assault spawn budget (PD2 besiege.assault.force_pool {150, 175, 225} at the 50/75/100% stage
## points 175/200/225, divided by PD2's full-stage force 17): AssaultDirector._force_pool() =
## ceil(full-stage force_cap x force_pool_per_force[stage]). Spending it ends BUILD/SUSTAIN in FADE
## (PD2 task_spawn_allowance <= 0 -> "fade"). 0 or empty = unlimited.
@export var force_pool_per_force: PackedFloat32Array = PackedFloat32Array([10.3, 11.8, 13.2])
## FADE retreat (L1.1; PD2 "retire" objective): every alive police unit with a PoliceBrain is ordered
## to the nearest spawn point and leaves the map once within retreat_arrive_m of it and out of every
## crew member's LOS. Units still on the map when CONTROL starts are released to fight again.
@export var fade_retreat: bool = true
@export var retreat_arrive_m: float = 2.5
## D-099: loud-phase body cleanup (PD2 removes corpses during assaults). A corpse (G.BODY, not bagged) dead for
## body_despawn_delay_s and out of every crew member's sight is removed; checked every body_despawn_check_s.
## Stealth bodies stay (they are detection stimuli). 0 delay = off.
@export var body_despawn_delay_s: float = 30.0
@export var body_despawn_check_s: float = 2.0

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
## PD2: specials come mostly WITH the assault (its spawn groups carry the shields, tasers, cloakers, dozers). Each
## BUILD/SUSTAIN pick adds, with this chance by stage, the specials of one special-carrying assault group in front of
## the plain squad (added, not swapped: the force refills at the same rate; skipped when no special can spawn).
@export var assault_special_share: PackedFloat32Array = PackedFloat32Array([0.35, 0.45, 0.55])
## CONTROL between waves (wave >= 2): every control_special_interval_s, with control_special_chance,
## one group from control_special_groups (weights by difficulty x stage; Phantoms weigh more).
@export var control_special_groups: Array[SpawnGroupDef] = []
@export var control_special_interval_s: float = 20.0
@export var control_special_chance: float = 0.5

@export_group("Low difficulties (D-145 §2, PO-17)")
## ◇ PO-17: multipliers per Enums.Difficulty (ROUTINE..CATACLYSM) that bring Routine near PD2 Normal and Tense near PD2
## Hard; Hazardous and up stay 1.0 (unchanged). Read through by_difficulty() (missing entries = 1.0).
## x the per-assault force pool (AssaultDirector._force_pool): shorter assaults on the low tiers.
@export var force_pool_difficulty_mult: PackedFloat32Array = PackedFloat32Array([0.6, 0.8, 1.0, 1.0, 1.0, 1.0])
## x assault_refill_interval_s (the PO6-16 top-up cadence, also the at-cap re-check): losses are replaced
## more slowly on the low tiers.
@export var refill_interval_difficulty_mult: PackedFloat32Array = PackedFloat32Array([2.0, 1.5, 1.0, 1.0, 1.0, 1.0])
## x assault_special_share[stage]: fewer specials riding with the assault squads on the low tiers.
@export var special_share_difficulty_mult: PackedFloat32Array = PackedFloat32Array([0.35, 0.6, 1.0, 1.0, 1.0, 1.0])

@export_group("Early armor (D-145 §3, PO-18)")
## Below this Enums.Difficulty (HAZARDOUS = PD2 Very Hard) no unit the director spawns has damage-reducing body
## armor (EnemyRoster.has_body_armor: a frontal plate, armor_body_mult < 1, or plates). EnemyRoster.resolve remaps an
## armored id to its armored_substitutes entry (TAC Heavy -> TAC Light, so breach / heli squads keep their size) and
## skips one without a substitute (Wreckers). Bulwark shields are not body armor (D-099: Routine has shields).
@export var armored_min_difficulty: int = 2
@export var armored_substitutes: Dictionary[StringName, StringName] = {&"enemy.tac_heavy": &"enemy.tac_light"}

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


## Entry `difficulty` of a per-difficulty multiplier array (clamped to its size), `fallback` when it is empty.
static func by_difficulty(arr: PackedFloat32Array, difficulty: int, fallback: float = 1.0) -> float:
	if arr.is_empty():
		return fallback
	return arr[clampi(difficulty, 0, arr.size() - 1)]
