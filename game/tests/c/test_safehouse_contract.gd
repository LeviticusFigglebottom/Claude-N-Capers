## The safehouse hub map (C4-02; docs/contracts/hub_map.md v1.2, docs/design/heists/safehouse.md). On the generated
## scene: the root is a data-only SafehouseMap (a HeistMap with no HeistDef); the 9 stations are ENV A's hub_station
## prefabs named by id, each with a floor UsePoint whose -Z faces the station, the Interactable within the standard
## reach of the standing eye on it and in clear sight (or behind the station's own body), and a StationCam marker;
## the return markers and spawn_transform's Spawn fallback; the station_requested relay; the jukebox cabinet (a
## MusicDirector off the event bus) and set_jukebox_track's default track. Owner: ENV C.
extends TestCase

## build_safehouse.gd SCENE_PATH (staged off hub_map's path until B's 2D-hub tests are pinned).
const SCENE: String = "res://world/hub/safehouse/safehouse_g1.tscn"
const IDS: Array[StringName] = [&"board", &"planning", &"armory", &"masks", &"jukebox", &"notoriety", &"range",
	&"crew", &"profile"]

var _map: SafehouseMap = null


func before_each() -> void:
	_map = (load(SCENE) as PackedScene).instantiate() as SafehouseMap
	add_child(_map)
	await wait_physics_frames(2)


func after_each() -> void:
	if _map != null and is_instance_valid(_map):
		if _map.jukebox != null:
			_map.jukebox.stop_all()
		_map.queue_free()
	_map = null
	await wait_frames(2)


func test_root_is_a_data_only_heist_map() -> void:
	assert_true(_map != null, "the root is a SafehouseMap")
	if _map == null:
		return
	assert_true(_map is HeistMap, "SafehouseMap extends HeistMap (hub_map v1.2)")
	assert_true(_map.heist_def == null and _map.variant_table == null, "no HeistDef: never on the Board")
	assert_eq(_map.floor_heights, PackedFloat32Array([0.0]))
	assert_true(_map.review_cameras.size() >= 12, "review cameras")


func test_nine_stations_in_reach_from_their_use_points() -> void:
	var eye_h: float = Tweak.crew().eye_standing
	var reach: float = Tweak.interaction().reach_m
	var space: PhysicsDirectSpaceState3D = _map.get_world_3d().direct_space_state
	var seen: Array[StringName] = []
	for st: Node in _map.stations():
		var hs: HubStationPrefab = st as HubStationPrefab
		assert_true(hs != null, "%s is a hub_station prefab" % st.name)
		if hs == null:
			continue
		assert_eq(String(hs.station_id), String(hs.name), "station %s is named by its id" % hs.name)
		assert_true(hs.is_in_group(G.HUB_STATION), "%s in the hub_station group" % hs.name)
		seen.append(hs.station_id)
		var up: Marker3D = hs.get_node(^"UsePoint") as Marker3D
		var it: Node3D = hs.get_node(^"Interactable") as Node3D
		assert_near(up.global_position.y, 0.0, 0.01, "%s UsePoint on the floor" % hs.name)
		var to: Vector3 = it.global_position - up.global_position
		var flat: Vector3 = Vector3(to.x, 0.0, to.z).normalized()
		assert_true(flat.dot(-up.global_basis.z) > 0.95, "%s UsePoint faces the station" % hs.name)
		var eye: Vector3 = up.global_position + Vector3.UP * eye_h
		var d: float = eye.distance_to(it.global_position)
		assert_true(d <= reach, "%s Interactable %.2f m from the eye (reach %.1f)" % [hs.name, d, reach])
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, it.global_position, 1)
		var hit: Dictionary = space.intersect_ray(q)
		var col: Node = hit.get("collider") as Node
		assert_true(hit.is_empty() or hs.is_ancestor_of(col), "%s in sight from its UsePoint (blocked by %s)" % [
			hs.name, col.get_path() if col != null else ""])
		assert_true(hs.get_node_or_null(^"StationCam") is Marker3D, "%s StationCam is a Marker3D" % hs.name)
	for id: StringName in IDS:
		assert_true(seen.has(id), "station %s exists" % id)
	assert_eq(seen.size(), IDS.size(), "exactly the 9 hub_map ids")


func test_spawn_transform_and_return_markers() -> void:
	var rr: Node3D = _map.get_node(^"Spawns/ReturnRange") as Node3D
	assert_true(_map.spawn_transform(&"ReturnRange").is_equal_approx(rr.global_transform), "ReturnRange")
	var spawn: Transform3D = (_map.get_node(^"Spawns/Spawn") as Node3D).global_transform
	assert_true(_map.spawn_transform(&"ReturnHeist").origin.is_equal_approx(spawn.origin), "back in the van at LB")
	assert_true(_map.spawn_transform(&"no_such_marker").is_equal_approx(spawn), "unknown ids land on Spawn")
	assert_true(_map.spawn_transform(&"").is_equal_approx(spawn), "an empty id lands on Spawn")
	assert_near(rr.global_position.distance_to(Vector3(20.75, 0.0, 16.4)), 0.0, 0.01, "ReturnRange in the vestibule")


func test_station_requested_is_relayed() -> void:
	var got: Array[StringName] = []
	_map.station_requested.connect(func(id: StringName) -> void: got.append(id))
	(_map.get_node(^"Stations/armory") as HubStationPrefab).station_requested.emit(&"armory")
	(_map.get_node(^"Stations/profile") as HubStationPrefab).station_requested.emit(&"profile")
	assert_eq(got, [&"armory", &"profile"] as Array[StringName])


func test_jukebox_cabinet() -> void:
	var j: MusicDirector = _map.jukebox
	assert_true(j != null and j == _map.get_node(^"Audio/Jukebox"), "jukebox is Audio/Jukebox")
	if j == null:
		return
	assert_false(j.listen_to_event_bus, "the cabinet ignores heist facts")
	assert_true(j.has_method(&"set_ducked"), "set_ducked (hub_map)")
	_map.set_jukebox_track(&"")
	assert_eq(j.track_id, SafehouseMap.DEFAULT_TRACK, "the heist default plays glasshouse")
	assert_eq(j.current_stem, MusicTrack.STEM_STEALTH, "on the stealth stem")
	_map.set_jukebox_track(&"rolling_thunder")
	assert_eq(j.track_id, &"rolling_thunder", "a picked track plays")
	_map.set_jukebox_track(&"no_such_track")
	assert_eq(j.track_id, SafehouseMap.DEFAULT_TRACK, "an unknown pick falls back to the default")
