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
## Pre-planning: available assets/plans: { id: { "cost": int, "favors": int, "slot": NodePath/StringName, "grants": Dictionary } }
@export var preplanning: Dictionary = {}
@export var escape_options: Array[StringName] = []    ## &"van", &"boat", &"heli", &"walk"
@export var music_track: StringName = &""
