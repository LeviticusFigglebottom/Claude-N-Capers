## Seeded, named random streams per run. Owner: LEAD.
## Usage (server): GameRng.begin_run(seed); var r := GameRng.stream(&"patrols"); r.randi_range(0, 3)
## Each stream is independent so adding rolls in one system never shifts another.
## Gameplay code must never call the global randi()/randf() (CI greps for it).
extends Node

var run_seed: int = 0
var _streams: Dictionary[StringName, RandomNumberGenerator] = {}


func begin_run(seed_value: int) -> void:
	run_seed = seed_value
	_streams.clear()
	Log.info(&"rng", "run seed %d" % seed_value)


## Pick a fresh seed (server). Tests pass a fixed seed to begin_run instead.
func make_seed() -> int:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.randomize()
	return r.randi()


func stream(stream_name: StringName) -> RandomNumberGenerator:
	var r: RandomNumberGenerator = _streams.get(stream_name)
	if r == null:
		r = RandomNumberGenerator.new()
		r.seed = hash([run_seed, String(stream_name)])
		_streams[stream_name] = r
	return r


## Convenience: weighted pick. `weights` same length as `items`; returns index.
func weighted_index(stream_name: StringName, weights: PackedFloat32Array) -> int:
	return stream(stream_name).rand_weighted(weights)


## Convenience: Fisher-Yates shuffle copy using a named stream.
func shuffled(stream_name: StringName, items: Array) -> Array:
	var out: Array = items.duplicate()
	var r: RandomNumberGenerator = stream(stream_name)
	for i: int in range(out.size() - 1, 0, -1):
		var j: int = r.randi_range(0, i)
		var tmp: Variant = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out
