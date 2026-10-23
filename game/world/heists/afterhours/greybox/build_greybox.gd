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
## navmesh (door_nav_clearance). Lighting: a greybox night environment (no sun; a dim moon) and `Lighting/ClubLights`
## (club / house states). Audio: `Audio` (CuePlayer, MusicDirector, the BOH / street beds) and `Audio/ClubSound`.
extends "res://world/heists/afterhours/greybox/ah_gameplay.gd"

const AM: GDScript = preload("res://world/heists/shared/assault_markers.gd")
const NS: GDScript = preload("res://world/heists/shared/npc_seat_spawns.gd")
const DNC: GDScript = preload("res://world/heists/shared/door_nav_clearance.gd")
const AUDIO_BUILDER: String = "res://world/audio/map_audio_builder.gd"
const CUE_EMITTER: String = "res://world/audio/cue_emitter.gd"
const CLUB_SOUND: String = "res://world/heists/afterhours/club_sound.gd"
const CLUB_LIGHTS: String = "res://world/heists/afterhours/club_lights.gd"
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
## ClubLights' children: [name, position, colour, energy, range] (club_lights.gd: `Club*` the club state, `Work*` the
## house state). Club: violet / magenta / amber / UV blue over the dance floor and the stage (never the interactable
## cyan, doc §Audio/lighting), low energy; house: 4000 K work lights on the truss line.
const CLUB_LIGHT_ROWS: Array = [
	["ClubFloorW", Vector3(10.5, 6.5, 13.5), Color(0.55, 0.25, 0.85), 0.6, 9.0],
	["ClubFloorC", Vector3(14.0, 6.5, 14.5), Color(0.97, 0.42, 0.83), 0.6, 9.0],
	["ClubFloorE", Vector3(17.5, 6.5, 13.5), Color(0.36, 0.29, 1.0), 0.6, 9.0],
	["ClubStage", Vector3(13.0, 5.0, 8.8), Color(1.0, 0.62, 0.25), 0.7, 8.0],
	["WorkW", Vector3(7.0, 7.4, 13.0), Color(1.0, 0.95, 0.88), 2.0, 16.0],
	["WorkC", Vector3(13.0, 7.4, 11.0), Color(1.0, 0.95, 0.88), 2.0, 16.0],
	["WorkE", Vector3(19.0, 7.4, 13.0), Color(1.0, 0.95, 0.88), 2.0, 16.0],
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
	for line: String in NS.snap(map_root):
		print("seat: " + line)
	_build_environment(n("Lighting"))
	preload("res://world/heists/afterhours/greybox/ah_finish.gd").new(self).call(&"build")  # AH-C2 finishes (G2)
	_build_club_lights(n("Lighting"))
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


## G1 greybox night (doc: 00:40, no sun or moon, an overcast sky lit orange from below): a flat dark sky colour, a
## dim cool ambient so the greybox reads, AgX, light SSAO and a dim shadowless moon fill (the one DirectionalLight3D).
func _build_environment(lighting: Node3D) -> void:
	var we: WorldEnvironment = WorldEnvironment.new()
	we.set_script(load(ENV_SCRIPT))  # brightness option (B5-01)
	we.name = "WorldEnvironment"
	var env: Environment = Environment.new()
	env.resource_name = "env_afterhours_greybox"
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.09, 0.06, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.52, 0.62)
	env.ambient_light_energy = 0.45
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.1
	env.ssao_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.35, 0.22, 0.14)
	env.fog_density = 0.004
	env.glow_enabled = true
	env.glow_intensity = 0.4
	we.environment = env
	add(lighting, we)
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.basis = Basis.looking_at(Vector3(0.3, -0.8, 0.5).normalized(), Vector3.UP)
	moon.position = Vector3(22.0, 30.0, 16.0)
	moon.light_color = Color(0.7, 0.75, 0.95)
	moon.light_energy = 0.15
	moon.shadow_enabled = false
	moon.layers = 1 | VIEWMODEL_LIT_LAYER  # D-095 like every map light
	add(lighting, moon)


## `Lighting/ClubLights` (club_lights.gd): the club state's coloured lights (visible) and the house state's work lights
## (hidden) over the hall; ENV A's mission switches them by name.
func _build_club_lights(lighting: Node3D) -> void:
	var cl: Node3D = node3d("ClubLights")
	cl.set_script(load(CLUB_LIGHTS))
	add(lighting, cl)
	for r: Array in CLUB_LIGHT_ROWS:
		var l: OmniLight3D = OmniLight3D.new()
		l.name = String(r[0])
		l.position = r[1]
		l.light_color = r[2]
		l.light_energy = float(r[3])
		l.omni_range = float(r[4])
		l.shadow_enabled = false
		l.layers = 1 | VIEWMODEL_LIT_LAYER
		l.visible = String(r[0]).begins_with("Club")   # the default state is club
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
