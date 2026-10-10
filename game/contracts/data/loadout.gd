## A crew member's equipped loadout, resolved by ENV B before the heist and sent to the host.
## ENV A consumes it (weapons, deployables, armor, detection risk). Owner: LEAD.
class_name Loadout
extends Resource

@export var primary: StringName = &""
@export var primary_mods: Array[StringName] = []
@export var secondary: StringName = &""
@export var secondary_mods: Array[StringName] = []
@export var melee: StringName = &""
@export var throwable: StringName = &""
@export var deployable: StringName = &""
@export var deployable_secondary: StringName = &""
@export var armor: StringName = &""
@export var mask: StringName = &""
@export var perk_deck: StringName = &""
@export var perk_deck_cards: int = 0       ## unlocked card count 0..9
@export var skills: Dictionary = {}        ## skill_id -> 1 (basic) / 2 (aced)

## Filled in by ENV B's LoadoutResolver (single source of truth for these numbers):
@export var resolved_primary: WeaponStats
@export var resolved_secondary: WeaponStats
@export var concealment_total: int = 0
@export var detection_risk: int = 75       ## 3..75 like PD2; see pd2_fidelity.md §S2
## Modifier grants from skills + perk deck (key -> value), handed to Modifiers.set_source.
@export var modifiers: Dictionary = {}
