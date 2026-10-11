## Lobby codes (B6-05, game_overview §9 "Steam-less lobby codes"). Owner: ENV B. Pure, static; no server.
## A short, case-insensitive code for an IPv4 address + port that a host reads out or pastes, and a joiner
## types into the lobby's join-by-code field (decoded back into the existing address / port join).
##
## Format: Crockford base32 (0-9 A-Z without I L O U), most significant symbol first, plus one check symbol.
## * Bits: [flag 1][IPv4 32][port 16 when flag = 1], zero-padded to a multiple of 5 bits.
##   flag 0 = the default port (LobbyTweak.default_port): 7 symbols; flag 1 = any other port: 10 symbols.
## * Check symbol: Luhn mod 32 over the data symbols (catches every single wrong symbol and almost every
##   swap of two neighbours). The pad bits must be zero.
## * So a code is 8 symbols (default port, "ABCD-EFGH") or 11 ("ABCD-EFGH-JKL"); display() groups by 4.
## * Decoding ignores case, spaces and dashes and reads O as 0 and I / L as 1 (Crockford).
## IPv6 is NOT supported (128 bits would make a ~27-symbol code): encode() returns "" for it. Codes carry the
## address as typed: a LAN address works on the LAN; over the internet the host needs its public address and a
## forwarded UDP port (pick_lan_ipv4() only ever offers local addresses).
class_name LobbyCode
extends RefCounted

const ALPHABET: String = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
const BASE: int = 32
const SHORT_LENGTH: int = 8
const LONG_LENGTH: int = 11
const GROUP: int = 4
## decode() errors (UI text: strings.csv `ui.lobby.code.error.<code>`).
const E_EMPTY: StringName = &"empty"
const E_CHAR: StringName = &"char"
const E_LENGTH: StringName = &"length"
const E_CHECKSUM: StringName = &"checksum"
const E_FORMAT: StringName = &"format"


## The code (no dashes, upper case) for IPv4 `address` and `port`, or "" when the address is not IPv4 or the
## port is outside 1..65535. `default_port` < 0 = LobbyTweak.default_port.
static func encode(address: String, port: int, default_port: int = -1) -> String:
	var ip: int = ipv4_to_int(address)
	if ip < 0 or port < 1 or port > 65535:
		return ""
	var short: bool = port == _default_port(default_port)
	var bits: int = 33 if short else 49
	var value: int = ip if short else ((1 << 48) | (ip << 16) | port)
	var symbols: int = ceili(bits / 5.0)
	value <<= symbols * 5 - bits
	var data: String = ""
	for i: int in range(symbols):
		data = ALPHABET[value & (BASE - 1)] + data
		value >>= 5
	return data + check_symbol(data)


## {"address": String, "port": int} for a valid code, else {"error": E_*}.
static func decode(code: String, default_port: int = -1) -> Dictionary:
	var norm: String = normalize(code)
	var err: StringName = validate(norm)
	if err != &"":
		return {"error": err}
	var data: String = norm.left(norm.length() - 1)
	var value: int = 0
	for i: int in range(data.length()):
		value = (value << 5) | ALPHABET.find(data[i])
	var short: bool = norm.length() == SHORT_LENGTH
	var bits: int = 33 if short else 49
	var pad: int = data.length() * 5 - bits
	var flag: int = (value >> (pad + bits - 1)) & 1
	if value & ((1 << pad) - 1) != 0 or flag != (0 if short else 1):
		return {"error": E_FORMAT}
	value >>= pad
	var port: int = _default_port(default_port) if short else value & 0xffff
	var ip: int = value & 0xffffffff if short else (value >> 16) & 0xffffffff
	if port < 1:
		return {"error": E_FORMAT}
	return {"address": int_to_ipv4(ip), "port": port}


## Why a normalized code is not valid (&"" = it is): E_EMPTY, E_CHAR, E_LENGTH or E_CHECKSUM.
static func validate(norm: String) -> StringName:
	if norm == "":
		return E_EMPTY
	for i: int in range(norm.length()):
		if ALPHABET.find(norm[i]) < 0:
			return E_CHAR
	if norm.length() != SHORT_LENGTH and norm.length() != LONG_LENGTH:
		return E_LENGTH
	var data: String = norm.left(norm.length() - 1)
	return &"" if check_symbol(data) == norm.right(1) else E_CHECKSUM


## Upper case, spaces / dashes dropped, O -> 0 and I / L -> 1.
static func normalize(code: String) -> String:
	var t: String = code.strip_edges().to_upper().replace("-", "").replace(" ", "")
	return t.replace("O", "0").replace("I", "1").replace("L", "1")


## "ABCDEFGHJKL" -> "ABCD-EFGH-JKL" (input normalized first).
static func display(code: String) -> String:
	var norm: String = normalize(code)
	var parts: PackedStringArray = PackedStringArray()
	for i: int in range(0, norm.length(), GROUP):
		parts.append(norm.substr(i, GROUP))
	return "-".join(parts)


## Luhn mod 32 check symbol of `data` (base32 symbols).
static func check_symbol(data: String) -> String:
	var factor: int = 2
	var total: int = 0
	for i: int in range(data.length() - 1, -1, -1):
		var addend: int = factor * ALPHABET.find(data[i])
		factor = 1 if factor == 2 else 2
		total += addend / BASE + addend % BASE
	return ALPHABET[(BASE - total % BASE) % BASE]


## Dotted IPv4 -> 32-bit int, or -1 when `address` is not a dotted IPv4 address.
static func ipv4_to_int(address: String) -> int:
	var t: String = address.strip_edges()
	if not t.is_valid_ip_address() or t.contains(":"):
		return -1
	var parts: PackedStringArray = t.split(".")
	if parts.size() != 4:
		return -1
	var out: int = 0
	for p: String in parts:
		if not p.is_valid_int() or p.to_int() < 0 or p.to_int() > 255:
			return -1
		out = (out << 8) | p.to_int()
	return out


static func int_to_ipv4(ip: int) -> String:
	return "%d.%d.%d.%d" % [(ip >> 24) & 255, (ip >> 16) & 255, (ip >> 8) & 255, ip & 255]


## The address a host should share from IP.get_local_addresses(): the first private LAN IPv4 (10/8, 172.16/12,
## 192.168/16), else the first other routable IPv4, else "" (only loopback / link-local / IPv6 found).
static func pick_lan_ipv4(addresses: PackedStringArray) -> String:
	var fallback: String = ""
	for a: String in addresses:
		var ip: int = ipv4_to_int(a)
		if ip < 0 or (ip >> 24) == 127 or (ip >> 16) == 0xa9fe or ip == 0:
			continue
		if is_private_ipv4(ip):
			return int_to_ipv4(ip)
		if fallback == "":
			fallback = int_to_ipv4(ip)
	return fallback


static func is_private_ipv4(ip: int) -> bool:
	return (ip >> 24) == 10 or (ip >> 20) == 0xac1 or (ip >> 16) == 0xc0a8


static func _default_port(default_port: int) -> int:
	return default_port if default_port >= 0 else LobbyTweak.load_default().default_port
