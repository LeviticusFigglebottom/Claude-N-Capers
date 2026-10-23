## contract_nodes: required map structure (heist_map.md §2) + resources + spawn/variant sanity.
class_name LcCheckContractNodes
extends LcCheck

## name -> required class (checked with is_class).
const REQUIRED: Dictionary = {
	&"Geometry": "Node3D", &"Props": "Node3D", &"Lighting": "Node3D",
	&"Navigation": "NavigationRegion3D", &"Zones": "Node3D", &"Rooms": "Node3D", &"Spawns": "Node3D",
	&"Patrols": "Node3D", &"Tactical": "Node3D", &"Gameplay": "Node3D", &"Variants": "Node3D",
	&"Mission": "Node", &"ReviewCameras": "Node3D",
}
const MIN_PLAYER_SPAWNS: int = 4
const MIN_POLICE_DIRECTIONS: int = 3
const POLICE_DIRECTION_SEP_DEG: float = 45.0
const MIN_REVIEW_CAMERAS_FINAL: int = 12
const MIN_REVIEW_CAMERAS_GREYBOX: int = 1
## hub_map.md (--profile=hub): the safehouse's nodes, its 9 station ids, its return markers and root API.
const HUB_REQUIRED: Dictionary = {
	&"Geometry": "Node3D", &"Props": "Node3D", &"Lighting": "Node3D", &"Navigation": "NavigationRegion3D",
	&"Rooms": "Node3D", &"Spawns": "Node3D", &"Stations": "Node3D", &"ReviewCameras": "Node3D",
}
const HUB_STATIONS: Array[StringName] = [&"board", &"planning", &"armory", &"masks", &"jukebox", &"notoriety",
	&"range", &"crew", &"profile"]
const HUB_MARKERS: Array[StringName] = [&"Spawn", &"ReturnHeist", &"ReturnRange"]
const HUB_METHODS: Array[StringName] = [&"spawn_transform", &"set_jukebox_track"]


func _init() -> void:
	id = &"contract_nodes"
	title = "Contract nodes"


func run(ctx: LcContext) -> void:
	if ctx.profile == "hub":
		_run_hub(ctx)
		return
	var m: HeistMap = ctx.map
	for n: StringName in REQUIRED.keys():
		var c: Node = m.get_node_or_null(NodePath(String(n)))
		if c == null:
			fail(ctx, m, null, "missing required child `%s` (%s)" % [n, REQUIRED[n]])
		elif not c.is_class(REQUIRED[n]):
			fail(ctx, c, null, "`%s` must be a %s, is %s" % [n, REQUIRED[n], c.get_class()])
	if m.heist_def == null:
		fail(ctx, m, null, "HeistMap.heist_def is not assigned")
	elif ctx.heist_id != "":
		if String(m.heist_def.id) != ctx.heist_id:
			fail(ctx, m, null, "heist_def.id `%s` != heist id `%s`" % [m.heist_def.id, ctx.heist_id])
		var want: String = "res://world/heists/%s/%s.tscn" % [ctx.heist_id, ctx.heist_id]
		if m.heist_def.map_scene != want:
			fail(ctx, m, null, "heist_def.map_scene `%s` != `%s`" % [m.heist_def.map_scene, want])
	if m.variant_table == null:
		fail(ctx, m, null, "HeistMap.variant_table is not assigned")
	var mission: Node = m.get_node_or_null("Mission")
	if mission != null and not bool(mission.get_meta(&"_lc_had_script", mission.get_script() != null)):
		fail(ctx, mission, null, "Mission node has no mission script")
	_check_floors(ctx)
	_check_spawns(ctx)
	_check_zones(ctx)
	_check_rooms(ctx)
	_check_review_cameras(ctx)
	_check_variants(ctx)
	if not ctx.has_navmesh():
		fail(ctx, m, null, "Navigation has no baked navmesh (maps must commit their baked NavigationMesh)")


## The hub profile: hub_map.md's node list, no HeistDef / variants / police / zones, the 9 stations (station_id,
## UsePoint), the return markers and the root API.
func _run_hub(ctx: LcContext) -> void:
	var m: HeistMap = ctx.map
	for n: StringName in HUB_REQUIRED.keys():
		var c: Node = m.get_node_or_null(NodePath(String(n)))
		if c == null:
			fail(ctx, m, null, "missing required hub child `%s` (%s)" % [n, HUB_REQUIRED[n]])
		elif not c.is_class(HUB_REQUIRED[n]):
			fail(ctx, c, null, "`%s` must be a %s, is %s" % [n, HUB_REQUIRED[n], c.get_class()])
	if m.heist_def != null or m.variant_table != null:
		fail(ctx, m, null, "a hub map has no HeistDef or variant table (hub_map.md: never on the Board)")
	if not m.has_signal(&"station_requested"):
		fail(ctx, m, null, "hub root has no `station_requested` signal")
	for meth: StringName in HUB_METHODS:
		if not m.has_method(meth):
			fail(ctx, m, null, "hub root has no `%s()`" % meth)
	if not (m.get(&"jukebox") is Node):
		fail(ctx, m, null, "hub root `jukebox` is not set (Audio/Jukebox MusicDirector)")
	_check_floors(ctx)
	_check_rooms(ctx)
	_check_review_cameras(ctx)
	var players: int = 0
	for n2: Node in m.find_children("*", "SpawnPoint", true, false):
		if (n2 as SpawnPoint).kind == SpawnPoint.Kind.PLAYER:
			players += 1
		else:
			fail(ctx, n2, null, "the hub has PLAYER spawns only")
	if players < MIN_PLAYER_SPAWNS:
		fail(ctx, m, null, "%d PLAYER spawns, need >= %d" % [players, MIN_PLAYER_SPAWNS])
	for mk: StringName in HUB_MARKERS:
		if not (m.get_node_or_null(NodePath("Spawns/%s" % mk)) is Marker3D):
			fail(ctx, m, null, "missing return marker Spawns/%s" % mk)
	var holder: Node = m.get_node_or_null(^"Stations")
	var seen: Dictionary = {}
	for st: Node in (holder.get_children() if holder != null else []):
		var sid: StringName = StringName(String(st.get(&"station_id"))) if &"station_id" in st else st.name
		if sid == &"":
			sid = st.name
		if seen.has(sid):
			fail(ctx, st, null, "duplicate station id `%s`" % sid)
		seen[sid] = true
		if not (st.get_node_or_null(^"UsePoint") is Marker3D):
			fail(ctx, st, null, "station `%s` has no UsePoint Marker3D" % sid)
		var cam: Node = st.get_node_or_null(^"StationCam")
		if cam != null and not (cam is Marker3D):
			fail(ctx, cam, null, "StationCam must be a Marker3D (hub_map.md), is %s" % cam.get_class())
	for want: StringName in HUB_STATIONS:
		if not seen.has(want):
			fail(ctx, m, null, "missing station `%s`" % want)
	if not ctx.has_navmesh():
		fail(ctx, m, null, "Navigation has no baked navmesh (maps must commit their baked NavigationMesh)")


func _check_floors(ctx: LcContext) -> void:
	var fh: PackedFloat32Array = ctx.map.floor_heights
	# heist_map.md §7: the ground floor is at 0.0; basements (negative heights) may come first.
	var has_ground: bool = false
	for h: float in fh:
		if is_zero_approx(h):
			has_ground = true
	if not has_ground:
		fail(ctx, ctx.map, null, "floor_heights must contain 0.0 (ground floor), got %s" % [fh])
	for i: int in range(1, fh.size()):
		if fh[i] <= fh[i - 1]:
			fail(ctx, ctx.map, null, "floor_heights must be strictly ascending: %s" % [fh])
	# D-054: floor_names is optional; when given it names every floor.
	var names: PackedStringArray = ctx.map.floor_names
	if not names.is_empty() and names.size() != fh.size():
		fail(ctx, ctx.map, null, "floor_names has %d entries for %d floor_heights (give one name per floor or none)"
			% [names.size(), fh.size()])


func _check_spawns(ctx: LcContext) -> void:
	var players: int = 0
	var police: Array[SpawnPoint] = []
	for n: Node in ctx.map.find_children("*", "SpawnPoint", true, false):
		var s: SpawnPoint = n
		if s.kind == SpawnPoint.Kind.PLAYER:
			players += 1
		elif s.kind == SpawnPoint.Kind.POLICE:
			police.append(s)
		if not s.patrol_graph.is_empty() and not (s.get_node_or_null(s.patrol_graph) is PatrolGraph):
			fail(ctx, s, null, "patrol_graph `%s` does not resolve to a PatrolGraph" % s.patrol_graph)
	if players < MIN_PLAYER_SPAWNS:
		fail(ctx, ctx.map, null, "%d PLAYER spawns, need >= %d" % [players, MIN_PLAYER_SPAWNS])
	# Police directions: bearings from the map centre, clustered by separation.
	var centre: Vector3 = _map_centre(ctx)
	var bearings: Array[float] = []
	for s2: SpawnPoint in police:
		var d: Vector3 = s2.global_position - centre
		bearings.append(rad_to_deg(atan2(d.x, d.z)))
	bearings.sort()
	var dirs: int = 0
	var last: float = -INF
	for b: float in bearings:
		if b - last >= POLICE_DIRECTION_SEP_DEG:
			dirs += 1
			last = b
	if dirs >= 2 and bearings[0] + 360.0 - bearings[bearings.size() - 1] < POLICE_DIRECTION_SEP_DEG:
		dirs -= 1
	if dirs < MIN_POLICE_DIRECTIONS:
		fail(ctx, ctx.map, null, "%d POLICE spawns cover %d direction(s) (>= %d deg apart), need >= %d"
			% [police.size(), dirs, int(POLICE_DIRECTION_SEP_DEG), MIN_POLICE_DIRECTIONS])


func _map_centre(ctx: LcContext) -> Vector3:
	var box: AABB = AABB()
	var first: bool = true
	for r: RoomVolume in ctx.rooms:
		var a: AABB = LcAreas.world_aabb(r)
		box = a if first else box.merge(a)
		first = false
	return box.get_center() if not first else ctx.map.global_position


func _check_zones(ctx: LcContext) -> void:
	var have: Dictionary = {}
	for n: Node in ctx.map.find_children("*", "MapZone", true, false):
		var z: MapZone = n
		have[z.kind] = true
		if LcAreas.boxes(z).is_empty():
			fail(ctx, z, null, "MapZone has no enabled CollisionShape3D")
	if not have.has(MapZone.Kind.ESCAPE):
		fail(ctx, ctx.map, null, "no ESCAPE MapZone")
	if not have.has(MapZone.Kind.SECURE_LOOT):
		fail(ctx, ctx.map, null, "no SECURE_LOOT MapZone")


func _check_rooms(ctx: LcContext) -> void:
	if ctx.rooms.is_empty():
		fail(ctx, ctx.map, null, "no RoomVolume nodes")
	var ids: Dictionary = {}
	for r: RoomVolume in ctx.rooms:
		if r.room_id == &"" or r.purpose == &"":
			fail(ctx, r, null, "RoomVolume needs room_id and purpose")
		if ids.has(r.room_id):
			fail(ctx, r, null, "duplicate room_id `%s`" % r.room_id)
		ids[r.room_id] = true
		if LcAreas.boxes(r).is_empty():
			fail(ctx, r, null, "RoomVolume has no enabled CollisionShape3D")
		if r.floor_index < 0 or r.floor_index >= ctx.map.floor_heights.size():
			fail(ctx, r, null, "floor_index %d not in floor_heights" % r.floor_index)


func _check_review_cameras(ctx: LcContext) -> void:
	var need: int = MIN_REVIEW_CAMERAS_FINAL if ctx.stage == "final" else MIN_REVIEW_CAMERAS_GREYBOX
	var ok: int = 0
	var top: int = 0
	for p: NodePath in ctx.map.review_cameras:
		var n: Node = ctx.map.get_node_or_null(p)
		if n == null or not (n is Marker3D or n is Camera3D):
			fail(ctx, ctx.map, null, "review_cameras entry `%s` is not a Marker3D/Camera3D" % p)
			continue
		ok += 1
		if String(n.name).begins_with("TopDown"):
			top += 1
	if ok < need:
		fail(ctx, ctx.map, null, "%d review cameras, need >= %d at %s" % [ok, need, ctx.stage])
	if ctx.stage == "final" and top == 0:
		fail(ctx, ctx.map, null, "no TopDown* review camera (top-down plan shot)")


func _check_variants(ctx: LcContext) -> void:
	var variants: Node = ctx.map.get_node_or_null("Variants")
	var groups: Dictionary = {}
	var ids: Dictionary = {}
	for s: VariantSlot in ctx.variant_slots():
		if variants != null and not variants.is_ancestor_of(s):
			fail(ctx, s, null, "VariantSlot must live under Variants")
		if s.slot_group == &"" or s.slot_id == &"":
			fail(ctx, s, null, "VariantSlot needs slot_group and slot_id")
			continue
		if ids.has(s.slot_id):
			fail(ctx, s, null, "duplicate slot_id `%s`" % s.slot_id)
		ids[s.slot_id] = true
		groups[s.slot_group] = int(groups.get(s.slot_group, 0)) + 1
	for g: StringName in groups.keys():
		if int(groups[g]) < 2:
			fail(ctx, ctx.map, null, "slot_group `%s` has %d slot(s), needs >= 2" % [g, groups[g]])
	if ctx.map.variant_table == null:
		return
	for rule: Dictionary in ctx.map.variant_table.rules:
		var g2: StringName = StringName(str(rule.get("group", "")))
		if not groups.has(g2):
			fail(ctx, ctx.map, null, "variant rule group `%s` has no VariantSlots" % g2)
	for g3: StringName in groups.keys():
		var has_rule: bool = false
		for rule2: Dictionary in ctx.map.variant_table.rules:
			if StringName(str(rule2.get("group", ""))) == g3:
				has_rule = true
		if not has_rule:
			fail(ctx, ctx.map, null, "slot_group `%s` has no rule in the variant table" % g3)
