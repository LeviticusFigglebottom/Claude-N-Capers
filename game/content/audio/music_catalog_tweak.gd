## MusicCatalog data (B5-03, D-062). Owner: ENV B. Data: res://content/data/tweak/music.tres.
## `table_path` names ENV C's MusicTrackTable resource (the authority once it exists); `tracks` is the
## STUB list MusicCatalog falls back to while that table is missing. The stub is replaced by C's table:
## when the table lands, the stub stays only as the fallback for trees without it.
class_name MusicCatalogTweak
extends Resource

## ENV C's MusicTrackTable .tres (D-062). Kept in data so B code holds no path into another env.
@export var table_path: String = ""
## Fallback list, used only while `table_path` does not exist (any order; the catalog sorts by id).
@export var tracks: Array[MusicStubTrack] = []
## OF G1 (round 244): track id -> fallback track id for a heist whose HeistDef.music_track has no stems in ENV C's table
## yet (they land with that heist's G2). A pending id counts as registered (MusicCatalog.has) but is never pickable;
## MusicDirector keeps the map's fallback track meanwhile. Remove the entry when C's table lists the id (test_music
## fails while a pending id is also in the table).
@export var pending: Dictionary = {}
