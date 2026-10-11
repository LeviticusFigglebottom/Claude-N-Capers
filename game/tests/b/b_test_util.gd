## Shared helpers for ENV B tests.
class_name BTestUtil
extends RefCounted


## Per-process SaveService root for tests. user:// is shared by every checkout of the project
## (same project name), so parallel test runs must not share one profile folder.
static func profile_root() -> String:
	return "user://test_profiles_%d" % OS.get_process_id()


## Per-process GameSettings root (B5-01): settings tests never touch the real user://settings.cfg.
static func settings_root() -> String:
	return "user://test_settings_%d" % OS.get_process_id()
