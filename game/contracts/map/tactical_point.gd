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

func _ready() -> void:
	add_to_group(_GROUPS[kind])
