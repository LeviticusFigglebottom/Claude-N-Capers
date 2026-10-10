## Declares a room: purpose + bounds. Owner: LEAD.
## Used by validate_level (density, ceiling height, dressing-kit checks) and by AI search logic.
@tool
class_name RoomVolume
extends Area3D

@export var room_id: StringName = &""
## Purpose from the heist design doc room list: &"sales_floor", &"office", &"break_room",
## &"restroom", &"storage", &"security_room", &"vault", &"corridor", &"stair", &"exterior"...
@export var purpose: StringName = &""
@export var floor_index: int = 0
## Dressing kit id used (world/kits/<kit>.tres) for the density/variety check.
@export var dressing_kit: StringName = &""
