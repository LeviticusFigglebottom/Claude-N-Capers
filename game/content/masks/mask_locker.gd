## A profile's masks (pd2_fidelity P8/P9): owned parts, custom slots, equip. Owner: ENV B. Static.
## Callers save the profile themselves (SaveService.save_profile).
##
## Ownership: a part is owned when `default_owned` (data) or listed in
## `PlayerProfile.owned_mask_parts` (grant_part; payday card drops later, P9). A preset is owned when
## its `unlock` is empty or its id is in `owned_masks` (same rule as the loadout screen).
## Custom slots: `PlayerProfile.custom_masks[n]` is a composition dict ({} = empty slot) and is
## equipped as `mask.custom.<n>`; n < MaskTweak.custom_slot_count.
class_name MaskLocker
extends RefCounted


static func is_part_owned(profile: PlayerProfile, id: StringName) -> bool:
	if not MaskCatalog.has_part(id):
		return false
	if MaskCatalog.part(id).default_owned:
		return true
	return profile != null and profile.owned_mask_parts.has(id)


## Adds a locked preset (`MaskDef.unlock` set) to `owned_masks` (payday card drop, unlock). False for
## unknown ids, presets without an unlock and presets already owned.
static func grant_preset(profile: PlayerProfile, mask_id: StringName) -> bool:
	if profile == null or profile.owned_masks.has(mask_id):
		return false
	for md: MaskDef in MaskCatalog.presets():
		if md.id == mask_id:
			if md.unlock == &"":
				return false
			profile.owned_masks.append(mask_id)
			ContentDB.sort_ids(profile.owned_masks)
			return true
	return false


## Ownership of a payday card mask item: a preset id (`mask.<name>`) or a part id.
static func is_drop_owned(profile: PlayerProfile, id: StringName) -> bool:
	return is_equippable(profile, id) if MaskCatalog.is_preset_id(id) else is_part_owned(profile, id)


## Grants unlock `unlock_id` (e.g. an achievement's `unlock.achievement.<x>`, B4-20): records it in
## `PlayerProfile.unlocks` (saved, v5) and owns every preset whose `unlock` is that id, and every
## AVAILABLE mask part whose `unlock` is that id (B7-02; a part still waiting for its ENV D model is owned
## by apply_unlocks once the glb lands). Returns the newly owned preset and part ids.
static func grant_unlock(profile: PlayerProfile, unlock_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	if profile == null or unlock_id == &"":
		return out
	if not profile.unlocks.has(unlock_id):
		profile.unlocks.append(unlock_id)
		ContentDB.sort_ids(profile.unlocks)
	for md: MaskDef in MaskCatalog.presets():
		if md.unlock == unlock_id and grant_preset(profile, md.id):
			out.append(md.id)
	var ids: Array[StringName] = [unlock_id]
	out.append_array(_grant_unlock_parts(profile, ids))
	return out


## Owns every preset and available part behind an unlock already recorded in `profile.unlocks` (load-time
## repair, so a preset or part added later behind an earned unlock is owned). Returns the newly owned ids.
static func apply_unlocks(profile: PlayerProfile) -> Array[StringName]:
	var out: Array[StringName] = []
	if profile == null:
		return out
	for md: MaskDef in MaskCatalog.presets():
		if md.unlock != &"" and profile.unlocks.has(md.unlock) and grant_preset(profile, md.id):
			out.append(md.id)
	out.append_array(_grant_unlock_parts(profile, profile.unlocks))
	return out


## Available parts whose `unlock` is in `unlock_ids`, granted (grant_part). Returns the newly owned ids.
static func _grant_unlock_parts(profile: PlayerProfile, unlock_ids: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	for kind: String in MaskCatalog.KINDS:
		for part: MaskPartDef in MaskCatalog.parts(kind):
			if part.unlock != &"" and unlock_ids.has(part.unlock) and grant_part(profile, part.id):
				out.append(part.id)
	return out


## Owned parts of one kind (MaskCatalog.BASE ...), data order.
static func owned_parts(profile: PlayerProfile, kind: String) -> Array[MaskPartDef]:
	var out: Array[MaskPartDef] = []
	for p: MaskPartDef in MaskCatalog.parts(kind):
		if is_part_owned(profile, p.id):
			out.append(p)
	return out


## Adds a part to the profile (drop / unlock). False for unknown or already owned parts.
static func grant_part(profile: PlayerProfile, id: StringName) -> bool:
	if profile == null or not MaskCatalog.has_part(id) or is_part_owned(profile, id):
		return false
	profile.owned_mask_parts.append(id)
	ContentDB.sort_ids(profile.owned_mask_parts)
	return true


## Every part in `comp` exists, has the right kind and is owned. Returns the problems (empty = ok).
static func check_composition(profile: PlayerProfile, comp: Dictionary) -> Array[String]:
	var errors: Array[String] = MaskComposer.validate(comp)
	if not errors.is_empty():
		return errors
	for k: String in MaskCatalog.KINDS:
		if not is_part_owned(profile, StringName(String(comp[k]))):
			errors.append("%s '%s' not owned" % [k, comp[k]])
	return errors


## Composition stored in custom slot `index` ({} when empty, out of range or no profile).
static func custom_composition(profile: PlayerProfile, index: int) -> Dictionary:
	if profile == null or index < 0 or index >= profile.custom_masks.size():
		return {}
	var comp: Dictionary = MaskComposer.normalized(profile.custom_masks[index])
	for k: String in MaskCatalog.KINDS:
		if String(comp[k]) == "":
			return {}
	return comp


## Stores `comp` in custom slot `index` (grows custom_masks with empty slots). Refuses invalid or
## unowned compositions and indexes outside MaskTweak.custom_slot_count. Returns the mask id or "".
static func save_custom(profile: PlayerProfile, index: int, comp: Dictionary) -> StringName:
	if profile == null or index < 0 or index >= MaskCatalog.tweak().custom_slot_count:
		return &""
	var errors: Array[String] = check_composition(profile, comp)
	if not errors.is_empty():
		Log.warn(MaskCatalog.LOG_CHANNEL, "custom mask refused: %s" % ", ".join(errors))
		return &""
	while profile.custom_masks.size() <= index:
		profile.custom_masks.append({})
	profile.custom_masks[index] = MaskComposer.normalized(comp)
	sync_descriptor(profile)
	return MaskCatalog.custom_id(index)


## Empties custom slot `index`; an equipped mask in that slot is unequipped.
static func clear_custom(profile: PlayerProfile, index: int) -> void:
	if profile == null or index < 0 or index >= profile.custom_masks.size():
		return
	profile.custom_masks[index] = {}
	if profile.loadout.mask == MaskCatalog.custom_id(index):
		profile.loadout.mask = &""
	sync_descriptor(profile)


## Owned preset or filled custom slot ("" = no mask is always equippable).
static func is_equippable(profile: PlayerProfile, mask_id: StringName) -> bool:
	if mask_id == &"":
		return true
	if MaskCatalog.is_custom_id(mask_id):
		var idx: int = MaskCatalog.custom_index(mask_id)
		return idx >= 0 and idx < MaskCatalog.tweak().custom_slot_count and not custom_composition(profile, idx).is_empty()
	for md: MaskDef in MaskCatalog.presets():
		if md.id == mask_id:
			return md.unlock == &"" or (profile != null and profile.owned_masks.has(mask_id))
	return false


## Writes Loadout.mask when equippable. Returns false (loadout unchanged) otherwise.
static func equip(profile: PlayerProfile, mask_id: StringName) -> bool:
	if profile == null or not is_equippable(profile, mask_id):
		return false
	profile.loadout.mask = mask_id
	sync_descriptor(profile)
	return true


## Refresh profile.loadout.mask_descriptor (D-043 QA-25) after the worn mask or its slot changed.
static func sync_descriptor(profile: PlayerProfile) -> void:
	if profile != null and profile.loadout != null:
		profile.loadout.mask_descriptor = LoadoutResolver.mask_descriptor_for(profile.loadout, profile)


## Every mask id the profile can equip: owned presets (sorted), then filled custom slots in order.
## For pickers (e.g. the loadout screen); names via MaskCatalog.display_name().
static func available_ids(profile: PlayerProfile) -> Array[StringName]:
	var out: Array[StringName] = []
	for md: MaskDef in MaskCatalog.presets():
		if is_equippable(profile, md.id):
			out.append(md.id)
	if profile != null:
		for i: int in range(mini(profile.custom_masks.size(), MaskCatalog.tweak().custom_slot_count)):
			if not custom_composition(profile, i).is_empty():
				out.append(MaskCatalog.custom_id(i))
	return out
