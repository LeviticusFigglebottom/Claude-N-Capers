## Bullet surface ids for map geometry (PO-8, impact_fx.md §1, D-105). Owner: ENV C.
##
## Every collision body bullets can hit carries `metadata/surface` (StringName). Map generators tag
## at the source: explicit ids where a body has no visual (`tag`), else `tag_tree` derives the id
## from the materials of the body's own meshes through surface_map.json (shared with the prop
## wrapper scenes, tools/blender/props/_scenes.py), so new geometry is tagged automatically.
## The runtime lookup (ImpactFx.surface_of) only reads the metas; this script is tool-time.
class_name SurfaceTags
extends RefCounted

const MAP_PATH: String = "res://world/materials/surface_map.json"
const META: StringName = &"surface"
## The hitboxes layer is left out of the bullet layers: characters resolve from the hit zone.
const HITBOXES_LAYER: int = 1 << 4
const MAX_PARENTS: int = 3

static var _table: Dictionary = {}


static func table() -> Dictionary:
	if _table.is_empty():
		var f: FileAccess = FileAccess.open(MAP_PATH, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_table = d
	return _table


## Collision layers a bullet ray can stop on (CombatTweak hitscan + penetrable), minus hitboxes.
static func bullet_layers() -> int:
	var tw: CombatTweak = CombatTweak.data()
	return (tw.hitscan_mask | tw.penetrable_mask) & ~HITBOXES_LAYER


static func is_id(s: StringName) -> bool:
	return (table().get("ids", []) as Array).has(String(s))


## Surface for a material / greybox class id: exact table entry (a leading `M_` and then any
## leading `<prefix>_` segments stripped one at a time), else the first keyword. &"" if unknown.
static func for_id(id: String) -> StringName:
	var mats: Dictionary = table().get("materials", {})
	var key: String = id.trim_prefix("M_")
	var probe: String = key
	while not probe.is_empty():
		if mats.has(probe):
			return StringName(mats[probe])
		var cut: int = probe.find("_")
		if cut < 0:
			break
		probe = probe.substr(cut + 1)
	for kw: Variant in table().get("keywords", []):
		var pair: Array = kw as Array
		if key.contains(String(pair[0])):
			return StringName(pair[1])
	return &""


## Surface for a material: its library file name (res://.../<id>.tres), else its resource_name.
static func for_material(m: Material) -> StringName:
	if m == null:
		return &""
	if not m.resource_path.is_empty() and not m.resource_path.contains("::"):
		var s: StringName = for_id(m.resource_path.get_file().get_basename())
		if s != &"":
			return s
	return for_id(m.resource_name) if not m.resource_name.is_empty() else &""


static func tag(body: Node, surface: StringName) -> void:
	if body is CollisionObject3D and surface != &"":
		body.set_meta(META, surface)


## Explicit tag on `body` (or a parent CollisionObject3D within MAX_PARENTS), mirroring the lookup.
static func has_tag(body: Node) -> bool:
	var n: Node = body
	var hops: int = 0
	while n != null and hops <= MAX_PARENTS:
		if n is CollisionObject3D and n.has_meta(META):
			return true
		n = n.get_parent()
		hops += 1
	return false


## Area-weighted surface of an axis-aligned box's faces, for map boxes whose visuals are merged
## elsewhere: `key_of(f, n, centre) -> String` gives face f's material key (0 -X, 1 +X, 2 -Y, 3 +Y,
## 4 -Z, 5 +Z; "" = not drawn), as the map's art pass draws it. No drawn face: the id of `cls` (hidden
## massing such as container stacks drawn by a dressing scene).
static func from_faces(mn: Vector3, mx: Vector3, key_of: Callable, cls: String = "") -> StringName:
	var size: Vector3 = mx - mn
	var mid: Vector3 = (mn + mx) * 0.5
	var normals: Array[Vector3] = [Vector3.LEFT, Vector3.RIGHT, Vector3.DOWN, Vector3.UP, Vector3.FORWARD, Vector3.BACK]
	var areas: Array[float] = [size.y * size.z, size.y * size.z, size.x * size.z, size.x * size.z, size.x * size.y,
		size.x * size.y]
	var votes: Dictionary = {}
	for f: int in range(6):
		var n: Vector3 = normals[f]
		var c: Vector3 = mid + n * size * 0.5
		var s: StringName = for_id(String(key_of.call(f, n, c)))
		if s != &"":
			# areas in cm² so thin faces still count
			votes[s] = int(votes.get(s, 0)) + maxi(1, int(areas[f] * 10000.0))
	return _best(votes) if not votes.is_empty() else for_id(cls)


## Dominant surface of the meshes under `body` (vertex-count weighted, not crossing nested bodies).
static func from_meshes(body: Node) -> StringName:
	var votes: Dictionary = {}
	_collect(body, body, votes)
	return _best(votes)


## Collision-only body next to its visual: a collider added to a prop wrapper takes the tag of
## the wrapper's own (tagged) body; else the dominant surface of the MeshInstance3D siblings and
## instanced visual scenes under the same parent (stair ramps beside their step meshes).
static func from_siblings(body: Node) -> StringName:
	var p: Node = body.get_parent()
	if p == null:
		return &""
	var votes: Dictionary = {}
	for c: Node in p.get_children():
		if c == body:
			continue
		if not c.scene_file_path.is_empty():
			for inner: Node in c.find_children("*", "CollisionObject3D", true, false):
				if inner.has_meta(META):
					return StringName(inner.get_meta(META))
			_collect(c, c, votes)
		elif c is MeshInstance3D:
			_collect(c, c, votes)
	return _best(votes)


## Tags the untagged bullet-layer bodies at `path` under `root` (the node itself and everything
## below it, map-built only): collision-only groups whose visuals are drawn elsewhere.
static func tag_untagged(root: Node, path: NodePath, surface: StringName) -> void:
	var top: Node = root.get_node_or_null(path)
	if top == null:
		return
	var layers: int = bullet_layers()
	var all: Array[Node] = top.find_children("*", "CollisionObject3D", true, false)
	all.append(top)
	for c: Node in all:
		var co: CollisionObject3D = c as CollisionObject3D
		if co != null and (co.collision_layer & layers) != 0 and co.owner == root and not has_tag(co):
			tag(co, surface)


static func _best(votes: Dictionary) -> StringName:
	var best: StringName = &""
	var best_w: int = 0
	var keys: Array = votes.keys()
	keys.sort()
	for k: Variant in keys:
		if int(votes[k]) > best_w:
			best_w = int(votes[k])
			best = StringName(k)
	return best


static func _collect(n: Node, body: Node, votes: Dictionary) -> void:
	if n != body and n is CollisionObject3D:
		return
	var mi: MeshInstance3D = n as MeshInstance3D
	if mi != null and mi.mesh != null:
		for i: int in range(mi.mesh.get_surface_count()):
			var m: Material = mi.get_active_material(i)
			var s: StringName = for_material(m)
			if s != &"":
				votes[s] = int(votes.get(s, 0)) + maxi(1, (mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	var csg: CSGShape3D = n as CSGShape3D
	if csg != null:
		var s2: StringName = for_material(csg.get(&"material") as Material)
		if s2 != &"":
			votes[s2] = int(votes.get(s2, 0)) + 1
	for c: Node in n.get_children():
		_collect(c, body, votes)


## Tags every untagged bullet-layer body owned by `root` (map-built, not inside an instanced scene)
## from its meshes (else its sibling meshes). Returns the paths of bodies still untagged.
static func tag_tree(root: Node) -> PackedStringArray:
	var left: PackedStringArray = PackedStringArray()
	var layers: int = bullet_layers()
	for c: Node in root.find_children("*", "CollisionObject3D", true, false):
		var co: CollisionObject3D = c as CollisionObject3D
		if (co.collision_layer & layers) == 0 or co.owner != root or has_tag(co):
			continue
		var s: StringName = from_meshes(co)
		if s == &"":
			s = from_siblings(co)
		if s == &"":
			left.append(str(root.get_path_to(co)))
			continue
		tag(co, s)
	return left
