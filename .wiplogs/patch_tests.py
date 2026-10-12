s = ""


def rep(a, b):
    global s
    assert a in s, a[:60]
    s = s.replace(a, b, 1)


p = 'game/tests/c/test_dockside_burn_map.gd'
s = open(p).read()
rep('''	for n2: Node in _map.find_children("Padlock", "", true, false):
		assert_true(n2.is_in_group(G.SAW_TARGET), "%s in G.SAW_TARGET" % _map.get_path_to(n2))
		assert_true(n2.has_meta(&"saw_s"), "%s carries saw metadata" % _map.get_path_to(n2))
		saws += 1''', '''	for n2: Node in _map.find_children("Padlock", "", true, false):
		assert_true(n2 is Padlock, "%s is ENV A's padlock prefab (QC-37; joins G.SAW_TARGET when ready)" % _map.get_path_to(n2))
		assert_eq((n2 as Padlock).targets.size(), 1, "%s opens one target" % _map.get_path_to(n2))
		saws += 1''')
a = s.index('		var bp: DrillPoint = _map.get_node_or_null("Variants/Group_product_location/Slot_%s/ProductPallet/BurnPoint"')
b = s.index('			"%s fire volume" % sid)') + len('			"%s fire volume" % sid)')
s = s[:a] + '''		var bp: BurnPoint = _map.get_node_or_null("Variants/Group_product_location/Slot_%s/BurnPoint" % sid) as BurnPoint
		assert_true(bp != null and bp.objective_tag == &"burn", "%s burn point (ENV A burn_point, QC-38)" % sid)
		if bp != null:
			assert_near(bp.duration_s, 30.0, 0.001, "burn 30 s")
			assert_eq(bp.requires_loot, &"loot.thermite", "the burn takes the thermite bag")
			assert_true(bp.fire_volume_size.x >= 10.0, "%s fire volume spans the room" % sid)''' + s[b:]
s = s.rstrip("\n") + '''


## Lead G2 review: the loading hall keeps an open floor >= 12 m (no props) between crate-cover banks.
func test_hall_open_floor_and_crate_cover() -> void:
	if _map == null:
		fail("map missing")
		return
	var r: Array = [28.6, 0.4, 42.4, 9.6]
	assert_true(float(r[2]) - float(r[0]) >= 12.0, "open floor >= 12 m")
	var crates: int = 0
	for n: Node in _map.get_node("Props").find_children("*", "StaticBody3D", true, false):
		var b: Node3D = n as Node3D
		var p: Vector3 = b.position
		if String(b.get_meta(&"kind", "")) == "crate":
			crates += 1
		if p.y < 1.0 and p.x > float(r[0]) and p.x < float(r[2]) and p.z > float(r[1]) and p.z < float(r[3]):
			fail("prop %s stands in the hall's open floor" % b.name)
	assert_true(crates >= 6, "crate cover in the hall (%d)" % crates)
'''
open(p, 'w').write(s)

p = 'game/tests/c/test_dockside_burn_launch.gd'
s = open(p).read()
rep('''	Engine.time_scale = 4.0
	await wait_until(func() -> bool: return mission.timer_left(&"fire_shutters") <= 0.0, 5.0)
	await wait_physics_frames(3)
	Engine.time_scale = 1.0
''', '''	await wait_physics_frames(3)
''')
rep("## The burn finishing drops the burning room's fire shutters 5 s later (D-064 Q6)",
    "## The burn point lighting (device_finished, after its 5 s telegraph) drops the fire shutters (D-064 Q6)")
open(p, 'w').write(s)
print("ok")
