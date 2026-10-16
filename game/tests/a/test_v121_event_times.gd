## Lead note on v1.21: AnimDriver's crew-state event times (reload `done`, downed_arrested `disarm`,
## crew_cuffed_free `free`) come from the rig's SOURCE.txt at load, so a D retime needs no tweak change. The tweak
## values are only the fallback while a clip is missing, and they must equal SOURCE wherever SOURCE has the event.
extends TestCase

## [AnimTweak accessor result, clip, event, tweak fallback]
func _cases(tw: AnimTweak) -> Array[Array]:
	var out: Array[Array] = [
		[tw.disarm_s(), &"downed_arrested", &"disarm", tw.arrest_disarm_s],
		[tw.free_s(), &"crew_cuffed_free", &"free", tw.cuffed_free_s],
	]
	for key: Variant in AnimTweak.RELOAD_CLIPS:
		out.append([tw.reload_done(key), AnimTweak.RELOAD_CLIPS[key], &"done", float(tw.reload_done_s.get(key, -1.0))])
	return out


func test_event_times_follow_the_rig_source() -> void:
	var src: Dictionary = FpViewmodelTweak.source_events(AnimTweak.CHAR_SOURCE)
	assert_false(src.is_empty(), "rig SOURCE.txt parsed")
	var seen: int = 0
	for c: Array in _cases(AnimTweak.data()):
		var ev: Dictionary = src.get(c[1], {})
		if ev.has(c[2]):
			seen += 1
			var want: float = float(ev[c[2]]) / AnimTweak.SOURCE_FPS
			assert_near(float(c[0]), want, 0.0001, "%s %s read from SOURCE" % [c[1], c[2]])
			assert_near(float(c[3]), want, 0.002, "%s %s tweak fallback matches SOURCE" % [c[1], c[2]])
		else:
			assert_near(float(c[0]), float(c[3]), 0.0001, "%s %s falls back to the tweak" % [c[1], c[2]])
	assert_true(seen >= 2, "at least the pistol and rifle reloads come from SOURCE (%d)" % seen)


func test_a_retime_moves_the_event() -> void:
	var src: Dictionary = FpViewmodelTweak.source_events(AnimTweak.CHAR_SOURCE)
	var had: bool = src.has(&"reload_rifle")
	var old: Dictionary = (src.get(&"reload_rifle", {}) as Dictionary).duplicate()
	src[&"reload_rifle"] = {&"done": 45}
	assert_near(AnimTweak.data().reload_done(&"rifle"), 1.5, 0.0001, "a retimed done@45 is 1.5 s with no tweak change")
	if had:
		src[&"reload_rifle"] = old
	else:
		src.erase(&"reload_rifle")
