## Gallery Night gameplay content (GN-C1 G1 step 2). Owner: ENV C.
## Chain: gn_builder_base <- gn_gameplay <- gn_content <- gn_npc <- build_greybox.
## Replaces the step-1 placeholders with ENV A's prefabs (found by contract class name): the list canvases
## (`loot_spawn`, B5 objective_tags canvas_*), studies, keycards, code notes, the Argus hack terminal, keypad and
## readers (TR, AS vault, LD art door), the drill points, cameras C1-C14 (layouts under cam_a/b/c; C11 and C14 always
## live, B6) with the partition screens, the TR laser grid, the CO safe, the consignment lockers, small loot, phones,
## alarm buttons, the Mews bins, both ladders and the escape / secure zones. Visuals come from the prop catalog where it
## has one (camera, reader, keypad, phone, alarm button, safe-less items, the van, ladders); everything else keeps the
## prefab's placeholder (the ENV D / prop brief lists them: canvases, studies, wall safe, deposit boxes, the 9 m caged
## ladder, the limo, the shutters, the vitrines' sketchbooks). Greybox support boxes (desks, counters, the bar, the
## key cabinet, the partition screens) live under Props with meta kind / support. Design: gallery_night.md (B2, B5,
## B6; Loot path; Sightlines; Escape).
extends "res://world/heists/gallery_night/greybox/gn_gameplay.gd"

## PO-13 escape visuals: the van / limo is the secure_zone's vehicle, the escape_zone carries only the contract nodes.
const ESCAPE_VAN_MARKER: String = "res://world/heists/shared/escape_van_marker.tscn"
## Drill points have no art of their own (visual_slots.md: the drill is a separate device visual).
const VIS_EMPTY: String = "res://world/heists/glasshouse/art/gh_empty.tscn"
const CUT_S: float = 4.0
const HACK_STEALTH_S: float = 60.0
const SERVER_DRILL_S: float = 60.0
const VAULT_DRILL_S: float = 240.0
## Laser grid (TR, z 26.5, x 36.1-43.8; B4.1). lz_static: origin 1.0 m above the floor (validator `lasers` finds the
## floor within 1 m) and 1.8 m tall, so its 3 beams sit at 1.30 / 1.90 / 2.50 m (low beam centre >= 1.30 m).
const LASER_Z: float = 26.5
const LASER_X: Vector2 = Vector2(36.1, 43.8)
const LASER_STATIC_Y: float = 1.0
const LASER_STATIC_H: float = 1.8
## cp_landing laser curtain (B4.1, enabled at last call by the mission, QC-53): across the half landing at z 9.6
## (between the canvas's UsePoint z 9.15 and the flights' arrival z 10.2) from x 17.6 to the east rail; its bypass is
## the >= 1.0 m gap west of it, at the west return flight. 5 beams to 2.4 m (no crouch-under).
const CURTAIN: Array = [17.6, 28.8, 9.6, 2.4, 5]
## Canvas loot ids per slot group (B README, the def's loot list).
const CANVAS_LOOT: Dictionary = {
	"centrepiece": &"loot.painting_lantern_bearer", "canvas_orchard": &"loot.painting_salt_orchard",
	"canvas_widow": &"loot.painting_widow_in_blue", "canvas_saint": &"loot.painting_tidewater_saint",
}
const STUDY_LOOT: StringName = &"loot.painting_study"
const SMALL_LOOT: StringName = &"loot.small_valuables"
## Wall-hung loot stands off its slot anchor by half the placeholder's depth (rehearsal F2).
const HUNG_OFFSET: float = 0.2
## Cameras (Sightlines table; B6): id -> [mount point (pivot on the wall face / ceiling), yaw (front -Z), mount].
const CAMERA_MOUNTS: Dictionary = {
	"C1": [Vector3(22.0, 3.2, 29.8), 0.0, "wall"],
	"C2": [Vector3(31.0, 5.1, 22.0), 45.0, "ceiling"],
	"C3": [Vector3(11.9, 3.2, 9.0), 90.0, "wall"],
	"C4": [Vector3(43.8, 3.2, 23.0), 90.0, "wall"],
	"C5": [Vector3(3.25, 2.8, 7.0), -90.0, "wall"],
	"C6": [Vector3(32.1, 3.2, 0.8), -90.0, "wall"],
	"C7": [Vector3(35.925, 3.2, -1.0), 90.0, "wall"],
	"C8": [Vector3(-0.2, 3.0, 9.0), 90.0, "wall"],
	"C9": [Vector3(11.9, 8.6, 17.5), 90.0, "wall"],
	"C10": [Vector3(32.6, 8.6, 12.1), 180.0, "wall"],
	"C11": [Vector3(43.8, 8.0, 24.6), 90.0, "wall"],
	"C12": [Vector3(31.8, -1.4, 7.0), 90.0, "wall"],
	"C13": [Vector3(3.25, 8.2, 7.0), -90.0, "wall"],
	"C14": [Vector3(31.8, -1.0, 8.8), 90.0, "wall"],
}
## C7's pole on the Mews at the LD roller door (the camera's wall).
const C7_POLE: Vector3 = Vector3(36.0, 0.0, -1.0)
## Studies (`loot.painting_study`, objective_tag study; doc Loot path: 1-2 per gallery): [name, slot-style anchor
## (0.1 m off the wall face), yaw (front -Z away from the wall)].
const STUDIES: Array = [
	["StudyWG1", Vector3(6.0, 0.0, 19.8), 0.0], ["StudyWG2", Vector3(9.5, 0.0, 19.8), 0.0],
	["StudyDC1", Vector3(0.3, 0.0, 23.5), -90.0], ["StudyDC2", Vector3(0.3, 0.0, 27.0), -90.0],
	["StudyEG1", Vector3(34.0, 0.0, 12.2), 180.0], ["StudyEG2", Vector3(42.0, 0.0, 12.2), 180.0],
	["StudyEB1", Vector3(42.5, 0.0, 24.2), 180.0],
	["StudyUG1a", Vector3(4.0, 5.4, 8.2), 180.0], ["StudyUG1b", Vector3(9.0, 5.4, 8.2), 180.0],
	["StudyUG2a", Vector3(4.0, 5.4, 29.7), 0.0], ["StudyUG2b", Vector3(8.0, 5.4, 29.7), 0.0],
	["StudyUG3a", Vector3(35.5, 5.4, 23.8), 0.0], ["StudyUG3b", Vector3(42.5, 5.4, 23.8), 0.0],
]
## AS rack studies (`store_paintings` 4/6/8: the mission keeps the first N, objective_tag store_study).
const STORE_STUDIES: Array = [
	Vector3(14.5, -4.2, 11.0), Vector3(28.5, -4.2, 14.0), Vector3(23.5, -4.2, 11.0), Vector3(17.5, -4.2, 14.0),
	Vector3(17.5, -4.2, 11.0), Vector3(23.5, -4.2, 14.0), Vector3(28.5, -4.2, 11.0), Vector3(14.5, -4.2, 14.0),
]
## Consignment lockers (`deposit_box`, saw; `consignment_lockers` 4/6/8: the mission keeps the first N) on the AS
## east wall face (x 31.8): [z, y].
const LOCKERS: Array = [[10.5, -3.3], [13.5, -3.3], [12.0, -3.3], [15.0, -3.3], [10.5, -2.8], [13.5, -2.8],
	[12.0, -2.8], [15.0, -2.8]]
const LOCKER_FACE_X: float = 31.8
## Phones (doc Circulation: CK, RG, SC, CO, AO, CS, AT, BR) and alarm buttons (SC console, AT, VE lectern): wall mounts
## [name, pivot on the wall face, yaw (front -Z into the room)].
const PHONES: Array = [
	["PhoneCloakroom", Vector3(12.1, 1.4, 27.0), -90.0], ["PhoneRegistrar", Vector3(18.1, 1.4, 2.0), -90.0],
	["PhoneSecurity", Vector3(17.9, 1.4, 5.0), 90.0], ["PhoneBreakRoom", Vector3(8.9, 1.4, 2.0), 90.0],
	["PhoneCurator", Vector3(9.9, 6.8, 4.5), 90.0], ["PhoneAdmin", Vector3(16.9, 6.8, 2.0), 90.0],
	["PhoneStudio", Vector3(42.0, 6.8, 11.9), 0.0], ["PhoneAttendants", Vector3(32.1, 6.8, 25.0), -90.0],
]
const ALARMS: Array = [
	["AlarmSecurity", Vector3(12.1, 1.1, 4.6), -90.0], ["AlarmAttendants", Vector3(35.9, 6.5, 26.0), 90.0],
	["AlarmVestibule", Vector3(18.1, 1.1, 28.0), -90.0],
]
## The three lockdown shutters (B2: the Calloway arch, the TR door, the LD art door). No shutter kit / 1 m industrial
## door exists yet (D brief; ENV A relock API, QC-55): tagged markers so `lockdown` resolves (B5 `shutter`).
const SHUTTERS: Array = [
	["ShutterCalloway", Vector3(12.0, 5.4, 13.0)], ["ShutterTreasury", Vector3(39.0, 5.4, 24.0)],
	["ShutterArtDoor", Vector3(38.0, 0.0, 12.0)],
]
## Escape / secure zones (Escape section; Build ruling B5 tags): slot -> [secure pos, secure yaw, escape pos, escape size].
## E1 van in the Mews at the LD roller door (rear doors east, toward the personnel door); E2 the limo at the portico
## kerb (the catalog van stands in for the limo until ENV D's limo visual: brief), its boot to the west.
const ESCAPES: Dictionary = {
	"esc_mews": [Vector3(36.5, 0.0, -4.2), -90.0, Vector3(39.0, 0.0, -1.4), Vector3(4.0, 3.0, 2.0)],
	"esc_parade": [Vector3(26.5, 0.0, 37.6), 90.0, Vector3(21.0, 0.0, 37.6), Vector3(3.6, 3.0, 2.4)],
}


# --- Helpers -------------------------------------------------------------------------------------

## A prefab whose visual is a catalog asset (or `vis` = a scene path, "" = the prefab's placeholder).
func cprefab(parent: Node3D, kind: String, nm: String, pos: Vector3, yaw: float, vis: String, props: Dictionary = {},
		use_point: Variant = null, metas: Dictionary = {}) -> Node3D:
	var p: Dictionary = props.duplicate()
	if vis != "":
		p["visual_scene"] = load(vis) as PackedScene if vis.begins_with("res://") else _catalog_scene(vis)
	var m: Dictionary = metas.duplicate()
	if not m.has("kind"):
		m["kind"] = kind
	return prefab(parent, kind, nm, pos, yaw, p, use_point, m)


## Nav obstruction for a prefab body from its catalog AABB ([x, y, z, sx, sy, sz], root-local).
func obstruct_catalog(asset_id: String, pos: Vector3, yaw: float) -> void:
	var a: Array = PropCatalog.entry(StringName(asset_id)).get("aabb", [])
	if a.size() == 6:
		obstruct(Transform3D(yaw_basis(yaw), pos), AABB(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5])))


static func front_of(yaw: float) -> Vector3:
	return yaw_basis(yaw) * Vector3.FORWARD


## A wall-mounted prefab (pivot on the wall face) with its UsePoint `reach` m in front on the floor `floor_y`.
func wall_prefab(parent: Node3D, kind: String, nm: String, pos: Vector3, yaw: float, floor_y: float, vis: String,
		props: Dictionary = {}, reach: float = 0.7) -> Node3D:
	var up: Vector3 = Vector3(pos.x, floor_y, pos.z) + front_of(yaw) * reach
	return cprefab(parent, kind, nm, pos, yaw, vis, props, up, {"mount": "wall", "kind": kind})


func tagged_marker(parent: Node3D, nm: String, pos: Vector3, tag: String, todo: String) -> Marker3D:
	return placeholder(parent, nm, pos, todo, tag)


## A list canvas / study `loot_spawn` at a slot-style anchor: wall-hung ones stand off the wall by HUNG_OFFSET; the
## UsePoint is USE_POINT_M in front on the anchor's floor.
func canvas(parent: Node3D, nm: String, anchor: Vector3, yaw: float, loot: StringName, tag: String, hung: bool) -> Node3D:
	var f: Vector3 = front_of(yaw)
	var pos: Vector3 = anchor + f * HUNG_OFFSET if hung else anchor
	var props: Dictionary = {"loot_id": loot, "count": 1, "interaction_time_s": CUT_S}
	if tag != "":
		props["objective_tag"] = StringName(tag)
	return cprefab(parent, "loot_spawn", nm, pos, yaw, "", props, anchor + f * L.USE_POINT_M, {"kind": "loot_spawn"})


## Pickup / note resting on a greybox support box: the box (Props) and the prefab on its top.
## `bx` = [box name, base (bottom-centre), size, yaw, kind].
func on_box(parent: Node3D, kind: String, nm: String, top: Vector3, yaw: float, vis: String, props: Dictionary,
		bx: Array) -> Node3D:
	var base: Vector3 = bx[1] as Vector3
	_prop_box(n("Props"), String(bx[0]), base, bx[2] as Vector3, float(bx[3]), String(bx[4]), true)
	var up: Vector3 = Vector3(top.x, base.y, top.z) + front_of(yaw) * L.USE_POINT_M
	return cprefab(parent, kind, nm, top, yaw, vis, props, up)


func spawn_at(parent: Node3D, nm: String, kind: String, pos: Vector3, yaw: float, tags: Array, idle: String,
		graph: String = "") -> SpawnPoint:
	var sp: SpawnPoint = spawn(parent, nm, kind, Vector3.ZERO, 0.0, tags, idle)
	sp.transform = global_xform(parent).affine_inverse() * Transform3D(yaw_basis(yaw), pos)
	if graph != "":
		sp.patrol_graph = sp.get_path_to(map_root.get_node("Patrols/" + graph))
	return sp


# --- Always-present gameplay -------------------------------------------------------------------

func build_devices(gp: Node3D) -> void:
	add(n("Props"), node3d("Greybox"))
	_build_security(gp)
	_build_argus(gp)
	_build_loot(gp)
	_build_misc(gp)
	_build_ladders(gp)
	var cams: Node3D = n("Gameplay/Cameras")
	for cid: String in ["C11", "C14"]:  # B6: live in every layout, outside any slot
		security_camera(cams, cid)
	add(cams, node3d("Poles"))
	_prop_box(n("Props/Greybox"), "CameraPoleC7", C7_POLE, Vector3(0.15, 3.6, 0.15), 0.0, "pole", false, "trim")
	for s: Array in L.SCREENS:   # B6 partition screens (2.4 m, freestanding)
		var a: Vector3 = Vector3(float(s[1]), 5.4, float(s[2]))
		var b: Vector3 = Vector3(float(s[3]), 5.4, float(s[4]))
		var along_z: bool = absf(b.z - a.z) > absf(b.x - a.x)
		var len_m: float = maxf(absf(b.z - a.z), absf(b.x - a.x))
		var scr: StaticBody3D = _prop_box(n("Props/Greybox"), "PartitionScreen" + String(s[0]), (a + b) * 0.5,
			Vector3(0.1, 2.4, len_m), 0.0 if along_z else 90.0, "partition_screen", false, "wall")
		scr.set_meta(&"room", String(s[0]))
	for sh: Array in SHUTTERS:
		tagged_marker(n("Gameplay/Markers"), String(sh[0]), sh[1] as Vector3, "shutter",
			"lockdown shutter (industrial_door BARRED on alarm; [hack] lifts it): ENV A relock API + ENV D shutter kit")


## SC: the camera station on the west (WC) wall, the operator's seat (CAMERA_OPERATOR spawn, read by the station and
## the security_room_staffed slot), the console alarm button.
func _build_security(gp: Node3D) -> void:
	var dev: Node3D = n("Gameplay/Devices")
	var seat: SpawnPoint = spawn_at(n("Spawns"), "CameraOperatorSeat", "CAMERA_OPERATOR", Vector3(13.5, 0.0, 3.0), 90.0,
		["guard_operator"], "desk_work")
	seat.set_meta(&"room", "SC")
	var st_pos: Vector3 = Vector3(12.5, 0.0, 3.0)
	var station: Node3D = cprefab(dev, "camera_station", "CameraStation", st_pos, -90.0, "prop_camera_station")
	obstruct_catalog("prop_camera_station", st_pos, -90.0)
	if station != null:
		station.set(&"operator_spawn", station.get_path_to(seat))
	gp.set_meta(&"security_room", "SC")


## Argus: the SV hack terminal (stealth 60 s, 1-2 interruptions; the mission retargets it to 120 s / 2-3 in loud,
## QC-55), the SV keypad (code group argus) and the loud drill on the SV door, the TR / AS vault / LD art door readers,
## the vault's thermal drill point (loud, 240 s).
func _build_argus(_gp: Node3D) -> void:
	var dev: Node3D = n("Gameplay/Devices")
	var rack: Vector3 = Vector3(26.5, 5.4, 0.75)
	cprefab(dev, "hack_terminal", "ArgusTerminal", rack, 180.0, "prop_server_rack_terminal",
		{"duration_s": HACK_STEALTH_S, "interruptions": Vector2i(1, 2), "objective_tag": &"hack"}, Vector3(26.5, 5.4, 2.2))
	obstruct_catalog("prop_server_rack_terminal", rack, 180.0)
	var doors: Node3D = n("Gameplay/Doors")
	var sv: Node3D = doors.get_node_or_null("ServerDoor") as Node3D
	var kp: Node3D = wall_prefab(dev, "keypad", "ServerKeypad", Vector3(26.0, 6.6, 6.1), 180.0, 5.4, "prop_keypad",
		{"code_group": CODE_GROUP, "objective_tag": &"server_keypad"})
	_bind_targets(kp, [sv])
	_drill(dev, "ServerDoorDrill", Vector3(25.0, 6.4, 6.15), 0.0, Vector3(25.0, 5.4, 6.9), SERVER_DRILL_S, "DRILL",
		"server_door", sv)
	var tr: Node3D = wall_prefab(dev, "keycard_reader", "TreasuryReader", Vector3(40.0, 6.6, 23.9), 0.0, 5.4,
		"prop_keycard_reader", {"objective_tag": &"treasury_door"})
	_bind_targets(tr, [doors.get_node_or_null("TreasuryDoor")])
	var vd: Node3D = doors.get_node_or_null("ArtStoreVaultDoor") as Node3D
	var vr: Node3D = wall_prefab(dev, "keycard_reader", "VaultReader", Vector3(23.2, -3.0, 7.8), 0.0, -4.2,
		"prop_keycard_reader", {"objective_tag": &"vault_reader", "stealth_only": true})
	_bind_targets(vr, [vd])
	_drill(dev, "VaultDrill", Vector3(21.5, -3.2, 7.75), 180.0, Vector3(21.5, -4.2, 7.0), VAULT_DRILL_S, "THERMAL",
		"vault_drill", vd)
	var ad: Node3D = wall_prefab(dev, "keycard_reader", "ArtDoorReader", Vector3(39.6, 1.2, 11.9), 0.0, 0.0,
		"prop_keycard_reader", {"objective_tag": &"art_door_reader"})
	_bind_targets(ad, [doors.get_node_or_null("ArtDoorEG")])


func _bind_targets(src: Node3D, targets: Array) -> void:
	if src == null:
		return
	var paths: Array[NodePath] = []
	for t: Variant in targets:
		if t != null:
			paths.append(src.get_path_to(t as Node))
	src.set(&"targets", paths)


func _drill(parent: Node3D, nm: String, pos: Vector3, yaw: float, use: Vector3, secs: float, device: String, tag: String,
		target: Node3D) -> void:
	var d: Node3D = cprefab(parent, "drill_point", nm, pos, yaw, VIS_EMPTY,
		{"device": "enum:" + device, "duration_s": secs, "loud_only": true, "objective_tag": StringName(tag)}, use)
	if d != null and target != null:
		d.set(&"target", d.get_path_to(target))


## Studies, the AS rack studies, the consignment lockers, the CO safe (+3 small loot), the TR vitrines, the CK cash box
## and the GS till (doc Loot path; small_valuables values on the prefabs, B README "Not data here").
func _build_loot(_gp: Node3D) -> void:
	var lt: Node3D = n("Gameplay/Loot")
	for s: Array in STUDIES:
		canvas(lt, String(s[0]), s[1] as Vector3, float(s[2]), STUDY_LOOT, "study", true)
	for i: int in range(STORE_STUDIES.size()):
		canvas(lt, "StoreStudy%d" % (i + 1), STORE_STUDIES[i] as Vector3, 0.0, STUDY_LOOT, "store_study", false)
	for j: int in range(LOCKERS.size()):
		var row: Array = LOCKERS[j]
		wall_prefab(lt, "deposit_box", "Locker%d" % (j + 1), Vector3(LOCKER_FACE_X, float(row[1]), float(row[0])), 90.0,
			-4.2, "", {"loot_id": SMALL_LOOT, "value": 900, "objective_tag": &"lockers"}, 0.8)
	var sp: Vector3 = Vector3(9.54, 5.4, 2.0)
	var safe: Node3D = cprefab(lt, "safe", "CuratorSafe", sp, 90.0, "",
		{"size": "enum:SMALL", "methods": [&"drill", &"lockpick", &"saw"] as Array[StringName],
			"objective_tag": &"curator_safe"}, Vector3(8.6, 5.4, 2.0))
	obstruct(Transform3D(yaw_basis(90.0), sp), AABB(Vector3(-0.4, 0.0, -0.35), Vector3(0.8, 1.2, 0.7)))
	if safe != null:
		for k: int in range(3):
			var z: float = 1.8 + 0.2 * float(k)
			cprefab(safe, "small_loot", "CuratorValuables%d" % (k + 1), Vector3(9.54, 5.7, z), 90.0, "prop_cash_stack",
				{"loot_id": SMALL_LOOT, "value": 1500}, Vector3(8.6, 5.4, z))
	for v: Array in [["VitrineW", 37.6], ["VitrineE", 42.3]]:
		var vp: Vector3 = Vector3(float(v[1]), 5.4, 28.6)
		cprefab(lt, "display_case", "Treasury" + String(v[0]), vp, 0.0, "prop_display_case_vitrine",
			{"loot_id": SMALL_LOOT, "glass_breaks_alarm": true}, Vector3(vp.x, 5.4, 27.6))
		obstruct_catalog("prop_display_case_vitrine", vp, 0.0)
	on_box(lt, "small_loot", "CloakroomCashBox", Vector3(15.5, 0.9, 28.6), 180.0, "prop_cash_stack",
		{"loot_id": SMALL_LOOT, "value": 1200}, ["CloakroomCounter", Vector3(15.0, 0.0, 28.6), Vector3(3.0, 0.9, 0.6), 0.0,
		"counter_box"])
	on_box(lt, "small_loot", "GiftShopTill", Vector3(30.0, 0.9, 28.0), 90.0, "prop_cash_stack",
		{"loot_id": SMALL_LOOT, "value": 1000}, ["GiftShopCounter", Vector3(30.0, 0.0, 28.0), Vector3(0.6, 0.9, 1.6), 0.0,
		"counter_box"])


## Phones, alarm buttons, the Mews bins (BODY_HIDE, 1 body each), the gala bar (kc_curator's curator_tipsy pickup).
func _build_misc(_gp: Node3D) -> void:
	var dev: Node3D = n("Gameplay/Devices")
	for p: Array in PHONES:
		var pp: Vector3 = p[1] as Vector3
		wall_prefab(dev, "phone", String(p[0]), pp, float(p[2]), _floor_y(pp.y), "prop_phone_wall")
	for a: Array in ALARMS:
		var ap: Vector3 = a[1] as Vector3
		wall_prefab(dev, "alarm_button", String(a[0]), ap, float(a[2]), _floor_y(ap.y), "prop_alarm_button")
	for b: Array in [["MewsBinW", 28.6], ["MewsBinE", 30.8]]:
		var bp: Vector3 = Vector3(float(b[1]), 0.0, -0.77)
		cprefab(dev, "body_container", String(b[0]), bp, 0.0, "prop_dumpster", {"capacity": 1}, null, {"kind": "bin"})
		obstruct_catalog("prop_dumpster", bp, 0.0)
	_prop_box(n("Props/Greybox"), "GalaBar", Vector3(14.8, 0.0, 18.6), Vector3(0.8, 1.1, 2.0), 0.0, "bar_counter", true)


static func _floor_y(y: float) -> float:
	var best: float = -4.2
	for f: float in L.FLOOR_HEIGHTS:
		if f <= y + 0.001:
			best = f
	return best


## Ladders (B4.6, masked only, no bags): the areaway ladder (catalog 4.2 m) on the light well's west wall, PL floor ->
## court grade; the caged fire-escape ladder (9.0 m, prefab placeholder until ENV D's caged ladder with the drop section)
## on the north facade at x 10, Mews -> the roof deck through the parapet opening. Each builds its own NavLink (A3-10).
func _build_ladders(_gp: Node3D) -> void:
	var lad: Node3D = n("Gameplay/Ladders")
	cprefab(lad, "ladder", "AreawayLadder", Vector3(-3.64, -4.2, 14.0), -90.0, "prop_ladder_fire_escape_h420",
		{"height_m": 4.2})
	cprefab(lad, "ladder", "FireEscapeLadder", Vector3(10.0, 0.0, -0.25), 0.0, "", {"height_m": 9.0})


func security_camera(parent: Node3D, cid: String) -> Node3D:
	var row: Array = CAMERA_MOUNTS[cid]
	var mount: String = String(row[2])
	return cprefab(parent, "security_camera", "Camera" + cid, row[0] as Vector3, float(row[1]),
		"prop_security_camera_" + mount, {"fov_deg": 60.0, "range_m": 20.0, "pan_deg": 40.0}, null,
		{"mount": mount, "kind": "security_camera", "camera_id": cid})


# --- Variant slot content ------------------------------------------------------------------------

func slot_content(vs: VariantSlot, group: String, slot_id: String, row: Array) -> bool:
	var at: Vector3 = Vector3(float(row[5]), float(row[6]), float(row[7]))
	var yaw: float = float(row[8])
	match group:
		"centrepiece", "canvas_orchard", "canvas_widow", "canvas_saint":
			canvas(vs, "Canvas", at, yaw, CANVAS_LOOT[group], String(SLOT_TAGS[group]), bool(row[9]))
			if slot_id == "cp_landing":
				_curtain(vs, at.y)
		"keycard":
			_keycard(vs, slot_id, at, yaw)
		"code_note":
			_code_note(vs, slot_id, at, yaw)
		"camera":
			for c: Array in L.CAMERAS:
				if (c[6] as Array).has(slot_id):
					security_camera(vs, String(c[0]))
		"laser_pattern":
			_lasers(vs, slot_id)
		"escape":
			_escape(vs, slot_id)
		"security_room_staffed":
			if slot_id == "sec_staffed":
				vs.params = {"operator_spawn": "Spawns/CameraOperatorSeat", "station": "Gameplay/Devices/CameraStation"}
		"xl_crate":
			if slot_id == "xl_loan":   # late_loan: the loan crate's 2 extra studies (B README extra_studies)
				for i: int in range(2):
					canvas(vs, "LoanStudy%d" % (i + 1), Vector3(37.3 + 1.4 * float(i), 0.0, 9.0), 180.0, STUDY_LOOT,
						"study", false)
		_:
			return npc_slot(vs, group, slot_id, at, yaw)
	return true


## Hook (gn_npc): NPC spawns of the guard / civilian slot groups; false keeps the placeholder.
func npc_slot(_vs: VariantSlot, _group: String, _slot_id: String, _at: Vector3, _yaw: float) -> bool:
	return false


## kc_* pickups (B5 `keycard`): the bar (kc_curator: the mission keeps it hidden unless curator_tipsy, QC-52 carries the
## real card on her lanyard), the SC key cabinet, the RG desk, the CS bench.
func _keycard(vs: VariantSlot, slot_id: String, at: Vector3, yaw: float) -> void:
	var vis: String = "prop_keycard_bank"
	var props: Dictionary = {"objective_tag": &"keycard"}
	match slot_id:
		"kc_curator":
			cprefab(vs, "keycard_pickup", "Keycard", Vector3(14.95, 1.1, 18.6), yaw, vis, props,
				Vector3(at.x, 0.0, at.z) + front_of(yaw) * L.USE_POINT_M)
		"kc_security":
			on_box(vs, "keycard_pickup", "Keycard", Vector3(17.725, 1.2, 3.0), yaw, vis, props, ["KeyCabinetSC",
				Vector3(17.725, 0.0, 3.0), Vector3(0.6, 1.2, 0.35), 90.0, "key_cabinet"])
		"kc_registrar":
			on_box(vs, "keycard_pickup", "Keycard", Vector3(21.0, 0.75, 3.0), yaw, vis, props, ["DeskRG",
				Vector3(21.0, 0.0, 3.0), Vector3(1.4, 0.75, 0.7), 0.0, "desk_box"])
		"kc_conservator":
			on_box(vs, "keycard_pickup", "Keycard", Vector3(40.0, 6.3, 10.0), yaw, vis, props, ["BenchCS",
				Vector3(40.0, 5.4, 10.0), Vector3(1.4, 0.9, 0.7), 0.0, "workbench_box"])


## code_* notes (B5 `code_note`, code group argus) on the SC counter, the CO desk, the AO desk.
func _code_note(vs: VariantSlot, slot_id: String, _at: Vector3, yaw: float) -> void:
	var props: Dictionary = {"code_group": CODE_GROUP, "objective_tag": &"code_note"}
	var vis: String = "res://world/props/clutter/prop_papers.tscn"
	match slot_id:
		"code_security_log":
			on_box(vs, "code_note", "CodeNote", Vector3(17.4, 1.0, 0.5), yaw, vis, props, ["CounterSC",
				Vector3(17.24, 0.0, 0.51), Vector3(1.3, 1.0, 0.6), 0.0, "counter_box"])
		"code_curator_planner":
			on_box(vs, "code_note", "CodeNote", Vector3(6.0, 6.15, 2.0), yaw, vis, props, ["DeskCO",
				Vector3(6.0, 5.4, 2.0), Vector3(1.4, 0.75, 0.7), 0.0, "desk_box"])
		"code_admin_postit":
			on_box(vs, "code_note", "CodeNote", Vector3(14.0, 6.15, 4.0), yaw, vis, props, ["DeskAO",
				Vector3(14.0, 5.4, 4.0), Vector3(1.4, 0.75, 0.7), 0.0, "desk_box"])


## TR grid at z 26.5 across the room, carried by two emitter columns (a support prop, as Shadow Ledger): lz_static
## 3 beams 1.30 / 1.90 / 2.50 m (crouch under, B4.1: meta crouch_under, bypass false), lz_sweep 3 vertical beams 6 s,
## lz_timed 4 beams off 4 s of 16 s.
func _lasers(vs: VariantSlot, slot_id: String) -> void:
	var span: float = LASER_X.y - LASER_X.x
	var mid: float = (LASER_X.x + LASER_X.y) * 0.5
	var em: StaticBody3D = _emitters(vs, Vector3(mid, 5.4, LASER_Z), span)
	var props: Dictionary = {"objective_tag": &"treasury_lasers"}
	var y: float = 0.0
	match slot_id:
		"lz_static":
			props.merge({"pattern": &"static", "size_m": Vector3(span - 0.4, LASER_STATIC_H, 0.1), "beam_count": 3})
			y = LASER_STATIC_Y
		"lz_sweep":
			props.merge({"pattern": &"sweeping", "size_m": Vector3(span - 0.4, 2.6, 0.1), "sweep_beams": 3, "period_s": 6.0})
		"lz_timed":
			props.merge({"pattern": &"timed_off", "size_m": Vector3(span - 0.4, 2.6, 0.1), "beam_count": 4,
				"period_s": 16.0, "off_s": 4.0})
	var metas: Dictionary = {"kind": "laser_grid"}
	if slot_id == "lz_static":
		metas["bypass"] = false
		metas["crouch_under"] = true
	prefab(em, "laser_grid", "TreasuryLasers", Vector3(mid, 5.4 + y, LASER_Z), 0.0, props, null, metas)


func _curtain(vs: VariantSlot, floor_y: float) -> void:
	var x0: float = float(CURTAIN[0])
	var x1: float = float(CURTAIN[1])
	prefab(vs, "laser_grid", "LandingCurtain", Vector3((x0 + x1) * 0.5, floor_y, float(CURTAIN[2])), 0.0,
		{"pattern": &"static", "size_m": Vector3(x1 - x0, float(CURTAIN[3]), 0.1), "beam_count": int(CURTAIN[4]),
			"objective_tag": &"landing_curtain"}, null, {"kind": "laser_grid"})


func _emitters(parent: Node3D, base: Vector3, span: float) -> StaticBody3D:
	var em: StaticBody3D = StaticBody3D.new()
	em.name = "LaserEmitters"
	em.collision_layer = 1
	em.collision_mask = 0
	em.transform = global_xform(parent).affine_inverse() * Transform3D(Basis.IDENTITY, base)
	em.set_meta(&"kind", "laser_emitter")
	em.set_meta(&"support", true)
	add(parent, em)
	var half: float = span * 0.5 - 0.085
	for i: int in range(2):
		var x: float = -half if i == 0 else half
		var col: CollisionShape3D = CollisionShape3D.new()
		col.name = "Collision%d" % i
		col.shape = box_shape(Vector3(0.15, 2.7, 0.12))
		col.position = Vector3(x, 1.35, 0.0)
		add(em, col)
		mesh_box(em, "Column%d" % i, Vector3(x - 0.075, 0.0, -0.06), Vector3(x + 0.075, 2.7, 0.06), "trim")
		obstruct(Transform3D(Basis.IDENTITY, base), AABB(Vector3(x - 0.075, 0.0, -0.06), Vector3(0.15, 2.7, 0.12)))
	return em


## The active escape's SECURE_LOOT (secure_<short>, the vehicle visual) and ESCAPE (escape_<short>, van-type) zones.
func _escape(vs: VariantSlot, slot_id: String) -> void:
	var e: Array = ESCAPES[slot_id]
	var short: String = slot_id.trim_prefix("esc_")
	var sp: Vector3 = e[0] as Vector3
	cprefab(vs, "secure_zone", "Secure" + short.capitalize(), sp, float(e[1]), "veh_van_secure",
		{"objective_tag": StringName("secure_" + short)}, null, {"kind": "vehicle"})
	obstruct_catalog("veh_van_secure", sp, float(e[1]))
	cprefab(vs, "escape_zone", "Escape" + short.capitalize(), e[2] as Vector3, 0.0, ESCAPE_VAN_MARKER,
		{"objective_tag": StringName("escape_" + short), "escape_type": &"van", "zone_size_m": e[3] as Vector3})
	vs.params = {"label": "E1" if short == "mews" else "E2", "vehicle": "van" if short == "mews" else "limo"}
