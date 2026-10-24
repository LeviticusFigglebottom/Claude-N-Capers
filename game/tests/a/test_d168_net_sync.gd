## D-168 (AH soak): transforms go out in chunks under the ENet MTU (56 civilians made one 4.3 kB unreliable packet), and
## a calm civilian far from every crew member is sent at 1 / CIV_SLOW_DIV of the transform rate. The host side runs
## offline here (begin() + _send_xforms on the authority); the per-peer ready gate is covered by the loopback tests.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _crowd(n: int, at: Vector3) -> Array[NpcBase]:
	var out: Array[NpcBase] = []
	for i: int in n:
		var p: Vector3 = at + Vector3(float(i % 8) * 1.2, 0.05, float(i / 8) * 1.2)
		out.append(_rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, p)))
	return out


func test_d168_xforms_are_chunked_under_the_mtu() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1680, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(2)
	_crowd(60, Vector3(-20, 0, -20))
	await wait_physics_frames(3)
	var ns: HeistNetSync = _rt.net_sync
	ns.begin()
	ns._send_xforms()  # the first send carries every transform (keyframe)
	assert_true(ns.last_xform_chunks >= 3, "60 civilians + crew: several packets (%d)" % ns.last_xform_chunks)
	assert_true(ns.last_xform_max_bytes <= HeistNetSync.XFORM_PACKET_BYTES,
		"every chunk within %d bytes (max %d)" % [HeistNetSync.XFORM_PACKET_BYTES, ns.last_xform_max_bytes])
	assert_true(HeistNetSync.XFORM_PACKET_BYTES + 200 < 1392, "payload + RPC framing under the ENet MTU")


func test_d168_far_calm_civilians_send_at_a_third_of_the_rate() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1681, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(2)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(25, 0.05, 25)))
	var far: Array[NpcBase] = _crowd(12, Vector3(-25, 0, -25))
	var near: Array[NpcBase] = _crowd(3, Vector3(22, 0, 22))
	await wait_physics_frames(3)
	var ns: HeistNetSync = _rt.net_sync
	ns.begin()
	ns._send_xforms()  # keyframe: everyone
	var crew_pos: Array[Vector3] = [_rt.crew_controller(0).global_position]
	assert_true(HeistNetSync._slow_civilian(far[0], crew_pos), "calm and far: slow")
	assert_false(HeistNetSync._slow_civilian(near[0], crew_pos), "near a crew member: full rate")
	var sent_far: Array[int] = []
	var sent_near: Array[int] = []
	for tick: int in HeistNetSync.CIV_SLOW_DIV:
		for n: NpcBase in far + near:
			n.global_position += Vector3(0.01, 0, 0)  # everyone moved since the last send
		ns._send_xforms()
		var f: int = 0
		for n: NpcBase in far:
			f += 1 if ns._last_xform[n.net_id] == NetEntityCodec.xform_of(n) else 0
		var m: int = 0
		for n: NpcBase in near:
			m += 1 if ns._last_xform[n.net_id] == NetEntityCodec.xform_of(n) else 0
		sent_far.append(f)
		sent_near.append(m)
	assert_eq(sent_near, [3, 3, 3] as Array[int], "near civilians every tick")
	var total: int = 0
	for f: int in sent_far:
		assert_true(f < far.size(), "far calm civilians: only a share per tick (%s)" % [sent_far])
		total += f
	assert_eq(total, far.size(), "each far civilian goes out once per CIV_SLOW_DIV ticks (%s)" % [sent_far])
	far[0].set_alert_state(Enums.AlertState.ALARMED)
	assert_false(HeistNetSync._slow_civilian(far[0], crew_pos), "a panicking civilian goes back to full rate")


## P6 churn: no whole-set keyframe burst. With nothing moving, every tracked transform is resent exactly once per
## KEYFRAME_TICKS sends (its staggered slot), a small slice per tick.
func test_p6_static_transforms_refresh_staggered() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1683, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(2)
	var crowd: Array[NpcBase] = _crowd(45, Vector3(-20, 0, -20))
	await wait_physics_frames(3)
	for n: NpcBase in crowd:
		n.process_mode = Node.PROCESS_MODE_DISABLED  # nothing moves
	var ns: HeistNetSync = _rt.net_sync
	ns.begin()
	ns._send_xforms()  # the first send carries everything
	var total: int = 0
	var max_per_tick: int = 0
	for t: int in HeistNetSync.KEYFRAME_TICKS:
		ns._send_xforms()
		total += ns.last_xform_sent
		max_per_tick = maxi(max_per_tick, ns.last_xform_sent)
	assert_eq(total, ns._last_xform.size(), "every tracked transform resent once per %d ticks (%d of %d)" % [
		HeistNetSync.KEYFRAME_TICKS, total, ns._last_xform.size()])
	assert_true(max_per_tick <= 4, "a small slice per tick, no burst (%d of %d)" % [max_per_tick, ns._last_xform.size()])
