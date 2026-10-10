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
@export var ready_color: Color = Color(0.45, 0.85, 0.5)
@export var not_ready_color: Color = Color(0.85, 0.78, 0.62)
@export var illegal_color: Color = Color(1.0, 0.45, 0.4)


static func load_default() -> LobbyTweak:
	var tw: LobbyTweak = null
	if ResourceLoader.exists(DEFAULT_PATH):
		tw = load(DEFAULT_PATH) as LobbyTweak
	return tw if tw != null else LobbyTweak.new()
