## Static access to ENV A tweak resources. Owner: ENV A.
## All gameplay numbers live in the .tres files next to this script (pd2_fidelity.md "Units").
class_name Tweak
extends RefCounted

static var _crew: CrewTweak = null
static var _interaction: InteractionTweak = null
static var _stealth: StealthTweak = null


static func crew() -> CrewTweak:
	if _crew == null:
		_crew = load("res://systems/tweak/crew_tweak.tres") as CrewTweak
	return _crew


static func interaction() -> InteractionTweak:
	if _interaction == null:
		_interaction = load("res://systems/tweak/interaction_tweak.tres") as InteractionTweak
	return _interaction


static func stealth() -> StealthTweak:
	if _stealth == null:
		_stealth = load("res://systems/stealth/stealth_tweak.tres") as StealthTweak
	return _stealth
