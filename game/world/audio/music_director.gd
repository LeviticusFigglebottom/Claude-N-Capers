## Heist music: picks the stem for the current heist/assault phase and crossfades to it on the next
## BAR boundary of the playing stem (beat-synced from playback position), keeping the musical
## phrase position. Win/lose stingers on heist_ended. Headless-safe (no audio output required:
## tests read target_stem / current_stem).
## Track choice (D-062): in a heist, `launch_options["music_track"]` when non-empty, else the map's
## HeistDef.music_track, else `track_id`. Hub jukebox: a bare `MusicDirector.new()` with
## `listen_to_event_bus = false` plays any table track via preview() / stop_preview().
class_name MusicDirector
extends Node

signal stem_changed(stem_name: StringName)

const SILENCE: StringName = &""
const FADE_FLOOR_DB: float = -60.0
## set_ducked (hub_map.md): -6 dB over 0.25 s.
const DUCK_DB: float = -6.0
const DUCK_S: float = 0.25

@export var track_id: StringName = &"glasshouse"
@export var track: MusicTrack
@export var listen_to_event_bus: bool = true
## Crossfade length in beats (applied at the bar line).
@export var crossfade_beats: float = 1.0
@export var bus: StringName = &"Music"

## Stem the director wants (changes immediately on a phase fact).
var target_stem: StringName = SILENCE
## Stem actually playing (changes at the bar boundary).
var current_stem: StringName = SILENCE
var heist_phase: int = Enums.HeistPhase.LOADING
var assault_phase: int = Enums.AssaultPhase.NONE
var last_stinger: StringName = &""

var _players: Array[AudioStreamPlayer] = []
var _active: int = -1
var _stinger: AudioStreamPlayer = null
var _tweens: Array[Tween] = [null, null]
var _duck_db: float = 0.0
var _duck_target: float = 0.0
var _duck_tween: Tween = null
## True once the track came from the heist (launch options / HeistDef), not the `track_id` export.
var _heist_track: bool = false


## Pure mapping (PD2 music logic): stealth bed while casing/stealth; loud follows the assault
## cycle (control between waves, anticipation riser, assault during build/sustain, fade);
## escape keeps the assault stem; loading/ended are silent.
static func stem_for(p_heist_phase: int, p_assault_phase: int) -> StringName:
	match p_heist_phase:
		Enums.HeistPhase.CASING, Enums.HeistPhase.STEALTH:
			return MusicTrack.STEM_STEALTH
		Enums.HeistPhase.ESCAPE:
			return MusicTrack.STEM_ASSAULT
		Enums.HeistPhase.LOUD:
			match p_assault_phase:
				Enums.AssaultPhase.ANTICIPATION:
					return MusicTrack.STEM_ANTICIPATION
				Enums.AssaultPhase.BUILD, Enums.AssaultPhase.SUSTAIN:
					return MusicTrack.STEM_ASSAULT
				Enums.AssaultPhase.FADE:
					return MusicTrack.STEM_FADE
				_:
					return MusicTrack.STEM_CONTROL
	return SILENCE


func _ready() -> void:
	AudioCueLib.ensure_buses()
	if listen_to_event_bus:
		_resolve_heist_track()
	if track == null and track_id != &"":
		track = MusicTrackTable.load_default().load_track(track_id)
	if track == null and listen_to_event_bus:
		Log.warn(&"audio", "MusicDirector: no music track '%s'" % track_id)
	_ensure_players()
	if listen_to_event_bus:
		EventBus.heist_phase_changed.connect(_on_heist_phase_changed)
		EventBus.assault_phase_changed.connect(_on_assault_phase_changed)
		EventBus.heist_ended.connect(_on_heist_ended)


## The heist's track id: launch option first, then the map's HeistDef (&"" outside a heist).
static func heist_track_id(rt: HeistRuntime) -> StringName:
	if rt == null:
		return &""
	var opt: StringName = StringName(String(rt.launch_options.get("music_track", "")))
	if opt != &"":
		return opt
	if rt.map != null and rt.map.heist_def != null:
		return rt.map.heist_def.music_track
	return &""


## Switch to the running heist's track (once). Called at ready and again on the first phase fact,
## since the map can enter the tree before the runtime has its launch options.
func _resolve_heist_track() -> void:
	if _heist_track:
		return
	var tid: StringName = heist_track_id(HeistRuntime.of(self))
	if tid == &"":
		return
	var t: MusicTrack = MusicTrackTable.load_default().load_track(tid)
	if t == null:
		Log.warn(&"audio", "MusicDirector: no music track '%s' (keeping '%s')" % [tid, track_id])
		return
	_heist_track = true
	track_id = tid
	track = t


## Hub jukebox (D-062): play `stem` of `p_track_id` right away (no bar wait). Returns false when the
## track or stem does not exist.
func preview(p_track_id: StringName, stem: StringName = MusicTrack.STEM_ASSAULT) -> bool:
	var t: MusicTrack = MusicTrackTable.load_default().load_track(p_track_id)
	if t == null or t.stem(stem) == null:
		Log.warn(&"audio", "MusicDirector.preview: no track/stem '%s'/'%s'" % [p_track_id, stem])
		return false
	_ensure_players()
	stop_preview()
	track_id = p_track_id
	track = t
	target_stem = stem
	_switch(0.0)
	return true


## hub_map.md (QC-48): duck the whole director by DUCK_DB over DUCK_S (the safehouse cabinet while another station's
## screen is open), or restore it. An offset on the playing stems; a crossfade's target carries it too.
func set_ducked(on: bool) -> void:
	var to: float = DUCK_DB if on else 0.0
	if is_equal_approx(to, _duck_target):
		return
	_duck_target = to
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	if not is_inside_tree():
		_apply_duck(to)
		return
	_duck_tween = create_tween()
	_duck_tween.tween_method(_apply_duck, _duck_db, to, DUCK_S)


func is_ducked() -> bool:
	return _duck_target < 0.0


func _apply_duck(v: float) -> void:
	var delta: float = v - _duck_db
	_duck_db = v
	for p: AudioStreamPlayer in _players:
		if p.playing and p.volume_db > FADE_FLOOR_DB + 1.0:
			p.volume_db += delta


## Stop the jukebox preview immediately.
func stop_preview() -> void:
	stop_all()
	_active = -1
	target_stem = SILENCE
	current_stem = SILENCE


func _ensure_players() -> void:
	if not _players.is_empty():
		return
	for i: int in range(2):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.name = "Stem%d" % i
		p.bus = AudioCueLib.bus_or_master(bus)
		p.volume_db = FADE_FLOOR_DB
		add_child(p)
		_players.append(p)
	_stinger = AudioStreamPlayer.new()
	_stinger.name = "Stinger"
	_stinger.bus = AudioCueLib.bus_or_master(bus)
	add_child(_stinger)


func _exit_tree() -> void:
	stop_all()


## Stop every stem and the stinger immediately (teardown, tests).
func stop_all() -> void:
	for p: AudioStreamPlayer in _players:
		p.stop()
	if _stinger != null:
		_stinger.stop()


func _process(delta: float) -> void:
	if target_stem == current_stem:
		return
	if _players.is_empty():
		return
	if _active < 0 or not _players[_active].playing or current_stem == SILENCE:
		_switch(0.0)
		return
	var bar: float = track.bar_seconds() if track != null else 2.0
	var pos: float = _players[_active].get_playback_position() + AudioServer.get_time_since_last_mix()
	var next_bar: float = ceilf(pos / bar - 0.001) * bar
	if next_bar - pos <= delta:
		_switch(next_bar)


## Ask for a stem directly (tools, mix test). Applied at the next bar line.
func request_stem(stem_name: StringName) -> void:
	target_stem = stem_name


## Seconds until the next bar line of the playing stem (0 when nothing plays).
func time_to_next_bar() -> float:
	if _active < 0 or not _players[_active].playing or track == null:
		return 0.0
	var bar: float = track.bar_seconds()
	var pos: float = _players[_active].get_playback_position()
	return ceilf(pos / bar - 0.001) * bar - pos


func play_stinger(stinger_name: StringName) -> void:
	last_stinger = stinger_name
	if track == null or _stinger == null or not track.stingers.has(stinger_name):
		return
	_stinger.stream = track.stingers[stinger_name]
	AudioCueLib.set_loop(_stinger.stream, false)
	_stinger.volume_db = track.stem_gain_db(stinger_name)
	_stinger.play()


func _on_heist_phase_changed(_old_phase: int, new_phase: int) -> void:
	_resolve_heist_track()
	heist_phase = new_phase
	if new_phase != Enums.HeistPhase.LOUD:
		assault_phase = Enums.AssaultPhase.NONE
	target_stem = stem_for(heist_phase, assault_phase)


func _on_assault_phase_changed(phase: int, _wave_index: int) -> void:
	assault_phase = phase
	if heist_phase != Enums.HeistPhase.ESCAPE and heist_phase != Enums.HeistPhase.ENDED:
		heist_phase = Enums.HeistPhase.LOUD
	target_stem = stem_for(heist_phase, assault_phase)


func _on_heist_ended(result: Dictionary) -> void:
	heist_phase = Enums.HeistPhase.ENDED
	target_stem = SILENCE
	play_stinger(MusicTrack.STINGER_WIN if bool(result.get("success", false)) else MusicTrack.STINGER_LOSE)


## Swap stems. `bar_pos` = playback position (s) of the outgoing stem at the bar line; the new stem
## starts at the same phrase position (modulo its own loop length) so bars stay aligned.
func _switch(bar_pos: float) -> void:
	var to_stem: StringName = target_stem
	var fade_s: float = crossfade_beats * 60.0 / (track.bpm if track != null else 120.0)
	if _active >= 0:
		_fade(_active, FADE_FLOOR_DB, fade_s, true)
	current_stem = to_stem
	stem_changed.emit(to_stem)
	if to_stem == SILENCE or track == null:
		return
	var stream: AudioStream = track.stem(to_stem)
	if stream == null:
		Log.warn(&"audio", "MusicDirector: track '%s' has no stem '%s'" % [track.id, to_stem])
		return
	AudioCueLib.set_loop(stream, true)
	var nxt: int = 1 if _active == 0 else 0
	var p: AudioStreamPlayer = _players[nxt]
	p.stream = stream
	var length: float = stream.get_length()
	var start: float = fmod(bar_pos, length) if length > 0.0 else 0.0
	p.volume_db = FADE_FLOOR_DB
	if p.is_inside_tree():
		p.play(start)
	_fade(nxt, track.stem_gain_db(to_stem) + _duck_db, fade_s, false)
	_active = nxt


func _fade(idx: int, to_db: float, seconds: float, stop_after: bool) -> void:
	var p: AudioStreamPlayer = _players[idx]
	if _tweens[idx] != null and _tweens[idx].is_valid():
		_tweens[idx].kill()
	if not is_inside_tree() or seconds <= 0.0:
		p.volume_db = to_db
		if stop_after:
			p.stop()
		return
	var tw: Tween = create_tween()
	tw.tween_property(p, "volume_db", to_db, seconds)
	if stop_after:
		tw.tween_callback(p.stop)
	_tweens[idx] = tw
