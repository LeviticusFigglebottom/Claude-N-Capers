## D-139 heist freshness (PO): a repeat penalty and a rotation bonus, per player, on money and XP. Owner: ENV B.
## State: PlayerProfile.freshness (save v9) =
##   {"recent": [heist_id, ...] (the last PayoutTweak.freshness_memory runs that reached payday, oldest first),
##    "runs": int (runs counted so far), "last_run": {heist_id: the "runs" value of its last run},
##    "completed": [heist_id, ...] (won at least once)}
## evaluate(p, heist) is read BEFORE this run is recorded (n never counts this run); record(p, heist, success) runs once
## per shown payday (PaydayScreen._apply), success or failure. A menu abort or a disconnect never reaches payday.
##   n = times `heist` is in "recent": n >= 1 -> mult = max(1 - repeat_step x n, repeat_floor)            ("repeat")
##   n = 0 and completed: since = runs - last_run (runs played since it); k = max(since - memory, 0)
##     -> mult = 1 + min(rotation_step x k, rotation_cap)                                                  ("rotation")
##   never completed (or no data): 1.0                                                                       ("none")
## A completed heist with no last_run (seeded by the v8 -> v9 migration) counts as run at 0, so its bonus ramps
## from the migration on instead of granting the full +10 % at once.
class_name HeistFreshness
extends RefCounted

const KIND_NONE: StringName = &"none"
const KIND_REPEAT: StringName = &"repeat"
const KIND_ROTATION: StringName = &"rotation"


static func empty() -> Dictionary:
	return {"recent": [], "runs": 0, "last_run": {}, "completed": []}


## {"mult": float, "kind": StringName, "n": int (times in the memory), "since": int (runs since its last run, -1 =
## never run), "k": int (runs since it left the memory)} for `heist_id` now.
static func evaluate(p: PlayerProfile, heist_id: StringName, tw: PayoutTweak = null) -> Dictionary:
	var t: PayoutTweak = tw if tw != null else PayoutCalculator._load_tweak()
	var out: Dictionary = {"mult": 1.0, "kind": KIND_NONE, "n": 0, "since": -1, "k": 0}
	if p == null or heist_id == &"":
		return out
	var f: Dictionary = state(p)
	var key: String = String(heist_id)
	var n: int = 0
	for id: Variant in f["recent"] as Array:
		n += int(String(id) == key)
	out["n"] = n
	var last: Dictionary = f["last_run"] as Dictionary
	var completed: bool = (f["completed"] as Array).has(key)
	if last.has(key) or completed:
		out["since"] = int(f["runs"]) - int(last.get(key, 0))
	if n >= 1:
		out["mult"] = maxf(1.0 - t.repeat_step * float(n), t.repeat_floor)
		out["kind"] = KIND_REPEAT
	elif completed:
		var k: int = maxi(int(out["since"]) - t.freshness_memory, 0)
		out["k"] = k
		out["mult"] = 1.0 + minf(t.rotation_step * float(k), t.rotation_cap)
		out["kind"] = KIND_ROTATION if k > 0 else KIND_NONE
	return out


## Banks one run that reached payday into `p.freshness` (after its payout was computed).
static func record(p: PlayerProfile, heist_id: StringName, success: bool, tw: PayoutTweak = null) -> void:
	if p == null or heist_id == &"":
		return
	var t: PayoutTweak = tw if tw != null else PayoutCalculator._load_tweak()
	var f: Dictionary = state(p)
	var key: String = String(heist_id)
	f["runs"] = int(f["runs"]) + 1
	var recent: Array = f["recent"] as Array
	recent.append(key)
	while recent.size() > maxi(t.freshness_memory, 0):
		recent.remove_at(0)
	(f["last_run"] as Dictionary)[key] = int(f["runs"])
	if success and not (f["completed"] as Array).has(key):
		(f["completed"] as Array).append(key)


## The profile's freshness dict, repaired to the full shape (keys present, ids as Strings).
static func state(p: PlayerProfile) -> Dictionary:
	var f: Dictionary = p.freshness
	if not f.get("recent") is Array:
		f["recent"] = []
	if not (f.get("runs") is int or f.get("runs") is float):
		f["runs"] = 0
	f["runs"] = int(f["runs"])
	if not f.get("last_run") is Dictionary:
		f["last_run"] = {}
	if not f.get("completed") is Array:
		f["completed"] = []
	return f


## Signed percent for the UI (+5 / -20 / 0).
static func percent(mult: float) -> int:
	return roundi((mult - 1.0) * 100.0)


## "+5 %" / "-20 %" (UiText's signed percent), "" for 1.0.
static func badge_text(mult: float) -> String:
	var pct: int = percent(mult)
	if pct == 0:
		return ""
	return UiText.t(&"ui.freshness.badge", {"pct": ("+%d" % pct) if pct > 0 else ("%d" % pct)})


## The one-line reason ("played 3x in your last 10 heists" / "not played in 17 heists"), "" for none.
static func reason_text(ev: Dictionary, tw: PayoutTweak = null) -> String:
	var t: PayoutTweak = tw if tw != null else PayoutCalculator._load_tweak()
	match StringName(ev.get("kind", KIND_NONE)):
		KIND_REPEAT:
			return UiText.t(&"ui.freshness.reason_repeat", {"n": int(ev.get("n", 0)), "memory": t.freshness_memory})
		KIND_ROTATION:
			return UiText.t(&"ui.freshness.reason_rotation", {"since": int(ev.get("since", 0))})
	return ""
