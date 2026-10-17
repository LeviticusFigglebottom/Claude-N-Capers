## OF G1 (round 244): MusicCatalogTweak.pending, heist tracks registered before their stems land (C's G2).
extends TestCase


## OF G1 (round 244): a heist track whose stems are not in C's table yet is registered as pending with a fallback, never
## pickable; once C's table lists it the pending entry must go (strict again).
func test_pending_tracks() -> void:
	var tw: MusicCatalogTweak = load("res://content/data/tweak/music.tres") as MusicCatalogTweak
	for id: Variant in tw.pending:
		var tid: StringName = StringName(String(id))
		var fb: StringName = StringName(String(tw.pending[id]))
		assert_true(MusicCatalog.has(tid), "%s registered" % tid)
		assert_true(MusicCatalog.track(tid).is_empty(), "%s: C's table lists it now: remove the pending entry" % tid)
		assert_false(MusicCatalog.available(null).has(tid), "%s never pickable while pending" % tid)
		assert_true(not MusicCatalog.track(fb).is_empty(), "%s falls back to a real track (%s)" % [tid, fb])
		assert_eq(MusicCatalog.playable_id(tid), fb)
		assert_true(UiText.has(MusicCatalog.display_key(tid)), "%s has a name" % tid)
	assert_eq(MusicCatalog.playable_id(&"glasshouse"), &"glasshouse")


## A track for a staged (hidden) heist is in the catalogue but not pickable until the heist is offered (OF's stems land
## before OF-A6 unhides it).
func test_staged_heist_track_not_pickable() -> void:
	for t: Dictionary in MusicCatalog.tracks():
		for h: StringName in t["default_for_heists"] as Array[StringName]:
			if HeistCatalog.heist_list().heists.has(h) and not HeistCatalog.ids().has(h):
				assert_true(MusicCatalog.has(t["id"]))
				assert_false(MusicCatalog.available(null).has(t["id"]), "%s waits for %s" % [t["id"], h])
