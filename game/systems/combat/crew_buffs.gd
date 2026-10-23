## Timed modifier sources per crew slot (B's unhooked skill keys, batch 1: Inspire's move / reload buff, Overkill's
## damage window, Swan Song's slow). Owner: ENV A. Server-authoritative: grant() sets Modifiers.set_source(slot,
## source, values) for `duration_s`, a re-grant of the same source refreshes it, and the expiry clears it. Clients
## mirror the live set (HeistNetSync SVC_BUFFS: net_state / apply_net_state) so their movement prediction and HUD
## read the same Modifiers as the server; the expiry reaches them with the next services sync. A buff may also carry
## `tags` (states that are no modifier key, e.g. TAG_FREE_AMMO: Swan Song Aced, Bulletstorm), mirrored the same way.
class_name CrewBuffs
extends Node

const SERVICE: StringName = &"crew_buffs"
const NODE_NAME: String = "CrewBuffs"
## Modifiers source names are prefixed so they never collide with the skill / perk / asset sources.
const PREFIX: String = "buff."
## Tag: no round is consumed per shot (CrewWeapons: the server's commit and the owner's prediction).
const TAG_FREE_AMMO: StringName = &"free_ammo"

## slot -> source -> {"values": Dictionary, "tags": Array, "left": float}
var _buffs: Dictionary[int, Dictionary] = {}


## The runtime's CrewBuffs, created on first use (null without a runtime).
static func of(rt: HeistRuntime) -> CrewBuffs:
	if rt == null:
		return null
	var b: CrewBuffs = rt.service(SERVICE) as CrewBuffs
	if b == null:
		b = CrewBuffs.new()
		b.name = NODE_NAME
		rt.register_service(SERVICE, b)
	return b


## Server: `values` (modifier key -> value) on `slot` for `duration_s`; the same `source` again refreshes it.
func grant(slot: int, source: StringName, values: Dictionary, duration_s: float, tags: Array = []) -> void:
	if not Net.is_authority() or duration_s <= 0.0:
		return
	if not _buffs.has(slot):
		_buffs[slot] = {}
	_buffs[slot][source] = {"values": values.duplicate(), "tags": tags.duplicate(), "left": duration_s}
	Modifiers.set_source(slot, _source(source), values)


## Server: end `source` on `slot` now.
func end(slot: int, source: StringName) -> void:
	if _buffs.has(slot) and (_buffs[slot] as Dictionary).erase(source):
		Modifiers.clear_source(slot, _source(source))


## Seconds left of `source` on `slot` (0 when not active).
func left(slot: int, source: StringName) -> float:
	var b: Dictionary = (_buffs.get(slot, {}) as Dictionary).get(source, {})
	return float(b.get("left", 0.0))


func active(slot: int, source: StringName) -> bool:
	return (_buffs.get(slot, {}) as Dictionary).has(source)


## Any live buff on `slot` carries `tag` (on the server and, mirrored, on clients).
func has_tag(slot: int, tag: StringName) -> bool:
	for b: Variant in (_buffs.get(slot, {}) as Dictionary).values():
		if ((b as Dictionary).get("tags", []) as Array).has(tag):
			return true
	return false


## `crew` fires without using ammo now (CrewWeapons): a TAG_FREE_AMMO buff on its slot.
static func free_ammo(crew: CrewController) -> bool:
	var rt: HeistRuntime = HeistRuntime.of(crew) if crew != null else null
	var b: CrewBuffs = rt.service(SERVICE) as CrewBuffs if rt != null else null
	return b != null and b.has_tag(crew.slot, TAG_FREE_AMMO)


func _physics_process(delta: float) -> void:
	if not Net.is_authority():
		return
	for slot: int in _buffs:
		var by: Dictionary = _buffs[slot]
		for source: StringName in by.keys():
			var b: Dictionary = by[source]
			b["left"] = float(b["left"]) - delta
			if float(b["left"]) <= 0.0:
				end(slot, source)


## Server -> clients: {slot: {source: {"values", "tags"}}} (no timers: the server's expiry removes the entry).
func net_state() -> Dictionary:
	var out: Dictionary = {}
	for slot: int in _buffs:
		var by: Dictionary = {}
		for source: StringName in _buffs[slot]:
			var b: Dictionary = _buffs[slot][source]
			by[source] = {"values": (b["values"] as Dictionary).duplicate(), "tags": (b["tags"] as Array).duplicate()}
		if not by.is_empty():
			out[slot] = by
	return out


## Client: mirror the server's live buffs (set the new / changed, clear the gone).
func apply_net_state(d: Dictionary) -> void:
	if Net.is_authority():
		return
	for slot: int in _buffs.keys():
		for source: StringName in (_buffs[slot] as Dictionary).keys():
			if not (d.get(slot, {}) as Dictionary).has(source):
				Modifiers.clear_source(slot, _source(source))
				(_buffs[slot] as Dictionary).erase(source)
	for k: Variant in d:
		var slot: int = int(k)
		if not _buffs.has(slot):
			_buffs[slot] = {}
		for source: Variant in d[k]:
			var e: Dictionary = d[k][source]
			var values: Dictionary = e.get("values", {})
			var had: Dictionary = (_buffs[slot] as Dictionary).get(StringName(source), {})
			if had.get("values", {}) != values or had.get("tags", []) != e.get("tags", []):
				_buffs[slot][StringName(source)] = {"values": values.duplicate(), "tags": (e.get("tags", []) as Array).duplicate(),
					"left": 0.0}
				Modifiers.set_source(slot, _source(StringName(source)), values)


static func _source(source: StringName) -> StringName:
	return StringName(PREFIX + String(source))
