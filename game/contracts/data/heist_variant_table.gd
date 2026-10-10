## Per-heist dynamic variable table. Owner: LEAD schema; data ENV C; resolved by ENV A.
## Contract: docs/contracts/heist_map.md §Variants.
class_name HeistVariantTable
extends Resource

## Each rule: {
##   "group": StringName,            # VariantSlot.slot_group this rule controls
##   "pick": Vector2i,               # [min, max] active slots (inclusive), rolled uniformly
##   "difficulty_add": Array[int],   # optional per-Difficulty extra picks (e.g. more guards)
##   "requires": Dictionary,         # optional: {"other_group": [slot_ids]} only roll if any active
##   "excludes": Dictionary,         # optional: {"other_group": [slot_ids]} slot conflicts
## }
@export var rules: Array[Dictionary] = []

## Rare outcomes: { "id": StringName, "chance": float, "effects": Dictionary, "good": bool }
## effects keys interpreted by HeistRuntime / map script, e.g.
## {"force_active": {"group": &"vault_state", "slot": &"vault_open"}}, {"modifier_team": {...}}
@export var rare_events: Array[Dictionary] = []

## Scalar variables: { "id": StringName, "values": Array, "weights": PackedFloat32Array }
## e.g. escape type/timing, civilian count range, guard count range.
@export var scalars: Array[Dictionary] = []
