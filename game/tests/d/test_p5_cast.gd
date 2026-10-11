## D3-01: the P5 heist casts (tools/blender/characters/char_p5_gallery.py, char_p5_bank.py,
## char_p5_convoy.py, char_p5_club.py) and the cast index world/characters/p5_cast.json. Checks the
## new assembled scenes against the character contract (docs/contracts/characters.md: Root >
## Skeleton3D with skinned meshes and the HandR/HandL/Head/Back/Hip BoneAttachment3D markers with a
## Socket), that every surface resolves to a library material, the triangle budget and plausible
## heights; that the cast index covers the four P5 heists and every role, points only at existing
## scenes and lists every new character; that every pager-carrying guard's Hip socket sits on a belt
## radio (and the pager roles, incl. club_bouncer); and the liveries: the gallery and armoured-car
## companies are neither Halden, Northgate nor police, the curator is the only pale suit at the gala
## and the Ostrander bank officers (D-075) wear the bank lanyard over grey. Regenerate with
## tools/blender/characters/assemble.sh.
extends TestCase

const Spec: GDScript = preload("res://world/characters/_tools/character_spec.gd")

const CAST_PATH: String = "res://world/characters/p5_cast.json"
## Characters built for D3-01 (asset ids).
const NEW: Array[String] = [
	"char_gallery_curator",
	"char_gallery_attendant",
	"char_gallery_attendant_b",
	"char_gallery_guard",
	"char_gallery_guard_b",
	"char_gallery_patron",
	"char_gallery_patron_b",
	"char_bank_manager",
	"char_bank_officer",
	"char_bank_officer_b",
	"char_bank_customer",
	"char_bank_customer_b",
	"char_armored_car_crew",
	"char_armored_car_crew_b",
	"char_club_bouncer",
	"char_club_bouncer_b",
	"char_club_bartender",
	"char_club_bartender_b",
	"char_club_dj",
	"char_club_patron",
	"char_club_patron_b",
	"char_club_patron_c",
	"char_club_patron_d",
]
## heist -> roles the index must carry (D3-01 brief; D-075 renamed meridian_federal and added
## bank_officer).
const ROLES: Dictionary = {
	"gallery_night": ["gallery_curator", "gallery_attendant", "gallery_guard", "gallery_patron"],
	"ostrander_federal": ["bank_teller", "bank_manager", "bank_officer", "bank_guard", "bank_customer"],
	"rolling_thunder": ["armored_car_crew", "convoy_escort"],
	"afterhours": ["club_bouncer", "club_bartender", "club_dj", "club_patron"],
}
## Minimum ids per role where the brief asks for several.
const MIN_COUNT: Dictionary = {
	"gallery_attendant": 2, "gallery_patron": 4, "bank_teller": 2, "bank_officer": 2, "bank_customer": 4, "armored_car_crew": 2,
	"club_bouncer": 2, "club_bartender": 2, "club_patron": 4,
}
## New characters whose pager is answered at Hip/Socket (a belt radio).
const RADIO: Array[String] = [
	"char_gallery_guard", "char_gallery_guard_b", "char_armored_car_crew", "char_armored_car_crew_b",
	"char_club_bouncer_b",
]
## Roles whose bodies carry a pager (p5_cast.json pager_roles; club_bouncer per QC-70).
const PAGER_ROLES: Array[String] = ["gallery_guard", "bank_guard", "armored_car_crew", "club_bouncer"]
## New pager-role characters without a modelled radio: the pager is answered at the default hip
## seat (club_bouncer's radio is under the bomber, not modelled; see the cast notes).
const NO_RADIO: Array[String] = ["char_club_bouncer"]
const TRI_BUDGET: int = 35000
const MIN_HEIGHT: float = 1.6
const MAX_HEIGHT: float = 2.0
const ALLOWED_MESHES: Array[String] = ["Body", "Hair", "Outfit", "Gear", "Headwear"]
const MAT_DIR: String = "res://world/materials/"
const RADIO_REACH: float = 0.07
const RADIO_CLUSTER: float = 0.10
const RADIO_MIN_VERTS: int = 8
## Other companies' and the police's liveries: the gallery and Vaultline must not wear them.
const OTHER_LIVERY: Array[String] = ["char_sec_", "char_ng_", "char_police_", "char_hivis", "char_tac_", "char_bank_"]
const CURATOR_SUIT: String = "char_gallery_bone"

var _index: Dictionary = {}
var _cast: Dictionary = {}


func before_all() -> void:
	for e: Dictionary in Spec.read_index():
		_index[String(e.get("asset", ""))] = e
	var f: FileAccess = FileAccess.open(CAST_PATH, FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_cast = parsed


func _instance(asset_id: String) -> Node3D:
	var packed: PackedScene = load(Spec.scene_path(asset_id)) as PackedScene
	if packed == null:
		fail("could not load %s (run tools/blender/characters/assemble.sh)" % Spec.scene_path(asset_id))
		return null
	var root: Node3D = packed.instantiate() as Node3D
	add_child(root)
	return root


func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
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


## Material ids (file names without .tres) used by one character.
func _materials(asset_id: String) -> Array[String]:
	var out: Array[String] = []
	var root: Node3D = _instance(asset_id)
	if root == null:
		return out
	for mi: MeshInstance3D in _meshes(root):
		for s: int in range(mi.mesh.get_surface_count()):
			var m: Material = mi.get_active_material(s)
			if m != null and m.resource_path.begins_with(MAT_DIR):
				var id: String = m.resource_path.get_file().get_basename()
				if not out.has(id):
					out.append(id)
	root.queue_free()
	return out


func _role_ids(heist: String, role: String) -> Array:
	var heists: Dictionary = _cast.get("heists", {}) as Dictionary
	return (heists.get(heist, {}) as Dictionary).get(role, []) as Array


func test_index_lists_every_new_character() -> void:
	for id: String in NEW:
		assert_true(_index.has(id), "%s in characters.json" % id)
		if not _index.has(id):
			continue
		var e: Dictionary = _index[id]
		assert_false(bool(e.get("test", false)), "%s: cast, not a test fixture" % id)
		assert_true(ResourceLoader.exists(String(e["scene"])), "%s: scene exists" % id)


func test_scene_contract_and_budget() -> void:
	for id: String in NEW:
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
	for id: String in NEW:
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
				var ok: bool = path.begins_with(MAT_DIR) and path.ends_with(".tres")
				assert_true(ok and ResourceLoader.exists(path), "%s/%s surface %d: %s" % [id, mi.name, s, path])
		root.queue_free()


func test_cast_index_covers_every_heist_and_role() -> void:
	assert_false(_cast.is_empty(), "p5_cast.json parses")
	for heist: String in ROLES:
		for role: String in ROLES[heist]:
			var ids: Array = _role_ids(heist, role)
			assert_true(ids.size() >= int(MIN_COUNT.get(role, 1)), "%s/%s: %d id(s)" % [heist, role, ids.size()])


func test_cast_index_points_at_existing_scenes() -> void:
	var by_id: Dictionary = {}
	for asset: String in _index:
		by_id[String((_index[asset] as Dictionary)["id"])] = _index[asset]
	var listed: Array[String] = []
	var heists: Dictionary = _cast.get("heists", {}) as Dictionary
	for heist: String in heists:
		var roles: Dictionary = heists[heist] as Dictionary
		for role: String in roles:
			for cid: Variant in roles[role]:
				var id: String = String(cid)
				listed.append(id)
				assert_true(by_id.has(id), "%s/%s: %s in characters.json" % [heist, role, id])
				if by_id.has(id):
					var scene: String = String((by_id[id] as Dictionary)["scene"])
					assert_eq(scene, "%s%s/%s.tscn" % [Spec.OUT_DIR, id, id], "%s: scene path convention" % id)
					assert_true(ResourceLoader.exists(scene), "%s: scene exists" % id)
	for asset: String in NEW:
		assert_has(listed, Spec.character_id(asset), "%s cast in p5_cast.json" % asset)


## The pager roles are exactly PAGER_ROLES, each is cast in some heist, and every new character in a
## pager role answers it on a belt radio (RADIO) or is a documented exception (NO_RADIO).
func test_pager_roles() -> void:
	var listed: Array[String] = []
	for r: Variant in _cast.get("pager_roles", []) as Array:
		listed.append(String(r))
	listed.sort()
	var want: Array[String] = PAGER_ROLES.duplicate()
	want.sort()
	assert_eq(listed, want, "pager_roles")
	var heists: Dictionary = _cast.get("heists", {}) as Dictionary
	for role: String in PAGER_ROLES:
		var found: bool = false
		for heist: String in heists:
			var roles: Dictionary = heists[heist] as Dictionary
			if not roles.has(role):
				continue
			found = true
			for cid: Variant in roles[role]:
				var asset: String = "char_" + String(cid)
				if NEW.has(asset):
					assert_true(RADIO.has(asset) or NO_RADIO.has(asset), "%s (%s): pager on a radio" % [asset, role])
		assert_true(found, "pager role %s is cast" % role)


## Every pager role's new characters answer the pager at Hip/Socket, on the belt radio (right hip).
func test_radio_hip_sockets() -> void:
	for id: String in RADIO:
		var root: Node3D = _instance(id)
		if root == null:
			continue
		var skel: Skeleton3D = root.get_node("Skeleton3D") as Skeleton3D
		var att: BoneAttachment3D = skel.get_node_or_null("Hip") as BoneAttachment3D
		var socket: Node3D = skel.get_node_or_null("Hip/" + Spec.SOCKET_NAME) as Node3D
		assert_true(att != null and socket != null, "%s: Hip/Socket" % id)
		if socket == null:
			root.queue_free()
			continue
		var p: Vector3 = (skel.get_bone_global_rest(skel.find_bone(att.bone_name)) * socket.transform).origin
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


## Halberd Gallery Security and Vaultline wear their own colours, never Halden, Northgate, police,
## TAC or the bank livery; each wears its own mark.
func test_company_liveries() -> void:
	for id: String in ["char_gallery_guard", "char_gallery_guard_b", "char_armored_car_crew", "char_armored_car_crew_b"]:
		var mats: Array[String] = _materials(id)
		for m: String in mats:
			for bad: String in OTHER_LIVERY:
				assert_false(m.begins_with(bad), "%s: no other company's livery (%s)" % [id, m])
		var own: String = "char_gallery_green" if id.begins_with("char_gallery") else "char_vl_amber"
		assert_has(mats, own, "%s: wears %s" % [id, own])


## Players find the curator at the gala: the only Gallery Night character in the bone-white suit.
func test_curator_stands_out() -> void:
	var users: Array[String] = []
	var heists: Dictionary = _cast.get("heists", {}) as Dictionary
	var roles: Dictionary = heists.get("gallery_night", {}) as Dictionary
	for role: String in roles:
		for cid: Variant in roles[role]:
			var asset: String = "char_" + String(cid)
			if _materials(asset).has(CURATOR_SUIT) and not users.has(asset):
				users.append(asset)
	assert_eq(users, ["char_gallery_curator"] as Array[String], "only the curator wears the bone suit: %s" % [users])


## D-075: the gallery-level bank officers wear the bank's lanyard (bank red + slate) over the grey
## suit, never the manager's navy three-piece or the customer's grey blazer.
func test_bank_officers() -> void:
	for id: String in ["char_bank_officer", "char_bank_officer_b"]:
		var mats: Array[String] = _materials(id)
		for need: String in ["char_suit_grey", "char_bank_red", "char_bank_slate"]:
			assert_has(mats, need, "%s: wears %s" % [id, need])
		for bad: String in ["char_suit_navy", "char_blazer_grey"]:
			assert_false(mats.has(bad), "%s: not %s" % [id, bad])
