## GN-8 / QC-57: the Vaultline couriers (rare vaultline_early) through the Gallery Night mission. They walk in at LD, walk
## to the rolled centrepiece slot, take the Lantern Bearer as an NPC-carried bag and carry it to the AS rack (cp_store),
## put it down there and walk back (B3: moves, never destroys). Killed, dominated or fighting, the carrier drops it
## where he stands, and the crew takes it back (centrepiece done, Vance's line). At an empty slot he radios the alarm.
## Also D-117 §6: every GN `event: mission` line in lines.tres is said by the mission script.
extends TestCase

const LINES_PATH: String = "res://content/data/voice/lines.tres"
const MISSION_PATH: String = "res://world/heists/gallery_night/gallery_night_mission.gd"
const VARIANTS_PATH: String = "res://world/heists/gallery_night/gallery_night_variants.tres"
const RUN_SEED: int = 1130
const TIME_SCALE: float = 4.0

var _rt: HeistRuntime = null
var _lines: Array[StringName] = []
var _cb: Callable


func before_each() -> void:
	_lines.clear()
	_cb = func(_speaker: StringName, line_id: StringName, _ctx: Dictionary) -> void: _lines.append(line_id)
	EventBus.voice_line_requested.connect(_cb)


func after_each() -> void:
	Engine.time_scale = 1.0
	if EventBus.voice_line_requested.is_connected(_cb):
		EventBus.voice_line_requested.disconnect(_cb)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


## Gallery Night with the centrepiece pinned on `slot` (a copy of the map's variant table, every other centrepiece
## slot weighted 0, through the dev `variant_table` option; the event's `requires` allows cp_landing / cp_treasury).
func _launch(slot: StringName = &"cp_treasury") -> bool:
	var vt: HeistVariantTable = (load(VARIANTS_PATH) as HeistVariantTable).duplicate(true) as HeistVariantTable
	var weights: Dictionary = {}
	for s: StringName in [&"cp_landing", &"cp_treasury", &"cp_store"]:
		weights[s] = 1.0 if s == slot else 0.0
	var by_diff: Dictionary = {}
	for d: int in Enums.Difficulty.values():
		by_diff[d] = weights
	for i: int in range(vt.rules.size()):
		if StringName(vt.rules[i].get("group", &"")) == &"centrepiece":
			var r: Dictionary = vt.rules[i].duplicate(true)
			r["weights_by_difficulty"] = by_diff
			vt.rules[i] = r
	_rt = await HeistLauncher.launch(&"gallery_night", RUN_SEED, Enums.Difficulty.HAZARDOUS, self,
		{"crew_ai": false, "ai_teammates": 0, "variant_table": vt})
	await wait_physics_frames(3)
	var cp: Variant = _rt.mission.variant(&"centrepiece") if _rt != null else null
	var ok: bool = cp is Array and (cp as Array) == [slot]
	assert_true(ok, "centrepiece pinned on %s (%s)" % [slot, cp])
	return ok


func _m() -> HeistMission:
	return _rt.mission


func _slot() -> LootSpawn:
	return _m().call(&"_lantern_slot") as LootSpawn


func _couriers() -> Array:
	return _m().get(&"couriers") as Array


func _state() -> StringName:
	return StringName(_m().get(&"courier_state"))


func _bag() -> LootBag:
	return _m().get(&"courier_bag") as LootBag


func _mgr() -> LootManager:
	return _rt.service(G.SVC_LOOT) as LootManager


## The couriers walk in (the rare event's timed spawn, through the mission's own handler).
func _spawn_couriers() -> void:
	_m().call(&"_on_timed_spawn", &"rare_vaultline_early", &"guard_vaultline")
	await wait_physics_frames(2)


## Put the couriers at the slot's UsePoint and let the errand tick: the first one takes the canvas.
func _teleport_to_slot() -> void:
	var stand: Vector3 = _m().call(&"_stand_of", _slot())
	for c: Variant in _couriers():
		(c as NpcBase).global_position = stand
	await wait_until(func() -> bool: return _state() != &"to_slot", 3.0)


func test_gn8_couriers_spawn_and_head_for_the_slot() -> void:
	if not await _launch():
		return
	var slot: LootSpawn = _slot()
	assert_true(slot != null and slot.remaining == 1, "the Lantern Bearer hangs on its slot")
	await _spawn_couriers()
	assert_eq(_couriers().size(), 2, "two Vaultline couriers walk in")
	assert_eq(_state(), &"to_slot", "they head for the centrepiece slot")
	assert_has(_lines, &"vo.mercer.gallery_night_vaultline", "Mercer names them")
	for c: Variant in _couriers():
		var npc: NpcBase = c as NpcBase
		var b: GuardBrain = npc.get_node(^"Brain") as GuardBrain
		assert_true(b.route.is_empty(), "no patrol: a scripted walk")
	assert_true(_bag() == null, "nothing carried yet")


func test_gn8_courier_carries_the_canvas_to_the_store_and_leaves_it_there() -> void:
	if not await _launch():
		return
	await _spawn_couriers()
	await _teleport_to_slot()
	assert_eq(_state(), &"carrying", "the first courier at the slot takes the canvas")
	var bag: LootBag = _bag()
	assert_true(bag != null and bag.loot_id == &"loot.painting_lantern_bearer", "the Lantern Bearer as a bag")
	assert_true(bag.is_npc_carried() and bag.npc_carrier == _couriers()[0], "on the carrier's back")
	assert_eq(_slot().remaining, 0, "the slot is empty")
	assert_false(bag.interactable.enabled, "the crew cannot take it off his back")
	assert_false(_mgr().carry(bag, _rt.crew_controller(0) as CrewController), "LootManager.carry refuses it too")
	assert_false(bag.moved, "not a crew-moved bag (S4.1)")
	assert_eq(bag.objective_tag, &"canvas_lantern_moved", "the moved canvas carries the marker tag")
	assert_has(_rt.find_by_tag(&"canvas_lantern_moved"), bag, "the centrepiece marker follows the bag (QC-60)")
	assert_eq(_m().objective_state(&"centrepiece"), Enums.ObjectiveState.ACTIVE, "still to steal")
	await wait_physics_frames(2)
	var carrier: NpcBase = _couriers()[0]
	assert_true(bag.global_position.distance_to(carrier.global_position) < 1.5, "the bag follows him")
	assert_false(_rt.went_loud, "no alarm: the couriers are expected")
	# He walks it to the AS rack (teleported near to keep the test short) and puts it down there.
	var store: Vector3 = _m().call(&"_store_point")
	carrier.global_position = store
	assert_true(await wait_until(func() -> bool: return _state() == &"stored", 3.0), "stored at the AS rack")
	assert_false(bag.is_carried(), "put down")
	assert_true(bag.interactable.enabled, "still there to steal (B3: moves, never destroys)")
	assert_true(Vector2(bag.global_position.x - store.x, bag.global_position.z - store.z).length() < 1.5,
		"on the AS rack")
	assert_true(is_instance_valid(bag) and not bag.secured, "not destroyed")
	var b: GuardBrain = carrier.get_node(^"Brain") as GuardBrain
	assert_false(b.at_post(1.0), "the couriers walk back to LD")
	# The crew takes it back: the centrepiece is done (a pick_bag, not the slot's cut) and Vance says his line.
	var crew: CrewController = _rt.crew_controller(0) as CrewController
	assert_true(_mgr().carry(bag, crew), "the crew picks the stored canvas up")
	assert_eq(_m().objective_state(&"centrepiece"), Enums.ObjectiveState.COMPLETED, "centrepiece done")
	assert_has(_lines, &"vo.vance.gallery_night_centrepiece", "Vance: the Lantern Bearer in crew hands")


func test_gn8_courier_killed_drops_the_canvas() -> void:
	if not await _launch():
		return
	await _spawn_couriers()
	await _teleport_to_slot()
	var bag: LootBag = _bag()
	var carrier: NpcBase = _couriers()[0]
	carrier.die({}, 0)
	await wait_physics_frames(2)
	assert_false(bag.is_carried(), "dropped when killed")
	assert_true(bag.interactable.enabled, "the crew can pick it up")
	assert_true(bag.global_position.distance_to(carrier.global_position) < 2.5, "where he fell")
	assert_true(await wait_until(func() -> bool: return _state() == &"intercepted", 2.0), "errand over: intercepted")
	assert_eq(_m().objective_state(&"centrepiece"), Enums.ObjectiveState.ACTIVE, "not a fail (B3)")
	assert_has(_rt.find_by_tag(&"canvas_lantern_moved"), bag, "the marker stays on the dropped canvas")
	var crew: CrewController = _rt.crew_controller(0) as CrewController
	assert_true(_mgr().carry(bag, crew), "taken from them")
	assert_eq(_m().objective_state(&"centrepiece"), Enums.ObjectiveState.COMPLETED, "centrepiece done")


func test_gn8_courier_dominated_drops_the_canvas() -> void:
	if not await _launch():
		return
	await _spawn_couriers()
	await _teleport_to_slot()
	var bag: LootBag = _bag()
	var carrier: NpcBase = _couriers()[0]
	(carrier.get_node(^"Brain") as GuardBrain).dominate(0)
	await wait_physics_frames(2)
	assert_eq(carrier.alert_state, Enums.AlertState.DOMINATED, "intimidated")
	assert_false(bag.is_carried(), "dropped when intimidated")
	assert_true(bag.interactable.enabled, "the crew can pick it up")
	assert_true(await wait_until(func() -> bool: return _state() == &"intercepted", 2.0), "errand over: intercepted")
	assert_false(_rt.went_loud, "intimidating them is a pager event, not an alarm (B3)")


func test_gn8_courier_stopped_before_the_slot_leaves_the_canvas_hanging() -> void:
	if not await _launch():
		return
	await _spawn_couriers()
	for c: Variant in _couriers():
		(c as NpcBase).die({}, 0)
	assert_true(await wait_until(func() -> bool: return _state() == &"intercepted", 2.0), "errand over")
	assert_eq(_slot().remaining, 1, "the canvas still hangs on its slot")
	assert_true(_bag() == null, "nothing taken")


func test_gn8_courier_alarms_on_an_empty_slot() -> void:
	if not await _launch():
		return
	var slot: LootSpawn = _slot()
	var taken: LootBag = slot.take_for_npc()  # the crew got there first (the slot is empty)
	assert_true(taken != null and slot.remaining == 0, "slot emptied")
	await _spawn_couriers()
	await _teleport_to_slot()
	assert_eq(_state(), &"alarm", "the canvas is gone")
	var b: GuardBrain = (_couriers()[0] as NpcBase).get_node(^"Brain") as GuardBrain
	assert_eq((_couriers()[0] as NpcBase).alert_state, Enums.AlertState.ALARMED, "he radios it in (S3.3)")
	assert_eq(b.alarm_cause, &"canvas_missing", "cause")
	assert_true(await wait_until(func() -> bool: return _rt.went_loud, Tweak.stealth().guard_radio_call_s + 2.0),
		"the radio call raises the alarm (B3: loud, never a fail)")
	assert_eq(_m().objective_state(&"lockdown"), Enums.ObjectiveState.COMPLETED, "the GN lockdown")


func test_gn8_courier_going_loud_drops_the_canvas() -> void:
	if not await _launch():
		return
	await _spawn_couriers()
	await _teleport_to_slot()
	var bag: LootBag = _bag()
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(3)
	assert_true(_rt.went_loud, "loud")
	assert_false(bag.is_carried(), "a courier who fights puts the canvas down")
	assert_true(bag.interactable.enabled, "reachable in loud (B3)")
	assert_true(await wait_until(func() -> bool: return _state() == &"intercepted", 2.0), "errand over")


## The real walk: LD -> the slot (through the guard_vaultline doors), canvas taken, then on to the AS rack.
func test_gn8_couriers_walk_the_errand_treasury() -> void:
	await _walk_errand(&"cp_treasury")


## cp_landing: up the imperial stair, past the walk-through velvet rope at its foot (no collider, next_heist §7.9).
func test_gn8_couriers_walk_the_errand_landing() -> void:
	await _walk_errand(&"cp_landing")


func _walk_errand(slot: StringName) -> void:
	if not await _launch(slot):
		return
	Engine.time_scale = TIME_SCALE
	await _spawn_couriers()
	var ok: bool = await wait_until(func() -> bool: return _state() != &"to_slot", 240.0)
	assert_true(ok, "the couriers reach the slot (state %s, at %s)" % [_state(),
		(_couriers()[0] as NpcBase).global_position if not _couriers().is_empty() else Vector3.ZERO])
	assert_eq(_state(), &"carrying", "and take the canvas")
	ok = await wait_until(func() -> bool: return _state() != &"carrying", 300.0)
	assert_true(ok, "they reach the AS rack (state %s, carrier at %s)" % [_state(),
		_bag().global_position if _bag() != null else Vector3.ZERO])
	assert_eq(_state(), &"stored", "the canvas is on the AS rack")
	assert_false(_rt.went_loud, "no alarm on the way")


## D-117 §6: every GN mission line (lines.tres `event: mission`) is said by the mission script, literally or through
## its built ids (canvas_found_<short>, <van|limo>_eta).
func test_gn8_d117_every_mission_line_is_wired() -> void:
	var src: String = FileAccess.get_file_as_string(MISSION_PATH)
	var lib: Resource = load(LINES_PATH)
	assert_true(lib != null and src != "", "lines.tres and the mission script")
	if lib == null:
		return
	var rows: Array = lib.get(&"lines") as Array
	assert_true(rows != null and not rows.is_empty(), "lines.tres rows")
	var built: Dictionary = {
		"vo.mercer.gallery_night_canvas_found_": "vo.mercer.gallery_night_canvas_found_%s",
		"vo.mercer.gallery_night_van_eta": "vo.mercer.gallery_night_%s_eta",
		"vo.mercer.gallery_night_limo_eta": "vo.mercer.gallery_night_%s_eta",
	}
	var n: int = 0
	for r: Variant in rows:
		var d: Dictionary = r as Dictionary if r is Dictionary else {}
		var id: String = String(d.get("id", ""))
		if StringName(d.get("event", &"")) != &"mission" or not id.contains(".gallery_night_"):
			continue
		n += 1
		var wired: bool = src.contains("\"%s\"" % id)
		for prefix: String in built:
			if id.begins_with(prefix):
				wired = wired or src.contains(String(built[prefix]))
		assert_true(wired, "%s is said by the GN mission script" % id)
	assert_true(n >= 30, "GN mission lines found (%d)" % n)
