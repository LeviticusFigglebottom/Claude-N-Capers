## Afterhours G1 greybox generator (AH-C1). Owner: ENV C. Writes res://world/heists/afterhours/afterhours.tscn (+ the
## HeistDef / variant table .tres from afterhours_resources.gd: ENV B's values block, D-143).
## Regenerate (deterministic; never hand-edit the output):
##   /opt/godot/godot --headless --path game --script res://world/heists/afterhours/greybox/build_greybox.gd \
##     -- --out=<path>            (default res://world/heists/afterhours/afterhours.tscn; a scratch --out skips the
##                                 .tres writes)
## Data: afterhours_layout.gd + afterhours_layout_content.gd, emitted by tools/levelcheck/plans/afterhours_emit_layout.py
## from the plan scripts. Design: docs/design/heists/afterhours.md (D-075 / D-143 rulings). Contracts: heist_map.md.
## Copy-adapted from the Rolling Thunder chain (D-147; the convoy, dressing, finishes, skyline and GI lanes dropped).
## Built (G1 milestone): the Velvet's shell (both floors, every opening, the stage riser, guards, two stair cores),
## the grade, neighbours, closures, landmarks, RoomVolumes, PUBLIC / RESTRICTED / OUT_OF_BOUNDS zones, player /
## police spawns, doors, the contract nodes, review cameras, VariantSlots for the 14 slot groups (the 4 scalars and 6
## rare events are table rows), preplan points, patrol graphs, tactical points, assault markers (none at G1), the
## navmesh (door_nav_clearance). G2 (AH-C2, reuse-first): ah_dress.gd (map-built art, kit rooms, direct props),
## ah_finish.gd (library finishes), ah_gi.gd (the night environment + lut_afterhours, VoxelGI, probes, occluders, the
## render policy) and `Lighting/ClubLights` (the hall rig's club / house states, CLUB_LIGHT_ROWS). Audio: `Audio`
## (CuePlayer, MusicDirector, the BOH / street beds) and `Audio/ClubSound`.
extends "res://world/heists/afterhours/greybox/ah_gameplay.gd"

const AM: GDScript = preload("res://world/heists/shared/assault_markers.gd")
const NS: GDScript = preload("res://world/heists/shared/npc_seat_spawns.gd")
const DNC: GDScript = preload("res://world/heists/shared/door_nav_clearance.gd")
const AUDIO_BUILDER: String = "res://world/audio/map_audio_builder.gd"
const CUE_EMITTER: String = "res://world/audio/cue_emitter.gd"
const CLUB_SOUND: String = "res://world/heists/afterhours/club_sound.gd"
const CLUB_LIGHTS: String = "res://world/heists/afterhours/club_lights.gd"
const AH_GI: GDScript = preload("res://world/heists/afterhours/greybox/ah_gi.gd")
const ENV_SCRIPT: String = "res://world/lighting/heist_world_environment.gd"
## The hall (G6): ClubSound's position (the emitters sit on it).
const HALL_SOUND_POS: Vector3 = Vector3(13.0, 2.0, 13.0)
## [node name, position, cue id, volume offset dB] (origin: the Velvet's NW corner; +z south): the BOH beds (the back
## corridor G13, the upper staff wing) and the wet street (Marlin Ave, the alley, Tolley St).
const AUDIO_BEDS: Array = [
	["BedBohCorridor", Vector3(18.0, 1.5, 6.0), &"cue.amb_afterhours_boh", 0.0],
	["BedBohUpper", Vector3(31.0, 5.7, 15.0), &"cue.amb_afterhours_boh", -2.0],
	["BedStreetMarlin", Vector3(16.0, 1.5, 33.0), &"cue.amb_street_wet_night", 0.0],
	["BedStreetAlley", Vector3(22.0, 1.5, -3.0), &"cue.amb_street_wet_night", -2.0],
	["BedStreetTolley", Vector3(40.0, 1.5, 14.0), &"cue.amb_street_wet_night", -2.0],
]
## ClubSound's children: [node name, cue id, autoplay, volume offset dB] (club_sound.gd names them).
const CLUB_EMITTERS: Array = [
	["BedClubMusic", &"cue.amb_afterhours_club_music", true, 0.0],
	["BedClub", &"cue.amb_afterhours_club", true, 0.0],
	["PowerDown", &"cue.club_power_down", false, 0.0],
	["Stampede", &"cue.crowd_stampede", false, 0.0],
]
## The hall rig (afterhours.md §Audio/lighting; AH-C2): [name, "spot" | "omni", position, aim (spots), colour,
## energy, range, spot angle, shadow]. `Club*` = the club state (stealth), `Work*` = the house state (loud), others in
## both. Shadows only on the key lights that read (LEAD r307): the DJ's amber key, the main and VIP bar backs, the four
## house work lights (club state 3 shadowed, house 6: <= 8, §Budgets). The washes hang from the stage-front truss
## (y 7.25, its underside) onto the dance floor; violet, magenta, UV blue (never the interactable cyan). The house
## work lights carry the loud state (16: at 6 the house state read dark in the G2 review); the balcony's rail uplights
## (doc zones) light both states.
const CLUB_LIGHT_ROWS: Array = [
	["ClubWashW", "spot", Vector3(10.8, 7.2, 10.6), Vector3(10.5, 0.0, 14.0), Color(0.55, 0.25, 0.85), 18.0, 14.0, 40.0,
		false],
	["ClubWashC", "spot", Vector3(14.0, 7.2, 10.6), Vector3(14.0, 0.0, 14.5), Color(0.97, 0.42, 0.83), 18.0, 14.0, 40.0,
		false],
	["ClubWashE", "spot", Vector3(17.2, 7.2, 10.6), Vector3(17.5, 0.0, 14.0), Color(0.36, 0.29, 1.0), 18.0, 14.0, 40.0,
		false],
	["ClubKeyDJ", "spot", Vector3(15.0, 7.2, 10.6), Vector3(15.5, 1.5, 8.2), Color(1.0, 0.62, 0.25), 7.0, 10.0, 18.0,
		true],
	["ClubMirrorBall", "spot", Vector3(4.0, 7.6, 18.0), Vector3(14.0, 7.6, 12.5), Color(1.0, 0.95, 0.9), 4.0, 14.0, 4.0,
		false],
	["BarBackMain", "omni", Vector3(1.2, 2.2, 13.5), Vector3.ZERO, Color(1.0, 0.72, 0.45), 1.6, 5.0, 0.0, true],
	["BarBackVIP", "omni", Vector3(16.0, 6.4, 27.0), Vector3.ZERO, Color(1.0, 0.72, 0.45), 1.6, 5.0, 0.0, true],
	["BarBackEast", "omni", Vector3(25.0, 2.2, 11.0), Vector3.ZERO, Color(1.0, 0.72, 0.45), 1.2, 4.0, 0.0, false],
	# club-state outlines (LEAD's G2 review: the hall read as a black void): violet / magenta washes up the hall walls
	# (west over the bottle wall, east, the stage wall either side of the riser), the truss outlined, the bar fronts'
	# LED strips (both states); all unshadowed (A's D-146 note)
	["ClubWallW0", "omni", Vector3(0.7, 5.0, 9.0), Vector3.ZERO, Color(0.55, 0.25, 0.85), 2.2, 5.5, 0.0, false],
	["ClubWallW1", "omni", Vector3(0.7, 5.0, 13.5), Vector3.ZERO, Color(0.97, 0.42, 0.83), 2.2, 5.5, 0.0, false],
	["ClubWallE0", "omni", Vector3(25.3, 5.0, 8.5), Vector3.ZERO, Color(0.97, 0.42, 0.83), 2.2, 5.5, 0.0, false],
	["ClubWallE1", "omni", Vector3(25.3, 5.0, 13.5), Vector3.ZERO, Color(0.55, 0.25, 0.85), 2.2, 5.5, 0.0, false],
	["ClubWallN0", "omni", Vector3(4.0, 4.5, 7.7), Vector3.ZERO, Color(0.36, 0.29, 1.0), 2.0, 5.0, 0.0, false],
	["ClubWallN1", "omni", Vector3(22.0, 4.5, 7.7), Vector3.ZERO, Color(0.36, 0.29, 1.0), 2.0, 5.0, 0.0, false],
	["ClubTruss0", "omni", Vector3(12.0, 7.5, 10.6), Vector3.ZERO, Color(0.55, 0.25, 0.85), 1.2, 3.0, 0.0, false],
	["ClubTruss1", "omni", Vector3(16.0, 7.5, 10.6), Vector3.ZERO, Color(0.97, 0.42, 0.83), 1.2, 3.0, 0.0, false],
	["BarFrontMain0", "omni", Vector3(2.8, 0.35, 11.5), Vector3.ZERO, Color(1.0, 0.62, 0.32), 0.9, 2.5, 0.0, false],
	["BarFrontMain1", "omni", Vector3(2.8, 0.35, 15.5), Vector3.ZERO, Color(1.0, 0.62, 0.32), 0.9, 2.5, 0.0, false],
	["BarFrontEast0", "omni", Vector3(23.3, 0.35, 9.5), Vector3.ZERO, Color(1.0, 0.62, 0.32), 0.9, 2.5, 0.0, false],
	["BarFrontEast1", "omni", Vector3(23.3, 0.35, 12.5), Vector3.ZERO, Color(1.0, 0.62, 0.32), 0.9, 2.5, 0.0, false],
	["RailUp0", "omni", Vector3(3.0, 4.35, 15.45), Vector3.ZERO, Color(1.0, 0.66, 0.4), 1.5, 5.0, 0.0, false],
	["RailUp1", "omni", Vector3(9.0, 4.35, 15.45), Vector3.ZERO, Color(1.0, 0.66, 0.4), 1.5, 5.0, 0.0, false],
	["RailUp2", "omni", Vector3(15.0, 4.35, 15.45), Vector3.ZERO, Color(1.0, 0.66, 0.4), 1.5, 5.0, 0.0, false],
	["RailUp3", "omni", Vector3(21.0, 4.35, 15.45), Vector3.ZERO, Color(1.0, 0.66, 0.4), 1.5, 5.0, 0.0, false],
	["WorkNW", "spot", Vector3(6.0, 7.9, 9.5), Vector3(6.0, 0.0, 10.5), Color(1.0, 0.92, 0.82), 16.0, 14.0, 60.0, true],
	["WorkNE", "spot", Vector3(20.0, 7.9, 9.5), Vector3(20.0, 0.0, 10.5), Color(1.0, 0.92, 0.82), 16.0, 14.0, 60.0,
		true],
	["WorkSW", "spot", Vector3(8.0, 7.9, 13.5), Vector3(8.0, 0.0, 14.0), Color(1.0, 0.92, 0.82), 16.0, 14.0, 60.0,
		true],
	["WorkSE", "spot", Vector3(19.0, 7.9, 13.5), Vector3(19.0, 0.0, 14.0), Color(1.0, 0.92, 0.82), 16.0, 14.0, 60.0,
		true],
	# the stage's house fill (P's G2 loud pass: the stage read dim purple in house lights), unshadowed (A's D-146 note)
	["WorkStageFill", "omni", Vector3(13.0, 4.2, 9.2), Vector3.ZERO, Color(1.0, 0.92, 0.82), 3.0, 9.0, 0.0, false],
	# the house state flat and even over the hall (doc: "every pool even"; B's r312 alarm frame still read purple on
	# the velvet), unshadowed
	["WorkFillW", "omni", Vector3(7.0, 6.0, 11.0), Vector3.ZERO, Color(0.95, 0.97, 1.0), 4.0, 12.0, 0.0, false],
	["WorkFillE", "omni", Vector3(19.0, 6.0, 11.0), Vector3.ZERO, Color(0.95, 0.97, 1.0), 4.0, 12.0, 0.0, false],
]
## Site groups whose thin bodies (< 2 nav cells) are widened in the bake (the closures' barriers and gates).
const THIN_GROUPS: Array[String] = ["Closures"]


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
	map_root.name = "Afterhours"
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
	mission.set_script(load(MISSION_PATH))   # ENV A's (AH-A1)
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
	# PO6-17 assault events: no ASSAULT_* rows emitted for AH at G1 (an empty AssaultEvents node)
	errors.append_array(AM.build(map_root, [], [], [], [], _breaches(), obstructions))
	build_nav_links(nav)
	load("res://world/heists/afterhours/greybox/ah_dress.gd").new().call(&"run", self)  # AH-C2 dressing (G2)
	for line: String in NS.snap(map_root):
		print("seat: " + line)
	_build_environment(n("Lighting"))
	preload("res://world/heists/afterhours/greybox/ah_finish.gd").new(self).call(&"build")  # AH-C2 finishes (G2)
	_build_club_lights(n("Lighting"))
	AH_GI.new(self).call(&"build")  # AH-C2 lighting lane: shadowed fixtures, VoxelGI, probes, occluders, policy
	_build_audio()
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
	print("afterhours: saved %s (navmesh polygons: %d)" % [out, polys])
	quit(0)


## Breach rows as assault_markers.gd reads them (none emitted for AH at G1).
static func _breaches() -> Array:
	return []


## HeistDef + variant table from afterhours_resources.gd (ENV B's values), byte-stable.
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
	push_error("afterhours: " + msg)
	if map_root != null and is_instance_valid(map_root):
		map_root.free()
	quit(1)


## The night environment + LUT (AH-C2 lighting lane: ah_gi.gd environment(); no sun or moon at 00:40).
func _build_environment(lighting: Node3D) -> void:
	AH_GI.new(self).call(&"environment", lighting)


## `Lighting/ClubLights` (club_lights.gd): the club state's coloured lights (visible) and the house state's work lights
## (hidden) over the hall; ENV A's mission switches them by name.
func _build_club_lights(lighting: Node3D) -> void:
	var cl: Node3D = node3d("ClubLights")
	cl.set_script(load(CLUB_LIGHTS))
	add(lighting, cl)
	for r: Array in CLUB_LIGHT_ROWS:
		var l: Light3D = null
		if String(r[1]) == "spot":
			var sp: SpotLight3D = SpotLight3D.new()
			sp.spot_range = float(r[6])
			sp.spot_angle = float(r[7])
			sp.spot_attenuation = 1.2
			l = sp
		else:
			var om: OmniLight3D = OmniLight3D.new()
			om.omni_range = float(r[6])
			om.omni_attenuation = 1.2
			l = om
		l.name = String(r[0])
		l.position = r[2]
		if String(r[1]) == "spot":
			var aim: Vector3 = ((r[3] as Vector3) - (r[2] as Vector3)).normalized()
			l.basis = Basis.looking_at(aim, Vector3.UP if absf(aim.y) < 0.99 else Vector3.FORWARD)
		l.light_color = r[4]
		l.light_energy = float(r[5])
		l.shadow_enabled = bool(r[8])
		l.light_bake_mode = Light3D.BAKE_DYNAMIC  # doc GI: the house switch re-lights GI without a re-bake
		l.layers = 1 | VIEWMODEL_LIT_LAYER
		l.visible = not String(r[0]).begins_with("Work")   # the default state is club
		add(cl, l)


## D-117 `Audio` node (as the other heists): the CuePlayer, the afterhours MusicDirector and the BOH / street beds
## (map_audio_builder.gd), plus `Audio/ClubSound` (club_sound.gd) in the hall with its four CueEmitters. Cue ids are
## not checked here: CueEmitter plays its placeholder for an id cues.tres does not define (yet).
func _build_audio() -> void:
	var audio: Node3D = map_root.get_node_or_null("Audio") as Node3D
	if audio == null:
		audio = add(map_root, node3d("Audio")) as Node3D
	load(AUDIO_BUILDER).call(&"build", audio, map_root, &"afterhours", AUDIO_BEDS)
	var cs: Node3D = node3d("ClubSound", HALL_SOUND_POS)
	cs.set_script(load(CLUB_SOUND))
	add(audio, cs)
	var emitter: Script = load(CUE_EMITTER)
	for e: Array in CLUB_EMITTERS:
		var em: Node3D = Node3D.new()
		em.set_script(emitter)
		em.name = String(e[0])
		em.set(&"cue_id", e[1])
		em.set(&"autoplay", bool(e[2]))
		em.set(&"volume_offset_db", float(e[3]))
		add(cs, em)


## Walkable navmesh (heist_map.md §3: agent radius 0.3, height 1.8, climb 0.3, slope 40, cell 0.1 / 0.1) from the
## Geometry colliders minus the projected obstructions (furniture, catalog bodies, baked-closed doors, thin closure
## bodies widened by _nav_thick, the culled tops nobody stands on: roofs, neighbours, closure vehicles), with the door
## throats (door_nav_clearance.gd, as every map since ENV P's ghost run 250).
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
	print("door throats: %d doors" % DNC.add(base, map_root, nm))
	holder.queue_free()
	var t_parse: int = Time.get_ticks_msec() - t0
	var t1: int = Time.get_ticks_msec()
	NavigationServer3D.bake_from_source_geometry_data(nm, base)
	await process_frame
	nav.navigation_mesh = nm
	print("navmesh bake: parse %d ms, main %d ms (%d polygons)" % [t_parse, Time.get_ticks_msec() - t1,
		nm.get_polygon_count()])
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
