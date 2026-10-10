## Mix test (style guide §9 readability): the assault stem plays while every registry cue is played
## in turn over it, 3 m in front of the listener. Run in the editor, or headless with
## `-- --quit-when-done` (prints the running order).
extends Node3D

@export var interval_s: float = 2.5
@export var music_stem: StringName = MusicTrack.STEM_ASSAULT
## Empty = every cue in the registry except ambience beds.
@export var cue_ids: Array[StringName] = []

var _queue: Array[StringName] = []
var _loop_key: StringName = &"mix_test_loop"

@onready var _cues: CuePlayer = $CuePlayer
@onready var _music: MusicDirector = $MusicDirector


func _ready() -> void:
	_music.request_stem(music_stem)
	_queue = cue_ids.duplicate()
	if _queue.is_empty():
		for c: AudioCueDef in _cues.registry.cues:
			if c.bus != &"Ambience":
				_queue.append(c.id)
	_next()


func _next() -> void:
	_cues.stop_loop(_loop_key)
	if _queue.is_empty():
		Log.info(&"audio", "mix test done")
		if OS.get_cmdline_user_args().has("--quit-when-done"):
			_music.stop_all()
			_cues.stop_everything()
			await get_tree().create_timer(0.25).timeout  # let the mixer release playbacks
			get_tree().quit(0)
		return
	var id: StringName = _queue.pop_front()
	var cue: AudioCueDef = _cues.registry.get_cue(id)
	Log.info(&"audio", "mix test: %s" % id)
	if cue != null and cue.loop:
		_cues.start_loop(_loop_key, id, Vector3(0.0, 0.0, -3.0))
	else:
		_cues.play_cue(id, Vector3(0.0, 0.0, -3.0))
	get_tree().create_timer(interval_s).timeout.connect(_next)
