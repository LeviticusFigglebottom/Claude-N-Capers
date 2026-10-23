## AH-A1 on ENV C's real map (D-165): every objective's marker tags resolve to nodes, the Mission node runs
## AfterhoursMission, the D-143 data (4 guards, pager caps [4,3,3,2,2,1], van escape, civilian start) holds, and the
## gear line matches the rolled gear_drop slot. SKIPs "pending C G1" until afterhours.tscn is on the branch.
extends TestCase

const HEIST: StringName = &"afterhours"
const MAP_PATH: String = "res://world/heists/afterhours/afterhours.tscn"
const DEF_PATH: String = "res://world/heists/afterhours/afterhours_def.tres"
const PENDING: String = "pending C G1: no afterhours map on this branch"
const PAGER_MAX: Array[int] = [4, 3, 3, 2, 2, 1]

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _pending() -> bool:
	if ResourceLoader.exists(MAP_PATH) and ResourceLoader.exists(DEF_PATH):
		return false
	skip(PENDING)
	return true


func test_def_data_d143() -> void:
	if _pending():
		return
	var def: HeistDef = load(DEF_PATH) as HeistDef
	assert_eq(def.start_mode, &"civilian", "civilian start (D-065)")
	assert_eq(def.escape_options, [&"van"] as Array[StringName], "van only (D-075 ruling 9)")
	assert_eq(def.pager_max_by_difficulty, PAGER_MAX, "PAGERS lever (D-143)")


func test_objective_markers_resolve_on_the_map() -> void:
	if _pending():
		return
	_rt = await HeistLauncher.launch(HEIST, 1650, Enums.Difficulty.ROUTINE, self, {"crew_ai": false, "ai_teammates": 0})
	await wait_physics_frames(3)
	assert_true(_rt.mission != null and _rt.mission.has_method(&"gear_line"), "the map's Mission is AfterhoursMission")
	for o: Dictionary in _rt.mission.objectives():
		var tags: Array = (o.get("data", {}) as Dictionary).get("marker_tags", [])
		for t: Variant in tags:
			assert_false(_rt.mission.find_tagged(StringName(t)).is_empty() and _rt.mission.loot_markers(StringName(t)).is_empty(),
				"%s: marker tag %s resolves" % [o["id"], t])
	assert_ne(StringName(_rt.mission.call(&"gear_line")), &"", "a gear_drop slot rolled, and Mercer has its line")
	var guards: int = _rt.npcs().filter(func(n: Node) -> bool: return (n as NpcBase).role == &"guard").size()
	assert_eq(guards, 4, "exactly 4 guards (D-143)")


func _launch_real(difficulty: int = Enums.Difficulty.ROUTINE) -> HeistMission:
	_rt = await HeistLauncher.launch(HEIST, 1650, difficulty, self, {"crew_ai": false, "ai_teammates": 0})
	await wait_physics_frames(3)
	return _rt.mission


func _first_net_id(tag: StringName) -> int:
	for n: Node in _rt.mission.find_tagged(tag):
		if n.get(&"net_id") != null and n.is_inside_tree():
			return int(n.get(&"net_id"))
	return 0


func test_stealth_line_on_the_real_map() -> void:
	if _pending():
		return
	var m: HeistMission = await _launch_real()
	var lm: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	var cash: Callable = func() -> int:
		return lm.bags().filter(func(b: LootBag) -> bool: return b.loot_id == &"loot.cash_bricks").size()
	if not m.get(&"safe_open"):  # the rare count_left_open starts it open
		assert_eq(cash.call(), 0, "no safe cash before the safe opens")
	assert_true(lm.bags().filter(func(b: LootBag) -> bool: return b.loot_id == &"loot.parcels").size() >= 3,
		"the product spawned at the active product marker")
	EventBus.item_picked_up.emit(&"item.gear", 0)
	EventBus.item_picked_up.emit(&"item.keycard", 0)
	EventBus.interaction_completed.emit(_first_net_id(&"office_reader"), 0, &"keycard_reader")
	EventBus.item_picked_up.emit(&"item.code_note", 0)
	m.call(&"open_safe", &"code")
	assert_true(int(cash.call()) >= 4, "the open safe holds its cash at safe_loot (%d)" % cash.call())
	var marker: Node3D = (m.loot_markers(&"safe_loot") as Array)[0] as Node3D
	for b: LootBag in lm.bags():
		if b.loot_id == &"loot.cash_bricks":
			assert_true(b.global_position.distance_to(marker.global_position) < 3.0, "%s in the safe" % b.name)
	for id: StringName in [&"gear", &"keycard", &"office", &"safe_code", &"safe"]:
		assert_eq(m.objective_state(id), Enums.ObjectiveState.COMPLETED, "%s done" % id)
	var secured: int = 0
	for b: LootBag in lm.bags():
		if b.loot_id == &"loot.cash_bricks" and secured < 3:
			lm._secure(b)
			secured += 1
	await wait_physics_frames(2)
	assert_eq(m.objective_state(&"secure"), Enums.ObjectiveState.COMPLETED, "3 bags")
	assert_eq(m.objective_state(&"escape"), Enums.ObjectiveState.ACTIVE, "stealth: the van is there")


func test_loud_on_the_real_map_cuts_the_club_and_locks_down() -> void:
	if _pending():
		return
	var m: HeistMission = await _launch_real()
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(3)
	assert_true(bool(m.get(&"lockdown")), "lockdown")
	var door: Door = m.find_tagged(&"office_door")[0] as Door
	assert_true(door.charges_required >= 1, "the office door takes C4 loud")
	assert_eq(m.objective_state(&"escape_wait"), Enums.ObjectiveState.ACTIVE, "escape_wait")
	var lights: Node = _rt.map.find_child("ClubLights", true, false)
	assert_true(lights != null, "C's ClubLights on the map")


## vip_party (C 5f0b8f52): the VIPGuest spawns (civ_vip + scripted) are empty at load; the rare event spawns all six.
func test_vip_party_guests_spawn_only_on_the_event() -> void:
	if _pending():
		return
	var m: HeistMission = await _launch_real()
	var tagged: Callable = func() -> int:
		return _rt.npcs(&"civilian").filter(func(n: NpcBase) -> bool:
			return (n.spawn_info.get("tags", []) as Array).has(&"civ_vip")).size()
	assert_eq(tagged.call(), 0 if not m.call(&"_rare", &"vip_party") else tagged.call(), "no VIP guests at load")
	var guests: Array = m.call(&"spawn_civilians", &"civ_vip")
	assert_eq(guests.size(), 6, "the six VIPGuest spawns")



## P AH read #3: Bag_cash_bricks2 was pushed out of the safe's solid box to (33.6, 4.2, 20.8), behind it, unreachable.
## The open safe's bags stay on their shelves and a crew member at the safe's use point can aim at every one.
func test_safe_cash_stays_on_the_shelves_and_is_aimable() -> void:
	if _pending():
		return
	var m: HeistMission = await _launch_real()
	m.call(&"open_safe", &"code")
	await wait_seconds(2.0)
	var safe: Safe = m.find_tagged(&"safe")[0] as Safe
	var interior: AABB = safe.interior_aabb().grow(0.05)
	var lm: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	var c: CrewController = _rt.crew_controller(0) as CrewController
	_rt.teleport_crew(0, safe.use_point.global_transform)
	await wait_physics_frames(3)
	var n: int = 0
	for b: LootBag in lm.bags():
		if b.loot_id != &"loot.cash_bricks":
			continue
		n += 1
		var local: Vector3 = safe.global_transform.affine_inverse() * b.global_position
		assert_true(interior.has_point(local), "%s on its shelf (local %s)" % [b.name, local])
		assert_true(_rt.interaction._has_los(c, c.eye_position(), b.interactable), "%s aimable from the use point" % b.name)
	assert_true(n >= 4, "the safe cash spawned (%d)" % n)
