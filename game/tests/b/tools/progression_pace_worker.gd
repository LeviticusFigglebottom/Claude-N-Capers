## Worker for progression_pace.gd (loaded at runtime so the autoloads exist when it compiles).
extends Node

## Typical clear: the heist's required bags, stealth where the mode allows it (DB is loud only), crew of 4 alive.
const HEISTS: Array[StringName] = [&"glasshouse", &"night_deposit", &"shadow_ledger", &"dockside_burn",
	&"gallery_night", &"ostrander_federal"]
const BAGS: Dictionary = {&"glasshouse": 2, &"night_deposit": 4, &"shadow_ledger": 2, &"dockside_burn": 4,
	&"gallery_night": 2, &"ostrander_federal": 6}
const STEALTH: Dictionary = {&"dockside_burn": false}
const DIFF_NAMES: Array[String] = ["routine", "tense", "hazardous", "brutal", "lethal", "cataclysm"]
## Option C: heist-size base XP (S / M / L) instead of the flat 2000.
const SIZE_BASE: Dictionary = {&"glasshouse": 1500, &"night_deposit": 2000, &"shadow_ledger": 2500,
	&"dockside_burn": 2000, &"gallery_night": 2500, &"ostrander_federal": 3000}

var _curve: XpCurveTweak = null
var _xp_mults: Array[float] = []
var _size_base: bool = false


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var base_curve: XpCurveTweak = load(XpCurve.DEFAULT_TWEAK_PATH) as XpCurveTweak
	var cur_mults: Array[float] = []
	for n: String in DIFF_NAMES:
		cur_mults.append((load("res://content/data/difficulty/%s.tres" % n) as DifficultyDef).xp_mult)
	var steep: XpCurveTweak = base_curve.duplicate() as XpCurveTweak
	steep.scale = base_curve.scale * 4.0
	var pd2: XpCurveTweak = base_curve.duplicate() as XpCurveTweak
	pd2.scale = base_curve.scale * 2.0
	var options: Array = [
		["current", base_curve, cur_mults, false],
		["A_curve_x4", steep, cur_mults, false],
		["B_flatter_mults", base_curve, [1.0, 1.5, 2.25, 3.25, 4.25, 5.0] as Array[float], false],
		["C_size_and_mults", base_curve, [1.0, 1.5, 2.25, 3.25, 4.25, 5.0] as Array[float], true],
		["D_curve_x2_size", pd2, cur_mults, true],
	]
	print("PACE curve total_xp_to_100=%d (A: %d)" % [XpCurve.xp_for_level(100, base_curve), XpCurve.xp_for_level(100, steep)])
	for o: Array in options:
		_curve = o[1]
		_xp_mults = o[2]
		_size_base = o[3]
		var tag: String = o[0]
		for d: int in range(6):
			var row: PackedStringArray = PackedStringArray()
			for h: StringName in HEISTS:
				var p: PlayerProfile = PlayerProfile.new_default()
				var xp: int = _clear(p, h, d)
				row.append("%s:%d/L%d" % [String(h).left(4), xp, XpCurve.level_for_xp(p.xp, _curve)])
			print("PACE %s first_clear d%d %s" % [tag, d, " ".join(row)])
		print("PACE %s new_player_path %s" % [tag, _path()])
		for d: int in range(6):
			print("PACE %s to_max d%d rotate=%d grind_of=%d" % [tag, d, _clears_to_max(d, true), _clears_to_max(d, false)])
	get_tree().quit(0)


func _result(h: StringName, d: int) -> Dictionary:
	var loot: Array = []
	for i: int in range(int(BAGS[h])):
		loot.append({"loot_id": &"loot.cash_bricks", "value": 1000})
	var crew: Array = []
	for slot: int in range(4):
		crew.append({"slot": slot, "is_ai": slot > 0, "kills": 0, "downs": 0, "civilians_killed": 0, "in_custody": false})
	return {"heist_id": h, "success": true, "stealth": bool(STEALTH.get(h, true)), "time_s": 900.0, "difficulty": d,
		"contract_pay": 0, "loot": loot, "small_loot": 0, "crew": crew, "pagers_answered": 0}


## One clear on `p` (freshness, the stealth bank and levels as PaydayScreen applies them); returns the XP gained.
func _clear(p: PlayerProfile, h: StringName, d: int) -> int:
	var diff: DifficultyDef = (load("res://content/data/difficulty/%s.tres" % DIFF_NAMES[d]) as DifficultyDef).duplicate()
	diff.xp_mult = _xp_mults[d]
	var tw: PayoutTweak = (load("res://content/data/tweak/payout.tres") as PayoutTweak).duplicate()
	if _size_base:
		tw.base_xp_success = int(SIZE_BASE[h])
	var fresh: Dictionary = HeistFreshness.evaluate(p, h)
	var payout: Dictionary = PayoutCalculator.compute(_result(h, d), diff, tw, false, 0, p.banked_stealth_mult, 1.0, 0.0,
			float(fresh.get("mult", 1.0)))
	SaveService.apply_heist_payout(p, payout, func(xp: int) -> int: return XpCurve.level_for_xp(xp, _curve))
	HeistFreshness.record(p, h, true)
	return int(payout["xp_total"])


## A new player: every heist once on Routine (GH, ND first), then the same rotation one difficulty up, to Cataclysm.
func _path() -> String:
	var p: PlayerProfile = PlayerProfile.new_default()
	var out: PackedStringArray = PackedStringArray()
	for d: int in range(6):
		for h: StringName in HEISTS:
			_clear(p, h, d)
		out.append("after_%s=L%d" % [DIFF_NAMES[d], p.level])
	return " ".join(out)


## Clears from level 0 to max on difficulty `d`: rotating the six heists, or grinding OF only (freshness penalty).
func _clears_to_max(d: int, rotate: bool) -> int:
	var p: PlayerProfile = PlayerProfile.new_default()
	var maxl: int = _curve.max_level
	for i: int in range(5000):
		_clear(p, HEISTS[i % HEISTS.size()] if rotate else &"ostrander_federal", d)
		if p.level >= maxl:
			return i + 1
	return -1
