## D-130 §1: stealth population by difficulty on the M heists (Gallery Night, Night Deposit, Shadow Ledger). Owner: ENV C.
## Rolls each map's real variant table on its real VariantSlots (VariantResolver, many seeds) and counts the guards and
## civilians that HeistRuntime would spawn at load: GUARD / CIVILIAN SpawnPoints outside any slot plus those inside
## the active slots (no `scripted` rare-event spawns; the camera operator is not counted). GN keeps the first `patrons`
## civ_patron spawns (the mission's thin_civilians) and counts the gala, before last call.
## Pins: every tier adds civilians (expected count), never below the tier below or the pre-D-130 count (addendum),
## the Cataclysm / Routine ratios D-130 asks for (>= +35 % civilians, a floor, on both; +50 % guards on ND; GN's
## guards keep their steeper lead-ruling curve, 1-2 / 1-2 / 3 / 4 / 5 / 5; SL keeps its pre-D-130 guard rows, 2 / 2-3 /
## 3-4 / 4 / 5 / 5, already +150 % at Lethal, and its civilians, already +45 % at Brutal before D-130, may pass +50 %),
## and that each map's spawn pool covers the largest roll.
## Design: docs/design/heists/night_deposit.md, gallery_night.md, shadow_ledger.md (§roster "Totals per difficulty").
extends TestCase

const MAPS: Dictionary = {
	&"night_deposit": "res://world/heists/night_deposit/night_deposit.tscn",
	&"gallery_night": "res://world/heists/gallery_night/gallery_night.tscn",
	&"shadow_ledger": "res://world/heists/shadow_ledger/shadow_ledger.tscn",
}
const RUNS: int = 1500
const SCRIPTED: StringName = &"scripted"
const PATRON_TAG: StringName = &"civ_patron"
## Cataclysm / Routine expected civilians: [floor (D-130's +35 %, a floor), cap]. SL's cap is higher: its pre-D-130
## Brutal..Cataclysm rows were already x1.46 and every tier must still add civilians.
const CIV_RATIO: Dictionary = {
	&"night_deposit": [1.33, 1.5], &"gallery_night": [1.33, 1.5], &"shadow_ledger": [1.33, 1.9],
}

## Expected counts per tier before D-130 (ROUTINE..CATACLYSM; same seeds, the a5b797f8 variant tables; SL: the 708a9cd1
## table, measured before its D-130 rows): D-130 counts
## never fall below them (LEAD, D-130 addendum).
const PRE_D130: Dictionary = {
	&"night_deposit": {"g": [2.71, 2.71, 2.71, 3.50, 3.50, 3.50], "c": [1.20, 1.20, 1.20, 1.19, 1.19, 1.19]},
	&"gallery_night": {"g": [1.82, 1.82, 3.00, 4.00, 5.00, 5.00], "c": [10.13, 10.13, 12.54, 12.51, 13.44, 13.44]},
	&"shadow_ledger": {"g": [2.00, 2.51, 3.47, 4.00, 5.00, 5.00], "c": [2.26, 2.27, 2.78, 3.29, 3.29, 3.29]},
}

var _maps: Dictionary = {}
## heist -> difficulty -> {"g": [min, max, sum], "c": [min, max, sum]}
var _stats: Dictionary = {}


func before_all() -> void:
	for id: StringName in MAPS:
		var ps: PackedScene = load(MAPS[id]) as PackedScene
		if ps != null:
			_maps[id] = ps.instantiate() as HeistMap
	for id: StringName in _maps:
		_stats[id] = _roll_all(_maps[id] as HeistMap, id)


func after_all() -> void:
	for id: StringName in _maps:
		(_maps[id] as Node).free()
	_maps.clear()


func _roll_all(map: HeistMap, id: StringName) -> Dictionary:
	var slots: Dictionary = VariantResolver.collect_slots(map)
	var fixed: Dictionary = _count(map.get_node("Spawns"), id == &"gallery_night")
	var out: Dictionary = {}
	for d: int in range(Enums.Difficulty.CATACLYSM + 1):
		var g: Array = [999, -1, 0.0]
		var c: Array = [999, -1, 0.0]
		for s: int in range(RUNS):
			GameRng.begin_run(130000 + s)
			var v: Dictionary = VariantResolver.resolve(map.variant_table, slots, d)
			var ng: int = int(fixed["g"])
			var nc: int = int(fixed["c"])
			for group: Variant in slots:
				for vs: VariantSlot in slots[group]:
					if (v.get(group, []) as Array).has(vs.slot_id):
						var k: Dictionary = _count(vs, false)
						ng += int(k["g"])
						nc += int(k["c"])
			if id == &"gallery_night":
				nc += mini(int(fixed["patrons"]), int(v.get(&"patrons", 0)))
			for pair: Array in [[g, ng], [c, nc]]:
				var acc: Array = pair[0]
				acc[0] = mini(int(acc[0]), int(pair[1]))
				acc[1] = maxi(int(acc[1]), int(pair[1]))
				acc[2] = float(acc[2]) + float(pair[1])
		g[2] = float(g[2]) / RUNS
		c[2] = float(c[2]) / RUNS
		out[d] = {"g": g, "c": c}
	return out


## Spawned-at-load guards / civilians under `root` (patrons counted apart when `split_patrons`).
func _count(root: Node, split_patrons: bool) -> Dictionary:
	var out: Dictionary = {"g": 0, "c": 0, "patrons": 0}
	for n: Node in root.find_children("*", "SpawnPoint", true, false):
		var sp: SpawnPoint = n as SpawnPoint
		if sp.tags.has(SCRIPTED):
			continue
		if sp.kind == SpawnPoint.Kind.GUARD:
			out["g"] += 1
		elif sp.kind == SpawnPoint.Kind.CIVILIAN:
			if split_patrons and sp.tags.has(PATRON_TAG):
				out["patrons"] += 1
			else:
				out["c"] += 1
	return out


func _mean(id: StringName, d: int, k: String) -> float:
	return float(((_stats[id] as Dictionary)[d] as Dictionary)[k][2])


func test_table_logged() -> void:
	assert_eq(_maps.size(), MAPS.size(), "every map instantiates")
	for id: StringName in _stats:
		var rows: PackedStringArray = PackedStringArray()
		for d: int in range(Enums.Difficulty.CATACLYSM + 1):
			var r: Dictionary = (_stats[id] as Dictionary)[d]
			rows.append("%d: guards %d-%d (%.2f) civilians %d-%d (%.2f)" % [d, r["g"][0], r["g"][1], r["g"][2],
				r["c"][0], r["c"][1], r["c"][2]])
		Log.info(&"test", "D-130 %s | %s" % [id, " | ".join(rows)])


func test_every_tier_adds_civilians() -> void:
	for id: StringName in _stats:
		for d: int in range(Enums.Difficulty.TENSE, Enums.Difficulty.CATACLYSM + 1):
			assert_true(_mean(id, d, "c") > _mean(id, d - 1, "c") + 0.03,
				"%s: civilians grow at difficulty %d (%.2f -> %.2f)" % [id, d, _mean(id, d - 1, "c"), _mean(id, d, "c")])


## D-130 addendum (LEAD): every tier >= the previous tier and >= its pre-D-130 value, guards and civilians.
func test_never_below_previous_tier_or_pre_d130() -> void:
	for id: StringName in _stats:
		for k: String in ["g", "c"]:
			for d: int in range(Enums.Difficulty.CATACLYSM + 1):
				var m: float = _mean(id, d, k)
				var old: float = float((PRE_D130[id][k] as Array)[d])
				assert_true(m >= old - 0.005, "%s %s at %d: %.2f >= pre-D-130 %.2f" % [id, k, d, m, old])
				if d > 0:
					assert_true(m >= _mean(id, d - 1, k) - 0.005, "%s %s at %d: %.2f >= tier below" % [id, k, d, m])


func test_cataclysm_ratios() -> void:
	for id: StringName in _stats:
		var r: float = _mean(id, Enums.Difficulty.CATACLYSM, "c") / _mean(id, Enums.Difficulty.ROUTINE, "c")
		var lim: Array = CIV_RATIO[id]
		assert_true(r >= float(lim[0]) and r <= float(lim[1]),
			"%s: Cataclysm civilians >= ~+35 %% (a floor, D-130 addendum; x%.2f)" % [id, r])
	var nd: StringName = &"night_deposit"
	var rg: float = _mean(nd, Enums.Difficulty.CATACLYSM, "g") / _mean(nd, Enums.Difficulty.ROUTINE, "g")
	assert_near(rg, 1.5, 0.06, "ND: Cataclysm guards ~ +50 %% (x%.2f)" % rg)
	for d: int in range(Enums.Difficulty.TENSE, Enums.Difficulty.CATACLYSM + 1):
		assert_true(_mean(nd, d, "g") > _mean(nd, d - 1, "g") + 0.1, "ND: guards grow at difficulty %d" % d)
	var gn: StringName = &"gallery_night"
	var want: Array[int] = [2, 2, 3, 4, 5, 5]  # GN max guards (hall + rovers/smoker; lead ruling 2, gallery_night.md)
	for d: int in range(want.size()):
		assert_eq(int(((_stats[gn] as Dictionary)[d] as Dictionary)["g"][1]), want[d], "GN max guards at %d" % d)
	# SL: reception + 1-2 rovers + 0-2 extras (stair / roof watch), the pre-D-130 rows; +50 % from Hazardous (floors).
	var sl: StringName = &"shadow_ledger"
	var sl_max: Array[int] = [2, 3, 4, 4, 5, 5]
	for d2: int in range(sl_max.size()):
		assert_eq(int(((_stats[sl] as Dictionary)[d2] as Dictionary)["g"][1]), sl_max[d2], "SL max guards at %d" % d2)
	var rs: float = _mean(sl, Enums.Difficulty.CATACLYSM, "g") / _mean(sl, Enums.Difficulty.ROUTINE, "g")
	assert_true(rs >= 1.5, "SL: Cataclysm guards >= +50 %% (x%.2f)" % rs)


## The largest roll fits the pool: Cataclysm's max is reachable (the pool has that many distinct spawn points).
func test_pools_cover_the_max() -> void:
	var want: Dictionary = {&"night_deposit": [5, 3], &"gallery_night": [5, 21], &"shadow_ledger": [5, 7]}
	for id: StringName in _stats:
		var r: Dictionary = (_stats[id] as Dictionary)[Enums.Difficulty.CATACLYSM]
		assert_eq(int(r["g"][1]), int(want[id][0]), "%s: Cataclysm max guards" % id)
		assert_true(int(r["c"][1]) <= int(want[id][1]), "%s: Cataclysm max civilians %d" % [id, r["c"][1]])
