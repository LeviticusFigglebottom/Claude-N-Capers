## Special enemy behaviour tunables (A3-01a): Phantom (L4.3), Stinger (L4.4), Longshot (L4.7).
## Owner: ENV A. Data: special_tweak.tres. Health / damage per difficulty live in the EnemyDefs
## (systems/ai/data/enemies/<id>.tres). ◇ = design values.
class_name SpecialTweak
extends Resource

const PATH: String = "res://systems/ai/specials/special_tweak.tres"

static var _cached: SpecialTweak = null

# --- Shared ------------------------------------------------------------------------------------
@export var retarget_s: Vector2 = Vector2(0.5, 1.0)
@export var arrive_m: float = 0.8
@export var fallback_run_speed: float = 4.0

# --- Phantom (L4.3) -----------------------------------------------------------------------------
## cue.phantom_hum is re-requested every interval while the Phantom is active (3D, 25 m in C's def).
@export var phantom_hum_interval_s: float = 2.0
## Starts a charge when the target is this close (flat m) with LOS and the kick is off cooldown.
@export var phantom_charge_range_m: float = 10.0
## Windup (goggles glow, cue.phantom_charge): the charge direction is committed at its start.
@export var phantom_windup_s: float = 0.5
@export var phantom_charge_speed: float = 7.5
## Kick lands when the victim is within this flat distance at the end of the charge...
@export var phantom_kick_range_m: float = 1.6
## ...and no further than this from the committed charge line (a sidestep dodges, L4.3).
@export var phantom_dodge_lateral_m: float = 1.2
## The charge runs this far past the committed point at most, and ends after the timeout.
@export var phantom_charge_overshoot_m: float = 1.0
@export var phantom_charge_timeout_s: float = 3.0
## Kick cooldown (hit or miss), PD2 ~10 s.
@export var phantom_kick_cooldown_s: float = 10.0
## After a kick the Phantom may stay over the body ("camp") for this long.
@export var phantom_camp_chance: float = 0.5
@export var phantom_camp_s: float = 4.0
## Goggle emission energy (normal / charging). C's shader reads instance parameter `glow` (0..1).
@export var phantom_goggle_energy_idle: float = 0.6
@export var phantom_goggle_energy_charge: float = 6.0
## "Play dead" (◇ 15%): chance per non-lethal hit to drop, then get up after the range (s).
@export var phantom_play_dead_chance: float = 0.15
@export var phantom_play_dead_s: Vector2 = Vector2(4.0, 8.0)
@export var phantom_play_dead_max: int = 1
## Flank: on activation, first run to a FLANK point near the target (vent nav layer allowed).
@export var phantom_flank_chance: float = 0.6
@export var phantom_flank_max_from_target_m: float = 25.0
@export var phantom_flank_timeout_s: float = 10.0
## Without a kickable target (last player standing) the Phantom keeps this standoff.
@export var phantom_standoff_m: float = 6.0
## Counterstrike (defense.cloaker_counter + melee held at the kick): the Phantom is knocked down.
@export var phantom_counter_knockdown_s: float = 3.0

# --- Stinger (L4.4) -----------------------------------------------------------------------------
## Tase beam range (flat m, ◇ 15 m); the windup starts within it with LOS.
@export var stinger_tase_range_m: float = 15.0
## The beam breaks if the victim gets further than this (or LOS is lost).
@export var stinger_break_range_m: float = 18.0
## Audible windup (cue.stinger_windup, 1 s ramp).
@export var stinger_windup_s: float = 1.0
## cue.stinger_arc re-requested every interval while tasing.
@export var stinger_arc_interval_s: float = 0.5
## Long tase: after this the beam ends and the victim stays helpless (TASED) until revived (◇ 6 s).
@export var stinger_helpless_after_s: float = 6.0
## Cooldown between tases (s).
@export var stinger_tase_cooldown_s: float = 4.0
## Involuntary fire while tased: spread multiplier and upward pull (deg).
@export var stinger_spread_mult: float = 3.0
@export var stinger_pitch_up_deg: float = 15.0
## Approach to this fraction of the tase range before holding.
@export var stinger_hold_frac: float = 0.7
## Shockproof backfire / counter: the Stinger is knocked back (stunned) this long.
@export var stinger_knockback_s: float = 2.0

# --- Longshot (L4.7) ----------------------------------------------------------------------------
## A Longshot spawned within this of a SNIPER_PERCH counts as perched (else it is moved to one).
@export var longshot_perch_snap_m: float = 1.5
## Aim lock with a tracking laser before each shot (◇ 1.2 s).
@export var longshot_aim_lock_s: float = 1.2
## Seconds between shots (after the report, a new aim lock starts).
@export var longshot_fire_interval_s: float = 2.5
## Max engagement range (S2.7 caps loud targeting at 80-180 m by DR; ◇ 150 m).
@export var longshot_range_m: float = 150.0
## L4.7: damage halved beyond this distance, except on the top difficulty.
@export var longshot_falloff_m: float = 30.0
@export var longshot_falloff_mult: float = 0.5
## Losing LOS for longer than this drops the aim lock.
@export var longshot_los_grace_s: float = 0.25


static func data() -> SpecialTweak:
	if _cached == null:
		_cached = load(PATH) as SpecialTweak
		if _cached == null:
			_cached = SpecialTweak.new()
	return _cached
