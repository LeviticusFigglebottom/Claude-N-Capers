## Public-facing doors open while casing (LEAD 2026-10-12, PD2): an unmasked crew member can use the listed
## public doors; every other door (staff-only, locked) still blocks with ui.blocked.casing. Dockside Burn is a
## closed yard at night: no public doors. Owner: ENV C. Setup: skip_casing false, no AI teammates.
extends TestCase

const PUBLIC: Dictionary = {
	&"glasshouse": [&"MainEntrance"],
	&"night_deposit": [&"AtmStreetDoor"],
	&"dockside_burn": [],
}

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func test_public_doors_open_unmasked() -> void:
	for heist: StringName in PUBLIC:
		_rt = await HeistLauncher.launch(heist, 1001, Enums.Difficulty.ROUTINE, self, {"ai_teammates": 0, "crew_ai": false})
		if _rt == null:
			fail("launch %s" % heist)
			continue
		await wait_physics_frames(3)
		var c: Node = _rt.crew_controller(0)
		var pub: Array = PUBLIC[heist]
		if not pub.is_empty():  # Dockside Burn starts masked (loud-only yard): only the casing_allowed flags are checked
			assert_false(bool(c.get(&"masked")), "%s: crew unmasked (casing)" % heist)
		var n_pub: int = 0
		var n_shut: int = 0
		for n: Node in _rt.map.get_node("Gameplay/Doors").get_children():
			var d: Door = n as Door
			if d == null or d.interactable == null:
				continue
			var why: StringName = d.interactable.availability(c)
			if pub.has(d.name):
				n_pub += 1
				assert_ne(why, InteractableComponent.BLOCK_CASING, "%s: %s openable unmasked" % [heist, d.name])
			else:
				n_shut += 1
				assert_true(not d.casing_allowed, "%s: %s not casing_allowed (staff / locked)" % [heist, d.name])
		assert_eq(n_pub, pub.size(), "%s: every public door present" % heist)
		print("[C3] %s: %d public door(s) open unmasked, %d other doors need the mask" % [heist, n_pub, n_shut])
		_rt.teardown()
		_rt = null
		await wait_frames(2)
