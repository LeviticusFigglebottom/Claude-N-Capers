## Root script of every heist map scene (world/heists/<id>/<id>.tscn). Owner: LEAD.
## Contract: docs/contracts/heist_map.md (v1). ENV C authors maps; ENV A's HeistRuntime consumes.
@tool
class_name HeistMap
extends Node3D

@export var heist_def: HeistDef
@export var variant_table: HeistVariantTable
## Floors: index -> finished floor height (m). Used by validate_level for stair/height checks.
@export var floor_heights: PackedFloat32Array = PackedFloat32Array([0.0])
## Optional display names per floor, parallel to floor_heights (e.g. "L40"); empty = named by height (QC-32).
@export var floor_names: PackedStringArray = PackedStringArray()


## Display name of floor `index`: floor_names when set, else "" (callers fall back to height naming).
func floor_name(index: int) -> String:
	return floor_names[index] if index >= 0 and index < floor_names.size() else ""
## Fixed camera positions for the review screenshot set (Marker3D/Camera3D children paths).
@export var review_cameras: Array[NodePath] = []


func get_slots(group: StringName) -> Array[Node]:
	var out: Array[Node] = []
	for n: Node in get_tree().get_nodes_in_group(group):
		if is_ancestor_of(n):
			out.append(n)
	return out


func get_variant_slots(slot_group: StringName) -> Array[VariantSlot]:
	var out: Array[VariantSlot] = []
	for n: Node in get_slots(G.VARIANT_SLOT):
		var vs: VariantSlot = n as VariantSlot
		if vs != null and vs.slot_group == slot_group:
			out.append(vs)
	return out
