## PO6-16 (D-114 §5): horde pacing + room entry. L1.1 (BUILD/SUSTAIN keep the force topped up, every wave
## ends in FADE -> CONTROL and the next wave re-emits ANTICIPATION / BUILD), L1.4 (spawn groups at police
## spawns out of crew sight). The crew holds a closed room whose only entrance is a closed door: police open
## it and push INTO the room (push slots with LOS to the target), and while sustaining the alive count stays
## near the force cap even as units die.
extends TestCase

const ROOM: Vector2 = Vector2(4.0, 8.0)
## Golden Hour's manager office shape: the crew holds the back of the room, 4.5 m from the door (PO playtest).
const HOLD: Vector3 = Vector3(0.0, 0.05, -4.5)

var _rt: HeistRuntime = null
var _phases: Array[Vector2i] = []
## Sim seconds elapsed (physics delta is scaled by Engine.time_scale), advanced by _physics_process.
var _sim_t: float = 0.0


func after_each() -> void:
	Engine.time_scale = 1.0
	if EventBus.assault_phase_changed.is_connected(_on_phase):
		EventBus.assault_phase_changed.disconnect(_on_phase)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	_phases.clear()
	await wait_frames(2)


func _physics_process(delta: float) -> void:
	_sim_t += delta


## Wait `s` sim seconds.
func _sim(s: float) -> void:
	var until: float = _sim_t + s
	while _sim_t < until:
		await get_tree().physics_frame


func _on_phase(phase: int, wave: int) -> void:
	_phases.append(Vector2i(phase, wave))


static func _inside(p: Vector3) -> bool:
	return absf(p.x) < ROOM.x - 0.1 and p.z < -0.3 and p.z > -ROOM.y + 0.1


## In the doorway: within 1.5 m of the door on either side (the threshold clump of the PO playtest).
static func _in_doorway(p: Vector3) -> bool:
	return absf(p.x) < 1.5 and absf(p.z) < 1.5


func _tweak() -> DirectorTweak:
	var tw: DirectorTweak = (load("res://systems/director/director_tweak.tres") as DirectorTweak).duplicate() as DirectorTweak
	tw.first_control_s = 1.0
	tw.first_responder_groups = 0
	tw.anticipation_s = 1.0
	tw.build_s = 4.0
	tw.sustain_by_stage_s = PackedFloat32Array([30.0, 30.0, 30.0])
	tw.sustain_crew_mult = PackedFloat32Array([1.0])
	tw.fade_wait_cap_s = 1.0
	tw.fade_s = 2.0
	tw.control_between_waves_s = 2.0
	tw.force_crew_mult = PackedFloat32Array([0.5])
	tw.stage_force_mult = PackedFloat32Array([1.0, 1.0, 1.0])
	tw.control_special_groups = []
	tw.captain_chance = 0.0
	return tw


func test_po6_16_police_push_into_held_room_and_force_stays_topped_up() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 616, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.with_doorway_wall(0, 0, ROOM), "ai_teammates": 0, "director_tweak": _tweak(),
		"captain": false})
	assert_true(_rt != null, "launched")
	assert_true(await ATestMaps.await_nav_synced(_rt), "navmesh synced")
	var door: Door = ATestMaps.add_prefab(_rt, "door", Vector3.ZERO, func(p: GameplayPrefab) -> void:
		(p as Door).lock = Door.Lock.NONE) as Door
	for x: float in [-9.0, 9.0]:
		var sp: SpawnPoint = SpawnPoint.new()
		sp.kind = SpawnPoint.Kind.POLICE
		_rt.map.get_node(^"Spawns").add_child(sp)
		sp.global_position = Vector3(x, 0.05, 11.0)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, HOLD))
	Modifiers.set_source(0, &"po6_16.immune", {&"defense.damage_taken_mult": 0.0})
	await wait_physics_frames(3)
	assert_false(door.is_open, "the room's door starts closed")
	EventBus.assault_phase_changed.connect(_on_phase)
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	_rt.stealth.raise_alarm(&"test", 0)
	Engine.time_scale = 2.0
	var cap: int = dir.police_budget()
	assert_true(cap >= 6, "force cap for the test (%d)" % cap)
	# Push: someone is inside the held room within 20 s of BUILD (it took the door to get there).
	var reached_build: bool = await wait_until(func() -> bool: return dir.assault_phase == Enums.AssaultPhase.BUILD, 10.0)
	assert_true(reached_build, "assault BUILD")
	var t_build: float = _sim_t
	var entered: bool = await wait_until(func() -> bool:
		for u: NpcBase in dir.alive_units():
			if _inside(u.global_position):
				return true
		return false, 12.0)
	var t_enter: float = _sim_t - t_build
	print("[PO6-16] first unit inside the room %.1f s after BUILD (cap %d)" % [t_enter, cap])
	assert_true(entered, "police entered the room the crew holds")
	assert_true(door.is_open, "they opened the closed door on the way")
	# Sustain: the alive count stays near the cap; kills are replaced.
	var in_sustain: bool = await wait_until(func() -> bool: return dir.assault_phase == Enums.AssaultPhase.SUSTAIN, 10.0)
	assert_true(in_sustain, "SUSTAIN")
	await _sim(4.0)
	var samples: Array[int] = []
	var inside_max: int = 0
	var doorway_samples: Array[int] = []
	for i: int in range(24):
		if i == 4 or i == 12:
			var units: Array[NpcBase] = dir.alive_units()
			for k: int in range(mini(3, units.size())):
				units[k].die({}, 0)
		await _sim(1.0)
		if dir.assault_phase != Enums.AssaultPhase.SUSTAIN:
			break
		samples.append(dir.alive_count())
		var inside: int = 0
		for u: NpcBase in dir.alive_units():
			if _inside(u.global_position):
				inside += 1
		inside_max = maxi(inside_max, inside)
		var at_door: int = 0
		for u: NpcBase in dir.alive_units():
			if _in_doorway(u.global_position):
				at_door += 1
		doorway_samples.append(at_door)
	print("[PO6-16] sustain alive samples %s, max inside %d, in doorway %s" % [samples, inside_max, doorway_samples])
	for u: NpcBase in dir.alive_units():
		var b: PoliceBrain = u.get_node_or_null(^"Brain") as PoliceBrain
		print("[PO6-16]   %s (%.1f, %.1f) mode %s" % [u.name, u.global_position.x, u.global_position.z, b.mode if b else &"-"])
	assert_true(samples.size() >= 15, "sampled most of the sustain (%d)" % samples.size())
	var near_cap: int = 0
	for n: int in samples:
		if n >= cap - 2:
			near_cap += 1
	assert_true(float(near_cap) >= 0.7 * float(samples.size()),
		"alive stays within 2 of the cap %d in >= 70%% of sustain samples %s" % [cap, samples])
	assert_true(inside_max >= 3, "several units inside the room at once (%d)" % inside_max)
	var clumped: int = 0
	for n: int in doorway_samples:
		if n > 3:
			clumped += 1
	assert_true(float(clumped) <= 0.2 * float(doorway_samples.size()),
		"no standing clump in the doorway (> 3 units within 1.5 m of it) %s" % [doorway_samples])
	# Wave end (ENV C's siren loop stops on FADE / CONTROL): FADE -> CONTROL (wave 2) -> ANTICIPATION / BUILD again.
	var wave2: bool = await wait_until(func() -> bool:
		return _phases.has(Vector2i(Enums.AssaultPhase.BUILD, 2)), 30.0)
	assert_true(wave2, "wave 2 BUILD (phases %s)" % [_phases])
	var i_fade: int = _phases.find(Vector2i(Enums.AssaultPhase.FADE, 1))
	var i_ctrl: int = _phases.find(Vector2i(Enums.AssaultPhase.CONTROL, 2))
	var i_ant: int = _phases.find(Vector2i(Enums.AssaultPhase.ANTICIPATION, 2))
	var i_build: int = _phases.find(Vector2i(Enums.AssaultPhase.BUILD, 2))
	assert_true(i_fade >= 0 and i_ctrl > i_fade and i_ant > i_ctrl and i_build > i_ant,
		"wave 1 ends FADE -> CONTROL, wave 2 re-emits ANTICIPATION -> BUILD (%s)" % [_phases])
