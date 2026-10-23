## Rolling Thunder gameplay layer (RT-C1): the door table, every VariantSlot (resolver order, the doc's slot ids) with its
## content, the convoy (movers, paths, the four layouts), the always-present prefabs (the signal rig, the lift breaker,
## loot, the goods lift, the frame ladder, containers, markers), NPC spawns, patrol graphs, tactical points and furniture.
## Owner: ENV C. Copy-adapted from ostrander_federal/greybox/of_gameplay.gd (D-147); chain: rt_builder_base <- rt_shell
## <- rt_gameplay <- build_greybox. Prefabs are ENV A's (found by contract class name); visuals are catalog props
## (doors: the greybox door kit). Content rows: rolling_thunder_layout_content.gd (rolling_thunder_content.py).
## RT-C2: the convoy is ENV A's convoy_vehicle movers carrying their armored_truck (A5-01 / A5-02), with a stop marker
## per vehicle in each layout (_convoy_sets).
extends "res://world/heists/rolling_thunder/greybox/rt_shell.gd"

const LOCKPICK_S: float = 8.0
## Door bake-closed (D-073 / D-122): the projected obstruction fills the opening, +0.15 m into each jamb, 0.3 m each side.
const BAKE_DEPTH: float = 0.3
## Catalog visuals whose bodies block the bake.
const OBSTRUCT_KINDS: Array[String] = ["safe", "body_container", "secure_zone", "hack_terminal"]
## Minimum width of a thin body in the nav bake (see _nav_thick).
const RIG_NAV_MIN: float = 0.2
## RT-C2 convoy: the truck hold (A5-01 ArmoredTruck visual) and cab (A5-02 ConvoyVehicle visual) per kind; the escort
## cars' visual (Seat0..3; its art fronts -Z, so the mover's `Visual` is turned 180 deg).
const CONVOY_CAR_ART: String = "veh_escort_car"
const CONVOY_TRUCK_ART: Dictionary = {"cash": "veh_armored_truck_cash", "bullion": "veh_armored_truck_bullion"}
## Phase 2: Reyes's mixer, a convoy mover waiting in the site (A drives it at the mixer move along the layout's
## `MixerPath` to its `MixerStop`).
const CONVOY_MIXER_ART: String = "veh_mixer_truck_mover"
const CONVOY_CAB_ART: Dictionary = {"cash": "veh_armored_cab_cash", "bullion": "veh_armored_cab_bullion"}
const CONVOY_THERMITE_ART: String = "prop_thermite_lock"
## ArmoredTruck defaults are the cash van (saw 120 s, hand saw 60 s, C4 x4); the bullion truck (doc Truck targets).
const CONVOY_TRUCK_PROPS: Dictionary = {"bullion": {"saw_duration_s": 180.0, "hand_saw_duration_s": 90.0}}
## rolling_thunder_convoy.py LEN / WIDTH (m) and the truck art's rear step and lock edge (x).
const CONVOY_LEN: Dictionary = {"car": 5.0, "cash": 7.5, "bullion": 9.0, "mixer": 8.0}
const CONVOY_WIDTH: Dictionary = {"car": 2.0, "cash": 2.5, "bullion": 2.5, "mixer": 2.5}
const TRUCK_STEP: float = 0.35
const TRUCK_LOCK_X: float = -0.85
const TRUCK_USE_BACK: float = 0.5
## The rear-step UsePoints stand at this x (truck-local), off the lock side's rear corner, clear of the door's swing
## (hinge +X) and of a vehicle queued close behind (the movers wait 0.55 m apart): the truck's saw / C4 spot
## TRUCK_USE_BACK behind the doors, the bullion thermite's THERMITE_USE_BACK.
const TRUCK_USE_X: float = -1.8
## An empty visual for a device spot whose host art already shows it (the SawPoint on the truck's lock plate).
const EMPTY_VISUAL: String = "res://world/heists/glasshouse/art/gh_empty.tscn"
const THERMITE_USE_BACK: float = 1.1
## Where the movers' `<Veh>Path` Path3Ds go: "Movers" (beside the movers) or "Paths" (`Convoy/Paths`); the mission's
## _drive_path finds them in either (A 88873eb2), so the vehicles drive in to their stops (D-149.8); any other name
## keeps the paths but the mission pops the vehicles in (park).
const CONVOY_PATH_PARENT: String = "Paths"

## RT-C2 convoy nav (D-149.1), read by build_greybox's bake: per route slot {route, layouts [{node, id, obs (the
## stopped vehicles' footprints)}]}.
var convoy_bake: Array[Dictionary] = []
## The movers' footprints where they wait upstream (the main bake keeps them clear).
var convoy_start_obs: Array[Array] = []
## [node, property, names] bound once everything is built (targets).
var _binds: Array[Array] = []


# --- Items ----------------------------------------------------------------------------------------

## Builds one content row under `parent` (formats: rolling_thunder_content.py header).
func build_item(parent: Node3D, it: Array) -> Node3D:
	var out: Node3D = null
	match String(it[0]):
		"prefab":
			out = place_prefab(parent, it)
		"spawn":
			out = _spawn_row(parent, it)
		"box":
			out = _box_row(parent, it)
		"marker":
			out = marker(parent, String(it[1]), v3(it[2]), float(it[3]), String(it[4]), String(it[5]))
		"tac":
			out = _tac_row(parent, it)
		"catalog":
			out = _catalog_row(parent, it)
		"call":   # a sidewalk call point (CivilianTargets.CALL_POINT_GROUP; its reason meta call_reason)
			out = marker(parent, String(it[1]), v3(it[2]), 0.0, "", "")
			out.set_meta(&"call_reason", &"civilian_call")
			out.add_to_group(&"civilian_call_point", true)
		_:
			errors.append("unknown content row %s" % [it])
	return out


## ["prefab", kind, name, pos, yaw, props, use, metas, visual]
func place_prefab(parent: Node3D, it: Array) -> Node3D:
	var kind: String = String(it[1])
	var ps: PackedScene = _prefab_scene(kind)
	if ps == null:
		return null
	var inst: Node3D = ps.instantiate() as Node3D
	inst.name = String(it[2])
	var xf: Transform3D = Transform3D(yaw_basis(float(it[4])), v3(it[3]))
	inst.transform = global_xform(parent).affine_inverse() * xf
	var vis: String = String(it[8])
	if vis != "":
		inst.set(&"visual_scene", catalog_scene(vis))
	var props: Dictionary = it[5]
	for k: Variant in props:
		var key: String = String(k)
		if not key.begins_with("@"):
			set_prop(inst, key, props[k])
	var metas: Dictionary = it[7]
	inst.set_meta(&"kind", String(metas.get("kind", kind)))
	for mk: Variant in metas:
		if String(mk) == "hidden":
			inst.visible = not bool(metas[mk])
		elif String(mk) == "group":
			inst.add_to_group(StringName(String(metas[mk])), true)
		elif String(mk) != "kind":
			inst.set_meta(StringName(String(mk)), metas[mk])
	parent.add_child(inst)
	inst.owner = map_root
	if it[6] != null:
		var up: Node3D = inst.get_node_or_null("UsePoint") as Node3D
		if up == null:
			errors.append("%s has no UsePoint" % inst.name)
		else:
			up.transform = global_xform(inst).affine_inverse() * _facing(v3(it[6]), xf.origin)
			map_root.set_editable_instance(inst, true)
	for k2: Variant in props:
		var key2: String = String(k2)
		if key2 == "@landings":
			_landings(inst, props[k2])
		elif key2 == "@contents":
			for c: Array in props[k2]:
				_content(inst, c)
		elif key2.begins_with("@"):
			_binds.append([inst, key2.substr(1), props[k2]])
	# (a `walkable` lift car is a navmesh floor: the crew walk in with the bags; its art never blocks the bake)
	if kind in OBSTRUCT_KINDS and not metas.has("mount") and not bool(metas.get("walkable", false)):
		_obstruct_catalog(vis, xf)
	return inst


## bag_lift landing markers (local offsets) -> `targets`.
func _landings(lift: Node3D, rows: Array) -> void:
	var targets: Array[NodePath] = []
	for l: Array in rows:
		var m: Marker3D = Marker3D.new()
		m.name = String(l[0])
		m.position = v3(l[1])
		add(lift, m)
		targets.append(lift.get_path_to(m))
	lift.set(&"targets", targets)


## A projected obstruction only marks the 0.1 m cells whose centre it covers, so a thin body (the F1 edge protection,
## the scaffold mesh, the palisades) can fall between the centres and leave a walkable seam (OF: ShaftE). Widen each
## thin horizontal axis, centred on the body, to RIG_NAV_MIN (two cells) for the bake only; the collider keeps its
## real size (of_gameplay.gd _nav_thick).
static func _nav_thick(b: AABB) -> AABB:
	var out: AABB = b
	for ax: int in [0, 2]:
		if out.size[ax] < RIG_NAV_MIN:
			var c: float = out.position[ax] + out.size[ax] * 0.5
			out.position[ax] = c - RIG_NAV_MIN * 0.5
			out.size[ax] = RIG_NAV_MIN
	return out


## A prefab inside another (a safe's contents): [kind, name, local offset, props].
func _content(host: Node3D, c: Array) -> void:
	var ps: PackedScene = _prefab_scene(String(c[0]))
	if ps == null:
		return
	var inst: Node3D = ps.instantiate() as Node3D
	inst.name = String(c[1])
	inst.position = v3(c[2])
	for k: Variant in (c[3] as Dictionary):
		set_prop(inst, String(k), c[3][k])
	inst.set_meta(&"kind", String(c[0]))
	inst.set_meta(&"inside", true)
	host.add_child(inst)
	inst.owner = map_root
	# PO6-05: stowed loot is taken from the safe's own UsePoint (the floor in front of the door)
	var hup: Node3D = host.get_node_or_null("UsePoint") as Node3D
	var cup: Node3D = inst.get_node_or_null("UsePoint") as Node3D
	if hup != null and cup != null:
		cup.transform = global_xform(inst).affine_inverse() * global_xform(hup)
		map_root.set_editable_instance(inst, true)


func _spawn_row(parent: Node3D, it: Array) -> SpawnPoint:
	var sp: SpawnPoint = spawn(parent, String(it[1]), String(it[2]), v3(it[3]), float(it[4]), it[5], String(it[6]))
	if String(it[7]) != "":
		sp.patrol_graph = sp.get_path_to(map_root.get_node("Patrols/" + String(it[7])))
	if String(it[8]) != "":   # the seated NPC's chair (NpcSeatSpawns snaps the spawn onto its Seat)
		var ps: PackedScene = catalog_scene(String(it[8]))
		if ps != null:
			var chair: Node3D = ps.instantiate() as Node3D
			chair.name = String(it[1]) + "Chair"
			chair.transform = global_xform(parent).affine_inverse() * Transform3D(yaw_basis(float(it[4])), v3(it[3]))
			add(parent, chair)
	return sp


## ["box", name, base, size, yaw, kind, support, class, metas]: a Props/MapBuilt box + its nav obstruction.
func _box_row(parent: Node3D, it: Array) -> StaticBody3D:
	var base: Vector3 = v3(it[2])
	var size: Vector3 = v3(it[3])
	var body: StaticBody3D = StaticBody3D.new()
	body.name = String(it[1])
	body.collision_layer = 1
	body.collision_mask = 0
	body.transform = global_xform(parent).affine_inverse() * Transform3D(yaw_basis(float(it[4])), base)
	body.set_meta(&"kind", String(it[5]))
	if bool(it[6]):
		body.set_meta(&"support", true)
	for mk: Variant in (it[8] as Dictionary):
		if String(mk) != "seats":
			body.set_meta(StringName(String(mk)), it[8][mk])
	add(parent, body)
	_seats(body, (it[8] as Dictionary).get("seats", []))
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Collision"
	col.shape = _box_shape(size)
	col.position = Vector3(0.0, size.y * 0.5, 0.0)
	add(body, col)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = _box_mesh(size, String(it[7]))
	mi.position = col.position
	add(body, mi)
	SurfaceTags.tag(body, _surface(String(it[7])))
	# a seat bench is carved exactly (no agent-radius margin), so its sitters' roots, 0.12 m in from its front edge, stay
	# within reach of the navmesh (ENV D's seated roots) and no polygon lies under the bench
	var seated: bool = not ((it[8] as Dictionary).get("seats", []) as Array).is_empty()
	obstruct(Transform3D(yaw_basis(float(it[4])), base), _nav_thick(AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5),
		size)), seated)
	return body


## Seat markers (local positions) on a bench / catalog seat: `Seat` for one, `Seat0`.. for several (ENV D's seated
## roots: the sitter's root on the marker's xz, its height the cushion top).
func _seats(host: Node3D, rows: Array) -> void:
	for i: int in range(rows.size()):
		var m: Marker3D = Marker3D.new()
		m.name = "Seat" if rows.size() == 1 else "Seat%d" % i
		m.position = v3(rows[i])
		add(host, m)


## ["catalog", name, pos, yaw, asset, metas, seats]: a catalog prop as furniture (Props/MapBuilt) + its nav obstruction.
func _catalog_row(parent: Node3D, it: Array) -> Node3D:
	var ps: PackedScene = catalog_scene(String(it[4]))
	if ps == null:
		return null
	var inst: Node3D = ps.instantiate() as Node3D
	inst.name = String(it[1])
	var xf: Transform3D = Transform3D(yaw_basis(float(it[3])), v3(it[2]))
	inst.transform = global_xform(parent).affine_inverse() * xf
	for mk: Variant in (it[5] as Dictionary):
		if String(mk) != "carve":
			inst.set_meta(StringName(String(mk)), it[5][mk])
	add(parent, inst)
	if not (it[6] as Array).is_empty():
		map_root.set_editable_instance(inst, true)
		_seats(inst, it[6])
	# a seat, or the table between two seats (meta carve: the booth), is carved exactly (no agent-radius margin)
	if not (it[6] as Array).is_empty() or bool((it[5] as Dictionary).get("carve", false)):
		var ab: Array = PropCatalog.entry(StringName(String(it[4]))).get("aabb", [])
		if ab.size() == 6:   # carved exactly; a seat only behind its sitters' root line (the feet stand in front)
			var box: AABB = AABB(Vector3(ab[0], ab[1], ab[2]), Vector3(ab[3], ab[4], ab[5]))
			if not (it[6] as Array).is_empty():
				var front: float = float((it[6] as Array)[0][2])   # the seat marker's local z (front is -Z)
				box = AABB(Vector3(box.position.x, box.position.y, front), Vector3(box.size.x, box.size.y,
					box.end.z - front))
			obstruct(xf, box, true)
	else:
		_obstruct_catalog(String(it[4]), xf)
	return inst


func _tac_row(parent: Node3D, it: Array) -> TacticalPoint:
	var tp: TacticalPoint = TacticalPoint.new()
	tp.name = String(it[1])
	tp.kind = TacticalPoint.Kind[String(it[2])]
	tp.transform = global_xform(parent).affine_inverse() * Transform3D(yaw_basis(float(it[4])), v3(it[3]))
	var tags: Array[StringName] = []
	for t: Variant in it[5]:
		tags.append(StringName(String(t)))
	tp.tags = tags
	tp.breachable = bool(it[6])
	add(parent, tp)
	return tp


## Resolves the "@" props (node names -> NodePaths) once every node exists.
func bind_targets() -> void:
	for b: Array in _binds:
		var inst: Node3D = b[0]
		var prop: String = String(b[1])
		var names: Array = b[2] if b[2] is Array else [b[2]]
		var paths: Array[NodePath] = []
		for nm: Variant in names:
			var t: Node = map_root.find_child(String(nm), true, false)
			if t == null:
				errors.append("%s: %s target `%s` not found" % [inst.name, prop, nm])
				continue
			paths.append(inst.get_path_to(t))
		if prop == "targets":
			inst.set(&"targets", paths)
		elif not paths.is_empty():
			inst.set(StringName(prop), paths[0])


# --- Doors ------------------------------------------------------------------------------------------

func build_doors(parent: Node3D) -> void:
	for d: Array in LC.DOORS:
		if String(d[5]) == "":
			continue   # a SLOT_DOORS slot builds it
		door(parent, d, String(d[0]), String(d[5]), d[8])


## One door prefab ([name, floor, origin, yaw, kind, lock, visual, width_m, extra]) under `parent` with `lock`.
## extra: kind (meta kind, default "door"; the Tannery gate: industrial_door), push_bar, npc (spawn tags a locked door
## lets through), tag (objective_tag), padlock (objective tag of a
## padlock on the leaf: a BARRED gate / magazine door opened by lockpick 8 s or a placed saw, D-138), todo.
func door(parent: Node3D, d: Array, nm: String, lock: String, extra: Dictionary) -> Node3D:
	var kind: String = String(d[4])
	var props: Dictionary = {"lock": "enum:" + lock, "width_m": float(d[7]),
		"swing": "enum:" + ("DOUBLE" if kind == "double" else ("OUTWARD" if bool(extra.get("push_bar", false)) else "INWARD"))}
	if lock == "LOCKPICK":
		props["interaction_time_s"] = LOCKPICK_S
	if bool(extra.get("push_bar", false)):
		props["push_bar"] = true
	if extra.has("npc"):
		props["npc_authorized_tags"] = extra["npc"]
	if extra.has("tag"):
		props["objective_tag"] = String(extra["tag"])
	if extra.has("leaf"):
		props["leaf_surface"] = String(extra["leaf"])
	if extra.has("height"):   # D-158: leaf collision as tall as the visual leaves (A's Door.height_m, env/a-core 75400478)
		props["height_m"] = float(extra["height"])
	var metas: Dictionary = {"kind": String(extra.get("kind", "door")), "swing_side": "back"}
	if bool(extra.get("push_bar", false)):
		metas["fire_exit"] = true
	if kind == "service":
		metas["service"] = true
	if extra.has("todo"):
		metas["todo"] = String(extra["todo"])
	if extra.has("opens_with"):   # the mission opens it with that event (the Tannery gate: the mixer's move)
		metas["opens_with"] = String(extra["opens_with"])
	var it: Array = ["prefab", "door", nm, d[2], float(d[3]), props, null, metas, String(d[6])]
	var inst: Node3D = place_prefab(parent, it)
	if lock == "BARRED":   # D-073 / D-122: baked closed; the door's NavLink bridges it once open (OF bake_closed)
		# (the Tannery site gate's 4.0 m width_m is wider than a double's 2.0 m frame)
		var w: float = maxf({"single": 1.0, "service": 1.2, "double": 2.0}.get(kind, 2.0), float(d[7])) + 0.3
		obstruct(Transform3D(yaw_basis(float(d[3])), v3(d[2])), AABB(Vector3(-w * 0.5, -0.2, -BAKE_DEPTH),
			Vector3(w, 2.6, BAKE_DEPTH * 2.0)))
	if inst != null and extra.has("padlock"):
		_gate_padlock(inst, String(extra["padlock"]))
	return inst


## D-138: the gate's padlock / hasp (lockpick 8 s, or a placed saw) on the leaf's front face; opening it opens the gate.
func _gate_padlock(gate: Node3D, tag: String) -> void:
	var xf: Transform3D = global_xform(gate)
	var pos: Vector3 = xf * Vector3(0.0, 1.05, -0.07)
	var use: Vector3 = xf * Vector3(0.0, 0.0, -0.8)
	place_prefab(gate, ["prefab", "padlock", "Padlock", [pos.x, pos.y, pos.z], rad_to_deg(xf.basis.get_euler().y),
		{"interaction_time_s": LOCKPICK_S, "place_saw": true, "objective_tag": tag, "@targets": [String(gate.name)]},
		[use.x, use.y, use.z], {"kind": "padlock"}, "prop_padlock_brass"])


# --- Variants ---------------------------------------------------------------------------------------

func build_variants(variants: Node3D) -> void:
	var groups: Dictionary = {}
	for g: String in LC.GROUP_ORDER:
		groups[g] = add(variants, node3d("Group_" + g))
	for row: Array in LC.SLOTS:
		var g2: String = String(row[0])
		var sid: String = String(row[1])
		var vs: VariantSlot = VariantSlot.new()
		vs.name = "Slot_" + sid
		vs.slot_group = StringName(g2)
		vs.slot_id = StringName(sid)
		vs.weight = float(row[2])
		vs.transform = Transform3D(yaw_basis(float(row[5])), v3(row[4]))
		vs.set_meta(&"room", String(row[3]))
		add(groups[g2], vs)
		for it: Array in LC.SLOT_ITEMS.get(sid, []):
			build_item(vs, it)
		if LC.SLOT_DOORS.has(sid):
			for nm: String in LC.SLOT_DOORS[sid]:
				for d: Array in LC.DOORS:
					if String(d[0]) == nm:
						door(vs, d, nm, String(LC.SLOT_DOORS[sid][nm]), d[8])
		if LC.CONVOY.has(sid):
			_convoy_sets(vs, sid)


## The route's convoy under its slot (RT-C2; A5-01 / A5-02, D-149.1 / QC-RT1):
## * `Convoy/Movers/<Veh>`: A's ConvoyVehicle at its path's start (cab +Z toward the junction); a truck mover's visual is
##   the cab (its AnimatableBody fits it) and it carries an ArmoredTruck child (the hold: its StaticBody fits the hold,
##   so the two bodies never stack); a bullion mover also carries the rear-door burn_point `Thermite` (QC-81, target
##   ../Truck: beside the truck, since Safe stows any prefab inside it as loot); `<Veh>Path` Path3Ds
##   beside them (CONVOY_PATH_PARENT);
## * `Convoy/<Clean|Crash>` (meta convoy_layout "<route>_<mode>", hidden: ConvoyLayouts shows the one in play): a
##   `<Veh>Stop` Marker3D per vehicle at the mover pivot (the east ramp's tilt in its basis), `RearStop2` (trucks_2: the
##   rear car GAP behind T2) and the per-layout COVER (TacticalPoint `enabled` false until the stop). The layout's nav
##   region is added by the bake (build_greybox `_bake_convoy`) from `convoy_bake`.
func _convoy_sets(vs: VariantSlot, sid: String) -> void:
	var data: Dictionary = LC.CONVOY[sid]
	var holder: Node3D = add(vs, node3d("Convoy")) as Node3D
	holder.transform = global_xform(vs).affine_inverse()
	var movers: Node3D = add(holder, node3d("Movers")) as Node3D
	var paths: Node3D = movers if CONVOY_PATH_PARENT == "Movers" else add(holder, node3d(CONVOY_PATH_PARENT)) as Node3D
	for mv: Array in data["movers"]:
		_convoy_mover(movers, paths, mv)
	var entry: Dictionary = {"route": sid, "layouts": []}
	for set_row: Array in data["layouts"]:
		var mode: String = String(set_row[0])
		var st: Node3D = add(holder, node3d(mode.capitalize())) as Node3D
		var lid: String = "%s_%s" % [sid.trim_prefix("route_"), mode]
		st.set_meta(&"convoy_layout", lid)
		st.visible = false   # ConvoyLayouts shows the layout in play at the stop
		var obs: Array = []
		for v: Array in set_row[1]:
			var size: Vector3 = v3(v[5])   # [length, height, width]
			# tilted onto its support line along the east arm (slope v[4] = -dy/dx): local up -> the ramp normal
			var up: Vector3 = Vector3(float(v[4]), 1.0, 0.0).normalized()
			var tilt: Basis = Basis(Quaternion(Vector3.UP, up)) if up.y < 0.99999 else Basis.IDENTITY
			var xf: Transform3D = Transform3D(tilt * yaw_basis(float(v[3])), v3(v[2]))
			var m: Marker3D = Marker3D.new()
			m.name = String(v[0])
			m.transform = xf
			m.set_meta(&"kind", "convoy_stop")
			m.set_meta(&"vehicle_kind", String(v[1]))
			add(st, m)
			obs.append(_vehicle_footprint(xf, String(v[1]), size))
			for cv: Array in v[6]:
				var tp: TacticalPoint = _tac_row(st, ["tac", String(cv[0]), "COVER", cv[1], float(cv[2]),
					["convoy", lid], false])
				tp.enabled = false
		if set_row.size() > 2:   # phase 2: the mixer's drive from the site to this layout's MixerStop
			add(st, _convoy_path("MixerPath", set_row[2]))
		(entry["layouts"] as Array).append({"node": st, "id": lid, "obs": obs})
	convoy_bake.append(entry)


## ["Lead", kind, start pivot, yaw, path rows]: the mover, its drive-in path and (a truck) its ArmoredTruck.
func _convoy_mover(movers: Node3D, paths: Node3D, mv: Array) -> void:
	var kind: String = String(mv[1])
	var ps: PackedScene = _prefab_scene("convoy_vehicle")
	if ps == null:
		return
	var veh: Node3D = ps.instantiate() as Node3D
	veh.name = String(mv[0])
	veh.transform = Transform3D(yaw_basis(float(mv[3])), v3(mv[2]))
	# (the mixer is its own kind: Reyes sits visible at its wheel; trucks are armoured, their crew hidden: D r280)
	set_prop(veh, "vehicle_kind", kind if kind == "car" or kind == "mixer" else "truck")
	var art: String = CONVOY_CAR_ART if kind == "car" else (CONVOY_MIXER_ART if kind == "mixer" else
		String(CONVOY_CAB_ART[kind]))
	veh.set(&"visual_scene", catalog_scene(art))
	veh.set_meta(&"kind", "convoy_" + kind)
	movers.add_child(veh)
	veh.owner = map_root
	if kind == "car":
		map_root.set_editable_instance(veh, true)
		(veh.get_node("Visual") as Node3D).basis = yaw_basis(180.0)
	if not (mv[4] as Array).is_empty():
		add(paths, _convoy_path(String(mv[0]) + "Path", mv[4]))
	convoy_start_obs.append(_vehicle_footprint(global_xform(veh), kind, Vector3(CONVOY_LEN[kind], 3.0,
		CONVOY_WIDTH[kind])))
	if kind == "cash" or kind == "bullion":
		_convoy_truck(veh, kind)


## A drive-in Path3D `nm` from [[point, in handle, out handle]] rows (world; its parent sits at the world origin).
func _convoy_path(nm: String, rows: Array) -> Path3D:
	var path: Path3D = Path3D.new()
	path.name = nm
	var curve: Curve3D = Curve3D.new()
	for p: Array in rows:
		curve.add_point(v3(p[0]), v3(p[1]), v3(p[2]))
	path.curve = curve
	return path


## A truck mover's hold: A5-01's ArmoredTruck in the mover's frame (cash defaults; bullion saw 180 / 90 s and the QC-81
## rear-door burn_point), its rear-step UsePoint on the road behind the doors and its Interactable on the lock.
func _convoy_truck(veh: Node3D, kind: String) -> void:
	var ps: PackedScene = _prefab_scene("armored_truck")
	if ps == null:
		return
	var t: Node3D = ps.instantiate() as Node3D
	t.name = "Truck"
	t.set(&"visual_scene", catalog_scene(String(CONVOY_TRUCK_ART[kind])))
	for k: String in (CONVOY_TRUCK_PROPS.get(kind, {}) as Dictionary):
		set_prop(t, k, CONVOY_TRUCK_PROPS[kind][k])
	set_prop(t, "loud_only", true)   # sawn / blown after the ambush (doc Truck targets), not while it queues upstream
	t.set_meta(&"kind", "convoy_" + kind)
	t.set_meta(&"truck_kind", kind)
	veh.add_child(t)
	t.owner = map_root
	map_root.set_editable_instance(t, true)
	var rear: float = -float(CONVOY_LEN[kind]) * 0.5
	var lock: Vector3 = Vector3(TRUCK_LOCK_X, 0.0, rear)
	(t.get_node("UsePoint") as Node3D).transform = _facing(Vector3(TRUCK_USE_X, 0.0, rear - TRUCK_USE_BACK), lock)
	(t.get_node("Interactable") as Node3D).position = Vector3(TRUCK_LOCK_X, 1.7, rear - 0.1)
	_truck_saw_point(t, kind, lock)
	if kind != "bullion":
		return
	var bps: PackedScene = _prefab_scene("burn_point")
	if bps == null:
		return
	var b: Node3D = bps.instantiate() as Node3D
	b.name = "Thermite"
	b.position = Vector3(TRUCK_LOCK_X, 1.0, rear - 0.085)   # on the door's thermite plate, under the lock
	b.set(&"visual_scene", catalog_scene(CONVOY_THERMITE_ART))
	set_prop(b, "target", NodePath("../Truck"))
	set_prop(b, "fire_volume_size", [0.0, 0.0, 0.0])
	set_prop(b, "loud_only", true)
	b.set_meta(&"kind", "burn_point")
	veh.add_child(b)   # beside the truck: a prefab inside a Safe is stowed as its loot (Safe._inner_loot)
	b.owner = map_root
	map_root.set_editable_instance(b, true)
	(b.get_node("UsePoint") as Node3D).transform = Transform3D(Basis.IDENTITY, -b.position) * _facing(
		Vector3(TRUCK_USE_X, 0.0, rear - THERMITE_USE_BACK), lock)


## The truck's saw spot (B's RT HUD run: with no SAW drill_point the truck's own runner anchors at its pivot, inside
## the cargo box, and the HUD timer hides behind its collision): a SAW drill_point child (Safe._own_device_point; not
## stowed as loot) at the art's `DrillPoint` on the rear door's lock (TRUCK_LOCK_X, 1.7 m, 0.1 m out of the door
## face, -Z into the lock), target the truck, the truck's own saw time; its UsePoint is the truck's rear-step spot.
func _truck_saw_point(t: Node3D, kind: String, lock: Vector3) -> void:
	var dps: PackedScene = _prefab_scene("drill_point")
	if dps == null:
		return
	var rear: float = lock.z
	var d: Node3D = dps.instantiate() as Node3D
	d.name = "SawPoint"
	d.set(&"visual_scene", load(EMPTY_VISUAL))   # the truck's own lock plate is the art (as ND's ATM saws: nd_empty)
	d.transform = Transform3D(yaw_basis(180.0), Vector3(TRUCK_LOCK_X, 1.7, rear - 0.1))
	set_prop(d, "device", "enum:SAW")
	# the bullion truck's own time (CONVOY_TRUCK_PROPS), else the prefab's default (armored_truck.tscn: the cash van)
	set_prop(d, "duration_s", float((CONVOY_TRUCK_PROPS.get(kind, {}) as Dictionary).get("saw_duration_s",
		t.get(&"saw_duration_s"))))
	set_prop(d, "target", NodePath(".."))
	set_prop(d, "loud_only", true)
	d.set_meta(&"kind", "drill_point")
	t.add_child(d)
	d.owner = map_root
	map_root.set_editable_instance(d, true)
	(d.get_node("UsePoint") as Node3D).transform = d.transform.affine_inverse() * _facing(
		Vector3(TRUCK_USE_X, 0.0, rear - TRUCK_USE_BACK), lock)


## A vehicle's nav footprint at `xf` (its pivot: bottom-centre, cab +Z): [corners, elevation, height, carve false],
## the box `size` [length, height, width] plus a truck's rear step behind its doors (-Z).
func _vehicle_footprint(xf: Transform3D, kind: String, size: Vector3) -> Array:
	var back: float = TRUCK_STEP if kind != "car" else 0.0
	var box: AABB = AABB(Vector3(-size.z * 0.5, 0.0, -size.x * 0.5 - back), Vector3(size.z, size.y, size.x + back))
	var pts: PackedVector3Array = PackedVector3Array()
	for c: Vector3 in [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]:
		pts.append(xf * (box.position + box.size * c))
	var lo: float = INF
	var hi: float = -INF
	for i: int in 8:
		var w: Vector3 = xf * (box.position + box.size * Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1))
		lo = minf(lo, w.y)
		hi = maxf(hi, w.y)
	return [pts, lo, hi - lo, false]


# --- Always-present content, NPCs, patrols, tactical ------------------------------------------------

func build_always() -> void:
	var mb: Node3D = add(n("Props"), node3d("MapBuilt")) as Node3D
	for it: Array in LC.FURNITURE:
		build_item(mb, it)
	for path: String in LC.ALWAYS:
		var parent: Node3D = map_root.get_node_or_null(path) as Node3D
		if parent == null:
			parent = add(n(path.get_slice("/", 0)), node3d(path.get_slice("/", 1))) as Node3D
		for it2: Array in LC.ALWAYS[path]:
			build_item(parent, it2)


func build_graphs(patrols: Node3D) -> void:
	for gname: String in LC.GRAPHS:
		var row: Array = LC.GRAPHS[gname]
		var g: PatrolGraph = PatrolGraph.new()
		g.name = gname
		g.graph_id = StringName(String(row[0]))
		g.floor_index = int(row[1])
		add(patrols, g)
		var points: Dictionary = row[2]
		for pn: Variant in points:
			var pr: Array = points[pn]
			var p: PatrolPoint = PatrolPoint.new()
			p.name = String(pn)
			p.position = v3(pr[0])
			p.pause_range = Vector2(float(pr[1][0]), float(pr[1][1]))
			p.pause_anim = StringName(String(pr[2]))
			var tags: Array[StringName] = []
			for t: Variant in pr[3]:
				tags.append(StringName(String(t)))
			p.tags = tags
			if pr[4] != null:
				p.basis = yaw_basis(float(pr[4]))
				p.face_marker_forward = true
			add(g, p)
		var links: Dictionary = {}
		for e: Array in row[3]:
			for pair: Array in [[e[0], e[1]], [e[1], e[0]]]:
				if not links.has(pair[0]):
					links[pair[0]] = []
				if not (links[pair[0]] as Array).has(pair[1]):
					(links[pair[0]] as Array).append(pair[1])
		for pn2: Variant in points:
			var pp: PatrolPoint = g.get_node(String(pn2)) as PatrolPoint
			var paths: Array[NodePath] = []
			for other: Variant in links.get(pn2, []):
				paths.append(pp.get_path_to(g.get_node(String(other))))
			pp.links = paths


## Levelcheck lines (Gameplay/Lines, OF's build_lines): a Node3D with the line metas and Marker3D children at the
## crew's feet.
func build_lines(parent: Node3D) -> void:
	for ln: Array in LC.LINES:
		var root: Node3D = add(parent, node3d(String(ln[0]))) as Node3D
		for mk: Variant in (ln[1] as Dictionary):
			var v: Variant = ln[1][mk]
			root.set_meta(StringName(String(mk)), PackedStringArray(v) if v is Array else v)
		var pts: Array = ln[2]
		for i: int in range(pts.size()):
			var m: Marker3D = Marker3D.new()
			m.name = "P%02d" % i
			m.position = v3(pts[i])
			add(root, m)


func build_npcs_and_tactical() -> void:
	for it: Array in LC.FIXED_SPAWNS:
		build_item(n("Spawns"), it)
	for t: Array in LC.TACTICAL:
		build_item(n("Tactical"), t)
