## D2-02 / D-063: heist NPCs (tools/blender/characters/char_npc_bank.py, char_npc_penthouse.py,
## char_npc_calder.py). Checks the assembled scenes (docs/contracts/characters.md: Root > Skeleton3D
## with skinned meshes and the HandR/HandL/Head/Back/Hip BoneAttachment3D markers with a Socket),
## that every surface resolves to a library material in world/materials, the triangle budget,
## plausible heights, that every guard's Hip socket sits on his belt radio (the pager seat), that
## the bank guard wears Halden livery and the Northgate detail does not, that Kessler (both looks)
## stands out (tallest, the only ones in the ice accent), and the IT contractor's lanyard and bag. D-115 hand props
## (world/characters/_props): each scene loads, is hand-sized and sits at its SOURCE.txt grip; on the cleaner playing
## smoke with hand_cigarette under HandR/Socket the cigarette is between the fingers and at the lips at each drag.
## OF-D1 (Ostrander Federal): the ten Halden uniformed faces and the Halden bodyguard (radio at Hip, livery / pin), and
## the VIP client's look (distinct from every bank customer, officer and the manager).
## Regenerate with tools/blender/characters/assemble.sh.
extends TestCase

const Spec: GDScript = preload("res://world/characters/_tools/character_spec.gd")

const NPCS: Array[String] = [
	"char_npc_bank_teller",
	"char_npc_bank_teller_b",
	"char_npc_bank_teller_c",
	"char_npc_bank_teller_d",
	"char_npc_bank_teller_e",
	"char_npc_bank_night_manager",
	"char_npc_bank_cleaner",
	"char_npc_bank_cleaner_b",
	"char_npc_bank_guard",
	"char_npc_penthouse_guest_a",
	"char_npc_penthouse_guest_b",
	"char_npc_penthouse_staff",
	"char_npc_kessler",
	"char_npc_kessler_coat",
	"char_npc_cleaner_sl",
	"char_npc_cleaner_sl_b",
	"char_npc_cleaner_sl_c",
	"char_npc_cleaner_sl_d",
	"char_npc_it_contractor",
	"char_npc_northgate_guard",
	"char_npc_northgate_guard_b",
	"char_npc_northgate_guard_c",
	"char_npc_northgate_guard_d",
	"char_npc_northgate_guard_e",
	"char_npc_northgate_guard_f",
	"char_npc_northgate_guard_g",
	"char_npc_northgate_guard_h",
	"char_npc_northgate_guard_i",
	"char_npc_helena_moor",
	"char_npc_km_assistant",
	"char_npc_km_associate",
	"char_security_bodyguard",
	"char_bank_vip_client",
]
const GUARD: String = "char_npc_bank_guard"
## OF-D1 (Ostrander Federal day shift, D-130-sized): the ten Halden uniformed faces (char_security.py) and the Halden
## close-protection officer who escorts the vip_client.
const HALDEN_OFFICERS: Array[String] = [
	"char_security_officer", "char_security_officer_b", "char_security_officer_c", "char_security_officer_d",
	"char_security_officer_e", "char_security_officer_f", "char_security_officer_g", "char_security_officer_h",
	"char_security_officer_i", "char_security_officer_j",
]
const BODYGUARD: String = "char_security_bodyguard"
const VIP: String = "char_bank_vip_client"
## The Ostrander Federal customers, staff and officers the VIP client must not resemble.
const VIP_OTHERS: Array[String] = [
	"char_bank_customer", "char_bank_customer_b", "char_civilian_customer_a", "char_civilian_customer_b",
	"char_bank_officer", "char_bank_officer_b", "char_bank_manager",
]
## Every NPC whose pager is answered at Hip/Socket (the radio on the belt).
const RADIO_GUARDS: Array[String] = [
	"char_npc_bank_guard", "char_npc_northgate_guard", "char_npc_northgate_guard_b", "char_npc_northgate_guard_c",
	"char_npc_northgate_guard_d", "char_npc_northgate_guard_e", "char_npc_northgate_guard_f", "char_npc_northgate_guard_g",
	"char_npc_northgate_guard_h", "char_npc_northgate_guard_i",
	"char_security_officer", "char_security_officer_b", "char_security_officer_c", "char_security_officer_d",
	"char_security_officer_e", "char_security_officer_f", "char_security_officer_g", "char_security_officer_h",
	"char_security_officer_i", "char_security_officer_j", "char_security_bodyguard",
]
const NORTHGATE: Array[String] = [
	"char_npc_northgate_guard", "char_npc_northgate_guard_b", "char_npc_northgate_guard_c", "char_npc_northgate_guard_d",
	"char_npc_northgate_guard_e", "char_npc_northgate_guard_f", "char_npc_northgate_guard_g", "char_npc_northgate_guard_h",
	"char_npc_northgate_guard_i",
]
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
## D-115 (heist cast audit 2026-10-15): Golden Hour staff (char_civilians.py) and Dockside Burn
## workers (char_dock_workers.py): the look-defining material per mesh each must wear.
const D115_CAST: Dictionary = {
	"char_civilian_manager_vossberg": {
		"Outfit": ["char_suit_plum", "char_silk_ivory"], "Gear": ["brass"], "Headwear": ["brass", "char_hair_grey"],
	},
	"char_civilian_sales_b": {"Outfit": ["char_suit_dark", "char_shirt_black"], "Gear": ["brass"]},
	"char_civilian_clerk": {
		"Outfit": ["char_knit_oat", "char_shirt_white", "char_dress_black"], "Gear": ["char_medic_white", "brass"],
		"Headwear": ["char_button_dark"],
	},
	"char_dock_worker": {
		"Outfit": ["char_hivis_orange", "char_reflect_silver", "char_work_navy", "char_work_charcoal"],
		"Headwear": ["char_hardhat_white"],
	},
	"char_dock_worker_b": {
		"Outfit": ["char_hivis", "char_reflect_silver", "char_work_charcoal"], "Headwear": ["char_hardhat_blue"],
	},
	"char_dock_worker_c": {   # D-115 DB cast: the third civ_worker face (beanie, maroon fleece, denim)
		"Outfit": ["char_hivis_orange", "char_reflect_silver", "char_fleece_maroon", "char_denim"],
		"Headwear": ["char_knit_navy"],
	},
	"char_npc_cleaner_sl_b": {
		"Outfit": [
			"char_cleaner_teal", "char_waistcoat_graphite", "char_knit_graphite", "char_trousers_black",
			"char_rubber_yellow",
		],
		"Gear": ["char_metal_silver"], "Headwear": ["char_hair_grey"],
	},
	"char_npc_cleaner_sl_d": {   # D-130: the fourth SL cleaner face, same Calder uniform
		"Outfit": [
			"char_cleaner_teal", "char_waistcoat_graphite", "char_knit_graphite", "char_trousers_black",
			"char_rubber_yellow",
		],
		"Gear": ["char_metal_silver"],
	},
	"char_npc_bank_cleaner_b": {   # D-130: the second ND cleaner, same contractor uniform, brown bun
		"Outfit": ["char_cleaner_tabard", "char_bank_cream", "char_knit_grey", "char_bank_slate_dark", "char_rubber_yellow"],
		"Headwear": ["char_hair_brown"],
	},
	"char_dock_packer": {   # D-116: processing whites (packing wing), not a third yard hand
		"Outfit": ["char_shirt_white", "char_rubber_yellow", "char_work_charcoal", "char_sneaker_white"],
		"Headwear": ["char_shirt_white"],
	},
	# GN-D1 polish (char_p5_gallery.py): five more gala patrons, the second waitstaff, the conservator's own look.
	"char_gallery_patron_c": {"Outfit": ["char_dress_black", "brass"], "Headwear": ["brass", "char_hair_grey"]},
	"char_gallery_patron_d": {
		"Outfit": ["char_tux_black", "char_satin_black", "char_shirt_black", "char_silk_plum"], "Gear": ["chrome"],
	},
	"char_gallery_patron_e": {"Outfit": ["char_satin_sapphire", "chrome"], "Headwear": ["chrome"]},
	"char_gallery_patron_f": {
		"Outfit": ["char_suit_navy", "char_satin_black", "char_shirt_white"], "Gear": ["char_gallery_wine"],
		"Headwear": ["char_metal_silver"],
	},
	"char_gallery_patron_g": {"Outfit": ["char_satin_amethyst", "char_satin_black"], "Headwear": ["brass"]},
	# D-130: three more patrons (twelve-look pool)
	"char_gallery_patron_h": {"Outfit": ["char_satin_gold", "char_satin_black"], "Headwear": ["brass"]},
	"char_gallery_patron_i": {
		"Outfit": ["char_suit_plum", "char_satin_black", "char_shirt_white", "char_tux_black"], "Gear": ["brass"],
	},
	"char_gallery_patron_j": {"Outfit": ["char_silk_graphite", "char_satin_gold"], "Headwear": ["chrome"]},
	"char_gallery_waiter": {
		"Outfit": ["char_gallery_wine", "char_shirt_white", "char_tux_black"], "Gear": ["brass", "char_tie_black"],
	},
	# D-130 gala_extra: the cloakroom waitstaff (short wine jacket, no apron) and the drawings-cabinet attendant
	# (grey knit cardigan, cotton gloves, staff lanyard).
	"char_gallery_waiter_b": {
		"Outfit": ["char_gallery_wine", "char_shirt_white", "char_trousers_black"], "Gear": ["brass", "char_tie_black"],
		"Headwear": ["char_hair_brown", "brass"],
	},
	"char_gallery_attendant_c": {
		"Outfit": ["char_knit_grey", "char_shirt_white", "char_glove_white", "char_trousers_black"],
		"Gear": ["char_medic_white", "char_gallery_wine", "brass"],
	},
	"char_gallery_conservator": {
		"Outfit": ["char_shirt_blue", "char_knit_grey", "char_work_charcoal", "char_glove_white", "char_chino_khaki"],
		"Gear": ["char_medic_white"], "Headwear": ["char_metal_silver", "polymer_black"],
	},
	# OF-D1 vip_client: the private client (camel overcoat, grey suit, sapphire silk scarf, leather gloves, gold watch)
	"char_bank_vip_client": {
		"Outfit": [
			"char_coat_camel", "char_suit_grey", "char_shirt_white", "char_tie_burgundy", "char_satin_sapphire",
			"leather_dark",
		],
		"Gear": ["brass"],
	},
}
## OF-D1 bank day pools (test_of_bank_civilians).
const OF_TELLERS: Array[String] = [
	"char_npc_bank_teller", "char_npc_bank_teller_b", "char_npc_bank_teller_c", "char_npc_bank_teller_d",
	"char_npc_bank_teller_e",
]
const OF_OFFICERS: Array[String] = [
	"char_bank_officer", "char_bank_officer_b", "char_bank_officer_c", "char_bank_officer_d",
]
const OF_CUSTOMERS: Array[String] = [
	"char_bank_customer", "char_bank_customer_b", "char_civilian_customer_a", "char_civilian_customer_b",
	"char_bank_customer_c", "char_bank_customer_d", "char_bank_customer_e", "char_bank_customer_f",
	"char_bank_customer_g", "char_bank_customer_h", "char_bank_customer_i", "char_bank_customer_j",
]
const OF_LOOK: Dictionary = {
	"char_npc_bank_teller_c": {"Outfit": ["char_knit_slate", "char_bank_red"]},
	"char_npc_bank_teller_d": {"Outfit": ["char_bank_slate", "char_bank_red"], "Headwear": ["char_hair_brown"]},
	"char_npc_bank_teller_e": {"Outfit": ["char_bank_slate", "char_bank_red"], "Gear": ["brass"]},
	"char_bank_officer_c": {"Outfit": ["char_shirt_white", "char_tie_burgundy"], "Gear": ["char_medic_white", "brass"]},
	"char_bank_officer_d": {"Outfit": ["char_shirt_white"], "Headwear": ["char_hair_dark", "char_button_dark"]},
	"char_bank_customer_c": {"Outfit": ["char_skirt_navy", "char_knit_mustard", "char_shirt_white"]},
	"char_bank_customer_d": {"Outfit": ["char_nylon_black", "char_work_charcoal"], "Headwear": ["char_hivis_orange"]},
	"char_bank_customer_e": {"Outfit": ["char_coat_heather", "char_knit_cream"], "Headwear": ["char_hair_grey"]},
	"char_bank_customer_f": {"Outfit": ["char_coat_stone", "char_shirt_blue", "char_suit_navy"]},
	"char_bank_customer_g": {"Outfit": ["char_hoodie_cream", "char_denim"], "Headwear": ["polymer_black"]},
	"char_bank_customer_h": {"Outfit": ["char_canvas_tan", "char_knit_grey", "char_work_navy"]},
	"char_bank_customer_i": {"Outfit": ["char_fleece_maroon", "char_chino_khaki"]},
	"char_bank_customer_j": {"Outfit": ["char_suit_brown", "char_knit_cream"], "Headwear": ["chrome"]},
}
## D-115 hand props (world/characters/_props, tools/blender/characters/make_hand_prop_scenes.py): the index, the
## largest extent a prop may have (m; the mop is 1.4 m long), and the smoke check (cigarette length, drag frames).
const HAND_PROPS_INDEX: String = "res://world/characters/_props/hand_props.json"
const HAND_PROP_MAX: Dictionary = {"mop": Vector3(0.45, 1.45, 0.45)}
const HAND_PROP_SMALL: Vector3 = Vector3(0.32, 0.32, 0.32)
const SMOKER: String = "char_npc_bank_cleaner"
const CIG_LEN: float = 0.072
const CIG_DRAG: Array[int] = [20, 26, 80, 86]
## The SL cleaner uniform's own hard parts (cleaner_outfit's metal); every SL cleaner wears them.
const CLEANER_SL_GEAR: Array[String] = ["char_metal_silver"]

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
	_check_d115_cast()


## D-115: the six new civilians are indexed with their scenes and wear their look (hi-vis + tape, hard
## hat or beanie, Vossberg's plum suit and gold, the clerk's lanyard card); the packer has no hard hat.
## D-SL-2: the second Shadow Ledger cleaner wears exactly npc_cleaner_sl's uniform but is another person.
## GN-D1 polish: the new Gallery Night looks (patrons c-g, waiter, conservator); test_p5_cast checks their roles.
## D-130: patrons h-j, the fourth SL cleaner (same uniform as cleaner_sl) and the second ND cleaner; GN gala_extra: waiter_b, attendant_c.
func _check_d115_cast() -> void:
	for id: String in D115_CAST:
		assert_true(_index.has(id), "%s in characters.json" % id)
		if not _index.has(id):
			continue
		var scene: String = String((_index[id] as Dictionary)["scene"])
		assert_eq(scene, _scene(id), "%s: scene path convention" % id)
		assert_true(ResourceLoader.exists(scene), "%s: scene exists" % id)
		var by_mesh: Dictionary = _materials(id)
		var want: Dictionary = D115_CAST[id]
		for mesh: String in want:
			for m: String in want[mesh]:
				assert_has(by_mesh.get(mesh, []) as Array, m, "%s: %s wears %s" % [id, mesh, m])
	var packer: Array[String] = _all_materials(_materials("char_dock_packer"))
	assert_false(packer.has("char_hardhat_white") or packer.has("char_hardhat_blue"), "dock_packer: no hard hat")
	var sl: Dictionary = _materials("char_npc_cleaner_sl")
	for other: String in ["char_npc_cleaner_sl_b", "char_npc_cleaner_sl_d"]:   # D-130: _d wears it too
		var sl_b: Dictionary = _materials(other)
		var a: Array = (sl.get("Outfit", []) as Array).duplicate()
		var b: Array = (sl_b.get("Outfit", []) as Array).duplicate()
		a.sort()
		b.sort()
		assert_eq(b, a, "%s: same Outfit uniform as cleaner_sl" % other)
		# SL-G3: Gear also carries one personal detail per cleaner (badge, pen, cloth), so only the uniform's own hard
		# parts must match
		for m: String in CLEANER_SL_GEAR:
			assert_has(sl_b.get("Gear", []) as Array, m, "%s: the uniform's %s Gear" % [other, m])
		assert_ne(sl_b.get("Body", []), sl.get("Body", []), "%s: a different skin from cleaner_sl" % other)
	assert_ne(_materials("char_npc_cleaner_sl_b").get("Hair", []), sl.get("Hair", []),
			"cleaner_sl_b: different hair from cleaner_sl")


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
	_check_hand_props()
	_check_smoke_cigarette()


## "basis x=(..) y=(..) z=(..) origin=(..)" (SOURCE.txt transform notation) -> Transform3D.
static func _parse_xform(text: String) -> Transform3D:
	var re: RegEx = RegEx.create_from_string("(x|y|z|origin)=\\(([^)]*)\\)")
	var v: Dictionary = {}
	for m: RegExMatch in re.search_all(text):
		var p: PackedStringArray = m.get_string(2).split(",")
		v[m.get_string(1)] = Vector3(float(p[0]), float(p[1]), float(p[2]))
	if v.size() < 4:
		return Transform3D(Basis(), Vector3.INF)
	return Transform3D(Basis(v["x"], v["y"], v["z"]), v["origin"])


static func _to_root(node: Node3D, root: Node3D) -> Transform3D:
	var t: Transform3D = Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


## D-115: every hand-prop scene loads, its `Model` (the char_hand_<prop> glb) has a MeshInstance3D, is hand-sized,
## sits at the SOURCE.txt `<prop>_grip` of the socket it names and within reach of that socket.
func _check_hand_props() -> void:
	var src: Dictionary = Spec.read_source(Spec.ANIM_SOURCE)
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(HAND_PROPS_INDEX))
	if not (index is Dictionary) or (index as Dictionary).size() < 9:
		fail("%s missing or short (run tools/blender/characters/make_hand_prop_scenes.py)" % HAND_PROPS_INDEX)
		return
	for prop: String in ["phone", "cigarette", "mug", "mop"]:
		assert_true((index as Dictionary).has(prop), "hand prop %s indexed" % prop)
	for prop: String in index:
		var row: Dictionary = index[prop]
		var line: String = String(src.get(prop + "_grip", ""))
		assert_true(line.contains("relative to %s/Socket" % row["socket"]), "%s_grip at %s/Socket" % [prop, row["socket"]])
		var packed: PackedScene = load(String(row["scene"])) as PackedScene
		if packed == null:
			fail("%s: %s does not load" % [prop, row["scene"]])
			continue
		var root: Node3D = packed.instantiate() as Node3D
		var model: Node3D = root.get_node_or_null("Model") as Node3D
		var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
		assert_true(model != null and not meshes.is_empty(), "%s: Model with a MeshInstance3D" % prop)
		assert_eq(String(root.get_meta("socket", "")), String(row["socket"]), "%s: socket metadata" % prop)
		if model != null:
			assert_true(model.transform.is_equal_approx(_parse_xform(line)), "%s: Model at %s_grip" % [prop, prop])
		var box: AABB = AABB()
		for i: int in range(meshes.size()):
			var mi: MeshInstance3D = meshes[i] as MeshInstance3D
			var b: AABB = _to_root(mi, root) * mi.get_aabb()
			box = b if i == 0 else box.merge(b)
		var cap: Vector3 = HAND_PROP_MAX.get(prop, HAND_PROP_SMALL)
		var axes: Array[float] = [box.size.x, box.size.y, box.size.z]
		axes.sort()
		assert_true(axes[2] > 0.03 and axes[2] <= maxf(cap.x, maxf(cap.y, cap.z)) and axes[0] < cap.x,
			"%s: hand-sized (%s)" % [prop, box.size])
		var reach: float = box.get_center().length() - box.size.length() * 0.5
		assert_true(reach < 0.08, "%s: within reach of the socket (%f m)" % [prop, reach])
		root.free()


## D-115 smoke on a real NPC with hand_cigarette.tscn under HandR/Socket: the cigarette crosses the gap between the
## index and middle fingers on every frame, its filter tip is at the lips at each drag, held low (ember up) between.
func _check_smoke_cigarette() -> void:
	var root: Node3D = _instance(SMOKER)
	var packed: PackedScene = load("res://world/characters/_props/hand_cigarette.tscn") as PackedScene
	if root == null or packed == null:
		fail("smoke: %s or hand_cigarette.tscn missing" % SMOKER)
		return
	var skel: Skeleton3D = root.get_node("Skeleton3D") as Skeleton3D
	var socket: Node3D = skel.get_node("HandR/" + Spec.SOCKET_NAME) as Node3D
	var prop: Node3D = packed.instantiate() as Node3D
	socket.add_child(prop)
	var grip: Transform3D = socket.transform * (prop.get_node("Model") as Node3D).transform
	var player: AnimationPlayer = root.get_node("AnimationPlayer") as AnimationPlayer
	player.play(&"humanoid/smoke")
	var worst: float = 0.0
	for f: int in range(0, 120, 4):
		player.seek(float(f) / 30.0, true)
		var cig: Transform3D = _bone(skel, "hand.R") * grip
		var gap: Vector3 = (_bone(skel, "index_01.R").origin.lerp(_bone(skel, "index_02.R").origin, 0.75)
			+ _bone(skel, "middle_01.R").origin.lerp(_bone(skel, "middle_02.R").origin, 0.75)) * 0.5
		var axis: Vector3 = cig.basis.y.normalized()
		var along: float = (gap - cig.origin).dot(axis)
		worst = maxf(worst, (gap - cig.origin - axis * along).length())
		assert_true(along > 0.01 and along < CIG_LEN - 0.02, "smoke f%d: fingers on the cigarette (%f m)" % [f, along])
	assert_true(worst < 0.006, "smoke: the cigarette between the index and middle fingers (worst %f m)" % worst)
	for f: int in CIG_DRAG:
		player.seek(float(f) / 30.0, true)
		var cig: Transform3D = _bone(skel, "hand.R") * grip
		var head: Vector3 = _bone(skel, "head").origin
		var d: float = cig.origin.distance_to(head)
		assert_true(d > 0.07 and d < 0.15 and cig.origin.z < head.z - 0.06 and absf(cig.origin.y - head.y) < 0.06,
			"smoke f%d: filter tip at the lips (%s, head joint %s)" % [f, cig.origin, head])
		var ember: Vector3 = cig.origin + cig.basis.y.normalized() * CIG_LEN
		assert_true(ember.distance_to(head) > d + 0.04, "smoke f%d: the cigarette points out of the mouth" % f)
	player.seek(50.0 / 30.0, true)
	var low: Transform3D = _bone(skel, "hand.R") * grip
	assert_true(low.origin.y < 1.3 and low.basis.y.normalized().y > 0.2,
		"smoke: held low, ember up between drags (%s, axis %s)" % [low.origin, low.basis.y])
	root.queue_free()


static func _bone(skel: Skeleton3D, bone: String) -> Transform3D:
	return skel.global_transform * skel.get_bone_global_pose(skel.find_bone(bone))


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


## OF-D1: every uniformed Halden face (a-j) wears the full livery and no bank livery.
func test_halden_officers_wear_the_livery() -> void:
	for id: String in HALDEN_OFFICERS:
		var by_mesh: Dictionary = _materials(id)
		var mats: Array[String] = _all_materials(by_mesh)
		for need: String in HALDEN:
			assert_has(mats, need, "%s wears Halden %s" % [id, need])
		for m: String in mats:
			assert_false(m.begins_with("char_bank_"), "%s: no bank livery (%s)" % [id, m])
		assert_true(by_mesh.has("Headwear"), "%s: peaked cap (Headwear)" % id)


## OF-D1 guard_vip: the Halden bodyguard is plainclothes (dark suit, white shirt, no uniform shirt, no cap) but carries
## the Halden pin (gold rim, burgundy enamel), the earpiece cable and the belt radio (test above).
func test_bodyguard_is_halden_close_protection() -> void:
	var by_mesh: Dictionary = _materials(BODYGUARD)
	var outfit: Array = by_mesh.get("Outfit", []) as Array
	var gear: Array = by_mesh.get("Gear", []) as Array
	assert_has(outfit, "char_tux_black", "bodyguard: near-black suit")
	assert_has(outfit, "char_shirt_white", "bodyguard: white shirt")
	assert_false(_all_materials(by_mesh).has("char_sec_shirt"), "bodyguard: not the uniform shirt")
	# OF-G3: his Headwear is the dark glasses; no Halden peaked cap (its gloss visor)
	assert_false(by_mesh.get("Headwear", []).has("char_visor_gloss"), "bodyguard: no cap")
	assert_has(gear, "brass", "bodyguard: Halden pin rim")
	assert_has(gear, "char_sec_burgundy", "bodyguard: Halden pin enamel")
	assert_has(gear, "char_cable_black", "bodyguard: earpiece cable")
	for id: String in NORTHGATE:
		assert_ne(_materials(id).get("Outfit", []), outfit, "bodyguard: not the Northgate suit (%s)" % id)


## OF-D1 civ_vip: the VIP client is nobody else in the bank: no other customer, officer or manager wears the camel coat
## with the sapphire silk scarf, or wears his outfit.
func test_vip_client_is_distinct() -> void:
	var vip: Dictionary = _materials(VIP)
	assert_false(vip.has("Headwear"), "VIP: no glasses or hat (the manager wears silver glasses)")
	for id: String in VIP_OTHERS:
		var other: Dictionary = _materials(id)
		var mats: Array[String] = _all_materials(other)
		assert_false(mats.has("char_coat_camel") and mats.has("char_satin_sapphire"), "%s: not the VIP's coat + scarf" % id)
		assert_ne(other.get("Outfit", []), vip.get("Outfit", []), "%s: not the VIP's outfit" % id)


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


## D-130 late_staff (seated desk_work at K4 / K8): the K&M executive assistant (open slate cardigan over a plum
## blouse, staff lanyard, chignon) and the junior associate (pale-blue shirt, loose burgundy tie, navy trousers, no
## jacket) are their own people: neither shares Moor's skin or blouse, and neither wears the IT contractor's lanyard.
func test_km_late_staff_looks() -> void:
	var asst: Dictionary = _materials("char_npc_km_assistant")
	var assoc: Dictionary = _materials("char_npc_km_associate")
	var moor: Dictionary = _materials("char_npc_helena_moor")
	assert_has(asst.get("Outfit", []) as Array, "char_knit_slate", "assistant: slate cardigan")
	assert_has(asst.get("Outfit", []) as Array, "char_silk_plum", "assistant: plum blouse")
	assert_has(asst.get("Gear", []) as Array, "char_medic_white", "assistant: staff ID card (Gear)")
	assert_has(asst.get("Headwear", []) as Array, "char_hair_dark", "assistant: dark chignon (Headwear)")
	assert_has(assoc.get("Outfit", []) as Array, "char_shirt_blue", "associate: pale-blue shirt")
	assert_has(assoc.get("Outfit", []) as Array, "char_tie_burgundy", "associate: burgundy tie")
	assert_has(assoc.get("Outfit", []) as Array, "char_suit_navy", "associate: navy suit trousers")
	assert_false((assoc.get("Outfit", []) as Array).has("char_suit_dark"), "associate: no charcoal (Northgate) suit")
	for pair: Array in [["assistant", asst], ["associate", assoc]]:
		var by_mesh: Dictionary = pair[1]
		assert_ne(by_mesh.get("Body", []), moor.get("Body", []), "%s: a different skin from Moor" % pair[0])
		assert_false(_all_materials(by_mesh).has("char_silk_ivory"), "%s: not Moor's ivory blouse" % pair[0])
		assert_false(_all_materials(by_mesh).has("char_lanyard"), "%s: not the contractor's visitor lanyard" % pair[0])
	assert_ne(asst.get("Body", []), assoc.get("Body", []), "assistant and associate: different skins")


## OF-D1 (Ostrander Federal by day, D-130: +35 % civilians at Cataclysm): the bank's day pools. Every teller wears the
## bank uniform (cream, bank red, dark slate), every officer the grey worsted with the bank lanyard; each new look wears
## its look-defining material; and no two looks in a pool are twins (skin, hair, headwear and outfit all equal).
func test_of_bank_civilians() -> void:
	var sigs: Dictionary = {}
	for pool: Array in [OF_TELLERS, OF_OFFICERS, OF_CUSTOMERS]:
		for id: Variant in pool:
			assert_true(_index.has(String(id)), "%s in characters.json" % id)
			var by_mesh: Dictionary = _materials(String(id))
			var parts: Array[String] = []
			for mesh: String in ["Body", "Hair", "Headwear", "Outfit"]:
				var mats: Array = (by_mesh.get(mesh, []) as Array).duplicate()
				mats.sort()
				parts.append("%s=%s" % [mesh, ",".join(PackedStringArray(mats))])
			sigs[String(id)] = "|".join(PackedStringArray(parts))
			var want: Dictionary = OF_LOOK.get(String(id), {})
			for mesh: String in want:
				for m: String in want[mesh]:
					assert_has(by_mesh.get(mesh, []) as Array, m, "%s: %s wears %s" % [id, mesh, m])
			var all: Array[String] = _all_materials(by_mesh)
			if pool == OF_TELLERS:
				for m: String in ["char_bank_cream", "char_bank_red", "char_bank_slate_dark"]:
					assert_has(all, m, "%s: teller uniform %s" % [id, m])
			elif pool == OF_OFFICERS:
				assert_has(all, "char_suit_grey", "%s: the officers' grey worsted" % id)
				assert_has(all, "char_bank_red", "%s: the bank lanyard" % id)
		for i: int in range(pool.size()):
			for j: int in range(i + 1, pool.size()):
				assert_ne(sigs.get(String(pool[i]), ""), sigs.get(String(pool[j]), ""),
						"%s and %s: not twins" % [pool[i], pool[j]])


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
