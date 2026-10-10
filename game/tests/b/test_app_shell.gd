## B1-04 / D-024: app shell. LaunchArgs parsing, direct launch through MenuFlow, and the heist
## catalog built from HeistRegistry with the placeholder fallback.
extends TestCase

const TEST_ROOT: String = "user://test_profiles"


func before_all() -> void:
	SaveService.root_dir = TEST_ROOT
	SaveService.delete_profile(0)


func after_all() -> void:
	SaveService.delete_profile(0)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR
	Log.capture = false
	Log.captured.clear()


func _args(list: Array) -> Dictionary:
	return LaunchArgs.parse(PackedStringArray(list))


# --- LaunchArgs ---

func test_parse_no_flags() -> void:
	var a: Dictionary = _args([])
	assert_false(bool(a["direct"]))
	assert_eq(a["heist_id"], &"")
	assert_false(bool(a["has_seed"]))
	assert_eq(int(a["difficulty"]), Enums.Difficulty.ROUTINE)
	assert_true((a["errors"] as Array).is_empty())


func test_parse_valid() -> void:
	var a: Dictionary = _args(["--heist=glasshouse", "--seed=1234", "--difficulty=3"])
	assert_true(bool(a["direct"]))
	assert_eq(a["heist_id"], &"glasshouse")
	assert_true(bool(a["has_seed"]))
	assert_eq(int(a["seed"]), 1234)
	assert_eq(int(a["difficulty"]), Enums.Difficulty.BRUTAL)
	assert_true((a["errors"] as Array).is_empty(), str(a["errors"]))


func test_parse_defaults_and_negative_seed() -> void:
	var a: Dictionary = _args(["--heist=glasshouse"])
	assert_true(bool(a["direct"]))
	assert_false(bool(a["has_seed"]), "seed defaults to time (chosen by MenuFlow)")
	assert_eq(int(a["difficulty"]), Enums.Difficulty.ROUTINE)
	assert_eq(int(_args(["--heist=x", "--seed=-7"])["seed"]), -7)


func test_parse_missing_values() -> void:
	for bad: Array in [["--heist"], ["--heist="], ["--heist=x", "--seed"], ["--heist=x", "--seed=abc"],
			["--heist=x", "--difficulty"]]:
		var a: Dictionary = _args(bad)
		assert_false((a["errors"] as Array).is_empty(), "error for %s" % [bad])
	assert_false(bool(_args(["--heist"])["direct"]), "no id, no direct launch")


func test_parse_bad_difficulty() -> void:
	for d: String in ["-1", "6", "99", "brutal", "2.5"]:
		var a: Dictionary = _args(["--heist=glasshouse", "--difficulty=%s" % d])
		assert_eq((a["errors"] as Array).size(), 1, "difficulty '%s' rejected" % d)
		assert_eq(int(a["difficulty"]), Enums.Difficulty.ROUTINE)
	assert_eq(int(_args(["--heist=x", "--difficulty=5"])["difficulty"]), Enums.Difficulty.CATACLYSM)


func test_parse_ignores_unknown_flags() -> void:
	var a: Dictionary = _args(["--dir=b", "--filter=ui", "plain", "--fullscreen", "--heist=glasshouse"])
	assert_true((a["errors"] as Array).is_empty(), str(a["errors"]))
	assert_eq(a["heist_id"], &"glasshouse")


func test_validate_heist() -> void:
	var known: Array[StringName] = [&"glasshouse"]
	assert_eq(LaunchArgs.validate_heist(&"glasshouse", known), "")
	assert_true(LaunchArgs.validate_heist(&"nope", known).contains("nope"))


# --- direct launch through MenuFlow ---

func _flow() -> MenuFlow:
	var f: MenuFlow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	add_child(f)
	return f


func test_direct_launch_without_launcher_shows_stub() -> void:
	if UiNav.global_class(&"HeistLauncher") != null:
		skip("HeistLauncher exists; launching is covered by the integration tests")
		return
	var f: MenuFlow = _flow()
	await wait_frames(1)
	var ok: bool = f.direct_launch(_args(["--heist=glasshouse", "--seed=42", "--difficulty=3"]))
	await wait_frames(1)
	assert_true(ok, "valid args accepted")
	assert_eq(f.current, f.stub_screen as Control)
	assert_true(f.visible, "menus stay visible without a launcher")
	assert_false(f.in_heist_ui_spawned(), "no HUD/payday layer without a launcher")
	assert_eq(get_tree().get_nodes_in_group(G.LOCAL_HUD_MODEL).size(), 0)
	f.stub_screen.back_button.pressed.emit()
	assert_eq(f.current, f.main_menu as Control)
	f.queue_free()
	await wait_frames(1)


func test_direct_launch_rejects_bad_input() -> void:
	Log.capture = true
	Log.captured.clear()
	var f: MenuFlow = _flow()
	await wait_frames(1)
	assert_false(f.direct_launch(_args(["--heist=no_such_heist"])), "unknown heist rejected")
	assert_eq(f.current, f.main_menu as Control)
	assert_false(f.direct_launch(_args(["--heist=glasshouse", "--difficulty=9"])), "bad difficulty rejected")
	assert_eq(f.current, f.main_menu as Control)
	assert_false(f.in_heist_ui_spawned())
	var errors: int = 0
	for line: String in Log.captured:
		if line.begins_with("[ERROR][ui]") and line.contains("direct launch"):
			errors += 1
	assert_eq(errors, 2, "one error per rejected launch")
	Log.capture = false
	f.queue_free()
	await wait_frames(1)


# --- heist catalog ---

func test_catalog_placeholder_while_def_missing() -> void:
	var list: UiHeistList = HeistCatalog.heist_list()
	assert_true(list.heists.has(&"glasshouse"))
	var e: Array[Dictionary] = HeistCatalog.entries_from({}, list)
	assert_eq(e.size(), 1)
	assert_eq(e[0]["id"], &"glasshouse")
	assert_true(bool(e[0]["placeholder"]))
	assert_eq(int(e[0]["base_payout"]), 40000)
	assert_true(e[0]["def"] == null)


func test_catalog_uses_registry_defs() -> void:
	var def: HeistDef = HeistDef.new()
	def.id = &"glasshouse"
	def.base_payout = 55000
	def.mode = Enums.HeistMode.STEALTH_ONLY
	var other: HeistDef = HeistDef.new()
	other.id = &"aardvark"
	other.base_payout = 1000
	var e: Array[Dictionary] = HeistCatalog.entries_from({&"glasshouse": def, &"aardvark": other},
			HeistCatalog.heist_list())
	assert_eq(e.size(), 2, "placeholder dropped once the def exists")
	assert_eq(e[0]["id"], &"aardvark", "sorted by id")
	assert_eq(e[1]["id"], &"glasshouse")
	assert_false(bool(e[1]["placeholder"]))
	assert_eq(int(e[1]["base_payout"]), 55000)
	assert_eq(int(e[1]["mode"]), Enums.HeistMode.STEALTH_ONLY)
	assert_eq(e[1]["def"], def)


func test_catalog_matches_registry() -> void:
	var reg: Array[StringName] = HeistRegistry.ids()
	var ids: Array[StringName] = HeistCatalog.ids()
	for id: StringName in reg:
		assert_has(ids, id)
	for e: Dictionary in HeistCatalog.entries():
		var id: StringName = StringName(e["id"])
		assert_eq(bool(e["placeholder"]), HeistRegistry.get_def(id) == null, "placeholder iff no def: %s" % id)
	assert_true(ids.has(&"glasshouse"), "Glasshouse listed (def or placeholder)")


func test_solo_ai_per_heist() -> void:
	var list: UiHeistList = UiHeistList.new()
	list.solo_ai_teammates = 3
	list.heists = {&"glasshouse": {"solo_ai_teammates": 1}}
	assert_eq(list.solo_ai_for(&"glasshouse"), 1)
	assert_eq(list.solo_ai_for(&"other"), 3)


# --- firing range entry (B1-05) ---

func test_main_menu_opens_and_closes_firing_range() -> void:
	var f: MenuFlow = _flow()
	await wait_frames(2)
	f.main_menu.range_button.pressed.emit()
	await wait_frames(3)
	assert_true(f.firing_range != null and f.firing_range.is_inside_tree(), "range entered")
	assert_false(f.visible, "menus hidden while in range")
	var r: FiringRange = f.firing_range
	r.exit_requested.emit()
	await wait_frames(2)
	assert_true(f.firing_range == null, "range closed")
	assert_false(is_instance_valid(r), "range freed")
	assert_true(f.visible, "menus visible again")
	assert_eq(f.current, f.main_menu, "back on the main menu")
	f.queue_free()
	await wait_frames(1)
