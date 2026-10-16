## X-5 GH workshop doorway police jam (heist_completion.md X-5): the crew holds the Glasshouse workshop (door open)
## and, before the assault pushes (CONTROL / ANTICIPATION, standoff band 8-15 m), every cop that reaches the doorway
## sees a target ~3 m away and backs off. PoliceBrain recomputed the back-off point every tick from the unit's own
## position: from the threshold that point lies behind the corridor's far wall, its nav route forks east / west
## around the wall, and every 0.2 m step flipped the route, so the cop danced on the threshold at full speed (or
## pressed into a teammate holding there) until BUILD switched it to the push. The back-off point is latched now,
## with side-step / hold when blocked (PoliceTweak back_off_*).
extends TestCase

const DOOR: Vector3 = Vector3(7.5, 0.0, 4.5)
## The back of the workshop (x 5-10.5, z 0-4.5), facing the WorkshopDoor.
const CREW_IN: Vector3 = Vector3(7.6, 0.05, 0.9)
## "In or near the doorway": flat distance from the door (m).
const NEAR_DOOR_M: float = 2.5
## A unit with a move goal that stays within STILL_M of one spot this long is jammed (s).
const STILL_M: float = 1.0
const JAM_S: float = 8.0
const SAMPLE_S: float = 0.25

var _rt: HeistRuntime = null
## Sim seconds (physics delta is scaled by Engine.time_scale), advanced by _physics_process.
var _sim_t: float = 0.0


func after_each() -> void:
	Engine.time_scale = 1.0
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _physics_process(delta: float) -> void:
	_sim_t += delta


func test_x5_gh_workshop_backoff_does_not_jam_the_doorway() -> void:
	_rt = await HeistLauncher.launch(&"glasshouse", 13, Enums.Difficulty.HAZARDOUS, self,
		{"crew_ai": false, "captain": false, "assault_events": false})
	assert_true(_rt != null, "launched")
	await wait_physics_frames(5)
	var nav: RID = _rt.map.get_world_3d().navigation_map
	for s: int in _rt.crew_members().size():
		var p: Vector3 = NavigationServer3D.map_get_closest_point(nav, CREW_IN + Vector3(0.6 * s - 0.9, 0.0, 0.0))
		_rt.teleport_crew(s, Transform3D(Basis.IDENTITY, p + Vector3(0.0, 0.05, 0.0)))
		Modifiers.set_source(s, &"diag.immune", {&"defense.damage_taken_mult": 0.0})
	for c: CrewController in _rt.crew_members():
		c.set_masked()
	var door: Door = _rt.map.find_child("WorkshopDoor", true, false) as Door
	assert_true(door != null, "WorkshopDoor")
	door.unlock()
	door.set_open(true, true)  # the crew picked it and went in
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(3)
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	Engine.time_scale = 4.0
	var t0: float = _sim_t
	var rest: Dictionary = {}  # unit instance id -> [anchor position, since t]
	var worst: float = 0.0
	var worst_what: String = ""
	var at_door: int = 0
	var saw_anticipation: bool = false
	# CONTROL (first responders, 20 s) and ANTICIPATION (30 s); stop when the assault starts building.
	while _sim_t - t0 < 70.0:
		var until: float = _sim_t + SAMPLE_S
		while _sim_t < until:
			await get_tree().physics_frame
		if dir.assault_phase == Enums.AssaultPhase.ANTICIPATION:
			saw_anticipation = true
		elif saw_anticipation:
			break
		var t: float = _sim_t - t0
		for u: NpcBase in dir.alive_units():
			var p: Vector3 = u.global_position
			var m: NpcMotor = u.get_node_or_null(^"Motor") as NpcMotor
			var near: bool = p.y < 1.0 and Vector2(p.x - DOOR.x, p.z - DOOR.z).length() < NEAR_DOOR_M
			var key: int = u.get_instance_id()
			var rec: Array = rest.get(key, [p, t])
			if not near or m == null or m.target == Vector3.INF or p.distance_to(rec[0]) > STILL_M:
				rec = [p, t]  # left the doorway, no move goal (holding), or got somewhere
			rest[key] = rec
			if not near:
				continue
			at_door += 1
			var still: float = t - float(rec[1])
			if still > worst:
				var b: PoliceBrain = u.get_node_or_null(^"Brain") as PoliceBrain
				worst = still
				worst_what = "%s at %s mode %s (t %.1f, phase %d)" % [u.name, p, b.mode if b != null else &"-", t,
					dir.assault_phase]
	print("X-5 GH workshop doorway: worst still with a move goal %.1f s %s" % [worst, worst_what])
	assert_true(saw_anticipation, "ran through ANTICIPATION")
	assert_true(at_door > 0, "police reached the workshop doorway")
	assert_true(worst < JAM_S, "no cop stands jammed in the workshop doorway with a move goal (%.1f s: %s)"
		% [worst, worst_what])
