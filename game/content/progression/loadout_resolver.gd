## Single source of truth for resolved weapon stats, concealment and detection risk
## (contracts/data_schemas.md, pd2_fidelity.md S2.4, P6). Owner: ENV B.
##
## resolve(loadout) returns a resolved COPY of the loadout:
## * resolved_primary / resolved_secondary = WeaponDef.base.plus(delta) for each mod in its slot,
##   where an equipped mod replaces the weapon's default (stock) mod of the same ModType. Then
##   clamps: concealment to the curve's weapon range (0..30), spreads >= 0, mag >= 1,
##   total_ammo >= mag. Skill modifiers are NOT baked in (ENV A applies them at runtime).
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
##   Crew-wide skill grants (`team.*`) are excluded; team_modifier_sources() returns them per skill as
##   TEAM sources `team_skill.<skill_id>` (modifiers.md non-stacking rule).
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
const CONCEALMENT_QUALIFIERS: Array[StringName] = [&"all", &"primary", &"secondary", &"melee", &"armor"]


static func resolve(loadout: Loadout) -> Loadout:
	var out: Loadout = loadout.duplicate(true) as Loadout
	out.resolved_primary = resolve_weapon(loadout.primary, loadout.primary_mods)
	out.resolved_secondary = resolve_weapon(loadout.secondary, loadout.secondary_mods)
	var bd: Dictionary = concealment_breakdown(loadout)
	out.concealment_total = int(bd["total"])
	out.detection_risk = int(bd["detection_risk"])
	out.modifiers = resolve_modifiers(loadout)
	return out


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
		if qualifier == &"all" or StringName(loadout.get(qualifier)) != &"":
			bonus += float(modifiers[key])
	return roundi(bonus)


static func detection_risk_for_total(total: int) -> int:
	return curve_tweak().dr_for_total(total)


static func curve_tweak() -> ConcealmentCurve:
	return ContentDB.tweak(CURVE_TWEAK) as ConcealmentCurve


## Merged modifier grants from skills (Loadout.skills: id -> 1 basic / 2 aced) and the first
## `perk_deck_cards` cards of the perk deck. Crew-wide skill grants (`team.*`) are NOT included: they go
## to the TEAM scope through team_modifier_sources() so the same skill never stacks (modifiers.md).
static func resolve_modifiers(loadout: Loadout) -> Dictionary:
	var out: Dictionary = {}
	var skill_ids: Array = loadout.skills.keys()
	ContentDB.sort_ids(skill_ids)  # by text: PARAMS grants are last-wins
	for sid: Variant in skill_ids:
		var level: int = int(loadout.skills[sid])
		var skill: SkillDef = ContentDB.by_id(ContentDB.SKILLS, StringName(sid)) as SkillDef
		if skill == null or level <= 0:
			continue
		_merge(out, _team_split(skill.grants_basic, false), "skill %s" % sid)
		if level >= 2:
			_merge(out, _team_split(skill.grants_aced, false), "skill %s aced" % sid)
	if loadout.perk_deck != &"":
		var deck: PerkDeckDef = ContentDB.by_id(ContentDB.PERKS, loadout.perk_deck) as PerkDeckDef
		if deck != null:
			var n: int = mini(loadout.perk_deck_cards, deck.cards.size())
			for i: int in range(n):
				_merge(out, deck.cards[i].get("grants", {}), "%s card %d" % [deck.id, i + 1])
	return out


## Crew-wide skill grants of one loadout: { &"team_skill.<skill_id>": {team key: value} }. The server
## calls Modifiers.set_source(Modifiers.TEAM, source, grants) for every crew member's entries; equal
## source names from two players overwrite each other, so a team skill counts once (PD2).
static func team_modifier_sources(loadout: Loadout) -> Dictionary:
	var out: Dictionary = {}
	var tree: SkillTreeDef = SkillPoints.tree_def()
	var skill_ids: Array = loadout.skills.keys()
	ContentDB.sort_ids(skill_ids)
	for sid: Variant in skill_ids:
		var level: int = int(loadout.skills[sid])
		var skill: SkillDef = ContentDB.by_id(ContentDB.SKILLS, StringName(sid)) as SkillDef
		if skill == null or level <= 0:
			continue
		var grants: Dictionary = {}
		_merge(grants, _team_split(skill.grants_basic, true), "skill %s" % sid)
		if level >= 2:
			_merge(grants, _team_split(skill.grants_aced, true), "skill %s aced" % sid)
		if not grants.is_empty():
			out[tree.team_source(skill.id)] = grants
	return out


## The `team.*` grants (team = true) or every other grant (team = false).
static func _team_split(grants: Dictionary, team: bool) -> Dictionary:
	var tree: SkillTreeDef = SkillPoints.tree_def()
	var out: Dictionary = {}
	for key: Variant in grants:
		if tree.is_team_key(StringName(key)) == team:
			out[key] = grants[key]
	return out


static func _merge(into: Dictionary, grants: Dictionary, source: String) -> void:
	for key: Variant in grants:
		var k: StringName = StringName(key)
		if not ModifierKeys.is_known(k):
			Log.error(LOG_CHANNEL, "%s grants unregistered modifier key %s" % [source, k])
			continue
		var v: Variant = grants[key]
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
	return s
