## Worker for progression_pace.gd (loaded at runtime so the autoloads exist when it compiles).
## D-148 (PO, option D) is the data now: xp_curve scale 1.0 (PD2's ~23 M) and PayoutTweak.base_xp_by_heist; "pre_d148"
## replays the old pace (scale 0.5, flat 2000 base) for the comparison in content/docs/progression_pace.md.
extends Node

## Typical clear: the heist's required bags, stealth where the mode allows it (DB is loud only), crew of 4 alive.
const HEISTS: Array[StringName] = [&"glasshouse", &"night_deposit", &"shadow_ledger", &"dockside_burn",
	&"gallery_night", &"ostrander_federal"]
const BAGS: Dictionary = {&"glasshouse": 2, &"night_deposit": 4, &"shadow_ledger": 2, &"dockside_burn": 4,
	&"gallery_night": 2, &"ostrander_federal": 6}
const STEALTH: Dictionary = {&"dockside_burn": false}
const DIFF_NAMES: Array[String] = ["routine", "tense", "hazardous", "brutal", "lethal", "cataclysm"]
## Levels that gate something: armor / weapon / mask unlock_level values (max 45) and the board's Lethal+ gate
## (70 since D-151; 80 is kept for the comparison).
const MILESTONES: Array[int] = [10, 20, 30, 45, 60, 70, 80, 100]

var _curve: XpCurveTweak = null
var _flat_base: bool = false


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var now: XpCurveTweak = load(XpCurve.DEFAULT_TWEAK_PATH) as XpCurveTweak
	var old: XpCurveTweak = now.duplicate() as XpCurveTweak
	old.scale = 0.5
	var gate: int = int((load("res://content/data/board/board_tweak.tres") as Resource).get("difficulty_min_level")[4])
	print("PACE total_xp_to_100 d148=%d pre_d148=%d lethal_gate=L%d" % [XpCurve.xp_for_level(100, now),
			XpCurve.xp_for_level(100, old), gate])
	for o: Array in [["d148", now, false], ["pre_d148", old, true]]:
		_curve = o[1]
		_flat_base = o[2]
		var tag: String = o[0]
		for d: int in range(6):
			var row: PackedStringArray = PackedStringArray()
			for h: StringName in HEISTS:
				var p: PlayerProfile = PlayerProfile.new_default()
				var xp: int = _clear(p, h, d)
				row.append("%s:%d/L%d" % [String(h).left(4), xp, XpCurve.level_for_xp(p.xp, _curve)])
			print("PACE %s first_clear d%d %s" % [tag, d, " ".join(row)])
		print("PACE %s new_player_path %s" % [tag, _path()])
		print("PACE %s milestones %s" % [tag, _milestones(gate)])
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
	var tw: PayoutTweak = (load("res://content/data/tweak/payout.tres") as PayoutTweak).duplicate()
	if _flat_base:
		tw.base_xp_by_heist = {}
	var fresh: Dictionary = HeistFreshness.evaluate(p, h)
	var payout: Dictionary = PayoutCalculator.compute(_result(h, d), null, tw, false, 0, p.banked_stealth_mult, 1.0, 0.0,
			float(fresh.get("mult", 1.0)))
	SaveService.apply_heist_payout(p, payout, func(xp: int) -> int: return XpCurve.level_for_xp(xp, _curve))
	HeistFreshness.record(p, h, true)
	return int(payout["xp_total"])


## A new player: every heist once per difficulty (GH and ND first), one difficulty up each rotation.
func _path() -> String:
	var p: PlayerProfile = PlayerProfile.new_default()
	var out: PackedStringArray = PackedStringArray()
	for d: int in range(6):
		for h: StringName in HEISTS:
			_clear(p, h, d)
		out.append("after_%s=L%d" % [DIFF_NAMES[d], p.level])
	return " ".join(out)


## Clears to each milestone level on a realistic path: one rotation each on Routine, Tense, Hazardous, then Brutal
## (Lethal / Cataclysm are board-gated at `gate`), Cataclysm once the gate opens.
func _milestones(gate: int) -> String:
	var p: PlayerProfile = PlayerProfile.new_default()
	var out: PackedStringArray = PackedStringArray()
	var next: int = 0
	for i: int in range(20000):
		var d: int = mini(i / HEISTS.size(), 3)
		if p.level >= gate:
			d = 5
		_clear(p, HEISTS[i % HEISTS.size()], d)
		while next < MILESTONES.size() and p.level >= MILESTONES[next]:
			out.append("L%d@%d" % [MILESTONES[next], i + 1])
			next += 1
		if next >= MILESTONES.size():
			break
	return " ".join(out)


## Clears from level 0 to max on difficulty `d`: rotating the six heists, or grinding OF only (freshness penalty).
func _clears_to_max(d: int, rotate: bool) -> int:
	var p: PlayerProfile = PlayerProfile.new_default()
	for i: int in range(6000):
		_clear(p, HEISTS[i % HEISTS.size()] if rotate else &"ostrander_federal", d)
		if p.level >= _curve.max_level:
			return i + 1
	return -1
