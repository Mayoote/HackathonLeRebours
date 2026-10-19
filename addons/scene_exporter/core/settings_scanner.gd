# settings_scanner.gd — filters the project settings referenced by carried
# scripts down to those that should travel with the scene, and attaches a
# current value + overwrite policy to each.
#
# Who calls: manifest.gd during export.
# Input: the list of setting keys the walker collected from literal
# `ProjectSettings.get_setting(...)` / `.has_setting(...)` / `.set_setting(...)`
# calls in carried scripts.
#
# Output: Array[Dictionary] like
#   [{"key": "game/difficulty_curve", "value": 1.5,
#     "overwrite_policy": "warn"}]
#
@tool
class_name SceneExporterSettingsScanner
extends RefCounted


# Forbidden namespaces — never travel. These are per-target-project
# concerns, not gameplay. Listed in PLAN.md §3.3.
const _FORBIDDEN_PREFIXES: Array[String] = [
	"application/",
	"run/",
	"display/",
	"rendering/",
	"editor/",
	"filesystem/",
	"debug/",
	"internationalization/locale/",
]

const DEFAULT_POLICY: String = "warn"


func scan(referenced_keys: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k: Variant in referenced_keys:
		var key: String = String(k)
		if key == "":
			continue
		if _is_forbidden(key):
			continue
		if not ProjectSettings.has_setting(key):
			# The script references a setting that doesn't exist in the
			# source project. Skip silently — it might be a default query
			# (`has_setting(...)`) or a typo; either way, nothing to carry.
			continue
		var value: Variant = ProjectSettings.get_setting(key)
		out.append({
			"key": key,
			"value": value,
			"overwrite_policy": DEFAULT_POLICY,
		})
	return out


func _is_forbidden(key: String) -> bool:
	for prefix: String in _FORBIDDEN_PREFIXES:
		if key.begins_with(prefix):
			return true
	return false
