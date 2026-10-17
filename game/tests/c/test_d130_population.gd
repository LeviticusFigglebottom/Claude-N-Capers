## D-130 §1 / D-140: stealth population by difficulty on the M heists (Gallery Night, Night Deposit, Shadow Ledger).
## Owner: ENV C (the map-side pin; ENV A has its own D-140 runtime test).
## Rolls each map's real variant table on its real VariantSlots (VariantResolver, many seeds) and counts what
## HeistRuntime / the CameraStation would spawn at load:
##   guards (D-140) = pager carriers: GUARD SpawnPoints outside any slot plus those inside the active slots, plus (ND, GN) the
##     CAMERA_OPERATOR seat when the security room is staffed (CameraStation.room_staffed); `scripted` rare-event /
##     timed spawns are not counted;
##   civilians (D-130) = CIVILIAN SpawnPoints the same way; GN keeps the first `patrons` civ_patron spawns (the
##     mission's thin_civilians) and counts the gala, before last call.
## Pins: D-140 (revised 12:25): Routine has <= 4 guards and a pager cap of 4 everywhere; from Tense up each map moves ONE
## lever: GUARDS maps (GN) keep the cap at 4 and reach the per-tier guard minimums; PAGERS maps (ND, SL) hold exactly 4
## guards on every seed and difficulty while HeistDef.pager_max_by_difficulty falls; from Tense the guards outnumber the
## cap on every seed. D-130: every tier adds civilians (expected count), never below the tier below or the pre-D-130
## count (addendum; guards too on a GUARDS map), Cataclysm / Routine civilians >= +35 % (a floor), and each map's pool
## covers the largest roll.
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
## D-140 per-heist table (decisions.md, revised 12:25), Routine..Cataclysm: lever, guards (GUARDS: the minimum over
## seeds; PAGERS: exact on every seed), pager cap (HeistDef.pager_max_by_difficulty; empty = 4).
const GUARDS_LEVER: StringName = &"guards"
const PAGERS_LEVER: StringName = &"pagers"
const ROUTINE_CAP: int = 4
## "operator": the CAMERA_OPERATOR seat counts as a guard when the room is staffed. ND / GN pair the operator with a
## sec_empty roundsman (SL: with a stair or roof watch post), so the room always holds exactly one pager.
const D140: Dictionary = {
	&"gallery_night": {"lever": GUARDS_LEVER, "guards": [4, 5, 5, 6, 6, 7], "cap": [4, 4, 4, 4, 4, 4], "operator": true},
	&"night_deposit": {"lever": PAGERS_LEVER, "guards": [4, 4, 4, 4, 4, 4], "cap": [4, 3, 3, 2, 2, 1], "operator": true},
	&"shadow_ledger": {"lever": PAGERS_LEVER, "guards": [4, 4, 4, 4, 4, 4], "cap": [4, 3, 3, 2, 2, 1], "operator": true},
}

## Expected counts per tier before D-130 (ROUTINE..CATACLYSM; same seeds, the a5b797f8 variant tables; SL: the 708a9cd1
## table, measured before its D-130 rows): D-130 counts never fall below them (LEAD, D-130 addendum). The guard rows
## (counted then without the operator) bind GUARDS-lever maps only: D-140 fixes a PAGERS map's guards at 4.
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
			var staffed: bool = bool((D140[id] as Dictionary)["operator"]) and CameraStation.room_staffed(v)
			if staffed:
				ng += int(fixed["op"])
			for group: Variant in slots:
				for vs: VariantSlot in slots[group]:
					if (v.get(group, []) as Array).has(vs.slot_id):
						var k: Dictionary = _count(vs, false)
						ng += int(k["g"]) + (int(k["op"]) if staffed else 0)
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


## Spawned-at-load guards / camera-operator seats / civilians under `root` (patrons apart when `split_patrons`).
func _count(root: Node, split_patrons: bool) -> Dictionary:
	var out: Dictionary = {"g": 0, "op": 0, "c": 0, "patrons": 0}
	for n: Node in root.find_children("*", "SpawnPoint", true, false):
		var sp: SpawnPoint = n as SpawnPoint
		if sp.tags.has(SCRIPTED):
			continue
		if sp.kind == SpawnPoint.Kind.GUARD:
			out["g"] += 1
		elif sp.kind == SpawnPoint.Kind.CAMERA_OPERATOR:
			out["op"] += 1
		elif sp.kind == SpawnPoint.Kind.CIVILIAN:
			if split_patrons and sp.tags.has(PATRON_TAG):
				out["patrons"] += 1
			else:
				out["c"] += 1
	return out


func _row(id: StringName, d: int, k: String) -> Array:
	return ((_stats[id] as Dictionary)[d] as Dictionary)[k]


func _mean(id: StringName, d: int, k: String) -> float:
	return float(_row(id, d, k)[2])


## The run's pager cap as PagerSystem.cap_for reads it (no rolled scalar: none of these tables defines one).
func _cap(id: StringName, d: int) -> int:
	var def: HeistDef = (_maps[id] as HeistMap).heist_def
	if def == null or def.pager_max_by_difficulty.is_empty():
		return ROUTINE_CAP
	return def.pager_max_by_difficulty[clampi(d, 0, def.pager_max_by_difficulty.size() - 1)]


func test_table_logged() -> void:
	assert_eq(_maps.size(), MAPS.size(), "every map instantiates")
	for id: StringName in _stats:
		var rows: PackedStringArray = PackedStringArray()
		for d: int in range(Enums.Difficulty.CATACLYSM + 1):
			var g: Array = _row(id, d, "g")
			var c: Array = _row(id, d, "c")
			rows.append("%d: guards %d-%d (%.2f) cap %d civilians %d-%d (%.2f)" % [d, g[0], g[1], g[2], _cap(id, d),
				c[0], c[1], c[2]])
		Log.info(&"test", "D-130/D-140 %s | %s" % [id, " | ".join(rows)])


## D-140 (a)-(c): Routine <= 4 guards with 4 pagers; one lever per map from Tense; guards > cap from Tense, every seed.
func test_d140_guards_and_pager_caps() -> void:
	for id: StringName in _stats:
		var t: Dictionary = D140[id]
		var lever: StringName = t["lever"]
		var for_rows: Array = t["guards"]
		for d: int in range(Enums.Difficulty.CATACLYSM + 1):
			var g: Array = _row(id, d, "g")
			var want: int = int(for_rows[d])
			assert_eq(_cap(id, d), int((t["cap"] as Array)[d]), "%s: pager cap at %d" % [id, d])
			if lever == GUARDS_LEVER:
				assert_true(int(g[0]) >= want, "%s: min guards at %d is %d (>= %d)" % [id, d, g[0], want])
				assert_eq(_cap(id, d), ROUTINE_CAP, "%s (GUARDS lever): the cap stays 4 at %d" % [id, d])
			else:
				assert_true(int(g[0]) == want and int(g[1]) == want,
					"%s (PAGERS lever): exactly %d guards at %d on every seed (%d-%d)" % [id, want, d, g[0], g[1]])
			if d == Enums.Difficulty.ROUTINE:
				assert_true(int(g[1]) <= ROUTINE_CAP, "%s: Routine max guards %d <= 4" % [id, g[1]])
				assert_eq(_cap(id, d), ROUTINE_CAP, "%s: Routine pager cap 4" % id)
			else:
				assert_true(int(g[0]) > _cap(id, d),
					"%s: from Tense guards > cap on every seed at %d (min %d, cap %d)" % [id, d, g[0], _cap(id, d)])
		var scalars: Array = (_maps[id] as HeistMap).variant_table.scalars
		for sc: Dictionary in scalars:
			assert_false(StringName(sc.get("id", &"")) == PagerSystem.MAX_ANSWERS_SCALAR,
				"%s: no rolled pager_max_answers scalar (D-140 (c))" % id)


func test_every_tier_adds_civilians() -> void:
	for id: StringName in _stats:
		for d: int in range(Enums.Difficulty.TENSE, Enums.Difficulty.CATACLYSM + 1):
			assert_true(_mean(id, d, "c") > _mean(id, d - 1, "c") + 0.03,
				"%s: civilians grow at difficulty %d (%.2f -> %.2f)" % [id, d, _mean(id, d - 1, "c"), _mean(id, d, "c")])


## D-130 addendum (LEAD): every tier >= the previous tier and >= its pre-D-130 value: civilians everywhere, guards on a
## GUARDS-lever map (a PAGERS map's guards are fixed at 4 by D-140).
func test_never_below_previous_tier_or_pre_d130() -> void:
	for id: StringName in _stats:
		var kinds: Array[String] = ["c"]
		if StringName((D140[id] as Dictionary)["lever"]) == GUARDS_LEVER:
			kinds.append("g")
		for k: String in kinds:
			for d: int in range(Enums.Difficulty.CATACLYSM + 1):
				var m: float = _mean(id, d, k)
				var old: float = float((PRE_D130[id][k] as Array)[d])
				assert_true(m >= old - 0.005, "%s %s at %d: %.2f >= pre-D-130 %.2f" % [id, k, d, m, old])
				if d > 0:
					assert_true(m >= _mean(id, d - 1, k) - 0.005, "%s %s at %d: %.2f >= tier below" % [id, k, d, m])


func test_cataclysm_civilian_ratios() -> void:
	for id: StringName in _stats:
		var r: float = _mean(id, Enums.Difficulty.CATACLYSM, "c") / _mean(id, Enums.Difficulty.ROUTINE, "c")
		var lim: Array = CIV_RATIO[id]
		assert_true(r >= float(lim[0]) and r <= float(lim[1]),
			"%s: Cataclysm civilians >= ~+35 %% (a floor, D-130 addendum; x%.2f)" % [id, r])


## The largest roll fits the pool: Cataclysm's max is reachable (the pool has that many distinct spawn points).
func test_pools_cover_the_max() -> void:
	var want: Dictionary = {&"night_deposit": [4, 3], &"gallery_night": [7, 21], &"shadow_ledger": [4, 7]}
	for id: StringName in _stats:
		var g: Array = _row(id, Enums.Difficulty.CATACLYSM, "g")
		var c: Array = _row(id, Enums.Difficulty.CATACLYSM, "c")
		assert_eq(int(g[1]), int(want[id][0]), "%s: Cataclysm max guards" % id)
		assert_true(int(c[1]) <= int(want[id][1]), "%s: Cataclysm max civilians %d" % [id, c[1]])
