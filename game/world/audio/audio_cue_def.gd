## One playable sound cue (contracts/audio_cues.md). Generated into cues.tres by tools/audiogen.
## Several streams = random variations; pitch_jitter is a +- fraction of pitch_scale.
class_name AudioCueDef
extends Resource

@export var id: StringName = &""
@export var streams: Array[AudioStream] = []
@export var volume_db: float = 0.0
## Contract bus name: Music, SFX, Weapons, Enemies, World, UI, Voice, Ambience.
@export var bus: StringName = &"SFX"
## true = AudioStreamPlayer3D at a world position; false = flat (UI, stingers, beds).
@export var positional: bool = true
@export var max_distance: float = 40.0
@export var pitch_jitter: float = 0.0
## Minimum seconds between two plays of this cue from the same source.
@export var cooldown_s: float = 0.0
## Seamless loop (stop it explicitly). Loop flags are applied to the stream at runtime.
@export var loop: bool = false
