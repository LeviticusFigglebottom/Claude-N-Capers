## Gate 3 snag (gh_stealth): a bag carrier lost ~80 s wedged between the G4 corridor wall corner (16.3, 4.6) and the
## LobbyDoor frame while turning from the corridor into the G10 lobby. PD2 feel: pressing diagonally into a convex
## corner / jamb slides off it into the doorway. Real input (PTraversal: W + mouse steering straight at a point in
## the lobby, i.e. the diagonal press), approaches at ~30-60 deg from the corridor, with and without a bag.
extends TestCase

## LobbyDoor at (17, 0, 4.5) in the corridor's north wall (opening x ~16.5..17.5); G10 lies north (-z). The reported
## path ran east along the corridor past the JanitorDoor (x 15.3) and turned at the doorway corner (16.9, 4.5).
const DOOR_CORNER: Vector3 = Vector3(16.9, 0.0, 4.5)
const IN_LOBBY: Vector3 = Vector3(17.0, 0.0, 3.0)
## Corridor starts (z 4.5..6.0), east of the JanitorDoor: hugging the north wall (z ~4.9) and further out, so the turn
## into the doorway presses diagonally (~20-55 deg) into the west jamb / wall corner at x ~16.3..16.5.
const STARTS: Array[Vector3] = [Vector3(15.8, 0.0, 4.88), Vector3(15.7, 0.0, 5.1), Vector3(15.9, 0.0, 5.35),
	Vector3(15.6, 0.0, 5.65), Vector3(16.2, 0.0, 5.6)]
const BUDGET_S: float = 8.0

var _rt: HeistRuntime = null
var _tr: PTraversal = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"glasshouse", 1002, Enums.Difficulty.ROUTINE, self, {"ai_teammates": 0})
	_rt.isolate_npc(null)
	var dir: Node = _rt.service(G.SVC_DIRECTOR)
	if dir != null:
		dir.process_mode = Node.PROCESS_MODE_DISABLED
	for n: Node in _rt.find_children("*", "Door", true, false):
		(n as Door).unlock()
		(n as Door).set_open(true)
	_tr = PTraversal.new(self, _rt)
	await wait_seconds(1.0)  # doors finish swinging (A's door swing, r75)


func after_each() -> void:
	_tr.inp.release_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func test_diagonal_into_lobby_door_slides_through() -> void:
	var fails: Array[String] = []
	for weight: int in [-1, Enums.LootWeight.MEDIUM, Enums.LootWeight.HEAVY]:
		for st: Vector3 in STARTS:
			var r: Dictionary = await _tr.route([st, DOOR_CORNER, IN_LOBBY] as Array[Vector3], weight, false, BUDGET_S)
			var ang: float = rad_to_deg(atan2(absf(DOOR_CORNER.z - st.z), absf(DOOR_CORNER.x - st.x)))
			var tag: String = "%s from (%.1f, %.1f) at %.0f deg" % ["no bag" if weight < 0 else "bag w%d" % weight,
				st.x, st.z, ang]
			print("[GH-LOBBY] %s: %s in %.1f s%s" % [tag, "through" if r["ok"] else "STUCK", float(r["time_s"]),
				"" if r["ok"] else " at %s" % r["stalled_at"]])
			if not r["ok"]:
				fails.append("%s stuck at %s" % [tag, r["stalled_at"]])
	assert_true(fails.is_empty(), "every diagonal approach slides into the lobby: %s" % [fails])
