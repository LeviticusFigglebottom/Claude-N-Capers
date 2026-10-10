## Behaviour tunables for the PoliceBrain-based specials (A3-01b): Bulwark (L4.5), Wrecker (L4.6),
## Corpsman (L4.8). Owner: ENV A. Data: heavy_special_tweak.tres. Health / damage / plates per
## difficulty live in the EnemyDefs (systems/ai/data/enemies/*.tres). ◇ = design values.
class_name HeavySpecialTweak
extends Resource

const PATH: String = "res://systems/ai/specials/heavy_special_tweak.tres"

static var _cached: HeavySpecialTweak = null

@export_group("Bulwark (L4.5)")
@export var bulwark_shield_scene: PackedScene
## Shield position in the Bulwark's local space (in front of the body, -Z forward).
@export var bulwark_shield_offset: Vector3 = Vector3(0.0, 0.95, -0.6)
## Standoff band toward the fixated target (◇: shields push in close).
@export var bulwark_standoff_min_m: float = 3.0
@export var bulwark_standoff_pref_m: float = 5.0
@export var bulwark_standoff_max_m: float = 8.0
## A free SHIELD_ANCHOR TacticalPoint (doorway / chokepoint) within this distance with LOS to the
## target is held instead of the standoff ("blocks doorways").
@export var bulwark_anchor_search_m: float = 25.0
@export var bulwark_anchor_max_from_target_m: float = 25.0
## Shield bang while holding with the target in sight: every interval (s, range), holding fire for
## bang_hold_s (cue.bulwark_bang, anim shield_bang).
@export var bulwark_bang_interval_s: Vector2 = Vector2(6.0, 10.0)
@export var bulwark_bang_hold_s: float = 0.8

@export_group("Shield formation (L4.5 shield_anchor)")
## Other specials within this distance of an allied, alive Bulwark take the spot behind it.
@export var formation_join_m: float = 12.0
## Distance behind the Bulwark (away from its target) and sideways spacing per follower.
@export var formation_behind_m: float = 1.6
@export var formation_side_m: float = 0.8

@export_group("Wrecker (L4.6)")
@export var wrecker_standoff_min_m: float = 1.5
@export var wrecker_standoff_pref_m: float = 3.0
@export var wrecker_standoff_max_m: float = 5.0
## cue.wrecker_step while moving (heavy footstep loop, C's cue def: audible 30 m).
@export var wrecker_step_interval_s: float = 0.55
@export var wrecker_moving_speed_m_s: float = 0.5
## Weak-point hitboxes in front of the head (local to the head point): Faceplate outermost, Visor
## behind it, then the head sphere.
@export var wrecker_faceplate_size: Vector3 = Vector3(0.3, 0.3, 0.04)
@export var wrecker_faceplate_offset: Vector3 = Vector3(0.0, 0.0, -0.21)
@export var wrecker_visor_size: Vector3 = Vector3(0.28, 0.14, 0.04)
@export var wrecker_visor_offset: Vector3 = Vector3(0.0, 0.02, -0.17)

@export_group("Corpsman (L4.8)")
## Heals or revives ONE ally within this distance (through walls), then waits the cooldown.
@export var corpsman_radius_m: float = 7.0
@export var corpsman_cooldown_s: float = 3.0
## Medic and target can neither move nor shoot for this long while healing.
@export var corpsman_heal_lock_s: float = 1.0
## A ready Corpsman also heals a living ally below this health fraction (revives always apply).
@export var corpsman_heal_below_frac: float = 0.6
## Seconds the healed unit shows the green outline (presentation state).
@export var corpsman_outline_s: float = 1.5


static func data() -> HeavySpecialTweak:
	if _cached == null:
		_cached = load(PATH) as HeavySpecialTweak
		if _cached == null:
			_cached = HeavySpecialTweak.new()
	return _cached
