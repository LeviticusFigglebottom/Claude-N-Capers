## Per-crew heist stats: one row per crew member, AI included (B6-02; content/docs/scoreboard.md). Owner: ENV B.
## Pure helpers shared by the Tab scoreboard (rows of LocalHudModel.crew_stats) and the payday awards
## (rows of HeistResult.crew, contracts/events.md). Row keys are Strings, named as in HeistResult:
##   slot, name, is_ai, is_local, kills, specials_killed, civilians_killed, downs, shots, hits, headshots.
## Any counter may be MISSING from a row (shots / hits / headshots do not exist in ENV A yet): callers
## check has_stat() per row and show "—" / skip the award instead of reading a zero.
## `accuracy` is derived: hits / shots, defined only when both counters exist and shots > 0.
class_name CrewStats
extends RefCounted

const KILLS: StringName = &"kills"
const SPECIALS: StringName = &"specials_killed"
const CIVILIANS: StringName = &"civilians_killed"
const DOWNS: StringName = &"downs"
const SHOTS: StringName = &"shots"
const HITS: StringName = &"hits"
const HEADSHOTS: StringName = &"headshots"
## Derived stat (hits / shots, 0..1).
const ACCURACY: StringName = &"accuracy"
## Stats an award or a scoreboard column may name.
const STATS: Array[StringName] = [KILLS, SPECIALS, CIVILIANS, DOWNS, SHOTS, HITS, HEADSHOTS, ACCURACY]


## True when `row` carries `stat` (accuracy: shots and hits present and shots > 0).
static func has_stat(row: Dictionary, stat: StringName) -> bool:
	if stat == ACCURACY:
		return _has(row, SHOTS) and _has(row, HITS) and _num(row, SHOTS) > 0.0
	return _has(row, stat)


## The value of `stat` in `row` (accuracy 0..1); 0.0 when missing (check has_stat first).
static func value(row: Dictionary, stat: StringName) -> float:
	if not has_stat(row, stat):
		return 0.0
	if stat == ACCURACY:
		return clampf(_num(row, HITS) / _num(row, SHOTS), 0.0, 1.0)
	return _num(row, stat)


## Accuracy as a whole percentage, or -1 when it is not defined for `row`.
static func accuracy_pct(row: Dictionary) -> int:
	return roundi(value(row, ACCURACY) * 100.0) if has_stat(row, ACCURACY) else -1


static func slot_of(row: Dictionary) -> int:
	return int(row.get("slot", -1))


static func is_ai(row: Dictionary) -> bool:
	return bool(row.get("is_ai", false))


## Rows ordered by crew slot (a copy; the input is untouched).
static func by_slot(rows: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Variant in rows:
		if r is Dictionary:
			out.append(r as Dictionary)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return slot_of(a) < slot_of(b))
	return out


static func _has(row: Dictionary, stat: StringName) -> bool:
	var v: Variant = row.get(String(stat))
	return v is int or v is float


static func _num(row: Dictionary, stat: StringName) -> float:
	return float(row.get(String(stat), 0))
