## PAYDAY card drop: roll 3 face-down cards, pick 1 (pd2_fidelity P9). Owner: ENV B. Static.
## Design and numbers: content/docs/payday_cards.md; table: content/data/payday/card_table.tres.
##
## roll(run_seed, slot, difficulty, profile, quality_add) -> {"seed", "cards", "auto_pick"}
##   cards: Array[Dictionary] {"type": StringName, "tier": int, "item_id": StringName (&"" for
##   cash/xp), "amount": int (0 for items)}. auto_pick: the card index used when the 30 s timer runs out.
## Determinism: one RandomNumberGenerator seeded like GameRng's named stream
## `payday_cards.<slot>` for the heist's run seed (hash([run_seed, "payday_cards.<slot>"])), so the
## same run seed, crew slot, difficulty, profile ownership and quality give the same cards. It is
## built locally because the payday screen runs after the run (GameRng may hold another seed).
## Draw order per card: type, tier, one quality roll per step, item index (only for items).
## Item cards only offer items the profile does not own yet, never two equal items in one roll, and
## a type whose pool is empty becomes `fallback_type` (cash) at the same tier.
## grant(profile, card) adds the reward to the profile (no save; the caller saves).
class_name PaydayCards
extends RefCounted

const TABLE_PATH: String = "res://content/data/payday/card_table.tres"
const STREAM_PREFIX: String = "payday_cards"
const QUALITY_KEY: StringName = &"progression.card_drop_quality_add"
const CASH: StringName = &"cash"
const XP: StringName = &"xp"
const WEAPON_MOD: StringName = &"weapon_mod"
const MASK_PART: StringName = &"mask_part"
const TYPES: Array[StringName] = [CASH, XP, WEAPON_MOD, MASK_PART]

static var _table: PaydayCardsTable


static func table() -> PaydayCardsTable:
	if _table == null:
		_table = load(TABLE_PATH) as PaydayCardsTable
		if _table == null:
			Log.error(&"payday", "card table missing: %s" % TABLE_PATH)
			_table = PaydayCardsTable.new()
	return _table


## Seed of the `payday_cards.<slot>` stream for a run seed (same formula as GameRng.stream).
static func seed_for(run_seed: int, slot: int) -> int:
	return hash([run_seed, "%s.%d" % [STREAM_PREFIX, slot]])


## The profile's `progression.card_drop_quality_add` (perk deck completion cards, D-031).
static func quality_add_for(profile: PlayerProfile) -> float:
	if profile == null:
		return 0.0
	var mods: Dictionary = LoadoutResolver.resolve(profile.loadout).modifiers
	return float(mods.get(QUALITY_KEY, 0.0))


static func roll(run_seed: int, slot: int, difficulty: int, profile: PlayerProfile,
		quality_add: float = 0.0, t: PaydayCardsTable = null) -> Dictionary:
	var tab: PaydayCardsTable = t if t != null else table()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_for(run_seed, slot)
	var cards: Array[Dictionary] = []
	var taken: Array[StringName] = []
	for i: int in range(maxi(tab.card_count, 1)):
		var card: Dictionary = _roll_card(rng, tab, difficulty, profile, quality_add, taken)
		if card["item_id"] != &"":
			taken.append(card["item_id"])
		cards.append(card)
	return {"seed": run_seed, "slot": slot, "cards": cards, "auto_pick": rng.randi_range(0, cards.size() - 1)}


## Unowned, droppable items of an item type (sorted ids). Weapon mods: every mod that is not a
## weapon's stock part. Mask parts: every available part that is not default-owned (hidden bases
## waiting for ENV D's mesh never drop), not a Notoriety reward (Notoriety.exclusive_ids) and not an achievement
## reward (Achievements.all_reward_ids; LEAD r278, PD2: achievement rewards never drop), plus the locked presets
## with `unlock.payday_card`.
static func pool(type: StringName, profile: PlayerProfile) -> Array[StringName]:
	var out: Array[StringName] = []
	match type:
		WEAPON_MOD:
			var stock: Dictionary = {}
			for w: Variant in ContentDB.all_weapons():
				for v: Variant in ((w as WeaponDef).default_mods as Dictionary).values():
					stock[StringName(v)] = true
			for m: Variant in ContentDB.all_mods():
				var id: StringName = (m as WeaponModDef).id
				if not stock.has(id) and (profile == null or not profile.owned_mods.has(id)):
					out.append(id)
		MASK_PART:
			var exclusive: Array[StringName] = Notoriety.exclusive_ids()
			var earned: Dictionary = Achievements.all_reward_ids()
			for kind: String in MaskCatalog.KINDS:
				for p: MaskPartDef in MaskCatalog.parts(kind):
					var locked: bool = p.unlock != &""  # B7-02: unlock-only parts (achievements, Notoriety) never drop
					if not p.default_owned and not locked and not exclusive.has(p.id) and not earned.has(p.id) \
							and not MaskLocker.is_part_owned(profile, p.id):
						out.append(p.id)
			for md: MaskDef in MaskCatalog.payday_presets():
				if not MaskLocker.is_drop_owned(profile, md.id):
					out.append(md.id)
	ContentDB.sort_ids(out)
	return out


## Adds the card's reward to the profile. False when nothing was granted (unknown type, item
## already owned). Cash goes to spending cash; XP updates the level (XpCurve).
static func grant(profile: PlayerProfile, card: Dictionary) -> bool:
	if profile == null:
		return false
	var item: StringName = StringName(card.get("item_id", &""))
	match StringName(card.get("type", &"")):
		CASH:
			profile.cash += int(card.get("amount", 0))
			return true
		XP:
			SaveService.apply_heist_payout(profile, {"xp_total": int(card.get("amount", 0))}, XpCurve.level_for_xp)
			return true
		WEAPON_MOD:
			if ContentDB.mod(item) == null or profile.owned_mods.has(item):
				return false
			profile.owned_mods.append(item)
			ContentDB.sort_ids(profile.owned_mods)
			return true
		MASK_PART:
			if MaskCatalog.is_preset_id(item):
				return MaskLocker.grant_preset(profile, item)
			return MaskLocker.grant_part(profile, item)
	return false


## The weapon whose mod slots list `mod_id` (first by id), or &"".
static func weapon_for_mod(mod_id: StringName) -> StringName:
	for w: Variant in ContentDB.all_weapons():
		for ids: Variant in ((w as WeaponDef).mod_slots as Dictionary).values():
			if (ids as Array).has(mod_id) or (ids as Array).has(String(mod_id)):
				return (w as WeaponDef).id
	return &""


static func _roll_card(rng: RandomNumberGenerator, tab: PaydayCardsTable, difficulty: int,
		profile: PlayerProfile, quality_add: float, taken: Array[StringName]) -> Dictionary:
	var type_i: int = rng.rand_weighted(tab.type_row(difficulty))
	var type: StringName = tab.types[type_i] if type_i >= 0 and type_i < tab.types.size() else tab.fallback_type
	var tier: int = maxi(rng.rand_weighted(tab.tier_row(difficulty)), 0)
	for _step: int in range(tab.quality_max_steps):
		if rng.randf() < quality_add:
			tier += 1
	tier = clampi(tier, 0, tab.tier_count() - 1)
	if type == WEAPON_MOD or type == MASK_PART:
		var candidates: Array[StringName] = _item_candidates(tab, type, profile, tier, taken)
		if not candidates.is_empty():
			var id: StringName = candidates[rng.randi_range(0, candidates.size() - 1)]
			return {"type": type, "tier": tab.item_tier(id), "item_id": id, "amount": 0}
		type = tab.fallback_type
	return {"type": type, "tier": tier, "item_id": &"", "amount": amount_for(tab, type, tier, difficulty)}


## Cash / XP amount of a card (0 for item types).
static func amount_for(tab: PaydayCardsTable, type: StringName, tier: int, difficulty: int) -> int:
	var base: PackedInt32Array
	var mults: PackedFloat32Array
	var step: int = 1
	if type == CASH:
		base = tab.cash_by_tier
		mults = tab.cash_difficulty_mult
		step = tab.cash_round
	elif type == XP:
		base = tab.xp_by_tier
		mults = tab.xp_difficulty_mult
		step = tab.xp_round
	else:
		return 0
	if base.is_empty():
		return 0
	var mult: float = mults[clampi(difficulty, 0, mults.size() - 1)] if not mults.is_empty() else 1.0
	var raw: float = float(base[clampi(tier, 0, base.size() - 1)]) * mult
	step = maxi(step, 1)
	return roundi(raw / float(step)) * step


## Items of the rolled tier; if none, the nearest lower tier, then the nearest higher one.
static func _item_candidates(tab: PaydayCardsTable, type: StringName, profile: PlayerProfile,
		tier: int, taken: Array[StringName]) -> Array[StringName]:
	var by_tier: Dictionary = {}
	for id: StringName in pool(type, profile):
		if taken.has(id):
			continue
		var it: int = tab.item_tier(id)
		if not by_tier.has(it):
			var fresh: Array[StringName] = []
			by_tier[it] = fresh
		(by_tier[it] as Array[StringName]).append(id)
	var order: Array[int] = []
	for i: int in range(tier, -1, -1):
		order.append(i)
	for i: int in range(tier + 1, tab.tier_count()):
		order.append(i)
	for i: int in order:
		if by_tier.has(i):
			return by_tier[i] as Array[StringName]
	return []
