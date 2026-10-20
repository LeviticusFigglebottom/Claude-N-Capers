## Ostrander Federal G1 greybox generator (OF-C1). Owner: ENV C. Writes res://world/heists/ostrander_federal/
## ostrander_federal.tscn (+ the HeistDef / variant table .tres from ostrander_federal_resources.gd, ENV B's values).
## Regenerate (deterministic; never hand-edit the output):
##   /opt/godot/godot --headless --path game --script res://world/heists/ostrander_federal/greybox/build_greybox.gd \
##     -- --out=<path>            (default res://world/heists/ostrander_federal/ostrander_federal.tscn; a scratch --out
##                                 skips the .tres writes)
## Data: ostrander_federal_layout.gd + ostrander_federal_layout_content.gd, emitted by tools/levelcheck/plans/
## ostrander_federal_emit_layout.py from the plan scripts (--check). Design: docs/design/heists/ostrander_federal.md
## (APPROVED D-075; D-136 build notes); next_heist_ostrander.md §3b / §4 / §7. Contracts: heist_map.md v1.2.
## Built: the 5 levels' shell (walls with every opening, glass, slabs with the stair / void / lantern / lid holes,
## ceilings, the counter, the gallery guard, the loggias, copings), stairs A / B (U-stairs, ramp colliders), the lantern,
## the Corvino fire escape, the site (grade, the plaza steps, the Tannery ramp, police islands, closures, neighbours),
## RoomVolumes, PUBLIC / RESTRICTED / OUT_OF_BOUNDS zones, player / police spawns, preplan points, review cameras, every
## VariantSlot with its content, cameras C1-C16, doors, prefabs, NPC spawns, patrol graphs, tactical points, assault
## markers, the navmesh. Greybox materials only (G1); no interior lights (the sun and the sky only).
extends "res://world/heists/ostrander_federal/greybox/of_gameplay.gd"

const AM: GDScript = preload("res://world/heists/shared/assault_markers.gd")
const AE: GDScript = preload("res://world/heists/ostrander_federal/greybox/of_assault.gd")
const NS: GDScript = preload("res://world/heists/shared/npc_seat_spawns.gd")
const OF_GI: GDScript = preload("res://world/heists/ostrander_federal/greybox/of_gi.gd")


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
	map_root.name = "OstranderFederal"
	map_root.heist_def = load(DEF_PATH) as HeistDef
	map_root.variant_table = load(VARIANTS_PATH) as HeistVariantTable
	if map_root.heist_def == null or map_root.variant_table == null:
		_fail("missing %s or %s (run without --out first)" % [DEF_PATH, VARIANTS_PATH])
		return
	map_root.floor_heights = PackedFloat32Array(L.FLOOR_HEIGHTS)
	map_root.floor_names = PackedStringArray(L.FLOOR_NAMES)
	map_root.set_meta(&"camera_spine_rooms", PackedStringArray(L.CAMERA_SPINE_ROOMS))
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
	mission.set_script(load(MISSION_PATH))   # G1 stub (OF-C1); ENV A owns and completes it (OF-A6)
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
	load("res://world/heists/ostrander_federal/greybox/of_dress.gd").new().call(&"run", self)  # OF-C2 lane C (G2)
	for line: String in NS.snap(map_root):
		print("seat: " + line)
	_build_environment(n("Lighting"))
	preload("res://world/heists/ostrander_federal/greybox/of_art_rooms.gd").new(self).call(&"build")  # OF-C2 lane B
	OF_GI.new(self).call(&"build")  # OF-C2 lighting lane: VoxelGI bands, reflection probes, occluders
	preload("res://world/heists/ostrander_federal/greybox/of_skyline.gd").new(self).call(&"build")  # OF-C2 skyline lane
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
	print("ostrander_federal: saved %s (navmesh polygons: %d)" % [out, polys])
	quit(0)


## Breach rows (layout ASSAULT_BREACHES) with the Vector3 / Vector2 fields assault_markers.gd reads.
static func _breaches() -> Array:
	var out: Array = []
	for b: Array in L.ASSAULT_BREACHES:
		var row: Array = [b[0], b[1], b[2], v3(b[3]), float(b[4]), Vector2(float(b[5][0]), float(b[5][1])), b[6], float(b[7])]
		if b.size() > 8:
			row.append(b[8])
		out.append(row)
	return out


## HeistDef + variant table from ENV B's values block (ostrander_federal_resources.gd), byte-stable.
func _write_resources() -> bool:
	for pair: Array in [[DEF_PATH, R.make_def()], [VARIANTS_PATH, R.make_variants()]]:
		var path: String = String(pair[0])
		var old_uid: String = _read_uid(path)
		var res: Resource = pair[1]
		res.resource_path = ""
		if ResourceSaver.save(res, path) != OK:
			_fail("cannot save %s" % path)
			return false
		normalize_scene(path, old_uid)
	return true


func _fail(msg: String) -> void:
	push_error("ostrander_federal: " + msg)
	if map_root != null and is_instance_valid(map_root):
		map_root.free()
	quit(1)


## The final 15:10 environment + LUT and the cloud-shadow sun (OF-C2 lighting lane: of_gi.gd environment()).
func _build_environment(lighting: Node3D) -> void:
	OF_GI.new(self).call(&"environment", lighting)


## Walkable navmesh (heist_map.md §3: agent radius 0.3, height 1.8, climb 0.3, slope 40, cell 0.1 / 0.1) from the Geometry
## colliders minus the projected obstructions (furniture, catalog bodies, the baked-closed doorways: D-073 / D-122).
func _bake(nav: NavigationRegion3D) -> int:
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
	var holder: Node3D = Node3D.new()
	holder.name = "BakeSource"
	holder.add_child(map_root.get_node("Geometry").duplicate())
	get_root().add_child(holder)
	await physics_frame
	var src: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, holder)
	for o: Array in obstructions:
		src.add_projected_obstruction(o[0], float(o[1]), float(o[2]), false)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	holder.queue_free()
	await process_frame
	nav.navigation_mesh = nm
	return nm.get_polygon_count()
