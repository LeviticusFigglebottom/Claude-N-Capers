## D-132 (3): AnimLod, the NPC animation LOD vs the local camera (bands, stagger, exemptions, headless fallback) and
## clip-event parity: over 30 s at 60 fps an NPC at 25 m (every 2nd frame) and at 45 m (every 4th) emits the same
## method-track keys and clip changes, in the same order, as a full-rate NPC, each within one cadence step.
## Uses a rig built in code whose clips carry method tracks into an `Events` recorder node.
extends TestCase

const DT: float = 1.0 / 60.0
const RECORDER: String = "extends Node\nvar now: float = 0.0\nvar log: Array = []\n" \
	+ "func ev(tag: String) -> void:\n\tlog.append([tag, now])\n"
## clip -> [length, looped, [[key time, tag], ...]]
const CLIPS: Dictionary = {
	&"idle": [2.0, true, [[0.5, "idle_breath"], [1.5, "idle_shift"]]],
	&"idle_alert": [2.0, true, [[1.0, "alert_breath"]]],
	&"walk": [1.0, true, [[0.25, "walk_foot_l"], [0.75, "walk_foot_r"]]],
	&"run": [0.7, true, [[0.17, "run_foot_l"], [0.52, "run_foot_r"]]],
	&"reload_rifle": [1.9, false, [[0.3, "reload_mag_out"], [1.2, "reload_done"]]],
	&"fire_rifle": [0.3, false, [[0.05, "fire_recoil"]]],
	&"aim_rifle": [1.0, true, []],
	&"death_front": [1.2, false, [[0.6, "death_impact"]]],
	&"death_back": [1.2, false, [[0.6, "death_impact"]]],
	&"hit_react": [0.5, false, []],
	&"turn_l": [0.8, false, []],
	&"turn_r": [0.8, false, []],
	&"hands_up": [1.0, true, []],
}

var _nodes: Array[Node] = []


func before_each() -> void:
	AnimLod.allow_headless = false
	AnimLod.invalidate()


func after_each() -> void:
	AnimLod.allow_headless = false
	AnimLod.invalidate()
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	await wait_frames(1)


static func _rig() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "LodRig"
	var skel: Skeleton3D = Skeleton3D.new()
	skel.name = "Skeleton3D"
	for b: String in ["root", "upper_arm.L", "forearm.L", "hand.L", "hand.R", "spine"]:
		skel.add_bone(b)
	skel.set_bone_parent(2, 1)
	skel.set_bone_parent(3, 2)
	root.add_child(skel)
	for side: String in ["R", "L"]:
		var hand: BoneAttachment3D = BoneAttachment3D.new()
		hand.name = "Hand" + side
		hand.bone_name = "hand." + side
		skel.add_child(hand)
		var socket: Marker3D = Marker3D.new()
		socket.name = "Socket"
		hand.add_child(socket)
	var gs: GDScript = GDScript.new()
	gs.source_code = RECORDER
	gs.reload()
	var rec: Node = Node.new()
	rec.name = "Events"
	rec.set_script(gs)
	root.add_child(rec)
	var ap: AnimationPlayer = AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	var lib: AnimationLibrary = AnimationLibrary.new()
	for c: StringName in CLIPS:
		var spec: Array = CLIPS[c]
		var a: Animation = Animation.new()
		a.length = float(spec[0])
		a.loop_mode = Animation.LOOP_LINEAR if bool(spec[1]) else Animation.LOOP_NONE
		var rt: int = a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(rt, NodePath("Skeleton3D:spine"))
		a.rotation_track_insert_key(rt, 0.0, Quaternion())
		a.rotation_track_insert_key(rt, a.length, Quaternion(Vector3.UP, 0.5))
		var keys: Array = spec[2]
		if not keys.is_empty():
			var mt: int = a.add_track(Animation.TYPE_METHOD)
			a.track_set_path(mt, NodePath("Events"))
			for k: Array in keys:
				a.track_insert_key(mt, float(k[0]), {"method": &"ev", "args": [String(k[1])]})
		lib.add_animation(c, a)
	ap.add_animation_library(AnimDriver.LIBRARY, lib)
	ap.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE  # keys land inside the frame
	root.add_child(ap)
	return root


func _npc(net_id: int, pos: Vector3 = Vector3.ZERO) -> NpcBase:
	var npc: NpcBase = NpcBase.new()
	npc.role = &"guard"
	npc.net_id = net_id
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	visual.add_child(_rig())
	npc.add_child(visual)
	add_child(npc)
	npc.global_position = pos
	_nodes.append(npc)
	return npc


func _drv(body: Node) -> AnimDriver:
	return AnimDriver.of(body)


## One simulated process frame as the engine runs it: an IDLE player samples itself first (tree order: Visual
## before AnimDriver), then the driver's _process (step_lod).
func _frame(d: AnimDriver, f: int) -> void:
	(d.rig.get_node(^"Events")).set(&"now", f * DT)
	if d.player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE:
		d.player.advance(DT)
	d.step_lod(DT, f)


## Driver at `dist_m` from a test camera, on screen or not.
func _view(d: AnimDriver, dist_m: float, on_screen: bool = true) -> void:
	d.lod.view_override = {"pos": d._body.global_position + Vector3(0.0, 0.9, dist_m), "on_screen": on_screen}


func test_band_selection_per_distance_and_visibility() -> void:
	var tw: AnimTweak = AnimTweak.data()
	assert_eq(tw.anim_lod_near_m, 15.0)
	assert_eq(tw.anim_lod_far_m, 30.0)
	assert_true(tw.anim_lod_enabled)
	var cases: Array = [
		[5.0, true, AnimLod.Band.FULL, 1], [14.9, true, AnimLod.Band.FULL, 1], [15.0, true, AnimLod.Band.NEAR, 2],
		[25.0, true, AnimLod.Band.NEAR, 2], [30.0, true, AnimLod.Band.NEAR, 2], [31.0, true, AnimLod.Band.FAR, 4],
		[45.0, true, AnimLod.Band.FAR, 4], [5.0, false, AnimLod.Band.FAR, 4], [25.0, false, AnimLod.Band.FAR, 4],
		[31.0, false, AnimLod.Band.PAUSED, 0], [80.0, false, AnimLod.Band.PAUSED, 0],
	]
	for c: Array in cases:
		var b: AnimLod.Band = AnimLod.band_for(float(c[0]), bool(c[1]), tw)
		assert_eq(b, c[2], "band at %.1f m on_screen=%s" % [c[0], c[1]])
		assert_eq(AnimLod.cadence_of(b, tw), c[3], "cadence at %.1f m on_screen=%s" % [c[0], c[1]])
	# Through a driver (injected view): ticks per 60 frames.
	var npc: NpcBase = _npc(4101)
	var d: AnimDriver = _drv(npc)
	for c: Array in [[5.0, true, 60], [25.0, true, 30], [45.0, true, 15], [20.0, false, 15], [45.0, false, 0]]:
		_view(d, float(c[0]), bool(c[1]))
		_frame(d, 0)  # settle the band (the first tick is always full rate)
		d.lod.ticks = 0
		for f: int in range(1, 61):
			_frame(d, f)
		assert_eq(d.lod.ticks, c[2], "%d ticks / 60 frames at %.0f m on_screen=%s" % [c[2], c[0], c[1]])
		var manual: bool = d.player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		assert_eq(manual, int(c[2]) != 60, "player MANUAL outside the full band (%.0f m)" % c[0])


## Run frames from `f` until the driver ticks once more; returns the next frame number.
func _until_tick(d: AnimDriver, f: int) -> int:
	var t: int = d.lod.ticks
	while d.lod.ticks == t and f < 10000:
		_frame(d, f)
		f += 1
	return f


func test_layers_by_band() -> void:
	var npc: NpcBase = _npc(4102)
	var d: AnimDriver = _drv(npc)
	assert_true(d.hold_layer != null and d.left_hand_ik != null, "rig has the hold layer and the left-hand IK")
	_view(d, 25.0)
	var f: int = _until_tick(d, 0)
	f = _until_tick(d, f)
	d.left_hand_ik.influence = 1.0
	d.left_hand_ik.active = true
	d.hold_layer.influence = 1.0
	d.hold_layer.active = true
	d.left_hand_ik.marker = d.rig  # a target, so only the LOD can turn it off
	f = _until_tick(d, f)
	assert_eq(d.lod.band, AnimLod.Band.NEAR)
	assert_false(d.left_hand_ik.active, "15-30 m: left-hand IK off")
	assert_eq(d.left_hand_ik.influence, 0.0, "15-30 m: left-hand IK influence 0 (blends back in near)")
	_view(d, 45.0)
	f = _until_tick(d, f)
	d.hold_layer.influence = 1.0
	d.hold_layer.active = true
	f = _until_tick(d, f)
	assert_eq(d.lod.band, AnimLod.Band.FAR)
	assert_eq(d.hold_layer.influence, 0.0, "> 30 m: hold layer influence 0")
	assert_false(d.hold_layer.active)
	var skel: Skeleton3D = d.rig.get_node(^"Skeleton3D") as Skeleton3D
	assert_eq(skel.modifier_callback_mode_process, Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL,
		"LOD: the skeleton runs its modifiers only on the driver's updates")
	_view(d, 5.0)
	_frame(d, f)
	assert_eq(skel.modifier_callback_mode_process, Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE, "full rate: IDLE again")
	assert_eq(d.player.callback_mode_process, AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE)


func test_stagger_by_net_id() -> void:
	var offsets: Dictionary = {}
	for id: int in range(1, 41):
		var o: int = AnimLod.stagger(id * 7919, 4)
		assert_true(o >= 0 and o < 4, "offset in [0, 4)")
		offsets[o] = int(offsets.get(o, 0)) + 1
		var due: int = 0
		for f: int in range(100, 104):
			due += 1 if AnimLod.due(id * 7919, f, 4) else 0
		assert_eq(due, 1, "net id %d ticks once per 4 frames" % (id * 7919))
	assert_eq(offsets.size(), 4, "a crowd spreads over every frame of the cadence: %s" % offsets)
	for o: int in offsets:
		assert_true(int(offsets[o]) <= 20, "no frame takes half the crowd: %s" % offsets)
	assert_eq(AnimLod.stagger(12345, 1), 0)
	# Two drivers at 45 m with different offsets tick on different frames.
	var a: AnimDriver = _drv(_npc(1))
	var ids: Array[int] = [2, 3, 4, 5, 6, 7, 8]
	var other: int = 2
	for id: int in ids:
		if AnimLod.stagger(id, 4) != AnimLod.stagger(1, 4):
			other = id
			break
	var b: AnimDriver = _drv(_npc(other))
	_view(a, 45.0)
	_view(b, 45.0)
	var same: int = 0
	for f: int in 40:
		var ta: int = a.lod.ticks
		var tb: int = b.lod.ticks
		_frame(a, f)
		_frame(b, f)
		if f > 0 and a.lod.ticks > ta and b.lod.ticks > tb:
			same += 1
	assert_eq(same, 0, "staggered drivers never tick on the same frame")


func test_exemptions() -> void:
	var tw: AnimTweak = AnimTweak.data()
	var npc: NpcBase = _npc(4103)
	var d: AnimDriver = _drv(npc)
	_view(d, 45.0)
	_frame(d, 0)
	_frame(d, 1)
	assert_eq(d.lod.band, AnimLod.Band.FAR, "a plain NPC at 45 m is LOD'd")
	npc.set_meta(AnimDriver.META_ANIM_OVERRIDE, &"hands_up")
	_frame(d, 2)
	assert_eq(d.lod.band, AnimLod.Band.FULL, "scripted override (PO6-17 META_ANIM_OVERRIDE): full rate")
	assert_eq(d.player.callback_mode_process, AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE, "player IDLE again")
	npc.remove_meta(AnimDriver.META_ANIM_OVERRIDE)
	npc.alert_state = Enums.AlertState.INTIMIDATED
	_frame(d, 3)
	assert_eq(d.lod.band, AnimLod.Band.FULL, "surrender sequence: full rate")
	npc.alert_state = Enums.AlertState.CALM
	npc.stun(2.0)
	_frame(d, 4)
	assert_eq(d.lod.band, AnimLod.Band.FULL, "stunned: full rate")
	npc.stun_left = 0.0
	_frame(d, 5)
	assert_eq(d.lod.band, AnimLod.Band.FAR)
	npc.die({"direction": Vector3(0, 0, -1)})
	_frame(d, 6)
	assert_eq(d.lod.band, AnimLod.Band.FULL, "dead (death clip settling, ragdoll handoff): full rate")
	# Crew bodies never LOD.
	var crew: CrewController = (load(CrewController.SCENE_PATH) as PackedScene).instantiate() as CrewController
	crew.setup(0, {"peer_id": 0, "is_ai": true, "display_name": "Bot"}, null)
	var visual: Node3D = crew.get_node(^"Visual") as Node3D
	for c: Node in visual.get_children():
		c.free()
	visual.add_child(_rig())
	add_child(crew)
	_nodes.append(crew)
	await wait_frames(2)
	var cd: AnimDriver = _drv(crew)
	assert_true(cd != null, "crew body driver")
	_view(cd, 45.0, false)
	cd.lod.ticks = 0
	for f: int in 8:
		_frame(cd, f)
	assert_eq(cd.lod.band, AnimLod.Band.FULL, "crew: full rate at any distance")
	assert_eq(cd.lod.ticks, 8)
	# Aimed at: a crew member's aim ray within anim_lod_aim_radius_m of the NPC.
	var target: NpcBase = _npc(4104, Vector3(0.0, 0.0, -25.0))
	var td: AnimDriver = _drv(target)
	crew.global_position = Vector3.ZERO
	crew.look_pitch = 0.0
	crew.look_yaw = 0.0  # -Z: at the target
	var eye: Vector3 = crew.eye_position()
	var chest: Vector3 = target.global_position + Vector3(0.0, tw.anim_lod_center_y_m, 0.0)
	crew.look_pitch = atan2(chest.y - eye.y, absf(chest.z - eye.z))
	_view(td, 25.0)
	_frame(td, 10)
	_frame(td, 11)
	assert_eq(td.lod.band, AnimLod.Band.FULL, "aimed at by a crew member: full rate")
	crew.look_yaw = PI * 0.5  # aiming off to the side
	_frame(td, 12)
	assert_eq(td.lod.band, AnimLod.Band.NEAR, "no longer aimed at: 15-30 m band")
	crew.look_yaw = atan2(1.5, 25.0)  # the ray passes ~1.5 m from the chest
	_frame(td, 13)
	assert_eq(td.lod.band, AnimLod.Band.FULL, "within ~2 m of the aim ray: full rate")


func test_headless_falls_back_to_full_rate() -> void:
	assert_eq(DisplayServer.get_name(), "headless", "this suite runs headless")
	var cam: Camera3D = Camera3D.new()
	add_child(cam)
	_nodes.append(cam)
	cam.global_position = Vector3(0.0, 1.65, 0.0)
	cam.current = true
	var npc: NpcBase = _npc(4105, Vector3(0.0, 0.0, 60.0))  # behind the camera, far: PAUSED if LOD applied
	var d: AnimDriver = _drv(npc)
	for f: int in 10:
		_frame(d, f)
	assert_eq(d.lod.band, AnimLod.Band.FULL, "headless: full rate whatever the camera")
	assert_eq(d.lod.ticks, 10)
	assert_eq(d.player.callback_mode_process, AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE)
	# The same scene with the LOD allowed headless (bench / this test): the real frustum check.
	AnimLod.allow_headless = true
	var cases: Array = [
		[Vector3(0, 0, -5), AnimLod.Band.FULL], [Vector3(0, 0, -20), AnimLod.Band.NEAR],
		[Vector3(0, 0, -40), AnimLod.Band.FAR], [Vector3(0, 0, 20), AnimLod.Band.FAR],
		[Vector3(0, 0, 40), AnimLod.Band.PAUSED], [Vector3(-200, 0, -5), AnimLod.Band.PAUSED],
	]
	var f2: int = 100
	for c: Array in cases:
		npc.global_position = c[0]
		f2 += 1
		_frame(d, f2)
		assert_eq(d.lod.band, c[1], "camera frustum band at %s" % c[0])
	cam.current = false
	cam.queue_free()
	await wait_frames(1)
	AnimLod.invalidate()
	_frame(d, f2 + 1)
	assert_eq(d.lod.band, AnimLod.Band.FULL, "no camera: full rate")
	AnimLod.allow_headless = false
	var tw: AnimTweak = AnimTweak.data()
	tw.anim_lod_enabled = false
	_view(d, 45.0, false)
	_frame(d, f2 + 2)
	tw.anim_lod_enabled = true
	assert_eq(d.lod.band, AnimLod.Band.FULL, "anim_lod_enabled off: full rate")


## Clip events (method-track keys + driver clip changes) of a 30 s scripted run. Every clip segment lasts longer than
## the far cadence step (a clip shown for fewer frames than one step, or a key an outgoing clip crosses during its
## crossfade within the same step, cannot be resolved at that cadence; D-121: gameplay reads none of them).
func _run_script(d: AnimDriver, npc: NpcBase) -> Array:
	var log: Array = []
	var last: StringName = &""
	for f: int in 1800:
		match f:
			300, 1420:
				npc.velocity = Vector3(0, 0, -1.6)
			700:
				npc.velocity = Vector3(0, 0, -3.5)
			1000, 1700:
				npc.velocity = Vector3.ZERO
			1100:
				d.play_oneshot(&"reload_rifle")
			1310, 1350, 1390:
				d.play_oneshot(&"fire_rifle")
			1720:
				npc.die({"direction": Vector3(0, 0, -1)})
		_frame(d, f)
		if d.clip != last:
			last = d.clip
			log.append(["clip:" + String(last), f * DT])
	var events: Array = (d.rig.get_node(^"Events")).get(&"log")
	return [log, events.duplicate()]


static func _tags(entries: Array) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for e: Array in entries:
		out.append(String(e[0]))
	return out


## "" when every reference event has a same-tag event in `got` within `tol` s (each matched once, in order: a
## matched event never precedes an earlier match by more than `tol`), else the first mismatch.
static func _match_events(want: Array, got: Array, tol: float, label: String = "") -> String:
	var worst: float = 0.0
	var used: Array[bool] = []
	used.resize(got.size())
	used.fill(false)
	var last_t: float = -INF
	for i: int in want.size():
		var hit: int = -1
		for j: int in got.size():
			if not used[j] and String(got[j][0]) == String(want[i][0]) \
					and absf(float(got[j][1]) - float(want[i][1])) <= tol:
				hit = j
				break
		if hit < 0:
			return "#%d %s @ %.3f s has no match" % [i, want[i][0], want[i][1]]
		used[hit] = true
		worst = maxf(worst, absf(float(got[hit][1]) - float(want[i][1])))
		if float(got[hit][1]) < last_t - tol:
			return "#%d %s out of order" % [i, want[i][0]]
		last_t = maxf(last_t, float(got[hit][1]))
	print("[d132] %s: %d events matched, worst offset %.4f s (tol %.4f s)" % [label, want.size(), worst, tol])
	return ""


func test_event_parity_30s() -> void:
	var full: NpcBase = _npc(5001, Vector3(0, 0, 0))
	var near: NpcBase = _npc(5002, Vector3(10, 0, 0))
	var far: NpcBase = _npc(5003, Vector3(20, 0, 0))
	_view(_drv(full), 5.0)
	_view(_drv(near), 25.0)
	_view(_drv(far), 45.0)
	var ref: Array = _run_script(_drv(full), full)
	assert_eq(_drv(full).lod.ticks, 1800, "reference ticks every frame")
	for pair: Array in [[near, 2, "25 m"], [far, 4, "45 m"]]:
		var npc: NpcBase = pair[0]
		var cad: int = pair[1]
		var got: Array = _run_script(_drv(npc), npc)
		var tol: float = cad * DT + 0.001
		for k: int in 2:
			var what: String = "clip changes" if k == 0 else "method-track keys"
			var want_tags: PackedStringArray = _tags(ref[k])
			var got_tags: PackedStringArray = _tags(got[k])
			assert_true(want_tags.size() > (8 if k == 0 else 40), "%s: the script produces events (%d)" % [what, want_tags.size()])
			assert_eq(got_tags.size(), want_tags.size(), "%s %s: same count" % [pair[2], what])
			var err: String = _match_events(ref[k], got[k], tol, "%s %s" % [pair[2], what])
			assert_eq(err, "", "%s %s: same events, same order (up to events < one cadence step apart), each within %.3f s"
				% [pair[2], what, tol])
			if err != "":
				print("[d132] %s %s\n  want %s\n  got  %s" % [pair[2], what, ref[k], got[k]])
		assert_true(_drv(npc).lod.ticks < 1800 / cad + 200, "%s: LOD ticked %d / 1800 frames" % [pair[2], _drv(npc).lod.ticks])
	for tag: String in ["reload_done", "fire_recoil", "death_impact", "walk_foot_l", "run_foot_r", "idle_breath"]:
		assert_true(_tags(ref[1]).has(tag), "reference emitted %s" % tag)


func test_paused_resume_catches_up() -> void:
	var ref: NpcBase = _npc(6001, Vector3(0, 0, 0))
	var lod: NpcBase = _npc(6002, Vector3(10, 0, 0))
	var rd: AnimDriver = _drv(ref)
	var ld: AnimDriver = _drv(lod)
	_view(rd, 5.0)
	_view(ld, 5.0)
	ref.velocity = Vector3(0, 0, -1.6)
	lod.velocity = Vector3(0, 0, -1.6)
	for f: int in 60:
		_frame(rd, f)
		_frame(ld, f)
	_view(ld, 45.0, false)
	var t0: int = ld.lod.ticks
	for f: int in range(60, 200):
		_frame(rd, f)
		_frame(ld, f)
	assert_eq(ld.lod.band, AnimLod.Band.PAUSED, "off screen beyond 30 m: paused")
	assert_eq(ld.lod.ticks, t0, "paused: no ticks")
	assert_near(ld.lod.banked_s(), 140 * DT, 0.0001, "paused time is banked")
	var before: float = ld.player.current_animation_position
	_frame(rd, 200)
	_view(ld, 25.0)  # back on screen (15-30 m)
	var f: int = 200
	_frame(ld, f)
	while ld.lod.banked_s() > 0.0 and f < 204:
		f += 1
		_frame(rd, f)
		_frame(ld, f)
	assert_true(f - 200 < 2, "resumed within one cadence step (%d frames)" % (f - 200))
	assert_ne(ld.player.current_animation_position, before, "the pose moved on")
	var len: float = ld.player.current_animation_length
	var diff: float = absf(wrapf(ld.player.current_animation_position - rd.player.current_animation_position, -len * 0.5, len * 0.5))
	assert_true(diff <= 2 * DT + 0.001, "caught up to the full-rate pose (off by %.4f s)" % diff)
	assert_eq(ld.clip, rd.clip)



## OF cast perf audit (D ca74efe3): an NPC's held weapon stops drawing at its body's CrowdLod switch (the body meshes'
## visibility_range_end) and casts shadows only in the FULL band.
func test_npc_weapon_range_and_shadows_follow_the_body() -> void:
	var npc: NpcBase = _npc(4140)
	var d: AnimDriver = _drv(npc)
	var body: MeshInstance3D = MeshInstance3D.new()
	body.visibility_range_end = 25.0
	d.rig.add_child(body)
	var wv: WeaponVisual = WeaponVisual.new()
	var gun: MeshInstance3D = MeshInstance3D.new()
	wv.add_child(gun)
	d.rig.add_child(wv)
	d.held_visuals._crowd_cull(d.rig, wv)
	assert_eq(gun.visibility_range_end, 25.0, "the weapon culls at the body's switch distance")
	_view(d, 5.0)
	var f: int = _until_tick(d, 0)
	assert_eq(d.lod.band, AnimLod.Band.FULL)
	assert_eq(gun.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "near: weapon shadows on")
	_view(d, 25.0)
	f = _until_tick(d, f)
	assert_eq(d.lod.band, AnimLod.Band.NEAR)
	assert_eq(gun.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "past the near tier: no weapon shadows")
	_view(d, 5.0)
	f = _until_tick(d, f)
	assert_eq(gun.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "back near: shadows on again")


## ENV D far weapon silhouettes (D 9216f31f): the NPC weapon id's silhouette sits beside the WeaponVisual under
## HandR/Socket (identity: the same weapon frame), follows the weapon's visibility and is freed on refresh.
func test_npc_weapon_silhouette_beside_the_weapon() -> void:
	var npc: NpcBase = _npc(4141)
	var d: AnimDriver = _drv(npc)
	var scene: PackedScene = PackedScene.new()
	var root: Node3D = Node3D.new()
	scene.pack(root)
	root.free()
	assert_eq(ResourceSaver.save(scene, "user://test_d132_silhouette.tscn"), OK, "temp silhouette scene")
	HeldVisuals._silhouettes = {"npc_rifle": "user://test_d132_silhouette.tscn"}
	var socket: Node3D = Node3D.new()
	d.rig.add_child(socket)
	d.held_visuals._add_silhouette(socket, &"npc_rifle")
	var sil: Node3D = socket.get_node_or_null(NodePath(HeldVisuals.SILHOUETTE_NODE)) as Node3D
	assert_true(sil != null, "the silhouette is under the hand socket")
	assert_true(sil != null and sil.transform.is_equal_approx(Transform3D.IDENTITY), "in the weapon frame")
	d.held_visuals.show_silhouette(false)
	assert_false(sil.visible, "hidden with the weapon")
	d.held_visuals._add_silhouette(socket, &"npc_unknown")
	assert_eq(socket.get_child_count(), 1, "no silhouette for an unmapped weapon id")
	d.held_visuals.refresh_weapon()
	await wait_frames(1)
	assert_false(is_instance_valid(sil), "freed on refresh")
	HeldVisuals._silhouettes = null
