## Music selection (D-062 / B5-03): MusicTrackTable data, MusicDirector jukebox preview on a bare
## instance, and the heist WorldEnvironment brightness hook (B5-01). Headless: checks state only.
extends TestCase

const HEIST_TRACKS: Array[StringName] = [&"glasshouse", &"night_deposit", &"shadow_ledger", &"dockside_burn",
		&"gallery_night", &"ostrander_federal"]
const UNLOCKS: Dictionary = {
	&"vault_hymn": &"unlock.music.vault_hymn", &"long_con": &"unlock.music.long_con",
	&"last_call": &"unlock.music.last_call",
}


func test_table_entries() -> void:
	var t: MusicTrackTable = MusicTrackTable.load_default()
	var ids: Array[StringName] = []
	for e: MusicTrackEntry in t.all():
		assert_false(ids.has(e.id), "unique id %s" % e.id)
		ids.append(e.id)
		# B reads entries duck-typed through get().
		assert_eq(e.get(&"id"), e.id)
		assert_true(e.get(&"default_for_heists") is Array, "%s default_for_heists is an Array" % e.id)
	for h: StringName in HEIST_TRACKS:
		assert_eq(t.default_for(h), h, "heist %s defaults to its own track" % h)
		assert_eq(t.find(h).unlock, &"", "heist track %s is always owned" % h)
	for k: StringName in UNLOCKS:
		assert_true(t.find(k) != null, "unlockable track %s" % k)
		if t.find(k) != null:
			assert_eq(t.find(k).unlock, UNLOCKS[k], "%s unlock id" % k)
	for h: StringName in HEIST_TRACKS:
		assert_true(t.load_track(h) != null, "%s stems load through the table (D-117)" % h)


func test_heist_defs_use_table_tracks() -> void:
	var t: MusicTrackTable = MusicTrackTable.load_default()
	for h: StringName in HEIST_TRACKS:
		var d: HeistDef = load("res://world/heists/%s/%s_def.tres" % [h, h]) as HeistDef
		if d != null:
			assert_true(t.find(d.music_track) != null, "%s music_track %s is in the table" % [h, d.music_track])


func test_preview_on_bare_director() -> void:
	var m: MusicDirector = MusicDirector.new()
	m.listen_to_event_bus = false
	assert_true(m.preview(&"glasshouse"), "preview glasshouse assault")
	assert_eq(m.current_stem, MusicTrack.STEM_ASSAULT, "assault stem selected immediately")
	assert_eq(m.track_id, &"glasshouse")
	assert_true(m.preview(&"glasshouse", MusicTrack.STEM_STEALTH), "switch preview stem")
	assert_eq(m.current_stem, MusicTrack.STEM_STEALTH)
	m.stop_preview()
	assert_eq(m.current_stem, MusicDirector.SILENCE, "stop_preview silences")
	assert_false(m.preview(&"no_such_track"), "unknown track refused")
	for h: StringName in HEIST_TRACKS:
		assert_true(m.preview(h), "jukebox preview (default assault stem) plays %s" % h)
	m.free()


func test_preview_in_tree() -> void:
	var m: MusicDirector = MusicDirector.new()
	m.listen_to_event_bus = false
	m.track_id = &""
	get_tree().root.add_child(m)
	assert_true(m.preview(&"glasshouse"), "preview in tree")
	assert_eq(m.current_stem, MusicTrack.STEM_ASSAULT)
	m.stop_preview()
	assert_eq(m.current_stem, MusicDirector.SILENCE)
	m.queue_free()
	await get_tree().process_frame


func test_heist_track_id_outside_heist_is_empty() -> void:
	assert_eq(MusicDirector.heist_track_id(null), &"", "no runtime -> no heist track")


func test_world_environment_hook_is_safe_without_options() -> void:
	var we: HeistWorldEnvironment = HeistWorldEnvironment.new()
	we.environment = Environment.new()
	get_tree().root.add_child(we)
	var has_b: bool = HeistWorldEnvironment._global_class(&"SettingsApplier") != null
	assert_eq(we.apply_brightness(), has_b, "applies only when ENV B's SettingsApplier exists")
	we.queue_free()
	await get_tree().process_frame
