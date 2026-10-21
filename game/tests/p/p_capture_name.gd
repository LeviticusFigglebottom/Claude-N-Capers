## Capture file names that every OS can check out (LEAD 2026-10-20: `->` in two PNG names broke the PO's Windows
## clone). safe_path() rewrites only the file name: "->" becomes "to" and < > : " \ | ? * become "_"; the directory
## part (an absolute scratch path) is left alone. Every ENV P capture tool wraps its save_png path in it. Owner: ENV P.
class_name PCaptureName
extends RefCounted

const BAD: PackedStringArray = ["<", ">", ":", "\"", "\\", "|", "?", "*"]


static func safe_name(file_name: String) -> String:
	var s: String = file_name.replace("->", "to")
	for c: String in BAD:
		s = s.replace(c, "_")
	return s


static func safe_path(path: String) -> String:
	var dir: String = path.get_base_dir()
	var file: String = safe_name(path.get_file())
	return file if dir == "" else dir.path_join(file)
