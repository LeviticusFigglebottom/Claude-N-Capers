## Gallery Night gameplay layer (GN-C1 skeleton). Owner: ENV C.
## Builds every VariantSlot of the map (groups in resolver order, ids, base weights and facings from the layout data,
## which tools/levelcheck/plans/gallery_night_slots.py --check keeps in step with the doc and ENV B's variant table),
## the door and window prefabs (Build ruling B2 lock table; rehearsal F7) and placeholder content for the rest. The G1
## build replaces each placeholder with ENV A's prefab instances (loot_spawn, keycard_pickup, code_note,
## security_camera, laser_grid, padlock, NPC SpawnPoints...). Prefabs are located by contract class name
## (gn_builder_base.prefab_scene, as sl_builder_base), never by a path into game/systems.
## Slot facing (rehearsal F2/F3): each VariantSlot is turned by its layout yaw (content front -Z), wall-hung slots
## face away from their wall, and every interactive slot carries a `UsePoint` USE_POINT_M in front of it on the
## floor, so the prefab that replaces the placeholder keeps its UsePoint on the navmesh.
## Tagged markers (rehearsal F5): placeholders of objective prefabs carry the B5 `objective_tag` (OBJECTIVE_MARKER),
## and Gameplay/Markers/CasingHall is the `casing_hall` marker at the Great Hall stair foot.
extends "res://world/heists/gallery_night/greybox/gn_builder_base.gd"

## Argus code group for the SV keypad and the code notes (B2).
const CODE_GROUP: StringName = &"argus"
## Spawn tags a locked door's `npc_authorized_tags` lists (Door._staff_authorised matches SpawnPoint tags; G1 step 2d):
## "@guards" in a DOORS `npc` list expands to every Halberd guard post, "@staff" to every staff civilian (B2: the
## curator, attendants, waitstaff, conservator, PA; patrons carry none of these). The rare-event inspectors (+ escorts) and
## Vaultline couriers walk to the centrepiece slot, so they also pass the TR door (cp_treasury); the LD personnel door
## (push_bar) lets the dock smoker and the waitstaff (Circulation: they leave by it at last call + 120 s) out.
const GUARD_TAGS: Array = ["guard_hall", "guard_rover_ground", "guard_rover_upper", "guard_rover_basement",
	"guard_inspection", "guard_inspection_escort", "guard_vaultline", "guard_court", "guard_rounds"]
const STAFF_TAGS: Array = ["civ_curator", "civ_attendant", "civ_waitstaff", "civ_conservator", "civ_admin"]
## B2: boundary doors into BOH are LOCKPICK 8 s.
const LOCKPICK_S: float = 8.0
## Door kit (tools/blender/greybox/_kit.py DOORS): opening width per kind; every opening head is 2.2 m.
const DOOR_OPENING_W: Dictionary = {"single": 1.0, "double": 2.0, "service": 1.2}
const DOOR_OPENING_H: float = 2.2
## Door leaf width (Door.width_m) per kind.
const DOOR_LEAF_W: Dictionary = {"single": 0.9, "double": 1.8, "service": 1.1}
## The prefab's front (-Z, UsePoint side) faces this way: yaw (gn_builder_base.yaw_basis).
const FRONT_YAW: Dictionary = {"N": 0.0, "W": 90.0, "S": 180.0, "E": -90.0}
## Stair SS / head-house east wall (0.3 m core, x 3.0): where it carries a door it is built 0.4 m thick on x 3.05, its
## stair-side face kept at x 2.85 (SS_CLEAR), so a t40 kit frame sits flush in it (door_frame_gap / frame_proud).
const CORE_DOOR_WALL: Array = ["z", 3.0, 0.3]
const CORE_FIT: Array = [3.05, 0.4]
## Doors (B2 lock table): [name, floor, axis, plan fixed, plan opening a0 (matches L.OPENINGS), kit kind, lock, front,
## extra]. extra: c (opening centre when it is not the plan opening's), starts_open, push_bar, leaf (leaf_surface),
## vis (a catalog visual instead of the greybox kit door; GN-C2 the art-lift landing gates, which open out of LF so
## their leaves never sweep the car),
## npc (npc_authorized_tags), code (code_group), tag (objective_tag), slot (built by that variant group instead),
## out (swing OUTWARD, toward the front: GN-C2, the leaves open into the room, never the corridor).
## The wall hole is cut to the kit opening (DOOR_OPENING_W x 2.2) on the door's centre, not the plan's 2.1 m hole.
## Public interior openings with no leaf in B2 (CK, PWW, PWM, DC, the arches) stay plain openings.
## B4.7 / next_heist §7.7 (ENV P traversal review): the route doors (staff door, CO, SV, CS from UC, AT N / W, TR, the
## head house) are 1.1 m service leaves in the 1.2 m kit opening (meta service), not the 0.9 m single default.
const DOORS: Array = [
	["StairDoorB", "B", "z", 3.0, 6.5, "single", "NONE", "E", {}],
	["LockerDoor", "B", "x", 6.0, 5.5, "single", "NONE", "S", {}],
	["FrameStoreDoor", "B", "x", 6.0, 14.5, "single", "NONE", "S", {}],
	["QuarantineDoor", "B", "x", 6.0, 23.5, "single", "NONE", "S", {}],
	["LiftLandingDoorB", "B", "x", 6.0, 28.6, "double", "NONE", "N", {"vis": "prop_door_double_liftgate_t20", "leaf": "metal"}],
	["PlantDoor", "B", "x", 8.0, 4.5, "single", "NONE", "N", {}],
	["ArtStoreVaultDoor", "B", "x", 8.0, 20.5, "double", "VAULT", "N",
		{"leaf": "metal", "npc": ["guard_vaultline"]}],
	["StairDoorG", "G", "z", 3.0, 6.5, "single", "NONE", "E", {}],
	["BreakRoomDoor", "G", "x", 6.0, 4.5, "single", "NONE", "S", {}],
	["StaffWCDoor", "G", "x", 6.0, 9.5, "single", "NONE", "S", {}],
	["SecurityDoor", "G", "x", 6.0, 15.5, "single", "NONE", "S", {}],
	["RegistrarDoor", "G", "x", 6.0, 19.5, "single", "NONE", "S", {}],
	["JanitorDoor", "G", "x", 6.0, 24.5, "single", "NONE", "S", {}],
	["ElectricalDoor", "G", "x", 6.0, 26.5, "single", "NONE", "S", {}],
	["LiftLandingDoorGS", "G", "x", 6.0, 28.6, "double", "NONE", "N", {"vis": "prop_door_double_liftgate_t20", "leaf": "metal"}],
	["LiftLandingDoorGE", "G", "z", 32.0, 1.5, "double", "NONE", "W", {"vis": "prop_door_double_liftgate_t20", "leaf": "metal"}],
	["DockCorridorDoor", "G", "z", 32.0, 6.1, "service", "NONE", "E", {"out": true}],
	["ArtHandlingDoor", "G", "x", 8.0, 4.6, "double", "LOCKPICK", "S", {"npc": ["@guards", "@staff"]}],
	["StaffDoor", "G", "x", 8.0, 18.5, "service", "LOCKPICK", "S", {"npc": ["@guards", "@staff"], "out": true}],
	["DockPersonnelDoor", "G", "x", 0.0, 40.5, "single", "LOCKPICK", "S",
		{"push_bar": true, "leaf": "metal", "npc": ["guard_mews", "civ_waitstaff"]}],
	["ArtDoorEG", "G", "x", 12.0, 37.0, "double", "KEYCARD", "N", {}],
	["CourtDoors", "G", "z", 0.0, 11.6, "double", "", "W", {"slot": "court_doors", "leaf": "glass"}],
	["BronzeDoorsW", "G", "x", 30.0, 18.5, "double", "NONE", "N",
		{"c": 19.4, "starts_open": true, "push_bar": true, "leaf": "metal"}],
	["BronzeDoorsE", "G", "x", 30.0, 18.5, "double", "NONE", "N",
		{"c": 21.6, "starts_open": true, "push_bar": true, "leaf": "metal"}],
	["GiftShopDoor", "G", "x", 26.0, 27.5, "single", "LOCKPICK", "N", {}],
	["StairDoorU", "U", "z", 3.0, 6.5, "single", "NONE", "E", {}],
	["CuratorDoor", "U", "x", 6.0, 5.5, "service", "NONE", "S", {}],
	["AdminDoor", "U", "x", 6.0, 13.5, "single", "NONE", "S", {}],
	["UpperWCDoor", "U", "x", 6.0, 17.5, "single", "NONE", "S", {}],
	["FrameStoreUDoor", "U", "x", 6.0, 20.5, "single", "NONE", "S", {}],
	["ServerDoor", "U", "x", 6.0, 24.5, "service", "CODE", "S", {"code": "argus", "leaf": "metal"}],
	["LiftLandingDoorUS", "U", "x", 6.0, 28.6, "double", "NONE", "N", {"vis": "prop_door_double_liftgate_t20", "leaf": "metal"}],
	["LiftLandingDoorUE", "U", "z", 32.0, 1.5, "double", "NONE", "W", {"vis": "prop_door_double_liftgate_t20", "leaf": "metal"}],
	["StudioDoor", "U", "z", 32.0, 6.5, "service", "NONE", "W", {}],
	["BalconyDoorW", "U", "x", 8.0, 12.5, "single", "NONE", "N", {}],
	["BalconyDoorE", "U", "x", 8.0, 29.5, "single", "NONE", "N", {}],
	["StudioGalleryDoor", "U", "x", 12.0, 35.5, "single", "LOCKPICK", "S",
		{"npc": ["@guards", "civ_conservator", "civ_curator"]}],
	["AttendantDoorN", "U", "x", 24.0, 32.5, "service", "NONE", "N", {}],
	["TreasuryDoor", "U", "x", 24.0, 38.5, "service", "KEYCARD", "N",
		{"npc": ["guard_inspection", "guard_inspection_escort", "guard_vaultline"]}],
	["AttendantDoorW", "U", "z", 32.0, 27.5, "service", "NONE", "W", {}],
	["HeadHouseDoor", "R", "z", 3.0, 6.5, "service", "LOCKPICK", "W", {"push_bar": true, "leaf": "metal"}],
]
## Gameplay windows (doc: EB windows S/E are a police ENTRY, glass; SL's tall windows face the Parade): breakable
## WindowPrefab with the 1.2 x 2.1 tall-window visual. [name, floor, axis, plan fixed, plan opening a0, room-side
## front(, "blinds")]. The hole is cut to WINDOW_W x WINDOW_H from the plan sill, on the plan opening's centre.
## D-142: "blinds" (the EB windows, closed blinds per the Room list) sets the Window prefab's `see_through = false`
## (opaque for stealth vision) where the prefab has that property (ENV A's D-142 Window); the loggia windows stay clear.
const WINDOWS: Array = [
	["BenefactorsWindowS1", "G", "x", 30.0, 33.5, "N", "blinds"],
	["BenefactorsWindowS2", "G", "x", 30.0, 37.5, "N", "blinds"],
	["BenefactorsWindowS3", "G", "x", 30.0, 41.5, "N", "blinds"],
	["BenefactorsWindowE1", "G", "z", 44.0, 25.5, "W", "blinds"],
	["BenefactorsWindowE2", "G", "z", 44.0, 27.5, "W", "blinds"],
	["LoggiaWindow1", "U", "x", 30.0, 15.5, "N"],
	["LoggiaWindow2", "U", "x", 30.0, 19.5, "N"],
	["LoggiaWindow3", "U", "x", 30.0, 23.5, "N"],
	["LoggiaWindow4", "U", "x", 30.0, 27.5, "N"],
]
## G2 (GN-C2): every B2 door wears its catalog door (tools/blender/props/doors.py: the greybox kit's frame and opening)
## prop_door_<kind>_<finish>_<t20|t40>: walnut on the public side, steel in plant / dock / stairs / vault, ivory in
## the back-of-house offices (the default).
const DOOR_FINISH: Dictionary = {
	"StairDoorB": "steel", "StairDoorG": "steel", "StairDoorU": "steel", "HeadHouseDoor": "steel", "PlantDoor": "steel",
	"ArtStoreVaultDoor": "steel", "DockCorridorDoor": "steel", "DockPersonnelDoor": "steel", "ServerDoor": "steel",
	"ArtDoorEG": "steel", "ArtHandlingDoor": "walnut", "StaffDoor": "walnut", "GiftShopDoor": "walnut",
	"BalconyDoorW": "walnut", "BalconyDoorE": "walnut", "StudioGalleryDoor": "walnut", "AttendantDoorN": "walnut",
	"AttendantDoorW": "walnut", "TreasuryDoor": "walnut", "BronzeDoorsW": "bronze", "BronzeDoorsE": "bronze",
	"CourtDoors": "glass",
}
const WINDOW_VISUAL: String = "res://assets/props/prop_window_w120_h210/prop_window_w120_h210.glb"
const WINDOW_W: float = 1.2
const WINDOW_H: float = 2.1
## LD roller door (B2: BARRED, crew cannot operate): a `door` prefab with the GN-C2 roller visual (industrial_door,
## 3.6 x 4.5, the curtain rolls up when the leaf opens), front N (the Mews), baked closed (D-073, B7) so the Mews
## reaches LD through the personnel door only. [floor, axis, plan fixed, a0, a1].
const ROLLER: Array = ["G", "x", 0.0, 34.7, 38.3]
const ROLLER_VISUAL: String = "prop_door_roller_steel_w360_h450"
## B5 objective_tag of each group's placeholder (the active slot's node only; no spoiler markers).
const SLOT_TAGS: Dictionary = {
	"centrepiece": "canvas_lantern", "canvas_orchard": "canvas_orchard", "canvas_widow": "canvas_widow",
	"canvas_saint": "canvas_saint", "keycard": "keycard", "code_note": "code_note",
}
## B5 casing marker: the Great Hall stair foot (the central flight's first riser is at z 14.4).
const CASING_HALL: Vector3 = Vector3(22.0, 0.0, 15.4)
## What each group's slot content will be (the placeholder's `todo`).
const SLOT_TODO: Dictionary = {
	"centrepiece": "loot_spawn loot.painting_lantern_bearer, objective_tag canvas_lantern, alarm group (sensor_net)",
	"canvas_orchard": "loot_spawn loot.painting_salt_orchard, objective_tag canvas_orchard",
	"canvas_widow": "loot_spawn loot.painting_widow_in_blue, objective_tag canvas_widow",
	"canvas_saint": "loot_spawn loot.painting_tidewater_saint, objective_tag canvas_saint",
	"sensor_net": "logic slot: params alarm_groups_live / alarm_groups_off for the mission (QC-54)",
	"conservator": "CIVILIAN SpawnPoint civ_conservator (cons_late) / empty (cons_gone)",
	"keycard": "keycard_pickup objective_tag keycard (kc_curator: NPC-carried, QC-52)",
	"code_note": "code_note code_group argus, objective_tag code_note",
	"guard_post": "GUARD SpawnPoint + PatrolGraph post (D-140: rover_court on its own Court graph)",
	"security_room_staffed": "CAMERA_OPERATOR SpawnPoint at the SC console (sec_staffed) / D-140 roundsman (sec_empty)",
	"camera": "security_camera instances of this layout (C* placeholders below)",
	"laser_pattern": "laser_grid TR z 26.5 with this pattern (B4: low beam centre >= 1.30 m)",
	"curator_route": "civ_curator SpawnPoint + staff_curator PatrolPoints",
	"court_doors": "door prefab at the WG French doors (built: CourtDoors)",
	"areaway": "grate (lift 3 s) / padlock prefab (lockpick 8 s or saw); ladder to PL",
	"escape": "escape_zone + secure_zone + vehicle visual (van / limo)",
	"xl_crate": "loan crate with extra loot.painting_study (late_loan)",
	"admin_pa": "CIVILIAN SpawnPoint civ_admin at an AO desk (late_paperwork)",
	"gala_extra": "CIVILIAN SpawnPoint of a D-130 difficulty extra (cloakroom attendant / DC attendant)",
}
## court_doors slot -> the French doors' lock (B2).
const COURT_LOCK: Dictionary = {"court_doors_open": "NONE", "court_doors_locked": "LOCKPICK"}


# --- Prefab helpers (ported from sl_gameplay.gd) ----------------------------------------------

## Instances a prefab under `parent` at a WORLD position / yaw (the parent may be a turned slot). props: export ->
## value ("enum:KEY" looks the key up in the prefab script's enums). use_point: world floor point for the UsePoint,
## or null to keep the prefab's own.
func prefab(parent: Node3D, kind: String, nm: String, pos: Vector3, yaw: float, props: Dictionary = {},
		use_point: Variant = null, metas: Dictionary = {}) -> Node3D:
	var ps: PackedScene = prefab_scene(kind)
	if ps == null:
		return null
	var inst: Node3D = ps.instantiate() as Node3D
	inst.name = nm
	inst.transform = global_xform(parent).affine_inverse() * Transform3D(yaw_basis(yaw), pos)
	for k: Variant in props:
		_set_prop(inst, String(k), props[k])
	for mk: Variant in metas:
		inst.set_meta(StringName(String(mk)), metas[mk])
	parent.add_child(inst)
	inst.owner = map_root
	if use_point != null:
		place_use_point(inst, use_point as Vector3)
	return inst


## Moves a prefab's UsePoint to a world floor point, -Z facing the object (Editable Children).
func place_use_point(inst: Node3D, world: Vector3) -> void:
	var up: Node3D = inst.get_node_or_null("UsePoint") as Node3D
	if up == null:
		errors.append("%s has no UsePoint" % inst.name)
		return
	var xf: Transform3D = global_xform(inst)
	up.transform = xf.affine_inverse() * _facing(world, xf.origin)
	map_root.set_editable_instance(inst, true)


## Transform at `at` whose -Z looks (horizontally) at `target`.
static func _facing(at: Vector3, target: Vector3) -> Transform3D:
	var to_obj: Vector3 = target - at
	to_obj.y = 0.0
	if to_obj.length() < 0.01:
		to_obj = Vector3.FORWARD
	return Transform3D(Basis.looking_at(to_obj.normalized(), Vector3.UP), at)


## True when `inst` has the property `prop` (a prefab property another environment may not have shipped yet).
static func _has_prop(inst: Node, prop: String) -> bool:
	for p: Dictionary in inst.get_property_list():
		if String(p["name"]) == prop:
			return true
	return false


## True when the Window prefab has the property `prop` (asked on a throwaway instance).
func _window_has(prop: String) -> bool:
	var ps: PackedScene = prefab_scene("window")
	if ps == null:
		return false
	var probe: Node = ps.instantiate()
	var ok: bool = _has_prop(probe, prop)
	probe.free()
	return ok


func _set_prop(inst: Node, prop: String, value: Variant) -> void:
	var found: bool = false
	for p: Dictionary in inst.get_property_list():
		if String(p["name"]) == prop:
			found = true
			break
	if not found:
		errors.append("%s has no property `%s`" % [inst.name, prop])
		return
	if value is String and String(value).begins_with("enum:"):
		value = _enum_value(inst, String(value).substr(5))
	inst.set(prop, value)


func _enum_value(inst: Node, key: String) -> int:
	var scr: Script = inst.get_script() as Script
	if scr != null:
		for c: Variant in scr.get_script_constant_map().values():
			if c is Dictionary and (c as Dictionary).has(key):
				return int((c as Dictionary)[key])
	errors.append("enum key %s not found on %s" % [key, inst.name])
	return 0


static func _names(a: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for v: Variant in a:
		out.append(StringName(String(v)))
	return out


# --- Doors and windows: placement data shared with the shell (build_greybox._build_walls) ----------

## The wall run (L.WALLS row) on a line that covers [a0, a1] on floor f, or [].
static func wall_at(f: String, axis: String, fixed: float, a0: float, a1: float) -> Array:
	for w: Array in L.WALLS:
		if String(w[0]) == f and String(w[1]) == axis and absf(float(w[2]) - fixed) < 0.001 \
				and float(w[3]) <= a0 + 0.001 and float(w[4]) >= a1 - 0.001:
			return w
	return []


## [fixed, thickness] a wall run is built at (the Stair SS / head-house core wall is refitted where it has a door).
static func wall_fit(f: String, axis: String, fixed: float, thick: float, a0: float, a1: float) -> Array:
	if axis == String(CORE_DOOR_WALL[0]) and absf(fixed - float(CORE_DOOR_WALL[1])) < 0.001 \
			and absf(thick - float(CORE_DOOR_WALL[2])) < 0.001:
		for d: Array in DOORS:
			if String(d[1]) == f and String(d[2]) == axis and absf(float(d[3]) - fixed) < 0.001 \
					and float(d[4]) >= a0 and float(d[4]) <= a1:
				return CORE_FIT
	return [fixed, thick]


## A door's opening centre (along its wall).
static func door_centre(d: Array) -> float:
	var extra: Dictionary = d[8]
	if extra.has("c"):
		return float(extra["c"])
	for o: Array in L.OPENINGS:
		if _is_opening(o, String(d[1]), String(d[2]), float(d[3]), float(d[4])):
			return (float(o[4]) + float(o[5])) * 0.5
	return float(d[4])


static func _is_opening(o: Array, f: String, axis: String, fixed: float, a0: float) -> bool:
	return String(o[0]) == f and String(o[2]) == axis and absf(float(o[3]) - fixed) < 0.001 and absf(float(o[4]) - a0) < 0.001


## The holes a plan opening is cut as: the kit-fitted door / window holes when prefabs fill it, else the plan hole.
## [[a0, a1, y0, y1], ...] and whether a prefab fills it (no greybox glass pane then).
static func opening_holes(o: Array) -> Array:
	var f: String = String(o[0])
	var holes: Array = []
	for d: Array in DOORS:   # the door's own floor: openings on the same line repeat floor to floor
		if String(d[1]) == f and _is_opening(o, f, String(d[2]), float(d[3]), float(d[4])):
			var c: float = door_centre(d)
			var hw: float = float(DOOR_OPENING_W[String(d[5])]) * 0.5
			holes.append([c - hw, c + hw, float(o[6]), float(o[6]) + DOOR_OPENING_H])
	for w: Array in WINDOWS:
		if String(w[1]) == f and _is_opening(o, f, String(w[2]), float(w[3]), float(w[4])):
			var cw: float = (float(o[4]) + float(o[5])) * 0.5
			holes.append([cw - WINDOW_W * 0.5, cw + WINDOW_W * 0.5, float(o[6]), float(o[6]) + WINDOW_H])
	if holes.is_empty():
		return [[[float(o[4]), float(o[5]), float(o[6]), float(o[7])]], false]
	return [holes, true]


## A door's world origin (bottom-centre of the opening on the built wall line), yaw and kit wall thickness.
static func door_place(d: Array) -> Array:
	var f: String = String(d[1])
	var axis: String = String(d[2])
	var c: float = door_centre(d)
	var hw: float = float(DOOR_OPENING_W[String(d[5])]) * 0.5
	var w: Array = wall_at(f, axis, float(d[3]), c - hw, c + hw)
	var fit: Array = wall_fit(f, axis, float(d[3]), float(w[5]) if not w.is_empty() else L.INT_T, float(w[3]) if not w.is_empty()
		else 0.0, float(w[4]) if not w.is_empty() else 0.0)
	var fixed: float = float(fit[0])
	var y: float = float(L.FFL[f])
	var pos: Vector3 = Vector3(c, y, fixed) if axis == "x" else Vector3(fixed, y, c)
	return [pos, float(FRONT_YAW[String(d[7])]), float(fit[1])]


# --- Gameplay ---------------------------------------------------------------------------------

## Gameplay: doors (B2), gameplay windows, the casing marker, the art lift (gn_content), the LD roller door, then
## build_devices (gn_content: the always-present prefabs, C11 / C14, ladders...).
func build_gameplay(gp: Node3D) -> void:
	_build_doors(add(gp, node3d("Doors")) as Node3D)
	_build_windows(add(gp, node3d("Windows")) as Node3D)
	for nm: String in ["Cameras", "Loot", "Devices", "Ladders", "Lifts", "Civilian", "Markers"]:
		add(gp, node3d(nm))
	placeholder(n("Gameplay/Markers"), "CasingHall", CASING_HALL,
		"casing objective marker (B5 casing_hall), the Great Hall stair foot", "casing_hall", 180.0)
	build_lift(n("Gameplay/Lifts"))
	var rc: float = (float(ROLLER[3]) + float(ROLLER[4])) * 0.5
	prefab(n("Gameplay/Doors"), "door", "DockRollerDoor", Vector3(rc, float(L.FFL[String(ROLLER[0])]), float(ROLLER[2])),
		0.0, {"lock": "enum:ELECTRONIC", "swing": "enum:INWARD", "width_m": float(ROLLER[4]) - float(ROLLER[3]),
			"leaf_surface": &"metal", "visual_scene": _catalog_scene(ROLLER_VISUAL)}, null,
		{"kind": "industrial_door", "swing_side": "back"})
	build_devices(gp)


## Hook (gn_content): the art lift (bag_lift, landings on every floor).
func build_lift(_parent: Node3D) -> void:
	pass


## Hook (gn_content): every always-present gameplay prefab outside the variant slots.
func build_devices(_gp: Node3D) -> void:
	pass


## Hook (gn_content): builds a slot's real content; false keeps the placeholder.
func slot_content(_vs: VariantSlot, _group: String, _slot_id: String, _row: Array) -> bool:
	return false


## B2 doors with their catalog visual (DOOR_FINISH; t20 / t40 by the wall they sit in: a flush frame, PO-7
## frame_proud / door_frame_gap), except the court French doors (the court_doors slots build theirs).
func _build_doors(parent: Node3D) -> void:
	for d: Array in DOORS:
		if not (d[8] as Dictionary).has("slot"):
			door(parent, d, String(d[0]), String(d[6]))
	_close_barred(parent)


## One B2 door prefab under `parent` with `lock`.
func door(parent: Node3D, d: Array, nm: String, lock: String) -> Node3D:
	var pl: Array = door_place(d)
	var kind: String = String(d[5])
	var extra: Dictionary = d[8]
	var t: String = "t40" if float(pl[2]) > 0.3 else "t20"
	var out: bool = bool(extra.get("out", false))
	var props: Dictionary = {"lock": "enum:" + lock,
		"swing": "enum:" + ("DOUBLE" if kind == "double" else ("OUTWARD" if out else "INWARD")),
		"visual_scene": _catalog_scene("prop_door_%s_%s_%s" % [kind, String(DOOR_FINISH.get(String(d[0]), "ivory")), t]),
		"width_m": float(DOOR_LEAF_W[kind])}
	if extra.has("vis"):
		props["visual_scene"] = _catalog_scene(String(extra["vis"]))
	if lock == "LOCKPICK":
		props["interaction_time_s"] = LOCKPICK_S
	if bool(extra.get("starts_open", false)):
		props["starts_open"] = true
	if bool(extra.get("push_bar", false)):
		props["push_bar"] = true
	if extra.has("leaf"):  # D-105: metal / glass leaves on a greybox kit visual (reads as wood)
		props["leaf_surface"] = StringName(String(extra["leaf"]))
	if extra.has("npc"):
		props["npc_authorized_tags"] = _names(_npc_tags(extra["npc"]))
	if extra.has("code"):
		props["code_group"] = StringName(String(extra["code"]))
	if extra.has("tag"):
		props["objective_tag"] = StringName(String(extra["tag"]))
	var metas: Dictionary = {"kind": "door", "swing_side": "front" if out else "back"}
	if bool(extra.get("push_bar", false)):
		metas["fire_exit"] = true
	if kind == "service":   # `scale`: a 1.0-1.2 m service leaf
		metas["service"] = true
	return prefab(parent, "door", nm, pl[0] as Vector3, float(pl[1]), props, null, metas)


## A DOORS `npc` list with "@guards" / "@staff" expanded (GUARD_TAGS / STAFF_TAGS), in order, no duplicates.
static func _npc_tags(src: Array) -> Array:
	var out: Array = []
	for t: Variant in src:
		var add_tags: Array = GUARD_TAGS if t == "@guards" else (STAFF_TAGS if t == "@staff" else [t])
		for a: Variant in add_tags:
			if not out.has(a):
				out.append(a)
	return out


## D-073: BARRED doorways are baked CLOSED (a projected obstruction fills the opening, +0.15 m into each jamb, 0.3 m
## each side of the door line); the door's NavLink bridges it while passable (validate_level `barred_doors`). The LD
## roller (BARRED door prefab, GN-C2 roller visual) is closed the same way. VAULT doors stay open in the bake (the art store has no
## other way in; reachability), as SL's vault-less map never had to decide.
func _close_barred(_parent: Node3D) -> void:
	for d: Array in DOORS:
		if String(d[6]) != "BARRED":
			continue
		var pl: Array = door_place(d)
		var w: float = float(DOOR_OPENING_W[String(d[5])]) + 0.3
		obstruct(Transform3D(yaw_basis(float(pl[1])), pl[0] as Vector3), AABB(Vector3(-w * 0.5, -0.2, -0.3), Vector3(w, 2.6, 0.6)))
	var a0: float = float(ROLLER[3]) - 0.15
	var a1: float = float(ROLLER[4]) + 0.15
	var fz: float = float(ROLLER[2])
	var y: float = float(L.FFL[String(ROLLER[0])])
	obstruct(Transform3D.IDENTITY, AABB(Vector3(a0, y - 0.2, fz - 0.3), Vector3(a1 - a0, 4.9, 0.6)))


## Gameplay windows: breakable WindowPrefab, tall-window visual, UsePoint 0.7 m in front on the room floor.
func _build_windows(parent: Node3D) -> void:
	var vis: PackedScene = load(WINDOW_VISUAL) as PackedScene
	if vis == null:
		errors.append("missing window visual %s" % WINDOW_VISUAL)
		return
	for w: Array in WINDOWS:
		var f: String = String(w[1])
		var o: Array = []
		for o2: Array in L.OPENINGS:
			if _is_opening(o2, f, String(w[2]), float(w[3]), float(w[4])):
				o = o2
		if o.is_empty():
			errors.append("window %s: no plan opening" % w[0])
			continue
		var c: float = (float(o[4]) + float(o[5])) * 0.5
		var fx: float = float(w[3])
		var pos: Vector3 = Vector3(c, float(o[6]), fx) if String(w[2]) == "x" else Vector3(fx, float(o[6]), c)
		var yaw: float = float(FRONT_YAW[String(w[5])])
		var front: Vector3 = yaw_basis(yaw) * Vector3.FORWARD
		var wp: Dictionary = {"breakable": true, "openable": false, "visual_scene": vis}
		if w.size() > 6 and String(w[6]) == "blinds" and _window_has("see_through"):
			wp["see_through"] = false
		prefab(parent, "window", String(w[0]), pos, yaw, wp, Vector3(pos.x, float(L.FFL[f]), pos.z) + front * 0.7,
			{"kind": "window"})


# --- Variants ---------------------------------------------------------------------------------

## Variants: Group_<group> / Slot_<slot_id> (VariantSlot) at the slot's anchor turned by its yaw, one placeholder
## child each (tagged per B5) with a UsePoint for interactive groups; the layout cameras under their cam_* slot;
## escape/secure zone placeholders (tagged escape_ / secure_<short>) under their escape slot; the court doors.
func build_variants(variants: Node3D) -> void:
	var groups: Dictionary = {}
	for g: String in L.GROUP_ORDER:
		groups[g] = add(variants, node3d("Group_" + g))
	for row: Array in L.SLOTS:
		var g2: String = String(row[0])
		var sid: String = String(row[1])
		var at: Vector3 = Vector3(float(row[5]), float(row[6]), float(row[7]))
		var yaw: float = float(row[8])
		var params: Dictionary = {}
		if g2 == "code_note":
			params = {"code_group": CODE_GROUP}
		var vs: VariantSlot = _slot(groups[g2], g2, sid, float(row[2]), at, yaw, params)
		vs.set_meta(&"room", String(row[4]))
		if bool(row[9]):
			vs.set_meta(&"wall_hung", true)
		if g2 == "court_doors":
			_court_doors(vs, sid)
			continue
		if slot_content(vs, g2, sid, row):
			continue
		var ph: Marker3D = placeholder(vs, "Placeholder", at, "%s (%s)" % [SLOT_TODO.get(g2, "?"), String(row[11])],
			String(SLOT_TAGS.get(g2, "")), yaw)
		if bool(row[10]):
			_slot_use_point(ph, at, yaw, String(row[3]))


## The UsePoint of an interactive slot's content: USE_POINT_M in front of the anchor, on the floor it stands on (the
## floor's FFL; an anchor more than 2 m above it, the GH half landing, stands on its own level), -Z at the anchor.
func _slot_use_point(ph: Marker3D, at: Vector3, yaw: float, floor_id: String) -> void:
	var ffl: float = float(L.FFL[floor_id])
	var fy: float = at.y if at.y - ffl > 2.0 else ffl
	var front: Vector3 = yaw_basis(yaw) * Vector3.FORWARD
	var p: Vector3 = Vector3(at.x, fy, at.z) + front * L.USE_POINT_M
	var up: Marker3D = Marker3D.new()
	up.name = "UsePoint"
	up.transform = global_xform(ph).affine_inverse() * _facing(p, at)
	add(ph, up)


## court_doors: the WG French doors, NONE until last call (court_doors_open) or LOCKPICK 8 s (court_doors_locked).
func _court_doors(vs: VariantSlot, sid: String) -> void:
	for d: Array in DOORS:
		if String((d[8] as Dictionary).get("slot", "")) == "court_doors":
			door(vs, d, String(d[0]), String(COURT_LOCK[sid]))


func _slot(parent: Node3D, group: String, slot_id: String, weight: float, at: Vector3, yaw: float,
		params: Dictionary) -> VariantSlot:
	var vs: VariantSlot = VariantSlot.new()
	vs.name = "Slot_" + slot_id
	vs.slot_group = StringName(group)
	vs.slot_id = StringName(slot_id)
	vs.weight = weight
	vs.params = params
	vs.transform = Transform3D(yaw_basis(yaw), at)
	add(parent, vs)
	return vs
