## OF-A6 (OF-D1 follow-up, SOURCE bank_animdriver / queue_variants): Ostrander Federal ambient wiring in AnimDriver.
## A customer at a `queue` mark plays queue_idle* (the variants.queue_idle member by hash(net_id) % 3, the same index
## rule as cower / surrender, a random loop start), at a `counter` mark counter_customer, at a `check_desk` mark
## check_desk_write; the VIP's bodyguard (spawn tag guard_vip) calm at his post plays bouncer_idle; a panicked
## civilian pressing an alarm_button (S3.1) plays interact_mid (a phone stays phone_call). Every clip falls back when
## the rig lacks it. Code-rig cases always run; real-rig cases skip while ENV D's clips are not in the library.
extends TestCase

const AD: Script = preload("res://tests/a/test_anim_driver.gd")
const HINT_SCRIPT: String = "extends Node\nvar anim_hint: StringName = &\"idle\"\n"
const QUEUE: Array[StringName] = [&"queue_idle", &"queue_idle_b", &"queue_idle_c"]
const BANK_CLIPS: Array[StringName] = [&"queue_idle", &"queue_idle_b", &"queue_idle_c", &"counter_customer",
	&"check_desk_write", &"bouncer_idle"]
const REAL_CHAR: String = "bank_customer"
const REAL_GUARD: String = "security_officer"

var _nodes: Array[Node] = []
var _rt: HeistRuntime = null


func after_each() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


## A code rig (test_anim_driver's) plus `extra` looped clips.
func _rig(extra: Array[StringName]) -> Node3D:
	var root: Node3D = AD._test_rig()
	var lib: AnimationLibrary = (root.get_node(^"AnimationPlayer") as AnimationPlayer).get_animation_library(
		AnimDriver.LIBRARY)
	for c: StringName in extra:
		var a: Animation = Animation.new()
		a.length = 1.0
		a.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation(c, a)
	return root


func _brain_node() -> Node:
	var gs: GDScript = GDScript.new()
	gs.source_code = HINT_SCRIPT
	gs.reload()
	var brain: Node = Node.new()
	brain.name = "Brain"
	brain.set_script(gs)
	return brain


## An NPC on a code rig with `extra` clips (or on the real character `real_char` when given).
func _npc(role: StringName, net_id: int, extra: Array[StringName] = [], real_char: String = "") -> NpcBase:
	var npc: NpcBase = NpcBase.new()
	npc.role = role
	npc.net_id = net_id
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	if real_char == "":
		visual.add_child(_rig(extra))
	else:
		npc.visual_scene = load(NpcVisuals.scene_path(real_char)) as PackedScene
	npc.add_child(visual)
	npc.add_child(_brain_node())
	add_child(npc)
	_nodes.append(npc)
	return npc


## A net id whose variant index (hash(net_id) % 3) is `index`.
static func _id_for(index: int, start: int = 77000) -> int:
	var n: int = start
	while absi(hash(n)) % 3 != index:
		n += 1
	return n


func _playing(d: AnimDriver) -> String:
	return String(d.player.current_animation) if d.player.is_playing() else "<stopped>"


func _hint(npc: NpcBase, h: StringName) -> AnimDriver:
	npc.get_node(^"Brain").set(&"anim_hint", h)
	var d: AnimDriver = AnimDriver.of(npc)
	d.tick(0.016)
	return d


func _missing(d: AnimDriver, clips: Array[StringName], what: String) -> bool:
	for c: StringName in clips:
		if d == null or d.player == null or not d.player.has_animation("%s/%s" % [AnimDriver.LIBRARY, c]):
			skip("%s: the rig has no %s (ENV D's OF-D1 clips not checked out)" % [what, c])
			return true
	return false


func test_of_a6_mapping() -> void:
	assert_eq(AnimDriver.HINT_CLIPS[&"queue"], &"queue_idle", "queue -> queue_idle (was plain idle)")
	assert_eq(AnimDriver.HINT_CLIPS[&"counter"], &"counter_customer", "counter -> counter_customer")
	assert_eq(AnimDriver.HINT_CLIPS[&"check_desk"], &"check_desk_write", "check_desk -> check_desk_write")
	assert_eq(AnimDriver.HINT_CLIPS[&"press_alarm"], &"interact_mid", "alarm button press -> interact_mid")
	assert_eq(AnimDriver.VARIANT_GROUPS[&"queue_idle"], QUEUE, "queue_idle is a variant group in SOURCE order")
	assert_true(AnimDriver.OFFSET_LOOP_GROUPS.has(&"queue_idle"), "a queue starts at random offsets (never syncs)")
	for a: StringName in [&"queue", &"counter", &"check_desk"]:
		assert_true(CivilianBrain.KNOWN_ACTIVITIES.has(a), "%s is a known civilian activity (held on its mark)" % a)
		assert_false(CivilianBrain.WANDER_ACTIVITIES.has(a), "%s stays on its mark (no wander)" % a)
	var n: NpcBase = _npc(&"civilian", _id_for(0), [&"counter_customer", &"check_desk_write"])
	assert_eq(_hint(n, &"counter").clip, &"counter_customer", "counter mark plays counter_customer")
	assert_eq(_playing(AnimDriver.of(n)), "humanoid/counter_customer", "player agrees")
	assert_eq(_hint(n, &"check_desk").clip, &"check_desk_write", "check_desk mark plays check_desk_write")
	assert_eq(_playing(AnimDriver.of(n)), "humanoid/check_desk_write", "player agrees")


func test_of_a6_fallback_when_clip_absent() -> void:
	var n: NpcBase = _npc(&"civilian", _id_for(1))  # the code rig: no OF-D1 clip, no bouncer_idle
	var d: AnimDriver = _hint(n, &"queue")
	assert_eq(_playing(d), "humanoid/idle", "no queue_idle*: a queue stands in idle (the old mapping)")
	_hint(n, &"counter")
	assert_eq(_playing(d), "humanoid/idle", "no counter_customer: idle (desk_type is seated, teller_count holds cash)")
	_hint(n, &"check_desk")
	assert_eq(_playing(d), "humanoid/idle", "no check_desk_write: idle")
	var g: NpcBase = _npc(&"guard", _id_for(2))
	g.spawn_info = {"tags": [&"guard_vip"]}
	var gd: AnimDriver = _hint(g, &"idle")
	assert_eq(gd.clip, &"bouncer_idle", "VIP bodyguard asks for bouncer_idle")
	assert_eq(_playing(gd), "humanoid/idle", "no bouncer_idle: idle (not idle_alert)")
	# Only queue_idle (no _b): index 1 plays the original.
	var one: NpcBase = _npc(&"civilian", _id_for(1), [&"queue_idle"])
	assert_eq(_hint(one, &"queue").clip, &"queue_idle", "variant missing: the group's original plays")


func test_of_a6_queue_variant_pick() -> void:
	for idx: int in 3:
		var n: NpcBase = _npc(&"civilian", _id_for(idx), QUEUE)
		var d: AnimDriver = _hint(n, &"queue")
		assert_eq(d.variant_index(), idx, "index = hash(net_id) % 3")
		assert_eq(d.clip, QUEUE[idx], "index %d queues with %s" % [idx, QUEUE[idx]])
		assert_eq(_playing(d), "humanoid/%s" % QUEUE[idx], "player agrees")
		assert_eq(d.pose_variant(&"cower"), &"cower", "the code rig has no cower_b/_c: the index is shared, not a clip")
		assert_true(d._loop_offsets.has(&"queue_idle"), "a loop start offset was drawn for the queue group")
	# Same index as the cower / surrender groups (one personality).
	var with_cower: Array[StringName] = QUEUE.duplicate()
	with_cower.append(&"cower_c")
	var m: NpcBase = _npc(&"civilian", _id_for(2), with_cower)
	var md: AnimDriver = _hint(m, &"queue")
	assert_eq(md.clip, &"queue_idle_c", "index 2 queues with _c")
	assert_eq(md.pose_variant(&"cower"), &"cower_c", "and cowers with _c")


func test_of_a6_vip_guard_bouncer_only_calm_at_post() -> void:
	var g: NpcBase = _npc(&"guard", _id_for(0), [&"bouncer_idle"])
	g.spawn_info = {"tags": [&"guard_vip"]}
	var d: AnimDriver = _hint(g, &"idle")
	assert_eq(d.clip, &"bouncer_idle", "calm VIP bodyguard at his post: bouncer_idle")
	assert_eq(_hint(g, &"investigate_look").clip, &"investigate_look", "the post look-around still plays")
	g.alert_state = Enums.AlertState.CURIOUS
	assert_ne(_hint(g, &"idle").clip, &"bouncer_idle", "alerted: not the doorman stance")
	var plain: NpcBase = _npc(&"guard", _id_for(1), [&"bouncer_idle"])
	plain.spawn_info = {"tags": [&"guard_lobby"]}
	assert_eq(_hint(plain, &"idle").clip, &"idle", "other OF posts idle as before")
	var civ: NpcBase = _npc(&"civilian", _id_for(2), [&"bouncer_idle"])
	civ.spawn_info = {"tags": [&"guard_vip"]}
	assert_eq(_hint(civ, &"idle").clip, &"idle", "guards only")


## S3.1: the civilian's CALLING hint depends on the call point: alarm button -> press_alarm, phone -> call.
func test_of_a6_alarm_button_press_plays_interact_mid() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 4343, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 1)})
	var civ: NpcBase = _rt.npcs(&"civilian")[0] as NpcBase
	var b: CivilianBrain = civ.get_node(^"Brain") as CivilianBrain
	civ.global_position = Vector3(0, 0.05, 0)
	var button: Node3D = Node3D.new()
	button.name = "TestAlarmButton"
	_rt.dynamic_root.add_child(button)
	button.global_position = Vector3(0, 0.05, -5)
	CivilianTargets.add_call_point(button, CivilianTargets.REASON_BUTTON)
	(_rt.crew_controller(0) as CrewController).set_masked(true)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 15)))
	await wait_physics_frames(2)
	civ.notify_crew_spotted(_rt.crew_controller(0))
	assert_eq(b.mode, CivilianBrain.Mode.RUN_TO_CALL, "running to the alarm button")
	assert_true(await wait_until(func() -> bool: return b.is_calling(), 5.0), "reached the button")
	assert_eq(b.anim_hint, &"press_alarm", "pressing the alarm button, not a phone call")
	var d: AnimDriver = AnimDriver.of(civ)
	if d != null and d.player != null:
		assert_eq(d._hint(), &"press_alarm", "the driver reads the press")
		assert_eq(AnimDriver.HINT_CLIPS[d._hint()], &"interact_mid", "-> interact_mid")


func test_of_a6_real_rig_queue_counter_desk() -> void:
	for idx: int in 3:
		var n: NpcBase = _npc(&"civilian", _id_for(idx, 78000), [], REAL_CHAR)
		await wait_frames(1)
		var d: AnimDriver = AnimDriver.of(n)
		assert_true(d != null and d.player != null, "real rig animated")
		if _missing(d, BANK_CLIPS, "real-rig bank clips"):
			return
		d = _hint(n, &"queue")
		assert_eq(_playing(d), "humanoid/%s" % QUEUE[idx], "real rig index %d: %s" % [idx, QUEUE[idx]])
		assert_true(d.player.get_animation("humanoid/%s" % QUEUE[idx]).loop_mode != Animation.LOOP_NONE, "loops")
		await wait_frames(1)
		_hint(n, &"counter")
		assert_eq(_playing(d), "humanoid/counter_customer", "real rig counter_customer")
		_hint(n, &"check_desk")
		assert_eq(_playing(d), "humanoid/check_desk_write", "real rig check_desk_write")
		_hint(n, &"press_alarm")
		assert_eq(_playing(d), "humanoid/interact_mid", "real rig interact_mid")


func test_of_a6_real_rig_vip_bouncer() -> void:
	var g: NpcBase = _npc(&"guard", _id_for(0, 79000), [], REAL_GUARD)
	g.spawn_info = {"tags": [&"guard_vip"]}
	await wait_frames(1)
	var d: AnimDriver = AnimDriver.of(g)
	assert_true(d != null and d.player != null, "real rig animated")
	if _missing(d, [&"bouncer_idle"], "real-rig bouncer"):
		return
	_hint(g, &"idle")
	assert_eq(_playing(d), "humanoid/bouncer_idle", "real rig: the bodyguard stands as a doorman")
