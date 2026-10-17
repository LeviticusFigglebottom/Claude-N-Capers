## D-140 (PO-15, revised 12:25): a stealth heist can't be beaten by killing every guard (Golden Hour exempt). Pager carriers
## at load = role guard (guards, the camera operator, escorts), on 3 seeds at every difficulty:
## (a) Routine: pager cap 4, guards <= 4;
## (b) one lever per map from Tense: GUARDS maps (GN; OF once G1 lands) keep cap 4 everywhere and raise guards to the table
##     minimum; PAGERS maps (ND, SL) have exactly 4 guards on every difficulty and seed and drop the cap to the table;
## (c) from Tense, guards > cap on every seed (a rolled pager_max_answers scalar only lowers the cap; cap_for includes it).
extends TestCase

const SEEDS: Array[int] = [11, 21, 1792002290]
const PAGERS_CAP: Array = [4, 3, 3, 2, 2, 1]
const PAGERS_GUARDS: int = 4
## GUARDS maps: minimum guards per difficulty (Routine .. Cataclysm).
const GUARDS_MIN: Dictionary = {&"gallery_night": [4, 5, 5, 6, 6, 7]}
const PAGERS_MAPS: Array[StringName] = [&"night_deposit", &"shadow_ledger"]

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func test_d140_night_deposit_pagers_lever() -> void:
	await _check(&"night_deposit")


func test_d140_shadow_ledger_pagers_lever() -> void:
	await _check(&"shadow_ledger")


func test_d140_gallery_night_guards_lever() -> void:
	await _check(&"gallery_night")


func _check(heist: StringName) -> void:
	var pagers: bool = PAGERS_MAPS.has(heist)
	var guards: Dictionary = {}
	for sd: int in SEEDS:
		guards[sd] = []
	for diff: int in Enums.Difficulty.values():
		for sd: int in SEEDS:
			_rt = await HeistLauncher.launch(heist, sd, diff, self, {"crew_ai": false, "ai_teammates": 0})
			await wait_physics_frames(2)
			var g: int = _rt.npcs(&"guard").size()
			var cap: int = PagerSystem.cap_for(_rt)
			_rt.teardown()
			_rt = null
			await wait_frames(2)
			var label: String = "%s seed %d difficulty %d" % [heist, sd, diff]
			print("[d140] %s: %d guards, cap %d" % [label, g, cap])
			(guards[sd] as Array).append(g)
			if diff == Enums.Difficulty.ROUTINE:
				assert_eq(cap, 4, "%s: (a) Routine cap 4" % label)
				assert_true(g <= 4, "%s: (a) Routine guards %d <= 4" % [label, g])
			else:
				assert_true(g > cap, "%s: (c) guards %d > cap %d" % [label, g, cap])
			if pagers:
				assert_eq(cap, int(PAGERS_CAP[diff]), "%s: (b) PAGERS cap" % label)
				assert_eq(g, PAGERS_GUARDS, "%s: (b) PAGERS map has exactly %d guards" % [label, PAGERS_GUARDS])
			else:
				assert_eq(cap, 4, "%s: (b) GUARDS map keeps cap 4" % label)
	for sd: int in SEEDS:
		var row: Array = guards[sd]
		if pagers:
			assert_true(row.all(func(x: int) -> bool: return x == int(row[0])), "%s seed %d: (b) PAGERS guards fixed %s" % [
				heist, sd, row])
	if not pagers:
		var want: Array = GUARDS_MIN[heist]
		for diff: int in Enums.Difficulty.values():
			var lo: int = 1 << 20
			for sd: int in SEEDS:
				lo = mini(lo, int((guards[sd] as Array)[diff]))
			assert_true(lo >= int(want[diff]), "%s difficulty %d: (b) min guards %d >= %d" % [heist, diff, lo, want[diff]])
