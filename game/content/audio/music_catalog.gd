## Heist music track catalog (B5-03, D-062). Owner: ENV B. Read-only view over ENV C's track registry.
## Source, in this order:
##   1. `table_override` (tests only): any Object with `all() -> Array`.
##   2. ENV C's `MusicTrackTable` at MusicCatalogTweak.table_path (res://world/audio/music/tracks.tres),
##      read as `MusicTrackTable.load_default().all()`. The class is looked up by name (UiNav.global_class)
##      so this file compiles before C ships it; entries are duck-typed with get(&"id"), get(&"unlock"),
##      get(&"default_for_heists").
##   3. The B STUB list in content/data/tweak/music.tres (MusicStubTrack, same fields) while that table
##      is missing. The stub is replaced by C's table.
## Every list is in stable id order (ContentDB.sort_ids). A track is unlocked when its `unlock` is &""
## or that id is in PlayerProfile.unlocks (Notoriety grants `unlock.music.<id>`, B5-02).
## The launch option `music_track` is resolve_choice(profile): the profile's music_choice while it still
## names a known, unlocked track, else &"" (= the heist default, HeistDef.music_track). Brief:
## content/docs/music.md.
class_name MusicCatalog
extends RefCounted

const TWEAK: MusicCatalogTweak = preload("res://content/data/tweak/music.tres")
const TABLE_CLASS: StringName = &"MusicTrackTable"
const KEY_PREFIX: String = "music."
const DEFAULT_KEY: StringName = &"ui.music.heist_default"

## Tests only: an Object with `all() -> Array` used instead of C's table and the stub. null = off.
static var table_override: Object = null


## Path of ENV C's MusicTrackTable resource (data, MusicCatalogTweak.table_path).
static func table_path() -> String:
	return TWEAK.table_path


## True when ENV C's table is present and readable (resource + MusicTrackTable class).
static func has_table() -> bool:
	return table_path() != "" and ResourceLoader.exists(table_path()) and UiNav.global_class(TABLE_CLASS) != null


## True while the catalog reads the B stub list (no override, no C table).
static func is_stub() -> bool:
	return table_override == null and not has_table()


## Every track as {id: StringName, unlock: StringName, default_for_heists: Array[StringName]}, sorted by id.
## Entries without an id are skipped; a repeated id keeps its first entry.
static func tracks() -> Array[Dictionary]:
	var by_id: Dictionary = {}
	for e: Variant in _entries():
		var d: Dictionary = _entry_dict(e)
		var id: StringName = d.get("id", &"")
		if id != &"" and not by_id.has(id):
			by_id[id] = d
	var ids: Array = by_id.keys()
	ContentDB.sort_ids(ids)
	var out: Array[Dictionary] = []
	for id: Variant in ids:
		out.append(by_id[id])
	return out


## Every track id, sorted.
static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for t: Dictionary in tracks():
		out.append(t["id"])
	return out


## The track's entry ({} for an unknown id).
static func track(id: StringName) -> Dictionary:
	for t: Dictionary in tracks():
		if t["id"] == id:
			return t
	return {}


static func has(id: StringName) -> bool:
	return id != &"" and (not track(id).is_empty() or is_pending(id))


## OF G1: `id` is registered while its stems are pending (MusicCatalogTweak.pending); never in tracks() / available().
static func is_pending(id: StringName) -> bool:
	return TWEAK.pending.has(id) or TWEAK.pending.has(String(id))


## The track `id` plays as: its pending fallback while its stems are missing, else itself.
static func playable_id(id: StringName) -> StringName:
	if track(id).is_empty() and is_pending(id):
		return StringName(String(TWEAK.pending.get(id, TWEAK.pending.get(String(id), ""))))
	return id


## True when `id` is a known track the profile may play (its unlock is &"" or owned). Unknown -> false.
static func is_unlocked(profile: PlayerProfile, id: StringName) -> bool:
	var t: Dictionary = track(id)
	if t.is_empty():
		return false
	var unlock: StringName = t["unlock"]
	return unlock == &"" or (profile != null and profile.unlocks.has(unlock))


## The ids `profile` may pick, sorted.
static func available(profile: PlayerProfile) -> Array[StringName]:
	var out: Array[StringName] = []
	for t: Dictionary in tracks():
		if is_unlocked(profile, t["id"]):
			out.append(t["id"])
	return out


## strings.csv key of a track's name: `music.<id>.name` (&"" -> the "Heist default" key).
static func display_key(id: StringName) -> StringName:
	if id == &"":
		return DEFAULT_KEY
	return StringName("%s%s.name" % [KEY_PREFIX, id])


## The Notoriety rank whose NotorietyDef.unlocks grants the track's unlock (0 = none / always owned).
static func unlock_rank(id: StringName) -> int:
	var t: Dictionary = track(id)
	var unlock: StringName = t.get("unlock", &"")
	if unlock == &"":
		return 0
	var table: NotorietyTable = Notoriety.table()
	if table == null:
		return 0
	for d: NotorietyDef in table.ranks:
		if d != null and d.unlocks.has(unlock):
			return d.rank
	return 0


## The track `heist_id` plays by default (first track listing it in default_for_heists, else &"").
static func default_for(heist_id: StringName) -> StringName:
	for t: Dictionary in tracks():
		if (t["default_for_heists"] as Array[StringName]).has(heist_id):
			return t["id"]
	return &""


## The launch option value for `profile`: music_choice while it is a known, unlocked track, else &""
## (heist default). A pick that was removed or is locked again falls back silently.
static func resolve_choice(profile: PlayerProfile) -> StringName:
	if profile == null or profile.music_choice == &"":
		return &""
	return profile.music_choice if is_unlocked(profile, profile.music_choice) else &""


static func _entries() -> Array:
	if table_override != null:
		return table_override.call(&"all") as Array
	if has_table():
		var script: Script = UiNav.global_class(TABLE_CLASS)
		var table: Object = script.call(&"load_default") as Object
		if table != null and table.has_method(&"all"):
			return table.call(&"all") as Array
		Log.warn(&"content", "MusicCatalog: %s has no readable all(); using the stub list" % TABLE_CLASS)
	var out: Array = []
	out.assign(TWEAK.tracks)
	return out


## Duck-typed entry (C's resource, a MusicStubTrack or a Dictionary) -> the catalog's Dictionary.
static func _entry_dict(e: Variant) -> Dictionary:
	if not (e is Object or e is Dictionary):
		return {}
	var heists: Array[StringName] = []
	var raw: Variant = _field(e, &"default_for_heists")
	if raw is Array or raw is PackedStringArray:
		for h: Variant in raw:
			heists.append(StringName(str(h)))
	return {
		"id": StringName(str(_field(e, &"id", ""))),
		"unlock": StringName(str(_field(e, &"unlock", ""))),
		"default_for_heists": heists,
	}


static func _field(e: Variant, key: StringName, fallback: Variant = null) -> Variant:
	var v: Variant = (e as Dictionary).get(String(key), (e as Dictionary).get(key)) if e is Dictionary else (e as Object).get(key)
	return fallback if v == null else v
