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
## D-073: chosen heister (&"rook" | &"sable" | &"dutch" | &"wren"); &"" = generic crew (no FP sleeve variant).
@export var heister: StringName = &""
## D-074: equipped weapon finishes (weapon_id -> finish_id, ENV B B7-04); teammates see them via the replicated loadout.
@export var weapon_finishes: Dictionary = {}
## Custom mask descriptor (ENV B MaskCatalog format) so every peer renders the same mask; {} = preset `mask` (QA-25).
@export var mask_descriptor: Dictionary = {}
@export var perk_deck: StringName = &""
@export var perk_deck_cards: int = 0       ## unlocked card count 0..9
## D-164 (Copycat): card index (0-based) -> chosen option index of that card's "choices"; missing = option 0.
@export var perk_choices: Dictionary = {}
## D-164 (Copycat): the deck whose mimic_grants the "mimic" card grants; &"" = none.
@export var perk_mimic_deck: StringName = &""
@export var skills: Dictionary = {}        ## skill_id -> 1 (basic) / 2 (aced)
## L6.2: AI teammates only (PD2 Crew Management). &"" = none; ids from ENV B's bot crew data.
@export var bot_ability: StringName = &""  ## e.g. &"bot_ability.inspire" (on the bot's own slot)
@export var bot_boost: StringName = &""    ## e.g. &"bot_boost.ammo" (crew-wide while the bot is free)

## Filled in by ENV B's LoadoutResolver (single source of truth for these numbers):
@export var resolved_primary: WeaponStats
@export var resolved_secondary: WeaponStats
@export var concealment_total: int = 0
@export var detection_risk: int = 75       ## 3..75 like PD2; see pd2_fidelity.md §S2
## Modifier grants from skills + perk deck (key -> value), handed to Modifiers.set_source.
@export var modifiers: Dictionary = {}
