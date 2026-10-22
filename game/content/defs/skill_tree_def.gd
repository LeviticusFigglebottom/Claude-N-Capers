## Skill tree layout and rules (pd2_fidelity.md P1/P2). Owner: ENV B. Data: content/data/skills/trees.tres.
## Design doc: content/docs/skills.md.
##
## * `trees` (display order) -> `subtrees[tree]` (display order) -> `layout[subtree]` = 4 tiers, each an
##   Array of skill ids (tier sizes 1/2/2/1). SkillDef.tree/subtree/tier must agree (tested).
## * Tier gate: a tier-t skill needs `tier_thresholds[t - 1]` points spent on LOWER tiers of the same
##   subtree (0/1/3/18). Counting only lower tiers makes the rule order-independent (PD2 unlocks a tier
##   once enough points are in the subtree, which can only be lower-tier points at that moment).
## * Cost per tier: basic `tier_cost_basic[t - 1]`, aced adds `tier_cost_aced[t - 1]` (1/3, 2/4, 3/6, 4/8).
## * Points: level * points_per_level + floor(level / bonus_every_levels) * bonus_points (120 at 100).
## * Team skills: a grant whose key starts with `team_key_prefix` is crew-wide; LoadoutResolver hands it to
##   the TEAM scope as source `team_source_prefix + skill_id` so the same skill never stacks.
## * `blocked_on_keys`: "<skill_id>:basic|aced" -> Array of modifier keys the part grants that no runtime code reads
##   yet (LEAD r280: the P4 coverage ratchet's UNHOOKED list; content/docs/unhooked_skill_keys.md). UI only: the skill
##   tree marks those parts "Not active yet". Kept equal to the ratchet by test_blocked_parts_track_the_unhooked_keys.
## * `unlocks`: "<skill_id>:basic|aced" -> item id the part unlocks through the item's own data
##   (ArmorDef.unlock_skill), not through a modifier grant.
class_name SkillTreeDef
extends Resource

const PATH: String = "res://content/data/skills/trees.tres"

@export var trees: Array[StringName] = []
@export var subtrees: Dictionary = {}          ## tree -> Array of subtree ids (display order)
@export var layout: Dictionary = {}            ## subtree -> [[t1 ids], [t2 ids], [t3 ids], [t4 ids]]
@export var tier_sizes: Array[int] = [1, 2, 2, 1]
@export var tier_thresholds: Array[int] = [0, 1, 3, 18]
@export var tier_cost_basic: Array[int] = [1, 2, 3, 4]
@export var tier_cost_aced: Array[int] = [3, 4, 6, 8]
@export var points_per_level: int = 1
@export var bonus_every_levels: int = 10
@export var bonus_points: int = 2
@export var max_level: int = 100
@export var respec_cost: int = 0
@export var team_key_prefix: String = "team."
@export var team_source_prefix: String = "team_skill."
@export var blocked_on_keys: Dictionary = {}
@export var unlocks: Dictionary = {}


static func load_default() -> SkillTreeDef:
	return ResourceLoader.load(PATH) as SkillTreeDef


## Every skill id in display order (tree, subtree, tier, slot).
func all_skill_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for tree: StringName in trees:
		for sub: Variant in subtrees.get(tree, []):
			for tier_ids: Variant in layout.get(StringName(sub), []):
				for sid: Variant in tier_ids:
					out.append(StringName(sid))
	return out


func subtree_ids(tree: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for sub: Variant in subtrees.get(tree, []):
		out.append(StringName(sub))
	return out


func threshold_for_tier(tier: int) -> int:
	return tier_thresholds[clampi(tier, 1, tier_thresholds.size()) - 1]


func is_team_key(key: StringName) -> bool:
	return String(key).begins_with(team_key_prefix)


func team_source(skill_id: StringName) -> StringName:
	return StringName(team_source_prefix + String(skill_id))
