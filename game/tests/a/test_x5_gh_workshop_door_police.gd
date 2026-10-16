## X-5 (heist_completion.md, ENV C audit): a GH first responder stood still > 100 s at (7.3, 0, 4.9), by the
## WorkshopDoor UsePoint. Root cause (reproduced headless): not the door. The crew was on the floor above
## (~(7.3, 4.4, 5.0)) and NpcMotor's arrival was horizontal only, so the cop "arrived" right under its target, the
## PoliceBrain re-issued the same approach go_to, and it arrived again every tick (mode approach, velocity 0, the
## nav path to the stairs unused). Arrival now also needs |dy| <= NpcMotor.arrive_dy (unless the path is done).
## Flake (~1 run in 30, more under CPU load): the navmesh syncs on worker threads, so the snap below could hit an
## empty map iteration; HeistLauncher.launch() now waits for it (HeistLauncher.navigation_ready).
extends TestCase

const DOOR: Vector3 = Vector3(7.5, 0.0, 4.5)
## The upper floor right above the WorkshopDoor (snapped to the navmesh).
const CREW_ABOVE: Vector3 = Vector3(7.3, 4.25, 4.9)

var _rt: HeistRuntime = null


func after_each() -> void:
	Engine.time_scale = 1.0
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func test_x5_gh_police_do_not_park_under_the_crew_upstairs() -> void:
	_rt = await HeistLauncher.launch(&"glasshouse", 7, Enums.Difficulty.HAZARDOUS, self,
		{"crew_ai": false, "captain": false, "assault_events": false})
	assert_true(_rt != null, "launched")
	await wait_physics_frames(5)
	var snap: Vector3 = NavigationServer3D.map_get_closest_point(_rt.map.get_world_3d().navigation_map, CREW_ABOVE)
	# The crew must really stand upstairs: before HeistLauncher waited for the navmesh sync, the map could still be
	# empty here (snap (0, 0, 0)), the crew stayed at the spawn and the police fought it on the ground floor.
	assert_true(HeistLauncher.navigation_ready(_rt), "launch() returns with the navmesh synced")
	assert_true(snap.distance_to(CREW_ABOVE) < 0.5, "the upper floor point snaps onto the navmesh (%s)" % snap)
	for s: int in _rt.crew_members().size():
		_rt.teleport_crew(s, Transform3D(Basis.IDENTITY, snap + Vector3(0.6 * s, 0.05, 0.0)))
		Modifiers.set_source(s, &"diag.immune", {&"defense.damage_taken_mult": 0.0})
	for c: CrewController in _rt.crew_members():
		c.set_masked()
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(3)
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	Engine.time_scale = 4.0
	var t0: int = Engine.get_physics_frames()
	var rest: Dictionary = {}
	var worst: float = 0.0
	var worst_what: String = ""
	var upstairs: int = 0
	for step: int in 20:
		await wait_physics_frames(int(4.0 * Engine.physics_ticks_per_second / Engine.time_scale))
		var t: float = float(Engine.get_physics_frames() - t0) * Engine.time_scale / float(Engine.physics_ticks_per_second)
		upstairs = 0
		for u: NpcBase in dir.alive_units():
			var p: Vector3 = u.global_position
			if p.y > 3.0:
				upstairs += 1
			var key: int = u.get_instance_id()
			var rec: Array = rest.get(key, [p, t])
			if p.distance_to(rec[0]) > 0.15:
				rec = [p, t]
			rest[key] = rec
			var b: PoliceBrain = u.get_node_or_null(^"Brain") as PoliceBrain
			# Below the crew (ground floor, within 3 m flat of it), approaching it unseen, not moving.
			if b == null or b.mode != &"approach" or p.y > 1.0 or Vector2(p.x - snap.x, p.z - snap.z).length() > 3.0:
				continue
			var still: float = t - float(rec[1])
			if still > worst:
				worst = still
				worst_what = "%s at %s (t %.0f)" % [u.name, p, t]
	print("X-5 GH door: worst still-under-the-crew %.0f s %s, %d units upstairs" % [worst, worst_what, upstairs])
	assert_true(worst < 12.0, "no cop parks under the crew on the floor above (%.0f s: %s)" % [worst, worst_what])
	assert_true(upstairs > 0, "police reach the crew's floor (%d units upstairs)" % upstairs)
