## D-116 turn in place with ENV D's turn_l_45 / turn_r_45 (12 f = 0.4 s, 45 deg; turn_l / turn_r 90 deg over 0.8 s,
## both 112.5 deg/s). TurnInPlace: 20..67.5 deg -> turn_*_45, above -> turn_l / turn_r, below 20 a short snap with no
## clip; speed_scale = clip deg / diff (0.75..1.5) and the rig yaws at diff / (length / speed_scale) so the rig and
## the clip finish together. A rig without the 45 clips turns with turn_l / turn_r.
extends TestCase

const ANIM_TEST: GDScript = preload("res://tests/a/test_anim_driver.gd")
const HINT_SCRIPT: String = "extends Node\nvar anim_hint: StringName = &\"\"\n"
const DT: float = 1.0 / 60.0

var _nodes: Array[Node] = []


func after_each() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	await wait_frames(2)


## A guard on the code-built test rig with turn_l / turn_r at 0.8 s and, `with_45`, turn_l_45 / turn_r_45 at 0.4 s.
func _npc(with_45: bool) -> NpcBase:
	var npc: NpcBase = NpcBase.new()
	npc.role = &"guard"
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	var rig: Node3D = ANIM_TEST._test_rig()
	var lib: AnimationLibrary = (rig.get_node(^"AnimationPlayer") as AnimationPlayer).get_animation_library(
		AnimDriver.LIBRARY)
	for c: StringName in [&"turn_l", &"turn_r"]:
		lib.get_animation(c).length = 0.8
	if with_45:
		for c: StringName in [&"turn_l_45", &"turn_r_45"]:
			var a: Animation = Animation.new()
			a.length = 0.4
			lib.add_animation(c, a)
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


## Turn the body by `deg` (positive = left) and run the turn: [clip, speed_scale, mid-turn rig yaw rate deg/s,
## seconds until the rig met the body, final rig offset deg].
func _turn(npc: NpcBase, deg: float) -> Array:
	var d: AnimDriver = AnimDriver.of(npc)
	npc.rotation.y += deg_to_rad(deg)
	d.tick(DT)
	var c: StringName = d.clip
	var spd: float = d.player.speed_scale
	var y0: float = d.rig.rotation.y
	d.tick(DT)
	var rate: float = absf(rad_to_deg(d.rig.rotation.y - y0)) / DT
	var t: float = 2.0 * DT
	while absf(d.rig.rotation.y) > 0.0001 and t < 3.0:
		d.tick(DT)
		t += DT
	return [c, spd, rate, t, rad_to_deg(d.rig.rotation.y)]


## The rig yaws at the clip's own turn rate (clip deg / clip length = 112.5 deg/s, the planted feet's
## counter-rotation) within 5 % for 30 / 50 / 80 / 120 deg turns, both ways, and lands on the body with the clip.
func test_rig_yaw_matches_the_clip_turn_rate() -> void:
	assert_near(AnimTweak.data().turn_threshold_deg, 20.0, 0.001, "threshold 20 deg")
	for deg: float in [30.0, 50.0, 80.0, 120.0, -30.0, -50.0, -80.0, -120.0]:
		var npc: NpcBase = _npc(true)
		var r: Array = _turn(npc, deg)
		var use_45: bool = absf(deg) < 67.5
		var clip_deg: float = 45.0 if use_45 else 90.0
		var length: float = 0.4 if use_45 else 0.8
		var want_clip: String = ("turn_l" if deg > 0.0 else "turn_r") + ("_45" if use_45 else "")
		assert_eq(String(r[0]), want_clip, "%.0f deg -> %s" % [deg, want_clip])
		var s: float = clampf(clip_deg / absf(deg), 0.75, 1.5)
		assert_near(float(r[1]), s, 0.001, "%.0f deg: speed_scale = clip deg / diff" % deg)
		var clip_rate: float = clip_deg / length
		assert_near(float(r[2]), clip_rate, clip_rate * 0.05, "%.0f deg: rig yaw rate = clip rate (no slide)" % deg)
		assert_near(float(r[3]), length / s, 2.0 * DT, "%.0f deg: the rig and the clip finish together" % deg)
		assert_near(float(r[4]), 0.0, 0.01, "%.0f deg: the rig met the body" % deg)


func test_small_turn_snaps_without_a_clip() -> void:
	var npc: NpcBase = _npc(true)
	var r: Array = _turn(npc, 12.0)
	assert_false(String(r[0]).begins_with("turn_"), "below 20 deg no turn clip (%s)" % r[0])
	assert_near(float(r[3]), AnimTweak.data().turn_snap_s, 2.0 * DT, "snapped over turn_snap_s")


## The body turns on during a turn: the rig keeps the clip's rate (no faster catch-up), then a second clip / the snap
## finishes the turn.
func test_no_catch_up_faster_than_a_clip() -> void:
	var npc: NpcBase = _npc(true)
	var d: AnimDriver = AnimDriver.of(npc)
	npc.rotation.y += deg_to_rad(40.0)
	d.tick(DT)
	assert_eq(d.clip, &"turn_l_45")
	npc.rotation.y += deg_to_rad(30.0)
	var prev: float = d.rig.rotation.y - deg_to_rad(30.0)  # the rig counter-rotates by the body's step
	var max_rate: float = 0.0
	var clips: Dictionary = {}
	for _i: int in 120:
		d.tick(DT)
		if String(d.clip).begins_with("turn_"):
			max_rate = maxf(max_rate, absf(rad_to_deg(d.rig.rotation.y - prev)) / DT)
		prev = d.rig.rotation.y
		clips[d.clip] = true
	assert_true(max_rate <= 112.5 * 1.05, "never faster than the clip rate during a clip (%.1f deg/s)" % max_rate)
	assert_near(rad_to_deg(d.rig.rotation.y), 0.0, 0.01, "the turn finished (clips %s)" % [clips.keys()])


func test_fallback_without_the_45_clips() -> void:
	for deg: float in [30.0, -50.0]:
		var npc: NpcBase = _npc(false)
		var r: Array = _turn(npc, deg)
		assert_eq(r[0], &"turn_l" if deg > 0.0 else &"turn_r", "%.0f deg: turn_l / turn_r without the 45s" % deg)
		var s: float = clampf(90.0 / absf(deg), 0.75, 1.5)
		assert_near(float(r[1]), s, 0.001, "speed_scale from the 90 deg clip")
		assert_near(float(r[3]), 0.8 / s, 2.0 * DT, "the rig and the clip finish together")


func test_shield_maps_the_45_clips() -> void:
	var sc: Dictionary = AnimTweak.data().shield_clips
	assert_eq(sc.get(&"turn_l_45"), &"shield_idle")
	assert_eq(sc.get(&"turn_r_45"), &"shield_idle")
