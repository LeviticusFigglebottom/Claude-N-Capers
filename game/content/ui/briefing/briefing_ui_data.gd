## Briefing screen data (res://content/ui/briefing/briefing_ui.tres). Owner: ENV B.
## Holds layout/timing numbers and the placeholder briefing for heists whose HeistDef is not on
## trunk yet (HeistRegistry.get_def(id) == null). Placeholder entries are dropped automatically once
## the def exists; payout and mode then come from the def, and before that from HeistCatalog.
class_name BriefingUiData
extends Resource

## heist id -> placeholder briefing, every key optional:
##   "contact": StringName                 ContactDef id (`contact.vance`)
##   "briefing": String                    strings.csv key or literal text (like HeistDef.briefing)
##   "objectives": Array[StringName]       ids (`objective.<heist>.<id>` keys) like HeistDef.objectives
##   "loot": Array[StringName]             LootDef ids, like HeistDef.loot
##   "escape_options": Array[StringName]   &"van", &"boat", &"heli", &"walk"
@export var placeholder_heists: Dictionary = {}
## Contact used when a heist names none or an unknown one.
@export var fallback_contact: StringName = &"contact.mercer"

@export_group("Subtitles")
## A subtitle stays at least this long, plus `subtitle_s_per_char` per character of its text.
@export var subtitle_min_s: float = 2.5
@export var subtitle_s_per_char: float = 0.055
## Silence between two briefing lines.
@export var line_gap_s: float = 0.4

@export_group("Layout (px at the 1920x1080 base; canvas_items stretch scales it)")
@export var portrait_size: Vector2 = Vector2(360, 360)
@export var left_column_width: float = 380.0
@export var right_column_width: float = 520.0
@export var blueprint_min_height: float = 300.0

@export_group("Colours")
@export var portrait_bg: Color = Color(0.06, 0.07, 0.09, 1)
@export var silhouette_color: Color = Color(0.12, 0.13, 0.16, 1)
@export var blueprint_bg: Color = Color(0.05, 0.12, 0.22, 1)
@export var blueprint_grid: Color = Color(0.25, 0.45, 0.7, 0.35)
@export var blueprint_line: Color = Color(0.6, 0.8, 1.0, 0.85)
@export var placeholder_color: Color = Color(1, 0.75, 0.25, 1)
