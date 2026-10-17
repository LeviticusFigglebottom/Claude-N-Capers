## B6-01: P5 loot + contract catalogue (game/content/docs/heists/<id>.md for the four P5 heists).
## Loot defs follow pd2_fidelity S10 weight classes and the PD2 bag shape our P2/P3 loot uses (a
## heavier bag is worth more per bag); the Board stubs (city map spot, accent, heist list entry,
## strings) stay hidden until ENV C ships a HeistDef and map (QB-55, D-049). Each check that depends
## on the def falls back to "hidden" while `HeistRegistry.get_def(id)` is null.
extends TestCase

## [id, weight, base value] (◇, data README "P5 heists").
const P5_LOOT: Array = [
	[&"loot.gold", Enums.LootWeight.HEAVY, 14000],
	[&"loot.server_drives", Enums.LootWeight.MEDIUM, 7500],
	[&"loot.bearer_bonds", Enums.LootWeight.LIGHT, 7000],
	[&"loot.parcels", Enums.LootWeight.LIGHT, 7500],
	[&"loot.painting_tidewater_saint", Enums.LootWeight.LIGHT, 5200],
	[&"loot.painting_widow_in_blue", Enums.LootWeight.LIGHT, 6000],
	[&"loot.painting_salt_orchard", Enums.LootWeight.LIGHT, 6800],
	[&"loot.painting_lantern_bearer", Enums.LootWeight.LIGHT, 8000],
	[&"loot.painting_study", Enums.LootWeight.LIGHT, 2800],  # D-075; D-081's $700 x4 in the D-115 balance pass
]
## Gallery Night's rolled canvases (PD2 carries cut paintings as a light bag).
const PAINTINGS: Array[StringName] = [
	&"loot.painting_tidewater_saint", &"loot.painting_widow_in_blue", &"loot.painting_salt_orchard",
	&"loot.painting_lantern_bearer", &"loot.painting_study",
]
## Value band per weight class (D-115 balance pass, data README "Loot"): [min, max] by Enums.LootWeight.
## LIGHT runs from the painting study ($2,800) to the Lantern Bearer ($8,000); MEDIUM from the discounted
## contraband ($7,000) to the cash bricks / ledger books ($8,000, P5 drives $7,500); HEAVY from the weapon
## crate ($8,500) to gold ($14,000), the top bag.
const BANDS: Array = [[2800, 8000], [7000, 8000], [8500, 14000]]
## Stubs whose G0 doc is approved and whose objective strings are drafted (GN-B1, D-103).
const OBJECTIVES_DRAFTED: Array[StringName] = [&"gallery_night", &"ostrander_federal"]  # OF: D-137 kickoff
## heist id -> [contact, district, placeholder base payout ◇ (unscaled)].
const STUBS: Dictionary = {
	&"gallery_night": [&"contact.vance", &"uptown", 57000],
	&"ostrander_federal": [&"contact.accountant", &"financial", 80000],  # D-137 (D-120 shape)
	&"rolling_thunder": [&"contact.reyes", &"southfield", 85000],
	&"afterhours": [&"contact.accountant", &"midtown", 75000],  # D-075
}
## Contract pay by difficulty (Routine..Cataclysm) for each placeholder payout, as the docs print it.
const PAY_TABLES: Dictionary = {
	&"gallery_night": [57000, 114000, 148200, 239400, 410400, 524400],
	&"ostrander_federal": [80000, 160000, 208000, 336000, 576000, 736000],
	&"rolling_thunder": [85000, 170000, 221000, 357000, 612000, 782000],
	&"afterhours": [75000, 150000, 195000, 315000, 540000, 690000],
}
const BODY_TEXT: float = 4.5
const RESERVED_CYAN: Color = Color(0.3098, 0.8196, 0.9098, 1)

var _table: Dictionary = {}


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()
	_table = StringTable.parse_csv()


func after_all() -> void:
	SaveService.delete_profile(0)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


## Stub ids whose HeistDef has not shipped yet (sorted by text).
func _missing() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: Variant in STUBS:
		if HeistRegistry.get_def(StringName(id)) == null:
			out.append(StringName(id))
	ContentDB.sort_ids(out)
	return out


func test_p5_loot_loads_with_s10_shape() -> void:
	for row: Variant in P5_LOOT:
		var id: StringName = (row as Array)[0]
		var w: int = int((row as Array)[1])
		var l: LootDef = ContentDB.loot(id)
		assert_true(l != null, String(id))
		if l == null:
			continue
		assert_eq(l.id, id)
		assert_eq(int(l.weight), w, "%s weight" % id)
		assert_eq(l.value, int((row as Array)[2]), "%s value" % id)
		var band: Array = BANDS[w] as Array
		assert_true(l.value >= int(band[0]) and l.value <= int(band[1]), "%s value in its class band" % id)
		assert_false(l.is_tool, "%s is profit, not a tool" % id)
		assert_false(l.conceals)
		assert_true(l.display_name != "", "%s display name" % id)
	var gold: LootDef = ContentDB.loot(&"loot.gold")
	if gold == null:
		return
	for row: Variant in P5_LOOT:
		var other: LootDef = ContentDB.loot((row as Array)[0] as StringName)
		if other != null and other != gold:
			assert_true(gold.value > other.value, "HEAVY gold beats %s per bag" % other.id)
	assert_true(gold.value > ContentDB.loot(&"loot.weapon_crate").value, "gold is the top HEAVY bag")
	var drives: LootDef = ContentDB.loot(&"loot.server_drives")
	assert_true(drives.value > ContentDB.loot(&"loot.bearer_bonds").value, "MEDIUM drives beat LIGHT bonds")


## Money is the existing MEDIUM cash bricks (no duplicate def); paintings are LIGHT and distinct.
func test_p5_loot_reuses_money_and_varies_paintings() -> void:
	var bricks: LootDef = ContentDB.loot(&"loot.cash_bricks")
	assert_true(bricks != null and bricks.weight == Enums.LootWeight.MEDIUM, "money = loot.cash_bricks (MEDIUM)")
	for row: Variant in P5_LOOT:
		var id: String = String((row as Array)[0])
		assert_false(id.contains("money") or id.contains("cash"), "no duplicate money def: %s" % id)
	var values: Array[int] = []
	for id: StringName in PAINTINGS:
		var p: LootDef = ContentDB.loot(id)
		if p == null:
			continue
		assert_eq(p.weight, Enums.LootWeight.LIGHT, "%s rolled canvas" % id)
		assert_false(values.has(p.value), "%s has its own value" % id)
		values.append(p.value)
	assert_eq(values.size(), PAINTINGS.size())


func test_p5_strings_exist() -> void:
	for row: Variant in P5_LOOT:
		var id: StringName = (row as Array)[0]
		assert_has(_table, "item.%s.name" % id)
		assert_has(_table, "item.%s.desc" % id)
		assert_eq(String(_table.get("item.%s.name" % id, "")), ContentDB.loot(id).display_name, "%s name" % id)
	for id: Variant in STUBS:
		for k: String in ["name", "subtitle", "brief"]:
			assert_has(_table, "heist.%s.%s" % [id, k])
		var prefix: String = "objective.%s." % id
		if OBJECTIVES_DRAFTED.has(id):
			assert_has(_table, prefix + "casing", "drafted objectives present")
			continue
		for key: String in _table.keys():
			assert_false(key.begins_with(prefix), "objective strings wait for ENV C's G0 doc: %s" % key)


## The Board spot, contact, heist list entry and pay table of each stub.
func test_p5_board_stub_data() -> void:
	var city: BoardCityMap = BoardCityMap.load_default()
	var list: UiHeistList = HeistCatalog.heist_list()
	for id: Variant in STUBS:
		var hid: StringName = StringName(id)
		var row: Array = STUBS[id] as Array
		assert_eq(city.heist_contact(hid), row[0] as StringName, "%s contact" % hid)
		assert_true(ContactDef.find(row[0] as StringName) != null, "%s contact exists" % hid)
		assert_eq(city.heist_district(hid), row[1] as StringName, "%s district" % hid)
		var poly: PackedVector2Array = city.districts[row[1]]["polygon"] as PackedVector2Array
		assert_true(Geometry2D.is_point_in_polygon(city.heist_anchor(hid), poly), "%s pin inside its district" % hid)
		assert_true(list.heists.has(hid), "%s heist list entry" % hid)
		assert_false((list.heists.get(hid, {}) as Dictionary).has("placeholder_base_payout"), "QB-55: no payout here")
		var table: Array = PAY_TABLES[id] as Array
		for d: int in range(table.size()):
			assert_eq(HeistCatalog.contract_preview(int(row[2]), d), int(table[d]), "%s pay, difficulty %d" % [hid, d])


## QB-55: no def -> not in the catalog, heist select, the Board pool, any rolled contract, the broker.
func test_p5_stubs_hidden_while_def_missing() -> void:
	var missing: Array[StringName] = _missing()
	if missing.is_empty():
		skip("every P5 HeistDef has shipped")
		return
	var offered: Array[StringName] = HeistCatalog.ids()
	var pool: Array[Dictionary] = BoardContracts.pool()
	for id: StringName in missing:
		assert_false(offered.has(id), "%s not offered by the menus" % id)
		assert_true(BoardBroker.find_heist(pool, id).is_empty(), "%s not in the Board pool" % id)
	var tweak: BoardTweak = BoardTweak.load_default()
	var city: BoardCityMap = BoardCityMap.load_default()
	var allowed: Array[int] = BoardContracts.allowed_difficulties(100, tweak)
	if not pool.is_empty():
		for bucket: int in range(100):
			for slot: int in range(tweak.slot_count):
				var c: Dictionary = BoardContracts.contract_for(slot, bucket, allowed, pool, tweak, city)
				assert_false(missing.has(StringName(c["heist_id"])), "rolled a hidden stub: %s" % c["heist_id"])
	var profile: PlayerProfile = PlayerProfile.new_default()
	profile.stash = 1000000000
	for id: StringName in missing:
		var r: StringName = BoardBroker.check(profile, id, Enums.Difficulty.ROUTINE, pool, tweak)
		assert_eq(r, BoardBroker.R_UNKNOWN_HEIST, "broker refuses %s" % id)
	# The stub's map spot, accent and list entry alone never make a heist offered.
	var map_only: Callable = func(_id: StringName) -> bool: return true
	var fake: Dictionary = {}
	for id: StringName in missing:
		fake[id] = null
	assert_eq(HeistCatalog.entries_from(fake, map_only), [] as Array[Dictionary], "a null def is never offered")


func test_p5_stubs_hidden_in_screens() -> void:
	var missing: Array[StringName] = _missing()
	if missing.is_empty():
		skip("every P5 HeistDef has shipped")
		return
	var s: HeistSelect = (load("res://content/ui/menus/heist_select.tscn") as PackedScene).instantiate() as HeistSelect
	add_child(s)
	await wait_frames(1)
	for id: StringName in missing:
		assert_false(s.select_heist_id(id), "heist select hides %s" % id)
	s.queue_free()
	var bs: BoardScreen = (load("res://content/ui/board/board_screen.tscn") as PackedScene).instantiate() as BoardScreen
	bs.save_on_buy = false
	bs.setup(PlayerProfile.new_default())
	add_child(bs)
	await wait_frames(1)
	for c: Dictionary in bs.contracts:
		assert_false(missing.has(StringName(c["heist_id"])), "Board pin for hidden %s" % c["heist_id"])
	for e: Dictionary in bs.heist_pool:
		assert_false(missing.has(StringName(e["id"])), "Board broker lists hidden %s" % e["id"])
	bs.queue_free()
	await wait_frames(1)


## Accents: raw colour passes WCAG AA for text (4.5:1) on the panel and the app background, and is
## clearly apart from the reserved interactable cyan and every other heist's accent.
func test_p5_accents_pass_wcag() -> void:
	var t: UiHeistAccents = UiAccent.table()
	for id: Variant in STUBS:
		assert_true(t.accents.has(id), "%s accent" % id)
		var c: Color = UiAccent.for_heist(StringName(id))
		for bg: Color in [UiAccent.panel_bg(), UiAccent.app_bg()]:
			var r: float = UiAccent.contrast_ratio(c, bg)
			assert_true(r >= BODY_TEXT, "%s accent contrast %.2f" % [id, r])
		assert_true(_dist(c, RESERVED_CYAN) > 0.25, "%s stays off the interactable cyan" % id)
		for other: Variant in t.accents:
			if other != id:
				assert_true(_dist(c, t.accents[other] as Color) > 0.2, "%s vs %s accents distinct" % [id, other])


static func _dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
