## D-145.4 / PO-19: the crew bots' loadouts, one per bot slot (PlayerProfile.crew_loadouts, save v10). Owner: ENV B.
## A bot slot equips a primary (any primary the player owns, with owned mods for it), an armor the player has unlocked
## (ArmorDef.unlock_level / unlock_skill), a mask the player can wear and an outfit: an unlocked heister (one of each per
## crew: a heister a human or an earlier bot holds falls back to the next free one, Heisters.assign) or a heist suit
## (CrewTweak.body_scenes keys starting SUIT_PREFIX, any number of bots). Nothing is bought here: the bots draw on the
## player's armory (weapons and mods bought in the Workshop), so a gun is never "used up" by a bot.
## Every id is checked when used (validate): an unowned, retired or wrong-slot id reads as &"" = the bot's default
## (A's CombatTweak default primary / armor, no mask, any free heister), so a save never breaks a launch.
## Bot slot i = the i-th AI seat in slot order (Heisters.ai_loadouts, LobbyState.heister_assignment).
## ENV A's runtime: for_slot(i) (defs) or the bot's launch Loadout (bot_loadout, via HeistLauncher options.loadouts).
## L6.2 (PD2 Crew Management): each bot also carries one ability and one boost (BotCrewDef ids, ContentDB kind bot_crew;
## &"" = none), written to Loadout.bot_ability / bot_boost for ENV A's BotCrew. They are free picks (PD2 sells them for
## Continental Coins; we have no second currency).
class_name CrewLoadouts
extends RefCounted

const SLOTS: int = ProfileSchema.CREW_SLOTS
## CrewTweak.body_scenes keys that are generic heist suits (D's crew_body / crew_body_b), wearable by any number of bots.
const SUIT_PREFIX: String = "suit_"
const FIELDS: Array[String] = ["weapon", "mods", "armor", "mask", "outfit", "ability", "boost"]

## The profile the bots read when a caller passes none (MenuFlow sets it to the host's profile before a launch).
static var source: PlayerProfile = null


## An empty entry: every field the bot's default.
static func empty_entry() -> Dictionary:
	return {"weapon": &"", "mods": [] as Array[StringName], "armor": &"", "mask": &"", "outfit": &"", "ability": &"",
		"boost": &""}


## Bot slot `i`'s saved entry (empty when `profile` is null or `i` is out of range). A copy.
static func entry(profile: PlayerProfile, i: int) -> Dictionary:
	if profile == null or i < 0 or i >= profile.crew_loadouts.size():
		return empty_entry()
	var e: Dictionary = profile.crew_loadouts[i]
	var out: Dictionary = empty_entry()
	for f: String in ["weapon", "armor", "mask", "outfit", "ability", "boost"]:
		out[f] = StringName(e.get(f, &""))
	var typed: Array[StringName] = []
	for m: Variant in e.get("mods", []) as Array:
		typed.append(StringName(m))
	out["mods"] = typed
	return out


## Store `e` (validated against `profile`) in bot slot `i`. False when `i` is out of range.
static func set_entry(profile: PlayerProfile, i: int, e: Dictionary) -> bool:
	if profile == null or i < 0 or i >= SLOTS:
		return false
	while profile.crew_loadouts.size() < SLOTS:
		profile.crew_loadouts.append(empty_entry())
	profile.crew_loadouts[i] = validate(profile, e)
	return true


## `e` with every id the player cannot give a bot replaced by the default (see the header).
static func validate(profile: PlayerProfile, e: Dictionary) -> Dictionary:
	var out: Dictionary = empty_entry()
	var w: StringName = StringName(e.get("weapon", &""))
	if weapons(profile).has(w):
		out["weapon"] = w
		var per_type: Dictionary = {}
		for m: Variant in e.get("mods", []) as Array:
			var t: int = _mod_type_in(ContentDB.weapon(w), StringName(m))
			if t >= 0 and profile.owned_mods.has(StringName(m)):
				per_type[t] = StringName(m)  # one per slot, the last wins
		var mods: Array[StringName] = []
		for t: Variant in per_type:
			mods.append(per_type[t])
		out["mods"] = mods
	if armors(profile).has(StringName(e.get("armor", &""))):
		out["armor"] = StringName(e["armor"])
	if masks(profile).has(StringName(e.get("mask", &""))):
		out["mask"] = StringName(e["mask"])
	if outfits(profile).has(StringName(e.get("outfit", &""))):
		out["outfit"] = StringName(e["outfit"])
	if abilities().has(StringName(e.get("ability", &""))):
		out["ability"] = StringName(e["ability"])
	if boosts().has(StringName(e.get("boost", &""))):
		out["boost"] = StringName(e["boost"])
	return out


## L6.2: every bot ability id (picker order), and every boost id.
static func abilities() -> Array[StringName]:
	return _bot_crew_ids(BotCrewDef.ABILITY)


static func boosts() -> Array[StringName]:
	return _bot_crew_ids(BotCrewDef.BOOST)


static func _bot_crew_ids(kind: String) -> Array[StringName]:
	var out: Array[StringName] = []
	for d: BotCrewDef in ContentDB.bot_crew(kind):
		out.append(d.id)
	return out


## Primaries the player owns (owned_weapons order).
static func weapons(profile: PlayerProfile) -> Array[StringName]:
	var out: Array[StringName] = []
	if profile == null:
		return out
	for id: StringName in profile.owned_weapons:
		var w: WeaponDef = ContentDB.weapon(id) if ContentDB.has(ContentDB.WEAPONS, id) else null
		if w != null and w.slot == Enums.WeaponSlot.PRIMARY and not out.has(id):
			out.append(id)
	return out


## ModType -> the owned mods weapon `weapon_id` takes in that slot (its stock part excluded: &"" is stock).
static func mods(profile: PlayerProfile, weapon_id: StringName) -> Dictionary:
	var out: Dictionary = {}
	var w: WeaponDef = ContentDB.weapon(weapon_id) if profile != null and ContentDB.has(ContentDB.WEAPONS, weapon_id) else null
	if w == null:
		return out
	for t: Variant in w.mod_slots:
		var ids: Array[StringName] = []
		for m: Variant in w.mod_slots[t] as Array:
			var id: StringName = StringName(m)
			if id != StringName(w.default_mods.get(t, &"")) and profile.owned_mods.has(id):
				ids.append(id)
		if not ids.is_empty():
			out[int(t)] = ids
	return out


## Armors the player has unlocked (level >= unlock_level; an unlock_skill must be in the loadout's skills).
static func armors(profile: PlayerProfile) -> Array[StringName]:
	var out: Array[StringName] = []
	if profile == null:
		return out
	for r: Variant in ContentDB.all_armors():
		var a: ArmorDef = r as ArmorDef
		if a == null or profile.level < a.unlock_level:
			continue
		if a.unlock_skill != &"" and int(profile.loadout.skills.get(a.unlock_skill, 0)) <= 0:
			continue
		out.append(a.id)
	return out


## Masks the player can wear (presets owned or unlocked, saved custom masks): MaskLocker.available_ids.
static func masks(profile: PlayerProfile) -> Array[StringName]:
	return MaskLocker.available_ids(profile) if profile != null else [] as Array[StringName]


## Outfits: the heisters the player has unlocked (roster order), then the heist suits.
static func outfits(profile: PlayerProfile) -> Array[StringName]:
	var out: Array[StringName] = []
	if profile == null:
		return out
	for id: StringName in Heisters.ids():
		if Heisters.is_unlocked(profile, id):
			out.append(id)
	out.append_array(suits())
	return out


## CrewTweak.body_scenes keys that are heist suits (sorted).
static func suits() -> Array[StringName]:
	var out: Array[StringName] = []
	for k: StringName in Tweak.crew().body_scenes.keys():
		if String(k).begins_with(SUIT_PREFIX):
			out.append(k)
	out.sort()
	return out


static func is_suit(outfit: StringName) -> bool:
	return String(outfit).begins_with(SUIT_PREFIX)


## ENV A's runtime API: bot slot `i`'s validated loadout as defs. {"weapon": WeaponDef or null (= default),
## "mods": Array[WeaponModDef], "armor": ArmorDef or null (= default), "mask": StringName (&"" = none),
## "outfit": StringName (&"" = any free heister)}. `profile` null = `source`.
static func for_slot(i: int, profile: PlayerProfile = null) -> Dictionary:
	var p: PlayerProfile = profile if profile != null else source
	var e: Dictionary = validate(p, entry(p, i)) if p != null else empty_entry()
	var mod_defs: Array[WeaponModDef] = []
	for m: StringName in e["mods"] as Array[StringName]:
		var md: WeaponModDef = ContentDB.mod(m)
		if md != null:
			mod_defs.append(md)
	return {"weapon": ContentDB.weapon(e["weapon"]) if e["weapon"] != &"" else null, "mods": mod_defs,
		"armor": ContentDB.armor(e["armor"]) if e["armor"] != &"" else null, "mask": e["mask"], "outfit": e["outfit"]}


## Bot slot `i`'s launch Loadout: A's default bot loadout (CrewWeapons.build_loadout(null)) with the slot's primary
## and mods, armor and mask on top, resolved against `profile` (custom mask descriptor), wearing `heister`.
static func bot_loadout(i: int, profile: PlayerProfile, heister: StringName) -> Loadout:
	var l: Loadout = CrewWeapons.build_loadout(null)  # a fresh Loadout per call
	var e: Dictionary = validate(profile, entry(profile, i)) if profile != null else empty_entry()
	if e["weapon"] != &"":
		l.primary = e["weapon"]
		l.primary_mods = (e["mods"] as Array[StringName]).duplicate()
		l.resolved_primary = null
	if e["armor"] != &"":
		l.armor = e["armor"]
	if e["mask"] != &"":
		l.mask = e["mask"]
	l = LoadoutResolver.resolve(l, profile)
	l.heister = heister
	l.bot_ability = e["ability"]
	l.bot_boost = e["boost"]
	return l


## AI seat -> preferred outfit for Heisters.assign: the i-th of `ai_slots` (slot order) takes bot slot i's outfit.
static func outfit_picks(profile: PlayerProfile, ai_slots: Array[int]) -> Dictionary:
	var out: Dictionary = {}
	var order: Array[int] = ai_slots.duplicate()
	order.sort()
	for i: int in range(mini(order.size(), SLOTS)):
		var o: StringName = StringName(validate(profile, entry(profile, i))["outfit"]) if profile != null else &""
		if o != &"":
			out[order[i]] = o
	return out


## JSON-safe validated entries for the host's lobby summary (LobbyState "crew").
static func summary(profile: PlayerProfile) -> Array:
	var out: Array = []
	for i: int in range(SLOTS):
		var e: Dictionary = validate(profile, entry(profile, i))
		var mods_s: Array = []
		for m: StringName in e["mods"] as Array[StringName]:
			mods_s.append(String(m))
		out.append({"weapon": String(e["weapon"]), "mods": mods_s, "armor": String(e["armor"]), "mask": String(e["mask"]),
			"outfit": String(e["outfit"]), "ability": String(e["ability"]), "boost": String(e["boost"])})
	return out


## Display names for an entry ({"weapon", "armor", "mask", "outfit", "ability", "boost"}; the default's own label when
## empty).
static func names(e: Dictionary) -> Dictionary:
	var w: StringName = StringName(e.get("weapon", &""))
	var a: StringName = StringName(e.get("armor", &""))
	var m: StringName = StringName(e.get("mask", &""))
	var o: StringName = StringName(e.get("outfit", &""))
	return {
		"weapon": UiText.t(UiText.item_key(w)) if w != &"" else default_weapon_name(),
		"armor": UiText.t(UiText.item_key(a)) if a != &"" else default_armor_name(),
		"mask": MaskCatalog.display_name(m) if m != &"" else UiText.t(&"ui.crew.no_mask"),
		"outfit": outfit_name(o),
		"ability": _bot_crew_name(StringName(e.get("ability", &"")), &"ui.crew.no_ability"),
		"boost": _bot_crew_name(StringName(e.get("boost", &"")), &"ui.crew.no_boost"),
	}


static func _bot_crew_name(id: StringName, none_key: StringName) -> String:
	return UiText.t(UiText.item_key(id)) if id != &"" else UiText.t(none_key)


## r246: the default's label names what an unequipped bot carries (A's CombatTweak.bot_default_primary /
## default_armor, "Standard: Corsair AR"), not a generic "Standard issue"; the generic label when the tweak has none.
static func default_weapon_name() -> String:
	return _standard(CombatTweak.data().bot_default_primary, &"ui.crew.default_weapon")


static func default_armor_name() -> String:
	return _standard(CombatTweak.data().default_armor, &"ui.crew.default_armor")


static func _standard(id: StringName, generic: StringName) -> String:
	if id == &"":
		return UiText.t(generic)
	return UiText.t(&"ui.crew.default_named", {"name": UiText.t(UiText.item_key(id))})


static func outfit_name(o: StringName) -> String:
	if o == &"":
		return UiText.t(&"ui.crew.any_heister")
	if is_suit(o):
		return UiText.t(StringName("ui.crew.outfit.%s" % o))
	return Heisters.display_name(o)


## The ModType `mod` occupies on `w` (-1 when `w` does not take it).
static func _mod_type_in(w: WeaponDef, mod: StringName) -> int:
	if w == null:
		return -1
	for t: Variant in w.mod_slots:
		if (w.mod_slots[t] as Array).has(mod):
			return int(t)
	return -1
