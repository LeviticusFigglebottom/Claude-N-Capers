## Heist music: picks the stem for the current heist/assault phase and crossfades to it on the next
## BAR boundary of the playing stem (beat-synced from playback position), keeping the musical
## phrase position. Win/lose stingers on heist_ended. Headless-safe (no audio output required:
## tests read target_stem / current_stem).
class_name MusicDirector
extends Node

signal stem_changed(stem_name: StringName)

const SILENCE: StringName = &""
const FADE_FLOOR_DB: float = -60.0

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
	if track == null and track_id != &"":
		track = MusicTrack.load_track(track_id)
	if track == null:
		Log.warn(&"audio", "MusicDirector: no music track '%s'" % track_id)
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
	if listen_to_event_bus:
		EventBus.heist_phase_changed.connect(_on_heist_phase_changed)
		EventBus.assault_phase_changed.connect(_on_assault_phase_changed)
		EventBus.heist_ended.connect(_on_heist_ended)


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
	if track == null or not track.stingers.has(stinger_name):
		return
	_stinger.stream = track.stingers[stinger_name]
	AudioCueLib.set_loop(_stinger.stream, false)
	_stinger.volume_db = track.stem_gain_db(stinger_name)
	_stinger.play()


func _on_heist_phase_changed(_old_phase: int, new_phase: int) -> void:
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
	p.play(start)
	_fade(nxt, track.stem_gain_db(to_stem), fade_s, false)
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
