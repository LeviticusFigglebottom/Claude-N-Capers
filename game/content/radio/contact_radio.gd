## Contact radio, the handler-on-comms of a heist (B7-03, pd2_fidelity C8; brief content/docs/radio.md). Owner: ENV B.
## Runs on EVERY peer from replicated EventBus facts ([R] in contracts/events.md), so clients hear it too; it never
## replicates anything itself. MenuFlow spawns it (with its SubtitleOverlay) in the in-heist layer: spawn().
##
## Facts -> radio events (VoiceLineTable `radio.*` lines; data/tweak/radio.tres = RadioTweak):
##   objective_updated: first sight of an id is silent (add_objective, drop-in); then -> COMPLETED =
##     radio.objective_done, HIDDEN -> ACTIVE = radio.objective_new, -> FAILED = radio.objective_failed
##     (ctx.objective = the id, so heist lines keyed by the design doc `[tag]` win);
##   alarm_raised = radio.alarm; assault_phase_changed = RadioTweak.assault_tags[phase] (build / sustain / fade);
##   heist_phase_changed -> ESCAPE = radio.escape_available; audio_cue_requested `cue.escape_arrive*` (EscapeZone
##   arrival, A3-10) = radio.escape; loot_secured = radio.loot_secured (ctx.loot_id; ignored_loot skipped).
## The speaker is the heist's contact (HeistDef.contact -> ContactDef.voice_speaker; RadioTweak.speaker_overrides,
## else fallback_contact = Mercer). A fact waits settle_s, then the line is picked with GameRng.stream(&"radio")
## (RadioLinePicker: heist line, else generic; cooldowns, no-repeat) and emitted LOCALLY as
## EventBus.voice_line_requested(speaker, id, {source: &"radio", radio: true, local: true, ...}) for subtitles and
## C's voice player, plus RadioTweak.squelch_cue (local audio_cue_requested) when set.
## No doubling with mission lines: a voice_line_requested from a comms speaker that is not ours (mission say(), abort,
## last pager) drops the waiting fact and keeps the radio quiet for max(mission_suppress_s, that line's subtitle time).
class_name ContactRadio
extends Node

## Emitted when the radio speaks (after voice_line_requested).
signal line_spoken(speaker: StringName, line_id: StringName, event: StringName)

const SOURCE: StringName = &"radio"
const EV_OBJECTIVE_DONE: StringName = &"radio.objective_done"
const EV_OBJECTIVE_NEW: StringName = &"radio.objective_new"
const EV_OBJECTIVE_FAILED: StringName = &"radio.objective_failed"
const EV_ALARM: StringName = &"radio.alarm"
const EV_ESCAPE_AVAILABLE: StringName = &"radio.escape_available"
const EV_ESCAPE: StringName = &"radio.escape"
const EV_LOOT: StringName = &"radio.loot_secured"
const LINES_PATH: String = "res://content/data/voice/lines.tres"

var tweak: RadioTweak = null
var table: VoiceLineTable = null
var picker: RadioLinePicker = null
var heist_id: StringName = &""
## VoiceLineTable speaker of the contact on the radio (e.g. &"reyes").
var speaker: StringName = &""
var contact: ContactDef = null
## Subtitle overlay spawned with the radio (spawn()); null when used alone (tests).
var overlay: SubtitleOverlay = null
## Radio clock (s). Advanced by _process; tests set auto_process = false and call advance().
var now_s: float = 0.0
var auto_process: bool = true
## The fact waiting to be spoken: {event, ctx, priority, at, due}; {} = none.
var pending: Dictionary = {}
var _on_air_until: float = -1.0
var _suppressed_until: float = -1.0
var _objective_states: Dictionary = {}
var _event_last: Dictionary = {}
var _spoken_once: Dictionary = {}
var _ended: bool = false


## Radio + SubtitleOverlay under `layer` (MenuFlow's in-heist CanvasLayer) for `p_heist_id`.
static func spawn(layer: Node, p_heist_id: StringName) -> ContactRadio:
	var radio: ContactRadio = ContactRadio.new()
	radio.name = "ContactRadio"
	radio.setup(p_heist_id)
	layer.add_child(radio)
	var sub: SubtitleOverlay = SubtitleOverlay.new()
	sub.name = "Subtitles"
	sub.tweak = radio.tweak
	sub.table = radio.table
	layer.add_child(sub)
	radio.overlay = sub
	return radio


## The contact on the radio for `p_heist_id` (override, HeistDef.contact, else the fallback); never null when the
## fallback exists.
static func contact_for(p_heist_id: StringName, p_tweak: RadioTweak) -> ContactDef:
	var cid: StringName = StringName(p_tweak.speaker_overrides.get(p_heist_id, &""))
	if cid == &"" and p_heist_id != &"":
		var def: HeistDef = HeistRegistry.get_def(p_heist_id)
		cid = def.contact if def != null else &""
	var c: ContactDef = null
	if cid != &"" and ResourceLoader.exists(ContactDef.path_for(cid)):
		c = ContactDef.find(cid)
	return c if c != null else ContactDef.find(p_tweak.fallback_contact)


func _init() -> void:
	if tweak == null:
		tweak = RadioTweak.load_default()
	if table == null:
		table = load(LINES_PATH) as VoiceLineTable
	picker = RadioLinePicker.new(table, tweak.no_repeat_depth)


func _ready() -> void:
	if heist_id == &"" and contact == null:
		setup(&"")
	_connect(EventBus.heist_loaded, _on_heist_loaded)
	_connect(EventBus.heist_ended, _on_heist_ended)
	_connect(EventBus.objective_updated, _on_objective_updated)
	_connect(EventBus.alarm_raised, _on_alarm_raised)
	_connect(EventBus.assault_phase_changed, _on_assault_phase_changed)
	_connect(EventBus.heist_phase_changed, _on_heist_phase_changed)
	_connect(EventBus.loot_secured, _on_loot_secured)
	_connect(EventBus.audio_cue_requested, _on_audio_cue_requested)
	_connect(EventBus.voice_line_requested, _on_voice_line_requested)


## (Re)start for `p_heist_id`: contact, speaker, and every per-heist memory cleared.
func setup(p_heist_id: StringName) -> void:
	heist_id = p_heist_id
	contact = contact_for(heist_id, tweak)
	speaker = contact.voice_speaker if contact != null else &""
	picker.no_repeat_depth = tweak.no_repeat_depth
	picker.reset()
	pending = {}
	_objective_states.clear()
	_event_last.clear()
	_spoken_once.clear()
	_on_air_until = -1.0
	_suppressed_until = -1.0
	_ended = false


func _process(delta: float) -> void:
	if auto_process:
		advance(delta)


## Moves the radio clock on and speaks the waiting fact when it is due.
func advance(dt: float) -> void:
	now_s += dt
	if pending.is_empty():
		return
	if now_s > float(pending["at"]) + tweak.max_wait_s or is_suppressed():
		pending = {}
		return
	if now_s < float(pending["due"]) or now_s < _on_air_until:
		return
	var p: Dictionary = pending
	pending = {}
	_speak(StringName(p["event"]), p["ctx"] as Dictionary)


## A fact for radio `event` (ctx: objective / loot_id ...). False when it is dropped at once (heist over, suppressed,
## once-per-heist spent, event cooldown, or a waiting fact of higher priority).
func request(event: StringName, ctx: Dictionary = {}) -> bool:
	if _ended or speaker == &"" or is_suppressed():
		return false
	if _spoken_once.has(event) or now_s < float(_event_last.get(event, -INF)) + tweak.cooldown_of(event):
		return false
	var prio: int = tweak.priority_of(event)
	if not pending.is_empty() and int(pending["priority"]) >= prio:
		return false
	pending = {"event": event, "ctx": ctx, "priority": prio, "at": now_s, "due": now_s + tweak.settle_s}
	return true


func is_suppressed() -> bool:
	return now_s < _suppressed_until


func _speak(event: StringName, ctx: Dictionary) -> void:
	var line: Dictionary = picker.pick(event, speaker, heist_id, ctx, now_s, GameRng.stream(&"radio"))
	if line.is_empty():
		return
	var id: StringName = StringName(line.get("id", &""))
	_event_last[event] = now_s
	if tweak.once_per_heist.has(event):
		_spoken_once[event] = true
	_on_air_until = now_s + tweak.display_s(StringTable.text(StringName(line.get("text_key", &"")), ctx))
	var vctx: Dictionary = ctx.duplicate()
	vctx.merge({"source": SOURCE, "radio": true, "local": true, "heist_id": heist_id, "event": event,
		"priority": int(line.get("priority", 0))}, true)
	EventBus.voice_line_requested.emit(speaker, id, vctx)
	if tweak.squelch_cue != &"":
		EventBus.audio_cue_requested.emit(tweak.squelch_cue, Vector3.ZERO, 0)
	line_spoken.emit(speaker, id, event)


func _on_heist_loaded(p_heist_id: StringName, _run_seed: int, _variants: Dictionary) -> void:
	if p_heist_id != heist_id or contact == null:
		setup(p_heist_id)


func _on_heist_ended(_result: Dictionary) -> void:
	_ended = true
	pending = {}


func _on_objective_updated(objective_id: StringName, state: int, _data: Dictionary) -> void:
	var prev: int = int(_objective_states.get(objective_id, -1))
	_objective_states[objective_id] = state
	if prev < 0 or prev == state:
		return
	var event: StringName = &""
	if state == Enums.ObjectiveState.COMPLETED:
		event = EV_OBJECTIVE_DONE
	elif state == Enums.ObjectiveState.FAILED:
		event = EV_OBJECTIVE_FAILED
	elif state == Enums.ObjectiveState.ACTIVE and prev == Enums.ObjectiveState.HIDDEN:
		event = EV_OBJECTIVE_NEW
	if event != &"":
		request(event, {"objective": objective_id})


func _on_alarm_raised(reason: StringName, _source_net_id: int) -> void:
	request(EV_ALARM, {"reason": reason})


func _on_assault_phase_changed(phase: int, wave_index: int) -> void:
	var event: StringName = StringName(tweak.assault_tags.get(phase, &""))
	if event != &"":
		request(event, {"wave": wave_index})


func _on_heist_phase_changed(_old_phase: int, new_phase: int) -> void:
	if new_phase == Enums.HeistPhase.ESCAPE:
		request(EV_ESCAPE_AVAILABLE)


func _on_loot_secured(_bag_net_id: int, loot_id: StringName, value: int) -> void:
	if not tweak.ignored_loot.has(loot_id):
		request(EV_LOOT, {"loot_id": loot_id, "value": value})


func _on_audio_cue_requested(cue_id: StringName, _position: Vector3, _source_net_id: int) -> void:
	if tweak.escape_cue_prefix != "" and String(cue_id).begins_with(tweak.escape_cue_prefix):
		request(EV_ESCAPE)


func _on_voice_line_requested(p_speaker: StringName, line_id: StringName, ctx: Dictionary) -> void:
	if StringName(ctx.get("source", &"")) == SOURCE or not tweak.comms_speakers.has(p_speaker):
		return
	pending = {}
	var line: Dictionary = table.line(line_id) if table != null else {}
	var key: StringName = StringName(line.get("text_key", StringName("voice.%s" % line_id)))
	var hold: float = maxf(tweak.mission_suppress_s, tweak.display_s(StringTable.text(key, ctx)))
	_suppressed_until = maxf(_suppressed_until, now_s + hold)


func _connect(sig: Signal, cb: Callable) -> void:
	if not sig.is_connected(cb):
		sig.connect(cb)
