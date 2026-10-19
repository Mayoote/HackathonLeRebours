# autoload_scanner.gd — scans project.godot's [autoload] section and decides
# which autoloads the exported scene actually needs to carry.
#
# Who calls: manifest.gd during export.
# What it emits: Array[Dictionary] like
#   [{"name": "GameManager", "path": "res://autoload/game_manager.gd",
#     "singleton": true}]
#
# Inclusion rule (two paths):
#   1. The autoload's script path is present in the walker's resolved dep set
#      (it was preloaded/loaded from a carried script).
#   2. The autoload's name appears as a free-standing identifier in any
#      carried script — i.e. the scene's code calls `GameManager.foo()` by
#      the registered singleton name, which is the common Godot pattern and
#      is otherwise invisible to a file-dependency walker.
#
# Rule 2 requires a word-boundary regex so that `GameManager` matches but
# `FakeGameManagerMock` does not. We also strip line comments first to
# avoid false positives on `# GameManager is nice`.
#
# Invariant: only reads files. Never modifies project.godot.

@tool
class_name SceneExporterAutoloadScanner
extends RefCounted


const _AUTOLOAD_SECTION: String = "autoload"


func scan(project_godot_path: String, dep_paths: Array, script_sources: Array[String]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []

	var cfg: ConfigFile = ConfigFile.new()
	var err: int = cfg.load(project_godot_path)
	if err != OK:
		push_warning("[autoload_scanner] could not read %s (err=%d)" % [project_godot_path, err])
		return out
	if not cfg.has_section(_AUTOLOAD_SECTION):
		return out

	var dep_set: Dictionary = {}
	for p: Variant in dep_paths:
		dep_set[String(p)] = true

	for name: String in cfg.get_section_keys(_AUTOLOAD_SECTION):
		var raw: String = String(cfg.get_value(_AUTOLOAD_SECTION, name, ""))
		if raw == "":
			continue
		var singleton: bool = raw.begins_with("*")
		var script_path: String = raw.trim_prefix("*")

		# Autoloads can be registered by UID (e.g. *uid://biad5wyemkhq5)
		# rather than by path. The target project has an empty UID cache
		# on first open, so a UID-referenced autoload fails to resolve
		# and any script that uses its singleton name won't parse.
		# Resolve UID → res:// path here so the written project.godot
		# uses a stable path reference that works without a warm cache.
		if script_path.begins_with("uid://"):
			var resolved: String = _resolve_uid_path(script_path)
			if resolved == "":
				push_warning(
					"[autoload_scanner] could not resolve UID %s for autoload %s; keeping UID as-is"
					% [script_path, name]
				)
			else:
				script_path = resolved

		if not _is_required(name, script_path, dep_set, script_sources):
			continue

		out.append({
			"name": name,
			"path": script_path,
			"singleton": singleton,
		})

	return out


func _is_required(
	autoload_name: String,
	script_path: String,
	dep_set: Dictionary,
	script_sources: Array[String],
) -> bool:
	if dep_set.has(script_path):
		return true
	return _name_referenced_in_any_script(autoload_name, script_sources)


func _name_referenced_in_any_script(autoload_name: String, script_sources: Array[String]) -> bool:
	# Match the autoload name as a standalone identifier. Godot's RegEx is
	# PCRE2-style, so \b does word-boundary matching on the default
	# identifier class.
	var pattern: String = "\\b" + _escape_for_regex(autoload_name) + "\\b"
	var re: RegEx = RegEx.new()
	if re.compile(pattern) != OK:
		return false
	for src: String in script_sources:
		if re.search(src) != null:
			return true
	return false


# Converts a "uid://..." string to its res:// path by consulting the
# engine's UID registry. Returns "" if the UID is unknown (stale or never
# registered). This relies on ResourceUID, which is populated from the
# editor's .godot/uid_cache.bin — available because export runs inside an
# open editor session.
func _resolve_uid_path(uid_str: String) -> String:
	var id: int = ResourceUID.text_to_id(uid_str)
	if id == ResourceUID.INVALID_ID:
		return ""
	if not ResourceUID.has_id(id):
		return ""
	var path: String = ResourceUID.get_id_path(id)
	if path.is_empty() or path == "res://":
		return ""
	return path


func _escape_for_regex(s: String) -> String:
	# Autoload names are identifiers in practice (letters/digits/underscore),
	# so no metachars — but belt-and-braces in case someone names one oddly.
	var out: String = ""
	for i: int in s.length():
		var c: String = s.substr(i, 1)
		if c in ["\\", ".", "^", "$", "|", "?", "*", "+", "(", ")", "[", "]", "{", "}"]:
			out += "\\" + c
		else:
			out += c
	return out
