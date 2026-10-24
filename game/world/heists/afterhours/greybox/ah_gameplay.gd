## Afterhours gameplay layer (AH-C1): the door table, every VariantSlot (resolver order, the doc's slot ids) with its
## content, the always-present prefabs (the office reader, the safes and their drill point, the tills, the drop ladder,
## containers, markers), NPC spawns, patrol graphs, tactical points and furniture. Owner: ENV C. Copy-adapted from
## rolling_thunder/greybox/rt_gameplay.gd (D-147; the convoy dropped); chain: ah_builder_base <- ah_shell <- ah_gameplay
## <- build_greybox. Prefabs are ENV A's (found by contract class name); visuals are catalog props (doors: the greybox
## door kit). Content rows: afterhours_layout_content.gd (afterhours_content.py).
extends "res://world/heists/afterhours/greybox/ah_shell.gd"

const LOCKPICK_S: float = 8.0
## Door bake-closed (D-073 / D-122): the projected obstruction fills the opening, +0.15 m into each jamb, 0.3 m each side.
const BAKE_DEPTH: float = 0.3
## Catalog visuals whose bodies block the bake.
const OBSTRUCT_KINDS: Array[String] = ["safe", "body_container", "secure_zone", "hack_terminal"]
## Minimum width of a thin body in the nav bake (see _nav_thick).
const RIG_NAV_MIN: float = 0.2
## The laser posts' depth along the grid and the catalog emitter column over them (OF's, SL-2).
const LASER_POST_D: float = 0.15
const LASER_COLUMN: String = "prop_laser_emitter_column"
## [node, property, names] bound once everything is built (targets).
var _binds: Array[Array] = []


# --- Items ----------------------------------------------------------------------------------------

## Builds one content row under `parent` (formats: afterhours_content.py header).
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


## A projected obstruction only marks the 0.1 m cells whose centre it covers, so a thin body (the stock cage's mesh,
## a queue rail) can fall between the centres and leave a walkable seam (OF: ShaftE). Widen each
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
	if c.size() > 4:   # optional yaw in the host's frame (a drill spot on the door face turns into it, GH's pattern)
		inst.basis = yaw_basis(float(c[4]))
	for k: Variant in (c[3] as Dictionary):
		if String(k) == "visual_path":   # a scene for the prefab's visual_scene (an empty one where the host shows it)
			inst.set(&"visual_scene", load(String(c[3][k])))
		else:
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
## roots: the sitter's root on the marker's xz, its height the cushion top). Each of several also carries a `Seat`
## child at its origin: CivilianTargets.seat_near (PO6-06) only finds nodes named exactly `Seat`.
func _seats(host: Node3D, rows: Array) -> void:
	for i: int in range(rows.size()):
		var m: Marker3D = Marker3D.new()
		m.name = "Seat" if rows.size() == 1 else "Seat%d" % i
		m.position = v3(rows[i])
		add(host, m)
		if rows.size() > 1:
			var c: Marker3D = Marker3D.new()
			c.name = "Seat"
			add(m, c)


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
## extra: kind (meta kind, default "door"), push_bar, npc (spawn tags a locked door
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
	if bool(extra.get("guest", false)):
		props["civilian_allowed"] = true   # D-075 guest doors: civilians (and the cased crew) pass
	if bool(extra.get("guest", false)) or bool(extra.get("casing", false)):
		props["casing_allowed"] = true   # the doc's stealth routes cross these unmasked (afterhours.md)
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
	if extra.has("opens_with"):   # the mission opens it with that event
		metas["opens_with"] = String(extra["opens_with"])
	var it: Array = ["prefab", "door", nm, d[2], float(d[3]), props, null, metas, String(d[6])]
	var inst: Node3D = place_prefab(parent, it)
	if lock == "BARRED":   # D-073 / D-122: baked closed; the door's NavLink bridges it once open (OF bake_closed)
		# (a width_m wider than the kind's frame wins)
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
			if String(it[0]) == "prefab" and String(it[1]) == "laser_grid":
				_laser_rig(vs, it)
			else:
				build_item(vs, it)
		if LC.SLOT_DOORS.has(sid):
			for nm: String in LC.SLOT_DOORS[sid]:
				for d: Array in LC.DOORS:
					if String(d[0]) == nm:
						door(vs, d, nm, String(LC.SLOT_DOORS[sid][nm]), d[8])


## A laser grid (yaw 90: its local X along -z) between its emitter / receiver posts, as OF's vault grid: each post a
## 0.12 x 2.7 x 0.15 collider just past the beams' ends under the catalog emitter column (lens turned to the other
## post; the static grid's south end is its bypass gap, so only the emitter); the grid hangs off its emitter post (G3
## validate final: the beams-only visual floated on its own).
func _laser_rig(vs: Node3D, it: Array) -> void:
	var c: Vector3 = v3(it[3])
	var half: float = float((it[5] as Dictionary)["size_m"][0]) * 0.5
	var post0: Node3D = vs
	var ends: int = 1 if String((it[5] as Dictionary)["pattern"]) == "static" else 2   # the static grid's +z end: the gap
	for i: int in range(ends):
		var z: float = c.z + (half + LASER_POST_D * 0.5) * (-1.0 if i == 0 else 1.0)
		var post: StaticBody3D = _box_row(vs, ["box", "LaserPost%d" % i, [c.x, c.y, z], [0.12, 2.7, LASER_POST_D], 0.0,
			"laser_emitter", true, "trim", {}])
		var mesh: Node = post.get_node_or_null(^"Mesh")
		if mesh != null:
			post.remove_child(mesh)
			mesh.free()
		var ps: PackedScene = catalog_scene(LASER_COLUMN)
		if ps != null:
			var column: Node3D = ps.instantiate() as Node3D
			column.name = "Column"
			column.basis = yaw_basis(-90.0 if i == 0 else 90.0)
			add(post, column)
		if i == 0:
			post0 = post
	place_prefab(post0, it)


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
