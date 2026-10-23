## A crew bot's ability or boost (L6.2, PD2 Crew Management). Owner: ENV B. Data: res://content/data/bot_crew/<name>.tres,
## id `bot_ability.<name>` / `bot_boost.<name>` (ContentDB kind `bot_crew`). Text: strings.csv `item.<id>.name` / `.desc`.
## Runtime (ENV A, BotCrew): an ability's `grants` land on the bot's own slot; a boost's are crew-wide while the bot is
## in play (not in custody). `params` are behaviour numbers (bot_ability.inspire: {range, cooldown}).
class_name BotCrewDef
extends Resource

const ABILITY: String = "ability"
const BOOST: String = "boost"

@export var id: StringName = &""
## "ability" | "boost" (one of each per bot).
@export var kind: String = ABILITY
## Modifier key -> value (contracts/modifier_keys.gd).
@export var grants: Dictionary = {}
@export var params: Dictionary = {}
## Picker order within its kind (then id).
@export var order: int = 0
