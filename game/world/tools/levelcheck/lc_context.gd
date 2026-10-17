# gdlint:disable=max-public-methods
## Shared state + scene/physics/navigation helpers for all levelcheck modules. Owner: ENV C.
## The map must be inside the tree (physics + navigation registered) before setup().
class_name LcContext
extends RefCounted

## Physics layer used for temporary visual-mesh proxies (bounds check). Layer 20.
const PROXY_LAYER: int = 1 << 19
## Everything except triggers (layer 10) and the proxy layer.
const QUERY_MASK: int = 0xFFFFFFFF & ~(1 << 9) & ~PROXY_LAYER
const CONTAINERS: Array[StringName] = [&"Geometry", &"Props", &"Lighting", &"Gameplay", &"Variants"]
## Folders whose geometry-carrying content roots are props too (prefabs, fixtures, slot content).
const CONTENT_FOLDERS: Array[StringName] = [&"Lighting", &"Gameplay", &"Variants"]
const PROP_METAS: Array[StringName] = [&"kind", &"mount", &"support", &"prop", &"fixture"]
## Kinds whose subtree is part of the building shell for ray classification.
const SHELL_KINDS: Array[StringName] = [&"door", &"vault_door", &"industrial_door", &"window", &"stairs", &"hatch"]
## GN-C2: a lockdown shutter mounted on a wall face over an opening another door fills (door prefab, meta kind
## `shutter`). It is never building shell (rays through the door behind it ignore it); door_frame_gap measures it
## in face mode, frame_proud skips it (its only collider is the coil hood above the opening).
const SHUTTER_KIND: StringName = &"shutter"

var map: HeistMap
var heist_id: String = ""
var stage: String = "greybox"
var variants_all: bool = false
var kit_dirs: PackedStringArray = PackedStringArray(["res://world/kits"])
## Absolute path for walkthrough.md ("" = do not write).
var walkthrough_report: String = ""
## Lines "<spawn name|*> <target node path|*>" (see README).
var walkthrough_whitelist: PackedStringArray = PackedStringArray()
var props: Array[LcProp] = []
var doors: Array[Node3D] = []
var rooms: Array[RoomVolume] = []
var nav_region: NavigationRegion3D = null
## Per-run scratch cache shared by checks (cleared by set_variant_config).
var cache: Dictionary = {}
## Temporary visual-mesh proxies (LcVisual.build_proxies).
var proxy_root: Node3D = null

var _prop_by_id: Dictionary = {}
var _active: Dictionary = {}  # VariantSlot instance id -> bool (empty: everything active)


func setup(p_map: HeistMap) -> void:
	map = p_map
	LcAreas.clear_cache()
	nav_region = map.get_node_or_null("Navigation") as NavigationRegion3D
	props.clear()
	_prop_by_id.clear()
	_scan(map, 0)
	_collect_doors()
	rooms.clear()
	for n: Node in map.find_children("*", "RoomVolume", true, false):
		rooms.append(n as RoomVolume)
	# Doors count as open (players can always breach them): the NavLinks of doorways baked closed
	# (D-073 BARRED / VAULT) carry the reachability and walkthrough paths.
	set_door_links(true)


## Sets `enabled` on every NavigationLink3D under a Door prefab; returns [[link, previous], ...].
func set_door_links(on: bool) -> Array[Array]:
	var saved: Array[Array] = []
	for n: Node in map.find_children("*", "NavigationLink3D", true, false):
		var l: NavigationLink3D = n as NavigationLink3D
		var cur: Node = l.get_parent()
		while cur != null and cur != map and not (cur is Door):
			cur = cur.get_parent()
		if cur is Door:
			saved.append([l, l.enabled])
			l.enabled = on
	return saved


func restore_links(saved: Array[Array]) -> void:
	for s: Array in saved:
		(s[0] as NavigationLink3D).enabled = bool(s[1])


func tree() -> SceneTree:
	return map.get_tree()


func space() -> PhysicsDirectSpaceState3D:
	return map.get_world_3d().direct_space_state


func _nav_map() -> RID:
	return map.get_world_3d().navigation_map


func node_path(n: Node) -> String:
	if n == map:
		return "."
	if map.is_ancestor_of(n):
		return String(map.get_path_to(n))
	return String(n.name)


## Waits for physics and navigation server sync.
func await_sync(frames: int = 3) -> void:
	for i: int in range(frames):
		await tree().physics_frame
		await tree().process_frame


## Waits until the navigation map has synced a change made just before the call (its iteration id moves on), plus
## `settle` more frames; at most `max_frames` (a loaded box can take longer than a fixed frame count).
func await_nav_update(settle: int = 2, max_frames: int = 120) -> void:
	var start: int = NavigationServer3D.map_get_iteration_id(_nav_map())
	for i: int in range(max_frames):
		await tree().physics_frame
		await tree().process_frame
		if NavigationServer3D.map_get_iteration_id(_nav_map()) != start:
			break
	await await_sync(settle)


# --- props ---------------------------------------------------------------------------------

func prop_of(obj: Object) -> LcProp:
	var n: Node = obj as Node
	while n != null and n != map:
		var id: int = n.get_instance_id()
		if _prop_by_id.has(id):
			return _prop_by_id[id]
		n = n.get_parent()
	return null


func props_of_kind(kinds: Array) -> Array[LcProp]:
	var out: Array[LcProp] = []
	for p: LcProp in props:
		if p.kind in kinds and is_active(p.node):
			out.append(p)
	return out


## mode: 0 = outside content folders (meta/group props only), 1 = under Props (any content root),
## 2 = under Gameplay / Lighting / Variants (content roots that carry geometry).
func _scan(n: Node, mode: int) -> void:
	for c: Node in n.get_children():
		if n == map and c.name == &"Geometry":
			continue
		var cm: int = mode
		if n == map:
			cm = 1 if c.name == &"Props" else (2 if c.name in CONTENT_FOLDERS else 0)
		var c3: Node3D = c as Node3D
		if LcUtil.lc_ignored(c):
			continue
		if c3 != null and _is_prop_root(c3, cm):
			_add_prop(c3)
			continue
		_scan(c, cm)


func _is_prop_root(n: Node3D, mode: int) -> bool:
	if n is Light3D or n is Marker3D or n is Area3D or n is Camera3D or n is VariantSlot \
			or n is NavigationRegion3D or n is NavigationLink3D or n is PatrolGraph:
		return false
	if n.is_in_group(&"prop") or n.is_in_group(&"fixture") or PROP_METAS.any(func(m: StringName) -> bool: return n.has_meta(m)):
		return true
	if mode == 0:
		return false
	var content: bool = n.scene_file_path != "" or n is GeometryInstance3D or n is CollisionObject3D
	if not content or mode == 1:
		return content
	return n is GeometryInstance3D or not n.find_children("*", "GeometryInstance3D", true, false).is_empty()


func _add_prop(n: Node3D) -> void:
	var p: LcProp = LcProp.new()
	p.node = n
	p.xform = n.global_transform
	p.kind = LcUtil.meta_s(n, &"kind")
	p.mount = LcUtil.meta_s(n, &"mount")
	p.is_support = LcUtil.meta_b(n, &"support")
	p.is_window = p.kind == &"window"
	p.is_door = p.kind in [&"door", &"vault_door", &"industrial_door", &"shutter", &"hatch"] \
		or n.find_child("Leaf", true, false) != null
	p.slot = LcUtil.slot_of(n)
	var inv: Transform3D = p.xform.affine_inverse()
	var first: bool = true
	var nodes: Array[Node] = [n]
	nodes.append_array(n.find_children("*", "", true, false))
	for c: Node in nodes:
		if LcUtil.lc_ignored(c):   # cable / FX-only meshes (meta lc_ignore): no prop extent, clipping or support
			continue
		var box: Variant = LcVisual.geometry_local_aabb(c)
		if box is AABB:
			var rel: AABB = (inv * (c as Node3D).global_transform) * (box as AABB)
			p.local_aabb = rel if first else p.local_aabb.merge(rel)
			first = false
			p.has_visuals = true
		var co: CollisionObject3D = c as CollisionObject3D
		if co != null and not (co is Area3D):
			p.bodies.append(co)
			p.rids.append(co.get_rid())
		var cs: CollisionShape3D = c as CollisionShape3D
		# GN-C2: a bag_lift's CarBody (ENV A: the moving car floor slab, under the car origin) rests in the landing's
		# floor by design; it is no clipping / support geometry of the prop
		if cs != null and cs.get_parent().name == &"CarBody" and cs.get_parent() is AnimatableBody3D:
			continue
		if cs != null and not cs.disabled and cs.shape != null and cs.get_parent() is CollisionObject3D \
				and not (cs.get_parent() is Area3D):
			p.shapes.append({"shape": cs.shape, "xf": cs.global_transform})
	if first:
		for s: Dictionary in p.shapes:
			var sb: AABB = (s["shape"] as Shape3D).get_debug_mesh().get_aabb()
			var rel2: AABB = (inv * (s["xf"] as Transform3D)) * sb
			p.local_aabb = rel2 if first else p.local_aabb.merge(rel2)
			first = false
	p.has_geometry = not first
	p.global_aabb = p.xform * p.local_aabb
	p.obb = LcGeom.obb(p.xform, p.local_aabb)
	props.append(p)
	_prop_by_id[n.get_instance_id()] = p


func _collect_doors() -> void:
	doors.clear()
	var seen: Dictionary = {}
	for p: LcProp in props:
		if p.is_door:
			seen[p.node.get_instance_id()] = true
			doors.append(p.node)
	for leaf: Node in map.find_children("Leaf", "Node3D", true, false):
		var root: Node = leaf
		var cur: Node = leaf.get_parent()
		while cur != null and cur != map:
			if prop_of(cur) != null:
				root = prop_of(cur).node
				break
			var par: Node = cur.get_parent()
			if par is VariantSlot or (par == map) or (par != null and par.get_parent() == map and par.name in CONTAINERS):
				root = cur
				break
			cur = par
		if not seen.has(root.get_instance_id()) and root is Node3D:
			seen[root.get_instance_id()] = true
			doors.append(root as Node3D)


# --- variants ------------------------------------------------------------------------------

func is_active(n: Node) -> bool:
	if _active.is_empty():
		return true
	var cur: Node = n
	while cur != null and cur != map:
		if cur is VariantSlot and not bool(_active.get(cur.get_instance_id(), true)):
			return false
		cur = cur.get_parent()
	return true


func variant_slots() -> Array[VariantSlot]:
	var out: Array[VariantSlot] = []
	for n: Node in map.find_children("*", "VariantSlot", true, false):
		out.append(n as VariantSlot)
	return out


## active: { VariantSlot: bool }. Slots absent from the dict stay active. Toggles navigation
## regions/links inside slots, then waits for nav sync. Pass {} to reset (all active).
func set_variant_config(active: Dictionary) -> void:
	_active.clear()
	cache.clear()
	for s: Variant in active.keys():
		_active[(s as Node).get_instance_id()] = bool(active[s])
	for slot: VariantSlot in variant_slots():
		var on: bool = bool(_active.get(slot.get_instance_id(), true))
		for r: Node in slot.find_children("*", "NavigationRegion3D", true, false):
			(r as NavigationRegion3D).enabled = on
		for l: Node in slot.find_children("*", "NavigationLink3D", true, false):
			(l as NavigationLink3D).enabled = on
	await await_sync(4)


# --- rays ----------------------------------------------------------------------------------

## Ray cast that skips hits rejected by `accept(hit) -> bool` (re-casts excluding them).
func ray(from: Vector3, to: Vector3, accept: Callable = Callable(), mask: int = QUERY_MASK) -> Dictionary:
	var ex: Array[RID] = []
	for i: int in range(24):
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, mask, ex)
		var hit: Dictionary = space().intersect_ray(q)
		if hit.is_empty():
			return {}
		if not accept.is_valid() or bool(accept.call(hit)):
			return hit
		ex.append(hit["rid"])
	return {}


## Accepts only building-shell hits: not a prop (doors/windows/stairs props count as shell),
## not inside an inactive variant slot.
func accept_shell(hit: Dictionary) -> bool:
	var obj: Object = hit.get("collider")
	if obj == null:
		return true
	var p: LcProp = prop_of(obj)
	if p != null and (p.kind == SHUTTER_KIND or not (p.kind in SHELL_KINDS or p.is_door)):
		return false
	return is_active(obj as Node)


func accept_any_active(hit: Dictionary) -> bool:
	var obj: Object = hit.get("collider")
	return obj == null or is_active(obj as Node)


## Floor below p (shell only). Returns {} or the hit dictionary.
func shell_floor(p: Vector3, up: float = 1.0, down: float = 1.0) -> Dictionary:
	return ray(p + Vector3.UP * up, p + Vector3.DOWN * down, accept_shell)


## Smallest room (by footprint) containing p, or null.
func room_at(p: Vector3) -> RoomVolume:
	var best: RoomVolume = null
	var best_area: float = INF
	for r: RoomVolume in rooms:
		if LcAreas.contains(r, p, 0.01):
			var ar: float = LcAreas.footprint(r)
			if ar < best_area or (is_equal_approx(ar, best_area) and best != null and String(r.name) < String(best.name)):
				best = r
				best_area = ar
	return best


# --- navigation ----------------------------------------------------------------------------

func has_navmesh() -> bool:
	return nav_region != null and nav_region.navigation_mesh != null \
		and nav_region.navigation_mesh.get_polygon_count() > 0


func nav_closest(p: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(_nav_map(), p)


## All navigation layers on purpose: reachability is crew reachability, and a masked unburdened player can
## climb ladders (layer "ladder", Ladder.NAV_LAYER) and use vents. Bag / police routes use layer 1 only.
func nav_path(a: Vector3, b: Vector3) -> PackedVector3Array:
	return NavigationServer3D.map_get_path(_nav_map(), a, b, true, 0xFFFFFFFF)


## Centroids of all navmesh polygons of every enabled region in the map (world space).
func navmesh_centroids() -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for n: Node in map.find_children("*", "NavigationRegion3D", true, false):
		var r: NavigationRegion3D = n
		if r.navigation_mesh == null or not r.enabled or not is_active(r):
			continue
		var nm: NavigationMesh = r.navigation_mesh
		var verts: PackedVector3Array = nm.get_vertices()
		var xf: Transform3D = r.global_transform
		for i: int in range(nm.get_polygon_count()):
			var poly: PackedInt32Array = nm.get_polygon(i)
			var c: Vector3 = Vector3.ZERO
			for vi: int in poly:
				c += verts[vi]
			out.append(xf * (c / float(maxi(1, poly.size()))))
	return out


# --- kits ----------------------------------------------------------------------------------

func load_kit(kit_id: StringName) -> DressingKit:
	for d: String in kit_dirs:
		var path: String = "%s/%s.tres" % [d, kit_id]
		if ResourceLoader.exists(path):
			return load(path) as DressingKit
	return null


