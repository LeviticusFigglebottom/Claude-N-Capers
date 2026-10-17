## D-133: crew_damage_taken_mult is a HARNESS-ONLY dev option. Only HeistLauncher.dev_options (set by the e2e runners)
## carries it into a run; the same key in the caller's options (what menus build) is stripped, and no profile or
## settings resource has such a field. Applied as a crew Modifiers source and logged.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	HeistLauncher.dev_options.clear()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func test_d133_caller_options_cannot_set_it() -> void:
	HeistLauncher.dev_options.clear()
	var o: Dictionary = HeistLauncher.with_dev_options({"crew_damage_taken_mult": 0.1, "skip_casing": true})
	assert_false(o.has("crew_damage_taken_mult"), "a caller-supplied (menu) key is stripped")
	assert_true(bool(o.get("skip_casing", false)), "other options pass through")
	HeistLauncher.dev_options["crew_damage_taken_mult"] = 0.25
	HeistLauncher.dev_options["not_a_dev_key"] = 1
	o = HeistLauncher.with_dev_options({"crew_damage_taken_mult": 0.1})
	assert_near(float(o["crew_damage_taken_mult"]), 0.25, 0.0001, "the harness value wins")
	assert_false(o.has("not_a_dev_key"), "only DEV_KEYS are honoured")


func test_d133_no_profile_or_settings_field() -> void:
	for path: String in ["res://content/save/player_profile.gd", "res://content/settings/game_settings.gd"]:
		var script: Script = load(path) as Script
		assert_true(script != null, "%s loads" % path)
		if script == null:
			continue
		for p: Dictionary in script.get_script_property_list():
			assert_false(String(p["name"]).contains("damage_taken"), "%s has no damage_taken field (%s)" % [path, p["name"]])


func test_d133_launch_applies_it_to_the_crew() -> void:
	HeistLauncher.dev_options["crew_damage_taken_mult"] = 0.25
	_rt = await HeistLauncher.launch(&"unit_map", 1330, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1, "crew_ai": false})
	await wait_physics_frames(2)
	assert_near(float(_rt.options.get("crew_damage_taken_mult", 1.0)), 0.25, 0.0001, "in the run's options")
	for c: CrewController in _rt.crew_members():
		assert_near(Modifiers.mult(c.slot, &"defense.damage_taken_mult"), 0.25, 0.0001, "slot %d takes x0.25" % c.slot)
	_rt.teardown()
	_rt = null
	await wait_frames(2)
	HeistLauncher.dev_options.clear()
	_rt = await HeistLauncher.launch(&"unit_map", 1330, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false, "crew_damage_taken_mult": 0.25})
	await wait_physics_frames(2)
	assert_near(Modifiers.mult(0, &"defense.damage_taken_mult"), 1.0, 0.0001, "menu-style option ignored: x1")
