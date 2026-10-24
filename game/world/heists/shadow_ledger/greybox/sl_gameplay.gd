## Shadow Ledger generator: gameplay prefabs (Gameplay) and variant slots (Variants). Owner: ENV C (C2).
## Chain: sl_builder_base.gd <- sl_gameplay.gd <- build_greybox.gd. Design: docs/design/heists/
## shadow_ledger.md (§Objectives, §Loot path, §Variable table, §Rare events); contracts:
## gameplay_prefabs.md, heist_map.md §5. Prefabs are found by contract class name (no path into
## ENV A's folder).
extends "res://world/heists/shadow_ledger/greybox/sl_builder_base.gd"

## Code group of the server cage (notes, contractor laptop, the cage lock).
const CAGE_GROUP: StringName = &"cage"
const HACK_S: float = 45.0
const HELI_DELAY_S: float = 45.0
## D-111 SL-2 bag-secure drops (tools/blender/props/secure_drops.py; low lying, no collider): the cargo net on the
## pad (E1), the crew's rigging tarp at the line anchor (E2), freight blankets in the service-lift car (E3).
const SECURE_NET_VISUAL: String = "prop_secure_cargo_net"
const SECURE_TARP_VISUAL: String = "prop_secure_line_tarp"
const SECURE_LIFT_VISUAL: String = "prop_secure_lift_blanket"
## D-111 SL-2 lasers (tools/blender/props/lasers.py): the emitter column art and the beam set per laser_pattern slot.
const LASER_COLUMN: String = "prop_laser_emitter_column"
const LASER_BEAMS: Dictionary = {
	"lz_static": "prop_laser_beams_h688x3", "lz_sweep": "prop_laser_beams_v260x3", "lz_timed": "prop_laser_beams_h688x4",
}
## D-111 SL-2 E2 bag line: the catalog anchor (prop_zipline_anchor, wall-mounted, `Line` at the sheave groove) bolted
## to the east face of the roof's E2AnchorFrame, ANCHOR_Y over the roof, the line leaving east over the parapet.
## The zipline's Interactable (the bag's start) hangs BAG_DROP below the sheave, so bags ride under the cable; the
## drawn cable (Zipline cable_start / cable_end) runs from the sheave to the far end raised by the same drop.
## D-138: the gate padlock visual (as DB's roller doors).
const PADLOCK_VISUAL: String = "res://assets/props/prop_padlock_brass/prop_padlock_brass.glb"
const ZIPLINE_ANCHOR: String = "prop_zipline_anchor"
const ANCHOR_FRAME: String = "E2AnchorFrame"
const ANCHOR_Y: float = 1.75
const ANCHOR_LINE: Vector3 = Vector3(0.0, 0.042, -0.27)  # the anchor's `Line` marker, anchor-local (equipment.py)
const BAG_DROP: float = 0.34
const ANCHOR_LINE_PATH: NodePath = ^"Visual/PropZiplineAnchor/Model/Line"
## SL-3: the camera operator's NPC seat (D-063 task chair, seat 0.47 m) on the CameraOperatorSeat spawn.
const OPERATOR_CHAIR: String = "prop_chair_task"
## PO-13 escape_zone visuals (tools/blender/props/escape.py): the landed heli, the crew's clip-on rig at the
## E2 anchor, the service-lift car fit-out.
const ESCAPE_HELI_VISUAL: String = "res://world/props/escape_zone/veh_heli_escape.tscn"
const ESCAPE_LINE_VISUAL: String = "res://world/props/escape_zone/prop_escape_zipline_rig.tscn"
const ESCAPE_LIFT_VISUAL: String = "res://world/props/escape_zone/prop_escape_lift_fitout.tscn"
## Victor Kessler's seat in M5 (kessler_in): the npc_seat armchair's seat centre = his spawn.
const KESSLER_SEAT: Vector3 = Vector3(3.0, L.F42, 12.3)
## The catalog armchair (sales.py: cushion 0.42-0.50 m between the back and the front edge) has no `Seat` marker:
## npc_seat adds one over its cushion centre, 0.09 m in front of the pivot.
const KESSLER_CHAIR: String = "prop_armchair"
const ARMCHAIR_SEAT: Vector3 = Vector3(0.0, 0.45, -0.09)
## D-130 `late_staff` work spots (doc §roster): [slot, spawn name, chair pivot, yaw (faces the desk), tags]. The seats
## are the layout chairs L.NPC_SEAT_CHAIRS (K4 AssistantChairA at desk A, K8 PodAChairS1 at pod A), built as D-063 NPC
## seats; there with or without their worker (as OperatorChair), who does `desk_work` on the `Seat` (the spawn moved
## onto it after the dressing, NpcSeatSpawns: prop_chair_office art, 0.12 m in front of the pivot).
const LATE_STAFF: Array = [
	["ls_assistant", "AssistantLate", Vector3(25.6, L.F41, 1.2), 180.0, ["civ_assistant", "civ_staff"]],
	["ls_associate", "AssociateLate", Vector3(2.4, L.F41, 11.25), 0.0, ["civ_associate", "civ_staff"]],
]
## D-111 prop art pass: catalog visual (tools/blender/props) per prefab type, as on Night Deposit
## (nd_gameplay.PREFAB_VISUALS). Doors, ladders, lasers, loot and escapes choose theirs where they are built.
const PREFAB_VISUALS: Dictionary = {
	"safe": "prop_safe_large", "keycard_pickup": "prop_keycard_bank", "keycard_reader": "prop_keycard_reader",
	"code_note": "prop_papers", "alarm_button": "prop_alarm_button", "phone": "prop_phone_desk",
	"body_container": "prop_dumpster", "camera_station": "prop_camera_station_bank",
	"security_camera": "prop_security_camera_wall", "hack_terminal": "prop_server_rack_terminal", "keypad": "prop_keypad",
}
## D-111 doors: the layout's greybox kit piece (arch_door_<kind>_t<20|40>) maps to the catalog door of the same kind
## and wall thickness (tools/blender/props/doors.py) in the room's finish: glass (leaf_surface glass), steel (back of
## house, stairs, plant, facade and security doors), walnut (the partners' and the residence's rooms), else ivory.
const DOOR_STEEL: Array[String] = [
	"RefuseDoor", "StairBL40", "StairAGate", "StairBGate", "K1FacadeDoor", "JanitorL41", "StairAL41", "StairBL41",
	"ServerDoor", "SecurityDoor", "ElectricalL41", "CageGate", "StudyFacadeDoor", "LinenL42", "StairAL42", "StairBL42",
	"ElectricalL42", "RoofDoor", "RiserBayDoor", "HeadHousePlantDoor", "PlantDoor",
]
## Doors in the curtain-wall facade (FACADE_LINES): the gondola access doors and the terrace sliders.
const DOOR_FACADE: Array[String] = ["K1FacadeDoor", "StudyFacadeDoor", "SliderDining", "SliderWest", "SliderEast"]
const DOOR_WALNUT: Array[String] = [
	"K1Door", "K5Door", "LibraryDoor", "ArtHallDoors", "StudyDoor", "SuiteDoor", "DiningDoor", "WineRoomDoor",
	"BoardroomDoor",
]
## D-111 loot: catalog stacks per loot id (tools/blender/props/loot.py; the cash bags) and the small valuables; the
## art-hall paintings are GN study canvases hung on the M3 south wall (wall loot: pivot back-centre on the face, centre
## PAINTING_HANG_Y above the floor, taken from the UsePoint in front).
const LOOT_VISUALS: Dictionary = {
	"loot.ledger_laptop": "prop_loot_laptop", "loot.ledger_drives": "prop_loot_ledger_drives",
	"loot.ledger_books": "prop_loot_ledger_books", "loot.cash": "prop_cash_bags",
}
const PAINTING_VISUALS: Array[String] = ["prop_canvas_study3", "prop_canvas_study6"]
const PAINTING_HANG_Y: float = 1.6
## Ladder visuals by height and wall gap (prefab_visuals.py `prop_ladder_steel_*`: Top / Bottom exactly where the
## placeholder had them, stand-offs reaching the wall behind; g00 = free-standing in the riser hole).
const LADDER_RISER_LOWER: String = "prop_ladder_steel_h440_g00"
const LADDER_RISER_UPPER: String = "prop_ladder_steel_h360_g00"
const LADDER_TERRACE: String = "prop_ladder_steel_h360_g25"
const LADDER_GONDOLA: Dictionary = {
	"gon_west_l41": "prop_ladder_steel_h800_g40", "gon_north_l42": "prop_ladder_steel_h360_g40",
}


# --- Prefab helpers ---------------------------------------------------------------------------

## Instances a prefab under `parent` at a WORLD position / yaw (the parent may be a moved prefab).
## props: export -> value ("enum:KEY" looks the key up in the prefab script's enums). use_point:
## world floor point for the UsePoint, or null to keep the prefab's own.
func prefab(parent: Node3D, kind: String, nm: String, pos: Vector3, yaw: float, props: Dictionary = {},
		use_point: Variant = null, metas: Dictionary = {}, obstruct_body: bool = true) -> Node3D:
	var ps: PackedScene = prefab_scene(kind)
	if ps == null:
		return null
	var inst: Node3D = ps.instantiate() as Node3D
	inst.name = nm
	var world: Transform3D = Transform3D(yaw_basis(yaw), pos)
	inst.transform = global_xform(parent).affine_inverse() * world if parent != map_root else world
	for k: Variant in props:
		_set_prop(inst, String(k), props[k])
	if not props.has("visual_scene") and PREFAB_VISUALS.has(kind):
		inst.set(&"visual_scene", _catalog_scene(String(PREFAB_VISUALS[kind])))
	elif not props.has("visual_scene") and kind == "loot_spawn" and LOOT_VISUALS.has(String(props.get("loot_id", ""))):
		inst.set(&"visual_scene", _catalog_scene(String(LOOT_VISUALS[String(props["loot_id"])])))
	for mk: Variant in metas:
		inst.set_meta(StringName(String(mk)), metas[mk])
	parent.add_child(inst)
	inst.owner = map_root
	if use_point != null:
		place_use_point(inst, use_point as Vector3)
	if obstruct_body and kind in ["safe", "body_container", "camera_station", "hack_terminal"]:
		_obstruct_prefab(inst)
	return inst


## Moves a prefab's UsePoint to a world floor point, -Z facing the object (Editable Children).
func place_use_point(inst: Node3D, world: Vector3) -> void:
	var up: Node3D = inst.get_node_or_null("UsePoint") as Node3D
	if up == null:
		errors.append("%s has no UsePoint" % inst.name)
		return
	var xf: Transform3D = global_xform(inst)
	var to_obj: Vector3 = xf.origin - world
	to_obj.y = 0.0
	if to_obj.length() < 0.01:
		to_obj = xf.basis * Vector3.FORWARD
	var g: Transform3D = Transform3D(Basis.looking_at(to_obj.normalized(), Vector3.UP), world)
	up.transform = xf.affine_inverse() * g
	map_root.set_editable_instance(inst, true)


func global_xform(c: Node3D) -> Transform3D:
	if c == map_root:
		return Transform3D.IDENTITY
	var xf: Transform3D = c.transform
	var p: Node = c.get_parent()
	while p != null and p != map_root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


func _obstruct_prefab(inst: Node3D) -> void:
	var base: Transform3D = global_xform(inst)
	for c: Node in inst.find_children("*", "CollisionShape3D", true, false):
		var cs: CollisionShape3D = c
		var body: Node = cs.get_parent()
		if not (body is StaticBody3D) or not (cs.shape is BoxShape3D):
			continue
		var rel: Transform3D = cs.transform
		var p: Node = body
		while p != null and p != inst:
			rel = (p as Node3D).transform * rel
			p = p.get_parent()
		var sz: Vector3 = (cs.shape as BoxShape3D).size
		obstruct(base * rel, AABB(-sz * 0.5, sz))


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


## Wall-mounted security camera (pivot on the wall / bracket face, -Z into the room).
func security_camera(parent: Node3D, cid: String) -> Node3D:
	var row: Array = L.CAMERAS[cid]
	return prefab(parent, "security_camera", "Camera" + cid, row[0], float(row[1]),
		{"fov_deg": 60.0, "range_m": 20.0, "pan_deg": 40.0}, null,
		{"mount": "wall", "kind": "security_camera", "camera_id": cid})


func marker(parent: Node3D, nm: String, world: Vector3) -> Marker3D:
	var m: Marker3D = Marker3D.new()
	m.name = nm
	m.position = global_xform(parent).affine_inverse() * world
	add(parent, m)
	return m


func nav_link(parent: Node3D, nm: String, a: Vector3, b: Vector3) -> NavigationLink3D:
	var link: NavigationLink3D = NavigationLink3D.new()
	link.name = nm
	link.bidirectional = true
	link.navigation_layers = 1
	var inv: Transform3D = global_xform(parent).affine_inverse()
	link.start_position = inv * a
	link.end_position = inv * b
	add(parent, link)
	return link


# --- Gameplay ---------------------------------------------------------------------------------

func build_gameplay(gp: Node3D) -> void:
	_build_doors(gp)
	_build_server(gp)
	_build_study(gp)
	_build_misc(gp)
	_build_ladders(gp)


func _build_doors(gp: Node3D) -> void:
	var doors: Node3D = add(gp, node3d("Doors")) as Node3D
	for d: Array in L.DOORS:
		var props: Dictionary = {"lock": "enum:" + String(d[4]), "swing": "enum:" + String(d[5]),
			"visual_scene": _catalog_scene(door_visual(d))}
		if String(d[6]) != "":
			props["objective_tag"] = StringName(String(d[6]))
		var metas: Dictionary = {"kind": "door", "swing_side": "front" if String(d[5]) == "OUTWARD" else "back"}
		var extra: Dictionary = d[7]
		if bool(extra.get("npc_auth", false)):
			props["npc_authorized_tags"] = _names(L.STAFF_TAGS)
		if bool(extra.get("fire_exit", false)):
			metas["fire_exit"] = true
		if bool(extra.get("starts_open", false)):
			props["starts_open"] = true
		if extra.has("interaction_time_s"):
			props["interaction_time_s"] = float(extra["interaction_time_s"])
		if extra.has("access_sides"):  # levelcheck door_access: the gondola doors' back is the cradle (a moving deck, not baked)
			metas["access_sides"] = String(extra["access_sides"])
		if extra.has("leaf_surface"):  # D-105: glass / metal leaves on a greybox kit visual (reads as wood)
			props["leaf_surface"] = StringName(String(extra["leaf_surface"]))
		if String(d[1]).contains("double"):
			props["width_m"] = 1.8
		prefab(doors, "door", String(d[0]), d[2], float(d[3]), props, null, metas)


## Catalog door for a layout row (DOOR_STEEL / DOOR_WALNUT; glass by leaf_surface): arch_door_single_t20 ->
## prop_door_single_<finish>_t20. The frame follows the wall it stands in (doors.py `wall_t`): the greybox t40 piece
## sits in a 0.3 m core wall (t30), or in the curtain wall's 0.04 m glazing (DOOR_FACADE, t04); a `no_wall` gate in
## its 0.06 m mesh screen (t06).
static func door_visual(d: Array) -> String:
	var piece: String = String(d[1]).trim_prefix("arch_door_")
	var nm: String = String(d[0])
	var extra: Dictionary = d[7] as Dictionary
	var fin: String = "ivory"
	if String(extra.get("leaf_surface", "")) == "glass":
		fin = "glass"
	elif nm in DOOR_STEEL:
		fin = "steel"
	elif nm in DOOR_WALNUT:
		fin = "walnut"
	var t: String = piece.get_slice("_", 1)
	if bool(extra.get("no_wall", false)):
		t = "t06"
	elif nm in DOOR_FACADE:
		t = "t04"
	elif t == "t40":
		t = "t30"
	return "prop_door_%s_%s_%s" % [piece.get_slice("_", 0), fin, t]


## K11 server room: the keycard reader on K10 (opens the server door), the cage gate's two locks (D-138 / PO-14: a
## `keypad` on the gate post, code group `cage`, and a brass `padlock` on the leaf for the placed saw, 90 s; either one
## opens the CageGate itself, no stand-in safe), the ledger rack's hack terminal and the three drive sleds inside.
## The terminal and sleds are siblings, and the mission gates them (hack after the cage, drives after the hack; G1 report).
func _build_server(gp: Node3D) -> void:
	var srv: Node3D = add(gp, node3d("Server")) as Node3D
	var door: Node3D = n("Gameplay/Doors/ServerDoor")
	var reader: Node3D = prefab(srv, "keycard_reader", "ServerReader", Vector3(25.4, L.F41 + 1.2, 9.2), 90.0,
		{"objective_tag": &"server_reader"}, Vector3(24.75, L.F41, 9.2), {"mount": "wall", "kind": "keycard_reader"})
	if reader != null and door != null:
		reader.set(&"targets", [reader.get_path_to(door)] as Array[NodePath])
	var gate: Node3D = n("Gameplay/Doors/CageGate")
	if gate == null:
		errors.append("CageGate missing: no cage locks")
		return
	_cage_locks(gate)
	# The ledger rack's drive-bay release (hack_terminal, a 0.6 x 2.0 x 1.0 rack, front south), back to the
	# cage's north panel and clear of the CageGate's 1 m door zone (PO-9).
	prefab(srv, "hack_terminal", "HackTerminal", Vector3(28.75, L.F41, 8.95), 180.0,
		{"duration_s": HACK_S, "interruptions": Vector2i(1, 2), "objective_tag": &"hack"}, null, {"kind": "hack_terminal"})
	for i: int in range(3):
		var x: float = [27.4, 29.45, 30.1][i]
		prefab(srv, "loot_spawn", "Drives%d" % (i + 1), Vector3(x, L.F41, 9.75), 180.0,
			{"loot_id": &"loot.ledger_drives", "count": 1, "objective_tag": &"drives"}, Vector3(x, L.F41, 10.1))


## D-138: the CageGate's locks on its hall face (gate yaw 180, so local -Z is the hall): the keypad on the post beyond
## the leaf's hinge-free edge (1.2 m), the brass padlock on the leaf's latch side (1.1 m); both target the gate.
func _cage_locks(gate: Node3D) -> void:
	var xf: Transform3D = global_xform(gate)
	var yaw: float = float(L.DOORS.filter(func(d: Array) -> bool: return String(d[0]) == "CageGate")[0][3]) + 180.0
	var pad: Vector3 = xf * Vector3(0.38, 1.1, -0.07)
	var key: Vector3 = xf * Vector3(-0.62, 1.2, -0.07)
	var use_pad: Vector3 = xf * Vector3(0.38, 0.0, -0.9)
	var use_key: Vector3 = xf * Vector3(-0.62, 0.0, -0.9)
	var to_gate: Array[NodePath] = [NodePath("..")]
	prefab(gate, "keypad", "CageKeypad", key, yaw, {"code_group": CAGE_GROUP, "targets": to_gate,
		"objective_tag": &"cage"}, use_key, {"mount": "wall", "kind": "keypad"})
	prefab(gate, "padlock", "CagePadlock", pad, yaw, {"targets": to_gate.duplicate(), "place_saw": true,
		"place_saw_stealth": true, "saw_duration_s": 90.0, "allow_lockpick": false, "objective_tag": &"cage",
		"visual_scene": load(PADLOCK_VISUAL)}, use_pad,
		{"mount": "door", "kind": "padlock"})  # D-115 SL-1: the doc's 90 s placed saw


## M4 study: the time-locked safe (MEDIUM, keycard via its reader; time_lock_s set by the mission)
## with the ledger books and 3 small loot inside.
func _build_study(gp: Node3D) -> void:
	var st: Node3D = add(gp, node3d("Study")) as Node3D
	var reader: Node3D = prefab(st, "keycard_reader", "StudyReader", Vector3(32.0, L.F42 + 1.2, 7.4), 0.0,
		{"objective_tag": &"study_reader"}, Vector3(32.0, L.F42, 6.6), {"mount": "wall", "kind": "keycard_reader"})
	var safe: Node3D = prefab(st, "safe", "StudySafe", Vector3(33.0, L.F42, 7.04), 0.0,
		{"size": "enum:MEDIUM", "methods": [&"keycard"] as Array[StringName], "time_lock_s": 90.0,
			"objective_tag": &"study_safe"}, null, {"kind": "safe"})
	if safe == null:
		return
	if reader != null:
		safe.set(&"reader", safe.get_path_to(reader))
		reader.set(&"targets", [reader.get_path_to(safe)] as Array[NodePath])
	for i: int in range(3):
		var x: float = 32.76 + 0.24 * float(i)
		prefab(safe, "small_loot", "StudyValuables%d" % (i + 1), Vector3(x, L.F42 + 0.75, 7.04), 0.0,
			{"loot_id": &"loot.small_valuables", "value": 1500,
				"visual_scene": _catalog_scene("prop_valuables_watch_box" if i == 1 else "prop_valuables_jewelry_case")},
			Vector3(x, L.F42, 6.2))
	# PO6-05: the books sit at the safe's LootAnchor (safe-local (0, 0.02, 0)), taken from the UsePoint in front.
	prefab(safe, "loot_spawn", "LedgerBooks", Vector3(33.0, L.F42 + 0.02, 7.04), 0.0,
		{"loot_id": &"loot.ledger_books", "count": 1, "objective_tag": &"study_safe_loot"}, Vector3(34.2, L.F42, 5.8))


func _build_misc(gp: Node3D) -> void:
	var misc: Node3D = add(gp, node3d("Misc")) as Node3D
	var station: Node3D = prefab(misc, "camera_station", "CameraStation", Vector3(29.49, L.F41, 14.5), 90.0,
		{}, null, {"kind": "camera_station"})
	if station != null:
		station.set(&"operator_spawn", station.get_path_to(map_root.get_node("Spawns/CameraOperatorSeat")))
	# SL-3: the operator's task chair on his layout spot, facing the monitor wall (as ND / GH OperatorChair); there with
	# or without `sec_staffed` (a security room keeps its chair), no collider (D-063 NPC seat). D-130: the chair's pivot
	# on the spot, the spawn then on its Seat (NpcSeatSpawns, after the dressing).
	var op: Node3D = map_root.get_node("Spawns/CameraOperatorSeat") as Node3D
	npc_seat(misc, "OperatorChair", global_xform(op).origin, roundf(rad_to_deg(op.basis.get_euler().y)), OPERATOR_CHAIR,
		Vector3(0.0, 0.45, 0.0), true)
	# Alarm buttons: under the reception ledge, the security console, the guest-suite bedside.
	prefab(misc, "alarm_button", "AlarmReception", Vector3(17.6, L.F41 + 0.8, 4.795), 0.0, {},
		Vector3(17.6, L.F41, 4.2), {"mount": "wall", "kind": "alarm_button"})
	prefab(misc, "alarm_button", "AlarmSecurity", Vector3(28.4, L.F41 + 1.2, 16.4), 0.0, {},
		Vector3(28.4, L.F41, 15.7), {"mount": "wall", "kind": "alarm_button"})
	prefab(misc, "alarm_button", "AlarmGuestSuite", Vector3(0.2, L.F42 + 0.75, 12.4), -90.0, {},
		Vector3(0.9, L.F42, 12.4), {"mount": "wall", "kind": "alarm_button"})
	# Phones (doc: K1, K3, K4, K5, K12, K13, K18, M5, M11).
	var phones: Array = [
		["PhoneKessler", Vector3(2.4, L.F41 + 0.75, 2.0), Vector3(2.4, L.F41, 3.05)],
		["PhoneReception", Vector3(17.0, L.F41 + 1.05, 5.1), Vector3(17.0, L.F41, 4.35)],
		["PhoneAssistant", Vector3(25.6, L.F41 + 0.75, 2.0), Vector3(25.6, L.F41, 2.75)],
		["PhoneMoor", Vector3(31.9, L.F41 + 0.75, 2.0), Vector3(31.9, L.F41, 3.05)],
		["PhoneIT", Vector3(32.6, L.F41 + 0.75, 11.2), Vector3(32.6, L.F41, 11.95)],
		["PhoneSecurity", Vector3(27.1, L.F41 + 0.9, 16.14), Vector3(27.1, L.F41, 15.45)],
		["PhoneBreakRoom", Vector3(7.8, L.F41 + 0.9, 23.49), Vector3(7.8, L.F41, 22.8)],
		["PhoneGuestSuite", Vector3(0.46, L.F42 + 0.6, 11.55), Vector3(1.2, L.F42, 11.95)],
		["PhonePantry", Vector3(27.0, L.F42 + 0.9, 7.885), Vector3(27.0, L.F42, 8.6)],
	]
	for p: Array in phones:
		prefab(misc, "phone", String(p[0]), p[1], 0.0, {}, p[2], {"kind": "phone"})
	# S2 refuse room: 2 waste containers (body_container, 1 body each; the 0.94 m deep prop_dumpster_d094 clears the back wall).
	for b: Array in [["RefuseBinA", 26.6], ["RefuseBinB", 28.5]]:
		prefab(misc, "body_container", String(b[0]), Vector3(float(b[1]), L.F40, 15.89), 0.0,
			{"capacity": 1, "visual_scene": _catalog_scene("prop_dumpster_d094")}, null, {"kind": "bin"})
	# Archive safe (K17, MEDIUM, saw only): the partners' cash float. D-142 / PO-14: 0.5 m east of the SW corner pier
	# (x <= 0.05) so the thermal-drill / saw rig's 1 m tail clears it (it clipped 127 mm); 1.2 m+ clear all round.
	var arch: Node3D = prefab(misc, "safe", "ArchiveSafe", Vector3(1.7, L.F41, 23.44), 0.0,
		{"size": "enum:MEDIUM", "methods": [&"saw"] as Array[StringName], "objective_tag": &"archive_safe"},
		null, {"kind": "safe"})
	# PO6-05: the cash at the safe's LootAnchor (safe-local (0, 0.14, 0)), taken from the UsePoint; D-111: the float
	# is bagged (prop_loot_bag_medium fits the MEDIUM body, the cash-bag stack does not).
	if arch != null:
		prefab(arch, "loot_spawn", "ArchiveCash", Vector3(1.7, L.F41 + 0.14, 23.44), 0.0,
			{"loot_id": &"loot.cash", "count": 1, "objective_tag": &"archive_loot",
				"visual_scene": _catalog_scene("prop_loot_bag_medium")}, Vector3(2.9, L.F41, 22.2))
	# Art hall paintings (east of the lasers), cut from the frame: hung on the M3 south wall face (z 7.4).
	for i: int in range(2):
		var x: float = 27.3 + 1.0 * float(i)
		prefab(misc, "loot_spawn", "Painting%d" % (i + 1), Vector3(x, L.F42 + PAINTING_HANG_Y, 7.4), 0.0,
			{"loot_id": &"loot.painting", "count": 1, "interaction_time_s": 4.0, "objective_tag": &"paintings",
				"visual_scene": _catalog_scene(PAINTING_VISUALS[i])},
			Vector3(x, L.F42, 6.4), {"mount": "wall"})
	# Rare `ledger_printout`: a working copy of the books on the K1 desk side (mission enables it).
	prefab(misc, "loot_spawn", "PrintoutBooks", Vector3(4.4, L.F41, 3.2), 0.0,
		{"loot_id": &"loot.ledger_books", "count": 1, "objective_tag": &"printout"}, Vector3(4.4, L.F41, 3.8))
	# Small loot: the partners' desks and the wine-room humidor.
	prefab(misc, "small_loot", "KesslerWatch", Vector3(3.5, L.F41 + 0.75, 2.0), 0.0,
		{"loot_id": &"loot.small_valuables", "value": 1200, "visual_scene": _catalog_scene("prop_valuables_watch_box")},
		Vector3(3.5, L.F41, 3.05))
	prefab(misc, "small_loot", "MoorBracelet", Vector3(33.0, L.F41 + 0.75, 2.0), 0.0,
		{"loot_id": &"loot.small_valuables", "value": 1200, "visual_scene": _catalog_scene("prop_valuables_jewelry_case")},
		Vector3(33.0, L.F41, 3.05))
	for i2: int in range(2):
		var z: float = 14.35 + 0.3 * float(i2)
		prefab(misc, "small_loot", "HumidorCigars%d" % (i2 + 1), Vector3(30.64, L.F42 + 1.0, z), 0.0,
			{"loot_id": &"loot.small_valuables", "value": 800, "visual_scene": _catalog_scene("prop_valuables_cigar_box")},
			Vector3(29.9, L.F42, z))


## Ladders (S9.11; unmasked crew cannot climb): the services riser (L41 -> L42 grating -> R1) and the
## terrace caged ladder. The gondola boarding ladders live in the `gondola` slots.
func _build_ladders(gp: Node3D) -> void:
	var lad: Node3D = add(gp, node3d("Ladders")) as Node3D
	var r: Dictionary = L.RISER
	prefab(lad, "ladder", "RiserLadderLower", r["lower_ladder"], 0.0, {"height_m": L.F42 - L.F41,
		"visual_scene": _catalog_scene(LADDER_RISER_LOWER)}, null, {"kind": "ladder"})
	prefab(lad, "ladder", "RiserLadderUpper", r["upper_ladder"], 0.0, {"height_m": L.FRF - L.F42,
		"visual_scene": _catalog_scene(LADDER_RISER_UPPER)}, null, {"kind": "ladder"})
	var t: Dictionary = L.TERRACE_LADDER
	prefab(lad, "ladder", "TerraceLadder", t["pos"], float(t["yaw"]), {"height_m": float(t["h"]),
		"visual_scene": _catalog_scene(LADDER_TERRACE)}, null, {"kind": "ladder"})


# --- Variants ---------------------------------------------------------------------------------

func _slot(parent: Node3D, group: String, slot_id: String, weight: float, params: Dictionary = {}) -> VariantSlot:
	var vs: VariantSlot = VariantSlot.new()
	vs.name = "Slot_" + slot_id
	vs.slot_group = StringName(group)
	vs.slot_id = StringName(slot_id)
	vs.weight = weight
	vs.params = params
	add(parent, vs)
	return vs


func _group(parent: Node3D, group: String) -> Node3D:
	return add(parent, node3d("Group_" + group)) as Node3D


func build_variants(variants: Node3D) -> void:
	_variants_people(variants)
	_variants_laptop(variants)
	_variants_server(variants)
	_variants_keycards(variants)
	_variants_code(variants)
	_variants_guards(variants)
	_variants_security(variants)
	_variants_lasers(variants)
	_variants_vent(variants)
	_variants_gondola(variants)
	_variants_escape(variants)


## Civilians: Helena Moor (late_partner), the cleaners, Victor Kessler (rare kessler_sleepover).
func _variants_people(variants: Node3D) -> void:
	var lp: Node3D = _group(variants, "late_partner")
	var ml: VariantSlot = _slot(lp, "late_partner", "moor_late", 0.35)
	spawn(ml, "HelenaMoor", "CIVILIAN", Vector3(31.2, L.F41, 1.0), 180.0, ["civ_partner", "civ_staff"], "phone", "")
	_slot(lp, "late_partner", "moor_gone", 0.65)
	var cl: Node3D = _group(variants, "cleaners")
	_slot(cl, "cleaners", "cleaners_1", 0.5)
	var c2: VariantSlot = _slot(cl, "cleaners", "cleaners_2", 0.5)
	spawn(c2, "CleanerL42", "CIVILIAN", Vector3(5.0, L.F42, 6.4), 0.0, ["civ_cleaner_l42", "civ_staff"], "browse", "")
	var c3: VariantSlot = _slot(cl, "cleaners", "cleaners_3", 0.0)
	spawn(c3, "CleanerL42", "CIVILIAN", Vector3(5.0, L.F42, 6.4), 0.0, ["civ_cleaner_l42", "civ_staff"], "browse", "")
	spawn(c3, "CleanerL41B", "CIVILIAN", Vector3(28.5, L.F41, 17.25), 90.0, ["civ_cleaner_l41", "civ_staff"], "browse", "")
	var kg: Node3D = _group(variants, "kessler")
	var ki: VariantSlot = _slot(kg, "kessler", "kessler_in", 0.0)
	# PO6-06: reading in the M5 armchair at the bedside (back to the south wall, facing the bed's foot), on its `Seat`;
	# the alarm button and the bedside phone are ~2 m west, the suite door's clear zone 3 m east.
	spawn(ki, "VictorKessler", "CIVILIAN", KESSLER_SEAT, 0.0, ["civ_kessler", "civ_staff"], "sit", "")
	npc_seat(ki, "KesslerArmchair", KESSLER_SEAT, 0.0, KESSLER_CHAIR, ARMCHAIR_SEAT)
	_slot(kg, "kessler", "kessler_out", 1.0)
	# D-130 (population by difficulty): one of the firm's staff working late from Tense up (pick 0 + difficulty_add,
	# the empty `ls_none` sets the odds per tier, shadow_ledger_resources.gd), seated at a desk: the executive
	# assistant in K4 (next to Moor's office and C5's corridor) or an associate in the K8 open office (C11's room).
	var ls: Node3D = _group(variants, "late_staff")
	for r: Array in LATE_STAFF:
		var s: VariantSlot = _slot(ls, "late_staff", String(r[0]), 1.0)
		spawn(s, String(r[1]), "CIVILIAN", r[2], float(r[3]), r[4], "desk_work", "")
	_slot(ls, "late_staff", "ls_none", 6.0)


## Laptop (LIGHT bag `loot.ledger_laptop`): K1, K5, M4 study (behind the lasers), M14 boardroom.
func _variants_laptop(variants: Node3D) -> void:
	var lg: Node3D = _group(variants, "laptop")
	var rows: Array = [
		["lap_kessler", 1.0, Vector3(4.3, L.F41, 2.2), Vector3(4.3, L.F41, 1.4)],
		["lap_moor", 1.0, Vector3(30.8, L.F41, 2.2), Vector3(30.8, L.F41, 3.0)],
		["lap_study", 1.0, Vector3(30.6, L.F42, 2.0), Vector3(30.6, L.F42, 1.2)],
		["lap_boardroom", 0.75, Vector3(35.0, L.F42, 8.4), Vector3(35.0, L.F42, 9.2)],
	]
	for r: Array in rows:
		var s: VariantSlot = _slot(lg, "laptop", String(r[0]), float(r[1]))
		prefab(s, "loot_spawn", "Laptop", r[2], 0.0,
			{"loot_id": &"loot.ledger_laptop", "count": 1, "objective_tag": &"laptop"}, r[3])


## Server room: locked (keycard) or the IT contractor at work (door propped, the code on his laptop).
func _variants_server(variants: Node3D) -> void:
	var sg: Node3D = _group(variants, "server_room")
	_slot(sg, "server_room", "srv_locked", 0.6)
	var sc: VariantSlot = _slot(sg, "server_room", "srv_contractor", 0.4, {"door_propped": "Gameplay/Doors/ServerDoor"})
	# PO6-06: K11 has no desk or chair (racks, CRAC, UPS), so the contractor stands on a call, not `desk_work`.
	spawn(sc, "ITContractor", "CIVILIAN", Vector3(26.5, L.F41, 11.8), 90.0, ["civ_it", "civ_staff"], "phone", "")


## Keycards (pick 2): reception drawer, security cabinet, IT desk, Kessler's desk, lounge bar, guest
## nightstand, the L42 cleaner's cart.
func _variants_keycards(variants: Node3D) -> void:
	var kc: Node3D = _group(variants, "keycard")
	var rows: Array = [
		["kc_reception", 1.0, Vector3(18.9, L.F41 + 1.05, 5.1), Vector3(18.9, L.F41, 4.35)],
		["kc_security", 0.75, Vector3(26.2, L.F41 + 1.0, 12.76), Vector3(26.2, L.F41, 13.45)],
		["kc_it", 1.0, Vector3(32.6, L.F41 + 0.75, 9.0), Vector3(32.6, L.F41, 9.75)],
		["kc_kessler", 1.0, Vector3(3.6, L.F41 + 0.75, 2.4), Vector3(3.6, L.F41, 3.05)],
		["kc_lounge", 1.0, Vector3(3.3, L.F42 + 1.1, 1.6), Vector3(3.3, L.F42, 2.35)],
		["kc_guest", 1.0, Vector3(0.46, L.F42 + 0.6, 8.85), Vector3(1.2, L.F42, 8.4)],
		["kc_cleaner", 0.75, Vector3(12.65, L.F42 + 1.0, 10.09), Vector3(13.5, L.F42, 9.7)],
	]
	for r: Array in rows:
		var s: VariantSlot = _slot(kc, "keycard", String(r[0]), float(r[1]))
		prefab(s, "keycard_pickup", "Keycard", r[2], 0.0, {"objective_tag": &"keycard"}, r[3])


## Cage code (pick 1): IT whiteboard, security logbook, Moor's planner, the contractor's laptop.
func _variants_code(variants: Node3D) -> void:
	var cn: Node3D = _group(variants, "code_note")
	var wb: VariantSlot = _slot(cn, "code_note", "code_it_board", 1.0, {"code_group": CAGE_GROUP})
	prefab(wb, "code_note", "CodeNote", Vector3(33.6, L.F41 + 0.75, 11.2), 0.0, {"code_group": CAGE_GROUP,
		"objective_tag": &"cage_code"}, Vector3(33.6, L.F41, 11.95))
	var lg: VariantSlot = _slot(cn, "code_note", "code_security_log", 1.0, {"code_group": CAGE_GROUP})
	prefab(lg, "code_note", "CodeNote", Vector3(26.3, L.F41 + 0.9, 16.14), 0.0, {"code_group": CAGE_GROUP,
		"objective_tag": &"cage_code"}, Vector3(26.3, L.F41, 15.45))
	var pl: VariantSlot = _slot(cn, "code_note", "code_moor_planner", 1.0, {"code_group": CAGE_GROUP})
	prefab(pl, "code_note", "CodeNote", Vector3(33.1, L.F41 + 0.75, 2.4), 0.0, {"code_group": CAGE_GROUP,
		"objective_tag": &"cage_code"}, Vector3(33.1, L.F41, 3.05))
	var ct: VariantSlot = _slot(cn, "code_note", "code_contractor", 1.5, {"code_group": CAGE_GROUP})
	prop_box(ct, "ContractorCart", Vector3(26.0, L.F41, 12.05), Vector3(0.8, 0.9, 0.5), 0.0, "cart", true, "prop")
	prefab(ct, "code_note", "CodeNote", Vector3(26.0, L.F41 + 0.9, 12.05), 0.0, {"code_group": CAGE_GROUP,
		"objective_tag": &"cage_code"}, Vector3(26.0, L.F41, 11.4))


## Guards: the reception post is fixed (Spawns); rovers (guard_post) and extras (guard_extra).
func _variants_guards(variants: Node3D) -> void:
	var gp: Node3D = _group(variants, "guard_post")
	var r1: VariantSlot = _slot(gp, "guard_post", "rover_l41", 1.0)
	spawn(r1, "GuardRoverL41", "GUARD", Vector3(15.0, L.F41, 17.25), 90.0, ["guard_rover_l41"], "", "Tower")
	var r2: VariantSlot = _slot(gp, "guard_post", "rover_l42", 1.0)
	spawn(r2, "GuardRoverL42", "GUARD", Vector3(22.0, L.F42, 5.5), 90.0, ["guard_rover_l42"], "", "Tower")
	var ge: Node3D = _group(variants, "guard_extra")
	var sw: VariantSlot = _slot(ge, "guard_extra", "stair_watch", 1.0)
	spawn(sw, "GuardStairWatch", "GUARD", Vector3(13.2, L.F41, 15.8), 0.0, ["guard_stair"], "", "Tower")
	var rw: VariantSlot = _slot(ge, "guard_extra", "roof_watch", 1.0)
	spawn(rw, "GuardRoofWatch", "GUARD", Vector3(19.5, L.FRF, 6.5), 90.0, ["guard_roof"], "", "Roof")
	_slot(ge, "guard_extra", "extra_none", 2.0)


## Cameras (C1-C12 in three layouts) and the staffed security room.
func _variants_security(variants: Node3D) -> void:
	var cg: Node3D = _group(variants, "camera")
	for s: Array in L.CAMERA_SETS:
		var slot: VariantSlot = _slot(cg, "camera", String(s[0]), 1.0)
		for cid: Variant in s[1]:
			security_camera(slot, String(cid))
	var sr: Node3D = _group(variants, "security_room_staffed")
	_slot(sr, "security_room_staffed", "sec_staffed", 0.6,
		{"operator_spawn": "Spawns/CameraOperatorSeat", "station": "Gameplay/Misc/CameraStation"})
	_slot(sr, "security_room_staffed", "sec_empty", 0.4)


## M3 art-hall laser plane at x 26.5 across the full room width, carried by two emitter columns
## (a prop root, so the raised static grid rests on a support). lz_static: 3 beams at 1.27 / 1.8 /
## 2.33 m (grid y 1.0-2.6; the placeholder posts are 2 m tall from the grid origin, so the origin
## cannot go above 1.0 under the 3.0 m ceiling): crouch under (meta crouch_under = true and
## bypass = false: the QC-29 vertical-gap check instead of a side gap). lz_sweep: 3 vertical beams, 6 s. lz_timed: 4 beams,
## off 4 s of every 16 s.
func _variants_lasers(variants: Node3D) -> void:
	var lg: Node3D = _group(variants, "laser_pattern")
	var span: float = L.LASER_Z.y - L.LASER_Z.x
	var mid: float = (L.LASER_Z.x + L.LASER_Z.y) * 0.5
	var rows: Array = [
		["lz_static", 0.5, 1.0, {"pattern": &"static", "size_m": Vector3(span - 0.4, 1.6, 0.1), "beam_count": 3}],
		["lz_sweep", 0.2, 0.0, {"pattern": &"sweeping", "size_m": Vector3(span - 0.4, 2.6, 0.1), "sweep_beams": 3,
			"period_s": 6.0}],
		["lz_timed", 0.3, 0.0, {"pattern": &"timed_off", "size_m": Vector3(span - 0.4, 2.6, 0.1), "beam_count": 4,
			"period_s": 16.0, "off_s": 4.0}],
	]
	for r: Array in rows:
		var s: VariantSlot = _slot(lg, "laser_pattern", String(r[0]), float(r[1]))
		var em: StaticBody3D = _emitters(s, Vector3(L.LASER_X, L.F42, mid), span)
		var props: Dictionary = (r[3] as Dictionary).duplicate()
		props["objective_tag"] = &"art_hall_lasers"
		props["visual_scene"] = _catalog_scene(String(LASER_BEAMS[String(r[0])]))  # SL-2: beams only, no posts
		var metas: Dictionary = {"kind": "laser_grid"}
		if String(r[0]) == "lz_static":
			metas["bypass"] = false
			metas["crouch_under"] = true
		prefab(em, "laser_grid", "ArtHallLasers", Vector3(L.LASER_X, L.F42 + float(r[2]), mid), 90.0, props, null, metas)


## Laser emitter columns (one prop root, yaw 90: local x runs along the room's z) at both ends of
## the laser span, 2.7 m. SL-2: each column is the catalog prop_laser_emitter_column (its lens face, +X, turned to
## the other column) over the root's 0.15 x 2.7 x 0.12 collider.
func _emitters(parent: Node3D, base: Vector3, span: float) -> StaticBody3D:
	var em: StaticBody3D = StaticBody3D.new()
	em.name = "LaserEmitters"
	em.collision_layer = 1
	em.collision_mask = 0
	em.position = base
	em.basis = yaw_basis(90.0)
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
		var column: Node3D = _catalog_scene(LASER_COLUMN).instantiate() as Node3D
		column.name = "Column%d" % i
		column.transform = Transform3D(yaw_basis(0.0 if i == 0 else 180.0), Vector3(x, 0.0, 0.0))
		add(em, column)
		obstruct(em.transform, AABB(Vector3(x - 0.075, 0.0, -0.06), Vector3(0.15, 2.7, 0.12)))
	return em


## Services riser panels: the loose panel is open (slot nav link roof <-> that floor's J); the
## other panels are bolted from inside (a panel box in the slot). vent_sealed: both bolted.
func _variants_vent(variants: Node3D) -> void:
	var vg: Node3D = _group(variants, "vent_open")
	var r: Dictionary = L.RISER
	var p: Array = r["panel"]
	var rows: Array = [["vent_l42", 0.35, [L.F41]], ["vent_l41", 0.35, [L.F42]], ["vent_sealed", 0.3, [L.F41, L.F42]]]
	for row: Array in rows:
		var s: VariantSlot = _slot(vg, "vent_open", String(row[0]), float(row[1]))
		for fy: Variant in row[2]:
			var tag: String = "L41" if float(fy) < 5.0 else "L42"
			prop_box(s, "BoltedPanel" + tag, Vector3((float(p[0]) + float(p[1])) * 0.5, float(fy), 9.0),
				Vector3(float(p[1]) - float(p[0]) - 0.004, 2.0, 0.08), 0.0, "riser_panel", false, "trim")
		if String(row[0]) != "vent_sealed":
			var fy2: float = L.F42 if String(row[0]) == "vent_l42" else L.F41
			nav_link(s, "RiserLink", Vector3(13.0, L.FRF, 9.8), Vector3(13.4, fy2, 9.7))


## Window-washer gondola: a hung cradle (deck + rails), its boarding ladder and gate, and the nav
## link roof <-> room; the closed boarding gates of the stops without a cradle.
func _variants_gondola(variants: Node3D) -> void:
	var gg: Node3D = _group(variants, "gondola")
	var weights: Dictionary = {"gon_west_l41": 0.3, "gon_north_l42": 0.3, "gon_stowed": 0.4}
	for sid: String in ["gon_west_l41", "gon_north_l42", "gon_stowed"]:
		var s: VariantSlot = _slot(gg, "gondola", sid, float(weights[sid]))
		for gid: String in L.GONDOLAS:
			var g: Dictionary = L.GONDOLAS[gid]
			if gid == sid:
				_cradle(s, g, String(LADDER_GONDOLA[gid]))
			else:
				_closed_gate(s, "ClosedGate" + ("West" if gid.contains("west") else "North"), g["gate"])


func _cradle(s: Node3D, g: Dictionary, ladder_visual: String) -> void:
	var d: Array = g["deck"]
	var mn: Vector3 = v3(d, 0)
	var mx: Vector3 = v3(d, 3)
	var size: Vector3 = mx - mn
	var along_x: bool = size.x > size.z
	# Hung from the BMU: a wall-mounted prop whose pivot is on the facade face (+Z = the facade).
	var length: float = size.x if along_x else size.z
	var depth: float = size.z if along_x else size.x
	var gap: float = 0.05
	var deck: StaticBody3D = StaticBody3D.new()
	deck.name = "CradleDeck"
	deck.collision_layer = 1
	deck.collision_mask = 0
	deck.position = Vector3((mn.x + mx.x) * 0.5, mn.y, mx.z + gap) if along_x else Vector3(mx.x + gap, mn.y, (mn.z + mx.z) * 0.5)
	deck.basis = yaw_basis(0.0 if along_x else 90.0)
	deck.set_meta(&"kind", "gondola_cradle")
	deck.set_meta(&"mount", "wall")
	deck.set_meta(&"support", true)
	add(s, deck)
	var h: float = length * 0.5
	var z0: float = -gap - depth
	var z1: float = -gap
	var parts: Array = [
		["Deck", Vector3(-h, 0.0, z0), Vector3(h, size.y, z1)],
		["RailOuter", Vector3(-h, size.y, z0), Vector3(h, size.y + 1.1, z0 + 0.05)],
		["RailEndA", Vector3(-h, size.y, z0 + 0.05), Vector3(-h + 0.05, size.y + 1.1, z1)],
		["RailEndB", Vector3(h - 0.05, size.y, z0 + 0.05), Vector3(h, size.y + 1.1, z1)],
	]
	for p: Array in parts:
		var pmn: Vector3 = p[1]
		var pmx: Vector3 = p[2]
		var col: CollisionShape3D = CollisionShape3D.new()
		col.name = String(p[0]) + "Collision"
		col.shape = box_shape(pmx - pmn)
		col.position = (pmn + pmx) * 0.5
		add(deck, col)
		mesh_box(deck, String(p[0]), pmn, pmx, "steel" if String(p[0]) == "Deck" else "fence")
	# Boarding ladder from the deck to the roof (Top 0.4 m along +Z, over the open gate).
	prefab(s, "ladder", "BoardingLadder", g["ladder"], float(g["ladder_yaw"]), {"height_m": float(g["ladder_h"]),
		"visual_scene": _catalog_scene(ladder_visual)}, null, {"kind": "ladder"})
	var link: Array = g["link"]
	nav_link(s, "GondolaLink", link[0], link[1])


## Closed BMU boarding gate (fills the parapet gap; 1.1 m).
func _closed_gate(s: Node3D, nm: String, gate: Array) -> void:
	var axis: String = String(gate[0])
	var fixed: float = float(gate[1])
	var a0: float = float(gate[2]) + 0.002
	var a1: float = float(gate[3]) - 0.002
	var base: Vector3 = Vector3((a0 + a1) * 0.5, L.FRF, fixed) if axis == "x" else Vector3(fixed, L.FRF, (a0 + a1) * 0.5)
	var size: Vector3 = Vector3(a1 - a0, 1.1, 0.06) if axis == "x" else Vector3(0.06, 1.1, a1 - a0)
	prop_box(s, nm, base, size, 0.0, "gate", false, "fence")


## Escapes: heli pad (E1, SECURE net from the start, heli lands 45 s after the required loot), the E2
## bag line (zipline to Vantage House; SECURE at the anchor, see the G1 report), the service lift (E3).
func _variants_escape(variants: Node3D) -> void:
	var esc: Node3D = _group(variants, "escape")
	var e1: VariantSlot = _slot(esc, "escape", "esc_heli", 0.4, {"label": "E1"})
	prefab(e1, "secure_zone", "HeliNetE1", Vector3(28.0, L.FRF, 9.8), 0.0,
		{"objective_tag": &"loot_secure", "vehicle_collision": false,
			"zone_size_m": Vector3(5.6, 2.5, 5.6), "visual_scene": _catalog_scene(SECURE_NET_VISUAL)},
		null, {"kind": "cargo_net"}, false)
	prefab(e1, "escape_zone", "HeliEscapeE1", Vector3(33.0, L.FRF, 8.0), 0.0,
		{"objective_tag": &"escape_heli", "escape_type": &"heli", "zone_size_m": Vector3(3.6, 3.0, 6.0),
			"arrival_delay_s": HELI_DELAY_S, "visual_scene": load(ESCAPE_HELI_VISUAL)})
	var e2: VariantSlot = _slot(esc, "escape", "esc_line", 0.35, {"label": "E2"})
	_bag_line(e2)
	prefab(e2, "secure_zone", "LineSecureE2", Vector3(33.9, L.FRF, 16.6), 0.0,
		{"objective_tag": &"loot_secure", "vehicle_collision": false,
			"zone_size_m": Vector3(2.0, 2.5, 2.0), "visual_scene": _catalog_scene(SECURE_TARP_VISUAL)},
		null, {"kind": "drop_tarp"}, false)
	prefab(e2, "escape_zone", "LineEscapeE2", Vector3(31.3, L.FRF, 16.6), 0.0,
		{"objective_tag": &"escape_line", "escape_type": &"zipline", "zone_size_m": Vector3(2.8, 3.0, 2.0),
			"visual_scene": load(ESCAPE_LINE_VISUAL)})
	var e3: VariantSlot = _slot(esc, "escape", "esc_service", 0.25, {"label": "E3"})
	# The car itself is the drop (freight blankets spread on its floor mark it); ESCAPE covers the car floor.
	# SL-P1: SECURE covers the whole 2.7 m car floor (walls at x 21.15 / z 7.65 / 10.35, the opening x 23.85), 5 mm
	# inside each wall: a bag thrown against a car wall rests with its centre a half bag inside, so it counts.
	prefab(e3, "secure_zone", "LiftSecureE3", Vector3(22.5, L.F40, 9.0), 0.0,
		{"objective_tag": &"loot_secure", "vehicle_collision": false,
			"zone_size_m": Vector3(2.69, 2.4, 2.69), "visual_scene": _catalog_scene(SECURE_LIFT_VISUAL)},
		null, {"kind": "drop_blanket", "inside": "LiftEscapeE3"}, false)  # levelcheck: inside the car's fit-out
	prefab(e3, "escape_zone", "LiftEscapeE3", Vector3(22.5, L.F40, 9.0), 0.0,
		{"objective_tag": &"escape_service", "escape_type": &"lift", "zone_size_m": Vector3(8.8, 2.4, 4.8),
			"zone_offset": Vector3(3.0, 0.0, 1.0), "visual_scene": load(ESCAPE_LIFT_VISUAL)})  # SL-7: car + lobby, one zone


## E2 bag line (zipline to Vantage House): the anchor on the E2AnchorFrame's east face (the frame is a layout prop
## row; its east face and centre z place the anchor), the Interactable BAG_DROP under the sheave and just east of the
## frame (reached round its south side from the UsePoint), the far end, and the drawn cable from the anchor's `Line`
## to the far end raised by BAG_DROP (the bags hang that far under it all the way).
func _bag_line(e2: Node3D) -> void:
	var frame: Array = []
	for p: Array in L.PROPS:
		if String(p[0]) == ANCHOR_FRAME:
			frame = p
	if frame.is_empty():
		errors.append("E2 bag line: layout prop %s not found" % ANCHOR_FRAME)
		return
	var fb: Vector3 = frame[1]
	var fs: Vector3 = frame[2]
	var pivot: Vector3 = Vector3(fb.x + fs.x * 0.5, L.FRF + ANCHOR_Y, fb.z)
	var zl: Node3D = prefab(e2, "zipline", "BagLineE2", pivot, -90.0,
		{"objective_tag": &"bag_line", "visual_scene": _catalog_scene(ZIPLINE_ANCHOR)},
		Vector3(fb.x, L.FRF, fb.z + fs.z * 0.5 + 0.7), {"kind": "zipline_anchor", "mount": "wall"})
	if zl == null:
		return
	var line: Vector3 = Transform3D(yaw_basis(-90.0), pivot) * ANCHOR_LINE
	var start: Vector3 = line - Vector3(0.0, BAG_DROP, 0.0)
	var it: Node3D = zl.get_node(^"Interactable") as Node3D
	it.transform = Transform3D(Basis.IDENTITY, global_xform(zl).affine_inverse() * start)
	map_root.set_editable_instance(zl, true)
	var far: Marker3D = marker(e2, "LineEndVantage", L.E2_LINE_END)
	var cable_end: Marker3D = marker(e2, "LineCableVantage", L.E2_LINE_END + Vector3(0.0, BAG_DROP, 0.0))
	zl.set(&"end", zl.get_path_to(far))
	zl.set(&"cable_start", ANCHOR_LINE_PATH)
	zl.set(&"cable_end", zl.get_path_to(cable_end))


## PO6-06 / D-063: a seat an NPC spawns seated in (as DB's `npc_seat` chairs and GH / GN's prop_chair_task), with no
## collider and no nav obstruction, so the spawn on it stays on the navmesh and the seated NPC owns the spot. The seat
## centre (its `Seat` marker, xz) is `base`, the NPC's spawn. `asset` = a catalog seat (SL-3: the prop's own `Seat`,
## else one added at `seat` prop-local, the pivot then set back so that seat lands on `base`); "" = the greybox
## chair. Kessler's lives in his slot (absent when he is); the operator's in Gameplay/Misc. D-130: `pivot` = `base` is
## the chair's pivot instead (the chair stays on its layout spot; NpcSeatSpawns then moves the spawn onto its Seat).
func npc_seat(parent: Node3D, nm: String, base: Vector3, yaw: float, asset: String = "",
		seat: Vector3 = Vector3(0.0, 0.45, 0.0), pivot: bool = false) -> void:
	var ps: PackedScene = _catalog_scene(asset) if asset != "" else null
	var body: Node3D = ps.instantiate() as Node3D if ps != null else Node3D.new()
	body.name = nm
	body.basis = yaw_basis(yaw)
	var own: Node3D = body.find_child("Seat", true, false) as Node3D
	var local: Vector3 = seat
	if own != null:
		local = own.transform.origin
		var p: Node = own.get_parent()
		while p != body and p is Node3D:
			local = (p as Node3D).transform * local
			p = p.get_parent()
	body.position = base if pivot else base - body.basis * Vector3(local.x, 0.0, local.z)
	if ps == null:
		body.set_meta(&"kind", "armchair")
	add(parent, body)
	if ps == null:
		mesh_box(body, "SeatMesh", Vector3(-0.225, 0.0, -0.225), Vector3(0.225, 0.45, 0.225), "chair")
		mesh_box(body, "BackMesh", Vector3(-0.225, 0.45, 0.165), Vector3(0.225, 0.85, 0.225), "chair")
	if own == null:
		var m: Marker3D = Marker3D.new()
		m.name = "Seat"
		m.position = seat
		add(body, m)
