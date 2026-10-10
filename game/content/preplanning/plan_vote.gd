## Plan votes (B2-01 stub, PD2 C3): for each vote group (e.g. &"escape") every human crew slot votes
## for one option; the majority wins and the HOST breaks ties. Solo: the host's vote decides.
## Owner: ENV B. AI teammates never vote.
## Relay (contract preplanning.md, D-038): a vote is sent with PlanVote.send_cast / send_retract
## (`Net.lobby_send`), and every peer, the sender included, applies it when `Net.lobby_message`
## delivers it (PreplanPlan.receive_vote). Solo: Net delivers locally at once. No RPCs here.
##
## Options are PlanVote.option_key(asset_id, point_id) -> &"asset.escape_position@pp_escape_pell".
class_name PlanVote
extends RefCounted

## Lobby message kinds. Data: MSG_CAST {"option": String}, MSG_RETRACT {"group": String}.
const MSG_CAST: StringName = &"preplan.vote_cast"
const MSG_RETRACT: StringName = &"preplan.vote_retract"

## Crew slot of the host (tie-breaker).
var host_slot: int = 0
## Slots allowed to vote (human crew). Empty = anyone who casts.
var voters: Array[int] = []
## group -> { slot: option StringName }
var votes: Dictionary = {}


func _init(p_host_slot: int = 0, p_voters: Array[int] = []) -> void:
	host_slot = p_host_slot
	voters = p_voters.duplicate()


static func option_key(asset_id: StringName, point_id: StringName) -> StringName:
	return StringName("%s@%s" % [asset_id, point_id])


## Send the local player's vote for `option` to every peer (self included).
static func send_cast(option: StringName) -> void:
	Net.lobby_send(MSG_CAST, {"option": String(option)})


## Withdraw the local player's vote in `group` on every peer (self included).
static func send_retract(group: StringName) -> void:
	Net.lobby_send(MSG_RETRACT, {"group": String(group)})


static func is_vote_message(kind: StringName) -> bool:
	return kind == MSG_CAST or kind == MSG_RETRACT


## &"asset.x@pp_y" -> {"asset": &"asset.x", "point": &"pp_y"}
static func parse_option(option: StringName) -> Dictionary:
	var parts: PackedStringArray = String(option).split("@", true, 1)
	return {"asset": StringName(parts[0]), "point": StringName(parts[1]) if parts.size() > 1 else &""}


## Returns false when `slot` may not vote.
func cast(slot: int, group: StringName, option: StringName) -> bool:
	if not voters.is_empty() and not voters.has(slot):
		return false
	if not votes.has(group):
		votes[group] = {}
	(votes[group] as Dictionary)[slot] = option
	return true


func retract(slot: int, group: StringName) -> void:
	if votes.has(group):
		(votes[group] as Dictionary).erase(slot)


func vote_of(slot: int, group: StringName) -> StringName:
	return StringName((votes.get(group, {}) as Dictionary).get(slot, &""))


## option -> number of votes
func tally(group: StringName) -> Dictionary:
	var out: Dictionary = {}
	var g: Dictionary = votes.get(group, {}) as Dictionary
	for slot: Variant in g:
		var o: StringName = StringName(g[slot])
		out[o] = int(out.get(o, 0)) + 1
	return out


## Winning option (&"" when nobody voted). Majority; on a tie the host's vote wins if it is among
## the tied options, else the first tied option by id text (deterministic on every peer).
func winner(group: StringName) -> StringName:
	var t: Dictionary = tally(group)
	if t.is_empty():
		return &""
	var best: int = 0
	for o: Variant in t:
		best = maxi(best, int(t[o]))
	var tied: Array[StringName] = []
	for o: Variant in t:
		if int(t[o]) == best:
			tied.append(StringName(o))
	if tied.size() == 1:
		return tied[0]
	var host_vote: StringName = vote_of(host_slot, group)
	if tied.has(host_vote):
		return host_vote
	ContentDB.sort_ids(tied)
	return tied[0]


func is_tied(group: StringName) -> bool:
	var t: Dictionary = tally(group)
	var best: int = 0
	var n: int = 0
	for o: Variant in t:
		var c: int = int(t[o])
		if c > best:
			best = c
			n = 1
		elif c == best:
			n += 1
	return n > 1


## Votes cast in `group` / eligible voters (voters.size(), or the casters when voters is empty).
func progress(group: StringName) -> Vector2i:
	var cast_n: int = (votes.get(group, {}) as Dictionary).size()
	return Vector2i(cast_n, voters.size() if not voters.is_empty() else cast_n)


func groups() -> Array[StringName]:
	var out: Array[StringName] = []
	for g: Variant in votes:
		out.append(StringName(g))
	ContentDB.sort_ids(out)
	return out


func to_dict() -> Dictionary:
	return {"host_slot": host_slot, "voters": voters.duplicate(), "votes": votes.duplicate(true)}


static func from_dict(d: Dictionary) -> PlanVote:
	var v: PlanVote = PlanVote.new(int(d.get("host_slot", 0)))
	for s: Variant in d.get("voters", []) as Array:
		v.voters.append(int(s))
	var src: Dictionary = d.get("votes", {}) as Dictionary
	for g: Variant in src:
		var inner: Dictionary = {}
		var gv: Dictionary = src[g] as Dictionary
		for slot: Variant in gv:
			inner[int(slot)] = StringName(String(gv[slot]))
		v.votes[StringName(String(g))] = inner
	return v
