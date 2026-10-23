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
