## One row of the music track table (D-062): a track id, where its stems live, whether it must be
## unlocked (B5-02 Notoriety rank) and which heists use it by default. Owner: ENV C.
class_name MusicTrackEntry
extends Resource

@export var id: StringName = &""
## Folder holding <id>.tres (MusicTrack) and its stems.
@export var stems: String = ""
## Unlock id owned by ENV B (`unlock.music.*`); &"" = always owned.
@export var unlock: StringName = &""
@export var default_for_heists: Array[StringName] = []


## The MusicTrack resource for this entry, or null when its stems are not built yet.
func load_track() -> MusicTrack:
	var path: String = stems.path_join("%s.tres" % id)
	if not ResourceLoader.exists(path):
		return null
	return load(path) as MusicTrack
