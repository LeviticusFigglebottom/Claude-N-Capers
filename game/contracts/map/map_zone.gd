## Volume marking gameplay meaning of space. Owner: LEAD.
## RESTRICTED: being seen here in casing mode is suspicious (trespassing).
## PUBLIC: casing is fine. SECURE_LOOT: bags dropped/thrown inside are secured.
## ESCAPE: crew standing inside when escape is available ends the heist.
## BODY_HIDE: bodies (bagged) here are never discovered (dumpsters, closets).
@tool
class_name MapZone
extends Area3D

enum Kind { RESTRICTED, PUBLIC, SECURE_LOOT, ESCAPE, BODY_HIDE, NO_CIVILIAN }

const _GROUPS: Dictionary = {
	Kind.RESTRICTED: G.RESTRICTED_AREA, Kind.PUBLIC: G.CASING_PUBLIC_AREA,
	Kind.SECURE_LOOT: G.LOOT_SECURE_ZONE, Kind.ESCAPE: G.ESCAPE_ZONE,
	Kind.BODY_HIDE: G.BODY_HIDE_ZONE, Kind.NO_CIVILIAN: &"no_civilian_zone",
}

@export var kind: Kind = Kind.RESTRICTED
@export var zone_id: StringName = &""

func _ready() -> void:
	add_to_group(_GROUPS[kind])
	collision_layer = 1 << 9  # "triggers" layer (10)
	monitorable = true
