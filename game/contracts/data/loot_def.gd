class_name LootDef
extends Resource

@export var id: StringName = &""           ## &"loot.jewelry"
@export var display_name: String = ""
@export var weight: Enums.LootWeight = Enums.LootWeight.LIGHT
@export var value: int = 0                 ## base value; difficulty multiplier applied at payout
@export var bag_model: PackedScene         ## ENV C visual
@export var conceals: bool = false         ## e.g. small loot that doesn't need bags
