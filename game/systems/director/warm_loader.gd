## Background scene prewarm with one rule: a main-thread load never overlaps a background load (GN-8).
## Owner: ENV A.
##
## GN-8 (seed 99 signal 11 at LOUD -> ESCAPE, "/root: The caller thread can't call propagate_notification()", i.e. the
## crash handler running on a worker thread): the director queued `ResourceLoader.load_threaded_request` for every
## spawnable NPC scene and character, left them uncollected for the whole heist, and the spawn code `load()`ed the same
## scenes (and their shared meshes / materials / scripts) on the main thread meanwhile. A synchronous load of a path, or
## of a sub-resource, that a worker is still loading is the classic Godot 4 threaded-load race. Here:
##   * `request()` queues the background load (no sub-threads) and remembers it;
##   * `poll()` (the director, every physics frame) collects each finished load with `load_threaded_get` and holds the
##     resource, so nothing stays uncollected in ResourceLoader and the scene stays cached;
##   * `get_or_load()` is the main-thread load for prewarmed paths: with any background load still in flight it
##     first collects them all (`load_threaded_get` blocks until each is done; the documented way to wait), and only
##     then `load()`s, so a sync load never runs beside a threaded one;
##   * `collect_all()` / `release()`: heist teardown (no load left running into the next scene; holds dropped).
class_name WarmLoader
extends RefCounted

## Paths queued with load_threaded_request and not collected yet.
static var _pending: PackedStringArray = PackedStringArray()
## Collected resources, held so they stay in the ResourceLoader cache until release().
static var _held: Dictionary[String, Resource] = {}


## Queue a background load of `path` (skipped when cached, already queued or missing). True when queued.
static func request(path: String) -> bool:
	if path == "" or _pending.has(path) or ResourceLoader.has_cached(path) or not ResourceLoader.exists(path):
		return false
	if ResourceLoader.load_threaded_request(path, "", false) != OK:
		return false
	_pending.append(path)
	return true


## Main thread: collect every background load that has finished (loaded or failed). Returns how many are still
## in flight.
static func poll() -> int:
	for p: String in _pending.duplicate():
		if ResourceLoader.load_threaded_get_status(p) != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_collect(p)
	return _pending.size()


## Main thread: wait for and collect every background load still in flight.
static func collect_all() -> void:
	for p: String in _pending.duplicate():
		_collect(p)


## Main thread: the resource at `path`. Never runs beside a background load: anything still in flight is collected
## first, then `path` comes from the hold / the cache / a plain load().
static func get_or_load(path: String) -> Resource:
	if path == "":
		return null
	if not _pending.is_empty():
		collect_all()
	if _held.has(path) and _held[path] != null:
		return _held[path]
	return load(path)


## Heist teardown: collect what is left and drop the holds.
static func release() -> void:
	collect_all()
	_held.clear()


static func is_pending(path: String) -> bool:
	return _pending.has(path)


static func pending_count() -> int:
	return _pending.size()


static func is_held(path: String) -> bool:
	return _held.has(path)


static func _collect(path: String) -> void:
	var idx: int = _pending.find(path)
	if idx >= 0:
		_pending.remove_at(idx)
	if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		return  # not a threaded load (any more)
	var res: Resource = ResourceLoader.load_threaded_get(path)
	if res != null:
		_held[path] = res
