## PO6-16 (D-114 §5, L1.1 / L1.4; P's PO6 GH regression: PARTIAL, "the manager office was not on this run's path"):
## Golden Hour loud with the crew holding the U6 manager office. The police push INTO the room during the SUSTAIN
## phase of the assault, not only up to its threshold. The office is the map's own room volume (Rooms/RoomU6, the
## room_id U6 Area3D box), not hand-typed bounds. Short: compressed director timings, fixed seed, time scale 4.
extends TestCase

const ROOM_PATH: NodePath = ^"Rooms/RoomU6"
## Crew spots inside U6 (the PO6-16 playtest: the crew held the office behind the desk, facing ManagerDoor).
const SPOTS: Array[Vector3] = [Vector3(9.0, 4.25, 10.8), Vector3(10.0, 4.25, 10.8), Vector3(11.2, 4.25, 10.5),
	Vector3(8.0, 4.25, 10.5)]
const SUSTAIN_S: float = 90.0

var _rt: HeistRuntime = null


func after_each() -> void:
	Engine.time_scale = 1.0
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


## World AABB of the room's box shape(s) (Area3D > CollisionShape3D with a BoxShape3D).
static func room_aabb(room: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for n: Node in room.find_children("*", "CollisionShape3D", true, false):
		var cs: CollisionShape3D = n as CollisionShape3D
		var box: BoxShape3D = cs.shape as BoxShape3D
		if box == null:
			continue
		var a: AABB = cs.global_transform * AABB(-box.size * 0.5, box.size)
		out = a if first else out.merge(a)
		first = false
	return out


func test_po6_16_gh_police_enter_the_manager_office_during_sustain() -> void:
	var tw: DirectorTweak = (load("res://systems/director/director_tweak.tres") as DirectorTweak).duplicate() as DirectorTweak
	tw.first_control_s = 3.0
	tw.anticipation_s = 2.0
	tw.build_s = 10.0
	tw.sustain_by_stage_s = PackedFloat32Array([SUSTAIN_S, SUSTAIN_S, SUSTAIN_S])
	_rt = await HeistLauncher.launch(&"glasshouse", 7, Enums.Difficulty.HAZARDOUS, self,
		{"crew_ai": false, "director_tweak": tw, "captain": false, "assault_events": false})
	assert_true(_rt != null, "launched")
	var room: Node3D = _rt.map.get_node_or_null(ROOM_PATH) as Node3D
	assert_true(room != null and StringName(room.get(&"room_id")) == &"U6", "GH map has the U6 manager office room")
	var office: AABB = room_aabb(room)
	assert_true(office.size.x > 3.0 and office.size.z > 3.0, "office volume %s" % office)
	await wait_physics_frames(5)
	for s: int in _rt.crew_members().size():
		assert_true(office.has_point(SPOTS[s] + Vector3(0, 0.5, 0)), "crew spot %d inside the office" % s)
		_rt.teleport_crew(s, Transform3D(Basis.IDENTITY, SPOTS[s]))
		Modifiers.set_source(s, &"diag.immune", {&"defense.damage_taken_mult": 0.0})
	for c: CrewController in _rt.crew_members():
		c.set_masked()
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(3)
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	Engine.time_scale = 4.0
	var tick_s: float = 1.0 / float(Engine.physics_ticks_per_second)
	var t: float = 0.0
	var sustain_t0: float = -1.0
	var entered_at: float = -1.0
	var most_inside: int = 0
	# Alarm -> control -> anticipation -> build -> sustain takes ~15 s of game time here; then SUSTAIN_S.
	while t < 30.0 + SUSTAIN_S and entered_at < 0.0:
		await wait_physics_frames(int(Engine.physics_ticks_per_second / Engine.time_scale))  # ~1 game s
		t += tick_s * float(int(Engine.physics_ticks_per_second / Engine.time_scale)) * Engine.time_scale
		if dir.assault_phase != Enums.AssaultPhase.SUSTAIN:
			if sustain_t0 >= 0.0:
				break  # sustain over (fade) without an entry
			continue
		if sustain_t0 < 0.0:
			sustain_t0 = t
		var inside: int = 0
		for u: NpcBase in dir.alive_units():
			if office.has_point(u.global_position + Vector3(0, 0.5, 0)):
				inside += 1
		most_inside = maxi(most_inside, inside)
		if inside > 0:
			entered_at = t - sustain_t0
	print("[PO6-16] sustain from t=%.0f, first cop inside U6 %.0f s into sustain (most %d, alive %d)" % [
		sustain_t0, entered_at, most_inside, dir.alive_units().size()])
	assert_true(sustain_t0 >= 0.0, "the assault reached SUSTAIN")
	assert_true(entered_at >= 0.0, "police entered the manager office within the sustain phase (%.0f s)" % SUSTAIN_S)
	assert_eq(dir.assault_phase, Enums.AssaultPhase.SUSTAIN, "still sustaining when they came in")
