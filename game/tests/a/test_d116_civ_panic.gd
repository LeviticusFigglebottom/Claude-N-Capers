## D-116 civ panic variants (ENV D SOURCE `civ_panic_variants`): cower / flee play this body's variant (the surrender
## groups' index, hash(net_id) % 3), cower loops start at a per-body offset, flee* keeps flee's speed (v / 4.0);
## panic_start plays once before a civilian's first cower* (0.1 s in, then cower exact / cower_b 0.2 s / cower_c
## 0.3 s), never before a first flee*; deaths: cower_b -> death_crouch, cower_c the normal deaths, panic_start
## death_crouch from ~f10. Every clip falls back when the rig lacks it. Code-built rig (test_anim_driver's) plus D's
## clips added per test; the real-rig check skips while the trunk library lacks them.
extends TestCase

const ANIM_TEST: GDScript = preload("res://tests/a/test_anim_driver.gd")
const HINT_SCRIPT: String = "extends Node\nvar anim_hint: StringName = &\"\"\n"
const DT: float = 1.0 / 60.0
const PANIC_LEN: float = 0.8
const LIB_PATH: String = "res://world/characters/anim_humanoid.res"
const NEW_LOOPS: Array[StringName] = [&"cower_b", &"cower_c", &"flee_b", &"flee_c"]

var _nodes: Array[Node] = []


func after_each() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	await wait_frames(2)


## A net id whose variant index (AnimDriver.variant_index) is `idx`.
static func _net_id_for(idx: int) -> int:
	for n: int in range(81000, 82000):
		if absi(hash(n)) % 3 == idx:
			return n
	return 0


func _civ(idx: int, with_d_clips: bool) -> NpcBase:
	var npc: NpcBase = NpcBase.new()
	npc.role = &"civilian"
	npc.net_id = _net_id_for(idx)
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	var rig: Node3D = ANIM_TEST._test_rig()
	if with_d_clips:
		var lib: AnimationLibrary = (rig.get_node(^"AnimationPlayer") as AnimationPlayer).get_animation_library(
			AnimDriver.LIBRARY)
		for c: StringName in NEW_LOOPS:
			var a: Animation = Animation.new()
			a.length = 1.0
			a.loop_mode = Animation.LOOP_LINEAR
			lib.add_animation(c, a)
		for c: StringName in [&"panic_start", &"death_crouch"]:
			var o: Animation = Animation.new()
			o.length = PANIC_LEN
			lib.add_animation(c, o)
	visual.add_child(rig)
	npc.add_child(visual)
	var gs: GDScript = GDScript.new()
	gs.source_code = HINT_SCRIPT
	gs.reload()
	var brain: Node = Node.new()
	brain.name = "Brain"
	brain.set_script(gs)
	npc.add_child(brain)
	add_child(npc)
	_nodes.append(npc)
	var d: AnimDriver = AnimDriver.of(npc)
	d.set_process(false)
	d.tick(DT)
	return npc


func _hint(npc: NpcBase, h: StringName) -> void:
	npc.get_node("Brain").set(&"anim_hint", h)


func test_variants_share_the_surrender_index() -> void:
	for idx: int in 3:
		var npc: NpcBase = _civ(idx, true)
		var d: AnimDriver = AnimDriver.of(npc)
		assert_eq(d.variant_index(), idx, "net id picked for index %d" % idx)
		assert_eq(d.pose_variant(&"cower"), [&"cower", &"cower_b", &"cower_c"][idx], "cower variant %d" % idx)
		assert_eq(d.pose_variant(&"flee"), [&"flee", &"flee_b", &"flee_c"][idx], "flee variant %d" % idx)
		assert_eq(d.pose_variant(&"hands_up"), &"hands_up", "the rig has no hands_up_b/_c: the original")
	assert_true(AnimDriver.OFFSET_LOOP_GROUPS.has(&"cower") and not AnimDriver.OFFSET_LOOP_GROUPS.has(&"flee"),
		"cower loops start at an offset, flee keeps its gait phase")


func test_panic_start_then_cower_chain() -> void:
	var cases: Array = [[0, &"cower", 0.0], [1, &"cower_b", 0.2], [2, &"cower_c", 0.3]]
	for c: Array in cases:
		var npc: NpcBase = _civ(int(c[0]), true)
		var d: AnimDriver = AnimDriver.of(npc)
		_hint(npc, &"browse")
		d.tick(DT)
		_hint(npc, &"cower")
		d.tick(DT)
		assert_eq(d.clip, &"panic_start", "first panic: panic_start")
		assert_near(d.last_blend_s, 0.1, 0.001, "0.1 s in from the ambient clip")
		assert_eq(d.last_net_oneshot, [&"panic_start", 0.0, 1.0], "npc_oneshot panic_start sent to the clients")
		var t: float = DT
		while d.clip == &"panic_start" and t < 2.0:
			d.tick(DT)
			t += DT
		assert_eq(d.clip, c[1], "then %s" % c[1])
		assert_near(t, PANIC_LEN, 2.0 * DT, "after the whole one-shot")
		assert_near(d.last_blend_s, float(c[2]), 0.001, "%s crossfade" % c[1])
		if c[1] == &"cower":
			assert_near(d.player.current_animation_position, 0.0, 0.001, "cower starts on frame 0 (exact chain)")
		_hint(npc, &"browse")
		d.tick(DT)
		_hint(npc, &"cower")
		d.tick(DT)
		assert_eq(d.clip, c[1], "panic_start plays once per body")


## Lead fix: the real brain always runs first, so a first flee* does not use panic_start up; it plays before the
## first cower* (once).
func test_flee_first_then_panic_start_before_the_first_cower() -> void:
	var npc: NpcBase = _civ(1, true)
	var d: AnimDriver = AnimDriver.of(npc)
	npc.alert_state = Enums.AlertState.PANICKED
	_hint(npc, &"flee")
	npc.velocity = Vector3(0, 0, -4.0)
	d.tick(DT)
	assert_eq(d.clip, &"flee_b", "a first flee* runs at once")
	assert_true(d.last_net_oneshot.is_empty(), "no npc_oneshot while fleeing")
	assert_near(d.player.speed_scale, 1.0, 0.001, "flee_b runs at flee's 4.0 m/s")
	npc.velocity = Vector3.ZERO
	_hint(npc, &"cower")
	d.tick(DT)
	assert_eq(d.clip, &"panic_start", "arrived: panic_start before the first cower")
	assert_eq(d.last_net_oneshot, [&"panic_start", 0.0, 1.0], "sent to the clients")
	for _i: int in 60:
		d.tick(DT)
	assert_eq(d.clip, &"cower_b", "then cower_b")
	_hint(npc, &"flee")
	npc.velocity = Vector3(0, 0, -4.0)
	d.tick(DT)
	npc.velocity = Vector3.ZERO
	_hint(npc, &"cower")
	d.tick(DT)
	assert_eq(d.clip, &"cower_b", "once per body: no panic_start at the next cower")


## The real CivilianBrain panic path (unit_map, a civilian on the code-built rig + D's clips): notify_crew_spotted with
## no phone -> PANICKED, FLEE (flee*), then the brain cowers on arrival -> panic_start once, sent as npc_oneshot,
## then this body's cower*.
func test_real_brain_panic_plays_panic_start_once() -> void:
	var rt: HeistRuntime = await HeistLauncher.launch(&"unit_map", 4242, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 1)})
	var civ: NpcBase = rt.npcs(&"civilian")[0] as NpcBase
	var visual: Node3D = civ.get_node_or_null(^"Visual") as Node3D
	if visual == null:
		visual = Node3D.new()
		visual.name = "Visual"
		civ.add_child(visual)
	for c: Node in visual.get_children():
		c.queue_free()
	var rig: Node3D = ANIM_TEST._test_rig()
	var lib: AnimationLibrary = (rig.get_node(^"AnimationPlayer") as AnimationPlayer).get_animation_library(
		AnimDriver.LIBRARY)
	for c: StringName in NEW_LOOPS:
		var a: Animation = Animation.new()
		a.length = 1.0
		a.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation(c, a)
	var o: Animation = Animation.new()
	o.length = PANIC_LEN
	lib.add_animation(&"panic_start", o)
	await wait_frames(1)
	visual.add_child(rig)
	var d: AnimDriver = AnimDriver.ensure(civ)
	assert_true(d != null and d.player != null, "the civilian is animated")
	if d == null or d.player == null:
		rt.teardown()
		return
	civ.global_position = Vector3(0, 0.05, 0)
	var crew: CrewController = rt.crew_controller(0) as CrewController
	crew.set_masked(true)
	rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 3)))
	await wait_physics_frames(3)
	var b: CivilianBrain = civ.get_node(^"Brain") as CivilianBrain
	civ.notify_crew_spotted(crew)
	assert_eq(civ.alert_state, Enums.AlertState.PANICKED, "panicked")
	var seq: Array[StringName] = []
	var starts: int = 0
	var t: float = 0.0
	while t < 20.0:
		await wait_frames(1)
		t += get_process_delta_time()
		if seq.is_empty() or seq[-1] != d.clip:
			seq.append(d.clip)
			if d.clip == &"panic_start":
				starts += 1
		if CivPanic.family(d.clip) == &"cower" and b.mode == CivilianBrain.Mode.COWER:
			break
	var fled: bool = seq.any(func(c: StringName) -> bool: return CivPanic.family(c) == &"flee")
	assert_true(fled, "the brain fled first (%s)" % [seq])
	assert_eq(starts, 1, "panic_start once, on the brain's first cower (%s)" % [seq])
	var i: int = seq.find(&"panic_start")
	assert_true(i >= 0 and i + 1 < seq.size() and CivPanic.family(seq[i + 1]) == &"cower",
		"then cower* (%s)" % [seq])
	assert_eq(d.last_net_oneshot, [&"panic_start", 0.0, 1.0], "panic_start sent as npc_oneshot")
	rt.teardown()
	await wait_frames(1)


func test_deaths_by_pose() -> void:
	var tw: AnimTweak = AnimTweak.data()
	assert_eq(tw.death_by_pose.get(&"cower_b"), &"death_crouch", "cower_b -> death_crouch")
	assert_false(tw.death_by_pose.has(&"cower_c"), "cower_c (standing): the normal deaths")
	for early: bool in [true, false]:
		var npc: NpcBase = _civ(0, true)
		var d: AnimDriver = AnimDriver.of(npc)
		_hint(npc, &"cower")
		d.tick(DT)
		var dt: float = 0.1 if early else 0.5
		d.player.seek(dt, true)
		npc.alive = false
		d.tick(DT)
		if early:
			assert_false(d.clip == &"death_crouch", "killed in panic_start before f10: a normal death (%s)" % d.clip)
		else:
			assert_eq(d.clip, &"death_crouch", "killed in panic_start after f10: death_crouch")


func test_falls_back_without_the_clips() -> void:
	var npc: NpcBase = _civ(1, false)
	var d: AnimDriver = AnimDriver.of(npc)
	_hint(npc, &"cower")
	d.tick(DT)
	assert_eq(d.clip, &"cower", "no cower_b / panic_start: cower at once (today)")
	npc.alert_state = Enums.AlertState.PANICKED
	_hint(npc, &"flee")
	npc.velocity = Vector3(0, 0, -4.0)
	d.tick(DT)
	assert_eq(d.clip, &"flee", "no flee_b: flee")
	assert_eq(String(d.player.current_animation), "humanoid/flee")


## D's real clips (env/d-art until they reach trunk): present together, panic_start ends where cower starts.
func test_real_rig_clips_when_present() -> void:
	var lib: AnimationLibrary = load(LIB_PATH) as AnimationLibrary
	if lib == null or not lib.has_animation(&"panic_start"):
		print("[d116 civ panic] skip: the humanoid library has no panic_start yet")
		return
	for c: StringName in NEW_LOOPS:
		assert_true(lib.has_animation(c), "%s present" % c)
		assert_true(lib.get_animation(c).loop_mode != Animation.LOOP_NONE, "%s loops" % c)
	var ps: Animation = lib.get_animation(&"panic_start")
	assert_eq(ps.loop_mode, Animation.LOOP_NONE, "panic_start one-shot")
	assert_near(ps.length, 24.0 / 30.0, 0.01, "24 f")



## The real cast rig (civilian_clerk) with D's clips: panic_start, then this body's cower variant.
func test_real_rig_panic_chain_when_present() -> void:
	var lib: AnimationLibrary = load(LIB_PATH) as AnimationLibrary
	if lib == null or not lib.has_animation(&"panic_start"):
		print("[d116 civ panic] skip: the humanoid library has no panic_start yet")
		return
	for idx: int in 3:
		var npc: NpcBase = NpcBase.new()
		npc.role = &"civilian"
		npc.net_id = _net_id_for(idx)
		var visual: Node3D = Node3D.new()
		visual.name = "Visual"
		visual.add_child((load("res://world/characters/civilian_clerk/civilian_clerk.tscn") as PackedScene).instantiate())
		npc.add_child(visual)
		var gs: GDScript = GDScript.new()
		gs.source_code = HINT_SCRIPT
		gs.reload()
		var brain: Node = Node.new()
		brain.name = "Brain"
		brain.set_script(gs)
		npc.add_child(brain)
		add_child(npc)
		_nodes.append(npc)
		var d: AnimDriver = AnimDriver.of(npc)
		assert_true(d != null and d.player != null, "the clerk rig is animated")
		if d == null or d.player == null:
			return
		d.set_process(false)
		d.tick(DT)
		_hint(npc, &"cower")
		d.tick(DT)
		assert_eq(d.clip, &"panic_start", "index %d: panic_start first" % idx)
		for _i: int in 60:
			d.tick(DT)
		var want: StringName = [&"cower", &"cower_b", &"cower_c"][idx]
		assert_eq(d.clip, want, "index %d: then %s" % [idx, want])
		assert_eq(String(d.player.current_animation), "humanoid/%s" % want, "the player agrees")
