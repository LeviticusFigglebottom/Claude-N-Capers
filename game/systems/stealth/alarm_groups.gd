## Alarm groups (D-103 §6 / QC-54, Gallery Night frame sensors). Owner: ENV A.
## A group (e.g. &"argus") is live until the mission or a hack disables it. Alarmed loot (LootSpawn.alarm_on_take)
## in a live group raises alarm_raised(&"sensor") when taken; a disabled group's loot is safe for the rest of the run.
## Server-side runtime service (SERVICE), created on first use like CivilianTargets / ShoutSystem.
class_name AlarmGroups
extends Node

const SERVICE: StringName = &"alarm_groups"
const REASON_SENSOR: StringName = &"sensor"

var _disabled: Dictionary[StringName, bool] = {}


## The runtime's AlarmGroups service, created on first use.
static func ensure(rt: HeistRuntime) -> AlarmGroups:
	if rt == null:
		return null
	var s: AlarmGroups = rt.service(SERVICE) as AlarmGroups
	if s == null:
		s = AlarmGroups.new()
		s.name = "AlarmGroups"
		rt.register_service(SERVICE, s)
	return s


## Server: take `group` offline for the rest of the run (hack done, mission script).
static func disable(rt: HeistRuntime, group: StringName) -> void:
	var s: AlarmGroups = ensure(rt)
	if s != null and group != &"":
		s._disabled[group] = true
		Log.info(&"stealth", "alarm group %s disabled" % group)


## True while `group` still alarms (an empty group is always live).
static func is_live(rt: HeistRuntime, group: StringName) -> bool:
	var s: AlarmGroups = ensure(rt)
	return s == null or group == &"" or not s._disabled.has(group)
