## Static description of a heist (job board, briefing, payout). Owner: LEAD schema; data ENV C
## (world/heists/<id>/<id>_def.tres) with ENV B reading it for UI.
class_name HeistDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var contact: StringName = &""          ## &"contact.vance"
@export_multiline var briefing: String = ""
@export var mode: Enums.HeistMode = Enums.HeistMode.STEALTH_OR_LOUD
@export var map_scene: String = ""             ## res:// path (string to avoid load cycles)
@export var base_payout: int = 0
@export var stealth_bonus_mult: float = 1.15
@export var loot: Array[StringName] = []
@export var objectives: Array[StringName] = []
## Briefing list (ordered objective ids, the main path ending in secure / escape); empty = every id in `objectives`.
@export var briefing_objectives: Array[StringName] = []
## One line for the loud branch, "If it goes loud: <text>" (a strings key; &"" = no line).
@export var briefing_loud_key: StringName = &""
## Optional extras listed under a small "Optional" sub-head (objective ids).
@export var briefing_optional: Array[StringName] = []
## Pre-planning: available assets/plans: { id: { "cost": int, "favors": int, "slot": NodePath/StringName, "grants": Dictionary } }
@export var preplanning: Dictionary = {}
@export var escape_options: Array[StringName] = []    ## &"van", &"boat", &"heli", &"walk"
@export var music_track: StringName = &""
## How the crew starts (S1.3, D-065): &"casing" (default) or &"civilian" (undetectable, no gear until a gear_pickup).
@export var start_mode: StringName = &"casing"
## PO6-17 (D-114 §5, data_schemas.md v1.1): RNG assault event rows, each
## {kind: StringName (&"turret_van" | &"heli" | &"breach"), weight: float, min_wave: int, cooldown_s: float,
##  max_per_heist: int, params: Dictionary}. Non-empty = overrides AssaultEventsTweak.heists[id]; empty = the tweak's rows.
@export var assault_events: Array[Dictionary] = []
## D-130 (data_schemas.md v1.3): pagers the crew may answer, indexed by Enums.Difficulty; empty = StealthTweak.pager_max_answers.
@export var pager_max_by_difficulty: Array[int] = []
## D-130 (data_schemas.md v1.3): cameras are Titan from this Enums.Difficulty; -1 = StealthTweak.camera_titan_min_difficulty.
@export var camera_titan_min_difficulty: int = -1
