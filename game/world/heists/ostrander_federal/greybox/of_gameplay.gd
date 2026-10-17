## Ostrander Federal gameplay layer (OF-C1): the door lock table, every VariantSlot (resolver order, B's ids and weights)
## with its content, cameras C1-C16 per layout, the VC laser grids, the always-present prefabs (devices, loot, lifts,
## ladders, containers, markers), NPC spawns, patrol graphs, tactical points and furniture. Owner: ENV C.
## Chain: of_builder_base <- of_shell <- of_gameplay <- build_greybox.
## Prefabs are ENV A's (found by contract class name); visuals are catalog props (doors: the greybox door kit). Content
## rows come from ostrander_federal_layout_content.gd (tools/levelcheck/plans/ostrander_federal_content.py).
## Pre-placed, disabled (QC-61, OF-A2 not on trunk yet): the hoist (bag_lift) and the rope ladder carry meta
## `starts_disabled` + `hidden`, the ladder `usable = false`; the lid plug is Geometry/Building/Lid/Lid (meta burn_lid).
extends "res://world/heists/ostrander_federal/greybox/of_shell.gd"

## Spawn tags a locked door's `npc_authorized_tags` lists: "@guards" (every Halden post) / "@staff" (staff civilians).
const GUARD_TAGS: Array = ["guard_lobby", "guard_vault", "guard_rover_hall", "guard_rover_gallery", "guard_rover_basement",
	"guard_rover_dock", "guard_extra_hall", "guard_extra_basement", "guard_extra_exec", "guard_extra_tannery",
	"guard_vaultline"]
const STAFF_TAGS: Array = ["civ_teller", "civ_manager_floor", "civ_manager_gallery", "civ_manager_vault", "civ_officer"]
const LOCKPICK_S: float = 8.0
## Door bake-closed (D-073 / D-122): the projected obstruction fills the opening, +0.15 m into each jamb, 0.3 m each side.
const BAKE_DEPTH: float = 0.3
## Catalog visuals whose bodies block the bake.
const OBSTRUCT_KINDS: Array[String] = ["safe", "body_container", "secure_zone", "camera_station", "hack_terminal",
	"loot_spawn", "bag_lift"]

## [node, property, names] bound once everything is built (targets, operator spawn).
var _binds: Array[Array] = []


# --- Items ----------------------------------------------------------------------------------------

## Builds one content row under `parent` (formats: ostrander_federal_content.py header).
func build_item(parent: Node3D, it: Array) -> Node3D:
	match String(it[0]):
		"prefab":
			return place_prefab(parent, it)
		"spawn":
			return _spawn_row(parent, it)
		"box":
			return _box_row(parent, it)
		"marker":
			return marker(parent, String(it[1]), v3(it[2]), float(it[3]), String(it[4]), String(it[5]))
		"tac":
			return _tac_row(parent, it)
	errors.append("unknown content row %s" % [it])
	return null


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
	if kind in OBSTRUCT_KINDS and not metas.has("mount") and not bool(metas.get("starts_disabled", false)):
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
	obstruct(Transform3D(yaw_basis(float(it[4])), base), AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), size))
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
	if bool(extra.get("push_bar", false)):
		metas["fire_exit"] = true
	if kind == "service":
		metas["service"] = true
	var it: Array = ["prefab", "door", nm, d[2], float(d[3]), props, null, metas, String(d[6])]
	var inst: Node3D = place_prefab(parent, it)
	if bool(extra.get("bake_closed", false)):
		var w: float = {"single": 1.0, "service": 1.2, "double": 2.0, "vault": 2.4, "roller": 3.6}.get(kind, 2.0) + 0.3
		var h: float = 4.9 if kind == "roller" else 2.6
		obstruct(Transform3D(yaw_basis(float(d[3])), v3(d[2])), AABB(Vector3(-w * 0.5, -0.2, -BAKE_DEPTH),
			Vector3(w, h, BAKE_DEPTH * 2.0)))
	if inst != null and String(d[0]) in ["CashCageGate", "GoldCageGate"]:
		_gate_padlock(inst, String(extra.get("tag", "")))
	return inst


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
		for it: Array in LC.SLOT_ITEMS.get(sid, []):
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
		{"fov_deg": 60.0, "range_m": 20.0, "pan_deg": 40.0}, null,
		{"mount": "wall", "kind": "security_camera", "camera_id": String(c[0])}, "prop_security_camera_wall"])


## The VC grid at x LASER_X across the concourse (local X along -z, yaw 90) with its emitter / receiver posts.
func _lasers(vs: VariantSlot, sid: String) -> void:
	var lz: Dictionary = LC.LASERS[sid]
	var z0: float = float(lz["z"][0])
	var z1: float = float(lz["z"][1])
	var fy: float = LC.LASER_FLOOR
	for i: int in range((lz["posts"] as Array).size()):
		var p: Array = lz["posts"][i]
		_box_row(vs, ["box", "LaserPost%d" % i, [LC.LASER_X, fy, (float(p[0]) + float(p[1])) * 0.5],
			[0.12, 2.7, float(p[1]) - float(p[0])], 0.0, "laser_emitter", true, "trim"])
	var props: Dictionary = {"pattern": String(lz["pattern"]), "size_m": [z1 - z0, float(lz["h"]), 0.1],
		"enabled_at_start": true, "objective_tag": "laser_grid"}
	for k: String in ["beams", "sweep_beams", "period_s", "off_s"]:
		if lz.has(k):
			props["beam_count" if k == "beams" else k] = lz[k]
	var metas: Dictionary = (lz["metas"] as Dictionary).duplicate()
	metas["kind"] = "laser_grid"
	place_prefab(vs, ["prefab", "laser_grid", "VaultLasers", [LC.LASER_X, fy + float(lz["y"]), (z0 + z1) * 0.5], 90.0,
		props, null, metas, ""])


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
