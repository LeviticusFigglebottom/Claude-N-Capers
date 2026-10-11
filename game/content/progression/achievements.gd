## Achievements stub (B4-20). Owner: ENV B. Static. Defs: AchievementDef (data/achievements/*.tres).
##
## State lives in PlayerProfile.achievements (save v5): id -> {"progress": int, "unlocked": bool}.
## PaydayScreen calls on_payday(profile, result, payout, is_pro) when it banks a HeistResult; it emits
## the events below in order and returns the ids unlocked by this payday (the caller saves):
##   heist_completed | heist_failed (from result.success), stash_earned (payout.stash), level_reached.
## Completing an achievement with an `unlock` grants it through MaskLocker.grant_unlock (e.g.
## achievement.cataclysm_clear -> unlock.achievement.cataclysm_clear -> mask.oxblood_herald).
## Unlocked achievements never progress or lock again.
class_name Achievements
extends RefCounted

const HEIST_COMPLETED: StringName = &"heist_completed"
const HEIST_FAILED: StringName = &"heist_failed"
const STASH_EARNED: StringName = &"stash_earned"
const LEVEL_REACHED: StringName = &"level_reached"
const EVENTS: Array[StringName] = [HEIST_COMPLETED, HEIST_FAILED, STASH_EARNED, LEVEL_REACHED]


## Every def in display order (order, then id).
static func all() -> Array[AchievementDef]:
	var out: Array[AchievementDef] = []
	for r: Variant in ContentDB.all_of(ContentDB.ACHIEVEMENTS):
		if r is AchievementDef:
			out.append(r as AchievementDef)
	out.sort_custom(func(a: AchievementDef, b: AchievementDef) -> bool:
		return a.order < b.order if a.order != b.order else ContentDB.id_less(a.id, b.id))
	return out


static func progress(p: PlayerProfile, id: StringName) -> int:
	return int((p.achievements.get(id, {}) as Dictionary).get("progress", 0)) if p != null else 0


static func is_unlocked(p: PlayerProfile, id: StringName) -> bool:
	return bool((p.achievements.get(id, {}) as Dictionary).get("unlocked", false)) if p != null else false


## The payday hook: HeistResult + PayoutCalculator output -> newly unlocked achievement ids.
static func on_payday(p: PlayerProfile, result: Dictionary, payout: Dictionary, is_pro: bool = false) -> Array[StringName]:
	var out: Array[StringName] = []
	if p == null:
		return out
	var ctx: Dictionary = {
		"heist": StringName(result.get("heist_id", &"")), "difficulty": int(result.get("difficulty", 0)),
		"stealth": bool(result.get("stealth", false)), "pro": is_pro,
		"stash": int(payout.get("stash", 0)), "level": p.level,
	}
	var success: bool = bool(payout.get("success", result.get("success", false)))
	out.append_array(record(p, HEIST_COMPLETED if success else HEIST_FAILED, ctx))
	out.append_array(record(p, STASH_EARNED, ctx))
	out.append_array(record(p, LEVEL_REACHED, ctx))
	return out


## Applies one event to every matching achievement. `ctx` keys: heist, difficulty, stealth, pro (heist
## events), stash (stash_earned), level (level_reached). Returns the ids unlocked by it.
static func record(p: PlayerProfile, event: StringName, ctx: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for a: AchievementDef in all():
		if a.event() != event or is_unlocked(p, a.id):
			continue
		var before: int = progress(p, a.id)
		var after: int = mini(_next_progress(a, before, ctx), a.target())
		if after == before:
			continue
		var unlocked: bool = after >= a.target()
		p.achievements[a.id] = {"progress": after, "unlocked": unlocked}
		if unlocked:
			out.append(a.id)
			if a.unlock != &"":
				MaskLocker.grant_unlock(p, a.unlock)
			Log.info(&"progression", "achievement unlocked: %s" % a.id)
	return out


## Whether a heist event `ctx` passes `a`'s filters.
static func matches(a: AchievementDef, ctx: Dictionary) -> bool:
	var c: Dictionary = a.condition
	var heist: StringName = StringName(c.get("heist", &""))
	var ok: bool = heist == &"" or heist == StringName(ctx.get("heist", &""))
	ok = ok and int(ctx.get("difficulty", 0)) >= int(c.get("difficulty_min", 0))
	ok = ok and not (bool(c.get("stealth", false)) and not bool(ctx.get("stealth", false)))
	ok = ok and not (bool(c.get("loud", false)) and bool(ctx.get("stealth", false)))
	return ok and not (bool(c.get("pro", false)) and not bool(ctx.get("pro", false)))


static func _next_progress(a: AchievementDef, before: int, ctx: Dictionary) -> int:
	match a.event():
		HEIST_COMPLETED, HEIST_FAILED:
			return before + 1 if matches(a, ctx) else before
		STASH_EARNED:
			return before + maxi(int(ctx.get("stash", 0)), 0)
		LEVEL_REACHED:
			return maxi(before, int(ctx.get("level", 0)))
	return before
