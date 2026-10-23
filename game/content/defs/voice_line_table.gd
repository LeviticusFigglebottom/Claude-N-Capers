## Voice line table (pd2_fidelity C8). Data: res://content/data/voice/lines.tres. Text lives in
## strings.csv under `text_key`; this table only says who says what, when.
##
## Line dictionary:
##   { "id": StringName           vo.<speaker>.<event>[_n]
##     "speaker": StringName      one of SPEAKERS (&"crew" = any heister)
##     "event": StringName        trigger: an EventBus signal name (pager_started, device_jammed,
##                                crew_downed, ...) or a semantic tag from EVENTS (heist_start_casing,
##                                assault_build, reloading, ...). Triggering code (ENV A/C) maps facts
##                                to these and emits EventBus.voice_line_requested(speaker, id, ctx).
##     "text_key": StringName     voice.<id> in strings.csv
##     "cooldown_s": float        min seconds before the same line (id) may play again
##     "priority": int            higher interrupts lower on the same speaker channel }
## Optional keys: "heist" (briefing / mission / radio lines of one heist), "order" (briefing), "objective"
## (radio.objective_* lines: the HeistMission objective id, D-039 `[tag]`), "loot" (radio.loot_secured: a loot id).
## Contact radio (B7-03, content/docs/radio.md): `radio.*` events are picked by ContactRadio on every peer.
## Crew barks are written per heister; pick the lines whose speaker matches the crew member's
## character and choose among variants with GameRng.stream(&"voice").
class_name VoiceLineTable
extends Resource

## Contacts (vance, reyes, accountant) speak briefing (B2-02), mission and contact-radio (B7-03) lines; see
## ContactDef.voice_speaker.
## &"guard" = any guard NPC (ENV A requests guard lines by id, e.g. StealthTweak.cuff_yell_line).
const SPEAKERS: Array[StringName] = [
	&"mercer", &"rook", &"sable", &"dutch", &"wren", &"marten", &"jay", &"juno", &"hale", &"crew", &"vance", &"reyes", &"accountant", &"guard",
	&"dj",  # Afterhours: the club DJ on the mic (diegetic, 3D at the stage)
]
## The heisters: the only speakers that &"crew" lines stand in for.
const HEISTERS: Array[StringName] = [&"rook", &"sable", &"dutch", &"wren", &"marten", &"jay", &"juno", &"hale"]
## Known trigger vocabulary: EventBus signal names first, then semantic tags.
const EVENTS: Array[StringName] = [
	# EventBus signals
	&"crew_masked", &"pager_started", &"pager_answered", &"pager_failed", &"body_discovered",
	&"alarm_raised", &"device_started", &"device_jammed", &"device_finished", &"loot_secured",
	&"crew_downed", &"crew_custody", &"crew_revived", &"civilian_killed",
	# Semantic tags (mapped by the trigger from state or event args)
	&"heist_start_casing", &"pager_last_answer", &"pager_limit", &"camera_spotted",
	&"assault_anticipation", &"assault_build", &"assault_fade", &"assault_control",
	&"escape_available", &"heist_success", &"heist_failed", &"stealth_success",
	&"reloading", &"bagging_body", &"going_loud", &"reviving", &"cops_incoming", &"guard_down",
	&"stealth_abort", &"cuff_warning", &"dev_start",
	# AI teammate acknowledges an order (D-043 QA-24): id vo.crew.ack_<CrewOrders order>, speaker crew.
	&"order_ack",
	# Briefing screen (B2-02): local UI playback, never replicated. Briefing lines also carry
	# "heist": StringName (the heist id) and "order": int (playback order within that heist).
	&"briefing",
	# Mission script lines (ENV C say(); D-048): id vo.<speaker>.<heist>_<line>, ctx args per line.
	&"mission",
	# Contact radio (B7-03, ContactRadio; content/docs/radio.md): generic per contact, or per heist ("heist" key).
	&"radio.objective_done", &"radio.objective_new", &"radio.objective_failed", &"radio.alarm",
	&"radio.assault_build", &"radio.assault_sustain", &"radio.assault_fade", &"radio.escape_available",
	&"radio.escape", &"radio.loot_secured",
]

@export var lines: Array[Dictionary] = []

var _by_id: Dictionary = {}


## Lines for `event`, optionally only those `speaker` may say (&"crew" lines match any heister).
func lines_for(event: StringName, speaker: StringName = &"") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for l: Dictionary in lines:
		if StringName(l.get("event", &"")) != event:
			continue
		var sp: StringName = StringName(l.get("speaker", &""))
		if speaker == &"" or sp == speaker or (sp == &"crew" and HEISTERS.has(speaker)):
			out.append(l)
	return out


## The line with `id`, or an empty Dictionary.
func line(id: StringName) -> Dictionary:
	if _by_id.size() != lines.size():
		_by_id.clear()
		for l: Dictionary in lines:
			_by_id[StringName(l.get("id", &""))] = l
	return _by_id.get(id, {})
