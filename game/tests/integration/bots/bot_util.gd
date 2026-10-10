## Helpers for integration-test bots. Owner: LEAD.
class_name BotUtil
extends RefCounted


## Intent that looks from `from` toward `to` (absolute yaw/pitch, Godot -Z forward).
static func look_at_intent(from: Vector3, to: Vector3, base: CrewIntent = null) -> CrewIntent:
	var i: CrewIntent = base if base != null else CrewIntent.new()
	var d: Vector3 = to - from
	i.look_yaw = atan2(-d.x, -d.z)
	i.look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	return i


static func idle() -> CrewIntent:
	return CrewIntent.new()


## True if the gameplay API needed by integration gates exists yet (ENV A delivers in P1).
static func runtime_available() -> bool:
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if c["class"] == &"HeistLauncher":
			return true
	return false
