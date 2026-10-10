## Base class for tests. Owner: LEAD.
## Write `func test_something() -> void:` methods; `await` is allowed.
## Optional hooks: before_all, before_each, after_each, after_all.
class_name TestCase
extends Node

var _failures: Array[String] = []
var _current: String = ""
var _skipped: String = ""


func before_all() -> void:
	pass


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func after_all() -> void:
	pass


## Mark the current test as skipped (pending dependency). Return right after calling it.
func skip(reason: String) -> void:
	_skipped = reason


func fail(msg: String) -> void:
	_failures.append("%s: %s" % [_current, msg])


func assert_true(cond: bool, msg: String = "expected true") -> void:
	if not cond:
		fail(msg)


func assert_false(cond: bool, msg: String = "expected false") -> void:
	if cond:
		fail(msg)


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		fail("expected <%s> got <%s> %s" % [expected, actual, msg])


func assert_ne(actual: Variant, other: Variant, msg: String = "") -> void:
	if typeof(actual) == typeof(other) and actual == other:
		fail("expected value != <%s> %s" % [other, msg])


func assert_near(actual: float, expected: float, eps: float = 0.0001, msg: String = "") -> void:
	if absf(actual - expected) > eps:
		fail("expected %f +- %f got %f %s" % [expected, eps, actual, msg])


func assert_has(container: Variant, item: Variant, msg: String = "") -> void:
	var ok: bool = false
	if container is Array or container is PackedStringArray:
		ok = item in container
	elif container is Dictionary:
		ok = (container as Dictionary).has(item)
	if not ok:
		fail("expected container to have <%s> %s" % [item, msg])


func wait_frames(n: int) -> void:
	for i: int in range(n):
		await get_tree().process_frame


func wait_physics_frames(n: int) -> void:
	for i: int in range(n):
		await get_tree().physics_frame


func wait_seconds(s: float) -> void:
	await get_tree().create_timer(s, true, true).timeout


## Wait until `cond` returns true or `timeout_s` elapses; returns whether it became true.
func wait_until(cond: Callable, timeout_s: float = 5.0) -> bool:
	var t: float = 0.0
	while not cond.call():
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if t >= timeout_s:
			return false
	return true
