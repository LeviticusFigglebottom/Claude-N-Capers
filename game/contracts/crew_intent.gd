## Per-tick intent for one crew member. Produced by: local player input (ENV A), AI teammate
## brain (ENV A), integration-test bots (LEAD). Consumed by ENV A's CrewController on the server
## (and predicted locally for the owning human). Owner: LEAD. Contract: docs/contracts/crew_intent.md.
class_name CrewIntent
extends RefCounted

var move: Vector2 = Vector2.ZERO        ## x = strafe right, y = forward; length <= 1
var look_yaw: float = 0.0               ## absolute, radians
var look_pitch: float = 0.0             ## absolute, radians, clamped +-89 deg
var sprint: bool = false
var crouch: bool = false
var jump: bool = false
var fire: bool = false
var aim: bool = false
var reload: bool = false
var interact: bool = false              ## held; target resolved by server-side ray/aim-assist cone
var interact_target_net_id: int = 0     ## optional explicit target (bots/AI); 0 = use aim
var shout: bool = false                 ## intimidate / mark / call out (context)
var melee: bool = false
var throw_item: bool = false
var deploy: bool = false
var mask_up: bool = false
var weapon_slot: int = -1               ## -1 = no change, else Enums.WeaponSlot
var drop_bag: bool = false
var throw_bag: bool = false
## AI teammate orders (from a human crew member): &"", &"follow", &"hold", &"carry_bag", &"drop_bag", &"revive"
var order: StringName = &""
var order_target_net_id: int = 0
var order_position: Vector3 = Vector3.ZERO


func to_dict() -> Dictionary:
	return {
		"mv": move, "yw": look_yaw, "pt": look_pitch, "sp": sprint, "cr": crouch, "jp": jump,
		"fi": fire, "ai": aim, "rl": reload, "in": interact, "it": interact_target_net_id,
		"sh": shout, "me": melee, "th": throw_item, "de": deploy, "mu": mask_up,
		"ws": weapon_slot, "db": drop_bag, "tb": throw_bag,
		"or": order, "ot": order_target_net_id, "op": order_position,
	}


static func from_dict(d: Dictionary) -> CrewIntent:
	var i: CrewIntent = CrewIntent.new()
	i.move = d.get("mv", Vector2.ZERO)
	i.look_yaw = d.get("yw", 0.0)
	i.look_pitch = d.get("pt", 0.0)
	i.sprint = d.get("sp", false)
	i.crouch = d.get("cr", false)
	i.jump = d.get("jp", false)
	i.fire = d.get("fi", false)
	i.aim = d.get("ai", false)
	i.reload = d.get("rl", false)
	i.interact = d.get("in", false)
	i.interact_target_net_id = d.get("it", 0)
	i.shout = d.get("sh", false)
	i.melee = d.get("me", false)
	i.throw_item = d.get("th", false)
	i.deploy = d.get("de", false)
	i.mask_up = d.get("mu", false)
	i.weapon_slot = d.get("ws", -1)
	i.drop_bag = d.get("db", false)
	i.throw_bag = d.get("tb", false)
	i.order = d.get("or", &"")
	i.order_target_net_id = d.get("ot", 0)
	i.order_position = d.get("op", Vector3.ZERO)
	return i
