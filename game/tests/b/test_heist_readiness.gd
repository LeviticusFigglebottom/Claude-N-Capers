## OF-B1 readiness gate: the menus offer a heist only with its def, its map and every heist_list.tres "requires" path
## (HeistCatalog.is_ready). Ostrander Federal stays hidden until C's G1 (def + map) and A's OF-A6 mission script land.
extends TestCase

const OF: StringName = &"ostrander_federal"
const OF_MISSION: String = "res://world/heists/ostrander_federal/ostrander_federal_mission.gd"
const OF_BLUEPRINT: String = "res://content/data/preplanning/blueprints/ostrander_federal.tres"
## Pre-staged room ids (docs/design/heists/ostrander_federal.md §Room list, lowercase) -> ui.preplan.bp.ostrander_federal.<id>.
const OF_ROOMS: Array[String] = ["lk", "gl", "cq", "sa", "cp", "pl", "cm", "ss", "sb", "bb", "rc", "vc", "vt", "sd",
	"ld", "e1", "sr", "gr", "wm", "ww", "j1", "mo", "bc", "lo", "tw", "pc", "cn1", "cn2", "av", "bh", "ve", "bm", "pw",
	"na", "br", "e2", "e3", "it", "sv", "j2", "ar", "uc", "ao1", "ao2", "ao3", "wl", "el", "of", "cf", "co", "ga", "vo",
	"tr", "tt", "bd", "ea", "pr", "pn", "hh", "ct", "lg", "ra", "rp", "wm2", "ww2", "x1", "x2", "x3", "x4", "x5", "xc",
	"xl", "xw"]


func test_of_requires_its_mission() -> void:
	assert_eq(HeistCatalog.heist_list().requires_for(OF), PackedStringArray([OF_MISSION]))
	assert_eq(HeistCatalog.heist_list().requires_for(&"glasshouse"), PackedStringArray(), "no gate beyond def + map")


func test_gate_needs_map_and_requires() -> void:
	var map_path: String = HeistRegistry.map_scene_path(OF)
	var have: Array[String] = [map_path]
	var exists: Callable = func(p: String) -> bool: return have.has(p)
	assert_false(HeistCatalog.is_ready(OF, exists), "G1 map without the OF-A6 mission: hidden")
	have.append(OF_MISSION)
	assert_eq(HeistCatalog.is_ready(OF, exists), not HeistCatalog.heist_list().is_hidden(OF),
			"map + mission: offered once the hidden switch is off")
	have.erase(map_path)
	assert_false(HeistCatalog.is_ready(OF, exists), "mission without a map: hidden")


## C's G1 ships a mission STUB at the same path: the "hidden" switch keeps RT and AH out until A's mission lands.
## OF's switch is off since OF-A6 phase 2 (LEAD r245: OF playable).
func test_hidden_switch() -> void:
	var have: Callable = func(_p: String) -> bool: return true
	assert_false(HeistCatalog.heist_list().is_hidden(OF), "OF offered (OF-A6, round 245)")
	assert_true(HeistCatalog.is_ready(OF, have), "OF ready with map + mission")
	assert_false(HeistCatalog.heist_list().is_hidden(&"rolling_thunder"), "RT offered (D-160 flip)")
	assert_true(HeistCatalog.is_ready(&"rolling_thunder", have), "RT ready with map + mission")
	for h: StringName in [&"afterhours"]:
		assert_true(HeistCatalog.heist_list().is_hidden(h), "%s hidden" % h)
		assert_false(HeistCatalog.is_ready(h, have), "%s: hidden even with map + mission present" % h)
		assert_false(HeistCatalog.ids().has(h))
	assert_false(HeistCatalog.heist_list().is_hidden(&"glasshouse"))


func test_of_menu_entry_follows_the_gate() -> void:
	var ready: bool = HeistRegistry.get_def(OF) != null and HeistCatalog.is_ready(OF)
	assert_eq(HeistCatalog.ids().has(OF), ready, "OF offered iff def + map + mission")
	if not ResourceLoader.exists(OF_MISSION):
		assert_false(HeistCatalog.ids().has(OF), "OF hidden until OF-A6")
	for k: String in ["name", "subtitle", "brief"]:
		assert_true(UiText.has(StringName("heist.%s.%s" % [OF, k])), "menu string heist.%s.%s" % [OF, k])


func test_ready_heists_unchanged() -> void:
	for id: StringName in [&"glasshouse", &"night_deposit", &"gallery_night", &"shadow_ledger", &"dockside_burn"]:
		if HeistRegistry.get_def(id) != null and HeistCatalog.has_map(id):
			assert_true(HeistCatalog.ids().has(id), "%s still offered" % id)


## Pre-staged blueprint plumbing: the exporter's floor names and every doc room's label exist now, so G1 only needs
## `blueprint_export.gd -- ostrander_federal`; once OF is offered its blueprint must be the exported one.
func test_of_blueprint_staged() -> void:
	for k: String in ["ui.preplan.floor.basement", "ui.preplan.floor.ground", "ui.preplan.floor.gallery",
			"ui.preplan.floor.executive", "ui.preplan.floor.roof"]:
		assert_true(UiText.has(StringName(k)), k)
	for id: String in OF_ROOMS:
		var key: StringName = StringName(BriefingIntel.ROOM_KEY_FMT % [OF, id])
		assert_true(UiText.has(key), "room label %s" % key)
	if HeistCatalog.ids().has(OF):
		assert_true(ResourceLoader.exists(OF_BLUEPRINT), "OF offered: its blueprint is exported")
	if ResourceLoader.exists(OF_BLUEPRINT):
		var bp: PreplanBlueprint = load(OF_BLUEPRINT) as PreplanBlueprint
		assert_eq(bp.floor_names.size(), 5, "5 levels")
		for sh: Dictionary in bp.shapes:
			var label: StringName = StringName(sh.get("label", &""))
			if label != &"":
				assert_true(UiText.has(label), "blueprint label %s" % label)


## Rolling Thunder groundwork (data only): hidden until its mission script lands; the Board / select / briefing say
## "Loud (ambush start)" (D-075) from heist_list.tres "mode_key".
func test_rolling_thunder_staged() -> void:
	var rt: StringName = &"rolling_thunder"
	var mission: String = "res://world/heists/rolling_thunder/rolling_thunder_mission.gd"
	assert_eq(HeistCatalog.heist_list().requires_for(rt), PackedStringArray([mission]))
	if not ResourceLoader.exists(mission):
		assert_false(HeistCatalog.ids().has(rt), "RT hidden until its mission")
	assert_eq(HeistCatalog.mode_key(rt, Enums.HeistMode.STEALTH_OR_LOUD), &"ui.heist_select.modes_loud_ambush")
	assert_eq(UiText.t(&"ui.heist_select.modes_loud_ambush"), "Loud (ambush start)")
	assert_eq(HeistCatalog.mode_key(&"glasshouse", Enums.HeistMode.STEALTH_OR_LOUD), &"ui.heist_select.modes_stealth_loud")
	assert_eq(HeistCatalog.mode_key(&"dockside_burn", Enums.HeistMode.LOUD_ONLY), &"ui.heist_select.modes_loud_only")
	for tag: String in ["casing", "signals", "charges", "thermite", "marshal", "convoy", "ambush", "escort", "trucks",
			"cargo", "secure", "escape_wait", "escape"]:
		assert_true(UiText.has(StringName("objective.rolling_thunder.%s" % tag)), "objective %s" % tag)
	for a: String in ["signal_insider", "intel_route"]:
		assert_true(ResourceLoader.exists("res://content/data/preplanning/assets/%s.tres" % a), a)
		assert_true(UiText.has(StringName("item.asset.%s.name" % a)), a + " name")


## Afterhours groundwork (data only): hidden until its mission script lands; objective, asset and music strings staged.
func test_afterhours_staged() -> void:
	var ah: StringName = &"afterhours"
	var mission: String = "res://world/heists/afterhours/afterhours_mission.gd"
	assert_eq(HeistCatalog.heist_list().requires_for(ah), PackedStringArray([mission]))
	if not ResourceLoader.exists(mission):
		assert_false(HeistCatalog.ids().has(ah), "AH hidden until its mission")
	for tag: String in ["casing", "gear", "keycard", "office", "safe_code", "safe", "safe_loot", "secure", "product",
			"count_room", "escape_wait", "escape"]:
		assert_true(UiText.has(StringName("objective.afterhours.%s" % tag)), "objective %s" % tag)
	for a: String in ["gear_drop", "count_window"]:
		var def: PreplanAssetDef = load("res://content/data/preplanning/assets/%s.tres" % a) as PreplanAssetDef
		assert_true(def != null and not def.point_ids.is_empty(), a + ": point-limited (Afterhours only)")
		assert_true(UiText.has(StringName("item.asset.%s.name" % a)), a + " name")
	assert_true(UiText.has(&"music.afterhours.name"))


## D-143 per-heist asset allow-list: Afterhours' intel assets (code_note / product_location) are not offered on the
## shipped heists that also have those variant groups; an empty list still means every heist.
func test_asset_allow_list() -> void:
	PreplanBoard.clear_cache()
	for a: StringName in [&"asset.intel_safe_code", &"asset.intel_product"]:
		var def: PreplanAssetDef = PreplanBoard.generic_assets().get(a) as PreplanAssetDef
		assert_true(def != null, "%s in the library" % a)
		assert_eq(def.heists, [&"afterhours"] as Array[StringName])
		assert_true(def.offered_on(&"afterhours"))
		assert_false(def.offered_on(&"glasshouse"))
		assert_true(UiText.has(StringName("item.%s.name" % a)))
	for heist: StringName in [&"glasshouse", &"gallery_night", &"night_deposit", &"shadow_ledger", &"dockside_burn"]:
		var b: PreplanBoard = PreplanBoard.build(heist, Enums.Difficulty.ROUTINE)
		assert_false(b.asset_ids().has(&"asset.intel_safe_code"), "%s: AH-only intel hidden" % heist)
		assert_false(b.asset_ids().has(&"asset.intel_product"), "%s: AH-only intel hidden" % heist)
	var gh: PreplanBoard = PreplanBoard.build(&"glasshouse", Enums.Difficulty.ROUTINE)
	assert_true(gh.asset_ids().has(&"asset.intel_cameras"), "an empty allow-list is offered everywhere")
	var ah: PreplanBoard = PreplanBoard.build(&"afterhours", Enums.Difficulty.ROUTINE)
	assert_true(ah.asset_ids().has(&"asset.intel_safe_code"), "offered on Afterhours")
