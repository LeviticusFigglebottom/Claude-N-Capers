## Per-heist service locator. Owner: LEAD.
## HeistRuntime (ENV A) registers its managers at heist start and calls Services.clear() on teardown.
##   Services.register(G.SVC_PAGERS, pager_system)
##   var pagers: Node = Services.get_service(G.SVC_PAGERS)
class_name Services
extends RefCounted

static var _map: Dictionary[StringName, Object] = {}


static func register(service_name: StringName, service: Object) -> void:
	if _map.has(service_name) and _map[service_name] != service:
		Log.warn(&"services", "replacing service %s" % service_name)
	_map[service_name] = service


static func get_service(service_name: StringName) -> Object:
	var s: Object = _map.get(service_name)
	if s != null and is_instance_valid(s):
		return s
	return null


static func has(service_name: StringName) -> bool:
	return get_service(service_name) != null


static func clear() -> void:
	_map.clear()
