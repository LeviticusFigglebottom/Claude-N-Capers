## VO bark director tunables (D-117 §6, pd2_fidelity C8). Owner: ENV A. Data: bark_tweak.tres.
## A bark key is "<channel>.<event>": channel mercer (the handler on comms) or crew (the acting heister);
## event = the VoiceLineTable event whose lines it plays. Every timing and pool lives here, never in code.
class_name BarkTweak
extends Resource

const PATH: String = "res://systems/vo/bark_tweak.tres"

static var _instance: BarkTweak = null

@export_group("Lines")
## Bark key -> the line ids it may play, as patterns (%d = a variant number). A line of the event from
## VoiceLineTable.lines_for(event, speaker) plays only when its id matches one of the key's patterns, so other
## lines of the same event (contact radio, mission, PagerSystem) are never picked. Heister keys list one
## pattern per heister; the speaker segment selects the acting heister's own lines.
@export var patterns: Dictionary = {}
## Heister used for a crew member whose Loadout.heister is empty (generic crew): index = slot % size.
@export var fallback_heisters: Array[StringName] = [&"rook", &"sable", &"dutch", &"wren"]

@export_group("Timing")
## A Mercer bark waits this long before it plays, so a mission say() of the same fact (before or after it)
## replaces it instead of doubling up (the RadioTweak.settle_s rule).
@export var mercer_settle_s: float = 0.75
## A queued bark is dropped when it could not play within this many seconds (channel busy).
@export var max_wait_s: float = 6.0
## The casing-start line waits this long instead: it plays after the mission intro rather than giving way to it.
@export var casing_wait_s: float = 15.0
## At most this many barks wait; a new one past it drops the lowest priority one.
@export var max_queue: int = 4
## Global minimum gap between the end of one line and the next bark (s).
@export var global_gap_s: float = 0.6
## Talk time of a line = clamp(talk_base_s + talk_per_char_s * characters, talk_min_s, talk_max_s); the channel
## is busy for that long (one speaker at a time).
@export var talk_base_s: float = 0.6
@export var talk_per_char_s: float = 0.05
@export var talk_min_s: float = 1.2
@export var talk_max_s: float = 6.0
## Bark key -> seconds before that key may play again (missing = 0). Heister keys are shared by the whole crew.
@export var key_cooldown_s: Dictionary = {}
## Keys played at most once per heist.
@export var once_per_heist: Array[StringName] = []

@export_group("Channel")
## voice_line_requested speakers whose lines (not the director's) hold the channel and drop waiting Mercer
## barks: mission say(), the abort / last-pager lines and the contact radio. Mercer mission VO has priority.
@export var comms_speakers: Array[StringName] = [&"mercer", &"vance", &"reyes", &"accountant"]
## Other speakers whose lines hold the channel (AI teammate order acks).
@export var hold_speakers: Array[StringName] = [&"crew_ai"]

@export_group("Facts")
## interaction_started kind -> crew event (the crew member who starts it speaks).
@export var interaction_events: Dictionary = {}
## Device kinds Mercer comments on (his device lines talk about the drill).
@export var mercer_device_kinds: Array[StringName] = [&"drill", &"thermal", &"saw"]
## Secured loot that gets no bark (body bags, the thermite bag).
@export var ignored_loot: Array[StringName] = [&"loot.body_bag", &"loot.thermite"]
## Enums.AssaultPhase values on which a heister calls the cops in.
@export var cops_incoming_phases: Array[int] = [1]
## NPC roles whose death by a crew member is a guard_down bark.
@export var guard_roles: Array[StringName] = [&"guard"]
## Reload barks only once the heist is loud.
@export var reload_loud_only: bool = true


static func get_default() -> BarkTweak:
	if _instance == null:
		_instance = load(PATH) as BarkTweak
		if _instance == null:
			_instance = BarkTweak.new()
	return _instance


func cooldown_of(key: StringName) -> float:
	return float(key_cooldown_s.get(key, 0.0))


func talk_s(text: String) -> float:
	return clampf(talk_base_s + talk_per_char_s * float(text.length()), talk_min_s, talk_max_s)


## True when line `id` matches one of `key`'s patterns.
func allows(key: StringName, id: StringName) -> bool:
	var s: String = String(id)
	for p: Variant in patterns.get(key, []):
		var pat: String = String(p)
		var at: int = pat.find("%d")
		if at < 0:
			if s == pat:
				return true
			continue
		var pre: String = pat.substr(0, at)
		var suf: String = pat.substr(at + 2)
		if s.length() > pre.length() + suf.length() and s.begins_with(pre) and s.ends_with(suf):
			if s.substr(pre.length(), s.length() - pre.length() - suf.length()).is_valid_int():
				return true
	return false
