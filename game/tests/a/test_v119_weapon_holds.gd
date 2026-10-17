## characters.md v1.19 (D-116 weapon holds, ENV D e016fbd5): a masked crew body (teammate or bot) holding a weapon
## idles in idle_alert_rifle / idle_alert_pistol (by AnimDriver.weapon_kind) instead of idle_alert; over walk / run /
## strafe the UpperBodyLayer carries hold_<kind> on the upper body (weight 1, 0.2 s blend); aiming keeps aim_*
## (never hold_*). Uses the crew body's real cast rig; a sub-case whose clip the rig lacks is skipped with a print.
extends TestCase

const HEISTER: StringName = &"rook"

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


func _bot() -> CrewController:
	var crew: CrewController = (load(CrewController.SCENE_PATH) as PackedScene).instantiate() as CrewController
	crew.setup(0, {"peer_id": 0, "is_ai": true, "display_name": "Bot"}, null)
	crew.heister = HEISTER  # D-073: the heister's cast body (generic crew is a capsule)
	add_child(crew)
	_nodes.append(crew)
	await wait_frames(3)  # CrewView.refresh is deferred
	return crew


## A heister's body on `crew` (CrewView.refresh_body), as a bot with a picked heister has in a heist.
static func _give_body(crew: CrewController) -> void:
	crew.heister = HEISTER
	var view: CrewView = CrewView.of(crew)
	if view != null:
		view.refresh()


func _missing(d: AnimDriver, clips: Array[StringName], what: String) -> bool:
	if d == null or d.player == null:
		print("[v119] skip %s: the crew body has no animated rig" % what)
		return true
	for c: StringName in clips:
		if not d.player.has_animation("%s/%s" % [AnimDriver.LIBRARY, c]):
			print("[v119] skip %s: the rig has no %s (ENV D assets not checked out)" % [what, c])
			return true
	return false


func _ticks(d: AnimDriver, n: int, dt: float = 0.05) -> void:
	for _i: int in n:
		d.tick(dt)


func test_idle_clip_per_weapon_kind() -> void:
	var crew: CrewController = await _bot()
	var d: AnimDriver = AnimDriver.of(crew)
	if _missing(d, [&"idle_alert_rifle", &"idle_alert_pistol"], "idle per kind"):
		return
	assert_true(d._holds_weapon, "the bot holds its equipped weapon")
	d.set_process(false)
	d.tick(0.016)
	assert_eq(d.clip, &"idle", "unmasked: plain idle (no weapon out)")
	crew.masked = true
	for kind: StringName in [&"rifle", &"pistol"]:
		d.weapon_kind = kind
		_ticks(d, 3)
		assert_eq(d.clip, StringName("idle_alert_" + kind), "masked, holding a %s, not aiming" % kind)
		assert_eq(String(d.player.current_animation), "humanoid/idle_alert_" + kind, "player agrees (%s)" % kind)
	d._aim_hold_left = 1.0
	d.tick(0.016)
	assert_true(String(d.clip).begins_with("aim_"), "aiming keeps aim_* (%s)" % d.clip)
	d._aim_hold_left = 0.0
	d._holds_weapon = false
	_ticks(d, 2)
	assert_eq(d.clip, &"idle_alert", "no weapon: idle_alert")


func test_upper_body_layer_while_moving_off_while_aiming() -> void:
	var crew: CrewController = await _bot()
	var d: AnimDriver = AnimDriver.of(crew)
	if _missing(d, [&"hold_rifle", &"hold_pistol", &"aim_rifle"], "hold layer"):
		return
	assert_true(d.hold_layer != null, "crew rig has the upper-body layer")
	assert_false(UpperBodyLayer.filtered("thigh.L") or UpperBodyLayer.filtered("hips"), "legs / hips not layered")
	assert_true(UpperBodyLayer.filtered("forearm.R") and UpperBodyLayer.filtered("index_02.L"), "arms / fingers are")
	d.set_process(false)
	crew.masked = true
	d.weapon_kind = &"rifle"
	_ticks(d, 2)
	assert_near(d.hold_layer.influence, 0.0, 0.001, "standing: layer off (idle_alert_rifle carries the hold)")
	crew.velocity = Vector3(0, 0, -1.6)
	_ticks(d, 1)
	assert_true(d.hold_layer.influence > 0.0 and d.hold_layer.influence < 1.0, "blends in (0.2 s)")
	_ticks(d, 6)
	assert_true(d.clip == &"walk" or d.clip == &"walk_start", "walking (%s)" % d.clip)
	# characters.md v1.25: hold_<kind>_<gait> (frame-locked to the base clip) when D has it, else hold_<kind>.
	assert_eq(d.hold_layer.clip, _hold(d, &"hold_rifle"), "hold_rifle (gait-locked) over the walk")
	assert_near(d.hold_layer.influence, 1.0, 0.001, "weight 1")
	assert_true(d.hold_layer.active and d.hold_layer.bone_count() >= 40, "active on the upper body (%d bones)" %
		d.hold_layer.bone_count())
	# The final pose: forearm.R follows the layer's hold clip at the layer's time, the thigh stays the walk's.
	var sk: Skeleton3D = d.rig.get_node("Skeleton3D") as Skeleton3D
	var hold: Animation = d.player.get_animation("humanoid/%s" % d.hold_layer.clip)
	var fa: int = sk.find_bone("forearm.R")
	var got: Array[Quaternion] = [Quaternion()]
	var grab: Callable = func() -> void:
		got[0] = sk.get_bone_pose_rotation(fa)
	sk.skeleton_updated.connect(grab)
	await wait_frames(3)
	sk.skeleton_updated.disconnect(grab)
	var track: int = hold.find_track(NodePath("Skeleton3D:forearm.R"), Animation.TYPE_ROTATION_3D)
	assert_true(track >= 0, "%s has a forearm.R rotation track" % d.hold_layer.clip)
	if track >= 0:
		var want: Quaternion = hold.rotation_track_interpolate(track, d.hold_layer.time)
		assert_true(got[0].angle_to(want) < 0.02, "forearm.R = %s's (off by %.3f rad)" % [d.hold_layer.clip,
			got[0].angle_to(want)])
	for v: Vector3 in [Vector3(1.2, 0, 0), Vector3(0, 0, -3.5)]:
		crew.velocity = v
		_ticks(d, 4)
		assert_eq(d.hold_layer.clip, _hold(d, &"hold_rifle"), "%s: hold layer over %s" % [v, d.clip])
		assert_near(d.hold_layer.influence, 1.0, 0.001, "%s: weight 1" % v)
	d.weapon_kind = &"pistol"
	_ticks(d, 1)
	assert_eq(d.hold_layer.clip, _hold(d, &"hold_pistol"), "pistol: hold_pistol (gait-locked)")
	d._aim_hold_left = 5.0
	_ticks(d, 2)
	assert_false(String(d.hold_layer.clip).begins_with("hold_"), "aiming: no hold_* (%s)" % d.hold_layer.clip)
	# D-116 (SOURCE police_combat): aim_pistol_run (the aim gait, frame-locked) when the rig has it
	var aim_run: StringName = &"aim_pistol_run" if d._has_clip(&"aim_pistol_run") else &"aim_pistol"
	assert_eq(d.hold_layer.clip, aim_run, "aim_* keeps priority on the upper body while moving")
	crew.velocity = Vector3.ZERO
	_ticks(d, 4)
	assert_eq(d.clip, &"run_stop", "stopping: run_stop (a locomotion transition)")
	assert_eq(d.hold_layer.clip, &"aim_pistol", "the stop keeps the aim on the upper body")
	_ticks(d, 20)  # past run_stop (0.67 s) and the 0.2 s blend out
	assert_true(String(d.clip).begins_with("aim_"), "standing and aiming: aim_* full body (%s)" % d.clip)
	assert_near(d.hold_layer.influence, 0.0, 0.001, "standing and aiming: layer off")


func test_loud_bots_show_hold_clips() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 5119, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1, "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(3)
	var bot: CrewController = _rt.crew_controller(1) as CrewController
	assert_true(bot != null and bot.is_ai, "an AI teammate in slot 1")
	if bot.heister == &"":
		_give_body(bot)
		await wait_frames(3)
	var d: AnimDriver = AnimDriver.of(bot)
	if _missing(d, [&"idle_alert_rifle", &"idle_alert_pistol"], "loud bot"):
		return
	EventBus.alarm_raised.emit(&"test", 0)
	await wait_seconds(0.6)
	assert_true(bot.masked, "the alarm masks the bot")
	# v1.23: mask_on plays through the mask-up (CrewActionAnim) when D's library has it; then the idle.
	await wait_until(func() -> bool: return d.clip != &"mask_on", 4.0)
	print("[v119] loud bot: %s (%s), weapon %s" % [d.clip, d.weapon_kind, d.weapon_visual])
	assert_eq(d.clip, StringName("idle_alert_" + d.weapon_kind), "loud bot idles holding its %s" % d.weapon_kind)
	assert_true(d.hold_layer != null, "and carries the hold layer for when it moves")


## characters.md v1.25 (HoldGait): the hold clip the layer should play over the driver's current base clip.
func _hold(d: AnimDriver, plain: StringName) -> StringName:
	return HoldGait.clip_for(plain, d.clip, d.player, AnimDriver.LIBRARY)
