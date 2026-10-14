## P PO-pass (GH loud): two police standing 0.33 m apart stayed stacked for 20 s, because the PO-10 idle drift only
## moved CALM NPCs. Any upright standing NPC now drifts apart to npc_separation_idle_m; posed bodies (cowering,
## on the floor, tied, hands up) stay put.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _standing(role: StringName, pos: Vector3) -> NpcBase:
	var npc: NpcBase = _rt.spawn_npc(role, Transform3D(Basis.IDENTITY, pos), {})
	npc.get_node("Brain").set_physics_process(false)
	return npc


static func _gap(a: NpcBase, b: NpcBase) -> float:
	return Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()


func test_po10_stacked_police_in_combat_drift_apart() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1012, Enums.Difficulty.ROUTINE, self, {"map_packed": ATestMaps.basic(0, 0)})
	await wait_physics_frames(2)
	var a: NpcBase = _standing(&"police", Vector3(0, 0.05, -6))
	var b: NpcBase = _standing(&"police", Vector3(0.3, 0.05, -6))
	var tied_a: NpcBase = _standing(&"civilian", Vector3(5, 0.05, -6))
	var tied_b: NpcBase = _standing(&"civilian", Vector3(5.3, 0.05, -6))
	await wait_physics_frames(1)
	for n: NpcBase in [a, b]:
		n.set_alert_state(Enums.AlertState.COMBAT)
	for n: NpcBase in [tied_a, tied_b]:
		n.set_alert_state(Enums.AlertState.TIED)
	var min_m: float = Tweak.stealth().npc_separation_idle_m
	assert_true(await wait_until(func() -> bool: return _gap(a, b) >= min_m * 0.95, 3.0),
		"combat police drift apart (%.2f m)" % _gap(a, b))
	assert_true(_gap(a, b) < min_m + 0.5, "only as far as needed (%.2f m)" % _gap(a, b))
	assert_true(_gap(tied_a, tied_b) < 0.4, "tied hostages keep their pose (%.2f m)" % _gap(tied_a, tied_b))
