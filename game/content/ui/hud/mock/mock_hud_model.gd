## Stand-in for ENV A's LocalHudModel (contracts/ui_hud.md v1.3) for the HUD demo and tests. Owner:
## ENV B. Same property and signal names as the real model
## (duck-typed: the HUD reads properties with get() and connects signals by name). Like the real
## model it joins group G.LOCAL_HUD_MODEL in _ready, so HUD discovery works in the demo and tests.
## Every property setter emits its group's change signal, so assign new Arrays/Dictionaries
## instead of mutating them in place.
class_name MockHudModel
extends Node

signal vitals_changed()          ## health, max_health, armor, max_armor, downs_left, crew_state, bleedout_s
signal ammo_changed()            ## ammo, equipped_slot, reloading, reload_progress (v1.12)
signal inventory_changed()       ## deployable_*, throwable_*, cable_ties, body_bags
signal carried_bag_changed()     ## carried_bag
signal interaction_changed()     ## interaction
signal detection_changed()       ## detection
signal marked_targets_changed()  ## marked_targets
signal objective_markers_changed(markers: Array)  ## objective_markers (v1.8)
signal pagers_changed()          ## pagers, pagers_answered, pagers_max
signal timers_changed()          ## ecm_time_left_s, camera_alarm_s
signal objectives_changed()      ## objectives
signal assault_changed()         ## assault_phase, assault_wave
signal hostages_changed()        ## hostages
signal warnings_changed()        ## warnings
signal crew_changed()            ## crew
signal masked_changed()          ## masked, casing
signal custody_changed()         ## custody (v1.2)
signal captain_changed()         ## captain_present, captain_resistance (v1.3)
signal stamina_changed()         ## stamina, exhausted (v1.4)
signal player_mode_changed()     ## player_mode (v1.6)
## Extras without a contract signal (like LocalHudModel): mask_progress.
signal changed(property: StringName)
signal dominate_prompt_changed()  ## dominate_target, dominate_window_s (PP-A-1, S5.8 / D-079)
signal devices_changed()         ## devices (PO6-03 proposal to ENV A)
signal crew_stats_changed()      ## crew_stats (B6-02 proposal, QB to ENV A; content/docs/scoreboard.md)
signal perk_item_changed()       ## perk_item (ui_hud v1.21 D-163, v1.22 segments)

## PD2 display units (health 0..max_health, armor 0..max_armor).
var health: float = 100.0:
	set(v):
		health = v
		vitals_changed.emit()
var max_health: float = 100.0:
	set(v):
		max_health = v
		vitals_changed.emit()
var armor: float = 0.0:
	set(v):
		armor = v
		vitals_changed.emit()
var max_armor: float = 0.0:
	set(v):
		max_armor = v
		vitals_changed.emit()
var downs_left: int = 3:
	set(v):
		downs_left = v
		vitals_changed.emit()
## Enums.CrewState
var crew_state: int = Enums.CrewState.NORMAL:
	set(v):
		crew_state = v
		vitals_changed.emit()
## Seconds until custody while DOWNED (< 0 = not bleeding out).
## ui_hud v1.15 (PO6-17b): seconds of breach flash left (vitals group).
var flashed_s: float = 0.0:
	set(v):
		flashed_s = v
		vitals_changed.emit()
var bleedout_s: float = -1.0:
	set(v):
		bleedout_s = v
		vitals_changed.emit()
## Enums.WeaponSlot (int) -> { "mag": int, "reserve": int }
var ammo: Dictionary = {}:
	set(v):
		ammo = v
		ammo_changed.emit()
## Enums.WeaponSlot
var equipped_slot: int = Enums.WeaponSlot.SECONDARY:
	set(v):
		equipped_slot = v
		ammo_changed.emit()
## v1.12 (D-106): the equipped weapon is reloading; progress 0..1 (-1 when not reloading).
var reloading: bool = false:
	set(v):
		reloading = v
		ammo_changed.emit()
var reload_progress: float = -1.0:
	set(v):
		reload_progress = v
		ammo_changed.emit()
var deployable_id: StringName = &"":
	set(v):
		deployable_id = v
		inventory_changed.emit()
var deployable_count: int = 0:
	set(v):
		deployable_count = v
		inventory_changed.emit()
var throwable_id: StringName = &"":
	set(v):
		throwable_id = v
		inventory_changed.emit()
var throwable_count: int = 0:
	set(v):
		throwable_count = v
		inventory_changed.emit()
var cable_ties: int = 0:
	set(v):
		cable_ties = v
		inventory_changed.emit()
var body_bags: int = 0:
	set(v):
		body_bags = v
		inventory_changed.emit()
## ui_hud v1.21 (D-163): the deck throwable's state. {} = none, else {kind: StringName (ThrowableDef.kind),
## charges: int, max: int, cooldown_left: float s, active_left: float s, partner_slot: int (-1 = none),
## mode: StringName (&"" | &"jam" | &"feedback"), segments: {count, size} (v1.22, only while a leech ampule runs)}.
var perk_item: Dictionary = {}:
	set(v):
		perk_item = v
		perk_item_changed.emit()
## {} = none, else { "loot_id": StringName, "weight": int (Enums.LootWeight) }
var carried_bag: Dictionary = {}:
	set(v):
		carried_bag = v
		carried_bag_changed.emit()
## {} = no prompt, else { "text_key": StringName, "args": Dictionary (e.g. {"key": "F"}),
##   "progress": float 0..1 (0 = not holding), "blocked_reason": StringName (strings key or &"") }
var interaction: Dictionary = {}:
	set(v):
		interaction = v
		interaction_changed.emit()
## [{ "observer_net_id": int, "world_pos": Vector3, "value": float 0..1, "kind": int (Enums.ObserverKind) }]
var detection: Array[Dictionary] = []:
	set(v):
		detection = v
		detection_changed.emit()
## [{ "net_id": int, "world_pos": Vector3, "kind": StringName }]
## v1.8 (D-089): [{id, text_key, position: Vector3, state}] for ACTIVE objectives.
var objective_markers: Array[Dictionary] = []:
	set(v):
		objective_markers = v
		objective_markers_changed.emit(v)

## PO6-03 proposal (asked of ENV A for ui_hud.md): [{net_id, kind, world_pos: Vector3, progress 0..1, time_left_s,
## state: &"running"/&"jammed", fix_prompt_key}]. null = the model has none (DeviceTimers then tracks EventBus).
var devices: Variant = null:
	set(v):
		devices = v
		devices_changed.emit()

var marked_targets: Array[Dictionary] = []:
	set(v):
		marked_targets = v
		marked_targets_changed.emit()
## Active pagers: [{ "pager_id": int, "time_left_s": float (window or answer time left),
##   "answering": bool, "progress": float 0..1 }]
var pagers: Array[Dictionary] = []:
	set(v):
		pagers = v
		pagers_changed.emit()
var pagers_answered: int = 0:
	set(v):
		pagers_answered = v
		pagers_changed.emit()
var pagers_max: int = 4:
	set(v):
		pagers_max = v
		pagers_changed.emit()
## < 0 = inactive.
var ecm_time_left_s: float = -1.0:
	set(v):
		ecm_time_left_s = v
		timers_changed.emit()
## Unstoppable camera alarm countdown (S3.5); < 0 = inactive.
var camera_alarm_s: float = -1.0:
	set(v):
		camera_alarm_s = v
		timers_changed.emit()
## [{ "id": StringName, "text_key": StringName, "args": Dictionary, "state": int (Enums.ObjectiveState) }]
var objectives: Array[Dictionary] = []:
	set(v):
		objectives = v
		objectives_changed.emit()
## Enums.AssaultPhase
var assault_phase: int = Enums.AssaultPhase.NONE:
	set(v):
		assault_phase = v
		assault_changed.emit()
var assault_wave: int = 0:
	set(v):
		assault_wave = v
		assault_changed.emit()
var hostages: int = 0:
	set(v):
		hostages = v
		hostages_changed.emit()
## Active special warnings: &"phantom", &"stinger".
var warnings: Array[StringName] = []:
	set(v):
		warnings = v
		warnings_changed.emit()
## Teammates (not the local player): [{ "slot": int, "name": String, "is_ai": bool,
##   "health_frac": float, "armor_frac": float, "state": int (Enums.CrewState), "downs_left": int,
##   "carried_loot_id": StringName, "mode": StringName (v1.6) }]
var crew: Array[Dictionary] = []:
	set(v):
		crew = v
		crew_changed.emit()
var masked: bool = false:
	set(v):
		masked = v
		masked_changed.emit()
## True while the heist is in the casing phase and the local player is unmasked.
var casing: bool = true:
	set(v):
		casing = v
		masked_changed.emit()

## v1.6 (D-065): &"civilian" / &"casing" / &"masked" for the local player; &"" = unset (widgets then
## derive it from masked / casing, like a pre-v1.6 model).
var player_mode: StringName = &"":
	set(v):
		player_mode = v
		player_mode_changed.emit()

## LocalHudModel extra: mask-up hold progress 0..1 (announced through `changed`).
var mask_progress: float = 0.0:
	set(v):
		mask_progress = v
		changed.emit(&"mask_progress")
## LocalHudModel extras (asked of ENV A): who is reviving the local player and how far (-1 = nobody).
var revive_progress: float = -1.0:
	set(v):
		revive_progress = v
		vitals_changed.emit()
var reviver_slot: int = -1:
	set(v):
		reviver_slot = v
		vitals_changed.emit()
## LocalHudModel extra (asked of ENV A): the local player's crew net id (0 = unknown).
var local_net_id: int = 0:
	set(v):
		local_net_id = v
		changed.emit(&"local_net_id")
## LocalHudModel extra: Enums.HeistPhase (announced through `changed`; OnboardingCard).
var heist_phase: int = Enums.HeistPhase.LOADING:
	set(v):
		heist_phase = v
		changed.emit(&"heist_phase")

## v1.2 (D-043): {} or { "in_custody": bool, "negotiation_left_s": float, "auto_release_left_s": float
##   (< 0 = none), "highlighted_hostage_net_id": int }
var custody: Dictionary = {}:
	set(v):
		custody = v
		custody_changed.emit()
## v1.3 (D-049): Commander Brandt on the map, and his Aegis damage resistance 0..1.
var captain_present: bool = false:
	set(v):
		captain_present = v
		captain_changed.emit()
var captain_resistance: float = 0.0:
	set(v):
		captain_resistance = v
		captain_changed.emit()
## PP-A-1 (S5.8 / D-079): net id of the guard a shout would dominate now, 0 = none; seconds left.
var dominate_target: int = 0:
	set(v):
		dominate_target = v
		dominate_prompt_changed.emit()
var dominate_window_s: float = 0.0:
	set(v):
		dominate_window_s = v
		dominate_prompt_changed.emit()
## ui_hud v1.16: P's scoped ADS (the HUD keeps its text panels out of `scope_ring`, screen space). Read every frame.
var scoped_ads: bool = false
var scope_ring: Rect2 = Rect2()
## v1.4 (B4-19): sprint stamina 0..1 (1 = full) and the exhausted flag (no sprint until recovered).
var stamina: float = 1.0:
	set(v):
		stamina = v
		stamina_changed.emit()
var exhausted: bool = false:
	set(v):
		exhausted = v
		stamina_changed.emit()
## B6-02 (proposed for ui_hud.md; ahead of ENV A): EVERY crew member incl. the local player and AI,
##   [{ "slot": int, "name": String, "is_ai": bool, "is_local": bool, "kills": int, "specials_killed": int,
##   "civilians_killed": int, "downs": int, "shots": int, "hits": int, "headshots": int }]
##   Counters ENV A does not track yet are simply absent from a row (the scoreboard shows "—").
var crew_stats: Array[Dictionary] = []:
	set(v):
		crew_stats = v
		crew_stats_changed.emit()
## v1.2: the crew member followed without a HeistRuntime (firing range); see track().
var tracked_crew: Node = null


## v1.2 stand-in for LocalHudModel.track(crew) (the mock only records it).
func track(crew_member: Node) -> void:
	tracked_crew = crew_member


func _ready() -> void:
	add_to_group(G.LOCAL_HUD_MODEL)
