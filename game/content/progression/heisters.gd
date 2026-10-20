## Heister choice (D-073). Owner: ENV B. Static and pure apart from reading the roster data.
## `Loadout.heister` names one of HeisterRoster.ids (&"rook" / &"sable" / &"dutch" / &"wren"); &"" in a profile
## means "no preference" (the picker's "Any free heister").
##
## Uniqueness rule (PD2: one of each heister per crew), applied by assign():
## 1. Humans are served first-come: the slot that claimed a heister first keeps it (LobbyState orders human
##    slots by when each slot first sent its current pick; solo has one human).
## 2. A later conflicting pick is not refused (it never blocks Start): that slot falls back to the next free
##    heister after its pick in roster order, wrapping around. A "no preference" pick takes the first free
##    heister in roster order. Conflicts are served after every uncontested pick, in claim order.
## 3. AI teammates (and empty seats the launcher fills with AI) take the remaining heisters in roster order,
##    lowest slot first.
## With at most 4 crew and 4 heisters every launched slot gets a distinct heister.
class_name Heisters
extends RefCounted

static var _roster: HeisterRoster = null


static func roster() -> HeisterRoster:
	if _roster == null:
		_roster = HeisterRoster.load_default()
	return _roster


static func ids() -> Array[StringName]:
	return roster().ids.duplicate()


static func is_known(id: StringName) -> bool:
	return id != &"" and roster().ids.has(id)


## strings.csv key of the heister's name (`crew.<id>`); &"" = `ui.heister.any`.
static func name_key(id: StringName) -> StringName:
	return StringName("crew.%s" % id) if is_known(id) else &"ui.heister.any"


static func display_name(id: StringName) -> String:
	return UiText.t(name_key(id))


## D-111: the unlock id that earns heister `id` (&"" = free from the start).
static func unlock_of(id: StringName) -> StringName:
	return StringName(roster().unlocks.get(id, &""))


## Whether `profile` may pick heister `id` (&"" = "any free heister" is always allowed).
static func is_unlocked(profile: PlayerProfile, id: StringName) -> bool:
	var u: StringName = unlock_of(id)
	return u == &"" or (profile != null and profile.unlocks.has(u))


static func accent(id: StringName) -> Color:
	var r: HeisterRoster = roster()
	return r.accents.get(id, r.generic_accent) as Color if is_known(id) else r.generic_accent


## ENV D's 2D portrait (`<portrait_dir>/<id>.png`), or null while none exists.
static func portrait(id: StringName) -> Texture2D:
	if not is_known(id):
		return null
	var path: String = "%s/%s.png" % [roster().portrait_dir, id]
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## The first heister not in `taken`, starting after `pick` in roster order (wrapping); from the start of the
## roster when `pick` is unknown or &"". &"" when every heister is taken.
static func next_free(pick: StringName, taken: Array[StringName]) -> StringName:
	var order: Array[StringName] = roster().ids
	var start: int = order.find(pick) + 1 if is_known(pick) else 0
	for i: int in range(order.size()):
		var id: StringName = order[(start + i) % order.size()]
		if not taken.has(id):
			return id
	return &""


## Distinct heisters per slot (see the header rule). `order` = human slots, first claim first; `picks` =
## slot -> picked id (&"" = no preference); `fill` = AI / empty slots in the order they take what is left.
## `fill_picks` (PO-19, CrewLoadouts.outfit_picks) = fill slot -> the bot's outfit: a heister it takes when still free
## (else the next free one), or a heist suit it always wears (a suit takes no heister).
## Returns slot -> heister id or suit (&"" only when the roster ran out).
static func assign(order: Array[int], picks: Dictionary, fill: Array[int], fill_picks: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	var taken: Array[StringName] = []
	var later: Array[int] = []
	for slot: int in order:
		var pick: StringName = StringName(picks.get(slot, &""))
		if is_known(pick) and not taken.has(pick):
			out[slot] = pick
			taken.append(pick)
		else:
			later.append(slot)
	for slot: int in fill:
		var want: StringName = StringName(fill_picks.get(slot, &""))
		if want != &"" and not is_known(want):
			out[slot] = want  # a heist suit: any number of bots
		elif is_known(want) and not taken.has(want):
			out[slot] = want
			taken.append(want)
	for slot: int in later + fill:
		if out.has(slot):
			continue
		var pick: StringName = StringName(picks.get(slot, &"")) if later.has(slot) else &""
		var id: StringName = next_free(pick, taken)
		out[slot] = id
		if id != &"":
			taken.append(id)
	return out


## Solo launch: the local player's pick, then the AI teammates (Net.start_solo seats the local player
## first and AI in the next free slots) -> slot -> heister id.
static func solo(pick: StringName, local_slot: int, ai_teammates: int, fill_picks: Dictionary = {}) -> Dictionary:
	return assign([local_slot] as Array[int], {local_slot: pick}, solo_ai_slots(local_slot, ai_teammates), fill_picks)


## The slots Net.start_solo gives `ai_teammates` AI teammates: the lowest crew slots other than the local one.
static func solo_ai_slots(local_slot: int, ai_teammates: int) -> Array[int]:
	var out: Array[int] = []
	var slot: int = 0
	while out.size() < ai_teammates and slot < LobbyState.MAX_CREW:
		if slot != local_slot:
			out.append(slot)
		slot += 1
	return out


## HeistLauncher loadouts for AI slots: ENV A's default AI loadout (CrewWeapons.build_loadout(null), the one
## a slot without an `options.loadouts` entry gets) with the slot's heister. `heisters` = slot -> id.
## PO-19: with `profile` (the host's), the i-th AI slot in slot order carries crew bot slot i's loadout
## (CrewLoadouts.bot_loadout: its primary + mods, armor and mask).
static func ai_loadouts(heisters: Dictionary, profile: PlayerProfile = null) -> Dictionary:
	var out: Dictionary = {}
	var slots: Array = heisters.keys()
	slots.sort()
	for i: int in range(slots.size()):
		var slot: int = int(slots[i])
		var id: StringName = StringName(heisters[slots[i]])
		if profile != null and i < CrewLoadouts.SLOTS:
			out[slot] = CrewLoadouts.bot_loadout(i, profile, id)
		else:
			var l: Loadout = CrewWeapons.build_loadout(null)  # a fresh Loadout per call
			l.heister = id
			out[slot] = l
	return out
