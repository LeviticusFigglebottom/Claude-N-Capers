## Per-run keypad codes and the crew's known codes (S9.7). Owner: ENV A.
## Runtime service `codes` (HeistRuntime registers it): `CodeRegistry.of(node).code_for(&"vault")`.
## Each `code_group` gets a 4-digit code, rolled once per run from GameRng &"codes": one base value
## is drawn from the stream, and each group's code is derived from (base, group name). That keeps a
## group's code the same for a seed no matter which group is asked first.
## Known codes are crew-wide (PD2: a read note shows the code to the whole crew): `reveal(group)`
## by a code_note, `is_known(group)` gates keypads and code safes, `known_codes()` feeds the HUD.
## Server state; clients learn of a read through item_picked_up(&"item.code_note", slot) [R].
class_name CodeRegistry
extends Node

signal code_revealed(code_group: StringName, crew_slot: int)

const SERVICE: StringName = &"codes"
const STREAM: StringName = &"codes"
## Item id emitted with item_picked_up when a note is read (events.md).
const NOTE_ITEM: StringName = &"item.code_note"
## Blocked reason when the code is not known yet (strings table key).
const BLOCK_CODE_UNKNOWN: StringName = &"ui.blocked.code_unknown"
const DIGITS: int = 4

var _base: int = 0
var _has_base: bool = false
var _codes: Dictionary[StringName, int] = {}
var _known: Dictionary[StringName, int] = {}


## The running heist's registry, or null (standalone prefab).
static func of(_node: Node) -> CodeRegistry:
	return HeistRuntime.get_service(SERVICE) as CodeRegistry


## Code of `code_group` as an int 0..9999.
func code_value(code_group: StringName) -> int:
	if _codes.has(code_group):
		return _codes[code_group]
	if not _has_base:
		_base = GameRng.stream(STREAM).randi()
		_has_base = true
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = hash([_base, String(code_group)])
	var v: int = r.randi_range(0, int(pow(10.0, DIGITS)) - 1)
	_codes[code_group] = v
	return v


## Code of `code_group` as 4 digits ("0427").
func code_for(code_group: StringName) -> String:
	return str(code_value(code_group)).pad_zeros(DIGITS)


func is_known(code_group: StringName) -> bool:
	return _known.has(code_group)


## Server: the crew learns `code_group` (`by_slot` read it). Returns true the first time.
func reveal(code_group: StringName, by_slot: int = -1) -> bool:
	if code_group == &"" or _known.has(code_group):
		return false
	_known[code_group] = by_slot
	code_value(code_group)
	code_revealed.emit(code_group, by_slot)
	return true


## HUD: { code_group: "0427" } for every known code.
func known_codes() -> Dictionary:
	var out: Dictionary = {}
	for g: StringName in _known:
		out[g] = code_for(g)
	return out
