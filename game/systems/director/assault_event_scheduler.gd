## PO6-17 (D-114 §5): when an RNG assault event fires and which row it is. Pure state + the RNG it is given
## (the director passes GameRng.stream(&"assault_events")), so a seed gives the same schedule and tests can run
## it over many seeds without a map. Owner: ENV A.
## Eligible time: SUSTAIN of tweak.first_event_wave, then BUILD and SUSTAIN of every later wave. The first roll
## comes first_event_delay_s of eligible time in, then one roll per roll_interval_s of eligible time. A roll:
## one randf() < chance (by difficulty), then, when it passes, a weighted pick (one randf()) among rows with
## wave >= min_wave, fired < max_per_heist (0 = no cap), cooldown_s passed since that row last fired, and a kind
## not in `blocked` (the runner blocks kinds with no usable marker). Nothing is picked while `active` >=
## max_active or within min_gap_s of the last event (the roll is still spent, so the schedule stays seeded).
class_name AssaultEventScheduler
extends RefCounted

var tweak: AssaultEventsTweak = null
var rows: Array[Dictionary] = []
var chance: float = 0.0
## Heist clock (s) since the director began.
var clock: float = 0.0
## Fires per row and the clock of each row's last fire (-INF = never).
var fired: PackedInt32Array = PackedInt32Array()
var last_fired_t: PackedFloat32Array = PackedFloat32Array()
var last_any_t: float = -INF
## Eligible seconds left to the next roll.
var roll_left: float = 0.0
var rolls: int = 0
## {t, wave, phase, row, kind} of every event fired (tests / logs).
var schedule: Array[Dictionary] = []


func setup(p_tweak: AssaultEventsTweak, p_rows: Array[Dictionary], difficulty: int) -> void:
	tweak = p_tweak
	rows = p_rows
	chance = tweak.chance_for(difficulty)
	fired = PackedInt32Array()
	fired.resize(rows.size())
	last_fired_t = PackedFloat32Array()
	for i: int in range(rows.size()):
		last_fired_t.append(-INF)
	roll_left = tweak.first_event_delay_s
	clock = 0.0
	last_any_t = -INF
	rolls = 0
	schedule.clear()


static func eligible(tw: AssaultEventsTweak, phase: int, wave: int) -> bool:
	if wave == tw.first_event_wave:
		return phase == Enums.AssaultPhase.SUSTAIN
	return wave > tw.first_event_wave and (phase == Enums.AssaultPhase.BUILD or phase == Enums.AssaultPhase.SUSTAIN)


## Advance by `delta`; returns the index of the row to run now, or -1.
func tick(delta: float, phase: int, wave: int, active: int, rng: RandomNumberGenerator,
		blocked: Array[StringName] = []) -> int:
	clock += delta
	if rows.is_empty() or not eligible(tweak, phase, wave):
		return -1
	roll_left -= delta
	if roll_left > 0.0:
		return -1
	roll_left = tweak.roll_interval_s
	rolls += 1
	if rng.randf() >= chance:
		return -1
	if active >= tweak.max_active or clock - last_any_t < tweak.min_gap_s:
		return -1
	var i: int = pick_row(rng, rows, wave, clock, fired, last_fired_t, blocked)
	if i < 0:
		return -1
	fired[i] += 1
	last_fired_t[i] = clock
	last_any_t = clock
	schedule.append({"t": clock, "wave": wave, "phase": phase, "row": i, "kind": StringName(rows[i].get("kind", &""))})
	return i


## Row eligible at `wave` / `now` (min_wave, max_per_heist, cooldown_s, not blocked).
static func row_allowed(row: Dictionary, i: int, wave: int, now: float, fired_n: PackedInt32Array,
		last_t: PackedFloat32Array, blocked: Array[StringName]) -> bool:
	if float(row.get("weight", 0.0)) <= 0.0 or wave < int(row.get("min_wave", 1)):
		return false
	if blocked.has(StringName(row.get("kind", &""))):
		return false
	var cap: int = int(row.get("max_per_heist", 0))
	if cap > 0 and fired_n[i] >= cap:
		return false
	return now - last_t[i] >= float(row.get("cooldown_s", 0.0))


## Weighted pick among the allowed rows (one rng.randf() when any is allowed); -1 when none.
static func pick_row(rng: RandomNumberGenerator, p_rows: Array[Dictionary], wave: int, now: float,
		fired_n: PackedInt32Array, last_t: PackedFloat32Array, blocked: Array[StringName] = []) -> int:
	var cands: Array[int] = []
	var total: float = 0.0
	for i: int in range(p_rows.size()):
		if row_allowed(p_rows[i], i, wave, now, fired_n, last_t, blocked):
			cands.append(i)
			total += float(p_rows[i].get("weight", 0.0))
	if cands.is_empty():
		return -1
	var r: float = rng.randf() * total
	for i: int in cands:
		r -= float(p_rows[i].get("weight", 0.0))
		if r <= 0.0:
			return i
	return cands[cands.size() - 1]
