## Skill sets across a Notoriety rank-up (B5-02). Owner: ENV B. Static. Design: content/docs/notoriety.md.
##
## PD2's modern infamy keeps the skill build, and skill points come back as levels are regained. Spent
## points may never exceed the level's budget (SkillPoints.validate; ProfileValidator resets an illegal
## set), so a rank-up HOLDS each set instead of leaving it over budget:
##   hold(p)    every set i is merged into PlayerProfile.held_skill_sets[i] (max level per skill) and
##              emptied, then restore() runs (level 0 = 0 points, so nothing comes back yet).
##   restore(p) after every level gain (SaveService.apply_heist_payout, payday card XP): re-buys held
##              skills, lowest tier first then by id, basic before aced, while SkillPoints.can_unlock
##              allows it. A set whose held build is fully back drops its hold.
##   release(p, i) the player edited set i by hand (refund / respec in the skill screen): its hold is
##              dropped, the player owns the build again.
## Every set stays legal at all times.
class_name NotorietySkills
extends RefCounted


## Number of skill sets the profile has (the active one may sit past the stored list).
static func set_count(p: PlayerProfile) -> int:
	return maxi(p.skill_sets.size(), p.active_skill_set + 1)


static func hold(p: PlayerProfile) -> void:
	if p == null:
		return
	var n: int = set_count(p)
	_pad(p, n)
	for i: int in range(n):
		var merged: Dictionary = (p.held_skill_sets[i] as Dictionary).duplicate()
		var cur: Dictionary = p.skill_set(i)
		for sid: Variant in cur:
			merged[StringName(sid)] = maxi(int(merged.get(StringName(sid), 0)), int(cur[sid]))
		p.held_skill_sets[i] = merged
		_write_set(p, i, {})
	restore(p)


## Re-invests held skills within the level's budget. Returns the points re-invested.
static func restore(p: PlayerProfile) -> int:
	if p == null:
		return 0
	var budget: int = SkillPoints.points_for_level(p.level)
	var total: int = 0
	_pad(p, set_count(p))
	for i: int in range(p.held_skill_sets.size()):
		var held: Dictionary = p.held_skill_sets[i]
		if held.is_empty() or i >= set_count(p):
			continue
		var s: Dictionary = p.skill_set(i).duplicate()
		var before: int = SkillPoints.spent_total(s)
		_refill(s, held, budget)
		total += SkillPoints.spent_total(s) - before
		_write_set(p, i, s)
		if _covers(s, held):
			p.held_skill_sets[i] = {}
	return total


static func release(p: PlayerProfile, index: int) -> void:
	if p != null and index >= 0 and index < p.held_skill_sets.size():
		p.held_skill_sets[index] = {}


## Points the held build of set `index` still waits for (0 = nothing held).
static func held_points(p: PlayerProfile, index: int) -> int:
	if p == null or index < 0 or index >= p.held_skill_sets.size():
		return 0
	var held: Dictionary = p.held_skill_sets[index]
	return maxi(SkillPoints.spent_total(held) - SkillPoints.spent_total(p.skill_set(index)), 0)


static func _refill(s: Dictionary, held: Dictionary, budget: int) -> void:
	var ids: Array = held.keys()
	ids.sort_custom(_tier_less)
	var progress: bool = true
	while progress:
		progress = false
		for sid: Variant in ids:
			var id: StringName = StringName(sid)
			while int(s.get(id, 0)) < int(held[sid]):
				if not bool(SkillPoints.can_unlock(s, id, budget)["ok"]):
					break
				s[id] = int(s.get(id, 0)) + 1
				progress = true


static func _covers(s: Dictionary, held: Dictionary) -> bool:
	for sid: Variant in held:
		if int(s.get(StringName(sid), 0)) < int(held[sid]):
			return false
	return true


## Lower tier first, then by id text (deterministic, never pointer order).
static func _tier_less(a: Variant, b: Variant) -> bool:
	var ta: int = _tier(StringName(a))
	var tb: int = _tier(StringName(b))
	if ta != tb:
		return ta < tb
	return ContentDB.id_less(a, b)


static func _tier(id: StringName) -> int:
	var s: SkillDef = ContentDB.by_id(ContentDB.SKILLS, id) as SkillDef if ContentDB.has(ContentDB.SKILLS, id) else null
	return s.tier if s != null else 99


static func _write_set(p: PlayerProfile, i: int, s: Dictionary) -> void:
	while p.skill_sets.size() <= i:
		p.skill_sets.append({})
	p.skill_sets[i] = s.duplicate()
	if i == p.active_skill_set:
		p.loadout.skills = s.duplicate()


static func _pad(p: PlayerProfile, n: int) -> void:
	while p.held_skill_sets.size() < n:
		p.held_skill_sets.append({})
