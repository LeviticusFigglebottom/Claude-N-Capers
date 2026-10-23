## Content validation of a loaded profile (B4-16). Owner: ENV B. Static.
##
## validate(p) runs on every SaveService load (after migrate + ProfileSchema.sanitize + from_dict) and
## repairs the profile in place, one Log.warn per repair, never an error:
##   * owned_weapons / owned_mods / owned_masks (presets) / owned_mask_parts: unknown ids pruned.
##   * custom_masks: a slot naming an unknown part (or a part of the wrong kind) is emptied.
##   * unlocks: ids not shaped `unlock.*` pruned; every preset whose unlock is recorded is owned
##     (MaskLocker.apply_unlocks), so a preset added later behind an earned unlock is owned too.
##   * loadout: an unknown weapon / melee / throwable / deployable / armor id falls back to the default
##     profile's value (data/save/default_profile.json); unknown mods are pruned; a mask that is not
##     equippable falls back to the default mask; an unknown perk deck is cleared (cards 0); an unknown
##     heister (D-073) is cleared to "" (no preference).
##   * perk_cards: unknown decks pruned, counts clamped to 0..deck size.
##   * skill sets (every set incl. the active one = loadout.skills): unknown skill ids pruned, then a set
##     that is still illegal for the profile's level (SkillPoints.validate) is reset to empty.
##   * achievements: unknown achievement ids pruned. pro_job_locks: keys not shaped `<slot>:<bucket>` pruned.
##   * notoriety (v6): clamped to 0..NotorietyTweak.max_rank, notoriety_xp to >= 0; a rank unlock id
##     `unlock.notoriety.rank_<n>` above the rank is pruned; notoriety_choices entries for a rank above the
##     profile's or naming an id that rank does not offer are pruned; held_skill_sets lose unknown skills /
##     bad levels and entries past the last skill set. Then Notoriety.apply_rewards re-grants every reached
##     rank's rewards (data added later reaches old profiles). music_choice is type-checked only (B5-03).
##   * career (v7): career.weapons entries for unknown weapon ids pruned (heist / loot ids are kept: a heist
##     removed from the registry still belongs to the player's history).
##   * weapon_finishes (v7): entries for unknown weapon ids or unknown finish ids pruned (lead ruling, as for
##     unknown masks). Ownership is not checked here: FinishApplier / WeaponFinishes.for_loadout skip unowned ones.
## Returns the repair messages (empty = the profile was already valid).
class_name ProfileValidator
extends RefCounted

const LOG_CHANNEL: StringName = &"save"
## Loadout id field -> ContentDB kind.
const LOADOUT_KINDS: Dictionary = {
	"primary": ContentDB.WEAPONS, "secondary": ContentDB.WEAPONS, "melee": ContentDB.MELEE,
	"throwable": ContentDB.THROWABLES, "deployable": ContentDB.DEPLOYABLES,
	"deployable_secondary": ContentDB.DEPLOYABLES, "armor": ContentDB.ARMOR,
}

static var _default_loadout: Loadout = null


static func validate(p: PlayerProfile) -> Array[String]:
	var notes: Array[String] = []
	if p == null:
		return notes
	p.owned_weapons = _known(p.owned_weapons, ContentDB.WEAPONS, "owned_weapons", notes)
	p.owned_mods = _known(p.owned_mods, ContentDB.MODS, "owned_mods", notes)
	p.owned_masks = _owned_presets(p.owned_masks, notes)
	p.owned_mask_parts = _known_parts(p.owned_mask_parts, notes)
	_custom_masks(p, notes)
	_notoriety_rank(p, notes)
	_unlocks(p, notes)
	_loadout(p, notes)
	_perk_cards(p, notes)
	_skill_sets(p, notes)
	_achievements(p, notes)
	_locks(p, notes)
	_notoriety_state(p, notes)
	_career(p, notes)
	for m: String in notes:
		Log.warn(LOG_CHANNEL, "profile: " + m)
	return notes


static func _known(ids: Array[StringName], kind: StringName, field: String, notes: Array[String]) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in ids:
		if ContentDB.has(kind, id):
			if not out.has(id):
				out.append(id)
		else:
			notes.append("%s: unknown id '%s' dropped" % [field, id])
	return out


static func _owned_presets(ids: Array[StringName], notes: Array[String]) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in ids:
		if MaskCatalog.is_preset_id(id) and ContentDB.has(ContentDB.MASKS, id):
			if not out.has(id):
				out.append(id)
		else:
			notes.append("owned_masks: unknown preset '%s' dropped" % id)
	return out


static func _known_parts(ids: Array[StringName], notes: Array[String]) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in ids:
		if MaskCatalog.is_known(id):
			if not out.has(id):
				out.append(id)
		else:
			notes.append("owned_mask_parts: unknown part '%s' dropped" % id)
	return out


## Custom slots: every kind present, known and of the right kind (hidden ENV D bases stay: they are
## known and come back when their model lands). Anything else empties the slot.
static func _custom_masks(p: PlayerProfile, notes: Array[String]) -> void:
	for i: int in range(p.custom_masks.size()):
		var comp: Dictionary = p.custom_masks[i]
		if comp.is_empty():
			continue
		for k: String in MaskCatalog.KINDS:
			var id: StringName = StringName(String(comp.get(k, "")))
			if MaskCatalog.kind_of(id) != k or not MaskCatalog.is_known(id):
				notes.append("custom_masks[%d]: unknown %s '%s'; slot emptied" % [i, k, id])
				p.custom_masks[i] = {}
				break
		if not p.custom_masks[i].is_empty():
			p.custom_masks[i] = MaskComposer.normalized(comp)


static func _unlocks(p: PlayerProfile, notes: Array[String]) -> void:
	var out: Array[StringName] = []
	for id: StringName in p.unlocks:
		if String(id).begins_with("unlock.") and String(id).length() > 7:
			if not out.has(id):
				out.append(id)
		else:
			notes.append("unlocks: malformed unlock id '%s' dropped" % id)
	ContentDB.sort_ids(out)
	p.unlocks = out
	MaskLocker.apply_unlocks(p)


static func _loadout(p: PlayerProfile, notes: Array[String]) -> void:
	var l: Loadout = p.loadout
	var def: Loadout = _defaults()
	for f: String in LOADOUT_KINDS:
		var id: StringName = l.get(f) as StringName
		if id != &"" and not ContentDB.has(LOADOUT_KINDS[f], id):
			notes.append("loadout.%s: unknown id '%s'; reset to '%s'" % [f, id, def.get(f)])
			l.set(f, def.get(f))
	for f: String in ["primary_mods", "secondary_mods"]:
		l.set(f, _known(l.get(f) as Array[StringName], ContentDB.MODS, "loadout." + f, notes))
	_weapon_slots(p, notes)
	if not MaskLocker.is_equippable(p, l.mask):
		notes.append("loadout.mask: '%s' not equippable; reset to '%s'" % [l.mask, def.mask])
		l.mask = def.mask if MaskLocker.is_equippable(p, def.mask) else &""
	if l.heister != &"" and not Heisters.is_known(l.heister):
		notes.append("loadout.heister: unknown heister '%s' cleared" % l.heister)
		l.heister = &""
	if l.perk_deck != &"" and not ContentDB.has(ContentDB.PERKS, l.perk_deck):
		notes.append("loadout.perk_deck: unknown deck '%s' cleared" % l.perk_deck)
		l.perk_deck = &""
		l.perk_deck_cards = 0
	MaskLocker.sync_descriptor(p)


## D-126 (shotguns joined the secondary slot): a weapon equipped in a slot it no longer belongs to moves over.
## A secondary-slot weapon in the primary slot becomes the secondary (with its mods; it was the player's main gun) and
## the primary falls back to the starter primary when owned, else the first owned primary, else empty. A primary-slot
## weapon in the secondary slot is replaced by the default secondary.
static func _weapon_slots(p: PlayerProfile, notes: Array[String]) -> void:
	var l: Loadout = p.loadout
	var pw: WeaponDef = ContentDB.weapon(l.primary) if l.primary != &"" else null
	if pw != null and pw.slot == Enums.WeaponSlot.SECONDARY:
		notes.append("loadout.primary: '%s' is a secondary now (D-126); moved to the secondary slot" % l.primary)
		l.secondary = l.primary
		l.secondary_mods = l.primary_mods.duplicate()
		l.primary = _owned_primary(p)
		l.primary_mods = [] as Array[StringName]
	var sw: WeaponDef = ContentDB.weapon(l.secondary) if l.secondary != &"" else null
	if sw != null and sw.slot == Enums.WeaponSlot.PRIMARY:
		var def: StringName = _defaults().secondary
		notes.append("loadout.secondary: '%s' is a primary; reset to '%s'" % [l.secondary, def])
		l.secondary = def
		l.secondary_mods = [] as Array[StringName]


static func _owned_primary(p: PlayerProfile) -> StringName:
	var starter: StringName = StringName(SaveService.STARTER_PRIMARY)
	if p.owned_weapons.has(starter):
		return starter
	for id: StringName in p.owned_weapons:
		var w: WeaponDef = ContentDB.weapon(id)
		if w != null and w.slot == Enums.WeaponSlot.PRIMARY:
			return id
	return &""


static func _perk_cards(p: PlayerProfile, notes: Array[String]) -> void:
	var out: Dictionary = {}
	for id: Variant in p.perk_cards:
		var sid: StringName = StringName(id)
		if not ContentDB.has(ContentDB.PERKS, sid):
			notes.append("perk_cards: unknown deck '%s' dropped" % sid)
			continue
		var size: int = ((ContentDB.by_id(ContentDB.PERKS, sid) as PerkDeckDef).cards as Array).size()
		var n: int = int(p.perk_cards[id])
		if n < 0 or n > size:
			notes.append("perk_cards.%s: %d clamped to 0..%d" % [sid, n, size])
		out[sid] = clampi(n, 0, size)
	p.perk_cards = out
	var deck: PerkDeckDef = PerkProgress.deck(p.loadout.perk_deck)
	if deck != null:
		p.loadout.perk_deck_cards = clampi(p.loadout.perk_deck_cards, 0, deck.cards.size())
	# D-164: a mimic pick must name a mimicable deck (an unknown, own or throwable-deck pick is dropped).
	if p.loadout.perk_mimic_deck != &"":
		var m: PerkDeckDef = PerkProgress.deck(p.loadout.perk_mimic_deck)
		if m == null or not m.mimicable or m.id == p.loadout.perk_deck:
			notes.append("loadout.perk_mimic_deck %s is not mimicable: dropped" % p.loadout.perk_mimic_deck)
			p.loadout.perk_mimic_deck = &""


static func _skill_sets(p: PlayerProfile, notes: Array[String]) -> void:
	var budget: int = SkillPoints.points_for_level(p.level)
	p.loadout.skills = _skill_set(p.loadout.skills, budget, "loadout.skills", notes)
	for i: int in range(p.skill_sets.size()):
		if i == p.active_skill_set:
			p.skill_sets[i] = p.loadout.skills.duplicate()
		else:
			p.skill_sets[i] = _skill_set(p.skill_sets[i], budget, "skill_sets[%d]" % i, notes)


static func _skill_set(skills: Dictionary, budget: int, field: String, notes: Array[String]) -> Dictionary:
	var out: Dictionary = {}
	for id: Variant in skills:
		if ContentDB.has(ContentDB.SKILLS, StringName(id)):
			out[StringName(id)] = int(skills[id])
		else:
			notes.append("%s: unknown skill '%s' dropped" % [field, id])
	var errors: Array[String] = SkillPoints.validate(out, budget)
	if not errors.is_empty():
		notes.append("%s: illegal set (%s); reset to empty" % [field, "; ".join(errors)])
		return {}
	return out


static func _achievements(p: PlayerProfile, notes: Array[String]) -> void:
	for id: Variant in p.achievements.keys():
		if not ContentDB.has(ContentDB.ACHIEVEMENTS, StringName(id)):
			notes.append("achievements: unknown id '%s' dropped" % id)
			p.achievements.erase(id)


static func _locks(p: PlayerProfile, notes: Array[String]) -> void:
	for key: Variant in p.pro_job_locks.keys():
		var parts: PackedStringArray = String(key).split(":")
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
			notes.append("pro_job_locks: malformed contract key '%s' dropped" % key)
			p.pro_job_locks.erase(key)


static func _notoriety_rank(p: PlayerProfile, notes: Array[String]) -> void:
	var cap: int = Notoriety.max_rank()
	if p.notoriety < 0 or p.notoriety > cap:
		notes.append("notoriety: %d clamped to 0..%d" % [p.notoriety, cap])
		p.notoriety = clampi(p.notoriety, 0, cap)
	if p.notoriety_xp < 0:
		notes.append("notoriety_xp: %d clamped to 0" % p.notoriety_xp)
		p.notoriety_xp = 0
	for id: StringName in p.unlocks.duplicate():
		var s: String = String(id)
		if not s.begins_with(Notoriety.UNLOCK_PREFIX):
			continue
		var n: String = s.substr(Notoriety.UNLOCK_PREFIX.length())
		if not n.is_valid_int() or int(n) < 1 or int(n) > p.notoriety:
			notes.append("unlocks: '%s' is not a rank reached (notoriety %d); dropped" % [id, p.notoriety])
			p.unlocks.erase(id)


static func _notoriety_state(p: PlayerProfile, notes: Array[String]) -> void:
	for rank: Variant in p.notoriety_choices.keys():
		var d: NotorietyDef = Notoriety.def_for(int(rank))
		var id: StringName = p.notoriety_choices[rank] as StringName
		if int(rank) < 1 or int(rank) > p.notoriety or d == null or not d.choices.has(id):
			notes.append("notoriety_choices.%s: '%s' not offered at that rank; dropped" % [rank, id])
			p.notoriety_choices.erase(rank)
	var sets: int = NotorietySkills.set_count(p)
	if p.held_skill_sets.size() > sets:
		notes.append("held_skill_sets: %d entries for %d skill sets; extras dropped" % [p.held_skill_sets.size(), sets])
		p.held_skill_sets.resize(sets)
	for i: int in range(p.held_skill_sets.size()):
		var out: Dictionary = {}
		for sid: Variant in p.held_skill_sets[i]:
			var lv: int = int(p.held_skill_sets[i][sid])
			if ContentDB.has(ContentDB.SKILLS, StringName(sid)) and (lv == SkillPoints.BASIC or lv == SkillPoints.ACED):
				out[StringName(sid)] = lv
			else:
				notes.append("held_skill_sets[%d]: '%s' (%d) dropped" % [i, sid, lv])
		p.held_skill_sets[i] = out
	Notoriety.apply_rewards(p)


static func _career(p: PlayerProfile, notes: Array[String]) -> void:
	var w: Dictionary = Career.section(p, "weapons")
	for id: Variant in w.keys():
		if not ContentDB.has(ContentDB.WEAPONS, StringName(String(id))):
			notes.append("career.weapons: unknown weapon '%s' dropped" % id)
			w.erase(id)
	for id: Variant in p.weapon_finishes.keys():
		if not ContentDB.has(ContentDB.WEAPONS, StringName(String(id))):
			notes.append("weapon_finishes: unknown weapon '%s' dropped" % id)
			p.weapon_finishes.erase(id)
		elif not WeaponFinishes.is_known(StringName(String(p.weapon_finishes[id]))):
			notes.append("weapon_finishes.%s: unknown finish '%s' dropped" % [id, p.weapon_finishes[id]])
			p.weapon_finishes.erase(id)


static func _defaults() -> Loadout:
	if _default_loadout == null:
		_default_loadout = PlayerProfile.new_default().loadout
	return _default_loadout
