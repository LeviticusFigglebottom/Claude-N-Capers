## Weapon finishes (B7-04): ownership, the equipped finish per weapon, how a locked one is earned, and the
## finishes a launch loadout carries. Owner: ENV B. Static. Data: FinishDef (`data/finishes/`); materials:
## FinishApplier / FinishMaterials; UI: WorkshopFinishPanel.
##
## Ownership: `default_owned`, or the finish's `unlock` (`unlock.finish.<name>`) in PlayerProfile.unlocks
## (an AchievementDef.unlock or a NotorietyDef.unlocks entry grants it through MaskLocker.grant_unlock).
##
## Storage: `PlayerProfile.weapon_finishes` (weapon id -> finish id), added in save v7 by B7-01. This code
## reads the field with `get(&"weapon_finishes")` and tolerates its absence: without the field the choice
## lives on the profile object's metadata only (not saved). No migration here.
##
## Teammates: `Loadout.weapon_finishes` (weapon id -> finish id, the equipped primary / secondary only; lead
## approved, contracts/data round 28). `stamp(loadout, profile)` fills it where MenuFlow builds launch
## loadouts and LobbyState writes summaries; `from_loadout(loadout, weapon_id)` reads it (null-safe while the
## contract field is not on the tree yet). WeaponVisual.apply_loadout_finish applies it.
class_name WeaponFinishes
extends RefCounted

const PROFILE_FIELD: StringName = &"weapon_finishes"
const LOADOUT_FIELD: StringName = &"weapon_finishes"
## Source kinds of source_of().
const SOURCE_DEFAULT: StringName = &"default"
const SOURCE_ACHIEVEMENT: StringName = &"achievement"
const SOURCE_NOTORIETY: StringName = &"notoriety"
const SOURCE_UNKNOWN: StringName = &"unknown"


## Every finish, by `order` then id.
static func all() -> Array[FinishDef]:
	var out: Array[FinishDef] = []
	for r: Resource in ContentDB.all_of(ContentDB.FINISHES):
		out.append(r as FinishDef)
	out.sort_custom(func(a: FinishDef, b: FinishDef) -> bool:
		return a.order < b.order if a.order != b.order else String(a.id) < String(b.id))
	return out


## The finish def (null, no error, for &"" or an unknown id).
static func def(id: StringName) -> FinishDef:
	if id == &"" or not ContentDB.has(ContentDB.FINISHES, id):
		return null
	return ContentDB.by_id(ContentDB.FINISHES, id) as FinishDef


static func is_known(id: StringName) -> bool:
	return id != &"" and ContentDB.has(ContentDB.FINISHES, id)


## Owned: default, or its unlock is recorded. &"" (stock) is always owned; unknown ids never are.
static func is_owned(profile: PlayerProfile, id: StringName) -> bool:
	if id == &"":
		return true
	var d: FinishDef = def(id)
	if d == null:
		return false
	return d.default_owned or (profile != null and profile.unlocks.has(d.unlock))


## Owned finishes, in display order.
static func owned(profile: PlayerProfile) -> Array[FinishDef]:
	var out: Array[FinishDef] = []
	for d: FinishDef in all():
		if is_owned(profile, d.id):
			out.append(d)
	return out


## True when the profile has the `weapon_finishes` field (save v7, B7-01) and so persists equips.
static func persists(profile: PlayerProfile) -> bool:
	return profile != null and profile.get(PROFILE_FIELD) is Dictionary


## The profile's weapon id -> finish id map (the save field, else the in-memory fallback). Live reference.
static func store(profile: PlayerProfile) -> Dictionary:
	if profile == null:
		return {}
	var v: Variant = profile.get(PROFILE_FIELD)
	if v is Dictionary:
		return v as Dictionary
	if not profile.has_meta(PROFILE_FIELD):
		profile.set_meta(PROFILE_FIELD, {})
	return profile.get_meta(PROFILE_FIELD) as Dictionary


## The finish equipped on `weapon_id` (&"" = stock; also for unknown or no-longer-owned ids).
static func equipped(profile: PlayerProfile, weapon_id: StringName) -> StringName:
	var id: StringName = StringName(String(store(profile).get(weapon_id, "")))
	return id if is_known(id) and is_owned(profile, id) else &""


## Equip `finish_id` on `weapon_id` (&"" = stock). False (nothing changes) for an unknown weapon or finish,
## or a locked finish. The caller saves the profile.
static func equip(profile: PlayerProfile, weapon_id: StringName, finish_id: StringName) -> bool:
	if profile == null or not ContentDB.has(ContentDB.WEAPONS, weapon_id):
		return false
	if finish_id != &"" and not (is_known(finish_id) and is_owned(profile, finish_id)):
		return false
	var s: Dictionary = store(profile)
	if finish_id == &"":
		s.erase(weapon_id)
	else:
		s[weapon_id] = finish_id
	return true


## Weapon id -> finish id for the loadout's primary and secondary (stock weapons left out).
static func for_loadout(profile: PlayerProfile, loadout: Loadout) -> Dictionary:
	var out: Dictionary = {}
	if profile == null or loadout == null:
		return out
	for w: StringName in [loadout.primary, loadout.secondary]:
		var f: StringName = equipped(profile, w) if w != &"" else &""
		if f != &"":
			out[w] = f
	return out


## Fill `Loadout.weapon_finishes` from the profile. False while the contract field is not on the tree.
static func stamp(loadout: Loadout, profile: PlayerProfile) -> bool:
	if loadout == null or not (LOADOUT_FIELD in loadout):
		return false
	loadout.set(LOADOUT_FIELD, for_loadout(profile, loadout))
	return true


## The finish a loadout carries for `weapon_id` (&"" when none, unknown, or the field is missing).
static func from_loadout(loadout: Loadout, weapon_id: StringName) -> StringName:
	if loadout == null or weapon_id == &"":
		return &""
	var v: Variant = loadout.get(LOADOUT_FIELD)
	if not v is Dictionary:
		return &""
	var id: StringName = StringName(String((v as Dictionary).get(weapon_id, "")))
	return id if is_known(id) else &""


## JSON-safe copy of a weapon_finishes map with only known weapon and finish ids (lobby summaries).
static func sanitize_map(v: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not v is Dictionary:
		return out
	for k: Variant in v as Dictionary:
		var f: Variant = (v as Dictionary)[k]
		if (k is String or k is StringName) and (f is String or f is StringName) \
				and ContentDB.has(ContentDB.WEAPONS, StringName(String(k))) and is_known(StringName(String(f))):
			out[String(k)] = String(f)
	return out


## How a finish is earned: {kind: SOURCE_*, achievement: id (achievement), rank: int (notoriety)}.
static func source_of(id: StringName) -> Dictionary:
	var d: FinishDef = def(id)
	if d == null:
		return {"kind": SOURCE_UNKNOWN}
	if d.default_owned:
		return {"kind": SOURCE_DEFAULT}
	for a: AchievementDef in Achievements.all():
		if a.unlock == d.unlock:
			return {"kind": SOURCE_ACHIEVEMENT, "achievement": a.id}
	for nd: NotorietyDef in Notoriety.table().ranks:
		if nd.unlocks.has(d.unlock):
			return {"kind": SOURCE_NOTORIETY, "rank": nd.rank}
	return {"kind": SOURCE_UNKNOWN}
