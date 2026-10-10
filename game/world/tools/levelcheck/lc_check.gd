## Base class of every validate_level check module. Owner: ENV C.
## Spec: docs/design/level_standards.md §7; algorithms: tools/levelcheck/README.md.
## A check appends issues via fail()/warn(); it passes when it has no FAIL issues.
class_name LcCheck
extends RefCounted

const SEV_FAIL: StringName = &"FAIL"
const SEV_WARN: StringName = &"WARN"

## Short id used on the command line (--only=) and in reports.
var id: StringName = &""
## Stages the check runs at: "greybox" and/or "final" (final also runs every greybox check).
var stages: PackedStringArray = PackedStringArray(["greybox", "final"])
var title: String = ""
## Each: { "severity": StringName, "node": String, "pos": Vector3, "msg": String, "has_pos": bool }
var issues: Array[Dictionary] = []
## Free-form report lines (statistics, per-room tables...).
var notes: PackedStringArray = PackedStringArray()
var elapsed_ms: int = 0
var skipped_reason: String = ""


func applies(stage: String) -> bool:
	return stage in stages


## Override. May await (navigation/physics sync).
func run(_ctx: LcContext) -> void:
	pass


func fail(ctx: LcContext, node: Node, pos: Variant, msg: String) -> void:
	_add(SEV_FAIL, ctx, node, pos, msg)


func warn(ctx: LcContext, node: Node, pos: Variant, msg: String) -> void:
	_add(SEV_WARN, ctx, node, pos, msg)


func note(line: String) -> void:
	notes.append(line)


func fail_count() -> int:
	var n: int = 0
	for i: Dictionary in issues:
		if i["severity"] == SEV_FAIL:
			n += 1
	return n


func warn_count() -> int:
	return issues.size() - fail_count()


func passed() -> bool:
	return fail_count() == 0


## Issues sorted deterministically (severity, node, message).
func sorted_issues() -> Array[Dictionary]:
	var out: Array[Dictionary] = issues.duplicate()
	out.sort_custom(_issue_less)
	return out


static func _issue_less(a: Dictionary, b: Dictionary) -> bool:
	if a["severity"] != b["severity"]:
		return String(a["severity"]) < String(b["severity"])
	if a["node"] != b["node"]:
		return String(a["node"]) < String(b["node"])
	return String(a["msg"]) < String(b["msg"])


static func fmt_v(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]


static func issue_line(i: Dictionary) -> String:
	var where: String = ""
	if i["has_pos"]:
		where = " @ %s" % fmt_v(i["pos"])
	return "%s `%s`%s: %s" % [i["severity"], i["node"], where, i["msg"]]


func _add(sev: StringName, ctx: LcContext, node: Node, pos: Variant, msg: String) -> void:
	var path: String = "<map>"
	if node != null:
		path = ctx.node_path(node)
	var has_pos: bool = pos is Vector3
	var p: Vector3 = Vector3.ZERO
	if has_pos:
		p = pos
	elif node is Node3D and (node as Node3D).is_inside_tree():
		p = (node as Node3D).global_position
		has_pos = true
	issues.append({"severity": sev, "node": path, "pos": p, "msg": msg, "has_pos": has_pos})
