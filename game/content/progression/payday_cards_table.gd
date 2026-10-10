## PAYDAY card drop table (pd2_fidelity P9; `content/data/payday/card_table.tres`). Owner: ENV B.
## Has no `id` property, so ContentDB skips it. Design + numbers: content/docs/payday_cards.md.
## Rows indexed by difficulty (Enums.Difficulty order); a missing row falls back to the last one.
class_name PaydayCardsTable
extends Resource

## Card types this table can drop. Known types: &"cash", &"xp", &"weapon_mod", &"mask_part"
## (PaydayCards.TYPES). Boosts and skins have no game system yet and are not listed.
@export var types: Array[StringName] = []
## One row per difficulty, parallel to `types`: relative weights of each card type.
@export var type_weights: Array[PackedFloat32Array] = []
## One row per difficulty: relative weights of each quality tier (index = tier, 0 = lowest).
@export var tier_weights: Array[PackedFloat32Array] = []
## Number of cards offered (PD2: 3).
@export var card_count: int = 3
## Seconds before a card is picked automatically (PD2: 30).
@export var pick_time_s: float = 30.0
## How many tiers `progression.card_drop_quality_add` can raise one card (one roll per step).
@export var quality_max_steps: int = 1
## Type used when a type's item pool is empty (everything owned).
@export var fallback_type: StringName = &"cash"

@export_group("Amounts")
## Cash per tier (spending cash), before the difficulty multiplier.
@export var cash_by_tier: PackedInt32Array = PackedInt32Array()
## Cash multiplier per difficulty.
@export var cash_difficulty_mult: PackedFloat32Array = PackedFloat32Array()
## Cash is rounded to a multiple of this.
@export var cash_round: int = 1000
## XP per tier, before the difficulty multiplier.
@export var xp_by_tier: PackedInt32Array = PackedInt32Array()
@export var xp_difficulty_mult: PackedFloat32Array = PackedFloat32Array()
@export var xp_round: int = 100

@export_group("Items")
## Quality tier of droppable items (weapon mods, mask parts): id -> tier. Unlisted items are tier 0.
@export var item_tiers: Dictionary = {}

@export_group("Visuals")
## Card face accent per tier (index = tier).
@export var tier_colors: PackedColorArray = PackedColorArray()
## Card face band colour per type: type -> Color.
@export var type_colors: Dictionary = {}


func tier_count() -> int:
	return maxi(tier_weights[0].size(), 1) if not tier_weights.is_empty() else 1


func type_row(difficulty: int) -> PackedFloat32Array:
	return _row(type_weights, difficulty)


func tier_row(difficulty: int) -> PackedFloat32Array:
	return _row(tier_weights, difficulty)


func item_tier(id: StringName) -> int:
	return clampi(int(item_tiers.get(id, item_tiers.get(String(id), 0))), 0, tier_count() - 1)


static func _row(rows: Array[PackedFloat32Array], difficulty: int) -> PackedFloat32Array:
	if rows.is_empty():
		return PackedFloat32Array()
	return rows[clampi(difficulty, 0, rows.size() - 1)]
