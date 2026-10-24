## P6 co-op hardening (LEAD r313): client snapshot interpolation (NetInterp). Samples stamped with the server's send
## tick are rendered DELAY_S behind the newest server time: lerped between the two around it, extrapolated at most
## EXTRAP_MAX_S past the newest, snapped on a teleport, late chunks ignored; the local crew member, corpses and carried bags are
## never buffered.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func test_p6_sample_at_lerps_extrapolates_and_clamps() -> void:
	var a: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0, 0, 0))
	var b: Transform3D = Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(2, 0, 0))
	var buf: Array = [[1.0, a], [1.2, b]]
	assert_eq(NetInterp.sample_at(buf, 0.5), a, "before the first sample: the first")
	var ext: Transform3D = NetInterp.sample_at(buf, 1.25) as Transform3D
	assert_true(ext.origin.distance_to(Vector3(2.5, 0, 0)) < 0.001, "just past the last: extrapolated along it (%s)" % ext.origin)
	var cap: Transform3D = NetInterp.sample_at(buf, 2.0) as Transform3D
	var cap_x: float = 2.0 + 2.0 * NetInterp.EXTRAP_MAX_S / 0.2
	assert_true(cap.origin.distance_to(Vector3(cap_x, 0, 0)) < 0.001, "long past: capped at EXTRAP_MAX_S, then held (%s)" % cap.origin)
	var mid: Transform3D = NetInterp.sample_at(buf, 1.1) as Transform3D
	assert_true(mid.origin.distance_to(Vector3(1, 0, 0)) < 0.001, "halfway: halfway (%s)" % mid.origin)
	assert_near(mid.basis.get_euler().y, PI / 4.0, 0.01, "rotation slerped halfway")
	var c0: Array = [Vector3.ZERO, deg_to_rad(170.0), 0.0, false]
	var c1: Array = [Vector3(1, 0, 0), deg_to_rad(-170.0), 0.2, true]
	var cm: Array = NetInterp.lerp_xform(c0, c1, 0.5) as Array
	assert_true((cm[0] as Vector3).distance_to(Vector3(0.5, 0, 0)) < 0.001, "crew position lerped")
	assert_near(absf(wrapf(float(cm[1]), -PI, PI)), PI, 0.01, "yaw the short way round (through 180, not 0)")
	assert_eq(cm[3], true, "crouched from the newer sample")


func test_p6_push_buffers_npcs_and_renders_behind() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 6601, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(2)
	var npc: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, Vector3(5, 0.05, 5)))
	await wait_physics_frames(2)
	npc.process_mode = Node.PROCESS_MODE_DISABLED  # its own brain / motor must not move it during the test
	var ni: NetInterp = NetInterp.new()
	ni.setup(15.0)
	add_child(ni)
	ni.set_process(false)
	var p0: Vector3 = Vector3(5, 0.05, 5)
	ni.push({npc.net_id: Transform3D(Basis.IDENTITY, p0)}, 30)
	ni.push({npc.net_id: Transform3D(Basis.IDENTITY, p0 + Vector3(1, 0, 0))}, 31)
	assert_eq(ni.samples_in, 2, "both samples buffered")
	ni.push({npc.net_id: Transform3D(Basis.IDENTITY, p0 + Vector3(9, 0, 0))}, 30)
	assert_eq(ni.samples_in, 2, "a late chunk for an older tick is ignored")
	ni.push({npc.net_id: Transform3D(Basis.IDENTITY, p0 + Vector3(2, 0, 0))}, 32)
	# Render time = newest server time (32/15 s) - DELAY_S (1.5 ticks at 15 Hz) = tick 30.5: halfway from 30 to 31.
	ni._heard_at = NetInterp._now()
	ni._process(0.0)
	var want: Vector3 = p0 + Vector3(2.0 - NetInterp.DELAY_S * 15.0, 0, 0)
	assert_true(npc.global_position.distance_to(want) < 0.05, "rendered %.2f s behind the newest: %s vs %s" % [
		NetInterp.DELAY_S, npc.global_position, want])
	ni.push({npc.net_id: Transform3D(Basis.IDENTITY, p0 + Vector3(20, 0, 0))}, 33)
	assert_true(npc.global_position.distance_to(p0 + Vector3(20, 0, 0)) < 0.01, "a %.0f m+ jump snaps" % NetInterp.SNAP_M)
	ni.queue_free()


func test_p6_local_crew_corpse_and_carried_bag_are_not_buffered() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 6602, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1, "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(2)
	var local: CrewController = _rt.crew_controller(0) as CrewController
	var bot: CrewController = _rt.crew_controller(1) as CrewController
	var arr: Array = [Vector3.ZERO, 0.0, 0.0, false]
	assert_false(NetInterp.interpolates(local, arr), "the local crew member is client-predicted")
	assert_true(NetInterp.interpolates(bot, arr), "a remote crew member is interpolated")
	var npc: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, Vector3(3, 0.05, 3)))
	await wait_physics_frames(2)
	assert_true(NetInterp.interpolates(npc, npc.global_transform), "a live NPC is")
	npc.alive = false
	assert_false(NetInterp.interpolates(npc, npc.global_transform), "a corpse is not (its anchor owns the root)")
	var lm: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	var bag: LootBag = lm.spawn_bag(&"loot.cash_bricks", Transform3D(Basis.IDENTITY, Vector3(0, 0.3, -1)))
	await wait_physics_frames(2)
	assert_true(NetInterp.interpolates(bag, bag.global_transform), "a loose bag is")
	lm.carry(bag, local)
	assert_false(NetInterp.interpolates(bag, bag.global_transform), "a carried bag is not (it follows its carrier)")


## P6 server side: a remote shooter's claim is checked against where the target was on its screen (NetRewind window:
## DELAY_S + RTT / 2 + margin); host and AI shooters use the present only; positions older than the window never count.
func test_p6_rewind_accepts_a_remote_claim_where_the_client_saw_the_target() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 6603, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1, "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(2)
	var rw: NetRewind = _rt.net_sync.get_node_or_null(NetRewind.NODE_NAME) as NetRewind
	assert_true(rw != null, "the authority's NetSync has a NetRewind")
	var npc: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -8)))
	await wait_physics_frames(2)
	npc.process_mode = Node.PROCESS_MODE_DISABLED
	rw.set_physics_process(false)
	var now: Vector3 = npc.global_position
	# It ran +X: 0.12 s ago it was 0.6 m back, 0.5 s ago 2.2 m back (outside a ~0.2 s window with RTT 0).
	rw._clock = 10.0
	rw._hist = [[9.5, {npc.net_id: now - Vector3(2.2, 0, 0)}], [9.88, {npc.net_id: now - Vector3(0.6, 0, 0)}]]
	var host: CrewController = _rt.crew_controller(0) as CrewController
	var remote: CrewController = _rt.crew_controller(1) as CrewController
	remote.is_ai = false
	remote.peer_id = 4242  # a remote client's crew member
	var tol: float = CombatTweak.data().claim_head_tolerance_m
	var seen: Vector3 = npc.head_position() - Vector3(0.6, 0, 0)  # where the client's screen had the head
	assert_true(CombatSystem._near_over_lag(seen, npc.head_position(), npc, remote, tol), "remote: matched in the window")
	assert_false(CombatSystem._near_over_lag(seen, npc.head_position(), npc, host, tol), "host: the present only")
	var stale: Vector3 = npc.head_position() - Vector3(2.2, 0, 0)
	assert_false(CombatSystem._near_over_lag(stale, npc.head_position(), npc, remote, tol), "older than the window: no")
	remote.is_ai = true
	assert_false(CombatSystem._near_over_lag(seen, npc.head_position(), npc, remote, tol), "an AI shooter: the present only")


## P6: the playout clock advances with the frame and eases toward its target, so a packet that arrives early (jitter,
## a chunked batch) does not make render time jump; a big gap snaps.
func test_p6_playout_clock_does_not_jump_on_an_early_packet() -> void:
	var ni: NetInterp = NetInterp.new()
	ni.setup(15.0)
	add_child(ni)
	ni.set_process(false)
	ni.push({}, 30)
	ni.advance_clock(0.0)
	var t0: float = ni.render_time()
	assert_near(t0, 30.0 / 15.0 - NetInterp.DELAY_S, 0.02, "starts DELAY_S behind the newest tick")
	for i: int in 3:
		ni.advance_clock(0.01)
	var before: float = ni.render_time()
	ni.push({}, 31)  # 30 ms after tick 30: a whole tick early
	ni.advance_clock(0.01)
	var step: float = ni.render_time() - before
	assert_true(step > 0.0 and step < 0.012, "the clock moved one frame's worth (%.4f s), not the early tick's 0.03 s" % step)
	ni.push({}, 60)  # two seconds of server time later (a hitch)
	ni.advance_clock(0.01)
	assert_near(ni.render_time(), 60.0 / 15.0 - NetInterp.DELAY_S, 0.03, "a gap > CLOCK_SNAP_S snaps")
	ni.queue_free()
