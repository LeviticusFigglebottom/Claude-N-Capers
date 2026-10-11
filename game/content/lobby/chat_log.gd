## Text chat log of a co-op session (B6-03). Owner: ENV B. Pure: no Net, no nodes.
## LobbyState owns one (`LobbyState.chat`) and feeds it every LobbyState.MSG_CHAT with the SENDER'S crew slot
## (Net's sender id, never a field of the payload), so a message cannot claim another slot.
##
## Payload: {"text": String}. receive() validates it:
## * the text is cleaned (clean_text): control characters (C0, DEL, C1), zero-width / bidi overrides and
##   line / paragraph separators are dropped (tab / newline become a space), runs of spaces collapse, the ends
##   are trimmed and the result is cut to `max_length`. Empty after cleaning -> R_EMPTY.
## * rate limit per sender slot: at most `rate_count` accepted messages in any `rate_window_s` window
##   (R_RATE_LIMITED; nothing logged). The clock is the caller's (`now_s`), so tests drive it.
## Entries keep the text as PLAIN TEXT; the UI renders it in Labels (never RichTextLabel / BBCode), so
## "[b]" or "[url]" stay literal. History is capped at `history_cap` (oldest dropped).
## Numbers: LobbyTweak (`chat_*`, data/lobby/lobby_tweak.tres).
class_name ChatLog
extends RefCounted

## receive() results (OK = "", shared with LobbyState).
const R_OK: StringName = &""
const R_BAD_PAYLOAD: StringName = &"bad_payload"
const R_EMPTY: StringName = &"empty"
const R_RATE_LIMITED: StringName = &"rate_limited"
## Raw text longer than max_length * this is cut before cleaning (bounds the work per message).
const RAW_SCAN_FACTOR: int = 4

## {"id": int, "slot": int, "name": String, "text": String, "time": float}, oldest first.
var entries: Array[Dictionary] = []
var max_length: int = 160
var max_name_length: int = 24
var history_cap: int = 50
var rate_count: int = 5
var rate_window_s: float = 5.0
## slot -> Array of accepted message times (seconds) inside the current window.
var _sent: Dictionary = {}
var _next_id: int = 1


func _init(tweak: LobbyTweak = null) -> void:
	configure(tweak if tweak != null else LobbyTweak.load_default())


func configure(tweak: LobbyTweak) -> void:
	max_length = maxi(tweak.chat_max_length, 1)
	max_name_length = maxi(tweak.max_name_length, 1)
	history_cap = maxi(tweak.chat_history_cap, 1)
	rate_count = maxi(tweak.chat_rate_count, 1)
	rate_window_s = maxf(tweak.chat_rate_window_s, 0.0)


func clear() -> void:
	entries.clear()
	_sent.clear()


## Apply one chat message from crew slot `slot` (already checked to be a human slot by LobbyState).
## Returns R_OK (entry appended) or why not (nothing changed).
func receive(slot: int, sender_name: String, data: Dictionary, now_s: float) -> StringName:
	var raw: Variant = data.get("text")
	if not raw is String:
		return R_BAD_PAYLOAD
	var text: String = clean_text(String(raw), max_length)
	if text == "":
		return R_EMPTY
	if not can_send(slot, now_s):
		return R_RATE_LIMITED
	var times: Array = _sent.get(slot, []) as Array
	times.append(now_s)
	_sent[slot] = times
	var entry: Dictionary = {"id": _next_id, "slot": slot, "name": clean_text(sender_name, max_name_length),
			"text": text, "time": now_s}
	_next_id += 1
	entries.append(entry)
	while entries.size() > history_cap:
		entries.pop_front()
	return R_OK


## True while `slot` may send one more message at `now_s` (rate limit). Prunes old timestamps.
func can_send(slot: int, now_s: float) -> bool:
	var kept: Array = []
	for t: Variant in _sent.get(slot, []) as Array:
		if now_s - float(t) < rate_window_s and float(t) <= now_s:
			kept.append(t)
	_sent[slot] = kept
	return kept.size() < rate_count


## The newest entry ({} when empty).
func last() -> Dictionary:
	return entries.back() if not entries.is_empty() else {}


## MSG_CHAT payload for `text`.
static func message(text: String) -> Dictionary:
	return {"text": text}


## Plain-text cleanup (see the header): returns "" when nothing printable is left.
static func clean_text(raw: String, max_len: int) -> String:
	var src: String = raw.left(maxi(max_len, 1) * RAW_SCAN_FACTOR)
	var out: String = ""
	var pending_space: bool = false
	for i: int in range(src.length()):
		var c: int = src.unicode_at(i)
		if c == 0x09 or c == 0x0a or c == 0x0d or c == 0x20 or c == 0xa0:
			pending_space = out != ""
			continue
		if is_control(c):
			continue
		if pending_space:
			out += " "
			pending_space = false
		out += String.chr(c)
	return out.left(maxi(max_len, 1)).strip_edges()


## Characters chat never shows: C0 controls, DEL, C1 controls, zero-width / joiner / bidi marks and
## overrides (U+200B..U+200F, U+202A..U+202E, U+2060..U+2069), line / paragraph separators and the BOM.
static func is_control(c: int) -> bool:
	if c < 0x20 or (c >= 0x7f and c <= 0x9f):
		return true
	return (c >= 0x200b and c <= 0x200f) or (c >= 0x2028 and c <= 0x202e) or (c >= 0x2060 and c <= 0x2069) \
			or c == 0xfeff
