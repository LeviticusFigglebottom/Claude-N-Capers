## D-130 §1: stealth population by difficulty on the M heists (Gallery Night, Night Deposit). Owner: ENV C.
## Rolls each map's real variant table on its real VariantSlots (VariantResolver, many seeds) and counts the guards and
## civilians that HeistRuntime would spawn at load: GUARD / CIVILIAN SpawnPoints outside any slot plus those inside
## the active slots (no `scripted` rare-event spawns; the camera operator is not counted). GN keeps the first `patrons`
## civ_patron spawns (the mission's thin_civilians) and counts the gala, before last call.
## Pins: every tier adds civilians (expected count), the Cataclysm / Routine ratios D-130 asks for (+35 % civilians
## on both; +50 % guards on ND; GN's guards keep their steeper lead-ruling curve, 1-2 / 1-2 / 3 / 4 / 5 / 5), and
## that each map's spawn pool covers the largest roll.
## Design: docs/design/heists/night_deposit.md, gallery_night.md (§roster "Totals per difficulty").
extends TestCase

const MAPS: Dictionary = {
	&"night_deposit": "res://world/heists/night_deposit/night_deposit.tscn",
	&"gallery_night": "res://world/heists/gallery_night/gallery_night.tscn",
}
const RUNS: int = 1500
const SCRIPTED: StringName = &"scripted"
const PATRON_TAG: StringName = &"civ_patron"

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
	assert_eq(_maps.size(), MAPS.size(), "both maps instantiate")
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


func test_cataclysm_ratios() -> void:
	for id: StringName in _stats:
		var r: float = _mean(id, Enums.Difficulty.CATACLYSM, "c") / _mean(id, Enums.Difficulty.ROUTINE, "c")
		assert_near(r, 1.35, 0.06, "%s: Cataclysm civilians ~ +35 %% (x%.2f)" % [id, r])
	var nd: StringName = &"night_deposit"
	var rg: float = _mean(nd, Enums.Difficulty.CATACLYSM, "g") / _mean(nd, Enums.Difficulty.ROUTINE, "g")
	assert_near(rg, 1.5, 0.06, "ND: Cataclysm guards ~ +50 %% (x%.2f)" % rg)
	for d: int in range(Enums.Difficulty.TENSE, Enums.Difficulty.CATACLYSM + 1):
		assert_true(_mean(nd, d, "g") > _mean(nd, d - 1, "g") + 0.1, "ND: guards grow at difficulty %d" % d)
	var gn: StringName = &"gallery_night"
	var want: Array[int] = [2, 2, 3, 4, 5, 5]  # GN max guards (hall + rovers/smoker; lead ruling 2, gallery_night.md)
	for d: int in range(want.size()):
		assert_eq(int(((_stats[gn] as Dictionary)[d] as Dictionary)["g"][1]), want[d], "GN max guards at %d" % d)


## The largest roll fits the pool: Cataclysm's max is reachable (the pool has that many distinct spawn points).
func test_pools_cover_the_max() -> void:
	var want: Dictionary = {&"night_deposit": [5, 3], &"gallery_night": [5, 21]}
	for id: StringName in _stats:
		var r: Dictionary = (_stats[id] as Dictionary)[Enums.Difficulty.CATACLYSM]
		assert_eq(int(r["g"][1]), int(want[id][0]), "%s: Cataclysm max guards" % id)
		assert_true(int(r["c"][1]) <= int(want[id][1]), "%s: Cataclysm max civilians %d" % [id, r["c"][1]])
