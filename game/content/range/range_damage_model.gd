## The firing-range dummies' damage rules (B4-13): the ONE function that turns a hit into damage
## for a range dummy. RangeTarget.take_hit applies hits through `apply()` on its own state, and the
## DPS/TTK readout simulates shots through the very same `apply()` on a scratch state, so the
## readout can never disagree with what the target does. Owner: ENV B.
##
## Rules (docs/contracts/damage.md v1.0 + D-027, pd2_fidelity L3.3, L3.4, L4.2, L4.5, L4.6):
## 1. Shield (hit arrived through the dummy's shield hitbox): explosions/fire pass; a bullet passes at
##    x shield_pierce_mult when `info.shield_pierce`, otherwise it is blocked (0 damage).
## 2. WEAKPOINT while plates remain: the amount goes into the current plate's HP pool (x1, no zone or
##    crit multiplier, excess lost); emptying it breaks the plate and exposes the next stage. With no
##    plates left (or none at all) WEAKPOINT counts x1 on health.
## 3. HEAD: x headshot_mult x info.headshot_bonus, except x1 while plates remain (headshot-immune).
## 4. Frontal armor: a BODY hit from the front takes x armor_body_mult (0 = blocked) unless
##    `info.pierced_armor`; explosions and fire ignore it.
## 5. Crit (D-027): x the HEAD multiplier on any zone (the same immunity applies).
## Health and plate pools live in a state Dictionary {health, plates: PackedFloat32Array, stage}.
class_name RangeDamageModel
extends RefCounted

## Readout simulation stops here (counts as "cannot kill").
const MAX_SIM_SHOTS: int = 20000

var health: float = 1.0
var headshot_mult: float = 1.0
var frontal_armor: bool = false
var armor_body_mult: float = 0.0
var shield: bool = false
var shield_pierce_mult: float = 0.25
var plate_health: PackedFloat32Array = PackedFloat32Array()


static func from_def(def: RangeDummyDef, difficulty: int) -> RangeDamageModel:
	var m: RangeDamageModel = RangeDamageModel.new()
	if def == null:
		return m
	m.health = def.health_for(difficulty)
	m.headshot_mult = def.headshot_mult_for(difficulty)
	m.frontal_armor = def.has_frontal_armor()
	m.armor_body_mult = def.armor_body_mult_value()
	m.shield = def.has_shield()
	m.shield_pierce_mult = def.shield_pierce_mult_value()
	m.plate_health = def.plates()
	return m


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


## Apply one hit to `state` (mutated). Returns {amount, killed, health_after, blocked,
## pierced_shield, pierced_armor, plate_stage (-1 = none), plate_broken, plate_health_after}.
func apply(state: Dictionary, info: Dictionary, via_shield: bool, frontal: bool) -> Dictionary:
	var out: Dictionary = {
		"amount": 0.0, "killed": false, "health_after": float(state["health"]), "blocked": false,
		"pierced_shield": false, "pierced_armor": false, "plate_stage": -1, "plate_broken": false,
		"plate_health_after": 0.0,
	}
	var amount: float = maxf(float(info.get("amount", 0.0)), 0.0)
	var dtype: int = int(info.get("type", Enums.DamageType.BULLET))
	var ignores_armor: bool = dtype == Enums.DamageType.EXPLOSION or dtype == Enums.DamageType.FIRE
	if via_shield and shield and not ignores_armor:
		if not bool(info.get("shield_pierce", false)):
			out["blocked"] = true
			return out
		amount *= shield_pierce_mult
		out["pierced_shield"] = true
	var zone: int = int(info.get("zone", Enums.HitZone.BODY))
	var plates: PackedFloat32Array = state["plates"]
	var stage: int = int(state["stage"])
	if zone == Enums.HitZone.WEAKPOINT and stage < plates.size():
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
	var head_mult: float = 1.0 if stage < plates.size() else headshot_mult
	var mult: float = 1.0
	if zone == Enums.HitZone.HEAD:
		mult = head_mult * float(info.get("headshot_bonus", 1.0))
	elif zone == Enums.HitZone.BODY and frontal_armor and frontal and not ignores_armor:
		if bool(info.get("pierced_armor", false)):
			out["pierced_armor"] = true
		else:
			mult = armor_body_mult
			if mult <= 0.0:
				out["blocked"] = true
	if bool(info.get("crit", false)):
		mult *= head_mult
	amount *= mult
	var h: float = maxf(float(state["health"]) - amount, 0.0)
	state["health"] = h
	out["amount"] = amount
	out["health_after"] = h
	out["killed"] = h <= RangeMath.EPS
	return out


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
