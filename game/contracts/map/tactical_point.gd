## Tactical marker for loud AI: cover, police entry/breach points, flank routes. Owner: LEAD.
@tool
class_name TacticalPoint
extends Marker3D

enum Kind { COVER, ENTRY, FLANK, SNIPER_PERCH, RAPPEL, SHIELD_ANCHOR }

const _GROUPS: Dictionary = {
	Kind.COVER: G.COVER_POINT, Kind.ENTRY: G.ENTRY_POINT, Kind.FLANK: &"flank_point",
	Kind.SNIPER_PERCH: G.SNIPER_PERCH, Kind.RAPPEL: &"rappel_point", Kind.SHIELD_ANCHOR: &"shield_anchor",
}

@export var kind: Kind = Kind.COVER
@export var tags: Array[StringName] = []
## For ENTRY points: is this a breachable window/door (VariantSlot may toggle).
@export var breachable: bool = false
## D-149 QC-RT1: off = out of its kind's group, so no consumer sees it (every lookup reads the groups live). Missions
## toggle it when a pre-baked nav region swaps in (RT convoy layouts, the mixer, the Tannery gate).
@export var enabled: bool = true:
	set(v):
		enabled = v
		if is_inside_tree():
			_sync_group()


func _ready() -> void:
	_sync_group()


func set_enabled(on: bool) -> void:
	enabled = on


func _sync_group() -> void:
	var g: StringName = _GROUPS[kind]
	if enabled and not is_in_group(g):
		add_to_group(g)
	elif not enabled and is_in_group(g):
		remove_from_group(g)
