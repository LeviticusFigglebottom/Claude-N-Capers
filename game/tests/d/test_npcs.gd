## D2-02 / D-063: heist NPCs (tools/blender/characters/char_npc_bank.py, char_npc_penthouse.py,
## char_npc_calder.py). Checks the assembled scenes (docs/contracts/characters.md: Root > Skeleton3D
## with skinned meshes and the HandR/HandL/Head/Back/Hip BoneAttachment3D markers with a Socket),
## that every surface resolves to a library material in world/materials, the triangle budget,
## plausible heights, that every guard's Hip socket sits on his belt radio (the pager seat), that
## the bank guard wears Halden livery and the Northgate detail does not, that Kessler (both looks)
## stands out (tallest, the only ones in the ice accent), and the IT contractor's lanyard and bag.
## Regenerate with tools/blender/characters/assemble.sh.
extends TestCase

const Spec: GDScript = preload("res://world/characters/_tools/character_spec.gd")

const NPCS: Array[String] = [
	"char_npc_bank_teller",
	"char_npc_bank_teller_b",
	"char_npc_bank_night_manager",
	"char_npc_bank_cleaner",
	"char_npc_bank_guard",
	"char_npc_penthouse_guest_a",
	"char_npc_penthouse_guest_b",
	"char_npc_penthouse_staff",
	"char_npc_kessler",
	"char_npc_kessler_coat",
	"char_npc_cleaner_sl",
	"char_npc_it_contractor",
	"char_npc_northgate_guard",
	"char_npc_northgate_guard_b",
	"char_npc_helena_moor",
]
const GUARD: String = "char_npc_bank_guard"
## Every NPC whose pager is answered at Hip/Socket (the radio on the belt).
const RADIO_GUARDS: Array[String] = ["char_npc_bank_guard", "char_npc_northgate_guard", "char_npc_northgate_guard_b"]
const NORTHGATE: Array[String] = ["char_npc_northgate_guard", "char_npc_northgate_guard_b"]
const TARGETS: Array[String] = ["char_npc_kessler", "char_npc_kessler_coat"]
## Kessler's recognisability accent: the ice coat (coat look) and the ice-silk robe (default look).
const TARGET_MATERIALS: Array[String] = [
	"res://world/materials/char_coat_ice.tres",
	"res://world/materials/char_silk_ice.tres",
]
const MAT_DIR: String = "res://world/materials/"
## Halden Security livery (char_security_officer): steel-blue shirt, charcoal, burgundy patch, gold.
const HALDEN: Array[String] = ["char_sec_shirt", "char_sec_charcoal", "char_sec_burgundy", "brass"]
const TRI_BUDGET: int = 35000
const MIN_HEIGHT: float = 1.6
const MAX_HEIGHT: float = 2.0
const ALLOWED_MESHES: Array[String] = ["Body", "Hair", "Outfit", "Gear", "Headwear"]
## The radio is a ~6 x 10 cm box on the belt and the socket sits on its face, so its corners are a
## few cm away: the socket needs a radio-sized cluster of gear vertices around it.
const RADIO_REACH: float = 0.07
const RADIO_CLUSTER: float = 0.10
const RADIO_MIN_VERTS: int = 8

var _index: Dictionary = {}


func before_all() -> void:
	for e: Dictionary in Spec.read_index():
		_index[String(e.get("asset", ""))] = e


func _scene(asset_id: String) -> String:
	return Spec.scene_path(asset_id)


func _instance(asset_id: String) -> Node3D:
	var packed: PackedScene = load(_scene(asset_id)) as PackedScene
	if packed == null:
		fail("could not load %s (run tools/blender/characters/assemble.sh)" % _scene(asset_id))
		return null
	var root: Node3D = packed.instantiate() as Node3D
	add_child(root)
	return root


func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		if String(n.name) != "CrowdLod":  # D4-01 LOD2 proxy: checked by test_lod.gd
			out.append(n as MeshInstance3D)
	return out


func _tris(mesh: Mesh) -> int:
	var n: int = 0
	for s: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(s)
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		n += idx.size() / 3 if idx.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


func _height(root: Node3D) -> float:
	var box: AABB = AABB()
	var first: bool = true
	for mi: MeshInstance3D in _meshes(root):
		var b: AABB = mi.transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box.end.y


func test_index_lists_every_npc() -> void:
	for id: String in NPCS:
		assert_true(_index.has(id), "%s in characters.json" % id)
		if not _index.has(id):
			continue
		var e: Dictionary = _index[id]
		assert_eq(String(e["scene"]), "%s%s/%s.tscn" % [Spec.OUT_DIR, Spec.character_id(id), Spec.character_id(id)],
				"%s: scene path convention" % id)
		assert_false(bool(e.get("test", false)), "%s: cast, not a test fixture" % id)
		assert_true(ResourceLoader.exists(String(e["scene"])), "%s: scene exists" % id)


func test_scene_contract_and_budget() -> void:
	for id: String in NPCS:
		var root: Node3D = _instance(id)
		if root == null:
			continue
		var skel: Skeleton3D = root.get_node_or_null("Skeleton3D") as Skeleton3D
		assert_true(skel != null, "%s: Root/Skeleton3D" % id)
		if skel == null:
			root.queue_free()
			continue
		assert_eq(skel.get_bone_count(), Spec.contract_bones().size(), "%s: contract bones" % id)
		assert_true(root.get_node_or_null("AnimationPlayer") is AnimationPlayer, "%s: AnimationPlayer" % id)
		for marker: String in Spec.MARKERS:
			var att: BoneAttachment3D = skel.get_node_or_null(marker) as BoneAttachment3D
			assert_true(att != null, "%s: %s marker" % [id, marker])
			if att != null:
				assert_true(att.get_node_or_null(Spec.SOCKET_NAME) is Marker3D, "%s: %s/Socket" % [id, marker])
		var tris: int = 0
		var names: Array[String] = []
		for mi: MeshInstance3D in _meshes(root):
			names.append(String(mi.name))
			assert_has(ALLOWED_MESHES, String(mi.name), "%s: unexpected mesh %s" % [id, mi.name])
			assert_true(mi.get_parent() == skel, "%s/%s: child of Skeleton3D" % [id, mi.name])
			assert_true(mi.skin != null, "%s/%s: skinned" % [id, mi.name])
			tris += _tris(mi.mesh)
		for need: String in ["Body", "Outfit"]:
			assert_has(names, need, "%s: has %s" % [id, need])
		assert_true(tris > 5000 and tris <= TRI_BUDGET, "%s: %d triangles within %d" % [id, tris, TRI_BUDGET])
		var h: float = _height(root)
		assert_true(h >= MIN_HEIGHT and h <= MAX_HEIGHT, "%s: height %.3f m" % [id, h])
		root.queue_free()


func test_materials_resolve_to_the_library() -> void:
	for id: String in NPCS:
		var root: Node3D = _instance(id)
		if root == null:
			continue
		for mi: MeshInstance3D in _meshes(root):
			for s: int in range(mi.mesh.get_surface_count()):
				var m: Material = mi.get_active_material(s)
				assert_true(m != null, "%s/%s surface %d: material" % [id, mi.name, s])
				if m == null:
					continue
				var path: String = m.resource_path
				var ok: bool = path.begins_with("res://world/materials/") and path.ends_with(".tres")
				assert_true(ok and ResourceLoader.exists(path), "%s/%s surface %d: %s" % [id, mi.name, s, path])
		root.queue_free()


## The pager is answered at Hip/Socket: on every guard it must sit on the belt radio (right hip), as
## on the Halden officer.
func test_guard_hip_socket_is_on_the_radio() -> void:
	for id: String in RADIO_GUARDS:
		_check_radio(id)


func _check_radio(id: String) -> void:
	var root: Node3D = _instance(id)
	if root == null:
		return
	var skel: Skeleton3D = root.get_node("Skeleton3D") as Skeleton3D
	var att: BoneAttachment3D = skel.get_node_or_null("Hip") as BoneAttachment3D
	var socket: Node3D = skel.get_node_or_null("Hip/" + Spec.SOCKET_NAME) as Node3D
	assert_true(att != null and socket != null, "%s: Hip/Socket" % id)
	if socket == null:
		root.queue_free()
		return
	var bone: int = skel.find_bone(att.bone_name)
	var p: Vector3 = (skel.get_bone_global_rest(bone) * socket.transform).origin
	assert_true(p.x > 0.10, "%s: Hip socket on the right hip (x = %.3f)" % [id, p.x])
	assert_true(p.y > 0.85 and p.y < 1.15, "%s: Hip socket at belt height (y = %.3f)" % [id, p.y])
	var gear: MeshInstance3D = skel.get_node_or_null("Gear") as MeshInstance3D
	assert_true(gear != null, "%s: Gear mesh (radio)" % id)
	if gear != null:
		var best: float = INF
		var near: int = 0
		for s: int in range(gear.mesh.get_surface_count()):
			var verts: PackedVector3Array = gear.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for v: Vector3 in verts:
				var d: float = (gear.transform * v).distance_to(p)
				best = minf(best, d)
				if d < RADIO_CLUSTER:
					near += 1
		assert_true(best < RADIO_REACH, "%s: Hip socket on the radio (nearest gear %.3f m)" % [id, best])
		assert_true(near >= RADIO_MIN_VERTS, "%s: radio-sized gear cluster at Hip (%d verts)" % [id, near])
	root.queue_free()


## Material ids (file names without .tres) per mesh name, for one NPC.
func _materials(id: String) -> Dictionary:
	var out: Dictionary = {}
	var root: Node3D = _instance(id)
	if root == null:
		return out
	for mi: MeshInstance3D in _meshes(root):
		var names: Array[String] = []
		for s: int in range(mi.mesh.get_surface_count()):
			var m: Material = mi.get_active_material(s)
			if m != null and m.resource_path.begins_with(MAT_DIR):
				names.append(m.resource_path.get_file().get_basename())
		out[String(mi.name)] = names
	root.queue_free()
	return out


func _all_materials(by_mesh: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for mesh: String in by_mesh:
		for m: String in by_mesh[mesh]:
			if not out.has(m):
				out.append(m)
	return out


## D-063: the Night Deposit guard is the contracted Halden Security guard, not bank livery.
func test_bank_guard_wears_halden_livery() -> void:
	var mats: Array[String] = _all_materials(_materials(GUARD))
	for need: String in HALDEN:
		assert_has(mats, need, "bank guard wears Halden %s" % need)
	for m: String in mats:
		assert_false(m.begins_with("char_bank_"), "bank guard: no bank livery (%s)" % m)


## Shadow Ledger's detail is Northgate Executive Protection: a second company, never Halden colours.
func test_northgate_is_not_halden() -> void:
	for id: String in NORTHGATE:
		var by_mesh: Dictionary = _materials(id)
		var mats: Array[String] = _all_materials(by_mesh)
		for m: String in mats:
			assert_false(m.begins_with("char_sec_"), "%s: no Halden material (%s)" % [id, m])
		assert_has(by_mesh.get("Gear", []) as Array, "char_ng_enamel", "%s: Northgate lapel pin" % id)


func test_it_contractor_has_lanyard_and_bag() -> void:
	var by_mesh: Dictionary = _materials("char_npc_it_contractor")
	var gear: Array = by_mesh.get("Gear", []) as Array
	assert_has(gear, "char_tac_gear", "IT contractor: messenger tool bag (Gear)")
	assert_has(gear, "char_medic_white", "IT contractor: badge card (Gear)")
	assert_has(_all_materials(by_mesh), "char_lanyard", "IT contractor: lanyard")


func test_helena_moor_look() -> void:
	var by_mesh: Dictionary = _materials("char_npc_helena_moor")
	assert_has(by_mesh.get("Outfit", []) as Array, "char_silk_ivory", "Helena: ivory silk blouse")
	assert_true(by_mesh.has("Headwear"), "Helena: reading glasses (Headwear)")


## Players must find Kessler in a crowd: in both looks the tallest NPC and the only one wearing the
## ice accent (the coat or the robe).
func test_kessler_stands_out() -> void:
	var heights: Dictionary = {}
	var accent_users: Array[String] = []
	for id: String in NPCS:
		var root: Node3D = _instance(id)
		if root == null:
			continue
		heights[id] = _height(root)
		for mi: MeshInstance3D in _meshes(root):
			for s: int in range(mi.mesh.get_surface_count()):
				var m: Material = mi.get_active_material(s)
				if m != null and TARGET_MATERIALS.has(m.resource_path) and not accent_users.has(id):
					accent_users.append(id)
		root.queue_free()
	accent_users.sort()
	var want: Array[String] = TARGETS.duplicate()
	want.sort()
	assert_eq(accent_users, want, "only the Kessler looks wear the ice accent: %s" % [accent_users])
	for t: String in TARGETS:
		if not heights.has(t):
			continue
		for id: String in heights:
			if not TARGETS.has(id):
				assert_true(float(heights[t]) > float(heights[id]), "%s taller than %s" % [t, id])
