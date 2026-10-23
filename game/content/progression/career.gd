## Lifetime career stats (B7-01). Owner: ENV B. Static. State: PlayerProfile.career (save v7).
##
## Shape (JSON; every counter is an int >= 0; a MISSING key means "never counted", not 0):
##   {"totals": {key: int}, "heists": {heist_id: {key: int}}, "difficulties": {"<Enums.Difficulty>": {key: int}},
##    "bags": {loot_id: int}, "weapons": {weapon_id: int}}
## Sources (only what the payday path actually carries; content/docs/save_format.md "career"):
##   * HeistResult (contracts/events.md v1.1): heist_id, success, stealth, difficulty, time_s, loot (secured
##     bags, counted on a success only), crew row of the local slot: kills, specials_killed,
##     civilians_killed, downs, in_custody, and shots / hits / headshots (D-071). A crew counter the row does
##     not carry is NOT counted (the total key stays absent), so accuracy is shown only when shots exist.
##   * PayoutCalculator output: spending, stash, small_loot (cash actually paid), xp_total.
##   * Spending: add_spent() from the workshop buys, pre-planning (refunds pass a negative amount), the
##     Notoriety rank-up cost (spending cash) and the Board broker (offshore, OFFSHORE_SPENT).
##   * Weapons: the profile loadout's primary / secondary at payday (heists carried, not kills: the
##     HeistResult has no per-weapon data). favourite_weapon() = most carried.
##   * Payday cards (record_card, after PaydayCards.grant): card_cash / card_xp amounts, cards_taken.
##   * Last Breath (One Down, C4): MenuFlow's contract flag via PaydayScreen.last_breath -> LAST_BREATH_WINS.
## TODO (no source yet): per-weapon kills, melee / throwable kills, pagers answered per player, time spent in menus.
class_name Career
extends RefCounted

const SECTIONS: Array[String] = ["totals", "heists", "difficulties", "bags", "weapons"]
## Totals keys.
const PLAYED: String = "played"
const WON: String = "won"
const FAILED: String = "failed"
const STEALTH_WINS: String = "stealth_wins"
const LOUD_WINS: String = "loud_wins"
const SPENDING_EARNED: String = "spending_earned"
const STASH_EARNED: String = "stash_earned"
const XP_EARNED: String = "xp_earned"
const SMALL_LOOT: String = "small_loot"
const BAGS: String = "bags"
const CASH_SPENT: String = "cash_spent"
const OFFSHORE_SPENT: String = "offshore_spent"
const CUSTODY: String = "custody"
const TIME_PLAYED_S: String = "time_played_s"
## Payday cards: cash and XP from picked cards (not a heist payout), and how many cards were taken.
const CARD_CASH: String = "card_cash"
const CARD_XP: String = "card_xp"
const CARDS_TAKEN: String = "cards_taken"
## Wins with the Last Breath toggle on (totals and per heist).
const LAST_BREATH_WINS: String = "last_breath_wins"
## Per-heist keys (besides played / won / failed / stealth_wins / loud_wins).
const FASTEST_WIN_MS: String = "fastest_win_ms"
## "won_d<difficulty>": wins of that heist on that difficulty.
const WON_ON_FMT: String = "won_d%d"
## Crew row counters copied into totals when the row carries them (v1.0 + v1.1 D-071).
const CREW_COUNTERS: Array[String] = ["kills", "specials_killed", "civilians_killed", "downs", "shots", "hits", "headshots"]


## A fresh career (every section empty).
static func empty() -> Dictionary:
	var out: Dictionary = {}
	for s: String in SECTIONS:
		out[s] = {}
	return out


## Banks one payday into p.career. `crew_slot` = the local player's HeistResult crew row (-1 / missing =
## no combat counters). Call once per shown result (PaydayScreen._apply, before Achievements.on_payday).
## `last_breath` = the run had Last Breath on (HeistResult does not carry it).
static func record(p: PlayerProfile, result: Dictionary, payout: Dictionary, crew_slot: int,
		last_breath: bool = false) -> void:
	if p == null:
		return
	_ensure(p)
	var success: bool = bool(payout.get("success", result.get("success", false)))
	var stealth: bool = bool(result.get("stealth", false))
	var heist: String = String(result.get("heist_id", ""))
	var diff: int = int(result.get("difficulty", 0))
	var outcome: Array[String] = [PLAYED, WON if success else FAILED]
	if success:
		outcome.append(STEALTH_WINS if stealth else LOUD_WINS)
	for k: String in outcome:
		_add(p, "totals", k, 1)
		if heist != "":
			_add_heist(p, heist, k, 1)
		if k != STEALTH_WINS and k != LOUD_WINS:
			_add_diff(p, diff, k, 1)
	if success and heist != "":
		_add_heist(p, heist, WON_ON_FMT % diff, 1)
	if success and last_breath:
		_add(p, "totals", LAST_BREATH_WINS, 1)
		if heist != "":
			_add_heist(p, heist, LAST_BREATH_WINS, 1)
	_record_time(p, result, success, heist)
	_record_money(p, payout)
	if success:
		for l: Variant in result.get("loot", []) as Array:
			if l is Dictionary and String((l as Dictionary).get("loot_id", "")) != "":
				_add(p, "bags", String((l as Dictionary)["loot_id"]), 1)
				_add(p, "totals", BAGS, 1)
	_record_crew(p, crew_row(result, crew_slot))
	for w: StringName in [p.loadout.primary, p.loadout.secondary]:
		if w != &"":
			_add(p, "weapons", String(w), 1)


## Spending (or with `offshore`, stash) money spent. A negative amount (a refund) lowers it, never below 0.
## Banks one granted payday card (PaydayCards.grant returned true): cards_taken + 1, and a cash / XP card's
## amount into card_cash / card_xp.
static func record_card(p: PlayerProfile, card: Dictionary) -> void:
	if p == null:
		return
	_ensure(p)
	_add(p, "totals", CARDS_TAKEN, 1)
	var amount: int = maxi(int(card.get("amount", 0)), 0)
	match StringName(card.get("type", &"")):
		PaydayCards.CASH:
			_add(p, "totals", CARD_CASH, amount)
		PaydayCards.XP:
			_add(p, "totals", CARD_XP, amount)


static func add_spent(p: PlayerProfile, amount: int, offshore: bool = false) -> void:
	if p == null or amount == 0:
		return
	_ensure(p)
	var key: String = OFFSHORE_SPENT if offshore else CASH_SPENT
	var t: Dictionary = p.career["totals"] as Dictionary
	t[key] = maxi(int(t.get(key, 0)) + amount, 0)


## A totals counter; -1 when it was never counted (e.g. shots before D-071 data).
static func total(p: PlayerProfile, key: String) -> int:
	return int(section(p, "totals").get(key, -1))


## One career section (empty dict when missing). Read-only use.
static func section(p: PlayerProfile, name: String) -> Dictionary:
	if p == null or not p.career.get(name) is Dictionary:
		return {}
	return p.career[name] as Dictionary


## Per-heist counters of `heist` ({} when never played).
static func heist(p: PlayerProfile, heist_id: StringName) -> Dictionary:
	return section(p, "heists").get(String(heist_id), {}) as Dictionary


## Highest difficulty `heist` was won on, -1 when never won.
static func best_difficulty(p: PlayerProfile, heist_id: StringName) -> int:
	var h: Dictionary = heist(p, heist_id)
	for d: int in range(Enums.Difficulty.size() - 1, -1, -1):
		if int(h.get(WON_ON_FMT % d, 0)) > 0:
			return d
	return -1


## Highest difficulty any heist was won on, -1 when none (D-117 §2 difficulty unlocks).
static func best_difficulty_any(p: PlayerProfile) -> int:
	var best: int = -1
	for id: Variant in section(p, "heists"):
		best = maxi(best, best_difficulty(p, StringName(id)))
	return best


## Fastest win of `heist` in seconds, -1.0 when unknown.
static func fastest_win_s(p: PlayerProfile, heist_id: StringName) -> float:
	var ms: int = int(heist(p, heist_id).get(FASTEST_WIN_MS, -1))
	return float(ms) / 1000.0 if ms > 0 else -1.0


## hits / shots in 0..1, -1.0 when shots were never counted (or are 0).
static func accuracy(p: PlayerProfile) -> float:
	var shots: int = total(p, "shots")
	var hits: int = total(p, "hits")
	if shots <= 0 or hits < 0:
		return -1.0
	return clampf(float(hits) / float(shots), 0.0, 1.0)


## Most carried weapon id (ties: lowest id), &"" when none.
static func favourite_weapon(p: PlayerProfile) -> StringName:
	var best: String = ""
	var most: int = 0
	var w: Dictionary = section(p, "weapons")
	for k: Variant in w:
		var n: int = int(w[k])
		if n > most or (n == most and n > 0 and String(k) < best):
			best = String(k)
			most = n
	return StringName(best)


## How many of `heist_ids` were won at least once with the filters (difficulty >= difficulty_min;
## stealth / loud = that style only).
static func heists_won(p: PlayerProfile, heist_ids: Array[StringName], difficulty_min: int = 0,
		stealth: bool = false, loud: bool = false) -> int:
	var n: int = 0
	for id: StringName in heist_ids:
		var h: Dictionary = heist(p, id)
		var ok: bool = best_difficulty(p, id) >= maxi(difficulty_min, 0)
		ok = ok and not (stealth and int(h.get(STEALTH_WINS, 0)) <= 0)
		ok = ok and not (loud and int(h.get(LOUD_WINS, 0)) <= 0)
		n += 1 if ok else 0
	return n


## The local player's crew row of a HeistResult ({} when absent).
static func crew_row(result: Dictionary, crew_slot: int) -> Dictionary:
	if crew_slot < 0:
		return {}
	for c: Variant in result.get("crew", []) as Array:
		if c is Dictionary and int((c as Dictionary).get("slot", -1)) == crew_slot:
			return c as Dictionary
	return {}


static func _record_time(p: PlayerProfile, result: Dictionary, success: bool, heist_id: String) -> void:
	var t: Variant = result.get("time_s")
	if not (t is float or t is int) or float(t) <= 0.0:
		return
	_add(p, "totals", TIME_PLAYED_S, roundi(float(t)))
	if not success or heist_id == "":
		return
	var ms: int = roundi(float(t) * 1000.0)
	var h: Dictionary = _heist_dict(p, heist_id)
	if not h.has(FASTEST_WIN_MS) or ms < int(h[FASTEST_WIN_MS]):
		h[FASTEST_WIN_MS] = ms


static func _record_money(p: PlayerProfile, payout: Dictionary) -> void:
	var pairs: Dictionary = {SPENDING_EARNED: "spending", STASH_EARNED: "stash", XP_EARNED: "xp_total", SMALL_LOOT: "small_loot"}
	for k: String in pairs:
		if payout.has(pairs[k]):
			_add(p, "totals", k, maxi(int(payout[pairs[k]]), 0))


static func _record_crew(p: PlayerProfile, row: Dictionary) -> void:
	if row.is_empty():
		return
	for k: String in CREW_COUNTERS:
		var v: Variant = row.get(k)
		if v is int or v is float:
			_add(p, "totals", k, maxi(int(v), 0))
	if bool(row.get("in_custody", false)):
		_add(p, "totals", CUSTODY, 1)


static func _ensure(p: PlayerProfile) -> void:
	for s: String in SECTIONS:
		if not p.career.get(s) is Dictionary:
			p.career[s] = {}


static func _add(p: PlayerProfile, sec: String, key: String, amount: int) -> void:
	var d: Dictionary = p.career[sec] as Dictionary
	d[key] = int(d.get(key, 0)) + amount


static func _heist_dict(p: PlayerProfile, heist_id: String) -> Dictionary:
	var hs: Dictionary = p.career["heists"] as Dictionary
	if not hs.get(heist_id) is Dictionary:
		hs[heist_id] = {}
	return hs[heist_id] as Dictionary


static func _add_heist(p: PlayerProfile, heist_id: String, key: String, amount: int) -> void:
	var h: Dictionary = _heist_dict(p, heist_id)
	h[key] = int(h.get(key, 0)) + amount


static func _add_diff(p: PlayerProfile, diff: int, key: String, amount: int) -> void:
	var ds: Dictionary = p.career["difficulties"] as Dictionary
	var k: String = str(diff)
	if not ds.get(k) is Dictionary:
		ds[k] = {}
	var d: Dictionary = ds[k] as Dictionary
	d[key] = int(d.get(key, 0)) + amount
