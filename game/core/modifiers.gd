## Modifier query service (skills, perk cards, assets, difficulty). Owner: LEAD (API).
## Contract: docs/contracts/modifiers.md (v1). Keys: game/contracts/modifier_keys.gd.
##
## Population (ENV B progression code / heist setup, on the SERVER):
##   Modifiers.set_source(crew_slot, &"skills", {&"stealth.body_bags_extra": 2, ...})
##   Modifiers.set_source(Modifiers.TEAM, &"asset.body_bag_case", {&"stealth.body_bags_extra": 2})
## Query (ENV A systems):
##   Modifiers.mult(slot, &"interaction.device_speed_mult")        -> float (1.0 default)
##   Modifiers.add(slot, &"stealth.body_bags_extra")               -> float (0 default)
##   Modifiers.flag(slot, &"stealth.silent_devices")               -> bool
##   Modifiers.params(slot, &"perk.stoic")                          -> Dictionary ({} if absent)
##   Qualified keys: Modifiers.mult(slot, &"weapon.damage_mult", &"shotgun") combines
##   "weapon.damage_mult.shotgun" and "weapon.damage_mult.all".
## TEAM-scoped sources apply to every crew slot.
extends Node

const TEAM: int = -1

## slot -> source_name -> { key: value }
var _sources: Dictionary[int, Dictionary] = {}


func set_source(slot: int, source: StringName, values: Dictionary) -> void:
	for key: Variant in values:
		if not ModifierKeys.is_known(key):
			Log.error(&"modifiers", "unknown modifier key '%s' from source '%s'" % [key, source])
	if not _sources.has(slot):
		_sources[slot] = {}
	_sources[slot][source] = values


func clear_source(slot: int, source: StringName) -> void:
	if _sources.has(slot):
		_sources[slot].erase(source)


func clear_all() -> void:
	_sources.clear()


func mult(slot: int, key: StringName, qualifier: StringName = &"") -> float:
	var result: float = 1.0
	for v: Variant in _collect(slot, key, qualifier):
		result *= float(v)
	return result


func add(slot: int, key: StringName, qualifier: StringName = &"") -> float:
	var result: float = 0.0
	for v: Variant in _collect(slot, key, qualifier):
		result += float(v)
	return result


func flag(slot: int, key: StringName, qualifier: StringName = &"") -> bool:
	for v: Variant in _collect(slot, key, qualifier):
		if bool(v):
			return true
	return false


func params(slot: int, key: StringName) -> Dictionary:
	var found: Array = _collect(slot, key, &"")
	if found.is_empty():
		return {}
	return found[-1]


## Snapshot for debugging / results screen.
func dump(slot: int) -> Dictionary:
	var out: Dictionary = {}
	for s: int in [TEAM, slot]:
		if _sources.has(s):
			out[s] = _sources[s].duplicate(true)
	return out


func _collect(slot: int, key: StringName, qualifier: StringName) -> Array:
	var keys: Array[StringName] = [key]
	if qualifier != &"":
		keys = [StringName("%s.%s" % [key, qualifier]), StringName("%s.all" % key)]
	var out: Array = []
	for s: int in [TEAM, slot]:
		if not _sources.has(s):
			continue
		var by_source: Dictionary = _sources[s]
		for source: Variant in by_source:
			var values: Dictionary = by_source[source]
			for k: StringName in keys:
				if values.has(k):
					out.append(values[k])
	return out
