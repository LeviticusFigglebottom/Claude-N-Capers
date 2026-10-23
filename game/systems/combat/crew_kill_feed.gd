## D-162 shared CREW-KILL event (Biker, Hacker card 9 Botnet). Owner: ENV A. Server only. One service per heist
## re-emits EventBus.npc_killed as crew_kill(killer_slot, victim_net_id, info) whenever the killer is a crew member
## (human or AI). Listeners that care about ANY teammate's kill connect here instead of resolving killer ids.
class_name CrewKillFeed
extends Node

signal crew_kill(killer_slot: int, victim_net_id: int, info: Dictionary)

const SERVICE: StringName = &"crew_kill_feed"
const NODE_NAME: String = "CrewKillFeed"


## The runtime's feed, created on first use (null without a runtime).
static func of(rt: HeistRuntime) -> CrewKillFeed:
	if rt == null:
		return null
	var f: CrewKillFeed = rt.service(SERVICE) as CrewKillFeed
	if f == null:
		f = CrewKillFeed.new()
		f.name = NODE_NAME
		rt.register_service(SERVICE, f)
	return f


func _ready() -> void:
	EventBus.npc_killed.connect(_on_npc_killed)


func _on_npc_killed(victim_net_id: int, killer_net_id: int, info: Dictionary) -> void:
	if not Net.is_authority():
		return
	var c: CrewController = Ids.lookup(killer_net_id) as CrewController
	if c != null:
		crew_kill.emit(c.slot, victim_net_id, info)
