## Pushes resolved crew loadouts into the Modifiers service at heist start (contracts/modifiers.md:
## "ENV B ... at heist start on the server, calls Modifiers.set_source"). Owner: ENV B.
## * per slot: source SOURCE_LOADOUT = the loadout's resolved `modifiers` (skills + perk cards, without
##   `team.*` grants);
## * TEAM: LoadoutResolver.crew_team_modifier_sources() (`team_skill.<id>` / `team_perk.<deck>`, one
##   copy per source name, the strongest wins).
## Call on the authority with the same {slot: resolved Loadout} dict passed to HeistLauncher.launch.
## HeistRuntime.teardown() clears every source (Modifiers.clear_all()).
class_name ModifierPush
extends RefCounted

const SOURCE_LOADOUT: StringName = &"loadout"


static func push(loadouts: Dictionary) -> void:
	var list: Array = []
	for slot: Variant in loadouts:
		var l: Loadout = loadouts[slot] as Loadout
		if l == null:
			continue
		Modifiers.set_source(int(slot), SOURCE_LOADOUT, l.modifiers)
		list.append(l)
	var team: Dictionary = LoadoutResolver.crew_team_modifier_sources(list)
	for source: Variant in team:
		Modifiers.set_source(Modifiers.TEAM, StringName(source), team[source])
