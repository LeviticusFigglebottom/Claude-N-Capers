## Menu-side heist data (res://content/data/ui/heist_list.tres). Owner: ENV B.
## Which heists exist comes from HeistRegistry (core, D-024); HeistDefs belong to ENV C. This list
## only holds UI data keyed by heist id, plus a placeholder for heists whose def has not landed yet.
class_name UiHeistList
extends Resource

## heist id (StringName) -> per-heist UI data, every key optional:
##   "solo_ai_teammates": int            overrides the default below for "Play solo"
##   "placeholder_base_payout": int      UNSCALED contract pay (like HeistDef.base_payout) and
##   "placeholder_mode": int             Enums.HeistMode: list the heist as a placeholder while
##                                       HeistRegistry.get_def(id) is null (dropped once it exists)
## Display text is always strings.csv `heist.<id>.name` / `.subtitle` / `.brief`.
@export var heists: Dictionary = {}
## Difficulties selectable in this build (Enums.Difficulty values); others show as locked (C4: P1 = 2).
@export var unlocked_difficulties: Array[int] = []
## Default AI teammates added by "Play solo" (contracts/test_hooks.md options.ai_teammates).
@export var solo_ai_teammates: int = 3


## AI teammates for a solo launch of `heist_id`.
func solo_ai_for(heist_id: StringName) -> int:
	var d: Dictionary = heists.get(heist_id, {}) as Dictionary
	return int(d.get("solo_ai_teammates", solo_ai_teammates))
