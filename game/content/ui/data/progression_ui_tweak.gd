## Skill tree / perk deck screen data (B4-03). Data: res://content/data/ui/progression_ui.tres.
## Owner: ENV B. The perk point rate lives here until the lead decides where it belongs (question
## QB perk points); it is read by PerkProgress.
class_name ProgressionUiTweak
extends Resource

const DEFAULT_PATH: String = "res://content/data/ui/progression_ui.tres"

## PD2 P2 "multiple skill sets": how many sets the selector offers (PlayerProfile.skill_sets).
@export var skill_set_count: int = 3
## Perk points (PD2 P4): earned = floor(total XP / xp_per_perk_point), spent = cost of every unlocked
## card of every deck; cards unlock in order. ◇ The rate is ours, not PD2's (question for the lead).
@export var xp_per_perk_point: int = 500
## Dev builds: every card of every deck counts as unlocked (no perk points needed).
@export var dev_unlock_all_perks: bool = false
## Perk deck list order (ids); decks missing here follow, sorted by id.
@export var deck_order: Array[StringName] = []
## Skill button border colors per state (SkillBuild.STATE_*).
@export var skill_locked_color: Color = Color(0.22, 0.23, 0.26)
@export var skill_available_color: Color = Color(0.45, 0.5, 0.58)
@export var skill_basic_color: Color = Color(0.35, 0.65, 1.0)
@export var skill_aced_color: Color = Color(1.0, 0.75, 0.25)
## How much an owned (basic / aced) skill's fill is tinted with its state color (focus keeps the border).
@export var owned_tint: float = 0.22
## Details text: blocked-effect note and "can't take" reason.
@export var note_color: Color = Color(0.6, 0.63, 0.68)
@export var reason_color: Color = Color(1.0, 0.45, 0.35)
## Perk card panel borders.
@export var card_unlocked_color: Color = Color(1.0, 0.75, 0.25)
@export var card_next_color: Color = Color(0.45, 0.5, 0.58)
@export var card_locked_color: Color = Color(0.22, 0.23, 0.26)


static func load_default() -> ProgressionUiTweak:
	var tw: ProgressionUiTweak = null
	if ResourceLoader.exists(DEFAULT_PATH):
		tw = load(DEFAULT_PATH) as ProgressionUiTweak
	return tw if tw != null else ProgressionUiTweak.new()
