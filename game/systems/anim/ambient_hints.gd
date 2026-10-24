## Brain anim_hint substitutions for AnimDriver._hint (D-069 / D-111 ambient clips). Owner: ENV A.
## Presentation only (reads NPC state, never writes it). Static: no state of its own.
class_name AmbientHints
extends RefCounted

## OF-A6 (Ostrander Federal rare vip_client): the bodyguard's spawn tag; calm at his post he plays bouncer_idle.
const VIP_GUARD_TAG: StringName = &"guard_vip"


## AnimDriver's hint for `npc`: on the host the brain's anim_hint (a non-empty `Surrender` component hint wins),
## resolved; on a client only the NET_HINTS the host replicates (NetEntityCodec NPC state "ah" -> META_NET_HINT).
static func of_body(npc: NpcBase, combat: CombatClips) -> StringName:
	if not Net.is_authority():
		var nh: Variant = npc.get_meta(AnimDriver.META_NET_HINT, &"")
		return nh if nh is StringName else &""
	var s: Node = npc.get_node_or_null(^"Surrender")
	if s != null:
		var sh: Variant = s.get(&"anim_hint")
		if sh is StringName and sh != &"":
			return sh
	var b: Node = npc.get_node_or_null(^"Brain")
	if b == null:
		return &""
	var h: Variant = b.get(&"anim_hint")
	return resolve(npc, combat, h if h is StringName else &"")  # D-111 dance pick, D-069 substitutions


## D-165 (LEAD r317): the hint the host replicates in the NPC state "ah" (META_NET_HINT on clients): the held cuff
## (D-116) and, while the NPC is calm, the hint the host's driver plays (dance pick, D-069 substitutions), so a client
## shows the same dancers / seats / bar staff. Combat (`aim`) and one-shot hints, the alert states and a plain idle
## (the client's default) stay host-only: clients use the alert-state fallbacks.
static func net_hint(npc: NpcBase) -> StringName:
	var b: Node = npc.get_node_or_null(^"Brain")
	var raw: Variant = b.get(&"anim_hint") if b != null else null
	var h: StringName = raw if raw is StringName else &""
	if AnimDriver.NET_HINTS.has(h):
		return h
	if not npc.alive or npc.alert_state != Enums.AlertState.CALM or h == &"aim" or AnimDriver.ONESHOT_HINTS.has(h):
		return &""
	var d: AnimDriver = AnimDriver.of(npc)
	var out: StringName = of_body(npc, d.combat) if d != null and d.combat != null else dance_pick(npc, h)
	return &"" if out == &"idle" else out


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
