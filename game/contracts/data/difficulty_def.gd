class_name DifficultyDef
extends Resource

@export var difficulty: Enums.Difficulty = Enums.Difficulty.ROUTINE
@export var display_name: String = ""
@export var payout_mult: float = 1.0
@export var xp_mult: float = 1.0
@export var enemy_cap: int = 20
@export var assault_intensity: float = 1.0
@export var special_limits: Dictionary = {}   ## special id -> max alive
@export var detection_speed_mult: float = 1.0
@export var civilian_kill_penalty: int = 0
@export var params: Dictionary = {}
