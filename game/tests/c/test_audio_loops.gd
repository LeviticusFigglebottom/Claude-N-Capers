## PO6-07 / D-114 §3: one-shots are one-shot, and every loop cue has a stop owner. Simulates the
## EventBus facts headless and checks loop state and stream loop flags (not audio output).
extends TestCase

var _reg: AudioCueRegistry


func before_all() -> void:
	_reg = AudioCueLib.registry()


func _make_player() -> CuePlayer:
	var p: CuePlayer = CuePlayer.new()
	p.siren_delay_s = 0.05
	add_child(p)
	return p


## Players in the pool that are playing a looping stream right now.
func _looping_players(p: CuePlayer) -> int:
	var n: int = 0
	for c: Node in p.get_children():
		var s3: AudioStreamPlayer3D = c as AudioStreamPlayer3D
		var s2: AudioStreamPlayer = c as AudioStreamPlayer
		if s3 != null and s3.playing and AudioCueLib.stream_loops(s3.stream):
			n += 1
		elif s2 != null and s2.playing and AudioCueLib.stream_loops(s2.stream):
			n += 1
	return n


func test_every_loop_cue_has_a_stop_owner() -> void:
	if _reg == null or _reg.cues.is_empty():
		skip("no registry")
		return
	var loops: int = 0
	for c: AudioCueDef in _reg.cues:
		if c.loop:
			loops += 1
			assert_true(CuePlayer.LOOP_STOP_OWNERS.has(c.id), "%s loops but has no stop owner" % c.id)
	for id: StringName in CuePlayer.LOOP_STOP_OWNERS.keys():
		var c: AudioCueDef = _reg.get_cue(id)
		assert_true(c != null and c.loop, "%s listed as a loop owner but is not a loop cue" % id)
	assert_true(loops >= 10, "expected the audited loop set, got %d" % loops)


func test_requested_loop_cue_plays_once() -> void:
	var player: CuePlayer = _make_player()
	# A's PagerSystem / special brains request loop cues through audio_cue_requested (unowned).
	for id: StringName in [&"cue.pager_beep", &"cue.pager_radio", &"cue.aegis_pulse", &"cue.stinger_arc",
			&"cue.phantom_hum", &"cue.police_siren_far"]:
		EventBus.audio_cue_requested.emit(id, Vector3(1, 0, 1), 0)
	assert_eq(_looping_players(player), 0, "no unowned looping player")
	assert_true(player.active_loop_keys().is_empty(), "no keyed loop from requests")
	# A keyed loop of the same cue still loops, and does not flip the shared stream for one-shots.
	player.start_loop(&"k", &"cue.pager_beep")
	assert_eq(_looping_players(player), 1, "keyed loop loops")
	var cue: AudioCueDef = _reg.get_cue(&"cue.pager_beep")
	assert_false(AudioCueLib.stream_loops(cue.streams[0]), "shared stream stays one-shot")
	player.stop_loop(&"k")
	assert_eq(_looping_players(player), 0, "stopped")
	player.queue_free()


func test_pager_beep_stops_after_answer_or_fail() -> void:
	var player: CuePlayer = _make_player()
	EventBus.pager_started.emit(3, 0)
	EventBus.audio_cue_requested.emit(&"cue.pager_beep", Vector3.ZERO, 0)
	EventBus.pager_answer_started.emit(3, 0)
	EventBus.audio_cue_requested.emit(&"cue.pager_radio", Vector3.ZERO, 0)
	EventBus.pager_answered.emit(3, 0, 1)
	assert_eq(_looping_players(player), 0, "nothing loops after the answer")
	EventBus.pager_started.emit(4, 0)
	EventBus.pager_failed.emit(4, &"expired")
	assert_eq(_looping_players(player), 0, "nothing loops after a failed pager")
	player.queue_free()


func test_siren_stops_when_assault_ends() -> void:
	var player: CuePlayer = _make_player()
	EventBus.alarm_raised.emit(&"test", 0)
	EventBus.assault_phase_changed.emit(Enums.AssaultPhase.ANTICIPATION, 1)
	assert_true(player.is_loop_active(CuePlayer.SIREN_KEY), "siren while police are inbound")
	EventBus.assault_phase_changed.emit(Enums.AssaultPhase.FADE, 1)
	assert_false(player.is_loop_active(CuePlayer.SIREN_KEY), "siren stops at assault fade")
	await wait_seconds(0.15)
	assert_false(player.is_loop_active(CuePlayer.SIREN_KEY), "the delayed siren timer does not restart it")
	EventBus.assault_phase_changed.emit(Enums.AssaultPhase.BUILD, 2)
	assert_true(player.is_loop_active(CuePlayer.SIREN_KEY), "siren back for the next wave")
	EventBus.heist_ended.emit({"success": false})
	assert_true(player.active_loop_keys().is_empty(), "all loops stop at heist end")
	player.queue_free()


func test_held_trigger_weapon_loop_stops_on_release() -> void:
	var player: CuePlayer = _make_player()
	player.weapon_loop_tail_s = 0.1
	var def: WeaponDef = WeaponDef.new()
	def.fire_cue = &"cue.weapon_minigun_fire"
	assert_eq(player.weapon_fire_cue(&"x", false, def), &"cue.weapon_minigun_fire")
	for i: int in range(5):
		player.play_cue(&"cue.weapon_minigun_fire")  # direct one-shot plays never loop
	assert_eq(_looping_players(player), 0, "direct plays of a weapon loop cue do not loop")
	# The held-trigger path (what _on_weapon_fired does for a loop cue): keyed loop + last-shot time.
	player.start_loop(&"weapon_55", &"cue.weapon_minigun_fire")
	player._weapon_last_ms[&"weapon_55"] = Time.get_ticks_msec()
	assert_true(player.is_loop_active(&"weapon_55"), "loop while firing")
	await wait_seconds(0.3)
	assert_false(player.is_loop_active(&"weapon_55"), "loop stops after the trigger is released")
	assert_eq(player.last_cue, &"cue.weapon_minigun_spin_down", "spin-down tail")
	player.queue_free()


func test_loop_safety_cap_and_npc_death() -> void:
	var player: CuePlayer = _make_player()
	player.loop_max_s[&"cue.lockpick"] = 0.1
	EventBus.interaction_started.emit(91, 0, &"lockpick")
	assert_true(player.is_loop_active(&"interact_91"), "lockpick loop")
	await wait_seconds(0.3)
	assert_false(player.is_loop_active(&"interact_91"), "cap stops an orphaned loop")
	EventBus.interaction_started.emit(92, 1, &"lockpick")
	EventBus.crew_downed.emit(1, 1)
	assert_false(player.is_loop_active(&"interact_92"), "downed picker stops the lockpick loop")
	EventBus.captain_arrived.emit(88)
	EventBus.npc_killed.emit(88, 0, {})
	assert_false(player.is_loop_active(&"captain_88"), "aegis loop stops when the captain dies")
	player.queue_free()
