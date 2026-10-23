## Single source of truth for resolved weapon stats, concealment and detection risk
## (contracts/data_schemas.md, pd2_fidelity.md S2.4, P6). Owner: ENV B.
##
## resolve(loadout, profile = null) returns a resolved COPY of the loadout:
## * mask_descriptor = mask_descriptor_for(loadout, profile) (custom masks only; {} for presets/none).
## * resolved_primary / resolved_secondary = WeaponDef.base.plus(delta) for each mod in its slot,
##   where an equipped mod replaces the weapon's default (stock) mod of the same ModType. Then
##   clamps: concealment to the curve's weapon range (0..30), spreads >= 0, mag >= 1,
##   total_ammo >= mag. Shell-fed weapons (`reload_per_round_s > 0`, D-045) then get DERIVED totals
##   after mods and clamps: reload_time_s = reload_start_s + mag_size x reload_per_round_s + reload_end_s,
##   reload_empty_time_s = reload_start_s + mag_size x reload_per_round_s + reload_end_empty_s
##   (Plowman: 0.4 + 6 x 0.4333 + 0.4 / 1.2 = 3.4 s / 4.2 s); a tube mod changes the totals through
##   mag_size only, and its raw reload deltas must be 0. Skill modifiers are NOT baked in (ENV A applies them at runtime).
## * Illegal mods (unknown id, not listed in the weapon's mod_slots for its type, a second mod in
##   the same slot, or a declared conflict) are rejected with Log.error and ignored.
## * concealment_total = primary + secondary + melee + armor + bonus; detection_risk via the
##   ConcealmentCurve tweak.
## * bonus = concealment_bonus(): sum of the `stealth.concealment_add.<qualifier>` grants in the
##   loadout's resolved modifiers (D-022 QB-6). Qualifiers: melee, armor, primary, secondary, all
##   (a bare key counts as all). A slot qualifier only counts while that slot is filled. The bonus
##   is added AFTER the per-weapon 0..30 clamp, so it can push the total past 4 x 30 (PD2: each
##   weapon caps at 30, skill/perk bonuses still raise the total).
## * modifiers = merged skill grants (basic, plus aced) and unlocked perk-deck card grants, merged by
##   ModifierKeys type (MULT multiply, ADD sum, FLAG or, PARAMS last wins). Unknown keys rejected.
##   Crew-wide grants (`team.*`) are excluded: team_modifier_sources() returns them as TEAM sources,
##   `team_skill.<skill_id>` per skill and `team_perk.<deck>` per perk deck (modifiers.md
##   non-stacking rule; D-031 QB-35: TEAM sources apply to the granter too, so there is no personal copy).
## * LIST keys (D-031, ModifierKeys.Type.LIST: weapon.kill_reload_buff, weapon.hit_stack_buff,
##   weapon.kill_damage_buff, defense.post_revive_buff (D-034 QB-39)) are NOT merged. The type is read
##   from ModifierKeys, so a key the registry makes LIST needs no change here. modifiers[key] is an Array[Dictionary] with one entry per
##   granting skill or perk card: a copy of the granted Dictionary plus
##   `"_source": StringName(<skill id>)` (e.g. &"skill.gunnery.run_and_gun") or
##   `"_source": StringName(<deck id>.card<n>)` (e.g. &"perk.foreman.card3"). Inside one skill the aced
##   Dictionary replaces the basic one (aced re-grants the full dict). Entries are ordered by `_source`
##   with ContentDB.id_less (ContentDB.sort_ids order). Example, Reload Rhythm + Run and Gun aced:
##     modifiers[&"weapon.kill_reload_buff"] = [
##       {"trigger": "auto_kills", ..., "_source": &"skill.gunnery.run_and_gun"},
##       {"trigger": "headshot_kill", ..., "_source": &"skill.marksman.reload_rhythm"}]
## * `stealth.concealment_add.suppressed` counts once per filled primary/secondary whose resolved stats
##   are `suppressed` (Low Profile aced).
##
## P1 RULE (data-driven, D-022 QB-11): an empty weapon/melee/armor slot contributes
## `ConcealmentCurve.empty_slot_concealment` (30), so the P1 pistol-only loadout is not penalized
## for having no primary. P1 ONLY: from P4 a loadout needs a primary and a secondary (PD2) and the
## resolver rejects empty weapon slots.
class_name LoadoutResolver
extends RefCounted

const LOG_CHANNEL: StringName = &"loadout"
const CURVE_TWEAK: StringName = &"concealment_curve"
const CONCEALMENT_ADD_KEY: StringName = &"stealth.concealment_add"
## Qualifiers of CONCEALMENT_ADD_KEY. &"all" always counts; the others only while the slot is filled.
## &"suppressed" counts once per suppressed weapon (primary/secondary).
const CONCEALMENT_QUALIFIERS: Array[StringName] = [&"all", &"primary", &"secondary", &"melee", &"armor", &"suppressed"]
const SUPPRESSED_QUALIFIER: StringName = &"suppressed"
## TEAM source of a perk deck's crew-wide grants: `team_perk.<deck id without "perk.">` (D-031 QB-35).
const TEAM_PERK_SOURCE_PREFIX: String = "team_perk."
const LIST_SOURCE_FIELD: String = "_source"


static func resolve(loadout: Loadout, profile: PlayerProfile = null) -> Loadout:
	var out: Loadout = loadout.duplicate(true) as Loadout
	out.mask_descriptor = mask_descriptor_for(loadout, profile)
	out.resolved_primary = resolve_weapon(loadout.primary, loadout.primary_mods)
	out.resolved_secondary = resolve_weapon(loadout.secondary, loadout.secondary_mods)
	var bd: Dictionary = concealment_breakdown(loadout)
	out.concealment_total = int(bd["total"])
	out.detection_risk = int(bd["detection_risk"])
	out.modifiers = resolve_modifiers(loadout)
	return out


## Loadout.mask_descriptor (D-043 QA-25): the equipped CUSTOM mask's MaskCatalog.descriptor(); {} for a
## preset mask or no mask (the preset id in `mask` is enough). Needs the owning profile for a custom
## mask; without one the loadout's existing descriptor is kept when it still names the same mask
## (filled earlier by LoadoutScreen.current_loadout() / PlayerProfile.from_dict(), so the launched
## loadout and ENV A's resolve() of an already-resolved loadout both carry it).
static func mask_descriptor_for(loadout: Loadout, profile: PlayerProfile = null) -> Dictionary:
	if not MaskCatalog.is_custom_id(loadout.mask):
		return {}
	if profile != null:
		return MaskCatalog.descriptor(loadout.mask, profile)
	var d: Dictionary = loadout.mask_descriptor
	return d.duplicate(true) if String(d.get("id", "")) == String(loadout.mask) else {}


## Resolved stats for one weapon id + equipped mod ids, or null for an empty slot / unknown weapon.
static func resolve_weapon(weapon_id: StringName, mods: Array[StringName]) -> WeaponStats:
	if weapon_id == &"":
		return null
	var def: WeaponDef = ContentDB.weapon(weapon_id)
	if def == null or def.base == null:
		return null
	var r: WeaponStats = def.base.duplicate(true) as WeaponStats
	for m: WeaponModDef in applied_mods(def, mods):
		if m.delta != null:
			r = r.plus(m.delta)
	return _clamp(r)


## The mods that end up on the weapon: validated equipped mods, plus defaults for slots left empty.
## Ordered by ModType for determinism.
static func applied_mods(def: WeaponDef, mods: Array[StringName]) -> Array[WeaponModDef]:
	var by_slot: Dictionary = {}  # ModType -> WeaponModDef
	for mod_id: StringName in mods:
		var m: WeaponModDef = ContentDB.mod(mod_id)
		if m == null:
			continue
		var reason: String = _illegal_reason(def, m, by_slot)
		if reason != "":
			Log.error(LOG_CHANNEL, "rejected mod %s on %s: %s" % [mod_id, def.id, reason])
			continue
		by_slot[int(m.mod_type)] = m
	for slot: Variant in def.default_mods:
		if by_slot.has(int(slot)):
			continue
		var d: WeaponModDef = ContentDB.mod(StringName(def.default_mods[slot]))
		if d != null:
			by_slot[int(slot)] = d
	var slots: Array = by_slot.keys()
	slots.sort()
	var out: Array[WeaponModDef] = []
	for s: Variant in slots:
		out.append(by_slot[s])
	return out


## {"primary", "secondary", "melee", "armor", "bonus", "total", "detection_risk"} (all int).
static func concealment_breakdown(loadout: Loadout) -> Dictionary:
	var curve: ConcealmentCurve = curve_tweak()
	var primary: int = _weapon_concealment(loadout.primary, loadout.primary_mods, curve)
	var secondary: int = _weapon_concealment(loadout.secondary, loadout.secondary_mods, curve)
	var melee: int = curve.empty_slot_concealment
	if loadout.melee != &"":
		var md: MeleeDef = ContentDB.melee(loadout.melee)
		melee = md.concealment if md != null else curve.empty_slot_concealment
	var armor: int = curve.empty_slot_concealment
	if loadout.armor != &"":
		var ad: ArmorDef = ContentDB.armor(loadout.armor)
		armor = ad.concealment if ad != null else curve.empty_slot_concealment
	var bonus: int = concealment_bonus(loadout)
	var total: int = primary + secondary + melee + armor + bonus
	return {
		"primary": primary, "secondary": secondary, "melee": melee, "armor": armor,
		"bonus": bonus, "total": total, "detection_risk": curve.dr_for_total(total),
	}


## Skill/perk concealment bonus (Inner Pockets / Blending In analogs, D-022 QB-6): the sum of the
## loadout's resolved `stealth.concealment_add[.qualifier]` grants. Not capped by the per-weapon 30.
static func concealment_bonus(loadout: Loadout) -> int:
	return concealment_bonus_from(loadout, resolve_modifiers(loadout))


## Same, from an already merged modifier dictionary (resolve_modifiers() output).
static func concealment_bonus_from(loadout: Loadout, modifiers: Dictionary) -> int:
	var bonus: float = 0.0
	for key: Variant in modifiers:
		var k: StringName = StringName(key)
		if ModifierKeys.base_key(k) != CONCEALMENT_ADD_KEY:
			continue
		var qualifier: StringName = &"all"
		if k != CONCEALMENT_ADD_KEY:
			qualifier = StringName(String(k).trim_prefix(String(CONCEALMENT_ADD_KEY) + "."))
		if not CONCEALMENT_QUALIFIERS.has(qualifier):
			Log.error(LOG_CHANNEL, "unknown concealment qualifier in %s" % k)
			continue
		if qualifier == SUPPRESSED_QUALIFIER:
			bonus += float(modifiers[key]) * suppressed_weapon_count(loadout)
		elif qualifier == &"all" or StringName(loadout.get(qualifier)) != &"":
			bonus += float(modifiers[key])
	return roundi(bonus)


## Equipped primary/secondary weapons whose resolved stats are suppressed (0..2).
static func suppressed_weapon_count(loadout: Loadout) -> int:
	var n: int = 0
	for pair: Array in [[loadout.primary, loadout.primary_mods], [loadout.secondary, loadout.secondary_mods]]:
		var mods: Array[StringName] = []
		mods.assign(pair[1])
		var s: WeaponStats = resolve_weapon(StringName(pair[0]), mods)
		if s != null and s.suppressed:
			n += 1
	return n


static func detection_risk_for_total(total: int) -> int:
	return curve_tweak().dr_for_total(total)


static func curve_tweak() -> ConcealmentCurve:
	return ContentDB.tweak(CURVE_TWEAK) as ConcealmentCurve


## Merged modifier grants from skills (Loadout.skills: id -> 1 basic / 2 aced) and the first
## `perk_deck_cards` cards of the perk deck. Crew-wide grants (`team.*`) are NOT included: they go to the
## TEAM scope through team_modifier_sources() so the same skill or deck never stacks (modifiers.md).
## LIST keys hold Array[Dictionary], one `_source`-tagged entry per skill / card (header).
static func resolve_modifiers(loadout: Loadout) -> Dictionary:
	var out: Dictionary = {}
	for sid: StringName in _sorted_skill_ids(loadout):
		var skill: SkillDef = ContentDB.by_id(ContentDB.SKILLS, sid) as SkillDef
		if skill == null:
			continue
		_accumulate(out, _team_split(_skill_grants(skill, int(loadout.skills[sid])), false), sid)
	var deck: PerkDeckDef = _deck(loadout)
	if deck != null:
		for i: int in range(_unlocked_cards(loadout, deck)):
			var source: StringName = card_source(deck, i)
			var grants: Dictionary = {}
			_merge(grants, card_grants(loadout, deck, i), String(source))
			_accumulate(out, _team_split(grants, false), source)
	for key: Variant in out:
		if out[key] is Array:
			(out[key] as Array).sort_custom(
				func(a: Dictionary, b: Dictionary) -> bool:
					return ContentDB.id_less(a[LIST_SOURCE_FIELD], b[LIST_SOURCE_FIELD])
			)
	return out


## Crew-wide grants of one loadout, for Modifiers.set_source(Modifiers.TEAM, source, grants):
## { &"team_skill.<skill_id>": {team key: value}, &"team_perk.<deck>": {team key: value} }. The server
## sets them for every crew member; equal source names from two players overwrite each other, so a
## team skill or perk deck counts once (PD2). They also apply to the granter (D-031 QB-35), which is
## why resolve_modifiers() leaves them out.
static func team_modifier_sources(loadout: Loadout) -> Dictionary:
	var out: Dictionary = {}
	var tree: SkillTreeDef = SkillPoints.tree_def()
	for sid: StringName in _sorted_skill_ids(loadout):
		var skill: SkillDef = ContentDB.by_id(ContentDB.SKILLS, sid) as SkillDef
		if skill == null:
			continue
		var grants: Dictionary = _team_split(_skill_grants(skill, int(loadout.skills[sid])), true)
		if not grants.is_empty():
			out[tree.team_source(skill.id)] = grants
	var deck: PerkDeckDef = _deck(loadout)
	if deck != null:
		var grants: Dictionary = {}
		for i: int in range(_unlocked_cards(loadout, deck)):
			_merge(grants, _team_split(card_grants(loadout, deck, i), true), String(card_source(deck, i)))
		if not grants.is_empty():
			out[team_perk_source(deck.id)] = grants
	return out


## TEAM sources of a whole crew (B4-14), for the server at heist start:
##   for source in crew_team_modifier_sources(loadouts): Modifiers.set_source(Modifiers.TEAM, source, ...)
## Equal source names (same team skill or same perk deck held by several players) count once, and
## the strongest copy wins instead of the last one set: the most unlocked cards for `team_perk.*`, the
## higher level (aced over basic) for `team_skill.*`. Ties keep the earlier loadout. Cards and aced
## grants are cumulative, so the strongest copy holds every grant of the weaker ones.
static func crew_team_modifier_sources(loadouts: Array) -> Dictionary:
	var out: Dictionary = {}
	var rank: Dictionary = {}
	for item: Variant in loadouts:
		var l: Loadout = item as Loadout
		if l == null:
			continue
		var sources: Dictionary = team_modifier_sources(l)
		for s: Variant in sources:
			var r: int = _team_source_rank(l, StringName(s))
			if not out.has(s) or r > int(rank[s]):
				out[s] = sources[s]
				rank[s] = r
	return out


## One perk card's grants for this loadout: the card's "grants", plus (D-164, Copycat) the chosen option of its
## "choices" (Loadout.perk_choices; missing or out of range = option 0) and, on a "mimic" card, the mimicked deck's
## mimic_grants (Loadout.perk_mimic_deck; ignored unless that deck is mimicable and not this deck). A MULT key picked
## on several cards stacks additively like PD2 (+20% health twice = +40%): its n-th pick grants the cumulative ratio
## (1 + step x n) / (1 + step x (n - 1)), authoring rule 2 applied at resolve time.
static func card_grants(loadout: Loadout, deck: PerkDeckDef, index: int) -> Dictionary:
	var card: Dictionary = deck.cards[index]
	var out: Dictionary = (card.get("grants", {}) as Dictionary).duplicate(true)
	var choices: Array = card.get("choices", []) as Array
	if not choices.is_empty():
		var picked: Dictionary = (choices[chosen_option(loadout, deck, index)] as Dictionary).get("grants", {}) as Dictionary
		var extra: Dictionary = {}
		for key: Variant in picked:
			var v: Variant = picked[key]
			if ModifierKeys.type_of(StringName(key)) == ModifierKeys.Type.MULT:
				var step: float = float(v) - 1.0
				var n: int = _earlier_picks_of(loadout, deck, index, StringName(key)) + 1
				v = (1.0 + step * n) / (1.0 + step * (n - 1))
			extra[key] = v
		_merge(out, extra, String(card_source(deck, index)))
	if bool(card.get("mimic", false)):
		var mimic: PerkDeckDef = mimic_deck(loadout)
		if mimic != null:
			_merge(out, _mimic_ratios(loadout, deck, index, out, mimic.mimic_grants), String(card_source(deck, index)))
	return out


## LEAD r304 (PD2 sums armor / health multipliers): a mimicked MULT bonus adds to the deck's running total instead of
## multiplying it. With `total` the product of this key over cards 0..index-1 and this card so far (1 + the summed
## bonuses, authoring rule 2), a mimic step m grants (total + m) / total, so card-1 armor 1.05 + Ironclad 1.05 = 1.10.
## Crew-wide (`team.*`) keys pass through unchanged to the TEAM source.
static func _mimic_ratios(loadout: Loadout, deck: PerkDeckDef, index: int, own: Dictionary,
		mimic_grants: Dictionary) -> Dictionary:
	var tree: SkillTreeDef = SkillPoints.tree_def()
	var out: Dictionary = {}
	for key: Variant in mimic_grants:
		var k: StringName = StringName(key)
		var v: Variant = mimic_grants[key]
		if ModifierKeys.type_of(k) == ModifierKeys.Type.MULT and not tree.is_team_key(k):
			var total: float = float(own.get(k, 1.0))
			for j: int in range(index):
				total *= float(card_grants(loadout, deck, j).get(k, 1.0))
			v = (total + float(v) - 1.0) / total
		out[key] = v
	return out


## The option index chosen on card `index` (0-based) of the loadout's deck: Loadout.perk_choices[index] (int or String
## key, as saved), clamped to the card's choices; 0 when unset.
static func chosen_option(loadout: Loadout, deck: PerkDeckDef, index: int) -> int:
	var choices: Array = deck.cards[index].get("choices", []) as Array
	if choices.is_empty():
		return 0
	var v: Variant = loadout.perk_choices.get(index, loadout.perk_choices.get(str(index), 0))
	return clampi(int(v), 0, choices.size() - 1)


## Loadout.perk_mimic_deck when it names a mimicable deck other than the loadout's own; else null.
static func mimic_deck(loadout: Loadout) -> PerkDeckDef:
	if loadout.perk_mimic_deck == &"" or loadout.perk_mimic_deck == loadout.perk_deck:
		return null
	var d: PerkDeckDef = ContentDB.by_id(ContentDB.PERKS, loadout.perk_mimic_deck) as PerkDeckDef
	return d if d != null and d.mimicable else null


## &"perk.foreman" -> &"team_perk.foreman".
static func team_perk_source(deck_id: StringName) -> StringName:
	return StringName(TEAM_PERK_SOURCE_PREFIX + String(deck_id).trim_prefix("perk."))


## LIST `_source` of a perk card: &"<deck id>.card<n>" (n from 1), e.g. &"perk.foreman.card3".
static func card_source(deck: PerkDeckDef, index: int) -> StringName:
	return StringName("%s.card%d" % [deck.id, index + 1])


static func _sorted_skill_ids(loadout: Loadout) -> Array[StringName]:
	var ids: Array = []
	for sid: Variant in loadout.skills:
		if int(loadout.skills[sid]) > 0:
			ids.append(StringName(sid))
	ContentDB.sort_ids(ids)  # by text: PARAMS grants are last-wins
	var out: Array[StringName] = []
	out.assign(ids)
	return out


## One skill's grants at `level` (1 basic, 2 aced): basic merged with aced (aced LIST/PARAMS replace).
static func _skill_grants(skill: SkillDef, level: int) -> Dictionary:
	var grants: Dictionary = {}
	_merge(grants, skill.grants_basic, "skill %s" % skill.id)
	if level >= 2:
		_merge(grants, skill.grants_aced, "skill %s aced" % skill.id)
	return grants


static func _deck(loadout: Loadout) -> PerkDeckDef:
	if loadout.perk_deck == &"":
		return null
	return ContentDB.by_id(ContentDB.PERKS, loadout.perk_deck) as PerkDeckDef


static func _unlocked_cards(loadout: Loadout, deck: PerkDeckDef) -> int:
	return clampi(loadout.perk_deck_cards, 0, deck.cards.size())


## Strength of one of `loadout`'s TEAM sources: unlocked cards (perk deck) or skill level.
static func _team_source_rank(loadout: Loadout, source: StringName) -> int:
	var deck: PerkDeckDef = _deck(loadout)
	if deck != null and team_perk_source(deck.id) == source:
		return _unlocked_cards(loadout, deck)
	var tree: SkillTreeDef = SkillPoints.tree_def()
	for sid: Variant in loadout.skills:
		if tree.team_source(StringName(sid)) == source:
			return int(loadout.skills[sid])
	return 0


## How many choice cards before `index` picked an option granting `key` (for the cumulative MULT ratio).
static func _earlier_picks_of(loadout: Loadout, deck: PerkDeckDef, index: int, key: StringName) -> int:
	var n: int = 0
	for j: int in range(index):
		var choices: Array = deck.cards[j].get("choices", []) as Array
		if choices.is_empty():
			continue
		var g: Dictionary = (choices[chosen_option(loadout, deck, j)] as Dictionary).get("grants", {}) as Dictionary
		if g.has(key):
			n += 1
	return n


## The `team.*` grants (team = true) or every other grant (team = false).
static func _team_split(grants: Dictionary, team: bool) -> Dictionary:
	var tree: SkillTreeDef = SkillPoints.tree_def()
	var out: Dictionary = {}
	for key: Variant in grants:
		if tree.is_team_key(StringName(key)) == team:
			out[key] = grants[key]
	return out


## Adds one source's (already merged, known-key) grants: LIST keys append a `_source`-tagged copy,
## everything else merges by type.
static func _accumulate(into: Dictionary, grants: Dictionary, source: StringName) -> void:
	var rest: Dictionary = {}
	for key: Variant in grants:
		var k: StringName = StringName(key)
		if ModifierKeys.type_of(k) != ModifierKeys.Type.LIST:
			rest[k] = grants[key]
			continue
		var entry: Dictionary = (grants[key] as Dictionary).duplicate(true)
		entry[LIST_SOURCE_FIELD] = source
		if not into.has(k):
			var list: Array[Dictionary] = []
			into[k] = list
		(into[k] as Array).append(entry)
	_merge(into, rest, String(source))


static func _merge(into: Dictionary, grants: Dictionary, source: String) -> void:
	for key: Variant in grants:
		var k: StringName = StringName(key)
		if not ModifierKeys.is_known(k):
			Log.error(LOG_CHANNEL, "%s grants unregistered modifier key %s" % [source, k])
			continue
		var v: Variant = grants[key]
		if ModifierKeys.type_of(k) == ModifierKeys.Type.LIST and not v is Dictionary:
			Log.error(LOG_CHANNEL, "%s grants LIST key %s with a non-Dictionary value" % [source, k])
			continue
		if not into.has(k):
			into[k] = v
			continue
		match ModifierKeys.type_of(k):
			ModifierKeys.Type.MULT:
				into[k] = float(into[k]) * float(v)
			ModifierKeys.Type.ADD:
				into[k] = into[k] + v
			ModifierKeys.Type.FLAG:
				into[k] = bool(into[k]) or bool(v)
			_:
				into[k] = v


static func _illegal_reason(def: WeaponDef, m: WeaponModDef, by_slot: Dictionary) -> String:
	var slot: int = int(m.mod_type)
	if not def.mod_slots.has(slot):
		return "weapon has no slot for mod type %s" % Enums.ModType.keys()[slot]
	var allowed: Array = def.mod_slots[slot]
	if not allowed.has(m.id):
		return "not allowed in slot %s" % Enums.ModType.keys()[slot]
	if by_slot.has(slot):
		return "slot %s already holds %s" % [Enums.ModType.keys()[slot], (by_slot[slot] as WeaponModDef).id]
	for other: Variant in by_slot.values():
		var o: WeaponModDef = other as WeaponModDef
		if m.conflicts.has(o.id) or o.conflicts.has(m.id):
			return "conflicts with %s" % o.id
	return ""


static func _weapon_concealment(weapon_id: StringName, mods: Array[StringName], curve: ConcealmentCurve) -> int:
	# TODO(P4): D-022 QB-11 - the empty slot = 30 rule is P1 only. From P4 reject a loadout without
	# a primary and a secondary instead of counting the empty slot as empty_slot_concealment.
	if weapon_id == &"":
		return curve.empty_slot_concealment
	var s: WeaponStats = resolve_weapon(weapon_id, mods)
	if s == null:
		return curve.empty_slot_concealment
	return s.concealment


static func _clamp(s: WeaponStats) -> WeaponStats:
	var curve: ConcealmentCurve = curve_tweak()
	s.concealment = clampi(s.concealment, curve.weapon_concealment_min, curve.weapon_concealment_max)
	s.spread_deg_hip = maxf(s.spread_deg_hip, 0.0)
	s.spread_deg_ads = maxf(s.spread_deg_ads, 0.0)
	s.mag_size = maxi(s.mag_size, 1)
	s.total_ammo = maxi(s.total_ammo, s.mag_size)
	_derive_shell_reload(s)
	return s


## D-045 (data_schemas.md "Shell-by-shell reload timing"): a shell-fed weapon's reload totals are
## derived from the resolved timings and magazine size, never summed from mod deltas.
static func _derive_shell_reload(s: WeaponStats) -> void:
	var t: Vector2 = reload_times(s)
	s.reload_time_s = t.x
	s.reload_empty_time_s = t.y


## (tactical, empty) reload seconds of a stat block: derived per D-045 for shell-fed weapons
## (`reload_per_round_s > 0`), else the stored reload_time_s / reload_empty_time_s. StatCalculator
## uses this so unresolved base stats display the same totals as resolved ones.
static func reload_times(s: WeaponStats) -> Vector2:
	if s.reload_per_round_s <= 0.0:
		return Vector2(s.reload_time_s, s.reload_empty_time_s)
	var load_s: float = s.reload_start_s + float(s.mag_size) * s.reload_per_round_s
	return Vector2(load_s + s.reload_end_s, load_s + s.reload_end_empty_s)
