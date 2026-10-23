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
## tools/blender/characters/assemble.sh. D-115: the same index casts the four pre-P5 heists, and every
## role in their design roster tables (docs/design/heists/<heist>.md) must have a loadable character.
extends TestCase

const Spec: GDScript = preload("res://world/characters/_tools/character_spec.gd")
const Layers: GDScript = preload("res://world/characters/_tools/char_layers.gd")

const CAST_PATH: String = "res://world/characters/p5_cast.json"
## Characters built for D3-01 (asset ids).
const NEW: Array[String] = [
	"char_gallery_curator",
	"char_gallery_attendant",
	"char_gallery_attendant_b",
	"char_gallery_attendant_c",
	"char_gallery_guard",
	"char_gallery_guard_b",
	"char_gallery_guard_c",
	"char_gallery_guard_d",
	"char_gallery_guard_e",
	"char_gallery_guard_f",
	"char_gallery_guard_g",
	"char_gallery_guard_h",
	"char_gallery_guard_i",
	"char_gallery_guard_j",
	"char_gallery_guard_k",
	"char_gallery_guard_l",
	"char_gallery_patron",
	"char_gallery_patron_b",
	"char_gallery_admin",
	"char_gallery_patron_c",
	"char_gallery_patron_d",
	"char_gallery_patron_e",
	"char_gallery_patron_f",
	"char_gallery_patron_g",
	"char_gallery_patron_h",
	"char_gallery_patron_i",
	"char_gallery_patron_j",
	"char_gallery_waiter",
	"char_gallery_waiter_b",
	"char_gallery_conservator",
	"char_bank_manager",
	"char_bank_officer",
	"char_bank_officer_b",
	"char_bank_customer",
	"char_bank_customer_b",
	"char_armored_car_crew",
	"char_armored_car_crew_b",
	"char_armored_car_crew_c",
	"char_armored_car_crew_d",
	"char_armored_car_crew_e",
	"char_armored_car_crew_f",
	"char_armored_car_marshal",
	"char_club_bouncer",
	"char_club_bouncer_b",
	"char_club_bartender",
	"char_club_bartender_b",
	"char_club_dj",
	"char_club_patron",
	"char_club_patron_b",
	"char_club_patron_c",
	"char_club_patron_d",
	# D-130 Shadow Ledger late_staff (civ_assistant, civ_associate)
	"char_npc_km_assistant",
	"char_npc_km_associate",
	# RT-D1 (prep/d-rt): Rolling Thunder diner staff, car-park attendant, street pedestrians a-f
	"char_diner_waitress",
	"char_diner_cook",
	"char_carpark_attendant",
	"char_street_pedestrian",
	"char_street_pedestrian_b",
	"char_street_pedestrian_c",
	"char_street_pedestrian_d",
	"char_street_pedestrian_e",
	"char_street_pedestrian_f",
	"char_street_pedestrian_g",
	"char_street_pedestrian_h",
	"char_street_pedestrian_i",
]
## heist -> roles the index must carry (D3-01 brief; D-075 renamed meridian_federal and added
## bank_officer).
const ROLES: Dictionary = {
	"gallery_night": ["gallery_curator", "gallery_attendant", "gallery_conservator", "gallery_admin", "gallery_guard",
		"gallery_patron", "gallery_waitstaff", "gallery_inspector", "gallery_vaultline"],
	"ostrander_federal": ["bank_teller", "bank_manager", "bank_officer", "bank_guard", "bank_customer"],
	"rolling_thunder": ["armored_car_crew", "convoy_escort"],
	"afterhours": ["club_bouncer", "club_bartender", "club_dj", "club_patron"],
}
## D-115: the pre-P5 heists whose roster is read from docs/design/heists/<heist>.md, section
## "### ... roster (spawn data)": every spawn tag in its "Spawn tags" column is a cast role.
const DESIGN_HEISTS: Array[String] = ["glasshouse", "night_deposit", "dockside_burn", "shadow_ledger"]
const ROSTER_HEADING: String = "roster (spawn data)"
## Roles a roster row names without a spawn-tag token: the CAMERA_OPERATOR spawn is tagged
## security_operator (<heist>_layout.gd CameraOperatorSeat) and the police row lists director spawn
## points, cast as the role `police`.
const OPERATOR_ROLE: String = "security_operator"
const POLICE_ROLE: String = "police"
## Roles the design names outside the roster table (kept explicit, pointing at the doc section).
const EXTRA_ROLES: Dictionary = {
	# glasshouse.md §Variants `guard_post` (post_floor, rover_boh, rover_upper, alley_smoker) and
	# §Sightlines "P2 camera operator" (spawn tags from glasshouse_layout.gd).
	"glasshouse": ["guard_post_floor", "guard_rover_boh", "guard_rover_upper", "guard_alley_smoker", "security_operator"],
	# night_deposit.md §Rare events `armored_car_early`: 2 extra guards (night_deposit_mission.gd tag).
	"night_deposit": ["guard_armored_car"],
}
## The roster spawn tags at D-115 (used only when docs/ is not in the checkout); D-130 adds SL's late_staff tags.
const ROSTER_FALLBACK: Dictionary = {
	"glasshouse": ["civ_staff_counter", "civ_staff_floor", "civ_staff_workshop", "civ_staff_admin", "civ_staff_manager",
		"civ_customer"],
	"night_deposit": ["guard_hall", "guard_basement", "guard_rover", "security_operator", "civ_cleaner", "civ_manager"],
	"dockside_burn": ["cartel_gate", "cartel_yard_w", "cartel_yard_e", "cartel_hall", "cartel_platform", "cartel_dock",
		"cartel_quay", "cartel_reinf", "civ_worker", "police"],
	"shadow_ledger": ["guard_reception", "guard_rover_l41", "guard_rover_l42", "guard_stair", "guard_roof",
		"security_operator", "civ_cleaner_l41", "civ_cleaner_l42", "civ_it", "civ_partner", "civ_kessler",
		"civ_assistant", "civ_associate"],
	"gallery_night": ["guard_hall", "guard_rover_ground", "guard_rover_upper", "guard_rover_basement", "guard_mews",
		"security_operator", "guard_inspection", "guard_vaultline", "civ_curator", "civ_attendant", "civ_waitstaff",
		"civ_conservator", "civ_admin", "civ_patron"],
}
## D-116 DB / SL cast polish (in the spirit of GN-D1): roles that put several NPCs on screen draw from a shared pool of
## looks ([heist, the roles of the pool, minimum looks, minimum looks of each gender (0: any mix)]); a gallery_night
## role missing from heists.gallery_night is read from tag_map.gallery_night (its spawn tags). Every pool lists the same looks on each of
## its roles, has at least that many distinct looks, and no two looks share a face (gender, skin, hair, hair colour
## and an age bucket from SOURCE.txt params), so two NPCs drawn from the pool are never twins. D-115 DB cast: the cartel
## pool has 12 looks (up to 12 posted gunmen at Cataclysm), civ_worker the three yard hands dock_worker a-c. D-130
## (Cataclysm: about +50 % guards, +35 % civilians on GN, SL and ND): GN guards 9 looks, 12 since the Cataclysm
## inspection fields 11 (at least 4 women), SL Northgate guards 9, ND Halden guards 6; civilians: SL cleaners 4,
## ND cleaners 2, GN patrons 12; GN gala_extra
## (cloakroom waitstaff + drawings-cabinet attendant): GN waitstaff 3, GN attendants 3. OF-D1 (an L heist, up to 6 guards,
## 4 tellers, 3 officers and 13 customers): OF Halden guards 10 (at least 3 women), tellers 5, officers 4, customers 12.
## D-140 twins audit: Glasshouse guards 10 (one Halden pool on every post + the operator), customers 12.
## RT-D1 (three trucks x driver + custodian): Vaultline crew 6 (at least 2 women), site guards 10, street civilians 12.
const POOLS: Array = [
	["dockside_burn", ["cartel_gate", "cartel_yard_w", "cartel_yard_e", "cartel_hall", "cartel_platform", "cartel_dock",
		"cartel_quay", "cartel_reinf"], 12, 1],
	["shadow_ledger", ["guard_reception", "guard_rover_l41", "guard_rover_l42", "guard_stair", "guard_roof",
		"security_operator"], 9, 1],
	["shadow_ledger", ["civ_cleaner_l41", "civ_cleaner_l42"], 4, 1],
	["dockside_burn", ["civ_worker"], 3, 1],
	["night_deposit", ["guard_hall", "guard_basement", "guard_rover"], 6, 1],
	["gallery_night", ["gallery_guard", "gallery_inspector", "guard_hall", "guard_rover_ground", "guard_rover_upper",
		"guard_rover_basement", "guard_mews", "guard_operator", "guard_inspection"], 12, 4],
	["night_deposit", ["civ_cleaner"], 2, 1],
	["gallery_night", ["gallery_patron", "civ_patron"], 12, 3],
	["gallery_night", ["gallery_waitstaff", "civ_waitstaff"], 3, 1],
	["gallery_night", ["gallery_attendant", "civ_attendant"], 3, 1],
	["ostrander_federal", ["guard_lobby", "guard_vault", "guard_rover_hall", "guard_rover_gallery",
		"guard_rover_basement", "guard_rover_dock", "guard_extra_hall", "guard_extra_basement"], 10, 3],
	["ostrander_federal", ["bank_teller", "civ_teller"], 5, 2],
	["ostrander_federal", ["bank_officer", "civ_officer", "civ_sd_attendant"], 4, 1],
	["ostrander_federal", ["civ_customer", "civ_plaza", "civ_client"], 12, 4],
	["glasshouse", ["guard_post_floor", "guard_rover_boh", "guard_rover_upper", "guard_alley_smoker",
		"security_operator"], 10, 3],
	["glasshouse", ["civ_customer"], 12, 4],
	["rolling_thunder", ["convoy_t1", "convoy_t2", "convoy_t3"], 6, 2],
	["rolling_thunder", ["site_guard", "guard_site_gate", "guard_site_frame", "guard_site_cabins"], 10, 3],
	["rolling_thunder", ["street_civilian", "civ_street", "civ_bus"], 21, 7],
	["rolling_thunder", ["civ_diner"], 14, 4],
	["rolling_thunder", ["diner_staff", "staff_diner"], 2, 1],
	["rolling_thunder", ["carpark_attendant", "staff_booth"], 1, 0],
	["rolling_thunder", ["ram_driver", "driver_mixer"], 1, 0],
]
## Northgate Executive Protection's own shirt; no other firm's livery (Halden char_sec_, bank, police).
const NORTHGATE_SHIRT: String = "char_ng_shirt"
## Minimum ids per role where the brief asks for several.
const MIN_COUNT: Dictionary = {
	"gallery_attendant": 3, "gallery_patron": 12, "gallery_waitstaff": 3, "bank_teller": 2, "bank_officer": 2,
	"bank_customer": 4, "armored_car_crew": 2,
	"club_bouncer": 2, "club_bartender": 2, "club_patron": 4,
}
## New characters whose pager is answered at Hip/Socket (a belt radio).
const RADIO: Array[String] = [
	"char_gallery_guard", "char_gallery_guard_b", "char_gallery_guard_c", "char_gallery_guard_d", "char_gallery_guard_e",
	"char_gallery_guard_f", "char_gallery_guard_g", "char_gallery_guard_h", "char_gallery_guard_i",
	"char_gallery_guard_j", "char_gallery_guard_k", "char_gallery_guard_l",
	"char_armored_car_crew", "char_armored_car_crew_b", "char_club_bouncer", "char_club_bouncer_b",
	"char_armored_car_crew_c", "char_armored_car_crew_d", "char_armored_car_crew_e", "char_armored_car_crew_f",
	"char_armored_car_marshal",
]
## Halberd Gallery Security (D-130: nine faces a-i; twelve, a-l, for the Cataclysm inspection).
const GN_GUARDS: Array[String] = [
	"char_gallery_guard", "char_gallery_guard_b", "char_gallery_guard_c", "char_gallery_guard_d", "char_gallery_guard_e",
	"char_gallery_guard_f", "char_gallery_guard_g", "char_gallery_guard_h", "char_gallery_guard_i",
	"char_gallery_guard_j", "char_gallery_guard_k", "char_gallery_guard_l",
]
## Vaultline Armored Transport (RT-D1: six crew faces a-f and the route marshal).
const VAULTLINE: Array[String] = [
	"char_armored_car_crew", "char_armored_car_crew_b", "char_armored_car_crew_c", "char_armored_car_crew_d",
	"char_armored_car_crew_e", "char_armored_car_crew_f", "char_armored_car_marshal",
]
## Roles whose bodies carry a pager (p5_cast.json pager_roles; club_bouncer per QC-70).
const PAGER_ROLES: Array[String] = ["gallery_guard", "bank_guard", "armored_car_crew", "club_bouncer"]
## New pager-role characters without a modelled radio (none: club_bouncer's radio is clipped
## outside the bomber on its waistband since QC-70).
const NO_RADIO: Array[String] = []
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
## QC-58c: the admin PA wears day office wear (the teal cardigan), never black tie or front-of-house kit.
const ADMIN_OFFICE: String = "char_knit_teal"
const GALA_KIT: Array[String] = ["char_tux_black", "char_satin_black", "char_velvet_midnight", "char_gallery_green",
	"char_glove_white", "char_gallery_bone"]
## GN-D1: p5_cast.json tag_map.gallery_night is the spawn tag -> ids map ENV A mirrors into
## NpcVisualTweak.heist_tag_characters.gallery_night. Its roster (gallery_night.md spawn data) names the
## camera operator CAMERA_OPERATOR; the greybox spawn (gn_content.gd) tags it guard_operator.
const GN: String = "gallery_night"
const OF: String = "ostrander_federal"
## ostrander_federal.md roster spawn tags (civ_manager_<route> expanded over manager_route mgr_floor / mgr_gallery /
## mgr_vault; the CAMERA_OPERATOR spawn is security_operator).
const OF_TAGS: Array[String] = ["guard_lobby", "guard_vault", "guard_rover_hall", "guard_rover_gallery",
	"guard_rover_basement", "guard_rover_dock", "guard_extra_hall", "guard_extra_basement", "security_operator",
	"civ_teller", "civ_sd_attendant", "civ_manager_mgr_floor",
	"civ_manager_mgr_gallery", "civ_manager_mgr_vault", "civ_customer", "civ_plaza", "civ_client", "civ_officer", "civ_vip",
	"guard_vip", "guard_vaultline"]
const GN_OPERATOR_TAG: String = "guard_operator"
## Up to nine patrons are live at once (gallery_night.md: `patrons` 3-9), twelve at Cataclysm (D-130: about +35 %
## civilians), so twelve looks keep the crowd free of twins; at least this many of each gender.
const GN_MAX_PATRONS: int = 12
const GN_MIN_PER_GENDER: int = 3
## Tags whose several live NPCs must be able to wear different looks (2 attendants, 1-2 waitstaff).
const GN_PAIRED_TAGS: Array[String] = ["civ_attendant", "civ_waitstaff"]
## Staff, security and work kit no gala patron wears (patrons are evening wear only).
const GN_NOT_EVENING: Array[String] = ["char_glove_white", "char_gallery_green", "char_gallery_bone", "char_knit_teal",
	"char_knit_grey", "char_work_charcoal", "char_vl_amber"]

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


## Material ids (file names without .tres) used by one character.
func _materials(asset_id: String) -> Array[String]:
	var out: Array[String] = []
	var root: Node3D = _instance(asset_id)
	if root == null:
		return out
	for mi: MeshInstance3D in _meshes(root):
		var look: Array[Material] = Layers.look_materials(mi)
		for s: int in range(look.size()):
			var m: Material = look[s]
			if m != null and m.resource_path.begins_with(MAT_DIR):
				var id: String = m.resource_path.get_file().get_basename()
				if not out.has(id):
					out.append(id)
	root.queue_free()
	return out


func _role_ids(heist: String, role: String) -> Array:
	var heists: Dictionary = _cast.get("heists", {}) as Dictionary
	return (heists.get(heist, {}) as Dictionary).get(role, []) as Array


## A pool role's ids: the heist role, or (gallery_night spawn tags) the tag_map entry.
func _pool_ids(heist: String, role: String) -> Array:
	var heists: Dictionary = _cast.get("heists", {}) as Dictionary
	if (heists.get(heist, {}) as Dictionary).has(role):
		return _role_ids(heist, role)
	return ((_cast.get("tag_map", {}) as Dictionary).get(heist, {}) as Dictionary).get(role, []) as Array


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
			var look: Array[Material] = Layers.look_materials(mi)
			for s: int in range(look.size()):
				var m: Material = look[s]
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


## Roles of one heist's design roster table (spawn tags), or ROSTER_FALLBACK when the doc is absent.
func _design_roles(heist: String) -> Array[String]:
	var out: Array[String] = []
	var doc: String = ProjectSettings.globalize_path("res://").path_join("../docs/design/heists/%s.md" % heist)
	if not FileAccess.file_exists(doc):
		out.assign(ROSTER_FALLBACK[heist])
		return out
	var lines: PackedStringArray = FileAccess.get_file_as_string(doc).split("\n")
	var start: int = -1
	for i: int in range(lines.size()):
		if lines[i].begins_with("### ") and lines[i].contains(ROSTER_HEADING):
			start = i + 1
			break
	assert_true(start >= 0, "%s.md: has a '### ... %s' section" % [heist, ROSTER_HEADING])
	if start < 0:
		return out
	var tick: RegEx = RegEx.create_from_string("`([a-z0-9_]+)`")
	var col: int = -1
	var in_table: bool = false
	for i: int in range(start, lines.size()):
		var line: String = lines[i].strip_edges()
		if not line.begins_with("|"):
			if in_table:
				break
			continue
		in_table = true
		var cells: PackedStringArray = line.split("|")
		if col < 0:
			for c: int in range(cells.size()):
				if cells[c].strip_edges() == "Spawn tags":
					col = c
			continue
		if col >= cells.size() or cells[col].strip_edges().begins_with("---"):
			continue
		var cell: String = cells[col]
		var found: Array[String] = []
		if cell.contains("CAMERA_OPERATOR"):
			found.append(OPERATOR_ROLE)
		elif cells[1].strip_edges().begins_with("Police"):
			found.append(POLICE_ROLE)
		else:
			for m: RegExMatch in tick.search_all(cell):
				found.append(m.get_string(1))
		assert_false(found.is_empty(), "%s.md roster row has a spawn tag: %s" % [heist, line.left(60)])
		for r: String in found:
			if not out.has(r):
				out.append(r)
	assert_true(col >= 0, "%s.md roster table has a 'Spawn tags' column" % heist)
	return out


## D-115: every role of the four pre-P5 heist designs (the roster table's spawn tags plus
## EXTRA_ROLES) is cast in p5_cast.json with >= 1 id that is in characters.json and whose scene loads.
func test_design_rosters_have_a_cast() -> void:
	var by_id: Dictionary = {}
	for asset: String in _index:
		by_id[String((_index[asset] as Dictionary)["id"])] = _index[asset]
	var loaded: Dictionary = {}
	for heist: String in DESIGN_HEISTS:
		var roles: Array[String] = _design_roles(heist)
		for r: Variant in EXTRA_ROLES.get(heist, []) as Array:
			if not roles.has(String(r)):
				roles.append(String(r))
		assert_true(roles.size() >= 6, "%s: design roster parsed (%d roles)" % [heist, roles.size()])
		for role: String in roles:
			var ids: Array = _role_ids(heist, role)
			assert_true(ids.size() >= 1, "%s/%s: cast in p5_cast.json" % [heist, role])
			for cid: Variant in ids:
				var id: String = String(cid)
				assert_true(by_id.has(id), "%s/%s: %s in characters.json" % [heist, role, id])
				if not by_id.has(id):
					continue
				if not loaded.has(id):
					var scene: String = String((by_id[id] as Dictionary)["scene"])
					loaded[id] = ResourceLoader.exists(scene) and load(scene) is PackedScene
				assert_true(bool(loaded[id]), "%s/%s: %s scene loads" % [heist, role, id])


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
	var ids: Array[String] = GN_GUARDS.duplicate()
	ids.append_array(VAULTLINE)
	for id: String in ids:
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


## QC-58c (gallery_night.md, `late_paperwork`): the admin PA reads as an office worker after hours.
func test_admin_pa_office_wear() -> void:
	var mats: Array[String] = _materials("char_gallery_admin")
	assert_has(mats, ADMIN_OFFICE, "admin PA wears the teal cardigan")
	for m: String in GALA_KIT:
		assert_false(mats.has(m), "admin PA must not wear gala/front-of-house %s" % m)


func _gn_tag_map() -> Dictionary:
	return (_cast.get("tag_map", {}) as Dictionary).get(GN, {}) as Dictionary


## GN-D1: tag_map.gallery_night covers every spawn tag of gallery_night.md's roster table (CAMERA_OPERATOR
## -> guard_operator), each tag's ids are cast in a gallery_night role and load, and the conservator,
## the patrons and the staff never share a look.
func test_gallery_tag_map() -> void:
	var tags: Dictionary = _gn_tag_map()
	assert_false(tags.is_empty(), "p5_cast.json has tag_map.%s" % GN)
	var cast_ids: Array[String] = []
	var roles: Dictionary = (_cast.get("heists", {}) as Dictionary).get(GN, {}) as Dictionary
	for role: String in roles:
		for cid: Variant in roles[role]:
			cast_ids.append(String(cid))
	for r: String in _design_roles(GN):
		var tag: String = GN_OPERATOR_TAG if r == OPERATOR_ROLE else r
		assert_true(tags.has(tag), "%s roster tag %s is in tag_map" % [GN, tag])
	var by_id: Dictionary = {}
	for asset: String in _index:
		by_id[String((_index[asset] as Dictionary)["id"])] = _index[asset]
	for tag: String in tags:
		var ids: Array = tags[tag] as Array
		assert_true(ids.size() >= 1, "%s/%s: >= 1 id" % [GN, tag])
		for cid: Variant in ids:
			var id: String = String(cid)
			assert_has(cast_ids, id, "%s/%s: %s is cast in a %s role" % [GN, tag, id, GN])
			assert_true(by_id.has(id) and ResourceLoader.exists(String((by_id.get(id, {}) as Dictionary).get("scene", ""))),
					"%s/%s: %s scene exists" % [GN, tag, id])
	for tag: String in GN_PAIRED_TAGS:
		var ids: Array = tags.get(tag, []) as Array
		var uniq: Dictionary = {}
		for cid: Variant in ids:
			uniq[String(cid)] = true
		assert_true(uniq.size() >= 2, "%s/%s: >= 2 distinct looks (%s)" % [GN, tag, ids])
	var staff: Array[String] = []
	for tag: String in tags:
		if tag != "civ_patron":
			for cid: Variant in tags[tag]:
				staff.append(String(cid))
	for cid: Variant in tags.get("civ_patron", []) as Array:
		assert_false(staff.has(String(cid)), "%s: patron %s is not also staff/security" % [GN, cid])
	for cid: Variant in tags.get("civ_conservator", []) as Array:
		assert_false((tags.get("civ_attendant", []) as Array).has(cid), "%s: conservator %s is not an attendant" % [GN, cid])


## OF-D1: tag_map.ostrander_federal carries every roster spawn tag (ostrander_federal.md, "Staff, civilian and guard
## roster"), each id is cast in an ostrander_federal role and has a scene, and the rare vip_client pair has its own looks.
func test_of_tag_map() -> void:
	var tags: Dictionary = ((_cast.get("tag_map", {}) as Dictionary).get(OF, {}) as Dictionary)
	assert_false(tags.is_empty(), "p5_cast.json has tag_map.%s" % OF)
	var cast_ids: Array[String] = []
	var roles: Dictionary = (_cast.get("heists", {}) as Dictionary).get(OF, {}) as Dictionary
	for role: String in roles:
		for cid: Variant in roles[role]:
			cast_ids.append(String(cid))
	var by_id: Dictionary = {}
	for asset: String in _index:
		by_id[String((_index[asset] as Dictionary)["id"])] = _index[asset]
	for tag: String in OF_TAGS:
		assert_true(tags.has(tag), "%s roster tag %s is in tag_map" % [OF, tag])
	for tag: String in tags:
		var ids: Array = tags[tag] as Array
		assert_true(ids.size() >= 1, "%s/%s: >= 1 id" % [OF, tag])
		for cid: Variant in ids:
			var id: String = String(cid)
			assert_has(cast_ids, id, "%s/%s: %s is cast in a %s role" % [OF, tag, id, OF])
			assert_true(by_id.has(id) and ResourceLoader.exists(String((by_id.get(id, {}) as Dictionary).get("scene", ""))),
					"%s/%s: %s scene exists" % [OF, tag, id])
	assert_eq(tags.get("guard_vip", []), ["security_bodyguard"], "%s/guard_vip: the Halden bodyguard" % OF)
	assert_eq(tags.get("civ_vip", []), ["bank_vip_client"], "%s/civ_vip: the VIP client" % OF)
	for tag: String in ["civ_customer", "civ_plaza", "civ_client", "guard_lobby"]:
		for cid: String in ["security_bodyguard", "bank_vip_client"]:
			assert_false((tags.get(tag, []) as Array).has(cid), "%s/%s: %s only appears for vip_client" % [OF, tag, cid])


## GN-D1: up to nine live patrons get nine distinct evening-wear looks, both genders (SOURCE.txt params).
func test_gallery_patron_variety() -> void:
	var ids: Array = _gn_tag_map().get("civ_patron", []) as Array
	var uniq: Dictionary = {}
	for cid: Variant in ids:
		uniq[String(cid)] = true
	assert_eq(uniq.size(), ids.size(), "%s/civ_patron: no id listed twice" % GN)
	assert_true(uniq.size() >= GN_MAX_PATRONS, "%s/civ_patron: %d looks for up to %d patrons" % [GN, uniq.size(), GN_MAX_PATRONS])
	var women: int = 0
	var men: int = 0
	for id: String in uniq:
		var asset: String = "char_" + id
		var src: Dictionary = Spec.read_source("%s%s/SOURCE.txt" % [Spec.ASSETS_DIR, asset])
		var params: Variant = JSON.parse_string(String(src.get("params", "{}")))
		assert_true(params is Dictionary and (params as Dictionary).has("gender"), "%s: SOURCE.txt params.gender" % asset)
		if params is Dictionary:
			if float((params as Dictionary).get("gender", 0.5)) >= 0.5:
				women += 1
			else:
				men += 1
		var mats: Array[String] = _materials(asset)
		for bad: String in GN_NOT_EVENING:
			assert_false(mats.has(bad), "%s: patron in evening wear, not %s" % [asset, bad])
	assert_true(women >= GN_MIN_PER_GENDER and men >= GN_MIN_PER_GENDER,
			"%s/civ_patron: both genders (%d women, %d men)" % [GN, women, men])


func _face(asset: String) -> String:
	var src: Dictionary = Spec.read_source("%s%s/SOURCE.txt" % [Spec.ASSETS_DIR, asset])
	var p: Variant = JSON.parse_string(String(src.get("params", "{}")))
	if not p is Dictionary:
		return ""
	var d: Dictionary = p
	return "%s/%s/%s/%s/%d" % [roundi(float(d.get("gender", 0.0))), d.get("skin", -1), d.get("hair", ""),
			d.get("hair_color", ""), int(float(d.get("age", 0.0)) * 4.0)]


func test_db_sl_pooled_variety() -> void:
	for pool: Array in POOLS:
		var heist: String = pool[0]
		var roles: Array = pool[1]
		var first: Array = _pool_ids(heist, String(roles[0]))
		for role: Variant in roles:
			assert_eq(_pool_ids(heist, String(role)), first, "%s/%s: the pool's looks" % [heist, role])
		var uniq: Dictionary = {}
		for cid: Variant in first:
			uniq[String(cid)] = true
		assert_eq(uniq.size(), first.size(), "%s/%s: no id listed twice" % [heist, roles[0]])
		assert_true(uniq.size() >= int(pool[2]), "%s/%s: %d looks (>= %d)" % [heist, roles[0], uniq.size(), pool[2]])
		var faces: Dictionary = {}
		var genders: Dictionary = {"0": 0, "1": 0}
		for id: String in uniq:
			var f: String = _face("char_" + id)
			assert_false(f.is_empty(), "char_%s: SOURCE.txt params" % id)
			assert_false(faces.has(f), "%s: %s and %s share a face (%s)" % [heist, id, faces.get(f, ""), f])
			faces[f] = id
			var gk: String = f.get_slice("/", 0)
			genders[gk] = int(genders.get(gk, 0)) + 1
		var per: int = int(pool[3])
		assert_true(int(genders["0"]) >= per and int(genders["1"]) >= per,
				"%s/%s: >= %d of each gender (%d men, %d women)" % [heist, roles[0], per, genders["0"], genders["1"]])
	# D-115 DB cast: the packer in processing whites works the packing table (civ_worker_packer), never the yard pool.
	assert_false(_role_ids("dockside_burn", "civ_worker").has("dock_packer"), "dockside_burn/civ_worker: no dock_packer")


func test_northgate_livery() -> void:
	for cid: Variant in _role_ids("shadow_ledger", "guard_reception"):
		var asset: String = "char_" + String(cid)
		var mats: Array[String] = _materials(asset)
		assert_has(mats, NORTHGATE_SHIRT, "%s: wears the Northgate shirt" % asset)
		for m: String in mats:
			for bad: String in OTHER_LIVERY:
				if bad != "char_ng_":
					assert_false(m.begins_with(bad), "%s: no other company's livery (%s)" % [asset, m])
