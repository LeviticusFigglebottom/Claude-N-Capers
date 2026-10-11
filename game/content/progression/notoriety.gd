## Notoriety ranks (pd2_fidelity P10, the PD2 infamy analog; roadmap B5-02). Owner: ENV B. Static.
## Design + numbers: content/docs/notoriety.md. Data: NotorietyTweak (data/tweak/notoriety.tres: cap,
## required level, cost table, XP bonus) and NotorietyTable (data/notoriety/ranks.tres: rewards per rank).
##
## Ranking up (rank_up): needs rank < max_rank, level >= required_level and spending cash >= the next
## rank's cost. It takes the cost from PlayerProfile.cash, moves `xp` into `notoriety_xp` (perk points keep
## counting it), sets level and xp to 0, holds every skill set (NotorietySkills.hold: points come back
## with levels) and grants the rank's rewards: the unlock id `unlock.notoriety.rank_<n>` (owns presets
## behind it), NotorietyDef.rewards (mask parts / presets) and NotorietyDef.unlocks (plain unlock ids such
## as `unlock.music.<track>`, D-062). Owned items, masks, perk decks, stash and the stealth bank are kept.
## A rank with NotorietyDef.choices adds a pending choice: choose() grants one option not owned yet.
## XP bonus: xp_bonus(rank) = min(rank x xp_bonus_per_rank, xp_bonus_cap), additive; PaydayScreen passes
## it to PayoutCalculator.compute(..., notoriety_bonus) (its own XP line).
## Callers save the profile themselves (SaveService.save_profile).
class_name Notoriety
extends RefCounted

const TWEAK_NAME: StringName = &"notoriety"
const TABLE_PATH: String = "res://content/data/notoriety/ranks.tres"
const UNLOCK_PREFIX: String = "unlock.notoriety.rank_"
## Requirement / refusal codes (UI text: strings.csv `ui.notoriety.check.<code>`).
const REQ_LEVEL: StringName = &"level"
const REQ_CASH: StringName = &"cash"
const REQ_CAP: StringName = &"cap"
const NUMERALS: Array[Array] = [[10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]

static var _table: NotorietyTable = null
## rank -> NotorietyDef
static var _by_rank: Dictionary = {}


static func tweak() -> NotorietyTweak:
	var t: NotorietyTweak = ContentDB.tweak(TWEAK_NAME) as NotorietyTweak
	return t if t != null else NotorietyTweak.new()


static func table() -> NotorietyTable:
	if _table == null:
		_table = load(TABLE_PATH) as NotorietyTable if ResourceLoader.exists(TABLE_PATH) else null
		if _table == null:
			Log.error(&"content", "Notoriety: missing %s" % TABLE_PATH)
			_table = NotorietyTable.new()
		_by_rank.clear()
		for d: NotorietyDef in _table.ranks:
			if d != null:
				_by_rank[d.rank] = d
	return _table


## The rank's reward def, or null when the rank has no item reward.
static func def_for(rank: int) -> NotorietyDef:
	table()
	return _by_rank.get(rank, null) as NotorietyDef


static func max_rank() -> int:
	return tweak().max_rank


## Spending cash needed to reach `rank` (1..max_rank); 0 outside that range.
static func cost_for(rank: int) -> int:
	var t: NotorietyTweak = tweak()
	if rank < 1 or rank > t.max_rank or t.costs.is_empty():
		return 0
	return t.costs[mini(rank, t.costs.size()) - 1]


## Additive XP bonus of a rank (0.04 = +4 %), capped by the tweak.
static func xp_bonus(rank: int) -> float:
	var t: NotorietyTweak = tweak()
	return clampf(float(maxi(rank, 0)) * t.xp_bonus_per_rank, 0.0, t.xp_bonus_cap)


static func unlock_id(rank: int) -> StringName:
	return StringName(UNLOCK_PREFIX + str(rank))


## Roman numeral of 1..39 ("" for 0 or less): the rank badge text.
static func roman(n: int) -> String:
	var out: String = ""
	var left: int = clampi(n, 0, 39)
	for pair: Array in NUMERALS:
		while left >= int(pair[0]):
			out += String(pair[1])
			left -= int(pair[0])
	return out


## The next rank's checklist: [{code: REQ_*, met: bool, have: int, need: int}]. At the cap it is the
## single unmet REQ_CAP row.
static func requirements(p: PlayerProfile) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var t: NotorietyTweak = tweak()
	if p.notoriety >= t.max_rank:
		out.append({"code": REQ_CAP, "met": false, "have": p.notoriety, "need": t.max_rank})
		return out
	out.append({"code": REQ_LEVEL, "met": p.level >= t.required_level, "have": p.level, "need": t.required_level})
	var cost: int = cost_for(p.notoriety + 1)
	out.append({"code": REQ_CASH, "met": p.cash >= cost, "have": p.cash, "need": cost})
	return out


static func can_rank_up(p: PlayerProfile) -> bool:
	if p == null:
		return false
	for r: Dictionary in requirements(p):
		if not bool(r["met"]):
			return false
	return true


## Ranks the profile up (see the header). Returns {ok, reason (first unmet REQ_* or &""), rank, cost,
## granted: Array[StringName] (newly owned items + recorded unlock ids), choices: options to pick from}.
static func rank_up(p: PlayerProfile) -> Dictionary:
	var out: Dictionary = {"ok": false, "reason": &"", "rank": 0, "cost": 0,
			"granted": [] as Array[StringName], "choices": [] as Array[StringName]}
	if p == null:
		return out
	out["rank"] = p.notoriety
	for r: Dictionary in requirements(p):
		if not bool(r["met"]):
			out["reason"] = r["code"]
			return out
	var rank: int = p.notoriety + 1
	var cost: int = cost_for(rank)
	p.cash -= cost
	p.notoriety_xp += maxi(p.xp, 0)
	p.xp = 0
	p.level = 0
	p.notoriety = rank
	NotorietySkills.hold(p)
	out["ok"] = true
	out["rank"] = rank
	out["cost"] = cost
	out["granted"] = _grant_rank(p, rank)
	out["choices"] = choice_options(p, rank)
	return out


## What reaching `rank` gives (choices excluded): fixed rewards, presets behind the rank's unlock id and
## the plain unlock ids, in that order.
static func rewards_for(rank: int) -> Array[StringName]:
	var out: Array[StringName] = []
	var d: NotorietyDef = def_for(rank)
	if d != null:
		out.append_array(d.rewards)
	for md: MaskDef in MaskCatalog.presets():
		if md.unlock == unlock_id(rank):
			out.append(md.id)
	if d != null:
		out.append_array(d.unlocks)
	return out


## Options still open for `rank`'s reward choice: listed choices not owned yet ([] once chosen, when the
## rank has no choice, or above the profile's rank).
static func choice_options(p: PlayerProfile, rank: int) -> Array[StringName]:
	var out: Array[StringName] = []
	var d: NotorietyDef = def_for(rank)
	if p == null or d == null or rank > p.notoriety or p.notoriety_choices.has(rank):
		return out
	for id: StringName in d.choices:
		if not _owns(p, id):
			out.append(id)
	return out


## Picks `item_id` for `rank`'s choice (must be one of choice_options). Grants and records it.
static func choose(p: PlayerProfile, rank: int, item_id: StringName) -> bool:
	if not choice_options(p, rank).has(item_id):
		return false
	_grant(p, item_id)
	p.notoriety_choices[rank] = item_id
	return true


## Ranks (ascending) with a reward choice still to make.
static func pending_choices(p: PlayerProfile) -> Array[int]:
	var out: Array[int] = []
	if p == null:
		return out
	for r: int in range(1, p.notoriety + 1):
		if not choice_options(p, r).is_empty():
			out.append(r)
	return out


## Mask part ids that only Notoriety grants (left out of the payday card pools), sorted.
static func exclusive_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for d: NotorietyDef in table().ranks:
		for id: StringName in d.rewards + d.choices:
			if MaskCatalog.has_part(id) and not out.has(id):
				out.append(id)
	ContentDB.sort_ids(out)
	return out


## Load-time repair (ProfileValidator): every rank up to the profile's re-grants its unlock id, fixed
## rewards, plain unlocks and the recorded choice, so data added later reaches old profiles. Silent.
static func apply_rewards(p: PlayerProfile) -> void:
	if p == null:
		return
	for rank: int in range(1, p.notoriety + 1):
		_grant_rank(p, rank)
		if p.notoriety_choices.has(rank):
			_grant(p, p.notoriety_choices[rank] as StringName)


## Display name of a reward id: preset, mask part or unlock id (`ui.notoriety.unlock.<id>` text when the
## strings table has one, else the id).
static func reward_name(id: StringName) -> String:
	if MaskCatalog.is_preset_id(id) and ContentDB.has(ContentDB.MASKS, id):
		return MaskCatalog.display_name(id)
	if MaskCatalog.has_part(id):
		return MaskCatalog.part_name(id)
	var key: StringName = StringName("ui.notoriety.unlock." + String(id))
	var text: String = UiText.t(key)
	return String(id) if text == String(key) else text


## Drop the cached rank table (tests, hot reload).
static func clear_cache() -> void:
	_table = null
	_by_rank.clear()


static func _grant_rank(p: PlayerProfile, rank: int) -> Array[StringName]:
	var out: Array[StringName] = []
	var uid: StringName = unlock_id(rank)
	if not p.unlocks.has(uid):
		out.append(uid)
	out.append_array(MaskLocker.grant_unlock(p, uid))
	var d: NotorietyDef = def_for(rank)
	if d != null:
		for id: StringName in d.rewards + d.unlocks:
			if _grant(p, id):
				out.append(id)
	return out


## Grants one reward id (preset, part or unlock id). False when unknown or already owned.
static func _grant(p: PlayerProfile, id: StringName) -> bool:
	if _owns(p, id):
		return false
	if String(id).begins_with("unlock."):
		MaskLocker.grant_unlock(p, id)
		return true
	if MaskCatalog.is_preset_id(id):
		return MaskLocker.grant_preset(p, id)
	return MaskLocker.grant_part(p, id)


static func _owns(p: PlayerProfile, id: StringName) -> bool:
	if String(id).begins_with("unlock."):
		return p.unlocks.has(id)
	return MaskLocker.is_drop_owned(p, id)
