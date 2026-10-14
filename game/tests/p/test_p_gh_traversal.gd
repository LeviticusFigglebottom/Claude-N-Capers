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


## Gate 3 (C 0177dfad): fire-escape ladder -> landing -> the break-room door-window (opened by holding F, or its glass
## broken when the variant is latched) -> U1; then a bag thrown back out through it to the landing / alley.
func test_fire_escape_window_route() -> void:
	var l: Ladder = null
	for n: Node in _rt.map.find_children("FireEscapeLadder", "Ladder", true, false):
		l = n as Ladder
	var win: WindowPrefab = null
	for n: Node in _rt.map.find_children("BreakRoomWindow", "Node3D", true, false):
		if n is WindowPrefab and n.is_inside_tree():
			win = n as WindowPrefab
	assert_true(l != null and win != null, "fire-escape ladder and break-room window")
	if l == null or win == null:
		return
	var up: Dictionary = await _tr.ladder(l, false)
	assert_true(up["up"], "up the ladder to the landing (%s)" % up)
	if win.openable:
		var use: Vector3 = win.use_point.global_position if win.get(&"use_point") != null else win.global_position + \
			Vector3(0, 0, -0.7)
		var latch: Vector3 = win.interactable.global_position if win.interactable != null else \
			win.global_position + Vector3.UP * 0.6
		await _tr.place(use, latch)
		var to: Vector3 = latch - _tr.crew.eye_position()
		await _tr.turn_to_pitch(atan2(to.y, Vector2(to.x, to.z).length()))  # look at the latch like a player
		_tr.inp.press(&"interact")
		var opened: bool = await wait_until(func() -> bool: return win.is_open, 6.0)
		_tr.inp.release(&"interact")
		assert_true(opened, "opened the door-window by holding F")
	else:
		win.break_glass()  # setup: the latched variant is passable once its glass is broken
		await wait_physics_frames(3)
	var inside: Vector3 = win.global_position + Vector3(0, 0, 1.6)
	var through: Dictionary = await _tr.route([win.global_position + Vector3(0, 0, -0.8), win.global_position +
		Vector3(0, 0, -0.3), inside] as Array[Vector3], -1, false, 12.0)
	print("[GH-TRAV] window route (%s): %s" % ["open" if win.openable else "broken", through])
	assert_true(through["ok"], "landing -> through the door-window -> U1 (%s)" % through)
	assert_true(_tr.crew.global_position.z > win.global_position.z + 0.5, "inside U1")
	var thrown: Dictionary = await _tr.throw_bag(win.global_position + Vector3(0, 0, 1.3), 0.0, deg_to_rad(8.0),
		Enums.LootWeight.MEDIUM)
	var land: Vector3 = thrown["landing"]
	print("[GH-TRAV] bag out of the window lands at %s" % land)
	assert_true(thrown["thrown"] and land.z < win.global_position.z - 0.2, "bag thrown back out (lands %s)" % land)
