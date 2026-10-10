## One skill (basic + aced). Effects are expressed ONLY as modifier grants (ModifierKeys).
class_name SkillDef
extends Resource

@export var id: StringName = &""           ## &"skill.ghost.cleaner"
@export var display_name: String = ""
@export var tree: StringName = &""         ## &"shade"
@export var subtree: StringName = &""      ## &"infiltrator"
@export var tier: int = 1                  ## 1..4 (tier 4 = capstone)
@export var cost_basic: int = 1
@export var cost_aced: int = 3
@export_multiline var desc_basic: String = ""
@export_multiline var desc_aced: String = ""
@export var grants_basic: Dictionary = {}  ## modifier key -> value
@export var grants_aced: Dictionary = {}   ## applied IN ADDITION to basic
