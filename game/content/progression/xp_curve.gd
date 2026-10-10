## Reputation level <-> XP (pd2_fidelity P1). Levels 0..max_level (100). Curve parameters are data
## (XpCurveTweak, res://content/data/tweak/xp_curve.tres); the per-level table is generated from them
## and cached. All functions take an optional tweak (tests); null = the default data file.
class_name XpCurve
extends RefCounted

const DEFAULT_TWEAK_PATH: String = "res://content/data/tweak/xp_curve.tres"

static var _default_tweak: XpCurveTweak = null
static var _cached_for: XpCurveTweak = null
## _cumulative[L] = total XP needed to reach level L from 0 (index 0 = 0).
static var _cumulative: PackedInt64Array = PackedInt64Array()


static func max_level(tweak: XpCurveTweak = null) -> int:
	return _resolve(tweak).max_level


## XP needed to go from level-1 to level (level 1..max_level); 0 outside that range.
static func step_xp(level: int, tweak: XpCurveTweak = null) -> int:
	var cum: PackedInt64Array = _table(tweak)
	if level < 1 or level >= cum.size():
		return 0
	return cum[level] - cum[level - 1]


## Total XP needed to reach `level` from 0, clamped to 0..max_level.
static func xp_for_level(level: int, tweak: XpCurveTweak = null) -> int:
	var cum: PackedInt64Array = _table(tweak)
	return cum[clampi(level, 0, cum.size() - 1)]


## Highest level whose total requirement is <= xp (0..max_level).
static func level_for_xp(xp: int, tweak: XpCurveTweak = null) -> int:
	var cum: PackedInt64Array = _table(tweak)
	var lo: int = 0
	var hi: int = cum.size() - 1
	while lo < hi:
		var mid: int = (lo + hi + 1) >> 1
		if cum[mid] <= xp:
			lo = mid
		else:
			hi = mid - 1
	return lo


## Forget the cached table (after editing the tweak resource).
static func reload() -> void:
	_default_tweak = null
	_cached_for = null
	_cumulative = PackedInt64Array()


static func _resolve(tweak: XpCurveTweak) -> XpCurveTweak:
	if tweak != null:
		return tweak
	if _default_tweak == null:
		if ResourceLoader.exists(DEFAULT_TWEAK_PATH):
			_default_tweak = load(DEFAULT_TWEAK_PATH) as XpCurveTweak
		if _default_tweak == null:
			Log.warn(&"content", "XpCurve: %s missing, using script defaults" % DEFAULT_TWEAK_PATH)
			_default_tweak = XpCurveTweak.new()
	return _default_tweak


static func _table(tweak: XpCurveTweak) -> PackedInt64Array:
	var t: XpCurveTweak = _resolve(tweak)
	if t == _cached_for and not _cumulative.is_empty():
		return _cumulative
	var cum: PackedInt64Array = PackedInt64Array()
	var n: int = maxi(t.max_level, 1)
	cum.resize(n + 1)
	cum[0] = 0
	for level: int in range(1, n + 1):
		var u: float = 0.0 if n == 1 else float(level - 1) / float(n - 1)
		var raw: float = t.first_level_xp + (t.last_level_xp - t.first_level_xp) * pow(u, t.exponent)
		cum[level] = cum[level - 1] + maxi(roundi(raw * t.scale), 1)
	_cached_for = t
	_cumulative = cum
	return cum
