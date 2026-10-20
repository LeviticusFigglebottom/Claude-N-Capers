## QB-L2: hands every crew slot's Loadout modifiers to the Modifiers service at heist start. Owner: ENV A.
## HeistRuntime.start() calls push() on the server BEFORE the crew spawns, so max health / armor,
## inventory counts and weapon arming read the skills and perk deck of the loadout that is actually
## used (the slot's `options.loadouts` entry, or the default loadout CrewWeapons.build_loadout builds).
## The push itself is ENV B's ModifierPush.push (per slot source &"loadout" = Loadout.modifiers; TEAM
## sources from LoadoutResolver.crew_team_modifier_sources). It reads Loadout.modifiers as given, so
## effective_loadouts() resolves them (LoadoutResolver.resolve_modifiers, on a copy) when a loadout with
## skills or a perk deck carries none. set_source is idempotent: a push already made by the menu flow
## is harmless.
class_name LoadoutModifiers
extends RefCounted

## Per-slot source name of the loadout's skill + perk grants (ModifierPush.SOURCE_LOADOUT).
const SOURCE: StringName = &"loadout"


## The effective (resolved) loadout of every slot in `slots`: `loadouts[slot]` or the default one.
static func effective_loadouts(loadouts: Dictionary, slots: Array) -> Dictionary:
	var out: Dictionary = {}
	for slot: Variant in slots:
		var l: Loadout = CrewWeapons.build_loadout(loadouts.get(int(slot)) as Loadout)
		if bool((Net.crew.get(int(slot), {}) as Dictionary).get("is_ai", false)):
			l = bot_armed(l)
		if _needs_modifiers(l):
			l = l.duplicate() as Loadout
			l.modifiers = LoadoutResolver.resolve_modifiers(l)
		out[int(slot)] = l
	return out


## LEAD ruling 2026-10-20 (D-145.4): an AI teammate with no primary gets CombatTweak.bot_default_primary (a resolved
## copy; a bot slot that equips a primary keeps it, and so does every human).
static func bot_armed(l: Loadout) -> Loadout:
	var rifle: StringName = CombatTweak.data().bot_default_primary
	if l == null or l.primary != &"" or rifle == &"":
		return l
	var out: Loadout = l.duplicate() as Loadout
	out.primary = rifle
	out.primary_mods = [] as Array[StringName]
	out.resolved_primary = null
	return CrewWeapons.build_loadout(out)


## Server: push the modifiers of `loadouts` ({slot: Loadout}, see effective_loadouts).
static func push(loadouts: Dictionary) -> void:
	if Net.is_authority():
		ModifierPush.push(loadouts)


## Personal grants of `l` (resolved now when a loadout with skills or a perk deck carries none).
static func modifiers_of(l: Loadout) -> Dictionary:
	return LoadoutResolver.resolve_modifiers(l) if _needs_modifiers(l) else l.modifiers


static func _needs_modifiers(l: Loadout) -> bool:
	return l != null and l.modifiers.is_empty() and (not l.skills.is_empty() or l.perk_deck != &"")
