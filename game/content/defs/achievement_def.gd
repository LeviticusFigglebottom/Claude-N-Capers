## One achievement (B4-20 stub, pd2_fidelity P8 unlock source). Owner: ENV B.
## Data: res://content/data/achievements/<name>.tres, id `achievement.<name>` (ContentDB `achievements`).
## Logic: progression/achievements.gd (Achievements). Text: strings.csv `<id>.name` / `<id>.desc`.
##
## `condition` (event-driven, evaluated on the payday/apply path):
##   "event": StringName, one of
##     &"heist_completed" / &"heist_failed": +1 per matching HeistResult. Filters (all optional):
##       "heist": StringName (&"" = any), "difficulty_min": int (Enums.Difficulty, default 0),
##       "stealth": true = stealth runs only, "loud": true = loud runs only (absent/false = either),
##       "pro": true = pro Board jobs only.
##     &"stash_earned": + the payday's offshore share (PayoutCalculator "stash").
##     &"level_reached": progress = the profile's level (a high-water mark).
##   State conditions (B7-02; Achievements.sync after every payday and Notoriety rank-up; progress is a
##   high-water mark of the current value, so the career already on the profile counts):
##     &"career_stat": a Career counter (B7-01). "stat": a Career totals key (won, loud_wins, kills,
##       headshots, bags, cash_spent, ...); optional "heist": read that heist's counter instead; optional
##       "bag": read career.bags[<loot id>]. A counter the HeistResult never carried (D-071 shots / hits /
##       headshots) stays 0, so the achievement stays locked until the data exists.
##     &"notoriety_reached": progress = the Notoriety rank.
##     &"heists_all": distinct offered heists (HeistCatalog.ids()) won at least once; filters
##       "difficulty_min", "stealth", "loud" as above. "count" 0 (or absent) = every offered heist.
##   "count": int target (default 1).
##   Run conditions (D-115, heist_completed / heist_failed only; HeistConditions, all optional, fail closed):
##     HeistResult: "max_time_s", "max_time_variant", "max_kills", "max_civilian_kills", "max_downs",
##     "max_custody", "max_pagers", "min_bags", "loot_all", "loot_min"; in-heist fact log (HeistFacts):
##     "all_loot_secured", "objectives_completed", "objectives_not_completed", "facts_seen", "facts_not_seen".
class_name AchievementDef
extends Resource

@export var id: StringName = &""
@export var name_key: StringName = &""
@export var desc_key: StringName = &""
@export var condition: Dictionary = {}
## Unlock id granted on completion (MaskLocker.grant_unlock), e.g. &"unlock.achievement.cataclysm_clear" or a
## weapon finish &"unlock.finish.arctic" (B7-04).
@export var unlock: StringName = &""
## Display order on the achievements screen (then id).
@export var order: int = 0
## Screen category (strings `ui.achievements.category.<category>`): career, heists, stealth, loud, combat,
## wealth, notoriety (B7-02).
@export var category: StringName = &"career"
## Mask part ids granted directly on completion (MaskLocker.grant_part; colours, materials) (B7-02).
@export var rewards: Array[StringName] = []
## Extra unlock ids recorded on completion (MaskLocker.grant_unlock), beside `unlock` (B7-02). Weapon finishes
## (B7-04) use `unlock` itself (`unlock.finish.<id>`, one achievement each).
@export var unlocks: Array[StringName] = []
## Facts this achievement's condition only approximates until they exist (D-115 notes for ENV A, e.g.
## &"heist_result.loot_available"). Documentation only: the evaluator never reads it.
@export var requires_facts: Array[StringName] = []


func target() -> int:
	return maxi(int(condition.get("count", 1)), 1)


func event() -> StringName:
	return StringName(condition.get("event", &""))
