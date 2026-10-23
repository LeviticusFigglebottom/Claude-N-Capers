## Perk deck: 9 cards; odd cards = deck-specific, even cards = shared common cards (PD2 layout).
class_name PerkDeckDef
extends Resource

@export var id: StringName = &""           ## &"perk.composure"
@export var display_name: String = ""
@export_multiline var description: String = ""
## Exactly 9 entries: each { "name": String, "desc": String, "cost": int, "grants": Dictionary }
## D-164 (Copycat), optional per card: "choices": [{name, desc, grants}] = pick one (Loadout.perk_choices) on top of
## "grants"; "mimic": true = the card also grants Loadout.perk_mimic_deck's mimic_grants.
@export var cards: Array[Dictionary] = []
## D-164: what Copycat's mimic card grants when it copies this deck (this deck's card 9 as standalone keys).
@export var mimic_grants: Dictionary = {}
## D-164: false for decks whose card 9 only works with their own deck item (PD2's mimicry list leaves them out).
@export var mimicable: bool = false
