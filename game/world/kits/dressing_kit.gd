## Dressing kit schema: what a room of a given purpose must / may contain and how densely.
## Data: game/world/kits/<id>.tres (one per purpose variant). Owner: ENV C.
## Consumed by the kit placer (tools) and validate_level's density/variety checks
## (tools/levelcheck/README.md). Prop "kinds" are the `kind` metas on prop roots.
class_name DressingKit
extends Resource

@export var id: StringName = &""
## RoomVolume.purpose this kit dresses (e.g. &"break_room").
@export var purpose: StringName = &""
## Prop kinds that must appear at least once in every room using this kit
## (break room: fridge, table, chair, counter_service, sink, microwave, bulletin_board...).
@export var required_items: Array[StringName] = []
## Optional prop kinds -> relative weight for the placer.
@export var optional_items: Dictionary = {}
## Clutter groups: group id -> { "anchors": Array[StringName] (kinds/"wall"/"door"/"corner"),
## "items": Dictionary (kind -> weight), "count": Vector2i (per anchor), "radius": float (m) }.
## Clutter clusters around anchors; never scattered uniformly.
@export var clutter_groups: Dictionary = {}
## Props (all kinds, incl. mounted) per m² of floor; validated.
@export var min_density: float = 0.05
@export var max_density: float = 1.5
## Absolute minimum prop count for a room of this kit (small rooms); validated.
@export var min_props: int = 3
## Kinds that may stand alone (no neighbour within 2 m) even in rooms > 12 m² (e.g. pillars,
## floor safes). Empty = none.
@export var lone_ok_kinds: Array[StringName] = []
## Seed salt for the placer (layouts must differ between rooms; validated by `variety`).
@export var seed_salt: int = 0
@export_multiline var notes: String = ""
