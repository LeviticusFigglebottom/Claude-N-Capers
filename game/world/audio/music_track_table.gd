## Every music track the game knows (D-062): the hub jukebox lists `all()`, a heist plays
## `launch_options["music_track"]` or its HeistDef.music_track. Owner: ENV C.
## Data: res://world/audio/music/tracks.tres.
class_name MusicTrackTable
extends Resource

const DEFAULT_PATH: String = "res://world/audio/music/tracks.tres"

@export var entries: Array[MusicTrackEntry] = []


static func load_default() -> MusicTrackTable:
	if not ResourceLoader.exists(DEFAULT_PATH):
		return MusicTrackTable.new()
	var t: MusicTrackTable = load(DEFAULT_PATH) as MusicTrackTable
	return t if t != null else MusicTrackTable.new()


func all() -> Array[MusicTrackEntry]:
	return entries.duplicate()


func find(track_id: StringName) -> MusicTrackEntry:
	for e: MusicTrackEntry in entries:
		if e.id == track_id:
			return e
	return null


## First track that lists `heist_id` in default_for_heists, else &"".
func default_for(heist_id: StringName) -> StringName:
	for e: MusicTrackEntry in entries:
		if e.default_for_heists.has(heist_id):
			return e.id
	return &""


## MusicTrack for `track_id`: via its table entry, else the conventional folder.
func load_track(track_id: StringName) -> MusicTrack:
	var e: MusicTrackEntry = find(track_id)
	if e != null:
		return e.load_track()
	return MusicTrack.load_track(track_id)
