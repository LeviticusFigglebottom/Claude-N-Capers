## Spawn marker for players, guards, civilians, police, specials. Owner: LEAD.
## Group is assigned from `kind` at _ready. -Z = initial facing.
@tool
class_name SpawnPoint
extends Marker3D

enum Kind { PLAYER, GUARD, CIVILIAN, POLICE, SNIPER_PERCH, CAMERA_OPERATOR }

const _GROUPS: Dictionary = {
	Kind.PLAYER: G.PLAYER_SPAWN, Kind.GUARD: G.GUARD_SPAWN, Kind.CIVILIAN: G.CIVILIAN_SPAWN,
	Kind.POLICE: G.POLICE_SPAWN, Kind.SNIPER_PERCH: G.SNIPER_PERCH, Kind.CAMERA_OPERATOR: G.SECURITY_ROOM,
}

@export var kind: Kind = Kind.GUARD
## Spawn-table tags: e.g. [&"guard_lobby"], [&"civ_customer"], [&"police_street_north"], [&"preplan_spawn_b"]
@export var tags: Array[StringName] = []
@export var weight: float = 1.0
## Optional patrol graph this NPC should start on.
@export var patrol_graph: NodePath
## Civilians/staff: idle activity at spawn (&"browse", &"desk_work", &"queue", &"phone", &"sit").
@export var idle_activity: StringName = &""

func _ready() -> void:
	add_to_group(_GROUPS[kind])
