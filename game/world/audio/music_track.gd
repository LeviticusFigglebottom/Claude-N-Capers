## A music track: loop-aligned stems per heist phase + one-shot stingers (contracts/audio_cues.md).
## Generated at game/world/audio/music/<track>/<track>.tres by tools/audiogen/build.py.
class_name MusicTrack
extends Resource

const STEM_STEALTH: StringName = &"stealth"
const STEM_CONTROL: StringName = &"control"
const STEM_ANTICIPATION: StringName = &"anticipation"
const STEM_ASSAULT: StringName = &"assault"
const STEM_FADE: StringName = &"fade"
const STINGER_WIN: StringName = &"win"
const STINGER_LOSE: StringName = &"lose"

@export var id: StringName = &""
@export var bpm: float = 140.0
@export var beats_per_bar: int = 4
## stem name -> looping stream (all on the same tempo grid, whole bars long)
@export var stems: Dictionary[StringName, AudioStream] = {}
## stinger name (win/lose) -> one-shot stream
@export var stingers: Dictionary[StringName, AudioStream] = {}
## per stem/stinger mix trim in dB (files are all -16 LUFS integrated)
@export var gain_db: Dictionary[StringName, float] = {}
## loop length in bars per stem (informational; MusicDirector uses stream length)
@export var loop_bars: Dictionary[StringName, int] = {}


static func load_track(track_id: StringName) -> MusicTrack:
	var path: String = "res://world/audio/music/%s/%s.tres" % [track_id, track_id]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as MusicTrack


func bar_seconds() -> float:
	return 60.0 / maxf(bpm, 1.0) * float(beats_per_bar)


func stem(stem_name: StringName) -> AudioStream:
	return stems.get(stem_name) as AudioStream


func stem_gain_db(stem_name: StringName) -> float:
	return float(gain_db.get(stem_name, 0.0))
