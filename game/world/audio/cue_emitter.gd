## Plays a registry cue locally at this node's position (for presentation of replicated state:
## a door that swung open, a drill whose synced state is "running", a map-placed alarm bell...).
## Runs on every peer; never emits gameplay facts.
class_name CueEmitter
extends Node3D

@export var cue_id: StringName = &""
@export var autoplay: bool = false
## Start this emitter (as the per-heist alarm variant when available) when the alarm is raised;
## lets a map place real bell positions (set CuePlayer.play_flat_alarm = false then).
@export var trigger_on_alarm: bool = false
@export var volume_offset_db: float = 0.0
@export var registry: AudioCueRegistry

var _player: AudioStreamPlayer3D = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _last_ms: int = -1000000
var _alarm_gen: int = 0


func _ready() -> void:
	AudioCueLib.ensure_buses()
	if registry == null:
		registry = AudioCueLib.registry()
	_rng.seed = hash(get_path())  # presentation-only variation
	_player = AudioStreamPlayer3D.new()
	_player.name = "Player"
	_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	_player.unit_size = 6.0
	add_child(_player)
	if trigger_on_alarm:
		EventBus.alarm_raised.connect(_on_alarm_raised)
		EventBus.heist_ended.connect(_on_heist_ended)
	if autoplay:
		play()


func _exit_tree() -> void:
	stop()


## Play the configured cue (or `override_id`). Loops keep playing until stop().
func play(override_id: StringName = &"", pitch: float = 1.0) -> void:
	var id: StringName = override_id if override_id != &"" else cue_id
	var cue: AudioCueDef = AudioCueLib.resolve(registry, id)
	if cue == null:
		_player.stream = AudioCueLib.placeholder_stream()
		_player.volume_db = -6.0
		_player.pitch_scale = 1.0
		_player.bus = AudioCueLib.bus_or_master(&"SFX")
		_player.play()
		return
	var now: int = Time.get_ticks_msec()
	if cue.cooldown_s > 0.0 and now - _last_ms < int(cue.cooldown_s * 1000.0):
		return
	_last_ms = now
	_player.stream = AudioCueLib.pick_stream(cue, _rng)
	_player.volume_db = cue.volume_db + volume_offset_db
	_player.max_distance = cue.max_distance
	_player.pitch_scale = AudioCueLib.pitch_for(cue, _rng, pitch)
	_player.bus = AudioCueLib.bus_or_master(cue.bus)
	_player.play()


func stop() -> void:
	if _player != null:
		_player.stop()


func is_playing() -> bool:
	return _player != null and _player.playing


func _on_alarm_raised(_reason: StringName, _source_net_id: int) -> void:
	if is_playing():
		return
	var heist_cue: StringName = cue_id if cue_id != &"" else &"cue.alarm_bell"
	var player: CuePlayer = _find_cue_player()
	play(player.variant_cue(heist_cue) if player != null else heist_cue)
	# PO6-07: a map-placed bell rings as long as the flat bell does, then stops (no endless bell).
	var ring_s: float = player.alarm_bell_duration_s if player != null else 120.0
	_alarm_gen += 1
	if is_inside_tree():
		get_tree().create_timer(ring_s).timeout.connect(_on_bell_timer.bind(_alarm_gen))


func _on_bell_timer(gen: int) -> void:
	if gen == _alarm_gen:
		stop()


func _on_heist_ended(_result: Dictionary) -> void:
	_alarm_gen += 1
	stop()


func _find_cue_player() -> CuePlayer:
	var n: Node = get_parent()
	while n != null:
		for c: Node in n.get_children():
			if c is CuePlayer:
				return c as CuePlayer
		n = n.get_parent()
	return null
