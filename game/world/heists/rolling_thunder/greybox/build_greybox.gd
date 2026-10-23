## Rolling Thunder G1 greybox generator (RT-C1). Owner: ENV C. Writes res://world/heists/rolling_thunder/
## rolling_thunder.tscn (+ the HeistDef / variant table .tres from rolling_thunder_resources.gd: ENV B's values; until
## B's RT-B1 block lands that file carries only ruled / doc numbers, see its header).
## Regenerate (deterministic; never hand-edit the output):
##   /opt/godot/godot --headless --path game --script res://world/heists/rolling_thunder/greybox/build_greybox.gd \
##     -- --out=<path>            (default res://world/heists/rolling_thunder/rolling_thunder.tscn; a scratch --out
##                                 skips the .tres writes)
## Data: rolling_thunder_layout.gd + rolling_thunder_layout_content.gd, emitted by tools/levelcheck/plans/
## rolling_thunder_emit_layout.py (--check) from the plan scripts. Design: docs/design/heists/rolling_thunder.md
## (G0 APPROVED, D-075; D-149 build rulings); docs/process/next_heist_rolling_thunder.md §4 / §6 / §7. Contracts:
## heist_map.md v1.4. Copy-adapted from the Ostrander Federal chain (D-147).
## Built (G1 milestone): the site (grade, the junction, the Skyway deck and piers, the east trench and underpass, the
## rail bank, the hoarding and its gates, closures, neighbours, play-space OOB), the shells of every level (car park x3,
## diner x2, the site cabins, magazine, frame + slab, scaffold tower) with every opening, stairs and ramps, RoomVolumes,
## PUBLIC / RESTRICTED / OUT_OF_BOUNDS zones, player / police spawns, police entries (breach_only on buildings), doors
## (route doors 1.0 m: the service kit), the contract nodes, review cameras, VariantSlots for the 12 slot groups (the
## 6 scalars and 8 rare events are table rows), the convoy (RT-C2: A5-02 movers + paths, the 4 layouts), holdouts,
## perches S1-S4, preplan points, patrol graphs, assault markers, the navmesh (door_nav_clearance, _nav_thick). Lighting: rt_gi.gd (the
## final environment + LUT, the sun, the fixtures' daylight state, VoxelGI, probes, occluders, the render policy).
## G2 (RT-C2 batch 1, reuse-first): rt_dress.gd (kit rooms, map-built art, street furniture) and rt_finish.gd (library
## finishes on every shell surface), both before the bake; rt_skyline.gd (the city round the site, visual only).
extends "res://world/heists/rolling_thunder/greybox/rt_gameplay.gd"

const AM: GDScript = preload("res://world/heists/shared/assault_markers.gd")
const AE: GDScript = preload("res://world/heists/rolling_thunder/greybox/rt_assault.gd")
const NS: GDScript = preload("res://world/heists/shared/npc_seat_spawns.gd")
const DNC: GDScript = preload("res://world/heists/shared/door_nav_clearance.gd")
const RT_GI: GDScript = preload("res://world/heists/rolling_thunder/greybox/rt_gi.gd")
## P's RT G1 real-input pass (r278): a HEAVY bag carrier pinned twice on Strip2GuardW2's south end; the bake erodes
## by the 0.3 m agent radius, the crew capsule is 0.35 m. The deck-2 strip guards' obstruction is grown by this much,
## so the navmesh keeps 0.4 m off them and round their ends.
const GUARD_PAD_PREFIX: String = "Strip2Guard"
const GUARD_NAV_PAD: float = 0.1
const AUDIO_BUILDER: String = "res://world/audio/map_audio_builder.gd"
## [node name, position, cue id, volume offset dB] (origin: the junction; +z south).
const AUDIO_BEDS: Array = [
	["BedJunction", Vector3(0.0, 2.0, 0.0), &"cue.amb_skyway_street", 0.0],
	["BedOrchardN", Vector3(0.0, 2.0, -45.0), &"cue.amb_skyway_street", -1.0],
	["BedOrchardFarN", Vector3(0.0, 2.0, -80.0), &"cue.amb_skyway_street", -3.0],
	["BedOrchardS", Vector3(0.0, 2.0, 45.0), &"cue.amb_skyway_street", -2.0],
	["BedPlaza", Vector3(-38.0, 1.5, 20.0), &"cue.amb_skyway_street", -2.0],
	["BedTanneryW", Vector3(-45.0, 1.5, 0.0), &"cue.amb_skyway_street", -3.0],
	["BedTanneryE", Vector3(30.0, 1.5, 0.0), &"cue.amb_skyway_street", -3.0],
	["BedRailLane", Vector3(58.0, 1.5, -50.0), &"cue.amb_skyway_street", -5.0],
	["BedCarParkGround", Vector3(34.0, 1.5, -32.0), &"cue.amb_skyway_street", -6.0],
	["BedCarParkDeck2", Vector3(34.0, 5.0, -32.0), &"cue.amb_skyway_street", -5.0],
	["BedCarParkRoof", Vector3(34.0, 8.5, -32.0), &"cue.amb_skyway_street", -2.0],
	["BedRamp", Vector3(52.0, -2.0, 0.0), &"cue.amb_underpass", -6.0],
	["BedUnderpass", Vector3(75.0, -3.5, 0.0), &"cue.amb_underpass", 0.0],
	["BedEastCut", Vector3(95.0, -3.5, 0.0), &"cue.amb_underpass", -2.0],
	["BedDiner", Vector3(24.0, 1.5, 23.0), &"cue.amb_diner", 0.0],
	["BedDinerUpper", Vector3(24.0, 5.0, 23.0), &"cue.amb_diner", -8.0],
	["BedSite", Vector3(-37.0, 1.5, -34.0), &"cue.amb_site", 0.0],
	["BedSiteNorth", Vector3(-37.0, 1.5, -52.0), &"cue.amb_site", -3.0],
	["BedSiteFrameUpper", Vector3(-37.0, 5.0, -34.0), &"cue.amb_site", -3.0],
]
## Site groups whose thin bodies (< 2 nav cells) are widened in the bake (the F1 edge protection, the scaffold mesh,
## the palisades and rail-lane fences).
const THIN_GROUPS: Array[String] = ["Frame", "Scaffold", "Rail", "RailLane"]


func _initialize() -> void:
	_build.call_deferred()


static func _scene_out() -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			return a.trim_prefix("--out=")
	return SCENE_PATH


func _build() -> void:
	var out: String = _scene_out()
	if out == SCENE_PATH and not _write_resources():
		return
	var old_scene_uid: String = _read_uid(out)
	map_root = HeistMap.new()
	map_root.name = "RollingThunder"
	map_root.heist_def = load(DEF_PATH) as HeistDef
	map_root.variant_table = load(VARIANTS_PATH) as HeistVariantTable
	if map_root.heist_def == null or map_root.variant_table == null:
		_fail("missing %s or %s (run without --out first)" % [DEF_PATH, VARIANTS_PATH])
		return
	map_root.floor_heights = PackedFloat32Array(L.FLOOR_HEIGHTS)
	map_root.floor_names = PackedStringArray(L.FLOOR_NAMES)
	for mk: String in LC.MAP_METAS:
		map_root.set_meta(StringName(mk), LC.MAP_METAS[mk])
	for nm: String in ["Geometry", "Props", "Lighting"]:
		add(map_root, node3d(nm))
	var nav: NavigationRegion3D = NavigationRegion3D.new()
	nav.name = "Navigation"
	nav.navigation_layers = 1
	add(map_root, nav)
	for nm2: String in ["Zones", "Rooms", "Spawns", "Patrols", "Tactical", "Gameplay", "Variants"]:
		add(map_root, node3d(nm2))
	var mission: Node = Node.new()
	mission.name = "Mission"
	mission.set_script(load(MISSION_PATH))   # G1 stub (RT-C1); ENV A owns and completes it (RT-A6)
	add(map_root, mission)
	add(map_root, node3d("Preplan"))
	add(map_root, node3d("ReviewCameras"))
	build_site(n("Geometry"))
	build_shell(n("Geometry"))
	build_rooms(n("Rooms"))
	build_zones(n("Zones"))
	build_spawns(n("Spawns"))
	build_preplan(n("Preplan"))
	build_review_cameras(n("ReviewCameras"))
	build_graphs(n("Patrols"))
	for nm3: String in ["Doors", "Devices", "Loot", "Lifts", "Ladders", "Containers", "Markers", "Lines"]:
		add(n("Gameplay"), node3d(nm3))
	build_doors(n("Gameplay/Doors"))
	build_always()
	build_npcs_and_tactical()
	build_variants(n("Variants"))
	build_lines(n("Gameplay/Lines"))
	bind_targets()
	errors.append_array(AM.build(map_root, AE.TURRET_VANS, AE.HELI_ORBITS, AE.HELI_DROPS, [], _breaches(), obstructions))
	build_nav_links(nav)
	load("res://world/heists/rolling_thunder/greybox/rt_dress.gd").new().call(&"run", self)  # RT-C2 dressing (G2)
	for line: String in NS.snap(map_root):
		print("seat: " + line)
	_build_environment(n("Lighting"))
	preload("res://world/heists/rolling_thunder/greybox/rt_finish.gd").new(self).call(&"build")  # RT-C2 finishes (G2)
	preload("res://world/heists/rolling_thunder/greybox/rt_skyline.gd").new(self).call(&"build")  # RT-C2 skyline (G2)
	var marks: int = preload("res://world/heists/rolling_thunder/greybox/rt_markings.gd").new(self).call(&"build")
	print("rt_markings: %d quads" % marks)  # RT-C2 G3 road markings (LEAD r305)
	var fac: Dictionary = preload("res://world/heists/rolling_thunder/greybox/rt_facades.gd").new(self).call(&"build")
	print("rt_facades: %s" % fac)  # RT-C2 G3 near facades + the Skyway soffit (LEAD r305)
	RT_GI.new(self).call(&"build")  # RT-C2 lighting lane: fixtures, VoxelGI, probes, occluders, render policy
	_build_audio()  # RT-C2 audio lane (D-117)
	var polys: int = await _bake(nav)
	if polys <= 0:
		_fail("navmesh bake produced no polygons")
		return
	for untagged: String in SurfaceTags.tag_tree(map_root):  # PO-8 / D-105: refuse untagged bodies
		errors.append("no surface id for %s" % untagged)
	if not errors.is_empty():
		_fail("\n".join(errors))
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out).get_base_dir())
	var ps: PackedScene = PackedScene.new()
	var err: int = ps.pack(map_root)
	if err == OK:
		err = ResourceSaver.save(ps, out)
	map_root.free()
	if err != OK:
		_fail("cannot save %s (%d)" % [out, err])
		return
	normalize_scene(out, old_scene_uid)
	print("rolling_thunder: saved %s (navmesh polygons: %d; RT plan §7.15 early warning 3,500)" % [out, polys])
	quit(0)


## Breach rows (rt_assault.gd BREACHES) as assault_markers.gd reads them.
static func _breaches() -> Array:
	var out: Array = []
	for b: Array in AE.BREACHES:
		out.append(b.duplicate())
	return out


## HeistDef + variant table from rolling_thunder_resources.gd (ENV B's values), byte-stable.
func _write_resources() -> bool:
	for pair: Array in [[DEF_PATH, R.make_def()], [VARIANTS_PATH, R.make_variants()]]:
		var path: String = String(pair[0])
		var old_uid: String = _read_uid(path)
		var res: Resource = pair[1]
		res.resource_path = ""
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
		if ResourceSaver.save(res, path) != OK:
			_fail("cannot save %s" % path)
			return false
		normalize_scene(path, old_uid)
	return true


func _fail(msg: String) -> void:
	push_error("rolling_thunder: " + msg)
	if map_root != null and is_instance_valid(map_root):
		map_root.free()
	quit(1)


## The final 16:50 environment + LUT and the low WSW sun (RT-C2 lighting lane: rt_gi.gd environment()).
func _build_environment(lighting: Node3D) -> void:
	RT_GI.new(self).call(&"environment", lighting)


## D-117 `Audio` node (as the other heists): the CuePlayer, the rolling_thunder MusicDirector and the ambience beds
## (map_audio_builder.gd; CueEmitter beds: 40 m max distance, so about 35-45 m apart). The car park has no bed of its
## own (doc §Audio/lighting): the street bed turned down.
func _build_audio() -> void:
	var audio: Node3D = map_root.get_node_or_null("Audio") as Node3D
	if audio == null:
		audio = add(map_root, node3d("Audio")) as Node3D
	load(AUDIO_BUILDER).call(&"build", audio, map_root, &"rolling_thunder", AUDIO_BEDS)


## Walkable navmesh (heist_map.md §3: agent radius 0.3, height 1.8, climb 0.3, slope 40, cell 0.1 / 0.1) from the Geometry
## colliders minus the projected obstructions (furniture, catalog bodies, thin site bodies widened by _nav_thick, the
## culled tops nobody stands on: neighbour roofs, the rail bank, closure vehicles), with the door throats
## (door_nav_clearance.gd, as every map since ENV P's ghost run 250).
## RT-C2 convoy (D-149.1, pre-baked nav per convoy layout, swapped at the stop): the source geometry is parsed once and
## reused. `Navigation` is the open road before the stop (meta `convoy_open_nav` = "convoy": ConvoyLayouts turns it off
## while a convoy layout is active), with the movers' upstream footprints kept clear; `_bake_convoy` bakes each layout.
func _bake(nav: NavigationRegion3D) -> int:
	var nm: NavigationMesh = _nav_mesh()
	var holder: Node3D = Node3D.new()
	holder.name = "BakeSource"
	holder.add_child(map_root.get_node("Geometry").duplicate())
	get_root().add_child(holder)
	await physics_frame
	var t0: int = Time.get_ticks_msec()
	var base: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, base, holder)
	for o: Array in obstructions:
		base.add_projected_obstruction(o[0], float(o[1]), float(o[2]), o.size() > 3 and bool(o[3]))
	for c: Array in L.NAV_CULL:
		var r: Array = c[1]
		var pts: PackedVector3Array = PackedVector3Array([Vector3(float(r[0]), 0.0, float(r[1])),
			Vector3(float(r[2]), 0.0, float(r[1])), Vector3(float(r[2]), 0.0, float(r[3])),
			Vector3(float(r[0]), 0.0, float(r[3]))])
		base.add_projected_obstruction(pts, float(c[2]), float(c[3]), true)
	for b: Array in L.SITE_BOXES:
		if not (String(b[0]) in THIN_GROUPS):
			continue
		var mn: Vector3 = v3(b[2])
		var mx: Vector3 = v3(b[3])
		var sz: Vector3 = mx - mn
		if minf(sz.x, sz.z) >= RIG_NAV_MIN:
			continue
		var bb: AABB = _nav_thick(AABB(mn, sz))
		var corners: PackedVector3Array = PackedVector3Array()
		for k: Vector3 in [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]:
			corners.append(bb.position + bb.size * k)
		base.add_projected_obstruction(corners, bb.position.y, bb.size.y, false)
	for h: Array in L.HULLS:   # P's RT G1 real-input pass: the strip guards kept the crew capsule's distance
		if String(h[1]).begins_with(GUARD_PAD_PREFIX):
			var gb: AABB = AABB(v3(h[2][0]), Vector3.ZERO)
			for q: Array in h[2]:
				gb = gb.expand(v3(q))
			gb = AABB(gb.position - Vector3(GUARD_NAV_PAD, 0.0, GUARD_NAV_PAD),
				gb.size + Vector3(GUARD_NAV_PAD, 0.0, GUARD_NAV_PAD) * 2.0)
			var gc: PackedVector3Array = PackedVector3Array()
			for k: Vector3 in [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]:
				gc.append(gb.position + gb.size * k)
			base.add_projected_obstruction(gc, gb.position.y, gb.size.y, false)
	print("door throats: %d doors" % DNC.add(base, map_root, nm))
	holder.queue_free()
	var t_parse: int = Time.get_ticks_msec() - t0
	var t1: int = Time.get_ticks_msec()
	NavigationServer3D.bake_from_source_geometry_data(nm, _src_with(base, convoy_start_obs))
	var t_main: int = Time.get_ticks_msec() - t1
	await process_frame
	nav.navigation_mesh = nm
	nav.set_meta(&"convoy_open_nav", "convoy")
	var t2: int = Time.get_ticks_msec()
	var counts: PackedStringArray = _bake_convoy(base)
	print("navmesh bake: parse %d ms, main %d ms (%d polygons), convoy layouts %d ms: %s" % [t_parse, t_main,
		nm.get_polygon_count(), Time.get_ticks_msec() - t2, ", ".join(counts)])
	return nm.get_polygon_count()


## The map's NavigationMesh settings (heist_map.md §3).
static func _nav_mesh() -> NavigationMesh:
	var nm: NavigationMesh = NavigationMesh.new()
	nm.agent_radius = 0.3
	nm.agent_height = 1.8
	nm.agent_max_climb = 0.3
	nm.agent_max_slope = 40.0
	nm.cell_size = 0.1
	nm.cell_height = 0.1
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	return nm


## A copy of the parsed `base` plus the projected obstructions `obs` ([corners, elevation, height, carve]).
static func _src_with(base: NavigationMeshSourceGeometryData3D, obs: Array) -> NavigationMeshSourceGeometryData3D:
	var s: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	s.set_vertices(base.get_vertices())
	s.set_indices(base.get_indices())
	s.set_projected_obstructions(base.get_projected_obstructions())
	for o: Array in obs:
		s.add_projected_obstruction(o[0], float(o[1]), float(o[2]), o.size() > 3 and bool(o[3]))
	return s


## D-149.1 per layout: `NavConvoy`, the whole map's navmesh as it stands once that layout's vehicles have stopped (the
## same source as `Navigation`, the movers gone from upstream, the layout's stopped vehicles as normal agent-radius-grown
## obstructions, RearStop2 with T3 and Rear so trucks_2 stays clear). Authored disabled: ConvoyLayouts turns it on and
## `Navigation` off at the stop, so no two regions ever overlap and there is no seam to connect. (A junction-box pair
## per layout, carved from the main mesh, did not connect in Godot 4.7: the boxes' long border edges got no edge
## connections to the carved main edges.) Returns "<layout> <polygons>" per bake.
func _bake_convoy(base: NavigationMeshSourceGeometryData3D) -> PackedStringArray:
	var counts: PackedStringArray = PackedStringArray()
	for e: Dictionary in convoy_bake:
		for lay: Dictionary in e["layouts"]:
			var st: Node3D = lay["node"]
			var mesh: NavigationMesh = _nav_mesh()
			NavigationServer3D.bake_from_source_geometry_data(mesh, _src_with(base, lay["obs"]))
			var r: NavigationRegion3D = NavigationRegion3D.new()
			r.name = "NavConvoy"
			r.navigation_layers = 1
			r.navigation_mesh = mesh
			r.enabled = false
			add(st, r)
			r.transform = global_xform(st).affine_inverse()   # the mesh is in world space
			counts.append("%s %d" % [lay["id"], mesh.get_polygon_count()])
	return counts
