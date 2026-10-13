## Skill tree / perk deck screen data (B4-03). Data: res://content/data/ui/progression_ui.tres.
## Owner: ENV B. The perk point rate moved to content/data/tweak/perk_points.tres (PerkPointTweak,
## D-034 QB-45); xp_per_perk_point below only forwards to it for existing readers.
class_name ProgressionUiTweak
extends Resource

const DEFAULT_PATH: String = "res://content/data/ui/progression_ui.tres"

## PD2 P2 "multiple skill sets": how many sets the selector offers (PlayerProfile.skill_sets).
@export var skill_set_count: int = 3
## Dev builds: every card of every deck counts as unlocked (no perk points needed). A dev/UI switch,
## not balance, so it stays here.
@export var dev_unlock_all_perks: bool = false
## Perk deck list order (ids); decks missing here follow, sorted by id.
@export var deck_order: Array[StringName] = []
## Skill button border colors per state (SkillBuild.STATE_*). PO-4 "Case File": ink lines for locked /
## available, paper for basic, OK green for aced (brass is money / primary, cyan is focus only).
@export var skill_locked_color: Color = UiTokens.LINE
@export var skill_available_color: Color = UiTokens.LINE_STRONG
@export var skill_basic_color: Color = UiTokens.PAPER_DIM
@export var skill_aced_color: Color = UiTokens.OK
## How much an owned (basic / aced) skill's fill is tinted with its state color (focus keeps the border).
@export var owned_tint: float = 0.22
## Details text: blocked-effect note and "can't take" reason.
@export var note_color: Color = UiTokens.PAPER_DIM
@export var reason_color: Color = UiTokens.ALERT
## Perk card panel borders (unlocked = OK green, next = paper, locked = hairline).
@export var card_unlocked_color: Color = UiTokens.OK
@export var card_next_color: Color = UiTokens.PAPER_DIM
@export var card_locked_color: Color = UiTokens.LINE

## Perk points (PD2 P4): read-only forward to PerkPointTweak (balance data, not UI; D-034 QB-45).
var xp_per_perk_point: int:
	get:
		return PerkPointTweak.current().xp_per_perk_point


static func load_default() -> ProgressionUiTweak:
	var tw: ProgressionUiTweak = null
	if ResourceLoader.exists(DEFAULT_PATH):
		tw = load(DEFAULT_PATH) as ProgressionUiTweak
	return tw if tw != null else ProgressionUiTweak.new()
