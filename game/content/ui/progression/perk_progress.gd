## Perk deck progress for the perk deck screen (B4-03, pd2_fidelity P4). Owner: ENV B.
##
## Rule (D-034 QB-45): perk points are earned from total XP,
## earned = floor((PlayerProfile.xp + notoriety_xp) / PerkPointTweak.xp_per_perk_point) (data/tweak/perk_points.tres;
## notoriety_xp = XP a Notoriety rank-up moved out of `xp`, so ranking up never costs perk points); a deck's cards unlock in
## order (1..9) at their PerkDeckDef cost; every deck keeps its own progress (PlayerProfile.perk_cards)
## and available = earned - cost of every unlocked card. One deck is active (Loadout.perk_deck) and
## Loadout.perk_deck_cards mirrors its progress (sync()). `dev_unlock_all_perks` in the tweak makes
## every card of every deck unlocked for dev builds. Earned points are derived, never stored, so a
## change of the rate in data re-prices old profiles.
class_name PerkProgress
extends RefCounted

const REASON_UNKNOWN: StringName = &"unknown_deck"
const REASON_ALL: StringName = &"all_unlocked"
const REASON_POINTS: StringName = &"not_enough_points"


## Every deck in display order (tweak.deck_order first, then the rest by id).
static func decks(tw: ProgressionUiTweak) -> Array[PerkDeckDef]:
	var by_id: Dictionary = {}
	for r: Resource in ContentDB.all_of(ContentDB.PERKS):
		var d: PerkDeckDef = r as PerkDeckDef
		if d != null:
			by_id[d.id] = d
	var out: Array[PerkDeckDef] = []
	for id: StringName in tw.deck_order:
		if by_id.has(id):
			out.append(by_id[id] as PerkDeckDef)
			by_id.erase(id)
	var rest: Array = by_id.keys()
	ContentDB.sort_ids(rest)
	for id: Variant in rest:
		out.append(by_id[id] as PerkDeckDef)
	return out


static func deck(deck_id: StringName) -> PerkDeckDef:
	if deck_id == &"":
		return null
	return ContentDB.by_id(ContentDB.PERKS, deck_id) as PerkDeckDef


## `_tw` is unused (the rate is balance data in PerkPointTweak); kept for the existing call sites.
static func earned(p: PlayerProfile, _tw: ProgressionUiTweak) -> int:
	var rate: int = PerkPointTweak.current().xp_per_perk_point
	if rate <= 0:
		return 0
	return maxi(floori(float(p.xp + p.notoriety_xp) / float(rate)), 0)


## Points spent on unlocked cards across every deck.
static func spent(p: PlayerProfile) -> int:
	var total: int = 0
	for id: Variant in p.perk_cards:
		var d: PerkDeckDef = deck(StringName(id))
		if d == null:
			continue
		var n: int = clampi(int(p.perk_cards[id]), 0, d.cards.size())
		for i: int in range(n):
			total += int(d.cards[i].get("cost", 0))
	return total


static func available(p: PlayerProfile, tw: ProgressionUiTweak) -> int:
	return earned(p, tw) - spent(p)


static func cards_unlocked(p: PlayerProfile, deck_id: StringName, tw: ProgressionUiTweak) -> int:
	var d: PerkDeckDef = deck(deck_id)
	if d == null:
		return 0
	if tw.dev_unlock_all_perks:
		return d.cards.size()
	return clampi(int(p.perk_cards.get(deck_id, 0)), 0, d.cards.size())


## {ok, reason (REASON_* or &""), index (1-based card), cost, have (available points)}.
static func can_unlock_next(p: PlayerProfile, deck_id: StringName, tw: ProgressionUiTweak) -> Dictionary:
	var out: Dictionary = {"ok": false, "reason": &"", "index": 0, "cost": 0, "have": available(p, tw)}
	var d: PerkDeckDef = deck(deck_id)
	if d == null:
		out["reason"] = REASON_UNKNOWN
		return out
	var n: int = cards_unlocked(p, deck_id, tw)
	if n >= d.cards.size():
		out["reason"] = REASON_ALL
		return out
	out["index"] = n + 1
	out["cost"] = int(d.cards[n].get("cost", 0))
	if int(out["cost"]) > int(out["have"]):
		out["reason"] = REASON_POINTS
		return out
	out["ok"] = true
	return out


static func unlock_next(p: PlayerProfile, deck_id: StringName, tw: ProgressionUiTweak) -> Dictionary:
	var r: Dictionary = can_unlock_next(p, deck_id, tw)
	if bool(r["ok"]):
		p.perk_cards[deck_id] = int(r["index"])
		sync(p, tw)
	return r


## Make `deck_id` the active deck (writes Loadout.perk_deck and perk_deck_cards). False if unknown.
static func equip(p: PlayerProfile, deck_id: StringName, tw: ProgressionUiTweak) -> bool:
	if deck(deck_id) == null:
		return false
	p.loadout.perk_deck = deck_id
	sync(p, tw)
	return true


## Loadout.perk_deck_cards = the active deck's unlocked count.
static func sync(p: PlayerProfile, tw: ProgressionUiTweak) -> void:
	p.loadout.perk_deck_cards = cards_unlocked(p, p.loadout.perk_deck, tw)


## One line for loadout summaries: "Perk deck: Bulk (9/9 cards)", "Perk deck: none". D-164: an Understudy (Copycat)
## loadout adds its picks per choice card and the deck its card 9 copies.
static func summary_text(l: Loadout) -> String:
	var d: PerkDeckDef = deck(l.perk_deck) if l != null else null
	if d == null:
		return UiText.t(&"ui.loadout.perk_none")
	var text: String = UiText.t(&"ui.loadout.perk_summary", {"deck": UiText.t(StringName("%s.name" % d.id)),
			"cards": l.perk_deck_cards})
	var picks: PackedStringArray = PackedStringArray()
	for i: int in range(d.cards.size()):
		var choices: Array = d.cards[i].get("choices", []) as Array
		if not choices.is_empty():
			var c: Dictionary = choices[LoadoutResolver.chosen_option(l, d, i)] as Dictionary
			picks.append(UiText.t(StringName(String(c.get("name", "")))))
	if not picks.is_empty():
		text += " · " + " / ".join(picks)
	if d.cards.any(func(c: Dictionary) -> bool: return bool(c.get("mimic", false))):
		var m: PerkDeckDef = LoadoutResolver.mimic_deck(l)
		text += " · " + (UiText.t(&"ui.loadout.perk_copies", {"deck": UiText.t(StringName("%s.name" % m.id))}) if m != null
				else UiText.t(&"ui.loadout.perk_copies_none"))
	return text
