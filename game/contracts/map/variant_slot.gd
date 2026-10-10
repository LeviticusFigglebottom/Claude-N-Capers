## A place where a per-run dynamic variable may land. Owner: LEAD.
## Contract: docs/contracts/heist_map.md §Variants.
##
## The VariantResolver (ENV A) reads the map's HeistVariantTable, picks which slots of each
## `slot_group` are active (GameRng stream &"variants"), then for each slot:
##   - active:   shows/enables children, instantiates `prefab` (if set) at this transform
##   - inactive: removes children (queue_free) so nothing of it remains in the scene
## ENV C places slots + the content children; ENV A never edits map scenes.
@tool
class_name VariantSlot
extends Node3D

## Group this slot competes in: &"keycard", &"camera", &"vault_code", &"open_window", &"guard_extra"...
@export var slot_group: StringName = &""
## Unique id within the heist (for logs, tests, and objectives referencing a specific option).
@export var slot_id: StringName = &""
@export var weight: float = 1.0
## Optional gameplay prefab (ENV A scene) to instantiate when active (e.g. keycard pickup, camera).
@export var prefab: PackedScene
## Free-form parameters passed to the prefab's `configure_variant(params)` if it has one.
@export var params: Dictionary = {}


func _ready() -> void:
	add_to_group(G.VARIANT_SLOT)
