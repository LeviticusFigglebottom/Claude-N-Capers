## Afterhours shell, site and the room / zone / spawn / preplan / review-camera contract nodes (AH-C1). Owner: ENV C.
## Copy-adapted from rolling_thunder/greybox/rt_shell.gd (D-147). Chain: ah_builder_base <- ah_shell <- ah_gameplay <-
## build_greybox. Everything is instantiated from the emitted primitives (afterhours_layout.gd, tools/levelcheck/plans/
## afterhours_geometry.py): the Velvet's walls with every door / window opening, slabs, ceilings, the stage riser and
## guards, the two stair cores (ramp colliders + handrails), the grade, neighbours, closures and landmarks.
extends "res://world/heists/afterhours/greybox/ah_builder_base.gd"

## Police spawns face the club (their -Z toward this point).
const POLICE_FACE: Vector3 = Vector3(18.0, 0.0, 14.0)


# --- Building shell ---------------------------------------------------------------------------------

func build_shell(geo: Node3D) -> void:
	var bld: Node3D = add(geo, node3d("Building")) as Node3D
	var walls_n: Node3D = add(bld, node3d("Walls")) as Node3D
	var lv: Dictionary = {}
	var counts: Dictionary = {}
	for w: Array in L.WALLS:
		var b: String = String(w[0])
		if not lv.has(b):
			lv[b] = add(walls_n, node3d("Walls" + b))
		var axis: String = String(w[1])
		var key: String = "%s%s%05d" % [b, axis.to_upper(), int(round(float(w[2]) * 10.0)) + 10000]
		counts[key] = int(counts.get(key, -1)) + 1
		wall(lv[b], "%s_%d" % [key, counts[key]], axis, float(w[2]), float(w[3]), float(w[4]), float(w[5]),
			Vector2(float(w[6]), float(w[7])), w[9], String(w[8]))
	var glass: Node3D = add(walls_n, node3d("Glass")) as Node3D
	for p: Array in L.PANES:
		box(glass, String(p[0]), v3(p[1]), v3(p[2]), "glass")
	var slabs: Node3D = add(bld, node3d("Slabs")) as Node3D
	for s: Array in L.SLABS:
		var rects: Array = rects_minus(s[1], s[2])
		for i: int in range(rects.size()):
			var r: Array = rects[i]
			box(slabs, "%s_%02d" % [String(s[0]), i], Vector3(float(r[0]), float(s[3]), float(r[1])),
				Vector3(float(r[2]), float(s[4]), float(r[3])), String(s[5]))
	var ceil_n: Node3D = add(bld, node3d("Ceilings")) as Node3D
	for c: Array in L.CEILINGS:
		var q: Array = c[1]
		box(ceil_n, String(c[0]), Vector3(float(q[0]), float(c[2]), float(q[1])),
			Vector3(float(q[2]), float(c[2]) + L.CEIL_T, float(q[3])), "ceiling")
	var groups: Dictionary = {}
	for b2: Array in L.SHELL_BOXES:
		var g: String = String(b2[0])
		if not groups.has(g):
			groups[g] = add(bld, node3d(g))
		box(groups[g], String(b2[1]), v3(b2[2]), v3(b2[3]), String(b2[4]))
	for h: Array in L.HULLS:
		var hg: String = String(h[0])
		var parent: Node3D = geo.get_node_or_null("Site/Grade") as Node3D if hg == "Grade" else null
		if parent == null:
			if not groups.has(hg):
				groups[hg] = add(bld, node3d(hg))
			parent = groups[hg]
		hull(parent, String(h[1]), h[2], h[3], String(h[4]))
	var stairs: Node3D = add(bld, node3d("StairFlights")) as Node3D
	for fl: Array in L.FLIGHTS:
		flight(stairs, String(fl[0]), v3(fl[1]), float(fl[2]), float(fl[3]), int(fl[4]), float(fl[5]), float(fl[6]))
	for hr: Array in L.HANDRAILS:
		handrail(stairs, String(hr[0]), v3(hr[1]), v3(hr[2]))


## Rectangle [x0, z0, x1, z1] minus holes -> merged rectangles (deterministic; OF / RT rects_minus).
static func rects_minus(outer: Array, holes_in: Array) -> Array:
	var xs: Array[float] = [float(outer[0]), float(outer[2])]
	var zs: Array[float] = [float(outer[1]), float(outer[3])]
	for h: Array in holes_in:
		for v: float in [float(h[0]), float(h[2])]:
			if v > xs[0] and v < xs[1] and not xs.has(v):
				xs.append(v)
		for w: float in [float(h[1]), float(h[3])]:
			if w > zs[0] and w < zs[1] and not zs.has(w):
				zs.append(w)
	xs.sort()
	zs.sort()
	var out: Array = []
	var open: Dictionary = {}
	for j: int in range(zs.size() - 1):
		var runs: Array = []
		var start: float = NAN
		for i: int in range(xs.size() - 1):
			var cx: float = (xs[i] + xs[i + 1]) * 0.5
			var cz: float = (zs[j] + zs[j + 1]) * 0.5
			var inside: bool = false
			for h2: Array in holes_in:
				if cx > float(h2[0]) and cx < float(h2[2]) and cz > float(h2[1]) and cz < float(h2[3]):
					inside = true
					break
			if not inside and is_nan(start):
				start = xs[i]
			if inside and not is_nan(start):
				runs.append([start, xs[i]])
				start = NAN
		if not is_nan(start):
			runs.append([start, xs[xs.size() - 1]])
		var nxt: Dictionary = {}
		for run: Array in runs:
			var key: String = "%.4f|%.4f" % [float(run[0]), float(run[1])]
			nxt[key] = [float(run[0]), open[key][1] if open.has(key) else zs[j], float(run[1]), zs[j + 1]]
		for k: String in open:
			if not nxt.has(k):
				out.append(open[k])
		open = nxt
	for k2: String in open:
		out.append(open[k2])
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1] or (a[1] == b[1] and a[0] < b[0]))
	return out


## Neighbours, closures and landmarks (Site table; the grade is a SLABS row).
func build_site(geo: Node3D) -> void:
	var site: Node3D = add(geo, node3d("Site")) as Node3D
	var groups: Dictionary = {}
	for b: Array in L.SITE_BOXES:
		var g: String = String(b[0])
		if not groups.has(g):
			groups[g] = add(site, node3d(g))
		box(groups[g], String(b[1]), v3(b[2]), v3(b[3]), String(b[4]))


# --- Rooms, zones, spawns, preplan, review cameras --------------------------------------------------

func build_rooms(rooms: Node3D) -> void:
	for r: Array in L.ROOMS:
		_room(rooms, String(r[0]), String(r[1]), String(r[3]), int(r[2]), r[4])


func _room(rooms: Node3D, uid: String, purpose: String, kit: String, fidx: int, boxes: Array) -> RoomVolume:
	var rv: RoomVolume = RoomVolume.new()
	rv.name = "Room" + uid.replace("-", "")
	rv.room_id = StringName(uid)
	rv.purpose = StringName(purpose)
	rv.dressing_kit = StringName(kit)
	rv.floor_index = fidx
	rv.collision_layer = 1 << 9
	rv.collision_mask = 0
	rv.monitoring = false
	add(rooms, rv)
	_area_boxes(rv, boxes)
	return rv


## PUBLIC (the guest side, the streets, the alley, the smokers' passage), RESTRICTED (the back of house, the VIP side, the
## staff wing, the BOH roof), OUT_OF_BOUNDS curtains beyond the closures (D-040).
func build_zones(zones: Node3D) -> void:
	zone(zones, "Public", "PUBLIC", "ah_public", L.ZONES["public"])
	zone(zones, "Restricted", "RESTRICTED", "ah_restricted", L.ZONES["restricted"])
	for o: Array in L.OOB:
		zone(zones, String(o[0]), "OUT_OF_BOUNDS", "oob_" + String(o[0]).to_lower(), [o[1]])


func build_spawns(spawns: Node3D) -> void:
	for p: Array in LC.PLAYER_SPAWNS:
		var tags: Array = [] if String(p[1]) == "" else [String(p[1])]
		spawn(spawns, String(p[0]), "PLAYER", v3(p[2]), float(p[3]), tags, "")
	for c: Array in LC.POLICE_SPAWNS:
		var pos: Vector3 = v3(c[2])
		var to: Vector3 = pos - POLICE_FACE
		var yaw: float = rad_to_deg(atan2(to.x, to.z))   # -Z faces the club
		spawn(spawns, String(c[0]), "POLICE", pos, yaw, [String(c[1])], "")


func build_nav_links(nav: NavigationRegion3D) -> void:
	for l: Array in L.NAV_LINKS:
		var link: NavigationLink3D = NavigationLink3D.new()
		link.name = String(l[0])
		link.start_position = v3(l[1])
		link.end_position = v3(l[2])
		link.bidirectional = bool(l[3])
		link.navigation_layers = int(l[4])
		add(nav, link)


## PREPLAN_POINT markers (preplanning.md): node name = point id; metas category / label / floor / params.
func build_preplan(pre: Node3D) -> void:
	for p: Array in LC.PREPLAN:
		var m: Marker3D = Marker3D.new()
		m.name = String(p[0])
		m.position = v3(p[3])
		m.set_meta(&"category", StringName(String(p[1])))
		m.set_meta(&"label", StringName("ui.preplan.point.afterhours." + String(p[0])))
		m.set_meta(&"floor", int(p[2]))
		var params: Dictionary = {}
		for k: String in (p[4] as Dictionary):
			params[k] = StringName(String(p[4][k]))
		m.set_meta(&"params", params)
		m.add_to_group(G.PREPLAN_POINT, true)
		add(pre, m)


func build_review_cameras(cams: Node3D) -> void:
	var paths: Array[NodePath] = []
	for c: Array in LC.REVIEW_CAMERAS:
		var m: Marker3D = Marker3D.new()
		var nm: String = String(c[0])
		m.name = nm
		var pos: Vector3 = v3(c[2])
		var dir: Vector3 = v3(c[3]) - pos
		var up: Vector3 = Vector3.FORWARD if absf(dir.normalized().dot(Vector3.UP)) > 0.99 else Vector3.UP
		m.position = pos
		m.basis = Basis.looking_at(dir, up)
		if nm.begins_with("TopDown"):
			m.set_meta(&"size", 100.0)
		else:
			m.set_meta(&"fov", 70.0)
		m.set_meta(&"caption", "%s (%s)" % [nm, String(c[1])])
		add(cams, m)
		paths.append(NodePath("ReviewCameras/" + nm))
	map_root.review_cameras = paths
