## Ostrander Federal gameplay layer (OF-C1): the door lock table, every VariantSlot (resolver order, B's ids and weights)
## with its content, cameras C1-C16 per layout, the VC laser grids, the always-present prefabs (devices, loot, lifts,
## ladders, containers, markers), NPC spawns, patrol graphs, tactical points and furniture. Owner: ENV C.
## Chain: of_builder_base <- of_shell <- of_gameplay <- build_greybox.
## Prefabs are ENV A's (found by contract class name); visuals are catalog props (doors: the greybox door kit). Content
## rows come from ostrander_federal_layout_content.gd (tools/levelcheck/plans/ostrander_federal_content.py).
## Pre-placed, disabled (QC-61, OF-A2): the hoist (bag_lift) and the rope ladder (`rope_ladder`) are placed with
## enabled_at_start = false (+ the G1 metas `starts_disabled` / `hidden` the mission's fallback still reads), the ladder
## `usable = false`. The lid (OF-A6) is a GameplayPrefab tagged `lid` at Gameplay/Devices/Lid (Plug + Visual/LidPanel):
## its set_enabled(false) at the burn replicates; the hole's footprint is a permanent navmesh hole (lead ruling, OF-A6).
## Civilian routes (OF-A4 CivilianRoute + CivilianRouteStop) under Patrols/Routes, the teller's per side_door slot.
extends "res://world/heists/ostrander_federal/greybox/of_shell.gd"

## Spawn tags a locked door's `npc_authorized_tags` lists: "@guards" (every Halden post) / "@staff" (staff civilians).
const GUARD_TAGS: Array = ["guard_lobby", "guard_vault", "guard_rover_hall", "guard_rover_gallery", "guard_rover_basement",
	"guard_rover_dock", "guard_extra_hall", "guard_extra_basement", "guard_extra_exec", "guard_extra_tannery",
	"guard_vaultline"]
const STAFF_TAGS: Array = ["civ_teller", "civ_manager_mgr_floor", "civ_manager_mgr_gallery", "civ_manager_mgr_vault",
	"civ_officer"]
const LOCKPICK_S: float = 8.0
## Door bake-closed (D-073 / D-122): the projected obstruction fills the opening, +0.15 m into each jamb, 0.3 m each side.
const BAKE_DEPTH: float = 0.3
## Catalog visuals whose bodies block the bake.
## (Not loot_spawn: its marker is a navmesh target, within 0.25 m of the bake.)
const OBSTRUCT_KINDS: Array[String] = ["safe", "body_container", "secure_zone", "camera_station", "hack_terminal",
	"bag_lift"]
## SL-2 laser emitter column art (tools/blender/props/lasers.py) on every VC laser post.
const LASER_COLUMN: String = "prop_laser_emitter_column"
## Minimum width of a rig wall in the nav bake (see _nav_thick).
const RIG_NAV_MIN: float = 0.2
## Door jamb boxes in the nav bake (see _jamb_clearance): crew capsule radius (crew_member.tscn), its clearance at the
## jambs, the bake cell, the frame's half depth (the wall's).
const JAMB_CREW_R: float = 0.35
const JAMB_CREW_CLEAR: float = 0.05
const NAV_CELL: float = 0.1
const JAMB_FRAME_D: float = 0.1

## [node, property, names] bound once everything is built (targets, operator spawn).
var _binds: Array[Array] = []


# --- Items ----------------------------------------------------------------------------------------

## Builds one content row under `parent` (formats: ostrander_federal_content.py header).
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
		"route":
			out = _route_row(parent, it)
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
	var pitch: float = float((it[7] as Dictionary).get("pitch", 0.0))
	if pitch != 0.0:   # a drill-down spot: -Z (the bit) pitched towards the floor (the OF lid, A r305)
		xf.basis = xf.basis * Basis(Vector3.RIGHT, deg_to_rad(pitch))
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
		elif key2 == "@rig":
			_rig(inst, props[k2])
		elif key2 == "@panel":
			_lift_panel(inst, props[k2])
		elif key2 == "@contents":
			for c: Array in props[k2]:
				_content(inst, c)
		elif key2.begins_with("@"):
			_binds.append([inst, key2.substr(1), props[k2]])
	# (a `walkable` lift car is a navmesh floor: the crew walk in with the bags; its art never blocks the bake)
	if kind in OBSTRUCT_KINDS and not metas.has("mount") and not bool(metas.get("starts_disabled", false)) \
			and not bool(metas.get("walkable", false)):
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


## OF-P1 §7.7: the hoist rig ([name, world min, world max] rows, ostrander_federal_content.HOIST_RIG) as static boxes
## under `host`/Rig: they come and go with the prefab (disabled = hidden and out of physics). world_dynamic (layer 2):
## crew and bags collide, interaction and vision rays (world_static) pass. Each box is a permanent nav obstruction (the
## hole's D-121 pattern: the navmesh never changes at the burn).
func _rig(host: Node3D, rows: Array) -> void:
	var rig: Node3D = add(host, node3d("Rig")) as Node3D
	var inv: Transform3D = global_xform(host).affine_inverse()
	for r: Array in rows:
		var mn: Vector3 = v3(r[1])
		var mx: Vector3 = v3(r[2])
		var sb: StaticBody3D = box(rig, String(r[0]), inv * mn, inv * mx, "trim")
		if sb != null:
			sb.collision_layer = 2
			sb.set_meta(&"lc_subprop", true)   # levelcheck: each its own prop (not merged into the hoist's box)
			sb.set_meta(&"kind", "hoist_rig")
		obstruct(Transform3D.IDENTITY, _nav_thick(AABB(mn, mx - mn)))


## A projected obstruction only marks the 0.1 m cells whose centre it covers, so a 5 cm shaft wall can fall between the
## centres and leave a walkable seam (ENV P burn re-run 2: a path through ShaftE). Widen each thin horizontal axis,
## centred on the wall, to RIG_NAV_MIN (two cells) for the bake only; the collider keeps its real size.
static func _nav_thick(box: AABB) -> AABB:
	var out: AABB = box
	for ax: int in [0, 2]:
		if out.size[ax] < RIG_NAV_MIN:
			var c: float = out.position[ax] + out.size[ax] * 0.5
			out.position[ax] = c - RIG_NAV_MIN * 0.5
			out.size[ax] = RIG_NAV_MIN
	return out


## bag_lift external call / send panel ([world min, world max, panel height], ostrander_federal_content.HOIST_PANEL):
## a `Panel` riser (a floor-standing strip against the shaft wall, its origin at the panel height) under the lift.
## bag_lift moves its Interactable onto the origin, hides the visual's own panel and copies the riser to every other
## landing; the Interactable is placed there in the scene too (the saved focus point matches the runtime one). A
## world_dynamic body like the rig (out of physics with the disabled hoist; levelcheck: its own prop, lc_subprop).
func _lift_panel(lift: Node3D, row: Array) -> void:
	var inv: Transform3D = global_xform(lift).affine_inverse()
	var mn: Vector3 = v3(row[0])
	var mx: Vector3 = v3(row[1])
	var at: Vector3 = Vector3((mn.x + mx.x) * 0.5, float(row[2]), (mn.z + mx.z) * 0.5)
	var size: Vector3 = mx - mn
	var sb: StaticBody3D = StaticBody3D.new()
	sb.name = "Panel"
	sb.collision_layer = 2
	sb.collision_mask = 0
	sb.position = inv * at
	sb.set_meta(&"lc_subprop", true)
	sb.set_meta(&"kind", "lift_panel")   # (bag_lift's LandingPanelVisual copies carry it)
	add(lift, sb)
	var off: Vector3 = (mn + mx) * 0.5 - at
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Collision"
	col.shape = _box_shape(size)
	col.position = off
	add(sb, col)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = _box_mesh(size, "trim")
	mi.position = off
	add(sb, mi)
	SurfaceTags.tag(sb, _surface("trim"))
	var it: Node3D = lift.get_node_or_null("Interactable") as Node3D
	if it == null:
		errors.append("%s has no Interactable" % lift.name)
		return
	map_root.set_editable_instance(lift, true)
	it.position = inv * at


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


## ["box", name, base, size, yaw, kind, support, class]: a Props/MapBuilt furniture box + its nav obstruction.
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
	if it.size() > 8:
		for mk: Variant in (it[8] as Dictionary):
			body.set_meta(StringName(String(mk)), it[8][mk])
	add(parent, body)
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
	# ENV P r260: a 5 cm partition (LK / PW cubicles, SD booths) rasterises to no cell; widen it in the bake only
	obstruct(Transform3D(yaw_basis(float(it[4])), base), _nav_thick(AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), size)))
	return body


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


## ["route", name, route_id, order, bind_tags, start_index, stops]: A's CivilianRoute with CivilianRouteStop children
## (stop: [name, pos, pause, pause_anim, away_window, facing yaw or null]). Scripts by class name at run time: the route
## script needs the GameRng autoload, which a --script generator cannot compile against.
func _route_row(parent: Node3D, it: Array) -> Node3D:
	var route_scr: Script = class_script("CivilianRoute")
	var stop_scr: Script = class_script("CivilianRouteStop")
	if route_scr == null or stop_scr == null:
		errors.append("CivilianRoute / CivilianRouteStop class not found (%s)" % it[1])
		return null
	var r: Node3D = route_scr.new() as Node3D
	r.name = String(it[1])
	r.set(&"route_id", StringName(String(it[2])))
	r.set(&"order", int((route_scr.get_script_constant_map()["Order"] as Dictionary)[String(it[3])]))
	var tags: Array[StringName] = []
	for t: Variant in it[4]:
		tags.append(StringName(String(t)))
	r.set(&"bind_tags", tags)
	r.set(&"start_index", int(it[5]))
	r.transform = global_xform(parent).affine_inverse()
	add(parent, r)
	for st: Array in it[6]:
		var p: PatrolPoint = stop_scr.new() as PatrolPoint
		p.name = String(st[0])
		p.position = v3(st[1])
		p.pause_range = Vector2(float(st[2][0]), float(st[2][1]))
		p.pause_anim = StringName(String(st[3]))
		p.set(&"away_window", StringName(String(st[4])))
		if st[5] != null:
			p.basis = yaw_basis(float(st[5]))
			p.face_marker_forward = true
		add(r, p)
	return r


## A global class's script by class name (null when missing).
static func class_script(cls: String) -> Script:
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if String(c["class"]) == cls:
			return load(String(c["path"])) as Script
	return null


## The lid (QC-61 / OF-A6): a bare GameplayPrefab (no interaction; found by class name) tagged `lid` holding the hole's
## plug body and the marble panel, so the mission's set_enabled(false) at the burn hides it and drops its collision on
## every peer. Meta burn_lid kept for the mission's G1 fallback. The footprint is carved out of the navmesh for good.
func build_lid(parent: Node3D) -> void:
	var scr: Script = class_script("GameplayPrefab")
	if scr == null:
		errors.append("GameplayPrefab class not found (the lid)")
		return
	var o: Vector3 = v3(L.LID["origin"])
	var lid: Node3D = Node3D.new()
	lid.set_script(scr)
	lid.name = "Lid"
	lid.position = o
	lid.set(&"objective_tag", &"lid")
	lid.set_meta(&"kind", "hatch")   # levelcheck: sits in its slab hole like a shell piece (GN-C2 floor hatch)
	lid.set_meta(&"burn_lid", true)
	add(parent, lid)
	var vis: Node3D = add(lid, node3d("Visual")) as Node3D
	var pl: Array = L.LID["panel"]
	mesh_box(vis, "LidPanel", v3(pl[0]) - o, v3(pl[1]) - o, String(pl[2]))
	var pg: Array = L.LID["plug"]
	box(lid, "Plug", v3(pg[0]) - o, v3(pg[1]) - o, String(pg[2]))
	var hole: AABB = AABB(v3(pg[0]), v3(pg[1]) - v3(pg[0]))
	obstruct(Transform3D.IDENTITY, AABB(Vector3(hole.position.x, -0.2, hole.position.z), Vector3(hole.size.x, 2.2,
		hole.size.z)))


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
	for d: Array in L.DOORS:
		if String(d[5]) == "":
			continue   # a side_door slot builds it
		door(parent, d, String(d[0]), String(d[5]), d[8])


## One door prefab ([name, floor, origin, yaw, kind, lock, visual, width_m, extra]) under `parent` with `lock`.
func door(parent: Node3D, d: Array, nm: String, lock: String, extra: Dictionary) -> Node3D:
	var kind: String = String(d[4])
	var props: Dictionary = {"lock": "enum:" + lock, "width_m": float(d[7]),
		"swing": "enum:" + ("DOUBLE" if kind == "double" else ("OUTWARD" if bool(extra.get("out", false)) else "INWARD"))}
	if lock == "LOCKPICK":
		props["interaction_time_s"] = LOCKPICK_S
	for k: String in ["starts_open", "push_bar"]:
		if bool(extra.get(k, false)):
			props[k] = true
	if extra.has("leaf"):
		props["leaf_surface"] = String(extra["leaf"])
	if extra.has("npc"):
		props["npc_authorized_tags"] = _npc_tags(extra["npc"])
	if extra.has("tag"):
		props["objective_tag"] = String(extra["tag"])
	var metas: Dictionary = {"kind": String(extra.get("kind_meta", "door")), "swing_side": "back"}
	if bool(extra.get("push_bar", false)) or bool(extra.get("fire_door", false)):
		metas["fire_exit"] = true   # (fire_door: a two-way cross-corridor smoke door, no push bar)
	if kind == "service":
		metas["service"] = true
	var it: Array = ["prefab", "door", nm, d[2], float(d[3]), props, null, metas, String(d[6])]
	var inst: Node3D = place_prefab(parent, it)
	if bool(extra.get("bake_closed", false)):
		var w: float = {"single": 1.0, "service": 1.2, "double": 2.0, "vault": 2.4, "roller": 3.6}.get(kind, 2.0) + 0.3
		var h: float = 4.9 if kind == "roller" else 2.6
		obstruct(Transform3D(yaw_basis(float(d[3])), v3(d[2])), AABB(Vector3(-w * 0.5, -0.2, -BAKE_DEPTH),
			Vector3(w, h, BAKE_DEPTH * 2.0)))
	else:
		_jamb_clearance(Transform3D(yaw_basis(float(d[3])), v3(d[2])), float(d[7]))
	if inst != null and String(d[0]) in ["CashCageGate", "GoldCageGate"]:
		_gate_padlock(inst, String(extra.get("tag", "")))
	return inst


## ENV P ghost run (AssistantDoor): the nav agent is 0.3 m but the crew capsule is 0.35 m, and the wall cut the bake
## sees is wider than the frame (clear half width = the leaf's half width) and off its centre, so a path on the throat
## edge put the capsule on a jamb and the pilot stalled there. Bake only: two carved (exact) boxes over the jambs, as
## deep as the frame plus the capsule, leave a straight throat at the frame centre +- `half`: on the cell grid like the
## door centres so it rasterizes exactly, a cell narrower for the contour simplification (edge_max_error 1.3 cells)
## on wide throats, and at least a cell (the 0.9 m singles keep a 0.2 m throat; there the capsule just touches at
## its edges). Off the throat the wall's own agent-radius margin (0.3 m) is only 5-10 cm narrower, so
## corridors and landings past the doors keep their width. The collider keeps its real size.
func _jamb_clearance(xf: Transform3D, width: float) -> void:
	var w2: float = width * 0.5
	var half: float = maxf(NAV_CELL, floorf((w2 - JAMB_CREW_R - JAMB_CREW_CLEAR - NAV_CELL) / NAV_CELL + 0.001) * NAV_CELL)
	var depth: float = ceilf((JAMB_FRAME_D + JAMB_CREW_R) / NAV_CELL - 0.001) * NAV_CELL
	var reach: float = w2 + JAMB_CREW_R + NAV_CELL - half   # over the jamb into the wall's own margin
	for side: float in [-1.0, 1.0]:
		var x0: float = half if side > 0.0 else -half - reach
		obstruct(xf, AABB(Vector3(x0, -0.2, -depth), Vector3(reach, 2.6, depth * 2.0)), true)


## D-138: the cage gate's padlock / hasp (lockpick 8 s, or a placed saw) on the gate itself; opening it opens the gate.
func _gate_padlock(gate: Node3D, tag: String) -> void:
	var xf: Transform3D = global_xform(gate)
	var pos: Vector3 = xf * Vector3(0.0, 1.05, -0.07)
	var use: Vector3 = xf * Vector3(0.0, 0.0, -0.8)
	place_prefab(gate, ["prefab", "padlock", "Padlock", [pos.x, pos.y, pos.z], rad_to_deg(xf.basis.get_euler().y),
		{"interaction_time_s": LOCKPICK_S, "place_saw": true, "objective_tag": tag, "@targets": [String(gate.name)]},
		[use.x, use.y, use.z], {"kind": "padlock"}, "prop_padlock_brass"])


static func _npc_tags(src: Array) -> Array:
	var out: Array = []
	for t: Variant in src:
		var add_tags: Array = GUARD_TAGS if t == "@guards" else (STAFF_TAGS if t == "@staff" else [t])
		for a: Variant in add_tags:
			if not out.has(a):
				out.append(a)
	return out


# --- Variants ---------------------------------------------------------------------------------------

func build_variants(variants: Node3D) -> void:
	var groups: Dictionary = {}
	for g: String in L.GROUP_ORDER:
		groups[g] = add(variants, node3d("Group_" + g))
	for row: Array in L.SLOTS:
		var g2: String = String(row[0])
		var sid: String = String(row[1])
		var vs: VariantSlot = VariantSlot.new()
		vs.name = "Slot_" + sid
		vs.slot_group = StringName(g2)
		vs.slot_id = StringName(sid)
		vs.weight = float(row[2])
		vs.params = L.SLOT_PARAMS.get(sid, {})
		vs.transform = Transform3D(yaw_basis(float(row[8])), Vector3(float(row[5]), float(row[6]), float(row[7])))
		vs.set_meta(&"room", String(row[4]))
		add(groups[g2], vs)
		for it: Array in LC.SLOT_ITEMS.get(sid, []) + L.ROUTES.get(sid, []):
			build_item(vs, it)
		match g2:
			"camera":
				for c: Array in L.CAMERAS:
					if (c[5] as Array).has(sid):
						security_camera(vs, c)
			"laser_pattern":
				_lasers(vs, sid)
			"side_door":
				for nm: String in L.SIDE_DOORS[sid]:
					var spec: Array = L.SIDE_DOORS[sid][nm]
					var extra: Dictionary = (L.SIDE_DOOR_EXTRA[nm] as Dictionary).duplicate()
					extra.merge(spec[1] as Dictionary, true)
					for d: Array in L.DOORS:
						if String(d[0]) == nm:
							door(vs, d, nm, String(spec[0]), extra)


func security_camera(parent: Node3D, c: Array) -> Node3D:
	var pos: Array = c[3]
	return place_prefab(parent, ["prefab", "security_camera", "Camera" + String(c[0]), pos, float(c[4]),
		{"fov_deg": 60.0, "range_m": 20.0, "pan_deg": float(c[6])}, null,
		{"mount": "wall", "kind": "security_camera", "camera_id": String(c[0])}, "prop_security_camera_wall"])


## The VC grid at x LASER_X across the concourse (local X along -z, yaw 90) with its emitter / receiver posts. OF-C2:
## each post's visual is the catalog emitter column (SL-2, its lens face turned to the other post) over the post's
## 0.12 x 2.7 x 0.15 collider, and the grid's visual the slot's beam set (LASERS `visual`: beams only, no posts).
func _lasers(vs: VariantSlot, sid: String) -> void:
	var lz: Dictionary = LC.LASERS[sid]
	var z0: float = float(lz["z"][0])
	var z1: float = float(lz["z"][1])
	var fy: float = LC.LASER_FLOOR
	var post0: Node3D = vs
	for i: int in range((lz["posts"] as Array).size()):
		var p: Array = lz["posts"][i]
		var post: StaticBody3D = _box_row(vs, ["box", "LaserPost%d" % i, [LC.LASER_X, fy, (float(p[0]) + float(p[1])) * 0.5],
			[0.12, 2.7, float(p[1]) - float(p[0])], 0.0, "laser_emitter", true, "trim"])
		if post == null:
			continue
		_laser_column(post, -90.0 if i == 0 else 90.0)
		if i == 0:
			post0 = post   # the grid hangs off its emitter post (as GN's TreasuryLasers)
	var props: Dictionary = {"pattern": String(lz["pattern"]), "size_m": [z1 - z0, float(lz["h"]), 0.1],
		"enabled_at_start": true, "objective_tag": "laser_grid"}
	for k: String in ["beams", "sweep_beams", "period_s", "off_s"]:
		if lz.has(k):
			props["beam_count" if k == "beams" else k] = lz[k]
	var metas: Dictionary = (lz["metas"] as Dictionary).duplicate()
	metas["kind"] = "laser_grid"
	place_prefab(post0, ["prefab", "laser_grid", "VaultLasers", [LC.LASER_X, fy + float(lz["y"]), (z0 + z1) * 0.5], 90.0,
		props, null, metas, String(lz.get("visual", ""))])


## Swaps a laser post's box mesh for the catalog emitter column (lens face +X turned by `yaw` toward the grid).
func _laser_column(post: StaticBody3D, yaw: float) -> void:
	var box_mesh: Node = post.get_node_or_null(^"Mesh")
	if box_mesh != null:
		post.remove_child(box_mesh)
		box_mesh.free()
	var ps: PackedScene = catalog_scene(LASER_COLUMN)
	if ps == null:
		return
	var column: Node3D = ps.instantiate() as Node3D
	column.name = "Column"
	column.basis = yaw_basis(yaw)
	add(post, column)


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
	var routes: Node3D = add(n("Patrols"), node3d("Routes")) as Node3D
	for r: Array in L.ROUTES["Patrols/Routes"]:
		build_item(routes, r)
	build_lid(n("Gameplay/Devices"))


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


func build_npcs_and_tactical() -> void:
	for it: Array in LC.FIXED_SPAWNS:
		build_item(n("Spawns"), it)
	for t: Array in LC.TACTICAL:
		build_item(n("Tactical"), t)


## OF-C3 levelcheck lines (Gameplay/Lines): a Node3D with the line metas and Marker3D children at the crew's feet.
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
