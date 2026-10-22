## Skill set editing rules for the skill tree screen (B4-03). Owner: ENV B.
## Legality is SkillPoints' (tier gates, budget); this adds the UI-side states, buying, refunding and
## respec on a skill dict (id -> 1 basic / 2 aced), mutated in place.
##
## Refund rule (PD2 behaviour): a refund removes ONE level (aced -> basic, basic -> none) and is
## BLOCKED when the remaining set would break a tier gate, i.e. a higher-tier skill of the same
## subtree depends on those points (reason `refund_breaks_tier`). No cascade: the player refunds the
## dependent skill first. Respec (free, SkillTreeDef.respec_cost) clears the whole set at once.
class_name SkillBuild
extends RefCounted

const STATE_LOCKED: StringName = &"locked"
const STATE_AVAILABLE: StringName = &"available"
const STATE_BASIC: StringName = &"basic"
const STATE_ACED: StringName = &"aced"
## refund reasons (strings: ui.skills.reason.<code>), next to SkillPoints.REASON_*.
const REASON_NOT_OWNED: StringName = &"not_owned"
const REASON_REFUND_TIER: StringName = &"refund_breaks_tier"
## Budget used when only the tier gates matter (refunds never fail on points).
const NO_BUDGET_LIMIT: int = 1 << 30


static func total_points(level: int) -> int:
	return SkillPoints.points_for_level(level)


static func available_points(skills: Dictionary, level: int) -> int:
	return total_points(level) - SkillPoints.spent_total(skills)


## locked (tier gate not met, not owned) / available (tier open, not owned) / basic / aced.
static func state_of(skills: Dictionary, skill_id: StringName, level: int) -> StringName:
	var owned: int = int(skills.get(skill_id, 0))
	if owned >= SkillPoints.ACED:
		return STATE_ACED
	if owned == SkillPoints.BASIC:
		return STATE_BASIC
	var r: Dictionary = SkillPoints.can_unlock(skills, skill_id, total_points(level))
	return STATE_LOCKED if StringName(r["reason"]) == SkillPoints.REASON_TIER else STATE_AVAILABLE


## Buy the next level (basic, then aced). Returns SkillPoints.can_unlock()'s dict; applied when ok.
static func buy(skills: Dictionary, skill_id: StringName, level: int) -> Dictionary:
	var r: Dictionary = SkillPoints.can_unlock(skills, skill_id, total_points(level))
	if bool(r["ok"]):
		skills[skill_id] = int(r["next_level"])
	return r


## Whether one level of `skill_id` can be refunded: {ok, reason, refund (points returned), next_level}.
static func can_refund(skills: Dictionary, skill_id: StringName) -> Dictionary:
	var out: Dictionary = {"ok": false, "reason": SkillPoints.REASON_OK, "refund": 0, "next_level": 0}
	var owned: int = int(skills.get(skill_id, 0))
	var s: SkillDef = ContentDB.by_id(ContentDB.SKILLS, skill_id) as SkillDef
	if owned <= 0 or s == null:
		out["reason"] = REASON_NOT_OWNED
		return out
	var trial: Dictionary = skills.duplicate()
	if owned >= SkillPoints.ACED:
		trial[skill_id] = SkillPoints.BASIC
	else:
		trial.erase(skill_id)
	out["next_level"] = owned - 1
	out["refund"] = SkillPoints.cost_of(s, owned) - SkillPoints.cost_of(s, owned - 1)
	if not SkillPoints.is_legal(trial, NO_BUDGET_LIMIT):
		out["reason"] = REASON_REFUND_TIER
		return out
	out["ok"] = true
	return out


## Refund one level; returns can_refund()'s dict, applied when ok.
static func refund(skills: Dictionary, skill_id: StringName) -> Dictionary:
	var r: Dictionary = can_refund(skills, skill_id)
	if bool(r["ok"]):
		if int(r["next_level"]) <= 0:
			skills.erase(skill_id)
		else:
			skills[skill_id] = int(r["next_level"])
	return r


## Free respec: clears the set. Returns the points given back.
static func respec(skills: Dictionary) -> int:
	var back: int = SkillPoints.spent_total(skills)
	skills.clear()
	return back


## Modifier keys a part ("basic" / "aced") still waits for (SkillTreeDef.blocked_on_keys).
static func blocked_keys(skill_id: StringName, part: String) -> Array:
	var v: Variant = SkillPoints.tree_def().blocked_on_keys.get("%s:%s" % [skill_id, part], [])
	return v as Array if v is Array else []


## LEAD r280: how much of a skill works in play today: &"active", &"partial" (some granted keys still wait for a
## runtime hook) or &"inactive" (every granted key waits). A grant key counts as waiting when it is a blocked key or a
## qualified form of one (`weapon.ads_speed_mult.shotgun` under `weapon.ads_speed_mult`).
static func activity(s: SkillDef) -> StringName:
	var total: int = 0
	var waiting: int = 0
	for part: String in ["basic", "aced"]:
		var blocked: Array = blocked_keys(s.id, part)
		for k: Variant in (s.grants_basic if part == "basic" else s.grants_aced):
			total += 1
			for b: Variant in blocked:
				if String(k) == String(b) or String(k).begins_with(String(b) + "."):
					waiting += 1
					break
	if waiting == 0:
		return &"active"
	return &"inactive" if waiting == total else &"partial"


## Item id a part unlocks through item data (SkillTreeDef.unlocks), or &"".
static func unlock_of(skill_id: StringName, part: String) -> StringName:
	return StringName(SkillPoints.tree_def().unlocks.get("%s:%s" % [skill_id, part], &""))


## True when any grant of the skill is crew-wide (`team.*`).
static func is_team_skill(s: SkillDef) -> bool:
	var t: SkillTreeDef = SkillPoints.tree_def()
	for grants: Dictionary in [s.grants_basic, s.grants_aced]:
		for k: Variant in grants:
			if t.is_team_key(StringName(k)):
				return true
	return false
