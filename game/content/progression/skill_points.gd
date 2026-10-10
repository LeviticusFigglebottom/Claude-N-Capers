## Skill point budget and legality (pd2_fidelity.md P1/P2). Owner: ENV B. Rules data: SkillTreeDef
## (content/data/skills/trees.tres); design doc: content/docs/skills.md.
##
## A skill set is `Loadout.skills`: skill id -> 1 (basic) / 2 (aced). Aced always includes basic, so its
## cost is cost_basic + cost_aced. The host validates every joining crew member's set with validate()
## (architecture.md §11); the skill UI uses can_unlock() for buttons and spent_*() for counters.
##
## Tier gate: a tier-t skill needs SkillTreeDef.tier_thresholds[t - 1] points spent on LOWER tiers of the
## same subtree (0/1/3/18). Respec is free (SkillTreeDef.respec_cost): a new set is simply validated.
class_name SkillPoints
extends RefCounted

const BASIC: int = 1
const ACED: int = 2
## can_unlock() reason codes; UI text is strings.csv `ui.skills.reason.<code>`.
const REASON_OK: StringName = &""
const REASON_UNKNOWN: StringName = &"unknown_skill"
const REASON_ACED: StringName = &"already_aced"
const REASON_TIER: StringName = &"tier_locked"
const REASON_POINTS: StringName = &"not_enough_points"

static var _tree: SkillTreeDef = null


static func tree_def() -> SkillTreeDef:
	if _tree == null:
		_tree = SkillTreeDef.load_default()
	return _tree


## Total skill points at a reputation level: 1 per level + 2 at every 10th level (120 at level 100).
static func points_for_level(level: int) -> int:
	var t: SkillTreeDef = tree_def()
	var lv: int = clampi(level, 0, t.max_level)
	return lv * t.points_per_level + floori(float(lv) / float(t.bonus_every_levels)) * t.bonus_points


## Points a skill costs at `level` (0 none, 1 basic, 2 aced = basic + aced).
static func cost_of(skill: SkillDef, level: int) -> int:
	if level <= 0:
		return 0
	if level == BASIC:
		return skill.cost_basic
	return skill.cost_basic + skill.cost_aced


## Total points a skill set spends (unknown ids count 0; validate() reports them).
static func spent_total(skills: Dictionary) -> int:
	var table: Dictionary = _skill_table()
	var total: int = 0
	for sid: Variant in skills:
		var s: SkillDef = table.get(StringName(sid), null) as SkillDef
		if s != null:
			total += cost_of(s, int(skills[sid]))
	return total


## Points spent in one subtree, counting only skills of tier < `below_tier` (default: every tier).
static func spent_in_subtree(skills: Dictionary, subtree: StringName, below_tier: int = 5) -> int:
	var table: Dictionary = _skill_table()
	var total: int = 0
	for sid: Variant in skills:
		var s: SkillDef = table.get(StringName(sid), null) as SkillDef
		if s != null and s.subtree == subtree and s.tier < below_tier:
			total += cost_of(s, int(skills[sid]))
	return total


## Whether the next level of `skill_id` (basic if not owned, else aced) can be bought on top of `skills`
## with `total_points` (use points_for_level()). Returns {ok: bool, reason: StringName (REASON_*),
## cost: int (points for that step), next_level: int, need: int (tier threshold), have: int}.
static func can_unlock(skills: Dictionary, skill_id: StringName, total_points: int) -> Dictionary:
	var out: Dictionary = {"ok": false, "reason": REASON_OK, "cost": 0, "next_level": 0, "need": 0, "have": 0}
	var s: SkillDef = _skill_table().get(skill_id, null) as SkillDef
	if s == null:
		out["reason"] = REASON_UNKNOWN
		return out
	var current: int = int(skills.get(skill_id, 0))
	if current >= ACED:
		out["reason"] = REASON_ACED
		return out
	var next: int = current + 1
	out["next_level"] = next
	out["cost"] = s.cost_basic if next == BASIC else s.cost_aced
	out["need"] = tree_def().threshold_for_tier(s.tier)
	out["have"] = spent_in_subtree(skills, s.subtree, s.tier)
	if int(out["have"]) < int(out["need"]):
		out["reason"] = REASON_TIER
		return out
	if spent_total(skills) + int(out["cost"]) > total_points:
		out["reason"] = REASON_POINTS
		return out
	out["ok"] = true
	return out


## Every legality problem of a skill set against a point budget (empty = legal): unknown ids, levels
## other than 1/2, tier gates, and the budget. Messages are for logs/host rejection, not UI.
static func validate(skills: Dictionary, total_points: int) -> Array[String]:
	var errors: Array[String] = []
	var table: Dictionary = _skill_table()
	var ids: Array = skills.keys()
	ContentDB.sort_ids(ids)
	for sid: Variant in ids:
		var level: Variant = skills[sid]
		var s: SkillDef = table.get(StringName(sid), null) as SkillDef
		if s == null:
			errors.append("unknown skill %s" % sid)
			continue
		if not (level is int) or (int(level) != BASIC and int(level) != ACED):
			errors.append("%s: level must be 1 (basic) or 2 (aced), got %s" % [sid, level])
			continue
		var need: int = tree_def().threshold_for_tier(s.tier)
		var have: int = spent_in_subtree(skills, s.subtree, s.tier)
		if have < need:
			errors.append("%s: tier %d needs %d points in lower tiers of %s, has %d" % [sid, s.tier, need, s.subtree, have])
	var spent: int = spent_total(skills)
	if spent > total_points:
		errors.append("spends %d points, only %d available" % [spent, total_points])
	return errors


static func is_legal(skills: Dictionary, total_points: int) -> bool:
	return validate(skills, total_points).is_empty()


## Drop the cached tree layout (tests, hot reload).
static func clear_cache() -> void:
	_tree = null


static func _skill_table() -> Dictionary:
	var out: Dictionary = {}
	for r: Variant in ContentDB.all_of(ContentDB.SKILLS):
		var s: SkillDef = r as SkillDef
		if s != null:
			out[s.id] = s
	return out
