## One heist music track of the B-side STUB list (B5-03, D-062). Owner: ENV B.
## Mirrors the fields of ENV C's MusicTrackTable entries (id, stems, default_for_heists, unlock) so
## MusicCatalog reads both the same way (duck-typed with get()). Lives only inside
## content/data/tweak/music.tres; replaced by C's table once res://world/audio/music/tracks.tres exists.
class_name MusicStubTrack
extends Resource

## Track id (`music.<id>.name` is its display string).
@export var id: StringName = &""
## Path of the track's stem resource (MusicTrack .tres). Informational for B; ENV C plays it.
@export var stems: String = ""
## Heist ids that play this track by default (HeistDef.music_track).
@export var default_for_heists: Array[StringName] = []
## Unlock id that owns the track (PlayerProfile.unlocks, granted by a Notoriety rank); &"" = always owned.
@export var unlock: StringName = &""
