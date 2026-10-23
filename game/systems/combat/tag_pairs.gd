## D-163 Tag Team pairs (PD2 Gas Dispenser). Owner: ENV A. Service SERVICE, server-authoritative, replicated (HeistNetSync
## SVC_TAG_PAIRS) for the HUD. A holder tags the teammate on its aim line (ShoutSystem.ally_target_for: the mark cone,
## within max_m, clear LOS); the pair lasts duration_s (extend() adds), the item recharges cooldown_s from the tag
## (cut_cooldown() shortens it). paired_holders(killer_slot) answers "whose pair does this kill count for" (the holder's
## or the tagged teammate's kill). The perk (perk.tag_team, B's params) reads and drives it.
class_name TagPairs
extends Node

signal paired(holder_slot: int, tagged_slot: int)
signal unpaired(holder_slot: int)

const SERVICE: StringName = &"tag_pairs"
const NODE_NAME: String = "TagPairs"

## holder slot -> {"tagged": slot (-1 = none), "left": s, "cooldown": s}
var pairs: Dictionary[int, Dictionary] = {}


## The runtime's TagPairs, created on first use (null without a runtime).
static func of(rt: HeistRuntime) -> TagPairs:
	if rt == null:
		return null
	var t: TagPairs = rt.service(SERVICE) as TagPairs
	if t == null:
		t = TagPairs.new()
		t.name = NODE_NAME
		rt.register_service(SERVICE, t)
	return t


## Server: `holder` tags the teammate it aims at. The tagged slot, or -1 (nobody in reach / sight, or still recharging).
func tag(holder: CrewController, max_m: float, duration_s: float, cooldown_s: float) -> int:
	if not Net.is_authority() or holder == null or cooldown_left(holder.slot) > 0.0:
		return -1
	var rt: HeistRuntime = HeistRuntime.of(holder)
	var target: CrewController = ShoutSystem.ensure(rt).ally_target_for(holder, max_m) if rt != null else null
	if target == null:
		return -1
	pairs[holder.slot] = {"tagged": target.slot, "left": duration_s, "cooldown": cooldown_s}
	paired.emit(holder.slot, target.slot)
	return target.slot


func tagged_of(holder_slot: int) -> int:
	var e: Dictionary = pairs.get(holder_slot, {})
	return int(e["tagged"]) if not e.is_empty() and float(e["left"]) > 0.0 else -1


func cooldown_left(holder_slot: int) -> float:
	return float((pairs.get(holder_slot, {}) as Dictionary).get("cooldown", 0.0))


## Server: lengthen holder_slot's live pair by `seconds`.
func extend(holder_slot: int, seconds: float) -> void:
	if tagged_of(holder_slot) >= 0:
		pairs[holder_slot]["left"] = float(pairs[holder_slot]["left"]) + seconds


## Server: shorten holder_slot's item recharge by `seconds`.
func cut_cooldown(holder_slot: int, seconds: float) -> void:
	if pairs.has(holder_slot):
		pairs[holder_slot]["cooldown"] = maxf(float(pairs[holder_slot]["cooldown"]) - seconds, 0.0)


## The holders whose live pair a kill by killer_slot counts for (the holder itself or its tagged teammate).
func paired_holders(killer_slot: int) -> Array[int]:
	var out: Array[int] = []
	for h: int in pairs:
		var t: int = tagged_of(h)
		if t >= 0 and (killer_slot == h or killer_slot == t):
			out.append(h)
	return out


func _physics_process(delta: float) -> void:
	if not Net.is_authority():
		return
	for h: int in pairs:
		var e: Dictionary = pairs[h]
		e["cooldown"] = maxf(float(e["cooldown"]) - delta, 0.0)
		if float(e["left"]) > 0.0:
			e["left"] = maxf(float(e["left"]) - delta, 0.0)
			if float(e["left"]) <= 0.0:
				e["tagged"] = -1
				unpaired.emit(h)


## HeistNetSync SVC_TAG_PAIRS: {holder: [tagged, left, cooldown]}.
func net_state() -> Dictionary:
	var out: Dictionary = {}
	for h: int in pairs:
		var e: Dictionary = pairs[h]
		out[h] = [int(e["tagged"]), snappedf(float(e["left"]), 0.1), snappedf(float(e["cooldown"]), 0.1)]
	return out


func apply_net_state(d: Dictionary) -> void:
	for k: Variant in d:
		var a: Array = d[k] as Array
		pairs[int(k)] = {"tagged": int(a[0]), "left": float(a[1]), "cooldown": float(a[2])}
