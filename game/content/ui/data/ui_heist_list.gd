## Heist list shown by the heist-select screen (data: res://content/data/ui/heist_list.tres).
## Owner: ENV B. HeistDefs belong to ENV C; this list only says where to find them, so content code
## never hard-codes another env's folder. Entries whose def does not exist yet use the placeholder
## fields (contract pay preview, mode) until ENV C ships the def.
class_name UiHeistList
extends Resource

## Each entry: { "id": StringName, "def_path": String, "placeholder_base_payout": int,
##               "placeholder_mode": int (Enums.HeistMode) }.
## Display text is always strings.csv `heist.<id>.name` / `.subtitle` / `.brief`.
@export var entries: Array[Dictionary] = []
## Difficulties selectable in this build (Enums.Difficulty values); others show as locked (C4: P1 = 2).
@export var unlocked_difficulties: Array[int] = []
## AI teammates added by "Play solo" (contracts/test_hooks.md options.ai_teammates).
@export var solo_ai_teammates: int = 3
