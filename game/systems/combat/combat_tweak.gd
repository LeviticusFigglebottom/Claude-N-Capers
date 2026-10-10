## Combat tunables (A1-08): player weapons, hit-claim validation, NPC gunfire, revive extras.
## Owner: ENV A. Data: combat_tweak.tres. Survival numbers (health, armor, bleedout, downs, revive
## time) live in CrewTweak (crew_tweak.tres); weapon stats come from ENV B's resolved WeaponStats.
## Fidelity rows: L2.2, L2.5, L2.7, L3.2, L3.7, L3.8, S1.1, S4.3. ◇ = design value, tune in playtest.
class_name CombatTweak
extends Resource

const PATH: String = "res://systems/combat/combat_tweak.tres"

static var _cached: CombatTweak = null

@export_group("Default loadout (D-025 QA-2)")
## Used when a crew member has no Loadout (no `options.loadouts`). Resolved by LoadoutResolver.
@export var default_primary: StringName = &""
@export var default_primary_mods: Array[StringName] = []
@export var default_secondary: StringName = &"weapon.kestrel_p9"
@export var default_secondary_mods: Array[StringName] = [&"mod.p9_suppressor"]
@export var default_armor: StringName = &"armor.tailored_suit"

@export_group("Hitscan")
@export var hitscan_max_range_m: float = 200.0
## world_static(1) + world_dynamic(2) + hitboxes(5).
@export_flags_3d_physics var hitscan_mask: int = (1 << 0) | (1 << 1) | (1 << 4)
## Rays that must be clear between shooter and hit point (server LOS check, NPC LOS).
@export_flags_3d_physics var los_mask: int = (1 << 0) | (1 << 1)
## Spread multipliers on the WeaponStats cone (PD2 standing/moving/crouching shape, ◇).
@export var spread_mult_still: float = 0.5
@export var spread_mult_moving: float = 1.0
@export var spread_mult_crouched: float = 0.75
## Horizontal speed (m/s) above which the shooter counts as moving.
@export var moving_speed_threshold: float = 0.5

@export_group("Hit claims (architecture.md §3)")
## A claim is accepted when the time since the last accepted shot >= interval x this.
@export var claim_rof_tolerance: float = 0.75
## Max distance between the claimed ray origin and the server's view of the shooter's eye.
@export var claim_origin_tolerance_m: float = 2.0
## Max distance between the claimed hit point and the target's centre.
@export var claim_target_tolerance_m: float = 1.6
## Max mismatch between the claimed and recomputed distance.
@export var claim_distance_tolerance_m: float = 1.0

@export_group("Downed / revive (L2.5, L2.7)")
## A downed crew member counts as "shooting" for this long after a shot (police hold fire otherwise).
@export var downed_shooting_grace_s: float = 2.0
## Armor fraction restored on revive (◇).
@export var revive_armor_frac: float = 1.0

@export_group("NPC gunfire")
## Seconds between NPC shots unless EnemyDef.params.fire_interval_s is set (◇).
@export var npc_fire_interval_s: float = 0.8
## Delay before the first shot after acquiring a target (EnemyDef.params.aim_delay_s overrides, ◇).
@export var npc_aim_delay_s: float = 0.6
@export var npc_max_range_m: float = 60.0
## Point on the crew member NPCs aim at (height above the feet).
@export var npc_aim_height_m: float = 1.2
## Hit chance by distance (x = metres, y = chance 0..1), linear between points (◇ curve).
@export var npc_hit_chance_curve: PackedVector2Array = PackedVector2Array([
	Vector2(0.0, 0.9), Vector2(5.0, 0.8), Vector2(15.0, 0.6), Vector2(30.0, 0.35), Vector2(60.0, 0.1),
])
## Hit-chance multiplier by Enums.Difficulty (◇).
@export var npc_hit_chance_mult: PackedFloat32Array = PackedFloat32Array([1.0, 1.0, 1.05, 1.1, 1.15, 1.2])
## Damage per shot when an NPC has no EnemyDef damage table.
@export var npc_fallback_damage: float = 10.0


static func data() -> CombatTweak:
	if _cached == null:
		_cached = load(PATH) as CombatTweak
		if _cached == null:
			_cached = CombatTweak.new()
	return _cached


## Linear interpolation of the NPC hit-chance curve at `distance`.
func npc_hit_chance(distance: float, difficulty: int) -> float:
	var c: PackedVector2Array = npc_hit_chance_curve
	var chance: float = 0.0
	if c.is_empty():
		chance = 0.5
	elif distance <= c[0].x:
		chance = c[0].y
	elif distance >= c[c.size() - 1].x:
		chance = c[c.size() - 1].y
	else:
		for i: int in range(1, c.size()):
			if distance <= c[i].x:
				var t: float = (distance - c[i - 1].x) / maxf(c[i].x - c[i - 1].x, 0.0001)
				chance = lerpf(c[i - 1].y, c[i].y, t)
				break
	if npc_hit_chance_mult.size() > 0:
		chance *= npc_hit_chance_mult[clampi(difficulty, 0, npc_hit_chance_mult.size() - 1)]
	return clampf(chance, 0.0, 1.0)
