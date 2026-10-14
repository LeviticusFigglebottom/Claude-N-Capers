## Gate 3 traversal checks on Glasshouse with the G1 harness (PTraversal, real input): the G8 U-stair up and down
## with and without a heavy bag, and the alley fire-escape ladder. When ENV C's stair ramp colliders and the
## fire-escape door-window land, the same routes re-verify them (the stair route is geometry-agnostic).
## Glasshouse on llvmpipe is slow: windowed run, a few minutes per test.
extends TestCase

## G8 stair (glasshouse.md vertical data): foot in G4, up-flight along -z at x 13.7 to the half landing (+2.1),
## return flight along +z at x 15.3 to the U4 arrival (+4.2).
const STAIR_UP: Array[Vector3] = [Vector3(13.7, 0.0, 5.3), Vector3(13.7, 0.0, 4.7), Vector3(13.7, 2.1, 1.0),
	Vector3(15.3, 2.1, 0.9), Vector3(15.3, 4.2, 4.9)]
## Seconds per flight pair at walk speed is ~3 s; heavy bag x0.5.
const BUDGET_S: float = 20.0

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
	await wait_physics_frames(5)


func after_each() -> void:
	_tr.inp.release_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _down(pts: Array[Vector3]) -> Array[Vector3]:
	var out: Array[Vector3] = pts.duplicate()
	out.reverse()
	return out


func test_stair_up_and_down() -> void:
	for weight: int in [-1, Enums.LootWeight.HEAVY]:
		var tag: String = "no bag" if weight < 0 else "heavy bag"
		var up: Dictionary = await _tr.route(STAIR_UP, weight, false, BUDGET_S)
		assert_true(up["ok"], "G8 stair up, %s: %s" % [tag, up])
		assert_true(_tr.crew.global_position.y > 4.0, "%s: arrived on the upper floor (y %.2f)" % [tag,
			_tr.crew.global_position.y])
		var down: Dictionary = await _tr.route(_down(STAIR_UP), weight, false, BUDGET_S)
		assert_true(down["ok"], "G8 stair down, %s: %s" % [tag, down])
		assert_true(_tr.crew.global_position.y < 0.3, "%s: back on the ground floor (y %.2f)" % [tag,
			_tr.crew.global_position.y])
		print("[GH-TRAV] stair %s: up %.1f s, down %.1f s" % [tag, float(up["time_s"]), float(down["time_s"])])


func test_fire_escape_ladder() -> void:
	var l: Ladder = null
	for n: Node in _rt.map.find_children("FireEscapeLadder", "Ladder", true, false):
		l = n as Ladder
	assert_true(l != null, "Glasshouse has FireEscapeLadder")
	if l == null:
		return
	var r: Dictionary = await _tr.ladder(l)
	print("[GH-TRAV] fire-escape ladder: %s" % r)
	assert_true(r["up"], "up the fire-escape ladder (%s)" % r)
	assert_true(r["down"], "back down (%s)" % r)
