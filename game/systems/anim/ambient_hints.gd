## Brain anim_hint substitutions for AnimDriver._hint (D-069 / D-111 ambient clips). Owner: ENV A.
## Presentation only (reads NPC state, never writes it). Static: no state of its own.
class_name AmbientHints
extends RefCounted

## OF-A6 (Ostrander Federal rare vip_client): the bodyguard's spawn tag; calm at his post he plays bouncer_idle.
const VIP_GUARD_TAG: StringName = &"guard_vip"


## The hint AnimDriver plays for brain hint `h` of `npc`: a dance pick, then the per-NPC ambient substitutions.
static func resolve(npc: NpcBase, combat: CombatClips, h: StringName) -> StringName:
	return ambient_hint(npc, combat, dance_pick(npc, h))


## D-111: `dance` is one of the three dance loops, stable per NPC name (every peer agrees).
static func dance_pick(npc: NpcBase, h: StringName) -> StringName:
	if h != &"dance" or npc == null:
		return h
	return [&"dance_a", &"dance_b", &"dance_c"][absi(hash(String(npc.name))) % 3]


## D-069 per-NPC ambient substitutions: cleaners mop instead of browsing, Kessler reads in his armchair instead of
## sitting, the camera operator watches the monitors, a seated phone call, cartel gunmen idle as thugs, the VIP's
## bodyguard (OF-A6) stands like a doorman.
static func ambient_hint(npc: NpcBase, combat: CombatClips, h: StringName) -> StringName:
	var tags: Array = npc.spawn_info.get("tags", []) as Array
	if h == &"browse" and tags.any(func(t: Variant) -> bool: return String(t).begins_with("civ_cleaner")):
		return &"mop"
	if h == &"sit" and (tags.has(&"civ_kessler") or combat.armed_seat_clip(npc) != &""):
		# LEAD (D's SL audit): Kessler's Seat is an armchair (falls back to sit_bed_read); DB-4 (characters.md v1.24):
		# a cartel gunman / armed guard sits armed, the long gun across the lap
		return &"sit_chair_read" if tags.has(&"civ_kessler") else &"sit_chair_armed"
	if h == &"phone" and String(npc.spawn_info.get("idle_activity", "")) == "sit":
		return &"phone_seated"
	if (h == &"" or h == &"idle") and npc.role == CartelBrain.ROLE and npc.alert_state == Enums.AlertState.CALM:
		return &"idle_thug"
	if (h == &"" or h == &"idle") and tags.has(VIP_GUARD_TAG) and npc.role == &"guard" \
			and npc.alert_state == Enums.AlertState.CALM:
		return &"bouncer"  # OF-A6: the VIP's close protection stands at his post arms crossed (bouncer_idle)
	if (h == &"" or h == &"idle") and bool(npc.spawn_info.get("no_patrol", false)) and npc.role == &"guard" \
			and npc.alert_state == Enums.AlertState.CALM:
		return &"sit_chair_watch"  # S8.2 camera operator at his station
	var act: StringName = StringName(npc.spawn_info.get("idle_activity", &""))
	if (h == &"" or h == &"idle") and npc.role == &"guard" and npc.alert_state == Enums.AlertState.CALM \
			and act != &"" and AnimDriver.HINT_CLIPS.has(act):
		return act  # D (AH cast): the door / rope bouncers stand at their post in bouncer_idle, not idle_b
	return h
