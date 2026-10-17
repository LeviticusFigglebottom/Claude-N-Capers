## Read-only access to the generated prop catalog (`prop_catalog.json`, written by
## tools/blender/props/_scenes.py). Owner: ENV C (C1-07).
## Each entry: scene, glb, kind, prefab, group, place, mount, support, fixture, hosts, z, clear,
## weight, aabb [x, y, z, sx, sy, sz] (Godot space, root-local), nodes, has_light.
class_name PropCatalog
extends RefCounted

const PATH: String = "res://world/props/prop_catalog.json"

static var _cache: Dictionary = {}


## The whole catalog: asset id -> entry Dictionary. Cached after the first call.
static func load_catalog() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var text: String = FileAccess.get_file_as_string(PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_cache = parsed
	else:
		push_error("PropCatalog: cannot parse %s" % PATH)
	return _cache


static func entry(asset_id: StringName) -> Dictionary:
	var c: Dictionary = load_catalog()
	return c.get(String(asset_id), {})


## Dressing asset ids (no prefab visuals) whose `kind` is `kind`, sorted. Entries marked `pin_only`
## (a heist's own variant of a shared kind) are left out: kits use them only through `assets`.
static func ids_of_kind(kind: StringName) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var c: Dictionary = load_catalog()
	for k: Variant in c.keys():
		var e: Dictionary = c[k]
		if bool(e.get("pin_only", false)):
			continue
		if StringName(String(e.get("kind", ""))) == kind and String(e.get("prefab", "")) == "":
			out.append(String(k))
	out.sort()
	return out


## Every dressing kind in the catalog, sorted.
static func kinds() -> PackedStringArray:
	var seen: Dictionary = {}
	var c: Dictionary = load_catalog()
	for k: Variant in c.keys():
		var e: Dictionary = c[k]
		if String(e.get("prefab", "")) == "":
			seen[String(e.get("kind", ""))] = true
	var out: PackedStringArray = PackedStringArray(seen.keys())
	out.sort()
	return out


## Model bounds in the prop's root space.
static func aabb(asset_id: StringName) -> AABB:
	var a: Array = entry(asset_id).get("aabb", [0, 0, 0, 0, 0, 0])
	return AABB(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]))


## Height of the support surface (catalog `top`, else the model top).
static func top(asset_id: StringName) -> float:
	var e: Dictionary = entry(asset_id)
	var t: float = float(e.get("top", 0.0))
	return t if t > 0.0 else aabb(asset_id).end.y


## D-130: the prop-local position of the wrapper's `Seat` when the generator moved it (catalog `seat`, cat
## `seat_fwd`: prop_chair_office / prop_chair_task, 0.12 m toward the front), else `fallback`.
static func seat(asset_id: StringName, fallback: Vector3) -> Vector3:
	var s: Array = entry(asset_id).get("seat", [])
	return Vector3(float(s[0]), float(s[1]), float(s[2])) if s.size() == 3 else fallback
