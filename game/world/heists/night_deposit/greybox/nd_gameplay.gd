## Night Deposit generator: gameplay prefabs (Gameplay) and variant slots (Variants). Owner: ENV C (C2).
## Chain: nd_builder_base.gd <- nd_gameplay.gd <- build_greybox.gd. Design: docs/design/heists/
## night_deposit.md (§Objectives, §Loot path, §Variable table); contracts: gameplay_prefabs.md v1.1,
## heist_map.md §5. Prefabs are found by contract class name (no path into ENV A's folder).
extends "res://world/heists/night_deposit/greybox/nd_builder_base.gd"

## Single time-lock code group: notes, the carried code, and the TL panel.
const CODE_GROUP: StringName = &"nd_time_lock"
## Generated visuals (nd_dress.make_visuals; library materials) for prefabs without catalog art.
const VIS_EMPTY: String = ART_DIR + "nd_empty.tscn"
const VIS_CASH_LIFT: String = ART_DIR + "nd_cash_lift.tscn"
const VIS_BOAT_HATCH: String = ART_DIR + "nd_boat_hatch.tscn"
## PO-13: escape_zone visuals. Van / boat escapes show the vehicle already parked or moored there (the slot's
## secure_zone van, the moored launch), so their visual only carries the contract nodes (no second vehicle).
const ESCAPE_VAN_MARKER: String = "res://world/heists/shared/escape_van_marker.tscn"
const ESCAPE_BOAT_MARKER: String = "res://world/heists/shared/escape_boat_marker.tscn"
const VIS_LASER: Dictionary = {
	"laser_static": ART_DIR + "nd_laser_static.tscn", "laser_sweep": ART_DIR + "nd_laser_sweep.tscn",
	"laser_timed": ART_DIR + "nd_laser_timed.tscn",
}
## Default visual per prefab type (catalog asset id or a generated scene path); doors, windows,
## lasers and loot choose theirs where they are built.
const PREFAB_VISUALS: Dictionary = {
	"safe": "prop_safe_large", "keycard_pickup": "prop_keycard_bank", "small_loot": "prop_cash_stack",
	"loot_spawn": "prop_cash_bags", "keypad": "prop_keypad", "alarm_button": "prop_alarm_button",
	"phone": "prop_phone_desk", "body_container": "prop_dumpster", "ladder": "prop_ladder_wall_h400",
	"camera_station": "prop_camera_station_bank", "security_camera": "prop_security_camera_wall",
	"code_note": "prop_papers", "drill_point": VIS_EMPTY, "secure_zone": "veh_van_secure",
	"hack_terminal": "prop_server_rack_terminal", "bag_lift": VIS_CASH_LIFT,
}
## ATM cash: a SAW drill_point (placed saw 20 s; DrillPoint is also a G.SAW_TARGET for the handheld saw,
## QC-37). The depository safe has &"saw" in its methods (Safe.saw_cut). Deposit boxes and the grate
## padlock are ENV A's deposit_box / padlock prefabs.
const SAW_ATM_S: float = 20.0
const CAMERA_POSITIONS: Dictionary = {
	# id: [pivot on the wall face, yaw (front -Z into the room)] (doc §Sightlines, 2.6-3.0 m).
	"C1": [Vector3(20.3, 2.8, 10.1), 180.0], "C2": [Vector3(0.6, 2.8, 19.8), 0.0],
	"C3": [Vector3(0.2, 2.6, 6.75), -90.0], "C4": [Vector3(3.5, 2.6, 5.9), 0.0],
	"C5": [Vector3(25.8, -1.4, 6.75), 90.0], "C6": [Vector3(9.1, -1.4, 8.8), -90.0],
	"C7": [Vector3(11.0, 3.0, -0.2), 0.0], "C8": [Vector3(25.0, -1.4, 7.6), 180.0],
}
const CAMERA_SETS: Array = [
	["cam_a", ["C1", "C3", "C5", "C6"]], ["cam_b", ["C2", "C4", "C5", "C7"]], ["cam_c", ["C1", "C4", "C6", "C8"]],
]


# --- Prefab helpers ---------------------------------------------------------------------------

## Instances a prefab under `parent` (all containers sit at the identity, so `pos` is world space
## unless `parent` is a prop). props: export -> value ("enum:KEY" looks the key up in the prefab
## script's enums). use_point: world floor point for the UsePoint (items on furniture) or null.
func prefab(parent: Node3D, kind: String, nm: String, pos: Vector3, yaw: float, props: Dictionary = {},
		use_point: Variant = null, metas: Dictionary = {}, obstruct_body: bool = true) -> Node3D:
	var ps: PackedScene = prefab_scene(kind)
	if ps == null:
		return null
	var inst: Node3D = ps.instantiate() as Node3D
	inst.name = nm
	inst.position = pos
	inst.basis = yaw_basis(yaw)
	for k: Variant in props:
		_set_prop(inst, String(k), props[k])
	if not props.has("visual_scene") and PREFAB_VISUALS.has(kind):
		inst.set(&"visual_scene", _visual(String(PREFAB_VISUALS[kind])))
	for mk: Variant in metas:
		inst.set_meta(StringName(String(mk)), metas[mk])
	if not inst.has_meta(&"kind"):
		inst.set_meta(&"kind", kind)
	parent.add_child(inst)
	inst.owner = map_root
	if use_point != null:
		place_use_point(inst, use_point as Vector3)
	if obstruct_body and kind in ["safe", "body_container", "secure_zone", "camera_station", "hack_terminal"]:
		_obstruct_prefab(inst)
	return inst


## A catalog asset id or a generated scene path -> PackedScene.
func _visual(id: String) -> PackedScene:
	if id.begins_with("res://"):
		return load(id) as PackedScene
	return catalog_scene(id)


## Catalog prop placed by the generator (variant content, the armoured car): instance + box collider
## from the catalog bounds + navmesh obstruction; metas kind etc.
func catalog_prop(parent: Node3D, nm: String, asset: String, pos: Vector3, yaw: float, metas: Dictionary = {}) -> Node3D:
	var ps: PackedScene = catalog_scene(asset)
	if ps == null:
		return null
	var n: Node3D = ps.instantiate() as Node3D
	n.name = nm
	n.position = pos
	n.basis = yaw_basis(yaw)
	for k: Variant in metas:
		n.set_meta(StringName(String(k)), metas[k])
	add(parent, n)
	var bb: AABB = dress.aabb(asset)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	add(n, body)
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.name = "Shape"
	cs.shape = box_shape(bb.size)
	cs.position = bb.get_center()
	add(body, cs)
	obstruct(n.transform, bb)
	return n


## Moves a prefab's UsePoint to a world floor point, -Z facing the object (Editable Children).
func place_use_point(inst: Node3D, world: Vector3) -> void:
	var up: Node3D = inst.get_node_or_null("UsePoint") as Node3D
	if up == null:
		errors.append("%s has no UsePoint" % inst.name)
		return
	var xf: Transform3D = global_xform(inst)
	var to_obj: Vector3 = xf.origin - world
	to_obj.y = 0.0
	var g: Transform3D = Transform3D(Basis.looking_at(to_obj.normalized(), Vector3.UP), world)
	up.transform = xf.affine_inverse() * g
	map_root.set_editable_instance(inst, true)


func global_xform(c: Node3D) -> Transform3D:
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


## Wall-mounted security camera. ENV A's prefab keeps its fitted hitbox on the room side of the pivot
## (A3-07); the earlier 0.03 m Editable Children workaround was removed by the lead.
func security_camera(parent: Node3D, cid: String, fov: float = 60.0, rng: float = 20.0) -> Node3D:
	var row: Array = CAMERA_POSITIONS[cid]
	var cam: Node3D = prefab(parent, "security_camera", "Camera" + cid, row[0], float(row[1]),
		{"fov_deg": fov, "range_m": rng, "pan_deg": 40.0}, null,
		{"mount": "wall", "kind": "security_camera", "camera_id": cid})
	return cam


# --- Gameplay ---------------------------------------------------------------------------------

func build_gameplay(gp: Node3D) -> void:
	_build_doors(gp)
	_build_windows(gp)
	_build_vault(gp)
	_build_depository(gp)
	_build_misc(gp)


func _build_doors(gp: Node3D) -> void:
	var doors: Node3D = add(gp, node3d("Doors")) as Node3D
	for d: Array in L.DOORS:
		var vis: PackedScene = catalog_scene(String(d[1]))
		var props: Dictionary = {"lock": "enum:" + String(d[4]), "swing": "enum:" + String(d[5]), "visual_scene": vis}
		if String(d[6]) != "":
			props["objective_tag"] = StringName(String(d[6]))
		var metas: Dictionary = {"kind": "vault_door" if String(d[1]).contains("vault") else "door", "swing_side": "back"}
		var extra: Dictionary = d[7]
		if bool(extra.get("service", false)):
			metas["service"] = true
		if bool(extra.get("fire_exit", false)):
			metas["fire_exit"] = true
		if bool(extra.get("suspicious_when_open", false)):
			props["suspicious_when_open"] = true
		if bool(extra.get("public", false)):
			props["casing_allowed"] = true  # public-facing: openable unmasked while casing (PD2)
		if bool(extra.get("npc_auth", false)):
			props["npc_authorized_tags"] = _names(L.STAFF_TAGS)
		if String(d[1]).contains("service"):
			props["width_m"] = 1.1
		if extra.has("width_m"):
			props["width_m"] = float(extra["width_m"])
		prefab(doors, "door", String(d[0]), d[2], float(d[3]), props, null, metas)


## Hall window bays (breakable; police ENTRY). The prefab's GlassBody is a fixed 1.0 x 1.2 panel, so
## a full-size glass blocker sits in Geometry/Building/Glazing (Glasshouse G1 convention).
func _build_windows(gp: Node3D) -> void:
	var wins: Node3D = add(gp, node3d("Windows")) as Node3D
	var gl: Node3D = n("Geometry/Building/Glazing")
	for w: Array in L.WINDOWS:
		var pos: Vector3 = w[2]
		var yaw: float = float(w[3])
		var front: Vector3 = yaw_basis(yaw) * Vector3.FORWARD
		prefab(wins, "window", String(w[0]), pos, yaw,
			{"breakable": true, "openable": false, "visual_scene": catalog_scene(String(w[1])), "objective_tag": &"hall_window"},
			Vector3(pos.x, 0.0, pos.z) + front * 0.7, {"kind": "window"})
		var blocker: Node3D = box(gl, String(w[0]) + "Blocker", Vector3(pos.x - 1.5, pos.y, pos.z - 0.02),
			Vector3(pos.x + 1.5, pos.y + 2.4, pos.z + 0.02), "")
		blocker.add_to_group(&"see_through", true)  # D-142: clear glass (with the prefab's GlassBody)


## Vault: round door (VAULT lock, 2.2 m; prop_vault_door_round), the thermal drill point (loud), the
## time-lock panel (keypad, code group nd_time_lock) behind the laser plane, cage cash, the Co-op
## pallet and the safe-deposit box walls (catalog units anchored by the dressing; one deposit_box
## prefab per unit at SAW_Y, QC-37).
func _build_vault(gp: Node3D) -> void:
	var v: Node3D = add(gp, node3d("Vault")) as Node3D
	var door: Node3D = n("Gameplay/Doors/VaultDoor")
	if door != null:
		# Drill on the antechamber side: -Z into the lock (south), on the wheel's face; UsePoint north.
		prefab(door, "drill_point", "VaultDrill", Vector3(0.6, 1.0, -0.035), 180.0,  # PO: the lance touches the leaf
			{"device": "enum:THERMAL", "target": NodePath(".."), "loud_only": true, "objective_tag": &"vault_drill"},
			Vector3(14.6, L.BASE, 9.0))
	prefab(v, "keypad", "TimeLockPanel", Vector3(18.9, L.BASE + 1.2, 9.1), 90.0,
		{"code_group": CODE_GROUP, "stealth_only": true, "objective_tag": &"time_lock"}, null,
		{"mount": "wall", "kind": "keypad"})
	prefab(v, "loot_spawn", "CageCash", Vector3(14.0, L.BASE, 15.4), 0.0,
		{"loot_id": &"loot.cash", "count": 4, "objective_tag": &"vault_loot"})
	# Co-op pallet of cash bricks (the loot_spawn stack stands for the pallet; markers sit on the floor).
	prefab(v, "loot_spawn", "CoopCashBricks", Vector3(14.0, L.BASE, 18.7), 0.0,
		{"loot_id": &"loot.cash_bricks", "count": 3, "objective_tag": &"vault_loot", "visual_scene": catalog_scene("prop_cash_pallet")})
	# Safe-deposit boxes: 4 units a side, one sawable box door per unit (ENV A `deposit_box`, QC-37: small
	# loot locked until the handheld saw cuts it, InteractionTweak.hand_saw_deposit_box_s; the mission
	# keeps the first `deposit_boxes`). The unit dressing (prop_deposit_boxes) is the visual.
	var idx: int = 0
	for side: Array in [["W", DD.BOX_FRONT_W, 90.0, 1.0, 0.145], ["E", DD.BOX_FRONT_E, -90.0, -1.0, -0.145]]:
		var dirx: float = float(side[3])
		for uz: float in DD.BOX_UNITS_Z:
			idx += 1
			var z: float = uz + float(side[4])
			var fx: float = float(side[1])
			prefab(v, "deposit_box", "Box%d" % idx, Vector3(fx + dirx * 0.01, L.BASE + DD.SAW_Y, z), float(side[2]),
				{"loot_id": &"loot.small_valuables", "value": 750, "objective_tag": &"deposit_box",
					"visual_scene": load(VIS_EMPTY)}, Vector3(fx + dirx * 0.85, L.BASE, z))


## B12 night depository safe (MEDIUM: saw 120 s or drill); the chute drops into it. The night-drop
## bags (count = scalar `depository_bags`, set by the mission) are enabled when it opens.
func _build_depository(gp: Node3D) -> void:
	var dp: Node3D = add(gp, node3d("Depository")) as Node3D
	var safe: Node3D = prefab(dp, "safe", "DepositorySafe", Vector3(21.47, L.BASE, 17.0), -90.0,
		{"size": "enum:MEDIUM", "methods": [&"saw", &"drill"] as Array[StringName], "objective_tag": &"depository"},
		null, {"kind": "safe"})
	# Night-drop bags (PO6-05): inside the safe at its LootAnchor (safe-local (0, 0.142, 0)), so the Safe hides them
	# until it opens; the UsePoint stays in front of the safe on the floor.
	if safe != null:
		prefab(safe, "loot_spawn", "NightDropBags", Vector3(0.0, 0.142, 0.0), 0.0,
			{"loot_id": &"loot.cash", "count": 4, "objective_tag": &"depository_loot",
				"visual_scene": catalog_scene("prop_night_drop_bags")}, Vector3(22.6, L.BASE, 18.3))
	# Chute from the G13 night drop down to the safe (Geometry, ceiling to the top of the safe body).
	box(n("Geometry/Building"), "DepositoryChute", Vector3(21.15, L.BASE + 1.395, 16.75), Vector3(21.55, L.BASE_CEIL, 17.25), "steel")


func _build_misc(gp: Node3D) -> void:
	var misc: Node3D = add(gp, node3d("Misc")) as Node3D
	# Teller drawers (small loot on the counter, workroom side).
	for i: int in range(3):
		var x: float = 4.0 + 5.0 * float(i)
		prefab(misc, "small_loot", "TellerDrawer%d" % (i + 1), Vector3(x, 1.05, 9.85), 0.0,
			{"loot_id": &"loot.cash", "value": 500}, Vector3(x, 0.0, 9.1))
	var station: Node3D = prefab(misc, "camera_station", "CameraStation", Vector3(10.51, 0.0, 2.5), -90.0,
		{}, null, {"kind": "camera_station"})
	if station != null:
		station.set(&"operator_spawn", station.get_path_to(map_root.get_node("Spawns/CameraOperatorSeat")))
	for a: Array in [["AlarmSecurity", Vector3(13.9, 1.2, 1.5), 90.0], ["AlarmManager", Vector3(22.0, 1.2, 12.1), 180.0],
			["AlarmTellers", Vector3(15.0, 1.2, 7.6), 180.0]]:
		prefab(misc, "alarm_button", String(a[0]), a[1], float(a[2]), {}, null, {"mount": "wall", "kind": "alarm_button"})
	prefab(misc, "phone", "PhoneManager", Vector3(23.45, 0.74, 14.55), 90.0, {}, Vector3(24.0, 0.0, 15.3))
	prefab(misc, "phone", "PhoneLoan", Vector3(23.85, 0.74, 9.35), 90.0, {}, Vector3(23.85, 0.0, 8.6))
	prefab(misc, "body_container", "Dumpster", Vector3(9.5, 0.0, -0.75), 0.0, {"capacity": 2}, null, {"kind": "dumpster"})
	var a2: Dictionary = L.AREAWAY
	prefab(misc, "ladder", "AreawayLadder", a2["ladder_pos"], float(a2["ladder_yaw"]), {"height_m": 4.0}, null,
		{"kind": "ladder"})
	_cash_lift(misc)
	_build_atms(gp)


## ATM saw targets (D-057, QC-37): a placed-saw drill point on each ATM's cash cassette door (front,
## G13 anchors in night_deposit_dressing.gd) bound to the cash inside (hidden small loot).
func _build_atms(gp: Node3D) -> void:
	var atm: Node3D = add(gp, node3d("Atms")) as Node3D
	var i: int = 0
	for a: Array in DD.ANCHORS:
		if String(a[2]) != "prop_atm":
			continue
		i += 1
		var p: Vector3 = a[3]
		var front_z: float = p.z + 0.36
		var use: Vector3 = Vector3(p.x, 0.0, front_z + 0.75)
		var loot: Node3D = prefab(atm, "small_loot", "AtmCash%d" % i, Vector3(p.x, 0.9, front_z + 0.05), 0.0,
			{"loot_id": &"loot.cash", "value": 1500, "objective_tag": &"atm_cash", "visual_scene": load(VIS_EMPTY)}, use)
		var drill: Node3D = prefab(atm, "drill_point", "AtmSaw%d" % i, Vector3(p.x - 0.12, 0.62, front_z + 0.02), 0.0,
			{"device": "enum:SAW", "duration_s": SAW_ATM_S, "objective_tag": &"atm", "ecm_atm": true}, use + Vector3(0.0, 0.0, 0.15))
		if drill != null and loot != null:
			drill.set(&"target", drill.get_path_to(loot))


## Cash lift (bag_lift, QC-11 / A3-09; doc §Loot path: bags only, 2 per cycle, 8 s). Landing 0 = G1
## (the prefab; the car waits by the sally door), landing 1 = B1 (`LandingBasement`, BASE below). Front
## -Z faces west through the shaft hatch (yaw 90). Generated visual `art/nd_cash_lift.tscn`: the car fits
## the 1.25 m shaft, `DoorL`/`DoorR` are empty anchors (0.6 m leaves sliding the 0.45 m tweak would
## pass through the shaft walls; the hatch is open), and `Panel` is an anchor too: the panels are
## shaft-wall dressing above each hatch (build_greybox.gd). The Interactable (focus point) sits on the G1
## panel; LandingPanel1 copies that offset to the B1 panel.
func _cash_lift(misc: Node3D) -> void:
	var car: Vector3 = L.LIFT["car"]
	var py: float = float(L.LIFT["panel_y"])
	var lift: Node3D = prefab(misc, "bag_lift", "CashLift", car, 90.0,
		{"travel_s": 8.0, "capacity": 2, "car_size_m": Vector3(1.1, 1.2, 1.05), "objective_tag": &"cash_lift"},
		Vector3(car.x - 1.3, 0.0, car.z), {}, false)
	if lift == null:
		return
	var it: Node3D = lift.get_node_or_null("Interactable") as Node3D
	if it != null:
		it.position = Vector3(0.0, py, -0.75)
	var m: Marker3D = Marker3D.new()
	m.name = "LandingBasement"
	m.position = Vector3(0.0, L.BASE, 0.0)
	add(lift, m)
	lift.set(&"targets", [lift.get_path_to(m)] as Array[NodePath])


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
	_variants_guards(variants)
	_variants_security(variants)
	_variants_code(variants)
	_variants_keycard(variants)
	_variants_server(variants)
	_variants_vent(variants)
	_variants_lasers(variants)
	_variants_loot_escape(variants)
	_variants_armored_car(variants)


func _variants_guards(variants: Node3D) -> void:
	var g: Node3D = _group(variants, "guard_post")
	var rg: VariantSlot = _slot(g, "guard_post", "rover_ground", 1.0)
	spawn(rg, "GuardRoverGround", "GUARD", Vector3(13.4, 0.0, 6.75), 90.0, ["guard_rover", "guard_rover_ground"], "", "Bank")
	var rb: VariantSlot = _slot(g, "guard_post", "rover_basement", 1.0)
	spawn(rb, "GuardRoverBasement", "GUARD", Vector3(5.0, L.BASE, 6.75), -90.0, ["guard_rover", "guard_rover_basement"], "",
		"Bank")
	var rx: VariantSlot = _slot(g, "guard_post", "rover_exterior", 1.0)
	spawn(rx, "GuardRoverExterior", "GUARD", Vector3(7.5, 0.0, -2.2), 0.0, ["guard_rover", "guard_rover_exterior"], "",
		"Exterior")
	# D-140 (PAGERS lever): exactly one rover on every seed and difficulty (pick 1, no empty slot, no difficulty_add).


## Cameras (doc C1-C8 in three sets), the staffed security room, and the two civilians.
func _variants_security(variants: Node3D) -> void:
	var cg: Node3D = _group(variants, "camera")
	for s: Array in CAMERA_SETS:
		var slot: VariantSlot = _slot(cg, "camera", String(s[0]), 1.0)
		for cid: Variant in s[1]:
			security_camera(slot, String(cid), 60.0, 25.0 if String(cid) in ["C1", "C2", "C7"] else 20.0)
	var sr: Node3D = _group(variants, "security_room_staffed")
	_slot(sr, "security_room_staffed", "sec_staffed", 0.6,
		{"operator_spawn": "Spawns/CameraOperatorSeat", "station": "Gameplay/Misc/CameraStation"})
	var se: VariantSlot = _slot(sr, "security_room_staffed", "sec_empty", 0.4)
	# D-140: an unstaffed room means the console officer is on his rounds (own graph `Rounds`), so the room always
	# holds one pager: 2 posts + 1 rover + the operator or the roundsman = 4 guards on every seed.
	spawn(se, "GuardRounds", "GUARD", Vector3(12.8, 0.0, 2.0), 90.0, ["guard_rover", "guard_rounds"], "", "Rounds")
	var nm: Node3D = _group(variants, "night_manager")
	var mi: VariantSlot = _slot(nm, "night_manager", "mgr_in", 0.5)
	# D-063: seated at the desk (prop_chair_task NPC seat, 0.47 m; desk 0.74 m)
	spawn(mi, "NightManager", "CIVILIAN", Vector3(24.55, 0.0, 13.95), 90.0, ["civ_manager", "civ_staff"], "desk_work", "")
	_slot(nm, "night_manager", "mgr_out", 0.5)
	var cl: Node3D = _group(variants, "cleaner")
	var cgr: VariantSlot = _slot(cl, "cleaner", "cleaner_ground", 0.4)
	spawn(cgr, "Cleaner", "CIVILIAN", Vector3(13.0, 0.0, 16.4), 90.0, ["civ_cleaner", "civ_staff"], "browse", "")
	var cbs: VariantSlot = _slot(cl, "cleaner", "cleaner_basement", 0.3)
	spawn(cbs, "Cleaner", "CIVILIAN", Vector3(20.6, L.BASE, 6.75), 90.0, ["civ_cleaner", "civ_staff"], "browse", "")
	_slot(cl, "cleaner", "cleaner_none", 0.3)


## Time-lock code (doc `code_note` row, pick 1 at 1/1/1/1.5): one written note, or the night manager
## carries it (`code_on_manager`, eligible only with `mgr_in` via the rule's slot_requires).
func _variants_code(variants: Node3D) -> void:
	var cn: Node3D = _group(variants, "code_note")
	var om: VariantSlot = _slot(cn, "code_note", "code_on_manager", 1.5, {"code_group": CODE_GROUP})
	var m: Marker3D = Marker3D.new()
	m.name = "ManagerCarriesCode"
	m.position = Vector3(24.55, 0.0, 13.95)
	m.set_meta(&"code_group", CODE_GROUP)
	add(om, m)
	var notes: Array = [
		["code_manager_planner", Vector3(23.75, 0.74, 13.35), Vector3(23.6, 0.0, 12.6)],
		["code_break_board", Vector3(14.8, 0.9, 0.55), Vector3(14.8, 0.0, 1.3)],
		["code_records_ledger", Vector3(0.55, L.BASE + 0.74, 16.05), Vector3(1.35, L.BASE, 16.5)],
	]
	for row: Array in notes:
		var slot: VariantSlot = _slot(cn, "code_note", String(row[0]), 1.0, {"code_group": CODE_GROUP})
		prefab(slot, "code_note", "CodeNote", row[1], 0.0, {"code_group": CODE_GROUP, "objective_tag": &"code_note"}, row[2])


func _variants_keycard(variants: Node3D) -> void:
	var kc: Node3D = _group(variants, "keycard")
	var rows: Array = [
		["kc_manager_desk", 1.0, Vector3(23.5, 0.74, 13.3), Vector3(23.6, 0.0, 12.6)],
		["kc_teller_drawer", 1.0, Vector3(6.0, 1.05, 9.85), Vector3(6.0, 0.0, 9.1)],
		# on the kitchen worktop (top face y 0.908; locker face is flush, PP-C-2)
		["kc_break_locker", 1.0, Vector3(15.85, 0.908, 0.7), Vector3(15.85, 0.0, 1.45)],
		["kc_security", 0.75, Vector3(13.55, 0.75, 4.1), Vector3(12.95, 0.0, 4.1)],
		["kc_records", 1.0, Vector3(0.5, L.BASE + 0.74, 15.1), Vector3(1.35, L.BASE, 14.75)],
	]
	for r: Array in rows:
		var s: VariantSlot = _slot(kc, "keycard", String(r[0]), float(r[1]))
		prefab(s, "keycard_pickup", "Keycard", r[2], 0.0, {"objective_tag": &"keycard"}, r[3])


## Server room (code-free alternative): the hack_terminal rack (QC-12, A3-09; node `HackTerminal`,
## objective_tag `server_hack`) against the north wall. Doc §Objectives: 3 x 20 s with 2 random reboot
## interruptions = duration_s 60, interruptions (2, 2) (rolled on GameRng &"devices", restart by
## re-interacting). Stealth only: the mission also disables it on the loud lockdown.
func _variants_server(variants: Node3D) -> void:
	var sg: Node3D = _group(variants, "server_room")
	var rows: Array = [["srv_basement", 0.6, Vector3(24.0, L.BASE, 0.72)], ["srv_ground", 0.4, Vector3(24.0, 0.0, 0.72)]]
	for r: Array in rows:
		var s: VariantSlot = _slot(sg, "server_room", String(r[0]), float(r[1]))
		if String(r[0]) == "srv_ground":
			catalog_prop(s, "ServerRackG6", "prop_server_rack", Vector3(25.288, 0.0, 1.5), 90.0, {"kind": "server_rack"})
		prefab(s, "hack_terminal", "HackTerminal", r[2], 180.0,
			{"duration_s": 60.0, "interruptions": Vector2i(2, 2), "stealth_only": true, "objective_tag": &"server_hack"},
			null, {"kind": "hack_terminal"})


## Areaway grate gate: unlocked (3 s, silent) or padlocked (the padlock prefab: lockpick 8 s or saw).
func _variants_vent(variants: Node3D) -> void:
	var vg: Node3D = _group(variants, "vent_open")
	var a: Dictionary = L.AREAWAY
	# vent_locked: the grate is BARRED and only its padlock (lockpick 8 s / saw) opens it.
	for r: Array in [["vent_open", "NONE", 3.0], ["vent_locked", "BARRED", -1.0]]:
		var s: VariantSlot = _slot(vg, "vent_open", String(r[0]), 0.5)
		var gate: Node3D = prefab(s, "door", "AreawayGrate", a["gate_pos"], float(a["gate_yaw"]),
			{"lock": "enum:" + String(r[1]), "swing": "enum:INWARD", "interaction_time_s": float(r[2]),
				"visual_scene": catalog_scene("prop_door_single_steel_t10"), "objective_tag": &"areaway_grate"},
			null, {"kind": "door", "swing_side": "back"})
		if gate != null and String(r[0]) == "vent_locked":
			_padlock(gate)


## Padlock on the locked areaway grate (lot side, the door's front): ENV A's `padlock` prefab (QC-37):
## lockpick 8 s (doc vent_locked) or the handheld saw (InteractionTweak.hand_saw_padlock_s); it unlocks
## and opens the BARRED grate (DrillPoint.open_target).
func _padlock(gate: Node3D) -> void:
	var o: Vector3 = gate.position
	var b: Basis = gate.basis
	var use: Vector3 = o + b * Vector3(0.38, 0.0, -0.9)
	use.y = o.y
	prefab(gate, "padlock", "Padlock", Vector3(0.38, 1.0, -0.07), 180.0,
		{"targets": [NodePath("..")] as Array[NodePath], "interaction_time_s": 8.0, "objective_tag": &"padlock",
			"visual_scene": catalog_scene("prop_padlock_brass")}, use, {"mount": "door"})


## Antechamber laser grid across B8 (z 8.5) in front of the TL panel and the vault door.
func _variants_lasers(variants: Node3D) -> void:
	var lg: Node3D = _group(variants, "laser_pattern")
	var rows: Array = [
		# static: a bypass gap at the west end (x 9.1-10.05, 0.95 m clear; D-048 needs >= 0.8 m) beside the wall.
		["laser_static", 0.5, Vector3(14.475, L.BASE, 8.5), {"pattern": &"static", "size_m": Vector3(8.85, 2.0, 0.1),
			"beam_count": 4}],
		["laser_sweep", 0.2, Vector3(14.0, L.BASE, 8.5), {"pattern": &"sweeping", "size_m": Vector3(9.8, 2.2, 0.1),
			"sweep_beams": 2, "period_s": 6.0}],
		["laser_timed", 0.3, Vector3(14.0, L.BASE, 8.5), {"pattern": &"timed_off", "size_m": Vector3(9.8, 2.0, 0.1),
			"beam_count": 4, "period_s": 20.0, "off_s": 6.0}],
	]
	for r: Array in rows:
		var s: VariantSlot = _slot(lg, "laser_pattern", String(r[0]), float(r[1]))
		var props: Dictionary = (r[3] as Dictionary).duplicate()
		props["objective_tag"] = &"antechamber_lasers"
		props["visual_scene"] = load(String(VIS_LASER[String(r[0])]))
		prefab(s, "laser_grid", "AntechamberLasers", r[2], 0.0, props, null, {"kind": "laser_grid"})


func _variants_loot_escape(variants: Node3D) -> void:
	var xl: Node3D = _group(variants, "extra_loot")
	for r: Array in [["mgr_safe_full", 4], ["mgr_safe_empty", 0]]:
		var s: VariantSlot = _slot(xl, "extra_loot", String(r[0]), 0.5)
		var safe: Node3D = prefab(s, "safe", "ManagerSafe", Vector3(25.44, 0.0, 15.3), 90.0,
			{"size": "enum:SMALL", "methods": [&"lockpick", &"drill"] as Array[StringName], "objective_tag": &"manager_safe"},
			null, {"kind": "safe"})
		if safe == null:
			continue
		for i: int in range(int(r[1])):
			prefab(safe, "small_loot", "SafeCash%d" % (i + 1), Vector3(-0.24 + 0.16 * float(i), 0.25, 0.0), 0.0,
				{"loot_id": &"loot.cash", "value": 1000, "visual_scene": load(VIS_EMPTY)},
				Vector3(24.4, 0.0, 15.3 - 0.24 + 0.16 * float(i)))
	var esc: Node3D = _group(variants, "escape")
	var e1: VariantSlot = _slot(esc, "escape", "esc_van_lot", 0.6, {"label": "E1"})
	prefab(e1, "secure_zone", "VanSecureE1", Vector3(2.5, 0.0, -5.4), 180.0, {"objective_tag": &"loot_secure"}, null,
		{"kind": "vehicle"})
	prefab(e1, "escape_zone", "VanEscapeE1", Vector3(3.5, 0.0, -1.5), 0.0,
		{"objective_tag": &"escape_van", "escape_type": &"van", "zone_size_m": Vector3(5.0, 3.0, 2.2),
			"visual_scene": load(ESCAPE_VAN_MARKER)})
	var e2: VariantSlot = _slot(esc, "escape", "esc_boat_quay", 0.4, {"label": "E2"})
	# Boat: SECURE_LOOT on the deck (deck-hatch visual, no van body), ESCAPE on the landing beside it.
	prefab(e2, "secure_zone", "BoatSecureE2", Vector3(7.0, -1.0, 36.9), 0.0,
		{"objective_tag": &"loot_secure", "vehicle_collision": false, "zone_size_m": Vector3(4.0, 2.5, 2.4),
			"visual_scene": load(VIS_BOAT_HATCH)},
		null, {"kind": "boat_hatch"}, false)
	prefab(e2, "escape_zone", "BoatEscapeE2", Vector3(8.5, -1.2, 34.7), 0.0,
		{"objective_tag": &"escape_boat", "escape_type": &"boat", "zone_size_m": Vector3(5.6, 3.0, 1.2),
			"visual_scene": load(ESCAPE_BOAT_MARKER)})


## Rare `armored_car_early` (Brutal+): group `armored_car` rolls no slot (pick 0); the rare event's
## force_active pins `armored_car_bay`. The mission hides the car until it arrives (12:00) and then
## spawns the 2 guards at its rear. `armored_car_none` only satisfies the >= 2 slots rule.
func _variants_armored_car(variants: Node3D) -> void:
	var g: Node3D = _group(variants, "armored_car")
	var bay: VariantSlot = _slot(g, "armored_car", "armored_car_bay", 1.0, {"label": "armoured car"})
	var body: Array = L.ARMORED_CAR["body"]
	catalog_prop(bay, "ArmoredCar", "veh_van_secure", body[0], 180.0, {"kind": "vehicle"})
	for sp: Array in L.ARMORED_CAR["spawns"]:
		spawn(bay, String(sp[0]), "GUARD", sp[1], float(sp[2]), ["scripted", "guard_armored_car"], "", "ArmoredCar")
	_slot(g, "armored_car", "armored_car_none", 1.0)
