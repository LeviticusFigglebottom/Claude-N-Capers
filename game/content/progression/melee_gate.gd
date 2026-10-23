## Which melees a player may equip (D-155). Owner: ENV B. Static.
## PD2 never sells melee: each MeleeDef unlocks at `unlock_level` and is free from then on. Derived from the
## player's level, so nothing is saved.
class_name MeleeGate
extends RefCounted

## The starter melee (unlock level 0); a saved pick that is locked falls back to it.
const DEFAULT_ID: StringName = &"melee.folding_knife"


static func is_unlocked(profile: PlayerProfile, def: MeleeDef) -> bool:
	return def != null and (profile.level if profile != null else 0) >= def.unlock_level


## `id` when `profile` may equip it, else DEFAULT_ID.
static func usable(profile: PlayerProfile, id: StringName) -> StringName:
	return id if is_unlocked(profile, ContentDB.melee(id)) else DEFAULT_ID
