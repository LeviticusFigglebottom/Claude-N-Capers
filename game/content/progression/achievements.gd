## Achievements (B4-20, expanded in B7-02). Owner: ENV B. Static. Defs: AchievementDef (data/achievements/*.tres).
##
## State lives in PlayerProfile.achievements (save v5): id -> {"progress": int, "unlocked": bool}.
## PaydayScreen calls on_payday(profile, result, payout, is_pro) when it banks a HeistResult (after
## Career.record); it emits the events below in order, then sync()s the state conditions, and returns the
## ids unlocked by this payday (the caller saves):
##   heist_completed | heist_failed (from result.success), stash_earned (payout.stash), level_reached.
## State conditions (career_stat, notoriety_reached, heists_all; see AchievementDef) are evaluated by
## sync(p), which Notoriety.rank_up also runs.
## Completing an achievement grants its `unlock` through MaskLocker.grant_unlock (presets and mask parts
## behind that id, e.g. achievement.cataclysm_clear -> unlock.achievement.cataclysm_clear ->
## mask.oxblood_herald), its `rewards` parts (MaskLocker.grant_part) and its `unlocks` ids (weapon
## finishes for B7-04). Unlocked achievements never progress or lock again.
class_name Achievements
extends RefCounted

const HEIST_COMPLETED: StringName = &"heist_completed"
const HEIST_FAILED: StringName = &"heist_failed"
const STASH_EARNED: StringName = &"stash_earned"
const LEVEL_REACHED: StringName = &"level_reached"
const CAREER_STAT: StringName = &"career_stat"
const NOTORIETY_REACHED: StringName = &"notoriety_reached"
const HEISTS_ALL: StringName = &"heists_all"
## Conditions evaluated from the profile's state by sync() (never by record()).
const STATE_EVENTS: Array[StringName] = [CAREER_STAT, NOTORIETY_REACHED, HEISTS_ALL]
const EVENTS: Array[StringName] = [HEIST_COMPLETED, HEIST_FAILED, STASH_EARNED, LEVEL_REACHED, CAREER_STAT,
	NOTORIETY_REACHED, HEISTS_ALL]
## Screen categories, in display order (strings `ui.achievements.category.<id>`).
## D-115: one category per heist (id = heist id) after the general heist list.
const CATEGORIES: Array[StringName] = [&"career", &"heists", &"glasshouse", &"night_deposit", &"shadow_ledger",
	&"dockside_burn", &"gallery_night", &"ostrander_federal", &"rolling_thunder",
	&"afterhours", &"stealth", &"loud", &"combat", &"wealth", &"notoriety"]


## Every def in display order (order, then id).
static func all() -> Array[AchievementDef]:
	var out: Array[AchievementDef] = []
	for r: Variant in ContentDB.all_of(ContentDB.ACHIEVEMENTS):
		if r is AchievementDef:
			out.append(r as AchievementDef)
	out.sort_custom(func(a: AchievementDef, b: AchievementDef) -> bool:
		return a.order < b.order if a.order != b.order else ContentDB.id_less(a.id, b.id))
	return out


## all() minus the achievements of a heist the menus do not offer yet (a staged heist_list entry, e.g. Ostrander
## Federal behind its "hidden" switch): the achievements screen shows these.
static func shown() -> Array[AchievementDef]:
	var list: UiHeistList = HeistCatalog.heist_list()
	var offered: Array[StringName] = HeistCatalog.ids()
	var out: Array[AchievementDef] = []
	for a: AchievementDef in all():
		if list.heists.has(a.category) and not offered.has(a.category):
			continue
		out.append(a)
	return out


static func progress(p: PlayerProfile, id: StringName) -> int:
	return int((p.achievements.get(id, {}) as Dictionary).get("progress", 0)) if p != null else 0


static func is_unlocked(p: PlayerProfile, id: StringName) -> bool:
	return bool((p.achievements.get(id, {}) as Dictionary).get("unlocked", false)) if p != null else false


## The payday hook: HeistResult + PayoutCalculator output -> newly unlocked achievement ids. `facts` is the
## in-heist log (HeistFacts.snapshot(), D-115); {} = none, so every fact condition fails closed.
static func on_payday(p: PlayerProfile, result: Dictionary, payout: Dictionary, is_pro: bool = false,
		facts: Dictionary = {}) -> Array[StringName]:
	var out: Array[StringName] = []
	if p == null:
		return out
	var ctx: Dictionary = {
		"heist": StringName(result.get("heist_id", &"")), "difficulty": int(result.get("difficulty", 0)),
		"stealth": bool(result.get("stealth", false)), "pro": is_pro,
		"stash": int(payout.get("stash", 0)), "level": p.level, "result": result, "facts": facts,
	}
	var success: bool = bool(payout.get("success", result.get("success", false)))
	out.append_array(record(p, HEIST_COMPLETED if success else HEIST_FAILED, ctx))
	out.append_array(record(p, STASH_EARNED, ctx))
	out.append_array(record(p, LEVEL_REACHED, ctx))
	out.append_array(sync(p))
	return out


## Applies one event to every matching achievement. `ctx` keys: heist, difficulty, stealth, pro, result
## (the HeistResult), facts (HeistFacts.snapshot()) (heist events), stash (stash_earned), level
## (level_reached). Returns the ids unlocked by it.
static func record(p: PlayerProfile, event: StringName, ctx: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for a: AchievementDef in all():
		if a.event() != event or is_unlocked(p, a.id):
			continue
		if _advance(p, a, _next_progress(a, progress(p, a.id), ctx)):
			out.append(a.id)
	return out


## Evaluates every state condition (career_stat, notoriety_reached, heists_all) against the profile.
## Returns the ids unlocked by it. Idempotent.
static func sync(p: PlayerProfile) -> Array[StringName]:
	var out: Array[StringName] = []
	if p == null:
		return out
	for a: AchievementDef in all():
		if STATE_EVENTS.has(a.event()) and not is_unlocked(p, a.id) and _advance(p, a, current_value(p, a)):
			out.append(a.id)
	return out


## Whether a heist event `ctx` passes `a`'s filters.
static func matches(a: AchievementDef, ctx: Dictionary) -> bool:
	var c: Dictionary = a.condition
	var heist: StringName = StringName(c.get("heist", &""))
	var ok: bool = heist == &"" or heist == StringName(ctx.get("heist", &""))
	ok = ok and int(ctx.get("difficulty", 0)) >= int(c.get("difficulty_min", 0))
	ok = ok and not (bool(c.get("stealth", false)) and not bool(ctx.get("stealth", false)))
	ok = ok and not (bool(c.get("loud", false)) and bool(ctx.get("stealth", false)))
	ok = ok and not (bool(c.get("pro", false)) and not bool(ctx.get("pro", false)))
	return ok and HeistConditions.passes(c, ctx.get("result", {}) as Dictionary, ctx.get("facts", {}) as Dictionary)


## Target of `a`: its count, or for heists_all with count 0 the number of offered heists.
static func target_of(a: AchievementDef) -> int:
	if a.event() == HEISTS_ALL and int(a.condition.get("count", 0)) <= 0:
		return maxi(HeistCatalog.ids().size(), 1)
	return a.target()


## The live value of a state condition (career counter, rank, heists won); stored progress for the others.
static func current_value(p: PlayerProfile, a: AchievementDef) -> int:
	if p == null:
		return 0
	var c: Dictionary = a.condition
	match a.event():
		CAREER_STAT:
			return _career_value(p, c)
		NOTORIETY_REACHED:
			return p.notoriety
		HEISTS_ALL:
			return Career.heists_won(p, HeistCatalog.ids(), int(c.get("difficulty_min", 0)),
					bool(c.get("stealth", false)), bool(c.get("loud", false)))
	return progress(p, a.id)


## Progress to show (screen): stored progress, or the live value of a state condition, capped at the target.
static func display_progress(p: PlayerProfile, a: AchievementDef) -> int:
	var v: int = progress(p, a.id)
	if STATE_EVENTS.has(a.event()) and not is_unlocked(p, a.id):
		v = maxi(v, current_value(p, a))
	return mini(v, target_of(a))


## Everything completing `a` grants: its unlock id, reward parts, extra unlock ids (in that order).
## Every id an achievement grants (reward_ids over all()), as a set. PaydayCards keeps these out of its drop pool
## (LEAD r278: PD2 achievement rewards never drop).
static func all_reward_ids() -> Dictionary:
	var out: Dictionary = {}
	for a: AchievementDef in all():
		for id: StringName in reward_ids(a):
			out[id] = true
	return out


static func reward_ids(a: AchievementDef) -> Array[StringName]:
	var out: Array[StringName] = []
	if a.unlock != &"":
		out.append(a.unlock)
	out.append_array(a.rewards)
	out.append_array(a.unlocks)
	return out


static func _career_value(p: PlayerProfile, c: Dictionary) -> int:
	var stat: String = String(c.get("stat", ""))
	var v: int = Career.total(p, stat)
	if c.has("bag"):
		v = int(Career.section(p, "bags").get(String(c["bag"]), 0))
	elif c.has("heist"):
		v = int(Career.heist(p, StringName(c["heist"])).get(stat, 0))
	return maxi(v, 0)


## Stores `value` (capped at the target, never below the stored progress) as a's progress; on reaching
## the target unlocks it and grants its rewards. True when this call unlocked it.
static func _advance(p: PlayerProfile, a: AchievementDef, value: int) -> bool:
	var before: int = progress(p, a.id)
	var after: int = mini(maxi(value, before), target_of(a))
	if after == before:
		return false
	var unlocked: bool = after >= target_of(a)
	p.achievements[a.id] = {"progress": after, "unlocked": unlocked}
	if not unlocked:
		return false
	if a.unlock != &"":
		MaskLocker.grant_unlock(p, a.unlock)
	for id: StringName in a.rewards:
		MaskLocker.grant_part(p, id)
	for id: StringName in a.unlocks:
		MaskLocker.grant_unlock(p, id)
	Log.info(&"progression", "achievement unlocked: %s" % a.id)
	return true


static func _next_progress(a: AchievementDef, before: int, ctx: Dictionary) -> int:
	match a.event():
		HEIST_COMPLETED, HEIST_FAILED:
			return before + 1 if matches(a, ctx) else before
		STASH_EARNED:
			return before + maxi(int(ctx.get("stash", 0)), 0)
		LEVEL_REACHED:
			return maxi(before, int(ctx.get("level", 0)))
	return before
