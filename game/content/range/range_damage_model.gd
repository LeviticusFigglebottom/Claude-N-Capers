## The firing-range dummies' damage rules (B4-13): the ONE function that turns a hit into damage
## for a range dummy. RangeTarget.take_hit applies hits through `apply()` on its own state, and the
## DPS/TTK readout simulates shots through the very same `apply()` on a scratch state, so the
## readout can never disagree with what the target does. Owner: ENV B.
##
## Armour comes from ENV A's EnemyDef through RangeDummyDef.armor() (= NpcHitRules.armor_of, D-052)
## and is applied with NpcHitRules / BulwarkShield / WreckerArmor semantics (systems/ai/README.md "Hit
## resolution order", docs/contracts/damage.md v1.1, D-027, pd2_fidelity L3.3-L3.6, L4.2, L4.5, L4.6):
## 1. EXPLOSION: x explosive_mult.
## 2. Shield (hit arrived through the dummy's shield hitbox): explosions go around it; FIRE passes at
##    x CombatTweak.shield_fire_damage_mult; a BULLET with `info.shield_pierce` passes at
##    x shield_pierce_mult; anything else is blocked (amount 0, `blocked`).
## 3. WEAKPOINT while plates remain (not explosions): the amount goes into the current plate's HP pool
##    (x1, no zone multiplier, no crit, excess lost); emptying it breaks the plate. With no plates
##    left WEAKPOINT counts x1 on health.
## 4. HEAD: x headshot_mult x info.headshot_bonus, except x1 while plates remain (armoured head).
##    BODY / LIMB BULLET without `info.pierced_armor`: x frontal_armor inside the frontal arc (0 =
##    blocked), else x armor_body_mult. Fire, explosions and melee ignore armour.
## 5. Crit (D-027): x headshot_mult on any zone, cleared on an armoured head.
## Health and plate pools live in a state Dictionary {health, plates: PackedFloat32Array, stage}.
class_name RangeDamageModel
extends RefCounted

## Readout simulation stops here (counts as "cannot kill").
const MAX_SIM_SHOTS: int = 20000

var health: float = 1.0
var headshot_mult: float = 1.0
## RangeDummyDef.armor() keys (canonical EnemyDef armour, D-052).
var armor_body_mult: float = 1.0
var frontal_armor: float = 1.0
var frontal_armor_arc_deg: float = 0.0
var explosive_mult: float = 1.0
var shield: bool = false
var shield_pierce_mult: float = 1.0
var plate_health: PackedFloat32Array = PackedFloat32Array()
## CombatTweak.shield_fire_damage_mult (FIRE through a shield).
var shield_fire_mult: float = 1.0


static func from_def(def: RangeDummyDef, difficulty: int) -> RangeDamageModel:
	var m: RangeDamageModel = RangeDamageModel.new()
	if def == null:
		return m
	m.health = def.health_for(difficulty)
	m.headshot_mult = def.headshot_mult_for(difficulty)
	var a: Dictionary = def.armor()
	m.armor_body_mult = float(a["armor_body_mult"])
	m.frontal_armor = float(a["frontal_armor"])
	m.frontal_armor_arc_deg = float(a["frontal_armor_arc_deg"])
	m.explosive_mult = float(a["explosive_mult"])
	m.shield = bool(a["shield"])
	m.shield_pierce_mult = float(a["shield_pierce_mult"])
	for v: Variant in a["plate_health"] as Array:
		m.plate_health.append(float(v))
	m.shield_fire_mult = CombatTweak.data().shield_fire_damage_mult
	return m


## True when the dummy has frontal armour (an arc).
func has_frontal_armor() -> bool:
	return frontal_armor_arc_deg > 0.0


func new_state() -> Dictionary:
	return {"health": health, "plates": plate_health.duplicate(), "stage": 0}


func plates_left(state: Dictionary) -> int:
	return maxi((state["plates"] as PackedFloat32Array).size() - int(state["stage"]), 0)


## Zone a shot aimed at the body (`head` false) or the head lands on from the front, given the
## state: through the shield the shield hitbox is hit (BODY); the face is the WEAKPOINT plate while
## one remains.
func aim_zone(state: Dictionary, head: bool) -> int:
	if shield or not head:
		return Enums.HitZone.BODY
	if plates_left(state) > 0:
		return Enums.HitZone.WEAKPOINT
	return Enums.HitZone.HEAD


## Apply one hit to `state` (mutated). `frontal`: the shot came from inside the frontal arc
## (RangeTarget.is_frontal). Returns {amount, killed, health_after, blocked, pierced_shield,
## pierced_armor, frontal_plate, armor_reduced, head_armored, plate_stage (-1 = none), plate_broken,
## plate_health_after}.
func apply(state: Dictionary, info: Dictionary, via_shield: bool, frontal: bool) -> Dictionary:
	var out: Dictionary = {
		"amount": 0.0, "killed": false, "health_after": float(state["health"]), "blocked": false,
		"pierced_shield": false, "pierced_armor": false, "frontal_plate": false, "armor_reduced": false,
		"head_armored": false, "plate_stage": -1, "plate_broken": false, "plate_health_after": 0.0,
	}
	var amount: float = maxf(float(info.get("amount", 0.0)), 0.0)
	var dtype: int = int(info.get("type", Enums.DamageType.BULLET))
	if dtype == Enums.DamageType.EXPLOSION:
		amount *= explosive_mult
	if via_shield and shield:
		amount = _through_shield(info, dtype, amount, out)
		if bool(out["blocked"]):
			return out
	var zone: int = int(info.get("zone", Enums.HitZone.BODY))
	var plated: bool = plates_left(state) > 0
	if zone == Enums.HitZone.WEAKPOINT and plated and dtype != Enums.DamageType.EXPLOSION:
		return _hit_plate(state, amount, out)
	var mult: float = 1.0
	if zone == Enums.HitZone.HEAD:
		out["head_armored"] = plated
		mult = (1.0 if plated else headshot_mult) * float(info.get("headshot_bonus", 1.0))
	else:
		mult = _armor_mult(info, dtype, zone, frontal, out)
	if bool(info.get("crit", false)) and not bool(out["head_armored"]):
		mult *= headshot_mult
	amount *= mult
	var h: float = maxf(float(state["health"]) - amount, 0.0)
	state["health"] = h
	out["amount"] = amount
	out["health_after"] = h
	out["killed"] = h <= RangeMath.EPS
	return out


## Shield rules (BulwarkShield): returns the amount that reaches the dummy; sets out.blocked.
func _through_shield(info: Dictionary, dtype: int, amount: float, out: Dictionary) -> float:
	if dtype == Enums.DamageType.EXPLOSION:
		return amount  # explosions go around shields
	if dtype == Enums.DamageType.FIRE:
		return amount * shield_fire_mult
	if dtype == Enums.DamageType.BULLET and bool(info.get("shield_pierce", false)):
		out["pierced_shield"] = true
		return amount * shield_pierce_mult
	out["blocked"] = true
	return 0.0


## The current plate soaks `amount` (x1, excess lost); emptying it breaks the plate.
func _hit_plate(state: Dictionary, amount: float, out: Dictionary) -> Dictionary:
	var plates: PackedFloat32Array = state["plates"]
	var stage: int = int(state["stage"])
	var hp: float = plates[stage]
	var dealt: float = minf(amount, hp)
	plates[stage] = hp - dealt
	state["plates"] = plates
	out["amount"] = dealt
	out["plate_stage"] = stage
	out["plate_health_after"] = plates[stage]
	if plates[stage] <= RangeMath.EPS:
		out["plate_broken"] = true
		state["stage"] = stage + 1
	return out


## Armour multiplier of a non-HEAD hit (NpcHitRules.pre_zone): BODY / LIMB BULLETs only.
func _armor_mult(info: Dictionary, dtype: int, zone: int, frontal: bool, out: Dictionary) -> float:
	if dtype != Enums.DamageType.BULLET or (zone != Enums.HitZone.BODY and zone != Enums.HitZone.LIMB):
		return 1.0
	var plate: bool = has_frontal_armor() and frontal
	if bool(info.get("pierced_armor", false)):
		out["pierced_armor"] = plate or armor_body_mult != 1.0
		return 1.0
	if plate:
		out["frontal_plate"] = true
		out["blocked"] = frontal_armor <= 0.0
		return frontal_armor
	out["armor_reduced"] = armor_body_mult != 1.0
	out["blocked"] = armor_body_mult <= 0.0
	return armor_body_mult


## The DamageInfo the readout assumes for one pellet of `s` at `distance_m` (what the attacker
## sends: body damage after falloff, the weapon headshot bonus, shield_pierce, and pierced_armor
## when the weapon always pierces (armor_pierce >= 1; chance-based AP is shown as not piercing).
static func readout_info(s: WeaponStats, distance_m: float, zone: int) -> Dictionary:
	var info: Dictionary = Damage.info(RangeMath.pellet_damage(s, distance_m), Enums.DamageType.BULLET, zone,
			&"", Vector3.ZERO, Vector3.FORWARD)
	info["headshot_bonus"] = s.headshot_mult
	info["shield_pierce"] = s.shield_pierce
	info["pierced_armor"] = s.armor_pierce >= 1.0 - RangeMath.EPS
	return info


## Shots of `s` from the front at `distance_m` until the dummy dies, aimed at the body or the head,
## every pellet hitting. {shots (0 = cannot kill), first_damage (final damage of the first shot,
## plate damage included)}.
func simulate(s: WeaponStats, distance_m: float, head: bool) -> Dictionary:
	var st: Dictionary = new_state()
	var first: float = -1.0
	var pellets: int = maxi(s.pellets, 1)
	for shot: int in range(1, MAX_SIM_SHOTS + 1):
		var dealt: float = 0.0
		for p: int in range(pellets):
			var r: Dictionary = apply(st, readout_info(s, distance_m, aim_zone(st, head)), shield, true)
			dealt += float(r["amount"])
			if bool(r["killed"]):
				break
		if first < 0.0:
			first = dealt
		if float(st["health"]) <= RangeMath.EPS:
			return {"shots": shot, "first_damage": first}
		if dealt <= 0.0:
			break
	return {"shots": 0, "first_damage": maxf(first, 0.0)}


## RangeMath.readout() against this dummy: shots/TTK/damage/DPS go through `apply()` (armor, shield,
## plates); falloff and timing come from RangeMath. Extra keys: body_blocked, head_blocked, plates.
func readout(s: WeaponStats, distance_m: float) -> Dictionary:
	var r: Dictionary = RangeMath.readout(s, health, headshot_mult, distance_m)
	var body: Dictionary = simulate(s, distance_m, false)
	var head: Dictionary = simulate(s, distance_m, true)
	var raw: float = RangeMath.shot_damage(s, distance_m)
	var ratio: float = float(body["first_damage"]) / raw if raw > 0.0 else 0.0
	r["body_damage"] = float(body["first_damage"])
	r["head_damage"] = float(head["first_damage"])
	r["shots_body"] = int(body["shots"])
	r["shots_head"] = int(head["shots"])
	r["ttk_body_s"] = RangeMath.time_to_kill_s(s, int(body["shots"]))
	r["ttk_head_s"] = RangeMath.time_to_kill_s(s, int(head["shots"]))
	r["dps"] = RangeMath.dps(s, distance_m) * ratio
	r["sustained_dps"] = RangeMath.sustained_dps(s, distance_m) * ratio
	r["body_blocked"] = int(body["shots"]) == 0
	r["head_blocked"] = int(head["shots"]) == 0
	r["plates"] = plate_health.size()
	return r
