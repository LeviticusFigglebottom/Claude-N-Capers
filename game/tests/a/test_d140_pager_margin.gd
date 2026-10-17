## D-140 (PO-15): a stealth heist can't be beaten by killing every guard. For Night Deposit, Gallery Night and Shadow
## Ledger (Ostrander Federal once G1 lands): pager carriers at load (role guard: guards, the camera operator, escorts; the
## minimum over seeds) are >= the per-heist table (>= 5 everywhere), the pager cap is the table (4 on Routine), and from
## Tense up guards > cap on every seed. Golden Hour is exempt (D-130). Skipped per heist until ENV C's D-140 rows are on
## the map (its def carries the D-140 pager_max_by_difficulty).
extends TestCase

const SEEDS: Array[int] = [11, 21, 1792002290]
## heist -> [guards min per difficulty, pager cap per difficulty] (Routine .. Cataclysm).
const TABLE: Dictionary = {
	&"night_deposit": [[5, 5, 5, 6, 6, 7], [4, 4, 3, 3, 2, 2]],
	&"gallery_night": [[5, 5, 6, 6, 7, 8], [4, 4, 4, 3, 3, 2]],
	&"shadow_ledger": [[5, 5, 6, 6, 7, 8], [4, 4, 4, 3, 3, 2]],
}

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func test_d140_night_deposit() -> void:
	await _check(&"night_deposit")


func test_d140_gallery_night() -> void:
	await _check(&"gallery_night")


func test_d140_shadow_ledger() -> void:
	await _check(&"shadow_ledger")


func _check(heist: StringName) -> void:
	var want_g: Array = (TABLE[heist] as Array)[0]
	var want_cap: Array = (TABLE[heist] as Array)[1]
	var def: HeistDef = null
	for diff: int in Enums.Difficulty.values():
		var min_g: int = 1 << 20
		for sd: int in SEEDS:
			_rt = await HeistLauncher.launch(heist, sd, diff, self, {"crew_ai": false, "ai_teammates": 0})
			await wait_physics_frames(2)
			if def == null:
				def = _rt.map.heist_def
			if def == null or Array(def.pager_max_by_difficulty) != want_cap:
				_rt.teardown()
				_rt = null
				skip("pending ENV C's D-140 rows for %s (pager_max_by_difficulty %s)" % [heist,
					def.pager_max_by_difficulty if def != null else "none"])
				return
			var g: int = _rt.npcs(&"guard").size()
			var cap: int = PagerSystem.cap_for(_rt)
			var label: String = "%s seed %d difficulty %d" % [heist, sd, diff]
			print("[d140] %s: %d guards, cap %d" % [label, g, cap])
			assert_eq(cap, int(want_cap[diff]), "%s: pager cap" % label)
			if diff >= Enums.Difficulty.TENSE:
				assert_true(g > cap, "%s: guards %d > cap %d" % [label, g, cap])
			min_g = mini(min_g, g)
			_rt.teardown()
			_rt = null
			await wait_frames(2)
		assert_true(min_g >= int(want_g[diff]) and min_g >= 5, "%s difficulty %d: min guards %d >= %d" % [heist, diff, min_g,
			want_g[diff]])
