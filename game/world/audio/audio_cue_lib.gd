## Shared helpers for CuePlayer / CueEmitter / MusicDirector: contract bus layout, registry cache,
## placeholder beep for missing cues, stream variation picking and loop flags.
class_name AudioCueLib
extends RefCounted

const BUS_LAYOUT_PATH: String = "res://world/audio/default_bus_layout.tres"
## Contract (audio_cues.md): Master > Music, SFX (> Weapons, Enemies, World, UI), Voice, Ambience.
## [bus, parent] in creation order.
const CONTRACT_BUSES: Array[Array] = [
	[&"Music", &"Master"], [&"SFX", &"Master"], [&"Weapons", &"SFX"], [&"Enemies", &"SFX"],
	[&"World", &"SFX"], [&"UI", &"SFX"], [&"Voice", &"Master"], [&"Ambience", &"Master"],
]
const NO_POSITION: Vector3 = Vector3.INF

static var _registry: AudioCueRegistry = null
static var _placeholder: AudioStreamWAV = null
static var _warned: Dictionary[StringName, bool] = {}


## Make sure every contract bus exists. If the project has only Master (no default_bus_layout set in
## project.godot) the generated layout is applied; any still-missing bus is then added in place.
static func ensure_buses() -> void:
	if AudioServer.bus_count <= 1 and ResourceLoader.exists(BUS_LAYOUT_PATH):
		var layout: AudioBusLayout = load(BUS_LAYOUT_PATH) as AudioBusLayout
		if layout != null:
			AudioServer.set_bus_layout(layout)
	for pair: Array in CONTRACT_BUSES:
		var bus_name: StringName = pair[0]
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		AudioServer.add_bus()
		var idx: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, pair[1])


static func has_contract_buses() -> bool:
	for pair: Array in CONTRACT_BUSES:
		if AudioServer.get_bus_index(pair[0]) == -1:
			return false
	return true


static func bus_or_master(bus_name: StringName) -> StringName:
	return bus_name if AudioServer.get_bus_index(bus_name) != -1 else &"Master"


static func registry() -> AudioCueRegistry:
	if _registry == null:
		_registry = AudioCueRegistry.load_default()
	return _registry


static func set_registry(reg: AudioCueRegistry) -> void:
	_registry = reg


## Drop cached resources (tests / heist teardown) so nothing is held at exit.
static func clear_cache() -> void:
	_registry = null
	_placeholder = null
	_warned.clear()


## Look up a cue; logs one warning per missing id and returns null (callers fall back to placeholder).
static func resolve(reg: AudioCueRegistry, cue_id: StringName) -> AudioCueDef:
	var cue: AudioCueDef = reg.get_cue(cue_id) if reg != null else null
	if cue == null or cue.streams.is_empty():
		if not _warned.has(cue_id):
			_warned[cue_id] = true
			Log.warn(&"audio", "missing audio cue %s; playing placeholder beep" % cue_id)
		return null
	return cue


## Tiny generated 880 Hz beep (AudioStreamWAV, 16-bit mono) used when a cue is missing.
static func placeholder_stream() -> AudioStreamWAV:
	if _placeholder != null:
		return _placeholder
	var rate: int = 22050
	var n: int = int(rate * 0.15)
	var data: PackedByteArray = PackedByteArray()
	data.resize(n * 2)
	for i: int in range(n):
		var t: float = float(i) / float(rate)
		var env: float = minf(1.0, t / 0.005) * minf(1.0, (0.15 - t) / 0.02)
		var s: int = int(sin(TAU * 880.0 * t) * env * 0.4 * 32767.0)
		data.encode_s16(i * 2, s)
	var w: AudioStreamWAV = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	_placeholder = w
	return w


## Pick a variation and apply the cue's loop flag to the stream resource.
static func pick_stream(cue: AudioCueDef, rng: RandomNumberGenerator) -> AudioStream:
	var idx: int = 0 if cue.streams.size() == 1 else rng.randi_range(0, cue.streams.size() - 1)
	var stream: AudioStream = cue.streams[idx]
	set_loop(stream, cue.loop)
	return stream


static func set_loop(stream: AudioStream, enabled: bool) -> void:
	var ogg: AudioStreamOggVorbis = stream as AudioStreamOggVorbis
	if ogg != null:
		ogg.loop = enabled
		ogg.loop_offset = 0.0
		return
	var wav: AudioStreamWAV = stream as AudioStreamWAV
	if wav != null and enabled:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)


static func pitch_for(cue: AudioCueDef, rng: RandomNumberGenerator, base: float = 1.0) -> float:
	if cue.pitch_jitter <= 0.0:
		return base
	return base * (1.0 + rng.randf_range(-cue.pitch_jitter, cue.pitch_jitter))
