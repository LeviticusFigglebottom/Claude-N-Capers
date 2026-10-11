## String constants for groups, services, and well-known ids. Owner: LEAD.
## Contract: docs/contracts/groups.md. Never type these strings literally elsewhere.
class_name G
extends RefCounted

# --- Groups placed by heist maps (ENV C) and consumed by systems (ENV A) ---
const PLAYER_SPAWN: StringName = &"player_spawn"
const PATROL_GRAPH: StringName = &"patrol_graph"
const GUARD_SPAWN: StringName = &"guard_spawn"
const CIVILIAN_SPAWN: StringName = &"civilian_spawn"
const CAMERA_SLOT: StringName = &"camera_slot"
const SECURITY_ROOM: StringName = &"security_room"
const POLICE_SPAWN: StringName = &"police_spawn"
const SNIPER_PERCH: StringName = &"sniper_perch"
const ESCAPE_ZONE: StringName = &"escape_zone"
const LOOT_SECURE_ZONE: StringName = &"loot_secure_zone"
const VARIANT_SLOT: StringName = &"variant_slot"
const COVER_POINT: StringName = &"cover_point"
const ENTRY_POINT: StringName = &"entry_point"  # windows/doors/vents police use to breach
const RESTRICTED_AREA: StringName = &"restricted_area"
const CASING_PUBLIC_AREA: StringName = &"public_area"
const BODY_HIDE_ZONE: StringName = &"body_hide_zone"
const PREPLAN_POINT: StringName = &"preplan_point"

# --- Runtime groups (ENV A) ---
const CREW: StringName = &"crew"
const NPC: StringName = &"npc"
const ENEMY: StringName = &"enemy"
const CIVILIAN: StringName = &"civilian"
const OBSERVER: StringName = &"observer"
const INTERACTABLE: StringName = &"interactable"
const LOOT_BAG: StringName = &"loot_bag"
const BODY: StringName = &"body"
const DEPLOYABLE: StringName = &"deployable"
const HOSTAGE: StringName = &"hostage"
const RANGE_TARGET: StringName = &"range_target"  ## firing-range targets: never in ENEMY/NPC (QB-24)
const SAW_TARGET: StringName = &"saw_target"  ## prefabs with saw_cut(seconds, attacker_net_id) (D-057)
const LOCAL_HUD_MODEL: StringName = &"local_hud_model"  ## exactly one per peer during a heist (ui_hud.md)

# --- HeistRuntime services ---
const SVC_STEALTH: StringName = &"stealth"
const SVC_PAGERS: StringName = &"pagers"
const SVC_DIRECTOR: StringName = &"director"
const SVC_LOOT: StringName = &"loot"
const SVC_OBJECTIVES: StringName = &"objectives"
const SVC_VARIANTS: StringName = &"variants"
const SVC_CREW: StringName = &"crew"
const SVC_NAV: StringName = &"nav"
