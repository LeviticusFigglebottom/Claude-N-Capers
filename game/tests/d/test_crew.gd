## D2-03: the four playable heisters Rook, Sable, Dutch and Wren (tools/blender/characters/char_crew.py,
## _crew_heisters.py). Checks the assembled scenes (docs/contracts/characters.md: Root > Skeleton3D
## with skinned meshes and the HandR/HandL/Head/Back/Hip BoneAttachment3D markers with a Socket),
## that every surface resolves to a library material in world/materials, the triangle budget, that the
## Head socket is at the face centre and a gilded and three base masks seat on every face without the
## outfit poking into them, the Hip seat on the right hip, and that the four read apart (one signature
## material each, Dutch the tallest, Wren the shortest, only Rook's coat reaching below the knee).
## Regenerate with tools/blender/characters/assemble.sh.
extends TestCase

const Spec: GDScript = preload("res://world/characters/_tools/character_spec.gd")

const CREW: Array[String] = [
	"char_crew_rook",
	"char_crew_sable",
	"char_crew_dutch",
	"char_crew_wren",
	"char_crew_marten",
	"char_crew_jay",
	"char_crew_juno",
	"char_crew_hale",
]
## Each heister's signature garment material: only that heister wears it.
const SIGNATURE: Dictionary = {
	"char_crew_rook": "res://world/materials/char_crew_rook_coat.tres",
	"char_crew_sable": "res://world/materials/char_crew_sable_blazer.tres",
	"char_crew_dutch": "res://world/materials/char_crew_dutch_bomber.tres",
	"char_crew_wren": "res://world/materials/char_crew_wren_vest.tres",
	"char_crew_marten": "res://world/materials/char_crew_marten_parka.tres",
	"char_crew_jay": "res://world/materials/char_crew_jay_jacket.tres",
	"char_crew_juno": "res://world/materials/char_crew_juno_jacket.tres",
	"char_crew_hale": "res://world/materials/char_crew_hale_jacket.tres",
}
const MASKS: Array[String] = [
	"res://assets/masks/mask_gilded_heron/mask_gilded_heron.glb",
	"res://assets/masks/mask_base_vulpine/mask_base_vulpine.glb",
	"res://assets/masks/mask_base_bruiser/mask_base_bruiser.glb",
	"res://assets/masks/mask_base_owl/mask_base_owl.glb",
]
const TRI_BUDGET: int = 35000
const MIN_HEIGHT: float = 1.6
const MAX_HEIGHT: float = 2.0
const ALLOWED_MESHES: Array[String] = ["Body", "Hair", "Outfit", "Gear", "Headwear"]
## Garment vertices allowed inside a mask's box (shrunk by MASK_INSET, above the chin) before it
## counts as the outfit poking through the mask.
const MASK_INSET: float = 0.01
const MASK_POKE_MAX: int = 0
## Rook's long coat hem (and nobody else's garment) reaches below this height (m, ~knee).
const KNEE_Y: float = 0.55

var _index: Dictionary = {}


func before_all() -> void:
	for e: Dictionary in Spec.read_index():
		_index[String(e.get("asset", ""))] = e


func _instance(asset_id: String) -> Node3D:
	var path: String = Spec.scene_path(asset_id)
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		fail("could not load %s (run tools/blender/characters/assemble.sh)" % path)
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


## Lowest rest-pose vertex of the surfaces using ``material_path`` (a garment's hem), INF if none.
func _surface_min_y(root: Node3D, material_path: String) -> float:
	var low: float = INF
	for mi: MeshInstance3D in _meshes(root):
		for s: int in range(mi.mesh.get_surface_count()):
			var m: Material = mi.get_active_material(s)
			if m == null or m.resource_path != material_path:
				continue
			for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
				low = minf(low, (mi.transform * v).y)
	return low


func test_index_lists_every_heister() -> void:
	for id: String in CREW:
		assert_true(_index.has(id), "%s in characters.json" % id)
		if not _index.has(id):
			continue
		var e: Dictionary = _index[id]
		assert_eq(String(e["scene"]), "%s%s/%s.tscn" % [Spec.OUT_DIR, Spec.character_id(id), Spec.character_id(id)],
				"%s: scene path convention" % id)
		assert_false(bool(e.get("test", false)), "%s: cast, not a test fixture" % id)
		assert_true(ResourceLoader.exists(String(e["scene"])), "%s: scene exists" % id)


func test_scene_contract_and_budget() -> void:
	for id: String in CREW:
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
		for need: String in ["Body", "Hair", "Outfit", "Gear"]:
			assert_has(names, need, "%s: has %s" % [id, need])
		assert_true(tris > 5000 and tris <= TRI_BUDGET, "%s: %d triangles within %d" % [id, tris, TRI_BUDGET])
		var h: float = _height(root)
		assert_true(h >= MIN_HEIGHT and h <= MAX_HEIGHT, "%s: height %.3f m" % [id, h])
		root.queue_free()


func test_materials_resolve_to_the_library() -> void:
	for id: String in CREW:
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


## The mask seats on Head/Socket (face centre, identity basis) and must cover the face of every
## heister, whatever the body (gender, build, height): spans the eye line, covers both eyes, sits in
## front of the nose bridge, and no collar, scarf, headphones or earring pokes into it.
func test_masks_seat_on_every_face() -> void:
	for id: String in CREW:
		var root: Node3D = _instance(id)
		if root == null:
			continue
		var skel: Skeleton3D = root.get_node("Skeleton3D") as Skeleton3D
		var head: int = skel.find_bone("head")
		var socket: Node3D = skel.get_node("Head/" + Spec.SOCKET_NAME) as Node3D
		var k: float = skel.get_bone_global_rest(head).origin.y / Spec.DEFAULT_HEAD_Y
		var at: Transform3D = skel.get_bone_global_rest(head) * socket.transform
		var face: Vector3 = (Spec.SOCKET_POINTS["Head"] as Vector3) * k
		assert_true(at.origin.distance_to(face) < 0.002, "%s: Head socket at the face centre (%s)" % [id, at.origin])
		assert_true(at.basis.is_equal_approx(Basis.IDENTITY), "%s: Head socket faces -Z, +Y up" % id)
		for mask_path: String in MASKS:
			var packed: PackedScene = load(mask_path) as PackedScene
			if packed == null:
				fail("%s: no mask %s" % [id, mask_path])
				continue
			var tag: String = "%s + %s" % [id, mask_path.get_file().get_basename()]
			var mask: Node3D = packed.instantiate() as Node3D
			socket.add_child(mask)
			await wait_frames(1)
			var box: AABB = AABB()
			var first: bool = true
			for n: Node in mask.find_children("*", "MeshInstance3D", true, false):
				var mi: MeshInstance3D = n as MeshInstance3D
				var b: AABB = root.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
				box = b if first else box.merge(b)
				first = false
			var eye_y: float = 1.666 * k
			assert_true(box.position.y < eye_y - 0.05 and box.end.y > eye_y + 0.05, "%s: mask spans the eye line" % tag)
			assert_true(box.position.x < -0.06 and box.end.x > 0.06, "%s: mask covers both eyes" % tag)
			assert_true(box.position.z < -0.096 * k, "%s: mask shell in front of the nose bridge" % tag)
			var inner: AABB = box.grow(-MASK_INSET)
			inner.position.y = maxf(inner.position.y, eye_y - 0.06 * k)
			inner.size.y = maxf(box.end.y - MASK_INSET - inner.position.y, 0.0)
			var poke: int = 0
			for mi: MeshInstance3D in _meshes(root):
				if not ["Outfit", "Gear", "Headwear"].has(String(mi.name)):
					continue
				for s: int in range(mi.mesh.get_surface_count()):
					for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
						var p: Vector3 = mi.transform * v
						if inner.has_point(p) and p.z < at.origin.z + 0.02:
							poke += 1
			assert_true(poke <= MASK_POKE_MAX, "%s: %d garment vertices inside the mask" % [tag, poke])
			mask.queue_free()
		root.queue_free()


## Hip (pager) on the right hip at belt height; Back = the carried bag's pivot (D-116): behind the back by the
## medium bag's height, the bag's up (socket +Y) facing forward onto the back, its length running down to the right.
func test_hip_and_back_seats() -> void:
	for id: String in CREW:
		var root: Node3D = _instance(id)
		if root == null:
			continue
		var skel: Skeleton3D = root.get_node("Skeleton3D") as Skeleton3D
		for marker: String in ["Hip", "Back"]:
			var att: BoneAttachment3D = skel.get_node_or_null(marker) as BoneAttachment3D
			var socket: Node3D = skel.get_node_or_null(marker + "/" + Spec.SOCKET_NAME) as Node3D
			if att == null or socket == null:
				fail("%s: %s/Socket" % [id, marker])
				continue
			var xf: Transform3D = skel.get_bone_global_rest(skel.find_bone(att.bone_name)) * socket.transform
			var p: Vector3 = xf.origin
			if marker == "Hip":
				assert_true(p.x > 0.10 and p.y > 0.85 and p.y < 1.15, "%s: Hip on the right hip (%s)" % [id, p])
			else:
				assert_true(p.z > 0.35 and p.z < 0.60 and p.y > 1.0 and p.y < 1.4, "%s: Back = bag pivot (%s)" % [id, p])
				assert_true(xf.basis.y.normalized().dot(Vector3.FORWARD) > 0.99, "%s: the bag's top faces the back" % id)
				var length: Vector3 = xf.basis.x.normalized()
				assert_true(length.x > 0.5 and length.y < -0.6, "%s: the bag runs down to the right (%s)" % [id, length])
		root.queue_free()


## The four must read apart: each wears a signature material nobody else in the crew wears, Dutch is
## the tallest, Wren the shortest, and only Rook's coat reaches below the knee.
func test_heisters_read_apart() -> void:
	var heights: Dictionary = {}
	var users: Dictionary = {}
	for id: String in CREW:
		var root: Node3D = _instance(id)
		if root == null:
			continue
		heights[id] = _height(root)
		for mi: MeshInstance3D in _meshes(root):
			for s: int in range(mi.mesh.get_surface_count()):
				var m: Material = mi.get_active_material(s)
				if m == null:
					continue
				var arr: Array = users.get(m.resource_path, [])
				if not arr.has(id):
					arr.append(id)
				users[m.resource_path] = arr
		var coat_low: float = _surface_min_y(root, String(SIGNATURE["char_crew_rook"]))
		if id == "char_crew_rook":
			assert_true(coat_low < KNEE_Y, "Rook's coat reaches below the knee (hem %.2f m)" % coat_low)
		var sig_low: float = _surface_min_y(root, String(SIGNATURE[id]))
		if id != "char_crew_rook":
			assert_true(sig_low > KNEE_Y, "%s: signature garment above the knee (%.2f m)" % [id, sig_low])
		root.queue_free()
	for id: String in CREW:
		var who: Array = users.get(String(SIGNATURE[id]), [])
		assert_eq(who, [id], "%s: only %s wears %s" % [id, id, SIGNATURE[id]])
	if heights.size() == CREW.size():
		for id: String in CREW:
			if id != "char_crew_dutch":
				assert_true(float(heights["char_crew_dutch"]) > float(heights[id]), "Dutch taller than %s" % id)
			if id != "char_crew_wren":
				assert_true(float(heights["char_crew_wren"]) < float(heights[id]), "Wren shorter than %s" % id)
