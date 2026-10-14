## Contact radio + subtitle tuning (B7-03; data: res://content/data/tweak/radio.tres). Owner: ENV B.
## Brief: content/docs/radio.md. Every timing, priority, cooldown and size is here, never in code.
class_name RadioTweak
extends Resource

const DEFAULT_PATH: String = "res://content/data/tweak/radio.tres"

static var _cached: RadioTweak = null

@export_group("Radio")
## A fact waits this long before its line is picked, so a mission say() that comes with (or right after)
## the same fact suppresses it instead of doubling up.
@export var settle_s: float = 0.75
## A waiting fact is dropped when it could not be spoken within this many seconds (radio busy).
@export var max_wait_s: float = 4.0
## A comms line from someone else (mission say(), abort, last pager) keeps the radio quiet for at least
## this long, or for that line's own subtitle time when it is longer.
@export var mission_suppress_s: float = 3.0
## The last N lines picked for an event are not repeated while other lines are available.
@export var no_repeat_depth: int = 2
## radio event tag -> priority. One fact waits at a time: a higher priority fact replaces the waiting one.
@export var event_priority: Dictionary = {}
## radio event tag -> seconds after that event spoke before it may speak again (missing = 0).
@export var event_cooldown_s: Dictionary = {}
## Events spoken at most once per heist.
@export var once_per_heist: Array[StringName] = []
## Enums.AssaultPhase (int) -> radio event tag. Phases without an entry are silent.
@export var assault_tags: Dictionary = {}
## Secured loot that never gets a line (body bags, the thermite bag).
@export var ignored_loot: Array[StringName] = []
## Contact used when the heist has none (or an unknown one): the handler.
@export var fallback_contact: StringName = &"contact.mercer"
## heist id -> contact id: who is on the radio instead of HeistDef.contact.
@export var speaker_overrides: Dictionary = {}
## voice_line_requested speakers whose lines (from anyone but the radio) suppress the radio.
@export var comms_speakers: Array[StringName] = []
## audio_cue_requested ids starting with this mean "the escape vehicle arrived" (EscapeZone, A3-10).
@export var escape_cue_prefix: String = "cue.escape_arrive"
## Local cue played with every radio line (ENV C's squelch); &"" = none until C ships it.
@export var squelch_cue: StringName = &""

@export_group("Subtitles")
## Speakers whose voice_line_requested lines get a subtitle (the radio's own lines always do).
@export var subtitle_speakers: Array[StringName] = []
## accessibility/subtitle_size -> font size in px at the 1920x1080 base.
@export var font_sizes: Dictionary = {"small": 22, "medium": 28, "large": 36}
@export var default_size: String = "medium"
## Box width at the base resolution; it sits bottom-centre between the vitals and ammo panels
## (clear of both up to hud_scale 1.5).
@export var width_px: float = 800.0
## P fresh-eyes #9: 90 (was 40) lifts the box out of the bottom HUD band (vitals / ammo / hint row).
@export var bottom_margin_px: float = 90.0
@export var max_lines: int = 2
## PQ-B-18: rows taller than this together (large text wraps) drop the oldest, so the box never reaches
## the interaction / domination prompts above it (interaction bottom = 1040 - 314 at hud_scale 1.5;
## box bottom 1080 - bottom_margin_px, so bottom_margin_px + max_height_px stays under 354).
@export var max_height_px: float = 264.0
## Display time = clamp(base_s + per_char_s * characters, min_s, max_s); the last fade_s fade out.
@export var base_s: float = 1.2
@export var per_char_s: float = 0.055
@export var min_s: float = 2.5
@export var max_s: float = 9.0
@export var fade_s: float = 0.4
## P fresh-eyes #9: a readable backing (0.85, was 0.62) over bright scenes and the HUD band.
@export var panel_color: Color = Color(0.04, 0.04, 0.05, 0.85)
## Speaker accents are lifted to this contrast against the panel (UiAccent.readable).
@export var min_contrast: float = 4.5


static func load_default() -> RadioTweak:
	if _cached == null:
		if ResourceLoader.exists(DEFAULT_PATH):
			_cached = load(DEFAULT_PATH) as RadioTweak
		if _cached == null:
			Log.error(&"content", "missing %s" % DEFAULT_PATH)
			_cached = RadioTweak.new()
	return _cached


## Seconds a line of `text` stays on screen (and keeps the radio busy).
func display_s(text: String) -> float:
	return clampf(base_s + per_char_s * float(text.length()), min_s, max_s)


func priority_of(event: StringName) -> int:
	return int(event_priority.get(event, 0))


func cooldown_of(event: StringName) -> float:
	return float(event_cooldown_s.get(event, 0.0))


## Font size for an accessibility/subtitle_size value (unknown -> default_size).
func font_size_for(size_id: String) -> int:
	return int(font_sizes.get(size_id, font_sizes.get(default_size, 28)))
