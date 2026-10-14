## GN-A1: the Gallery Night mission on the real map. Last call (PUBLIC zones -> RESTRICTED, patrons walk out, bronze
## doors relocked LOCKPICK, the landing curtain on), the lockdown (art door BARRED, AS reader dead, the hack retargeted
## to 120 s / 2-3), the loud hack lifting it, and asset.intel_list seeding find_canvases.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _launch(opts: Dictionary = {}) -> void:
	var o: Dictionary = {"crew_ai": false, "ai_teammates": 0}
	o.merge(opts, true)
	_rt = await HeistLauncher.launch(&"gallery_night", 1130, Enums.Difficulty.ROUTINE, self, o)
	await wait_physics_frames(3)


func _door(path: String) -> Door:
	return _rt.map.get_node_or_null(NodePath(path)) as Door


func _count_zones(kind: int) -> int:
	var n: int = 0
	for z: Node in _rt.map.find_children("*", "Area3D", true, false):
		if z is MapZone and (z as MapZone).kind == kind:
			n += 1
	return n


func test_gn_last_call() -> void:
	await _launch()
	var m: HeistMission = _rt.mission
	assert_true(_count_zones(MapZone.Kind.PUBLIC) > 0, "public gala rooms before last call")
	m.call(&"_on_last_call")
	await wait_physics_frames(2)
	assert_eq(_count_zones(MapZone.Kind.PUBLIC), 0, "every PUBLIC zone is RESTRICTED after last call")
	for p: String in ["Gameplay/Doors/BronzeDoorsW", "Gameplay/Doors/BronzeDoorsE"]:
		var d: Door = _door(p)
		assert_true(d != null and d.locked and d.lock == Door.Lock.LOCKPICK and not d.is_open, "%s relocked" % p)
	var leaving: int = 0
	for n: Node in _rt.npcs(&"civilian"):
		var b: CivilianBrain = n.get_node_or_null(^"Brain") as CivilianBrain
		if b != null and b.mode == CivilianBrain.Mode.LEAVE:
			leaving += 1
			assert_true((n as NpcBase).spawn_info.get("tags", []).has(&"civ_patron"), "only patrons leave at last call")
	assert_true(leaving >= 1, "patrons walk out (%d)" % leaving)
	for g: Node in m.find_tagged(&"landing_curtain"):
		assert_true((g as LaserGrid).active, "landing curtain on")


func test_gn_lockdown_and_loud_hack() -> void:
	await _launch()
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(3)
	var art: Door = _door("Gameplay/Doors/ArtDoorEG")
	assert_true(art != null and art.lock == Door.Lock.BARRED and not art.is_open, "LD art door BARRED")
	for r: Node in _rt.mission.find_tagged(&"vault_reader"):
		assert_true((r as KeycardReader).disabled, "AS reader dead")
	for h: Node in _rt.mission.find_tagged(&"hack"):
		var ht: HackTerminal = h as HackTerminal
		assert_near(ht.duration_s, 120.0, 0.01, "loud hack 120 s")
		assert_true(ht.interruptions.x >= 2 and ht.interruptions.y >= 3, "2-3 interruptions (%s)" % ht.interruptions)
	_rt.mission.call(&"_lift_lockdown")
	await wait_physics_frames(2)
	assert_true(not art.locked and art.is_open, "loud hack done: art door open")
	var vault: Door = _door("Gameplay/Doors/ArtStoreVaultDoor")
	assert_true(vault != null and not vault.locked and vault.is_open, "AS vault door open")
	assert_eq(_rt.mission.objective_state(&"art_store"), Enums.ObjectiveState.COMPLETED, "art_store done")


func test_gn_intel_list_seeds_find_canvases() -> void:
	await _launch({"preplanning": [&"asset.intel_list"]})
	assert_true(_rt.mission.has_asset(&"asset.intel_list"), "asset bought")
	assert_eq(_rt.mission.objective_state(&"find_canvases"), Enums.ObjectiveState.COMPLETED, "all four canvases known")


## C bff4dd40: the areaway ladder is usable only while the rolled areaway grate is open (skipped until the map has
## them).
func test_gn_areaway_ladder_follows_the_grate() -> void:
	await _launch()
	var ladder: Ladder = _rt.map.get_node_or_null(^"Gameplay/Ladders/AreawayLadder") as Ladder
	var group: Node = _rt.map.get_node_or_null(^"Variants/Group_areaway")
	var grates: Array[Node] = group.find_children("AreawayGrate", "", true, false) if group != null else []
	if ladder == null or grates.is_empty():
		skip("map has no areaway ladder / grate yet (ENV C bff4dd40)")
		return
	var grate: Door = grates[0] as Door
	assert_eq(ladder.usable, grate.is_open, "ladder follows the grate at start")
	grate.unlock()
	grate.set_open(true)
	await wait_physics_frames(2)
	assert_true(ladder.usable, "grate open: climbable")
	grate.set_open(false)
	await wait_physics_frames(2)
	assert_false(ladder.usable, "grate closed: not climbable")
