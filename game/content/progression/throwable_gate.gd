## Which throwables the loadout picker offers (D-073). Owner: ENV B. Static.
## Perk-deck throwables (the Composure flask, the Overlord injector) are never equipped from the picker:
## a deck grants them through its `perk.throwable` card (`item_id`, PerkHooks.throwable_id replaces the
## equipped throwable while the deck is active). Any throwable some deck's card names is perk-only here,
## so a new deck item is excluded without a list to keep in sync.
class_name ThrowableGate
extends RefCounted

const PERK_KEY: StringName = &"perk.throwable"


## Throwable ids granted by a perk deck card (`perk.throwable` item_id), in ContentDB id order.
static func perk_item_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for r: Variant in ContentDB.all_of(ContentDB.PERKS):
		var deck: PerkDeckDef = r as PerkDeckDef
		if deck == null:
			continue
		for card: Dictionary in deck.cards:
			var grants: Dictionary = card.get("grants", {})
			if grants.has(PERK_KEY):
				var id: StringName = StringName((grants[PERK_KEY] as Dictionary).get("item_id", &""))
				if id != &"" and not out.has(id):
					out.append(id)
	ContentDB.sort_ids(out)
	return out


## True for a known throwable that is not perk-only.
static func is_pickable(id: StringName) -> bool:
	return ContentDB.has(ContentDB.THROWABLES, id) and not perk_item_ids().has(id)


## The ThrowableDefs the loadout picker lists (ContentDB order, perk-only items left out).
static func pickable() -> Array[ThrowableDef]:
	var perk: Array[StringName] = perk_item_ids()
	var out: Array[ThrowableDef] = []
	for r: Variant in ContentDB.all_throwables():
		var def: ThrowableDef = r as ThrowableDef
		if def != null and not perk.has(def.id):
			out.append(def)
	return out
