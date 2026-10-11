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
##   "count": int target (default 1).
class_name AchievementDef
extends Resource

@export var id: StringName = &""
@export var name_key: StringName = &""
@export var desc_key: StringName = &""
@export var condition: Dictionary = {}
## Unlock id granted on completion (MaskLocker.grant_unlock), e.g. &"unlock.achievement.cataclysm_clear".
@export var unlock: StringName = &""
## Display order on the achievements screen (then id).
@export var order: int = 0


func target() -> int:
	return maxi(int(condition.get("count", 1)), 1)


func event() -> StringName:
	return StringName(condition.get("event", &""))
