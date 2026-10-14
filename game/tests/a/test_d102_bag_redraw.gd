## D-102 follow-up (ENV P request): CrewWeapons.equip(equipped_slot, true) re-draws the equipped weapon (PD2
## PlayerCarry:_enter -> _start_action_equip): same slot, no equipped_changed, reload cancelled, no fire until
## the equip time has passed.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_d102_redraw_same_slot() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 31, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "skip_casing": true, "crew_ai": false})
	await wait_frames(2)
	var w: CrewWeapons = (_rt.crew_controller(0) as CrewController).weapons
	await wait_seconds(1.5)  # initial draw
	var ws: int = w.equipped_slot
	var changed: Array[int] = []
	w.equipped_changed.connect(func(s: int) -> void: changed.append(s))
	assert_false(w.equip(ws), "plain equip of the same slot is still a no-op")
	w.set_ammo(ws, 1, 30)
	assert_true(w.start_reload(), "reload started")
	assert_true(w.equip(ws, true), "redraw")
	assert_eq(w.equipped_slot, ws, "same slot")
	assert_eq(changed, [] as Array[int], "no equipped_changed on a redraw")
	assert_false(w.reloading, "redraw cancels the reload")
	var equip_s: float = w.stats(ws).equip_time_s
	assert_true(equip_s > 0.0, "weapon has an equip time")
	var t0: int = Time.get_ticks_msec()
	var ready: bool = await wait_until(func() -> bool: return _ready_to_fire(w), equip_s + 2.0)
	assert_true(ready, "fire allowed again after the redraw")
	assert_true(float(Time.get_ticks_msec() - t0) / 1000.0 >= equip_s * 0.8, "blocked for ~equip_time_s")


func _ready_to_fire(w: CrewWeapons) -> bool:
	return w.get(&"_equip_left") <= 0.0
