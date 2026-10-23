## D-163 VFX: Sicario's smoke cloud (fade-in / hold / fade-out inside the duration, pool cap, prewarm) and the Tag
## Team tether (follows both bodies, motes pulse every 0.2 s, unlinks when a body leaves). Headless.
extends TestCase

var _d: VfxDirector


func before_each() -> void:
	VfxSettings.reset()
	_d = VfxDirector.new()
	_d.listen_to_event_bus = false
	_d.use_game_settings = false
	_d.auto_advance = false
	_d.play_impact_cues = false
	add_child(_d)


func after_each() -> void:
	if is_instance_valid(_d):
		_d.free()
	_d = null
	VfxSettings.reset()


func _alpha(cloud: Node3D) -> float:
	return (cloud.get_meta(&"mat") as StandardMaterial3D).albedo_color.a


func test_smoke_fade_curve() -> void:
	assert_near(SmokeCloudFx.fade(0.0, 10.0), 0.0)
	assert_near(SmokeCloudFx.fade(0.5, 10.0), 0.5)
	assert_near(SmokeCloudFx.fade(5.0, 10.0), 1.0)
	assert_near(SmokeCloudFx.fade(9.0, 10.0), 0.5)
	assert_near(SmokeCloudFx.fade(10.0, 10.0), 0.0)


func test_smoke_cloud_lives_its_duration() -> void:
	_d.on_smoke_cloud_fx(Vector3(2, 0, 3), 6.0, 10.0)
	var cloud: Node3D = _d.smoke.get_child(0) as Node3D
	assert_true(cloud.visible)
	assert_near(_alpha(cloud), 0.0, 0.001, "starts transparent")
	for i: int in range(60 * 5):
		_d.advance(1.0 / 60.0)
	assert_near(_alpha(cloud), SmokeCloudFx.ALPHA, 0.01, "full at the hold")
	var far: float = 0.0
	for c: Node in cloud.get_children():
		far = maxf(far, Vector2((c as Node3D).position.x, (c as Node3D).position.z).length())
	assert_true(far > 2.0 and far < 6.0 * 1.4, "puffs spread over the 6 m radius (%.2f)" % far)
	for i2: int in range(60 * 6):
		_d.advance(1.0 / 60.0)
	assert_false(cloud.visible, "gone after 10 s")
	assert_eq(int(_d.stats()["smoke_clouds"]), 0)


func test_smoke_dome_hides_a_standing_crew_member() -> void:
	_d.on_smoke_cloud_fx(Vector3.ZERO, 4.0, 10.0)
	var cloud: Node3D = _d.smoke.get_child(0) as Node3D
	var top: float = 0.0
	var low: int = 0
	for c: Node in cloud.get_children():
		var q: Node3D = c as Node3D
		top = maxf(top, q.position.y)
		if q.position.y < 1.2:
			low += 1
	assert_true(top >= 2.5, "the crown stands >= 2.5 m at radius 4 (%.2f)" % top)
	assert_true(low >= cloud.get_child_count() / 4, "a ground layer engulfs the base (%d low puffs)" % low)


func test_smoke_pool_capped_and_prewarmed() -> void:
	_d.prewarm()
	var cap: int = _d.smoke.cap()
	assert_eq(_d.smoke.get_child_count(), cap, "prewarm builds every cloud")
	for i: int in range(cap * 3):
		_d.on_smoke_cloud_fx(Vector3(float(i), 0, 0), 6.0, 10.0)
	assert_eq(_d.smoke.get_child_count(), cap, "no node beyond the cap")
	assert_eq(int(_d.stats()["smoke_clouds"]), cap)


func test_tether_follows_bodies_and_pulses() -> void:
	var a: Node3D = Node3D.new()
	var b: Node3D = Node3D.new()
	add_child(a)
	add_child(b)
	b.position = Vector3(4, 0, 0)
	assert_true(_d.tethers.link(Vector2i(0, 1), a, b))
	_d.advance(0.05)
	var link: Node3D = _d.tethers.get_child(0) as Node3D
	assert_true(link.visible)
	var mote: Node3D = link.get_node("Mote0") as Node3D
	var p0: Vector3 = mote.global_position
	assert_near(p0.y, TetherFx.CHEST_Y_M, 0.001)
	_d.advance(TetherFx.PULSE_S)
	assert_true(mote.global_position.distance_to(p0) < 0.01, "a mote repeats every pulse")
	b.position = Vector3(0, 0, 6)
	_d.advance(0.01)
	var line: Node3D = link.get_node("Line") as Node3D
	assert_near(line.global_position.z, 3.0, 0.01, "the line follows the moved body")
	var reach: float = (line.global_transform * Vector3(0, 0, 0.5) - line.global_transform * Vector3(0, 0, -0.5)).length()
	assert_near(reach, 6.0, 0.01, "the ribbon spans body to body (the unit box stretched along its own axis)")
	b.position = Vector3(5, 0, 0)
	_d.advance(0.01)
	var ends: Array[Vector3] = [line.global_transform * Vector3(0, 0, 0.5), line.global_transform * Vector3(0, 0, -0.5)]
	var want: Array[Vector3] = [Vector3(0, TetherFx.CHEST_Y_M, 0), Vector3(5, TetherFx.CHEST_Y_M, 0)]
	for w: Vector3 in want:
		assert_true(ends[0].distance_to(w) < 0.01 or ends[1].distance_to(w) < 0.01, "an end at %s (%s)" % [w, ends])
	b.free()
	_d.advance(0.01)
	assert_eq(_d.tethers.active_count(), 0, "a freed body unlinks")
	a.free()


func test_tether_pool_cap() -> void:
	var nodes: Array[Node3D] = []
	for i: int in range(6):
		var n: Node3D = Node3D.new()
		add_child(n)
		nodes.append(n)
	var linked: int = 0
	for i: int in range(5):
		if _d.tethers.link(Vector2i(i, i + 1), nodes[i], nodes[i + 1]):
			linked += 1
	assert_eq(linked, VfxSettings.TETHER_CAP)
	_d.tethers.unlink(Vector2i(0, 1))
	assert_eq(_d.tethers.active_count(), VfxSettings.TETHER_CAP - 1)
	for n: Node3D in nodes:
		n.free()
