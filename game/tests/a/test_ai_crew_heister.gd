## LEAD r281 (P's real-input RT run): AI teammates launched without a heister (a direct HeistLauncher.launch with bare
## loadouts) drew the grey capsule placeholder. The runtime gives each such bot the first heister nobody wears.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_bare_launch_bots_wear_heisters() -> void:
	var mine: Loadout = CrewWeapons.build_loadout(null)
	mine.heister = Heisters.ids()[0]
	_rt = await HeistLauncher.launch(&"unit_map", 1281, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 2, "crew_ai": false, "loadouts": {0: mine}})
	await wait_physics_frames(3)
	var seen: Array[StringName] = []
	for c: CrewController in _rt.crew_members():
		assert_ne(c.heister, &"", "slot %d wears a heister" % c.slot)
		assert_false(seen.has(c.heister), "slot %d: %s is not worn twice" % [c.slot, c.heister])
		seen.append(c.heister)
		var v: Node = c.get_node(^"Visual")
		assert_true(v.get_child_count() > 0 and v.get_child(0).name != &"Placeholder", "slot %d: a body, not the capsule" % c.slot)
	assert_eq(_rt.crew_controller(0).heister, mine.heister, "the player's pick stays")
