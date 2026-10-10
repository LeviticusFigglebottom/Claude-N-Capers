## Perk deck: 9 cards; odd cards = deck-specific, even cards = shared common cards (PD2 layout).
class_name PerkDeckDef
extends Resource

@export var id: StringName = &""           ## &"perk.composure"
@export var display_name: String = ""
@export_multiline var description: String = ""
## Exactly 9 entries: each { "name": String, "desc": String, "cost": int, "grants": Dictionary }
@export var cards: Array[Dictionary] = []
