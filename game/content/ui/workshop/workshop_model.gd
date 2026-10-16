## Workshop state and rules, free of UI nodes (B4-17, pd2_fidelity P6). Owner: ENV B.
## WorkshopScreen drives it; tests use it directly.
##
## * Weapons: every WeaponDef. OWNED (profile.owned_weapons), FOR_SALE (level >= unlock_level, buy for
##   WeaponDef.price with spending cash) or LOCKED (below unlock_level).
## * Mods per slot: "" = the stock part (or nothing when the slot has no default), then every other mod
##   the slot allows. A mod is OWNED when it is the slot's stock part or in profile.owned_mods,
##   FOR_SALE when WeaponModDef.unlock is "" (buy for its price; payday cards also drop it), else LOCKED
##   (unlock = its source id). Unowned parts can be previewed but not equipped.
## * Picking a mod drops picked mods it conflicts with (WeaponModDef.conflicts, both directions).
## * Stats: StatCalculator.display of the preview build, deltas (StatCalculator.delta) against the
##   weapon equipped in the same slot (or the preview weapon's stock build when that slot is empty).
##   Concealment total and detection risk come from LoadoutResolver.resolve() of the profile loadout
##   with the preview weapon in its slot, so they always equal what the loadout will resolve to.
## * equip() writes loadout.primary/secondary (+ mods) for the weapon's slot; buy_*() spend cash.
##   The caller saves (SaveService).
class_name WorkshopModel
extends RefCounted

enum ItemState { OWNED, FOR_SALE, LOCKED }

## Why equip is refused (strings keys); &"" = allowed.
const BLOCK_WEAPON: StringName = &"ui.workshop.equip_blocked.weapon"
const BLOCK_MODS: StringName = &"ui.workshop.equip_blocked.mods"

var profile: PlayerProfile
var weapon_id: StringName = &""
## ModType (int) -> picked mod id (&"" = stock / none) for the previewed weapon.
var picks: Dictionary = {}
## D-106: stat rows include the player's skills and perk deck (SkillBoost); false = base weapon values.
var with_skills: bool = true


func _init(p: PlayerProfile) -> void:
	profile = p


## Every weapon id: primaries first, then secondaries; each by class (D-126: pistols, SMGs, shotguns ... in
## Enums.WeaponClass order), then unlock level, then id.
static func weapon_ids() -> Array[StringName]:
	var defs: Array[WeaponDef] = []
	for r: Resource in ContentDB.all_weapons():
		defs.append(r as WeaponDef)
	defs.sort_custom(func(a: WeaponDef, b: WeaponDef) -> bool:
		if a.slot != b.slot:
			return a.slot < b.slot
		if a.weapon_class != b.weapon_class:
			return a.weapon_class < b.weapon_class
		if a.unlock_level != b.unlock_level:
			return a.unlock_level < b.unlock_level
		return ContentDB.id_less(a.id, b.id))
	var out: Array[StringName] = []
	for d: WeaponDef in defs:
		out.append(d.id)
	return out


func weapon() -> WeaponDef:
	return ContentDB.weapon(weapon_id) if weapon_id != &"" else null


func weapon_state(id: StringName) -> ItemState:
	if profile.owned_weapons.has(id):
		return ItemState.OWNED
	var w: WeaponDef = ContentDB.weapon(id)
	if w != null and profile.level >= w.unlock_level:
		return ItemState.FOR_SALE
	return ItemState.LOCKED


## State of `mod_id` on the previewed weapon (&"" = the stock part, always owned).
func mod_state(mod_id: StringName) -> ItemState:
	if mod_id == &"" or _is_stock(mod_id) or profile.owned_mods.has(mod_id):
		return ItemState.OWNED
	var m: WeaponModDef = ContentDB.mod(mod_id)
	if m != null and m.unlock == &"":
		return ItemState.FOR_SALE
	return ItemState.LOCKED


func _is_stock(mod_id: StringName) -> bool:
	var w: WeaponDef = weapon()
	return w != null and w.default_mods.values().has(mod_id)


## Loadout slot the weapon is equipped in (Enums.WeaponSlot), -1 when not equipped.
func equipped_slot_of(id: StringName) -> int:
	if id == &"":
		return -1
	if profile.loadout.primary == id:
		return Enums.WeaponSlot.PRIMARY
	if profile.loadout.secondary == id:
		return Enums.WeaponSlot.SECONDARY
	return -1


## Preview weapon `id`: its equipped mods when it is in the loadout, else the stock build.
func select_weapon(id: StringName) -> void:
	weapon_id = id
	picks.clear()
	var w: WeaponDef = weapon()
	if w == null:
		return
	for t: int in slots():
		picks[t] = &""
	var equipped: Array[StringName] = []
	if equipped_slot_of(id) == w.slot:
		equipped = _loadout_mods(w.slot)
	for mid: StringName in equipped:
		var m: WeaponModDef = ContentDB.mod(mid)
		if m != null and picks.has(int(m.mod_type)):
			picks[int(m.mod_type)] = &"" if _is_stock(mid) else mid


## Mod slots (ModType ints) of the previewed weapon, sorted.
func slots() -> Array[int]:
	var out: Array[int] = []
	var w: WeaponDef = weapon()
	if w == null:
		return out
	for t: Variant in w.mod_slots:
		out.append(int(t))
	out.sort()
	return out


## Choices for slot `t`: &"" (stock / none) then every non-stock mod the slot allows.
func slot_options(t: int) -> Array[StringName]:
	var out: Array[StringName] = [&""]
	var w: WeaponDef = weapon()
	if w == null or not w.mod_slots.has(t):
		return out
	for mid: Variant in (w.mod_slots[t] as Array):
		var id: StringName = StringName(mid)
		if not _is_stock(id):
			out.append(id)
	return out



## Pick `mod_id` (&"" = stock) in slot `t`. Returns the mod ids it removed from other slots (conflicts).
func pick(t: int, mod_id: StringName) -> Array[StringName]:
	var removed: Array[StringName] = []
	if not picks.has(t):
		return removed
	picks[t] = mod_id
	var m: WeaponModDef = ContentDB.mod(mod_id) if mod_id != &"" else null
	if m == null:
		return removed
	for other: int in picks.keys():
		var oid: StringName = picks[other]
		if other == t or oid == &"":
			continue
		var o: WeaponModDef = ContentDB.mod(oid)
		if o != null and (m.conflicts.has(oid) or o.conflicts.has(mod_id)):
			picks[other] = &""
			removed.append(oid)
	return removed


## Picked non-stock mod ids in slot order (the Loadout `*_mods` list).
func mod_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for t: int in slots():
		var id: StringName = picks.get(t, &"")
		if id != &"":
			out.append(id)
	return out


## Mods on the model: the picks plus stock defaults for the other slots (LoadoutResolver.applied_mods).
func applied_mods() -> Array[WeaponModDef]:
	var w: WeaponDef = weapon()
	if w == null:
		return []
	return LoadoutResolver.applied_mods(w, mod_ids())


## The profile loadout with the preview weapon + picks in the weapon's slot (unresolved).
func preview_loadout() -> Loadout:
	var l: Loadout = profile.loadout.duplicate(true) as Loadout
	var w: WeaponDef = weapon()
	if w == null:
		return l
	if w.slot == Enums.WeaponSlot.PRIMARY:
		l.primary = w.id
		l.primary_mods = mod_ids()
	else:
		l.secondary = w.id
		l.secondary_mods = mod_ids()
	return l


## The preview build as it fires (D-118: a loaded shotgun AMMO mod through AmmoStats).
func _preview_stats() -> WeaponStats:
	return AmmoStats.apply(LoadoutResolver.resolve_weapon(weapon_id, mod_ids()), weapon(), mod_ids())


## Comparison base: the weapon equipped in the preview weapon's slot (with its mods), else the preview
## weapon's stock build.
func _baseline_stats() -> WeaponStats:
	var w: WeaponDef = weapon()
	if w == null:
		return null
	var cur: StringName = profile.loadout.primary if w.slot == Enums.WeaponSlot.PRIMARY else profile.loadout.secondary
	if cur != &"":
		var raw: Array[StringName] = profile.loadout.primary_mods if w.slot == Enums.WeaponSlot.PRIMARY else profile.loadout.secondary_mods
		var s: WeaponStats = AmmoStats.apply(LoadoutResolver.resolve_weapon(cur, raw), ContentDB.weapon(cur), raw)
		if s != null:
			return s
	return LoadoutResolver.resolve_weapon(weapon_id, [] as Array[StringName])


## {"shown": StatCalculator.display(preview), "delta": StatCalculator.delta(baseline, preview),
## "boosted": [display keys the skills change], "pellets": pellets per shot as the ammo fires (D-118),
## "ammo": the loaded ShotgunAmmo type (&"" = buckshot / none)}; {} when nothing is previewed. With `with_skills` both
## preview and baseline carry the skills (deltas compare like with like); "boosted" is empty without.
func stat_rows() -> Dictionary:
	var p: WeaponStats = _preview_stats()
	var b: WeaponStats = _baseline_stats()
	if p == null or b == null:
		return {}
	var boosted: Array[String] = []
	if with_skills:
		var mods: Dictionary = LoadoutResolver.resolve_modifiers(profile.loadout)
		var pb: WeaponStats = SkillBoost.apply(p, weapon(), mods)
		boosted = SkillBoost.boosted_keys(StatCalculator.display(p), StatCalculator.display(pb))
		p = pb
		b = SkillBoost.apply(b, ContentDB.weapon(_baseline_id()), mods)
	var shown: Dictionary = StatCalculator.display(p)
	return {"shown": shown, "delta": StatCalculator.delta(b, p), "boosted": boosted,
			"pellets": maxi(p.pellets, 1), "ammo": AmmoStats.profile(weapon(), mod_ids()).get("ammo_type", &"")}


## The weapon the baseline stats belong to (the equipped one of this slot, else this weapon).
func _baseline_id() -> StringName:
	var w: WeaponDef = weapon()
	if w == null:
		return &""
	var cur: StringName = profile.loadout.primary if w.slot == Enums.WeaponSlot.PRIMARY else profile.loadout.secondary
	return cur if cur != &"" else weapon_id


## {"concealment", "detection_risk"} of the preview loadout and {"current_concealment",
## "current_detection_risk"} of the profile loadout, both via LoadoutResolver.resolve().
func dr_preview() -> Dictionary:
	var now: Loadout = LoadoutResolver.resolve(profile.loadout, profile)
	var pre: Loadout = LoadoutResolver.resolve(preview_loadout(), profile)
	return {
		"concealment": pre.concealment_total, "detection_risk": pre.detection_risk,
		"current_concealment": now.concealment_total, "current_detection_risk": now.detection_risk,
	}


## &"" when the preview build can be equipped, else the strings key of the reason.
func equip_block() -> StringName:
	if weapon() == null or weapon_state(weapon_id) != ItemState.OWNED:
		return BLOCK_WEAPON
	for id: StringName in mod_ids():
		if mod_state(id) != ItemState.OWNED:
			return BLOCK_MODS
	return &""


## True when the preview build is exactly what the loadout holds.
func is_equipped() -> bool:
	var w: WeaponDef = weapon()
	return w != null and equipped_slot_of(weapon_id) == w.slot and _loadout_mods(w.slot) == mod_ids()


## Write the preview weapon + mods into the loadout slot of the weapon. False when blocked.
func equip() -> bool:
	if equip_block() != &"":
		return false
	var mask_descriptor: Dictionary = profile.loadout.mask_descriptor
	profile.loadout = preview_loadout()
	profile.loadout.mask_descriptor = mask_descriptor
	return true


func can_afford(price: int) -> bool:
	return profile.cash >= price


## Buy weapon `id` with spending cash. False when it is not FOR_SALE or the cash is short.
func buy_weapon(id: StringName) -> bool:
	var w: WeaponDef = ContentDB.weapon(id)
	if w == null or weapon_state(id) != ItemState.FOR_SALE or not can_afford(w.price):
		return false
	profile.cash -= w.price
	Career.add_spent(profile, w.price)
	profile.owned_weapons.append(id)
	ContentDB.sort_ids(profile.owned_weapons)
	return true


## Buy mod `id` with spending cash. False when it is not FOR_SALE or the cash is short.
func buy_mod(id: StringName) -> bool:
	var m: WeaponModDef = ContentDB.mod(id)
	if m == null or mod_state(id) != ItemState.FOR_SALE or not can_afford(m.price):
		return false
	profile.cash -= m.price
	Career.add_spent(profile, m.price)
	profile.owned_mods.append(id)
	ContentDB.sort_ids(profile.owned_mods)
	return true


## The loadout's non-stock mods of `slot` for the PREVIEW weapon, in its slot order.
func _loadout_mods(slot: int) -> Array[StringName]:
	var src: Array[StringName] = profile.loadout.primary_mods if slot == Enums.WeaponSlot.PRIMARY else profile.loadout.secondary_mods
	var out: Array[StringName] = []
	var w: WeaponDef = weapon()
	# Keep the loadout's mods in slot order so is_equipped() compares like with like.
	for t: int in slots():
		for id: StringName in src:
			var m: WeaponModDef = ContentDB.mod(id)
			if m != null and int(m.mod_type) == t and (w == null or not w.default_mods.values().has(id)):
				out.append(id)
	return out
