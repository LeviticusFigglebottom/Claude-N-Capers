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
## 6 scalars and 8 rare events are table rows), the 4 ConvoyLayout placeholder sets, holdouts, perches S1-S4, preplan
## points, patrol graphs, assault markers, the navmesh (door_nav_clearance, _nav_thick). Greybox materials only; no
## lights but the sun and the sky.
extends "res://world/heists/rolling_thunder/greybox/rt_gameplay.gd"

const AM: GDScript = preload("res://world/heists/shared/assault_markers.gd")
const AE: GDScript = preload("res://world/heists/rolling_thunder/greybox/rt_assault.gd")
const NS: GDScript = preload("res://world/heists/shared/npc_seat_spawns.gd")
const DNC: GDScript = preload("res://world/heists/shared/door_nav_clearance.gd")
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
	for line: String in NS.snap(map_root):
		print("seat: " + line)
	_build_environment(n("Lighting"))
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


## G1 daylight: the sky and a low afternoon sun from the WSW (doc: 245 deg / 9 deg, straight down Tannery from the west;
## the G2 look pass sets the final colour, haze and LUT). No other lights at G1.
func _build_environment(lighting: Node3D) -> void:
	var we: WorldEnvironment = WorldEnvironment.new()
	we.set_script(load("res://world/lighting/heist_world_environment.gd"))  # brightness option (B5-01)
	we.name = "WorldEnvironment"
	var env: Environment = Environment.new()
	env.resource_name = "env_rolling_thunder_g1"
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.46, 0.66)
	sky_mat.sky_horizon_color = Color(0.78, 0.7, 0.58)
	sky_mat.ground_bottom_color = Color(0.2, 0.18, 0.16)
	sky_mat.ground_horizon_color = Color(0.7, 0.63, 0.53)
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	we.environment = env
	add(lighting, we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	# from azimuth 245 deg (WSW), 9 deg up: the light travels toward the ENE and slightly down
	var az: float = deg_to_rad(245.0)
	var alt: float = deg_to_rad(9.0)
	var to_sun: Vector3 = Vector3(sin(az) * cos(alt), sin(alt), -cos(az) * cos(alt))
	sun.basis = Basis.looking_at(-to_sun, Vector3.UP)
	sun.position = Vector3(0.0, 60.0, 0.0)
	sun.light_color = Color(1.0, 0.86, 0.68)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.layers = 1 | VIEWMODEL_LIT_LAYER   # D-095: every map light also lights the viewmodel
	add(lighting, sun)


## Walkable navmesh (heist_map.md §3: agent radius 0.3, height 1.8, climb 0.3, slope 40, cell 0.1 / 0.1) from the Geometry
## colliders minus the projected obstructions (furniture, catalog bodies, thin site bodies widened by _nav_thick, the
## culled tops nobody stands on: neighbour roofs, the rail bank, closure vehicles), with the door throats
## (door_nav_clearance.gd, as every map since ENV P's ghost run 250).
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
		src.add_projected_obstruction(o[0], float(o[1]), float(o[2]), o.size() > 3 and bool(o[3]))
	for c: Array in L.NAV_CULL:
		var r: Array = c[1]
		var pts: PackedVector3Array = PackedVector3Array([Vector3(float(r[0]), 0.0, float(r[1])),
			Vector3(float(r[2]), 0.0, float(r[1])), Vector3(float(r[2]), 0.0, float(r[3])),
			Vector3(float(r[0]), 0.0, float(r[3]))])
		src.add_projected_obstruction(pts, float(c[2]), float(c[3]), true)
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
		src.add_projected_obstruction(corners, bb.position.y, bb.size.y, false)
	print("door throats: %d doors" % DNC.add(src, map_root, nm))
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	holder.queue_free()
	await process_frame
	nav.navigation_mesh = nm
	return nm.get_polygon_count()
