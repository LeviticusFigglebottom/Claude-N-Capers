## Shared enums. Owner: LEAD. Contract: docs/contracts/README.md. Append-only (never reorder:
## values are serialized in saves and over the network).
class_name Enums
extends RefCounted

enum HeistPhase { LOADING, CASING, STEALTH, LOUD, ESCAPE, ENDED }

## NPC awareness. CURIOUS = detection filling ("?"), INVESTIGATING = walking to check,
## ALARMED = "!" will raise/call alarm, PANICKED = civilian fleeing/calling.
enum AlertState {
	CALM, CURIOUS, INVESTIGATING, ALARMED, PANICKED,
	INTIMIDATED, TIED, SURRENDERED, DOMINATED, CONVERTED, COMBAT, DEAD,
}

enum ObserverKind { GUARD, CIVILIAN, CAMERA, POLICE }

enum ObjectiveState { HIDDEN, ACTIVE, COMPLETED, FAILED }

## NONE while stealth. Cycle: ANTICIPATION -> BUILD -> SUSTAIN -> FADE -> CONTROL -> ANTICIPATION...
enum AssaultPhase { NONE, ANTICIPATION, BUILD, SUSTAIN, FADE, CONTROL }

enum WeaponClass { PISTOL, SMG, ASSAULT_RIFLE, SHOTGUN, LMG, SNIPER, SPECIAL, MELEE, THROWABLE }

enum WeaponSlot { PRIMARY, SECONDARY, MELEE, THROWABLE, DEPLOYABLE }

enum LootWeight { LIGHT, MEDIUM, HEAVY, VERY_HEAVY }

enum HitZone { BODY, HEAD, LIMB, WEAKPOINT }

enum DamageType { BULLET, MELEE, EXPLOSION, FIRE, POISON, TASE, FALL, ENVIRONMENT }

enum CrewState { NORMAL, DOWNED, TASED, CLOAKER_DOWNED, CUFFED, CUSTODY, SWAN_SONG }

enum Difficulty { ROUTINE, TENSE, HAZARDOUS, BRUTAL, LETHAL, CATACLYSM }

enum HeistMode { STEALTH_OR_LOUD, STEALTH_ONLY, LOUD_ONLY }

enum ModType { BARREL, BARREL_EXT, SUPPRESSOR, SIGHT, GRIP, FOREGRIP, STOCK, MAGAZINE, GADGET, BOLT, BODY, AMMO, CHARM, SKIN }

## Lowercase qualifier string for Modifiers queries ("shotgun", "assault_rifle", ...).
static func weapon_class_qualifier(c: WeaponClass) -> StringName:
	return StringName(String(WeaponClass.keys()[c]).to_lower())
