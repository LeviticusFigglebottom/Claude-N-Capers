## Gallery Night map (GN-C1 G1 step 2): contract nodes, ENV B's def / variant table wired, every variant slot of the
## table, the B2 door lock table, the B5 marker tags, the B6 camera layout, key lights on viewmodel_lit (B1), the
## B3 fail-reason rule in the mission stub. Owner: ENV C. Design: docs/design/heists/gallery_night.md (Build rulings
## B1-B7). Contract: docs/contracts/heist_map.md v1.2.
extends TestCase

const SCENE: String = "res://world/heists/gallery_night/gallery_night.tscn"
const DEF: String = "res://world/heists/gallery_night/gallery_night_def.tres"
const VARIANTS: String = "res://world/heists/gallery_night/gallery_night_variants.tres"
const MISSION: String = "res://world/heists/gallery_night/gallery_night_mission.gd"
## ENV B's drafts: the registry copies must stay byte-identical while the drafts exist (B owns the data).
const DRAFTS: String = "res://content/_drafts/gallery_night/"
const REQUIRED: Dictionary = {
	"Geometry": "Node3D", "Props": "Node3D", "Lighting": "Node3D", "Navigation": "NavigationRegion3D",
	"Zones": "Node3D", "Rooms": "Node3D", "Spawns": "Node3D", "Patrols": "Node3D", "Tactical": "Node3D",
	"Gameplay": "Node3D", "Variants": "Node3D", "Mission": "Node", "Preplan": "Node3D", "ReviewCameras": "Node3D",
}
## B2 lock table (door.gd Lock names); route doors (B4.7) are >= 1.0 m.
const LOCKS: Dictionary = {
	"StaffDoor": "LOCKPICK", "ArtHandlingDoor": "LOCKPICK", "DockPersonnelDoor": "LOCKPICK", "GiftShopDoor": "LOCKPICK",
	"StudioGalleryDoor": "LOCKPICK", "HeadHouseDoor": "LOCKPICK", "ArtDoorEG": "KEYCARD", "TreasuryDoor": "KEYCARD",
	"ServerDoor": "CODE", "ArtStoreVaultDoor": "VAULT", "BronzeDoorsW": "NONE", "BronzeDoorsE": "NONE",
	"SecurityDoor": "NONE", "CuratorDoor": "NONE", "StudioDoor": "NONE", "AttendantDoorN": "NONE",
	"AttendantDoorW": "NONE", "StairDoorB": "NONE", "StairDoorG": "NONE", "StairDoorU": "NONE",
}
const ROUTE_DOORS: Array[String] = ["StaffDoor", "CuratorDoor", "ServerDoor", "StudioDoor", "AttendantDoorN",
	"AttendantDoorW", "TreasuryDoor", "HeadHouseDoor"]
const COURT_LOCKS: Dictionary = {"court_doors_open": "NONE", "court_doors_locked": "LOCKPICK"}
## B5 tags every map must carry (somewhere; per-slot tags are checked per slot below).
const TAGS: Array[StringName] = [&"casing_hall", &"hack", &"server_door", &"treasury_door", &"vault_reader",
	&"vault_drill", &"shutter", &"lockers", &"curator_safe"]
const SLOT_TAGS: Dictionary = {
	"centrepiece": &"canvas_lantern", "canvas_orchard": &"canvas_orchard", "canvas_widow": &"canvas_widow",
	"canvas_saint": &"canvas_saint", "keycard": &"keycard", "code_note": &"code_note",
}
const ALWAYS_CAMERAS: Array[String] = ["CameraC11", "CameraC14"]

var _map: HeistMap = null


func before_all() -> void:
	var ps: PackedScene = load(SCENE) as PackedScene
	if ps != null:
		_map = ps.instantiate() as HeistMap


func after_all() -> void:
	if _map != null:
		_map.free()


func test_map_and_registry() -> void:
	assert_true(_map != null, "gallery_night.tscn instantiates a HeistMap")
	assert_eq(HeistRegistry.map_scene_path(&"gallery_night"), SCENE, "HeistRegistry resolves the map")
	assert_true(HeistRegistry.get_def(&"gallery_night") != null, "HeistRegistry lists gallery_night")


func test_contract_nodes() -> void:
	if _map == null:
		fail("map missing")
		return
	for n: String in REQUIRED:
		var c: Node = _map.get_node_or_null(n)
		assert_true(c != null and c.is_class(REQUIRED[n]), "required child %s (%s)" % [n, REQUIRED[n]])
	assert_true(_map.get_node("Mission") is HeistMission, "Mission script extends HeistMission")
	assert_eq(_map.floor_heights, PackedFloat32Array([-4.2, 0.0, 5.4, 9.0]), "floor_heights")
	assert_eq(_map.floor_names, PackedStringArray(["Basement", "Ground", "Upper", "Roof"]), "floor_names")
	var nav: NavigationRegion3D = _map.get_node("Navigation") as NavigationRegion3D
	assert_true(nav.navigation_mesh != null and nav.navigation_mesh.get_polygon_count() > 0, "baked navmesh")
	var kinds: Dictionary = {}
	for z: Node in _map.find_children("*", "MapZone", true, false):
		kinds[(z as MapZone).kind] = true
	assert_true(kinds.has(MapZone.Kind.ESCAPE) and kinds.has(MapZone.Kind.SECURE_LOOT), "ESCAPE + SECURE_LOOT zones")


func test_def_and_table_are_bs() -> void:
	if _map == null:
		fail("map missing")
		return
	assert_true(_map.heist_def != null and _map.heist_def.resource_path == DEF, "heist_def is the registry def")
	assert_true(_map.variant_table != null and _map.variant_table.resource_path == VARIANTS, "variant_table wired")
	assert_eq(_map.heist_def.id, &"gallery_night", "def id")
	for f: String in ["gallery_night_def.tres", "gallery_night_variants.tres"]:
		if FileAccess.file_exists(DRAFTS + f):
			assert_true(FileAccess.get_file_as_bytes(DRAFTS + f) == FileAccess.get_file_as_bytes(
				"res://world/heists/gallery_night/" + f), "%s byte-identical to ENV B's draft" % f)


## Every rule group of B's table has >= 2 slots in the map; every force_active / weights key names a real slot.
func test_variant_slots_match_table() -> void:
	if _map == null:
		fail("map missing")
		return
	var slots: Dictionary = {}
	for vs: Node in _map.get_node("Variants").find_children("*", "VariantSlot", true, false):
		var s: VariantSlot = vs as VariantSlot
		if not slots.has(s.slot_group):
			slots[s.slot_group] = []
		(slots[s.slot_group] as Array).append(s.slot_id)
	for r: Dictionary in _map.variant_table.rules:
		var g: StringName = r["group"]
		assert_true(slots.has(g) and (slots[g] as Array).size() >= 2, "group %s has >= 2 slots" % g)
		for d: Variant in (r.get("weights_by_difficulty", {}) as Dictionary).values():
			for sid: Variant in (d as Dictionary).keys():
				assert_has(slots.get(g, []), StringName(sid), "%s weight key %s is a slot" % [g, sid])
	for ev: Dictionary in _map.variant_table.rare_events:
		var fa: Variant = (ev.get("effects", {}) as Dictionary).get("force_active")
		if fa is Dictionary:
			assert_has(slots.get(StringName((fa as Dictionary)["group"]), []), StringName((fa as Dictionary)["slot"]),
				"rare %s forces a real slot" % ev.get("id"))


func test_door_locks_b2() -> void:
	if _map == null:
		fail("map missing")
		return
	var doors: Node = _map.get_node("Gameplay/Doors")
	for nm: String in LOCKS:
		var d: Node = doors.get_node_or_null(nm)
		assert_true(d != null, "door %s exists" % nm)
		if d != null:
			assert_eq(int(d.get(&"lock")), int(Door.Lock[LOCKS[nm]]), "%s lock %s (B2)" % [nm, LOCKS[nm]])
	for nm2: String in ROUTE_DOORS:
		var r: Node = doors.get_node_or_null(nm2)
		assert_true(r != null and float(r.get(&"width_m")) >= 1.0, "%s is a >= 1.0 m route door (B4.7)" % nm2)
	assert_true(bool(doors.get_node("BronzeDoorsW").get(&"starts_open")), "bronze doors start open")
	assert_eq(PackedStringArray(doors.get_node("ArtStoreVaultDoor").get(&"npc_authorized_tags")),
		PackedStringArray(["guard_vaultline"]), "Vaultline couriers pass the vault door")
	for sid: String in COURT_LOCKS:
		var cd: Node = _map.get_node("Variants/Group_court_doors/Slot_%s/CourtDoors" % sid)
		assert_eq(int(cd.get(&"lock")), int(Door.Lock[COURT_LOCKS[sid]]), "court doors in %s" % sid)


func test_marker_tags_b5() -> void:
	if _map == null:
		fail("map missing")
		return
	var seen: Dictionary = {}
	for n: Node in _map.find_children("*", "", true, false):
		var t: Variant = n.get(&"objective_tag")
		if t != null and StringName(t) != &"":
			seen[StringName(t)] = true
	for tag: StringName in TAGS:
		assert_true(seen.has(tag), "a node carries objective_tag %s (B5)" % tag)
	for vs: Node in _map.get_node("Variants").find_children("*", "VariantSlot", true, false):
		var s: VariantSlot = vs as VariantSlot
		var want: Variant = SLOT_TAGS.get(String(s.slot_group))
		if s.slot_group == &"escape":
			var short: String = String(s.slot_id).trim_prefix("esc_")
			assert_true(_has_tag(s, StringName("secure_" + short)) and _has_tag(s, StringName("escape_" + short)),
				"%s holds secure_/escape_%s" % [s.slot_id, short])
		elif want != null:
			assert_true(_has_tag(s, want), "slot %s holds a %s node" % [s.slot_id, want])


func test_cameras_b6() -> void:
	if _map == null:
		fail("map missing")
		return
	assert_eq(_map.get_meta(&"camera_spine_rooms"), PackedStringArray(["BC", "UC"]), "camera_spine_rooms")
	assert_eq(_map.get_meta(&"camera_screen_slots"), PackedStringArray(["orchard_calloway", "widow_sallow",
		"saint_maritime"]), "camera_screen_slots")
	for c: String in ALWAYS_CAMERAS:
		assert_true(_map.get_node_or_null("Gameplay/Cameras/" + c) is SecurityCamera, "%s live in every layout" % c)
	for sid: String in ["cam_a", "cam_b", "cam_c"]:
		var slot: Node = _map.get_node("Variants/Group_camera/Slot_" + sid)
		assert_eq(slot.find_children("*", "SecurityCamera", true, false).size(), 6, "%s holds 6 cameras" % sid)
	var screens: int = 0
	for p: Node in _map.get_node("Props").find_children("*", "StaticBody3D", true, false):
		if String(p.get_meta(&"kind", "")) == "partition_screen":
			screens += 1
	assert_eq(screens, 2, "two partition screens (UG1, UG3)")


func test_key_lights_viewmodel_lit() -> void:
	if _map == null:
		fail("map missing")
		return
	var lights: Array[Node] = _map.get_node("Lighting").find_children("*", "Light3D", true, false)
	assert_true(lights.size() >= 30, "a key light per interior room")
	for l: Node in lights:
		assert_true(((l as Light3D).layers & (1 << 20)) != 0, "%s on viewmodel_lit (D-095)" % l.name)


## B3: custody / abort only; the stub never fails the heist itself nor uses the stealth-only reason.
func test_mission_fail_reasons_b3() -> void:
	var src: String = FileAccess.get_file_as_string(MISSION)
	assert_false(src.contains("stealth_only_alarm") or src.contains("FAIL_STEALTH_ONLY_ALARM"), "no stealth-only fail")
	assert_false(src.contains("end_heist(false"), "the mission never ends the heist as failed")


func _has_tag(root: Node, tag: StringName) -> bool:
	for n: Node in root.find_children("*", "", true, false):
		var t: Variant = n.get(&"objective_tag")
		if t != null and StringName(t) == tag:
			return true
	return false
