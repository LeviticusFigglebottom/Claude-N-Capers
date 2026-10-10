## Host / Join field validation for the co-op lobby (B4-11). Owner: ENV B. Pure.
class_name LobbyAddress
extends RefCounted


## Port typed in a field: an integer in tweak.min_port..max_port, else -1.
static func parse_port(text: String, tweak: LobbyTweak = null) -> int:
	var tw: LobbyTweak = tweak if tweak != null else LobbyTweak.load_default()
	var t: String = text.strip_edges()
	if t == "" or not t.is_valid_int():
		return -1
	var p: int = t.to_int()
	return p if p >= tw.min_port and p <= tw.max_port else -1


## Address typed in the Join field, normalized (trimmed, lower case), or "" when it is not an IPv4/IPv6
## address or a host name (letters, digits, '-' and '.', labels of 1..63 characters).
static func parse_address(text: String) -> String:
	var t: String = text.strip_edges().to_lower()
	if t == "" or t.length() > 253:
		return ""
	if t.is_valid_ip_address():
		return t
	if t.count(".") == 3 and t.replace(".", "").is_valid_int():
		return ""  # looks like IPv4 but is not one (e.g. 300.1.1.1)
	for label: String in t.split("."):
		if label.is_empty() or label.length() > 63 or label.begins_with("-") or label.ends_with("-"):
			return ""
		for i: int in range(label.length()):
			var c: int = label.unicode_at(i)
			var ok: bool = (c >= 0x61 and c <= 0x7a) or (c >= 0x30 and c <= 0x39) or c == 0x2d
			if not ok:
				return ""
	return t
