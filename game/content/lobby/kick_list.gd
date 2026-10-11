## Session kick list (B6-04, D-072, net.md v1.1). Owner: ENV B. Pure: no Net, no nodes.
## A kicked player cannot come back to the same lobby session: LobbyState owns one (`LobbyState.kicked`), every
## peer adds the target of an accepted LobbyState.MSG_KICK notice, and the host checks lobby joins and drop-in
## requests against it (LobbyState.join_decision). Keyed by peer id AND profile name: ENet hands a rejoining
## client a new peer id, so the name catches the rejoin; the id catches a renamed client still connected.
## Names compare normalized (normalize(): trimmed, cut to the lobby name length, lower case). Cleared with the
## session (LobbyState.reset).
class_name KickList
extends RefCounted

## Longest name compared (Net cuts display names to 24 characters; LobbyTweak.max_name_length).
const NAME_LENGTH: int = 24

## peer id -> true
var peers: Dictionary = {}
## normalized name -> true
var names: Dictionary = {}


## Remember a kicked player (peer id <= 0 or an empty name only adds the other key).
func add(peer_id: int, player_name: String) -> void:
	if peer_id > 0:
		peers[peer_id] = true
	var n: String = normalize(player_name)
	if n != "":
		names[n] = true


## True when `peer_id` or `player_name` was kicked this session.
func has(peer_id: int, player_name: String = "") -> bool:
	if peer_id > 0 and peers.has(peer_id):
		return true
	var n: String = normalize(player_name)
	return n != "" and names.has(n)


func is_empty() -> bool:
	return peers.is_empty() and names.is_empty()


func clear() -> void:
	peers.clear()
	names.clear()


static func normalize(player_name: String) -> String:
	return player_name.strip_edges().left(NAME_LENGTH).to_lower()
