class_name ThrowableDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: StringName = &"frag"     ## &"frag", &"concussion", &"incendiary", &"throwing_knife", &"injector"...
@export var count: int = 3
@export var damage: float = 0.0
@export var radius_m: float = 5.0
@export var fuse_s: float = 2.5
@export var model: PackedScene
