## PO-8 §1 (impact_fx.md, D-105): every collision body bullets can hit carries an explicit
## `metadata/surface` id, so impacts get the right debris, decal and sound. Owner: ENV C.
##
## Walks every CollisionObject3D on the bullet layers (CombatTweak hitscan_mask | penetrable_mask) in
## the props library and the four heist maps and resolves its surface with the ImpactFx.surface_of rule
## (meta on the body itself or on a parent CollisionObject3D, up to 3 parents; else the implicit
## default `concrete`). A body that only resolves by the implicit default fails, except:
## - bodies inside ENV A gameplay prefabs (scenes under res://systems/): A tags those (PO-8 report),
##   listed as a warning so the gap stays visible;
## - bodies on the hitboxes layer only (characters resolve to flesh/armor/shield from the hit zone);
## - MapZone areas (they move to the triggers layer in _ready).
## Map generators tag through SurfaceTags (game/world/materials/surface_tags.gd), prop wrappers through
## tools/blender/props/_scenes.py; both read game/world/materials/surface_map.json.
## Prints a per-map surface histogram.
extends TestCase

const SURFACES: Array[StringName] = [&"concrete", &"brick", &"plaster", &"tile", &"wood", &"metal", &"glass",
	&"fabric", &"dirt", &"water", &"flesh", &"armor", &"shield"]
const DEFAULT_SURFACE: StringName = &"concrete"
const MAX_PARENTS: int = 3
const MAPS: Array[String] = [
	"res://world/heists/glasshouse/glasshouse.tscn",
	"res://world/heists/night_deposit/night_deposit.tscn",
	"res://world/heists/dockside_burn/dockside_burn.tscn",
	"res://world/heists/shadow_ledger/shadow_ledger.tscn",
]
## ENV A gameplay prefabs: tagged by A (allowlisted here, reported).
const PREFAB_PREFIX: String = "res://systems/"
const HITBOXES_LAYER: int = 1 << 4


## Mirror of ImpactFx.surface_of (game/world/vfx/impact_fx.gd, another lane): returns
## [surface, explicit]. Explicit = a `surface` meta was found on the body or a parent body.
static func resolve(col: Object) -> Array:
	var n: Node = col as Node
	var hops: int = 0
	while n != null and hops <= MAX_PARENTS:
		if n is CollisionObject3D and n.has_meta(&"surface"):
			return [StringName(n.get_meta(&"surface")), true]
		n = n.get_parent()
		hops += 1
	return [DEFAULT_SURFACE, false]


static func bullet_mask() -> int:
	var tw: CombatTweak = CombatTweak.data()
	return tw.hitscan_mask | tw.penetrable_mask


## Nearest ancestor (or self) instanced from a scene file, for grouping and the prefab allowlist.
static func source_of(n: Node, root: Node) -> String:
	var p: Node = n
	while p != null and p != root:
		if not p.scene_file_path.is_empty():
			return p.scene_file_path
		p = p.get_parent()
	return "<map>"


## Scan `root`: { "hist": {surface: count}, "untagged": [String], "prefab": {scene: count},
## "bad_id": [String], "total": int }.
static func scan(root: Node) -> Dictionary:
	var hist: Dictionary = {}
	var untagged: Array[String] = []
	var prefab: Dictionary = {}
	var bad_id: Array[String] = []
	var total: int = 0
	var mask: int = bullet_mask()
	for c: Node in root.find_children("*", "CollisionObject3D", true, false):
		var co: CollisionObject3D = c as CollisionObject3D
		if (co.collision_layer & mask) == 0:
			continue
		if (co.collision_layer & mask) == HITBOXES_LAYER or co is MapZone:
			continue  # MapZone moves itself to the triggers layer in _ready
		total += 1
		var r: Array = resolve(co)
		var s: StringName = r[0]
		var src: String = source_of(co, root)
		if not bool(r[1]):
			if src.begins_with(PREFAB_PREFIX):
				prefab[src] = int(prefab.get(src, 0)) + 1
			else:
				untagged.append("%s  [%s]" % [root.get_path_to(co), src])
			continue
		if not SURFACES.has(s):
			bad_id.append("%s = %s" % [root.get_path_to(co), s])
		hist[s] = int(hist.get(s, 0)) + 1
	return {"hist": hist, "untagged": untagged, "prefab": prefab, "bad_id": bad_id, "total": total}


static func hist_line(hist: Dictionary) -> String:
	var keys: Array = hist.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(hist[a]) > int(hist[b]))
	var parts: PackedStringArray = []
	for k: Variant in keys:
		parts.append("%s %d" % [k, hist[k]])
	return ", ".join(parts)


func _check(label: String, root: Node) -> void:
	var r: Dictionary = scan(root)
	print("  surfaces %s (%d bodies): %s" % [label, r["total"], hist_line(r["hist"])])
	var prefab: Dictionary = r["prefab"]
	if not prefab.is_empty():
		var parts: PackedStringArray = []
		for k: String in prefab:
			parts.append("%s x%d" % [k.get_file(), prefab[k]])
		print("  surfaces %s: untagged ENV A prefab bodies (A to tag): %s" % [label, ", ".join(parts)])
	var untagged: Array[String] = r["untagged"]
	for u: String in untagged.slice(0, 40):
		print("    untagged: %s" % u)
	assert_true(untagged.is_empty(), "%s: %d bullet-hittable bodies without a surface tag" % [label, untagged.size()])
	var bad: Array[String] = r["bad_id"]
	assert_true(bad.is_empty(), "%s: unknown surface ids: %s" % [label, bad])


func test_props_library_tagged() -> void:
	var catalog: Dictionary = PropCatalog.load_catalog()
	assert_true(not catalog.is_empty(), "prop catalog empty")
	var holder := Node3D.new()
	var ids: Array = catalog.keys()
	ids.sort()
	for id: Variant in ids:
		var ps: PackedScene = load(String(catalog[id]["scene"])) as PackedScene
		if ps == null:
			fail("%s: cannot load scene" % id)
			continue
		holder.add_child(ps.instantiate())
	_check("props library", holder)
	holder.free()


func test_maps_tagged() -> void:
	for path: String in MAPS:
		var ps: PackedScene = load(path) as PackedScene
		if ps == null:
			fail("cannot load %s" % path)
			continue
		var map: Node = ps.instantiate()
		_check(path.get_file().get_basename(), map)
		map.free()


func test_resolve_rule() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	body.add_child(shape)
	assert_eq(resolve(body), [DEFAULT_SURFACE, false], "untagged body -> implicit concrete")
	body.set_meta(&"surface", &"wood")
	assert_eq(resolve(body), [&"wood", true], "tag on the body")
	var outer := StaticBody3D.new()
	outer.set_meta(&"surface", &"metal")
	var inner := StaticBody3D.new()
	outer.add_child(inner)
	assert_eq(resolve(inner), [&"metal", true], "tag on a parent body")
	outer.free()
	body.free()
