## Interaction framework tunables (S9.1-S9.3, S10.3, S6.2, S7.2). Owner: ENV A.
class_name InteractionTweak
extends Resource

## Server aim resolution: ray length and assist cone (crew_intent.md).
@export var reach_m: float = 2.0
@export var assist_cone_deg: float = 10.0
## Explicit-target interactions (bots/AI) allow a slightly longer reach.
@export var explicit_reach_m: float = 2.5
## S9.1: moving further than this from the start position cancels.
@export var cancel_move_m: float = 0.5
## S9.1: looking away more than this (aimed interactions only) cancels.
@export var cancel_look_deg: float = 40.0

@export_group("Default durations (s)")
@export var lockpick_door_s: float = 8.0
@export var keycard_s: float = 1.0
@export var drill_place_s: float = 3.0
@export var drill_fix_s: float = 2.0
@export var body_bag_s: float = 3.0
@export var cable_tie_s: float = 2.0
@export var small_loot_s: float = 0.75
@export var bag_loot_s: float = 1.0
@export var pager_answer_s: float = 10.0
@export var item_pickup_s: float = 0.5
@export var door_open_s: float = 0.0
@export var revive_s: float = 6.0

@export_group("Noise radii (S4.3)")
## noise profile id -> radius in m. "silent" = 0.
@export var noise_profiles: Dictionary = {&"silent": 0.0, &"quiet": 5.0, &"loud": 25.0}
