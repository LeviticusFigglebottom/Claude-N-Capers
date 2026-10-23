## D-163 deck-item HUD state (ui_hud v1.21 perk_item). Owner: ENV A. Service SERVICE: the server's perk components
## publish their throwable's state per slot ({kind, charges, max, cooldown_left, active_left, partner_slot}); it is
## replicated (HeistNetSync SVC_PERK_ITEMS) so every peer's LocalHudModel reads the same. Display only.
class_name PerkItems
extends Node

const SERVICE: StringName = &"perk_items"
const NODE_NAME: String = "PerkItems"

## slot -> {"kind": StringName, "charges": int, "max": int, "cooldown_left": float, "active_left": float,
## "partner_slot": int (-1 = none), "mode": StringName (&"" | &"jam" | &"feedback"), and while a Leech ampule runs
## "segments": {"count": int (left), "size": int (total)} (ui_hud v1.22)}
var items: Dictionary[int, Dictionary] = {}
## Server: slot -> the perk key that published it (not replicated).
var _keys: Dictionary[int, StringName] = {}


## The runtime's PerkItems, created on first use (null without a runtime).
static func of(rt: HeistRuntime) -> PerkItems:
	if rt == null:
		return null
	var p: PerkItems = rt.service(SERVICE) as PerkItems
	if p == null:
		p = PerkItems.new()
		p.name = NODE_NAME
		rt.register_service(SERVICE, p)
	return p


## One state dict in the perk_item shape.
static func entry(kind: StringName, charges: int, max_charges: int, cooldown_left: float, active_left: float,
		partner_slot: int = -1, mode: StringName = &"", segments: Dictionary = {}) -> Dictionary:
	var e: Dictionary = {"kind": kind, "charges": charges, "max": max_charges,
		"cooldown_left": snappedf(maxf(cooldown_left, 0.0), 0.1), "active_left": snappedf(maxf(active_left, 0.0), 0.1),
		"partner_slot": partner_slot, "mode": mode}
	if not segments.is_empty():
		e["segments"] = segments
	return e


## Server: slot's item state now, from perk `key` ({} clears it).
func publish(slot: int, key: StringName, state: Dictionary) -> void:
	if state.is_empty():
		items.erase(slot)
		_keys.erase(slot)
	else:
		items[slot] = state
		_keys[slot] = key


## Server, CrewPerks: perk `key` left slot; its item (if it published one) goes too.
static func clear_key(rt: HeistRuntime, slot: int, key: StringName) -> void:
	var p: PerkItems = rt.service(SERVICE) as PerkItems if rt != null else null
	if p != null and p._keys.get(slot, &"") == key:
		p.publish(slot, key, {})


func state(slot: int) -> Dictionary:
	return items.get(slot, {})


## HeistNetSync SVC_PERK_ITEMS: {slot: [kind, charges, max, cooldown_left, active_left, partner_slot, mode,
## segments count, segments size (-1 = none)]}.
func net_state() -> Dictionary:
	var out: Dictionary = {}
	for s: int in items:
		var e: Dictionary = items[s]
		var seg: Dictionary = e.get("segments", {})
		out[s] = [String(e["kind"]), int(e["charges"]), int(e["max"]), float(e["cooldown_left"]),
			float(e["active_left"]), int(e["partner_slot"]), String(e.get("mode", &"")),
			int(seg.get("count", -1)), int(seg.get("size", -1))]
	return out


func apply_net_state(d: Dictionary) -> void:
	items.clear()
	for k: Variant in d:
		var a: Array = d[k] as Array
		var seg: Dictionary = {"count": int(a[7]), "size": int(a[8])} if int(a[8]) >= 0 else {}
		items[int(k)] = entry(StringName(a[0]), int(a[1]), int(a[2]), float(a[3]), float(a[4]), int(a[5]),
			StringName(a[6]), seg)
