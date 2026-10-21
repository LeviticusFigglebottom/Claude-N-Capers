## Custody, hostage trade, police cuffs, cop surrender and converts tunables (A3-04). Owner: ENV A.
## Data: custody_tweak.tres. Rows: L2.8-L2.10, L2.12, L5.1-L5.3, L1.6, S7.3. ◇ = design values.
class_name CustodyTweak
extends Resource

const PATH: String = "res://systems/combat/custody_tweak.tres"

static var _cached: CustodyTweak = null

@export_group("Custody (L2.9)")
## Auto-release time per Enums.Difficulty (ROUTINE..CATACLYSM); < 0 = trade only. PD2: 119 s on
## Normal/Hard (our Routine/Tense), trade-only above.
@export var auto_release_s: PackedFloat32Array = PackedFloat32Array([119.0, 119.0, -1.0, -1.0, -1.0, -1.0])
## Fraction of each weapon's full ammo (magazine + reserve) a released crew member gets back.
@export var release_ammo_frac: float = 0.5
## Release position: this far behind the free crew member it spawns next to (m) ◇.
@export var release_near_crew_offset_m: float = 1.5
## Seconds the "every human is in custody and no trade is possible" condition must hold before the
## heist fails (&"all_custody") ◇.
@export var all_custody_fail_delay_s: float = 1.0

@export_group("Trade (L2.10, S7.3, L1.6)")
## Negotiation: base + per civilian killed by that crew member (PD2: 5 s + 30 s per kill).
@export var trade_base_s: float = 5.0
@export var trade_per_civilian_kill_s: float = 30.0
## Enums.AssaultPhase values during which negotiation does not progress (L1.6) ◇.
@export var trade_locked_phases: Array[int] = [
	Enums.AssaultPhase.ANTICIPATION, Enums.AssaultPhase.BUILD, Enums.AssaultPhase.SUSTAIN,
]
## Hold time of the `trade_hostage` interaction on the highlighted hostage ◇.
@export var trade_interaction_s: float = 1.0

@export_group("Police cuffs (L2.12)")
## A police unit cuffs a downed, non-shooting crew member from this distance (flat m).
@export var police_cuff_range_m: float = 1.0
## Police only walk over to cuff a downed target this close (flat m) ◇.
@export var police_cuff_approach_m: float = 15.0
## Retired (L2.12, LEAD 2026-10-21): police cuffs have no self-free; a cuffed downed heister bleeds out unless a
## teammate uncuffs them. Kept so saved .tres files still load; nothing reads it.
@export var police_cuff_self_free_s: float = 60.0
## D-108: a downed crew member is cuffable only after this long down without firing (s ◇).
@export var police_cuff_grace_s: float = 2.0
## D-108: the cop's arrest hold at police_cuff_range_m (s ◇); the player firing or the cop being hurt / stunned
## interrupts it (restarts from zero).
@export var police_cuff_time_s: float = 1.5
## D-145 (P's GH Tense run: cuffed 3 s after the down): police cuff a downed player only from this difficulty
## (Enums.Difficulty) up. Below it the bleed-out timer alone decides custody, as for bots (D-082) ◇.
@export var police_cuff_min_difficulty: int = Enums.Difficulty.HAZARDOUS

@export_group("Cop surrender (L5.1)")
## false: any crew member's shout can make low-tier cops surrender (PD2 base game); true: only with
## `ability.intimidate_cops` ◇.
@export var surrender_requires_skill: bool = false
## Chance = base + hurt x (1 - hp%) + per_crew x crew within surrender_crew_radius_m (◇), clamped.
@export var surrender_base_chance: float = 0.2
@export var surrender_hurt_chance: float = 0.5
@export var surrender_per_crew_chance: float = 0.1
@export var surrender_crew_radius_m: float = 10.0
@export var surrender_max_chance: float = 0.95
## Shout reach vs police (m, x ability.shout_range_mult) and aim cone half angle (deg).
@export var surrender_shout_range_m: float = 12.0
@export var surrender_cone_half_deg: float = 20.0
## A surrendered cop nobody ties gets back up after this long (s, re-shout restarts it) ◇.
@export var surrender_duration_s: float = 30.0

@export_group("Converts (L5.2)")
## Convert interaction hold time (s, x ability.convert_speed_mult) ◇.
@export var convert_s: float = 2.0
## Converted ally AI: follow band around its owner (m), engage range (m), retarget interval (s).
@export var convert_follow_min_m: float = 2.0
@export var convert_follow_max_m: float = 6.0
@export var convert_engage_range_m: float = 35.0
@export var convert_retarget_s: float = 0.5
@export var convert_run_speed: float = 4.0
## Converted ally hit chance per shot (flat, GameRng &"convert_fire") ◇.
@export var convert_hit_chance: float = 0.6


static func data() -> CustodyTweak:
	if _cached == null:
		_cached = load(PATH) as CustodyTweak
		if _cached == null:
			_cached = CustodyTweak.new()
	return _cached


## Auto-release seconds for `difficulty` (< 0 = trade only).
func auto_release_for(difficulty: int) -> float:
	if auto_release_s.is_empty():
		return -1.0
	return auto_release_s[clampi(difficulty, 0, auto_release_s.size() - 1)]
