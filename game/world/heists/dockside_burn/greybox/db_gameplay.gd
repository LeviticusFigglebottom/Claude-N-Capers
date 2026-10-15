## Dockside Burn generator: gameplay prefabs (Gameplay) and variant slots (Variants). Owner: ENV C (C3).
## Chain: db_builder_base.gd <- db_gameplay.gd <- build_greybox.gd. Design: docs/design/heists/
## dockside_burn.md (§Objectives, §Loot path, §Loud, §Variable table, §Rare events; APPROVED D-064);
## contracts: gameplay_prefabs.md (v1.3 SAW_TARGET), heist_map.md §5. Prefabs are found by contract
## class name (no path into ENV A's folder). G2: ENV A's padlock / burn_point prefabs replace the G1
## placeholders (QC-37 / QC-38).
extends "res://world/heists/dockside_burn/greybox/db_builder_base.gd"

## D-111 doors (tools/blender/props/doors.py): the industrial doors keep the G1 visuals' frame boxes, leaf planes and
## widths (twin roller curtains that roll up, cold-store leaves that slide into the wall, the strongroom door); the
## kit doors (layout `<kind>_t<20|40>`) map to the catalog door of the same kind and wall thickness, ivory in the
## office block's corridors and the gatehouse, steel everywhere else (warehouse, plant, fire exits, yard gates).
const CUSTOM_VISUAL: Dictionary = {
	"slide": "prop_door_slide_coldstore_w240_h360", "roller": "prop_door_roller_twin_w360_h400",
	"vault": "prop_door_vault_strongroom_w200_h220",
}
const DOOR_IVORY: Array[String] = [
	"O1Corridor", "O2Corridor", "E1Corridor", "M2Corridor", "M1Corridor", "M3Corridor", "GatehouseNorth",
	"GatehouseSouth",
]
## Greybox t20 doors that stand in 0.3 m walls (the office core stair / hall doors, the gatehouse and net store
## partitions): their catalog frame is t30 (doors.py `wall_t`); the police gates sit in 0.1 m fences (t10).
const DOOR_T30: Array[String] = [
	"StairGround", "OCHall", "PLCorridor", "WSCorridor", "WSHall", "StairMezz", "MCPlatform", "RoofDoor",
	"GatehouseNorth", "GatehouseSouth", "NetStoreWest", "NetStoreEast",
]
const LIFT_VISUAL: String = "res://world/heists/dockside_burn/greybox/goods_lift_visual.tscn"
const BOAT_DROP_VISUAL: String = "res://world/heists/dockside_burn/greybox/boat_drop_visual.tscn"
## PO-13: the escape vans are the catalog van (as on GH / ND), not the secure_zone placeholder.
const VAN_VISUAL: String = "res://world/props/secure_zone/veh_van_secure.tscn"
## PO-13: escape_zone visuals. Van / boat escapes show the vehicle already parked or moored there (the slot's
## secure_zone van, the moored launch), so their visual only carries the contract nodes (no second vehicle).
const ESCAPE_VAN_MARKER: String = "res://world/heists/shared/escape_van_marker.tscn"
const ESCAPE_BOAT_MARKER: String = "res://world/heists/shared/escape_boat_marker.tscn"
## D-111 prop art pass: catalog visual (tools/blender/props) per prefab type, as on Night Deposit
## (nd_gameplay.PREFAB_VISUALS). Doors, ladders, drills, burn points and loot choose theirs where they are built.
const PREFAB_VISUALS: Dictionary = {"safe": "prop_safe_large", "hack_terminal": "prop_server_rack_terminal"}
## D1 stack ladder: 5.2 m rise, the container doors 0.22 m behind the stiles (prefab_visuals.py).
const LADDER_D1: String = "prop_ladder_steel_h520_g22"
## Leaf widths per custom door type (width_m must equal the visual leaf width; validator scale check).
const CUSTOM_WIDTH: Dictionary = {"slide": 2.4, "roller": 3.6, "vault": 2.0}
## Containers K1-K6: [prop name, door x (the door end face), door side (+1 = doors face +x)].
const CONTAINERS: Dictionary = {
	"k1": ["ContainerK1", 14.1, 1.0], "k2": ["ContainerK2", 14.1, 1.0], "k3": ["ContainerK3", 14.1, 1.0],
	"k4": ["ContainerK4", 45.9, -1.0], "k5": ["ContainerK5", 45.9, -1.0], "k6": ["ContainerK6", 45.9, -1.0],
}
const CONTAINER_Z: Dictionary = {"k1": -26.82, "k2": -20.82, "k3": -14.82, "k4": -26.82, "k5": -20.82, "k6": -14.82}
## ENV A padlock prefab (QC-37): lockpick seconds (the hand-held saw cuts it in
## InteractionTweak.hand_saw_padlock_s); the brass padlock visual (prefab_visuals.py).
const PADLOCK_PICK_S: float = 8.0
const PADLOCK_VISUAL: String = "res://assets/props/prop_padlock_brass/prop_padlock_brass.glb"
## Container door latch: the padlock's target; the mission releases the crates on its `opened`.
const LATCH_SCRIPT: String = "res://world/heists/dockside_burn/db_container_latch.gd"
## Product rooms (doc Loot path): slot -> [room, burn pallet base, product loot spawns, fire volume box].
const PRODUCT: Dictionary = {
	"prod_chamber_a": ["C1", Vector3(25.0, 0.0, 13.6), [Vector3(25.0, 0.0, 20.8), Vector3(19.5, 0.0, 18.0)],
		[18.2, 0.0, 10.15, 31.8, 8.0, 23.8]],
	"prod_chamber_b": ["C2", Vector3(41.0, 0.0, 13.6), [Vector3(41.0, 0.0, 20.8), Vector3(46.4, 0.0, 18.0)],
		[35.2, 0.0, 10.15, 47.8, 8.0, 23.8]],
	"prod_packing": ["PK", Vector3(11.0, 0.0, 23.8), [Vector3(6.6, 0.0, 23.6), Vector3(13.6, 0.0, 30.4)],
		[0.2, 0.0, 23.1, 17.8, 4.5, 31.8]],
}
## Doc: the burn runs 30 s (no jams); the burn_point's fire volume deals fire DoT (D-064 Q6).
const BURN_S: float = 30.0

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
	_build_strongroom(gp)
	_build_containers(gp)
	_build_misc(gp)
	_build_lift(gp)


func _door_type(d: Array) -> String:
	return String(d[1]).get_slice("_", 0)


func _build_doors(gp: Node3D) -> void:
	var doors: Node3D = add(gp, node3d("Doors")) as Node3D
	for d: Array in L.DOORS:
		var dtype: String = _door_type(d)
		var vis: PackedScene = _catalog_scene(door_visual(d))
		var props: Dictionary = {"lock": "enum:" + String(d[4]), "swing": "enum:" + String(d[5]), "visual_scene": vis}
		if String(d[6]) != "":
			props["objective_tag"] = StringName(String(d[6]))
		var extra: Dictionary = d[7]
		var metas: Dictionary = {"kind": "industrial_door" if dtype in ["slide", "roller"] else "door", "swing_side": "back"}
		if bool(extra.get("service", false)):
			metas["service"] = true
		if bool(extra.get("public", false)):
			props["casing_allowed"] = true  # public-facing: openable unmasked while casing (PD2); none at the closed yard
		if bool(extra.get("fire_exit", false)):
			metas["fire_exit"] = true
		if extra.has("shutter"):
			metas["fire_shutter"] = String(extra["shutter"])
		if dtype == "service":
			props["width_m"] = 1.1
		elif CUSTOM_WIDTH.has(dtype):
			props["width_m"] = float(CUSTOM_WIDTH[dtype])
		if dtype in ["slide", "roller"]:
			props["leaf_surface"] = &"metal"  # D-105: steel roller / insulated sliding leaves (visual name reads as wood)
		var door: Node3D = prefab(doors, "door", String(d[0]), d[2], float(d[3]), props, null, metas)
		if door != null and extra.has("padlock"):
			_padlock(door, d, float(extra["padlock"]))


## Catalog door for a layout row (CUSTOM_VISUAL, else <kind>_t<n> -> prop_door_<kind>_<ivory|steel>_t<n>).
static func door_visual(d: Array) -> String:
	var piece: String = String(d[1])
	var dtype: String = piece.get_slice("_", 0)
	if CUSTOM_VISUAL.has(dtype):
		return String(CUSTOM_VISUAL[dtype])
	var fin: String = "ivory" if String(d[0]) in DOOR_IVORY else "steel"
	var t: String = piece.get_slice("_", 1)
	if String(d[6]) == "police_gate":
		t = "t10"  # the 0.1 m yard / lane fences
	elif String(d[0]) in DOOR_T30:
		t = "t30"
	return "prop_door_%s_%s_%s" % [dtype, fin, t]


## Padlock on a chained roller door: ENV A's `padlock` prefab (QC-37) on the door's outside (front)
## face, its target the door. Lockpick (PADLOCK_PICK_S) or the hand-held saw (G.SAW_TARGET,
## InteractionTweak.hand_saw_padlock_s) opens it; opening unlocks and raises the door.
func _padlock(door: Node3D, d: Array, _seconds: float) -> void:
	var o: Vector3 = d[2]
	var yaw: float = float(d[3])
	var b: Basis = yaw_basis(yaw)
	var face: Vector3 = o + b * Vector3(0.45, 1.1, -0.07)
	var use: Vector3 = o + b * Vector3(0.45, 0.0, -1.0)
	use.y = o.y
	prefab(door, "padlock", "Padlock", face, yaw + 180.0,
		{"targets": [NodePath("..")] as Array[NodePath], "interaction_time_s": PADLOCK_PICK_S, "objective_tag": &"padlock",
			"visual_scene": load(PADLOCK_VISUAL)}, use, {"mount": "door"})


## SR strongroom: the thermal drill on the vault door (doc 240 s, jams), AN side.
func _build_strongroom(_gp: Node3D) -> void:
	var door: Node3D = n("Gameplay/Doors/StrongroomDoor")
	if door == null:
		return
	prefab(door, "drill_point", "StrongroomDrill", Vector3(26.36, 1.0, 28.6), 90.0,
		{"device": "enum:THERMAL", "duration_s": 240.0, "target": NodePath(".."), "loud_only": true,
			"objective_tag": &"strongroom_drill"}, Vector3(27.2, 0.0, 28.6))


## Yard containers K1-K6: every one has ENV A's padlock prefab on its doors (lockpick or hand-held
## saw, QC-37), its target the container's latch (Gameplay/Containers/LatchKn); two (three with
## `extra_container`) hold 2 weapon crates each. The crate stacks stand at the doors and the mission
## releases them when a weapons container's latch opens.
func _build_containers(gp: Node3D) -> void:
	var cg: Node3D = add(gp, node3d("Containers")) as Node3D
	var keys: Array = CONTAINERS.keys()
	keys.sort()
	for k: Variant in keys:
		var row: Array = CONTAINERS[k]
		var body: Node3D = n("Props/Exterior/" + String(row[0]))
		if body == null:
			errors.append("container prop %s missing" % row[0])
			continue
		var side: float = float(row[2])
		var zc: float = float(CONTAINER_Z[k])
		var face: Vector3 = Vector3(float(row[1]) + side * 0.06, 1.1, zc + 0.5)
		var use: Vector3 = Vector3(float(row[1]) + side * 0.8, 0.0, zc + 0.5)
		var latch: Node3D = node3d("Latch" + String(k).to_upper(), Vector3(float(row[1]), 1.1, zc + 0.5))
		latch.set_script(load(LATCH_SCRIPT))
		latch.set_meta(&"objective_tag", StringName("latch_" + String(k)))
		add(cg, latch)
		var pl: Node3D = prefab(body, "padlock", "Padlock", face, 90.0 if side > 0.0 else -90.0,
			{"interaction_time_s": PADLOCK_PICK_S, "objective_tag": StringName("padlock_" + String(k)),
				"visual_scene": load(PADLOCK_VISUAL)}, use, {"mount": "door"})
		if pl != null:
			pl.set(&"targets", [pl.get_path_to(latch)] as Array[NodePath])
		prefab(cg, "loot_spawn", "Crates" + String(k).to_upper(), Vector3(float(row[1]) + side * 1.1, 0.0, zc - 0.7), 0.0,
			{"loot_id": &"loot.weapon_crate", "count": 2, "objective_tag": StringName("crates_" + String(k))})


func _build_misc(gp: Node3D) -> void:
	var misc: Node3D = add(gp, node3d("Misc")) as Node3D
	# O2 dispatch safe (SMALL, drill or C4) with 3 small loot inside.
	var safe: Node3D = prefab(misc, "safe", "DispatchSafe", Vector3(9.55, 0.0, 0.56), 180.0,
		{"size": "enum:SMALL", "methods": [&"drill", &"c4"] as Array[StringName], "objective_tag": &"dispatch_safe"},
		Vector3(9.55, 0.0, 1.5), {"kind": "safe"})
	if safe != null:
		for i: int in range(3):
			var lp: Vector3 = Vector3(9.39 + 0.16 * float(i), 0.25, 0.56)
			prefab(safe, "small_loot", "SafeCash%d" % (i + 1), lp, 180.0, {"loot_id": &"loot.cash", "value": 1000},
				Vector3(lp.x, 0.0, 1.5))
	# Desk / counter small loot (O1, O2, M1).
	for s: Array in [["DeskCashO1", Vector3(6.8, 0.9, 3.2), Vector3(6.8, 0.0, 2.4)],
			["DeskCashO2", Vector3(13.0, 0.75, 0.9), Vector3(13.2, 0.0, 1.8)],
			["DeskCashM1", Vector3(10.8, L.MEZZ + 0.9, 2.6), Vector3(10.2, L.MEZZ, 3.5)]]:
		prefab(misc, "small_loot", String(s[0]), s[1], 0.0, {"loot_id": &"loot.cash", "value": 750}, s[2])
	# The thermite bag at the van (gate spawn): ENV A's burn_point consumes it (QC-38).
	prefab(misc, "loot_spawn", "ThermiteBag", Vector3(30.2, 0.0, -38.0), 0.0,
		{"loot_id": &"loot.thermite", "count": 1, "objective_tag": &"thermite"})


## Goods lift LF (bag_lift, bags only: 2 bags / 8 s): landing 0 = ground (car at the east hatch, front
## east into the hall), landing 1 = mezzanine (`LandingMezz`, car at the west hatch, front west into
## M1). The Interactable (call / send panel) sits outside the ground hatch; the runtime copies it to
## the mezzanine landing. The closed shaft keeps its navmesh island under the car floor (meta
## walkable: the car floor is a floor; the crew cannot enter the shaft through the 0.8 m hatches).
func _build_lift(gp: Node3D) -> void:
	var lf: Dictionary = L.LIFT
	var car0: Vector3 = lf["car0"]
	var car1: Vector3 = lf["car1"]
	var py: float = float(lf["panel_y"])
	var lift: Node3D = prefab(gp.get_node("Misc") as Node3D, "bag_lift", "GoodsLift", car0, float(lf["yaw0"]),
		{"travel_s": 8.0, "capacity": 2, "car_size_m": Vector3(1.1, 1.2, 1.05), "objective_tag": &"goods_lift",
			"visual_scene": load(LIFT_VISUAL)}, lf["use0"], {"walkable": true}, false)
	if lift == null:
		return
	var it: Node3D = lift.get_node_or_null("Interactable") as Node3D
	if it != null:
		it.position = Vector3(0.0, py, -1.05)
	var m: Marker3D = marker(lift, "LandingMezz", car1)
	m.transform = global_xform(lift).affine_inverse() * Transform3D(yaw_basis(float(lf["yaw1"])), car1)
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
	_variants_cartel(variants)
	_variants_cash(variants)
	_variants_containers(variants)
	_variants_product(variants)
	_variants_entry(variants)
	_variants_gangway(variants)
	_variants_lift(variants)
	_variants_perch(variants)
	_variants_escape(variants)
	_variants_night_shift(variants)
	_variants_rare_perches(variants)


## Cartel posts (doc roster): two gunmen per post on graph `Cartel`, starting unalerted.
## TODO(QC-36): ENV A's `enemy.cartel_gunman` (no pager, not dominatable, wakes on noise); until it
## ships the runtime spawns ordinary guards at these GUARD points. meta enemy_id names the intended def.
func _variants_cartel(variants: Node3D) -> void:
	var g: Node3D = _group(variants, "guard_post")
	var posts: Array = L.CARTEL_POSTS.keys()
	posts.sort()
	for post: Variant in posts:
		var row: Array = L.CARTEL_POSTS[post]
		var slot: VariantSlot = _slot(g, "guard_post", String(post), 1.0)
		for gm: Array in row[0]:
			var sp: SpawnPoint = spawn(slot, String(gm[0]), "GUARD", gm[1], float(gm[2]), ["cartel", String(row[1])],
				String(row[2]), "Cartel")
			sp.set_meta(&"enemy_id", &"enemy.cartel_gunman")


## Cash: the strongroom pallets (thermal drill on the vault door) or the count-room cage (drill / C4).
## The mission splits `cash_bags` over the two stacks of the active location.
func _variants_cash(variants: Node3D) -> void:
	var g: Node3D = _group(variants, "cash_location")
	var sr: VariantSlot = _slot(g, "cash_location", "cash_strongroom", 0.6, {"holdout": "H2"})
	for c: Array in [["StrongroomCashA", Vector3(20.4, 0.0, 27.4)], ["StrongroomCashB", Vector3(20.4, 0.0, 30.0)]]:
		prefab(sr, "loot_spawn", String(c[0]), c[1], 90.0, {"loot_id": &"loot.cash_bricks", "count": 2,
			"objective_tag": &"cash_bricks"})
	var cr: VariantSlot = _slot(g, "cash_location", "cash_countroom", 0.4, {"holdout": "H1"})
	prefab(cr, "safe", "CountCage", Vector3(9.5, L.MEZZ, 4.4), -90.0,
		{"size": "enum:LARGE", "methods": [&"drill", &"c4"] as Array[StringName], "objective_tag": &"count_cage"},
		Vector3(10.4, L.MEZZ, 4.4), {"kind": "safe"})
	for c2: Array in [["CageCashA", Vector3(9.65, L.MEZZ, 2.4)], ["CageCashB", Vector3(9.65, L.MEZZ, 1.2)]]:
		prefab(cr, "loot_spawn", String(c2[0]), c2[1], 90.0, {"loot_id": &"loot.cash_bricks", "count": 2,
			"objective_tag": &"cash_bricks"}, Vector3(10.4, L.MEZZ, minf((c2[1] as Vector3).z, 2.1)))  # use inside the cage, not past M_X9
	# The empty strongroom: fish blocks on the floor.
	prop_box(cr, "FishBlocks", Vector3(21.0, 0.0, 28.6), Vector3(2.0, 1.2, 2.0), 0.0, "fish_blocks", false, "panel")


## Weapons containers (doc `weapons_containers`, pick 2): the slot marks the Co-op's brass padlock on
## that container (readable, not signposted; G1 marker, G2 visual); the crates are Gameplay/Containers.
func _variants_containers(variants: Node3D) -> void:
	var g: Node3D = _group(variants, "weapons_containers")
	var keys: Array = CONTAINERS.keys()
	keys.sort()
	for k: Variant in keys:
		var row: Array = CONTAINERS[k]
		var s: VariantSlot = _slot(g, "weapons_containers", String(k), 1.0,
			{"container": String(row[0]), "crates": "Gameplay/Containers/Crates" + String(k).to_upper()})
		var m: Marker3D = marker(s, "BrassPadlock", Vector3(float(row[1]) + float(row[2]) * 0.06, 1.1,
			float(CONTAINER_Z[k]) + 0.5))
		m.set_meta(&"brass_padlock", true)


## Product location: product stacks (contraband), the product pallet and ENV A's `burn_point` on it
## (QC-38: a carried / nearby loot.thermite bag, burn_place_s to place, a 30 s burn, the
## cue.burn_warning telegraph, then the fire volume: FIRE damage over time, ignores armour, AI keeps
## out). The prefab's `FireVolume` node is moved to the burning room's floor centre and sized to it.
func _variants_product(variants: Node3D) -> void:
	var g: Node3D = _group(variants, "product_location")
	for sid: String in ["prod_chamber_a", "prod_chamber_b", "prod_packing"]:
		var row: Array = PRODUCT[sid]
		var s: VariantSlot = _slot(g, "product_location", sid, 0.8 if sid == "prod_packing" else 1.0,
			{"room": String(row[0]), "shutters": L.SHUTTERS[sid]})
		var base: Vector3 = row[1]
		prop_box(s, "ProductPallet", base, Vector3(1.2, 1.2, 1.0), 0.0, "pallet_product", true, "prop")
		var fb: Array = row[3]
		var fmn: Vector3 = v3(fb, 0)
		var fmx: Vector3 = v3(fb, 3)
		var bp: Node3D = prefab(s, "burn_point", "BurnPoint", base + Vector3(0.0, 1.2, 0.0), 0.0,
			{"duration_s": BURN_S, "loud_only": true, "objective_tag": &"burn", "fire_volume_size": fmx - fmn},
			base + Vector3(0.0, 0.0, 1.3))
		if bp != null:
			var fv: Node3D = bp.get_node_or_null(^"FireVolume") as Node3D
			if fv == null:
				errors.append("burn_point has no FireVolume node")
			else:
				var floor_c: Vector3 = Vector3((fmn.x + fmx.x) * 0.5, fmn.y, (fmn.z + fmx.z) * 0.5)
				fv.transform = global_xform(bp).affine_inverse() * Transform3D(Basis.IDENTITY, floor_c)
				map_root.set_editable_instance(bp, true)
		var loots: Array = row[2]
		for i: int in range(loots.size()):
			prefab(s, "loot_spawn", "Product%d" % (i + 1), loots[i], 0.0,
				{"loot_id": &"loot.contraband", "count": 2, "objective_tag": &"product"})


## The first way in without a lockpick or a padlock cut (doc `warehouse_entry`): the mission opens the
## named door. Slot content: a marker at the door.
func _variants_entry(variants: Node3D) -> void:
	var g: Node3D = _group(variants, "warehouse_entry")
	for r: Array in [["door_office", 0.35, "O1Front"], ["door_quay", 0.35, "ANQuay"], ["door_dock", 0.3, "DockRoller"]]:
		var s: VariantSlot = _slot(g, "warehouse_entry", String(r[0]), float(r[1]), {"door": String(r[2])})
		var d: Node3D = n("Gameplay/Doors/" + String(r[2]))
		if d != null:
			marker(s, "EntryDoor", global_xform(d).origin)


## East gangway (doc): down = the swing bridge spans the slip (a walkable deck prop, its nav link, the
## P3 police spawn on Pier 10 and its ENTRY point); up = swung clear, a 1.05 m barrier in the gap.
func _variants_gangway(variants: Node3D) -> void:
	var g: Node3D = _group(variants, "east_gangway")
	var down: VariantSlot = _slot(g, "east_gangway", "gangway_down", 0.6)
	var deck: StaticBody3D = prop_box(down, "GangwayDeck", Vector3(67.0, 0.0, -13.0), Vector3(13.0, 0.12, 3.0), 0.0,
		"gangway", true, "deck")
	deck.set_meta(&"walkable", true)
	for side: Array in [["RailN", -14.45], ["RailS", -11.55]]:
		var col: CollisionShape3D = CollisionShape3D.new()
		col.name = String(side[0]) + "Collision"
		col.shape = box_shape(Vector3(10.0, 1.1, 0.06))
		col.position = Vector3(0.0, 0.12 + 0.55, float(side[1]) + 13.0)
		add(deck, col)
		mesh_box(deck, String(side[0]), Vector3(-5.0, 0.12, float(side[1]) + 13.0 - 0.03),
			Vector3(5.0, 1.22, float(side[1]) + 13.0 + 0.03), "trim")
	nav_link(down, "GangwayLink", Vector3(60.6, 0.0, -13.0), Vector3(74.0, 0.0, -13.0))
	var p3: Array = L.POLICE_PIER10
	spawn(down, String(p3[0]), "POLICE", p3[1], float(p3[2]), p3[3], "", "")
	_tactical(down, ["EntryGangway", "ENTRY", Vector3(61.4, 0.0, -13.0), 90.0, ["gangway", "east"], false])
	var up: VariantSlot = _slot(g, "east_gangway", "gangway_up", 0.4)
	var bar: StaticBody3D = prop_box(up, "GangwayBarrier", Vector3(61.85, 0.0, -13.0), Vector3(0.1, 1.05, 3.2), 0.0,
		"railing", false, "trim")
	bar.set_meta(&"hinged_barrier", true)


## Goods lift power (doc `goods_lift`): dead = the E1 breaker must be reset (interact 5 s) before the
## lift runs. G1 stand-in: a hack_terminal (duration 5 s, no interruptions) on E1's east wall.
func _variants_lift(variants: Node3D) -> void:
	var g: Node3D = _group(variants, "goods_lift")
	_slot(g, "goods_lift", "lift_powered", 0.6)
	var dead: VariantSlot = _slot(g, "goods_lift", "lift_dead", 0.4)
	prefab(dead, "hack_terminal", "LiftBreaker", Vector3(17.3, 0.0, 4.55), 90.0,
		{"duration_s": 5.0, "interruptions": Vector2i(0, 0), "objective_tag": &"lift_breaker"}, Vector3(16.3, 0.0, 4.55),
		{"kind": "breaker_panel"})


## Player perch (doc `player_perch`): the roof head-house door unlocked, the D1 ladder in place, none.
func _variants_perch(variants: Node3D) -> void:
	var g: Node3D = _group(variants, "player_perch")
	var roof: VariantSlot = _slot(g, "player_perch", "perch_roof", 0.3, {"door": "RoofDoor"})
	marker(roof, "PerchRoof", Vector3(10.0, L.ROOF, 5.0))
	var stack: VariantSlot = _slot(g, "player_perch", "perch_stack", 0.3)
	prefab(stack, "ladder", "D1Ladder", Vector3(8.0, 0.0, -5.38), 180.0, {"height_m": 5.2,
		"visual_scene": _catalog_scene(LADDER_D1)}, null, {"kind": "ladder"})
	_slot(g, "player_perch", "perch_none", 0.4)


## Escapes (doc §Escape): E1 van on the weighbridge, E2 van in the lane, E3 the Co-op launch.
## SECURE_LOOT exists from the start; the mission activates the escape after [burn] + [secure].
func _variants_escape(variants: Node3D) -> void:
	var esc: Node3D = _group(variants, "escape")
	var e1: VariantSlot = _slot(esc, "escape", "esc_van_gate", 0.4, {"label": "E1", "holdout": "H4"})
	prefab(e1, "secure_zone", "VanSecureE1", Vector3(34.0, 0.0, -23.0), 180.0,
		{"objective_tag": &"loot_secure", "visual_scene": load(VAN_VISUAL)}, null, {"kind": "vehicle"})
	prefab(e1, "escape_zone", "VanEscapeE1", Vector3(34.0, 0.0, -18.8), 0.0,
		{"objective_tag": &"escape_van", "escape_type": &"van", "zone_size_m": Vector3(5.0, 3.0, 2.4),
			"visual_scene": load(ESCAPE_VAN_MARKER)})
	var e2: VariantSlot = _slot(esc, "escape", "esc_van_lane", 0.3, {"label": "E2", "holdout": "lane"})
	prefab(e2, "secure_zone", "VanSecureE2", Vector3(-5.0, 0.0, 1.0), 180.0,
		{"objective_tag": &"loot_secure", "visual_scene": load(VAN_VISUAL)}, null, {"kind": "vehicle"})
	prefab(e2, "escape_zone", "VanEscapeE2", Vector3(-5.0, 0.0, 5.0), 0.0,
		{"objective_tag": &"escape_van", "escape_type": &"van", "zone_size_m": Vector3(3.6, 3.0, 2.4),
			"visual_scene": load(ESCAPE_VAN_MARKER)})
	var e3: VariantSlot = _slot(esc, "escape", "esc_boat", 0.3, {"label": "E3", "holdout": "H3"})
	prefab(e3, "secure_zone", "BoatSecureE3", Vector3(22.5, -1.6, 55.6), 0.0,
		{"objective_tag": &"loot_secure", "vehicle_collision": false,
			"zone_size_m": Vector3(4.0, 2.5, 2.4), "visual_scene": load(BOAT_DROP_VISUAL)},
		null, {"kind": "boat_hatch"}, false)
	prefab(e3, "escape_zone", "BoatEscapeE3", Vector3(24.0, L.LAND, 52.2), 0.0,
		{"objective_tag": &"escape_boat", "escape_type": &"boat", "zone_size_m": Vector3(7.0, 3.0, 2.6),
			"visual_scene": load(ESCAPE_BOAT_MARKER)})


## Night shift (doc `night_shift` 1-3 workers; the hostages): a slot group (a scalar cannot add NPCs).
func _variants_night_shift(variants: Node3D) -> void:
	var g: Node3D = _group(variants, "night_shift")
	for sid: String in ["shift_1", "shift_2", "shift_3"]:
		var s: VariantSlot = _slot(g, "night_shift", sid, 1.0)
		for wid: Variant in L.NIGHT_SHIFT[sid]:
			var w: Array = L.WORKERS[wid]
			spawn(s, "Worker" + String(wid), "CIVILIAN", w[0], float(w[1]), ["civ_worker"], "browse", "")


## Rare perches: S3 viaduct walkway (`fog_lifts`), S4 trawler wheelhouse (`harbor_unit`). Never rolled
## (pick 0): the rare event pins the `_on` slot. TODO(QC-25): S3 should only become a valid perch at
## the event time (the director has no perch-enable hook); G1 enables it for the whole run.
func _variants_rare_perches(variants: Node3D) -> void:
	for r: Array in [["perch_viaduct", "viaduct", L.SNIPER_VIADUCT], ["perch_trawler", "trawler", L.SNIPER_TRAWLER]]:
		var g: Node3D = _group(variants, String(r[0]))
		var on: VariantSlot = _slot(g, String(r[0]), String(r[1]) + "_on", 1.0)
		_tactical(on, r[2])
		_slot(g, String(r[0]), String(r[1]) + "_off", 1.0)


func _tactical(parent: Node3D, t: Array) -> TacticalPoint:
	var tp: TacticalPoint = TacticalPoint.new()
	tp.name = String(t[0])
	tp.kind = TacticalPoint.Kind[String(t[1])]
	tp.position = global_xform(parent).affine_inverse() * (t[2] as Vector3)
	tp.basis = yaw_basis(float(t[3]))
	var tg: Array[StringName] = []
	for x: Variant in t[4]:
		tg.append(StringName(String(x)))
	tp.tags = tg
	tp.breachable = bool(t[5])
	add(parent, tp)
	return tp
