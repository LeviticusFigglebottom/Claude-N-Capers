## Co-op lobby tuning (data: res://content/data/lobby/lobby_tweak.tres). Owner: ENV B.
class_name LobbyTweak
extends Resource

const DEFAULT_PATH: String = "res://content/data/lobby/lobby_tweak.tres"

## Port the Host / Join fields start with (Net.DEFAULT_PORT unless the data says otherwise).
@export var default_port: int = 27655
## Lowest / highest port the Join and Host fields accept.
@export var min_port: int = 1024
@export var max_port: int = 65535
## Address of the "loopback" quick-join (dev and tests: a host in another instance on this machine).
@export var loopback_address: String = "127.0.0.1"
## A join that has not been given a crew slot after this long is reported as failed.
@export var join_timeout_s: float = 8.0
## Longest crew name shown / accepted in a profile summary (longer names are cut).
@export var max_name_length: int = 24
## Slot text colours: ready, not ready, illegal loadout.
@export var ready_color: Color = UiTokens.OK
@export var not_ready_color: Color = UiTokens.PAPER_DIM
@export var illegal_color: Color = UiTokens.ALERT
## Chat (B6-03, ChatLog / ChatPanel): longest message (characters, after cleaning).
@export var chat_max_length: int = 160
## Rate limit per sender slot: at most chat_rate_count messages in any chat_rate_window_s seconds.
@export var chat_rate_count: int = 5
@export var chat_rate_window_s: float = 5.0
## Messages kept in the log and drawn by a chat panel.
@export var chat_history_cap: int = 50
## In-heist overlay: the closed panel starts fading this long after the last message, over chat_fade_time_s.
@export var chat_fade_after_s: float = 8.0
@export var chat_fade_time_s: float = 1.5
## InputMap action that opens the chat (project.godot `chat`: Enter / keypad Enter, D-072; T is `order_menu`).
@export var chat_action: StringName = &"chat"
## Drop-in (B6-04): the host's join request dialog auto-denies after this many seconds.
@export var dropin_request_timeout_s: float = 30.0
## Drop-in policy a new lobby starts with (LobbyState.POLICIES: ask / auto / off; PD2 default ask).
@export var dropin_default_policy: StringName = &"ask"


static func load_default() -> LobbyTweak:
	var tw: LobbyTweak = null
	if ResourceLoader.exists(DEFAULT_PATH):
		tw = load(DEFAULT_PATH) as LobbyTweak
	return tw if tw != null else LobbyTweak.new()
