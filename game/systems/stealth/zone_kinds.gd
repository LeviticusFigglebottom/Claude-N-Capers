## Runtime MapZone kind changes (D-103 §6 / QC-51, Gallery Night last call: the galleries turn RESTRICTED).
## Owner: ENV A. MapZone (contract) reads `kind` live (StealthDirector._zone_mask_at), so the server flips it in place
## and moves the zone to the new kind's group; the overrides are replicated as a runtime service
## (HeistNetSync services diff, late join included) keyed by the zone's path from the map.
class_name ZoneKinds
extends Node

const SERVICE: StringName = &"zone_kinds"

## Zone path (relative to the map root) -> MapZone.Kind, every change applied so far.
var overrides: Dictionary = {}

var _runtime: HeistRuntime = null


## The runtime's ZoneKinds service, created on first use.
static func ensure(rt: HeistRuntime) -> ZoneKinds:
	if rt == null:
		return null
	var s: ZoneKinds = rt.service(SERVICE) as ZoneKinds
	if s == null:
		s = ZoneKinds.new()
		s.name = "ZoneKinds"
		s._runtime = rt
		rt.register_service(SERVICE, s)
	return s


## Server: give `zone` the kind `kind` (MapZone.Kind) for the rest of the run. Replicated.
static func set_kind(rt: HeistRuntime, zone: MapZone, kind: int) -> void:
	if not Net.is_authority() or zone == null or rt == null or rt.map == null:
		return
	var s: ZoneKinds = ensure(rt)
	apply_kind(zone, kind)
	s.overrides[String(rt.map.get_path_to(zone))] = kind
	Log.info(&"stealth", "zone %s is now %s" % [zone.name, MapZone.Kind.keys()[kind]])


## Flip a zone's kind in place and move it between the kind groups (G.RESTRICTED_AREA, ...).
static func apply_kind(zone: MapZone, kind: int) -> void:
	if zone.kind == kind:
		return
	var old_group: StringName = MapZone._GROUPS.get(zone.kind, &"")
	if old_group != &"" and zone.is_in_group(old_group):
		zone.remove_from_group(old_group)
	zone.kind = kind as MapZone.Kind
	var new_group: StringName = MapZone._GROUPS.get(kind, &"")
	if new_group != &"":
		zone.add_to_group(new_group)


func net_state() -> Dictionary:
	return overrides.duplicate()


## Client: apply every replicated override (idempotent).
func apply_net_state(d: Dictionary) -> void:
	if _runtime == null or _runtime.map == null:
		return
	for path: Variant in d:
		var z: MapZone = _runtime.map.get_node_or_null(NodePath(String(path))) as MapZone
		if z != null:
			apply_kind(z, int(d[path]))
	overrides = d.duplicate()
