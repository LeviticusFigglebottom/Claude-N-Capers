## validate_level `lasers` check (D-048) with the real ENV A laser_grid prefab: the static grid's
## bypass gap must fit the player. Skipped if ENV A's prefab is absent.
extends LcTestBase

const GRID_PREFAB: String = "res://systems/prefabs/laser_grid/laser_grid.tscn"
## Fixture room A interior: x 0.4 .. 7.9 (walls), grid plane at z = 5.0.
const WALL_W: float = 0.4
const WALL_E: float = 7.9


## Grid across room A, flush with the east wall, leaving `gap` m at the west wall.
## `height` / `beams`: with one beam its centre sits at height / 2. `crouch`: meta crouch_under.
func _grid_case(gap: float, pattern: StringName, bypass: Variant, height: float = 2.0, beams: int = 4,
		crouch: Variant = null) -> Dictionary:
	return await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		var g: Node3D = (load(GRID_PREFAB) as PackedScene).instantiate() as Node3D
		g.name = "TestLasers"
		var w: float = WALL_E - WALL_W - gap
		g.set(&"pattern", pattern)
		g.set(&"beam_count", beams)
		g.set(&"size_m", Vector3(w, height, 0.1))
		if crouch != null:
			g.set_meta(&"crouch_under", crouch)
		g.position = Vector3(WALL_E - w * 0.5, 0.0, 5.0)
		if bypass != null:
			g.set_meta(&"bypass", bypass)
		m.get_node("Gameplay").add_child(g)
		g.owner = m, false, ["lasers"])


func _prefab_ok() -> bool:
	if not ResourceLoader.exists(GRID_PREFAB):
		skip("ENV A laser_grid prefab not present")
		return false
	return true


func test_static_grid_0_7m_gap_fails() -> void:
	if not _prefab_ok():
		return
	var res: Dictionary = await _grid_case(0.7, &"static", null)
	_expect_fail(res, "lasers", "TestLasers")
	_expect_fail(res, "lasers", "clear 0.70")


func test_static_grid_0_9m_gap_passes() -> void:
	if not _prefab_ok():
		return
	var res: Dictionary = await _grid_case(0.9, &"static", null)
	_expect_only(res, [])


func test_timed_grid_without_gap_and_bypass_false_is_skipped() -> void:
	if not _prefab_ok():
		return
	var res: Dictionary = await _grid_case(0.0, &"timed_off", false)
	_expect_only(res, [])


func test_sweeping_grid_with_bypass_true_is_checked() -> void:
	if not _prefab_ok():
		return
	var res: Dictionary = await _grid_case(0.0, &"sweeping", true)
	_expect_fail(res, "lasers", "TestLasers")


func test_crouch_under_beam_at_1_0m_fails() -> void:
	if not _prefab_ok():
		return
	var res: Dictionary = await _grid_case(0.0, &"static", false, 2.0, 1, true)
	_expect_fail(res, "lasers", "TestLasers")
	_expect_fail(res, "lasers", "lowest beam 0.99")


func test_crouch_under_beam_at_1_3m_passes() -> void:
	if not _prefab_ok():
		return
	var res: Dictionary = await _grid_case(0.0, &"static", false, 2.6, 1, true)
	_expect_only(res, [])


func test_crouch_under_false_is_unaffected() -> void:
	if not _prefab_ok():
		return
	# Low single beam, no crouch route: judged on its 0.9 m side gap alone (passes).
	var res: Dictionary = await _grid_case(0.9, &"static", null, 2.0, 1, false)
	_expect_only(res, [])
