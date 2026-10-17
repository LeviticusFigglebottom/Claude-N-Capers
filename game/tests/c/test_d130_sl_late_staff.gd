## D-130 Shadow Ledger `late_staff`: on the real launched map (Cataclysm, a few seeds) the late K4 assistant and K8
## associate spawn calm, on the navmesh, seated on their NPC seat (CivilianBrain.has_seat_under) at their desk and
## working (desk_work: a seated clip, never a floor pose), and stay put. Owner: ENV C.
## Design: docs/design/heists/shadow_ledger.md (§roster, D-130). Generator: greybox/sl_gameplay.gd LATE_STAFF.
extends TestCase

const TAGS: Array[StringName] = [&"civ_assistant", &"civ_associate"]
const SEEDS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
const SEATED_CLIPS: Array[StringName] = [&"desk_work", &"desk_type", &"phone_seated", &"sit_chair"]

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_late_staff_seated_at_work() -> void:
	var seen: Dictionary = {}
	for sd: int in SEEDS:
		if seen.size() == TAGS.size():
			break
		_rt = await HeistLauncher.launch(&"shadow_ledger", sd, Enums.Difficulty.CATACLYSM, self, {"crew_ai": false})
		assert_true(_rt != null, "launched shadow_ledger seed %d" % sd)
		if _rt == null:
			continue
		await wait_seconds(2.0)
		for n: Node in _rt.npcs(&"civilian"):
			var npc: NpcBase = n as NpcBase
			var tags: Array = npc.spawn_info.get("tags", [])
			for t: StringName in TAGS:
				if tags.has(t):
					seen[t] = true
					_check(npc, "%s seed %d" % [t, sd])
		_rt.teardown()
		_rt = null
		await wait_frames(2)
	for t2: StringName in TAGS:
		assert_true(seen.has(t2), "a Cataclysm seed in %s spawns %s" % [SEEDS, t2])


func _check(npc: NpcBase, what: String) -> void:
	assert_eq(npc.alert_state, Enums.AlertState.CALM, "%s: calm" % what)
	var sp: Node3D = npc.spawn_info.get("spawn_point") as Node3D
	if sp != null:
		var d: float = Vector2(npc.global_position.x - sp.global_position.x, npc.global_position.z - sp.global_position.z).length()
		assert_true(d < 0.3, "%s: stays on its seat (%.2f m off the spawn)" % [what, d])
	assert_true(CivilianBrain.has_seat_under(npc), "%s: a seat under it" % what)
	var map: Node3D = _rt.map as Node3D
	var nav: NavigationRegion3D = map.get_node("Navigation") as NavigationRegion3D
	var q: Vector3 = NavigationServer3D.map_get_closest_point(nav.get_navigation_map(), npc.global_position)
	assert_true(Vector2(q.x - npc.global_position.x, q.z - npc.global_position.z).length() < 0.15,
		"%s: spawn on the navmesh" % what)
	var ad: AnimDriver = npc.get_node_or_null(^"AnimDriver") as AnimDriver
	if ad != null and ad.player != null:
		var clip: StringName = ad.choose_clip()
		assert_true(SEATED_CLIPS.has(clip), "%s: plays a seated working clip (%s)" % [what, clip])
	print("D-130 SL %s at %s" % [what, npc.global_position])
