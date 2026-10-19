# preflight.gd — dry-run check that tells the user exactly what will change
# in the target project BEFORE the importer writes anything.
#
# Who calls: import_dialog.gd (to build its summary UI); run_import.gd (for
# optional headless CI reports).
# What it emits: a Dictionary keyed by check category, each carrying a list
# of per-item entries with a `status` field the UI can colour-code.
#
# Status vocabulary (stable across categories so the UI can reuse icons):
#   "ok"              — nothing to do / already matches
#   "new"             — will be added (no conflict)
#   "warn_overwrite"  — target already has this and it'll be replaced
#                       (file or setting with policy=warn)
#   "missing"         — required prerequisite is absent (plugin not
#                       installed; autoload conflict)
#   "disabled"        — plugin installed but not enabled in target
#   "mismatch"        — value differs and policy demands user attention
#   "skipped"         — target value is kept (policy=skip_if_exists)
#
# Overall result: "ok" | "warnings" | "errors". "errors" means the user
# must act (install a plugin, resolve an autoload conflict) before the
# apply phase can proceed.
#
# Invariant: read-only. Never writes to the target. Safe to run on
# background thread if a UI ever needs to.

@tool
class_name SceneExporterPreflight
extends RefCounted


const MANIFEST_ENTRY: String = "package.json"
const FILES_PREFIX: String = "files/"


# zip_path: absolute path to the package zip.
# target_project_path: absolute path to the target project root.
func check(zip_path: String, target_project_path: String) -> Dictionary:
	var report: Dictionary = {
		"zip_path": zip_path,
		"target_project_path": target_project_path,
		"manifest": null,
		"godot_version": {},
		"plugins": [],
		"autoloads": [],
		"settings": [],
		"files": [],
		"warnings": [] as Array[String],
		"errors": [] as Array[String],
		"overall": "ok",
	}

	var reader: ZIPReader = ZIPReader.new()
	if reader.open(zip_path) != OK:
		report.errors.append(tr("Could not open the package at {path}. Is the file actually a Scene Package?").format({"path": zip_path}))
		report.overall = "errors"
		return report

	var manifest_bytes: PackedByteArray = reader.read_file(MANIFEST_ENTRY)
	if manifest_bytes.size() == 0:
		report.errors.append(tr("The package has no package.json — it doesn't look like a Scene Package."))
		report.overall = "errors"
		reader.close()
		return report

	var parsed: Variant = JSON.parse_string(manifest_bytes.get_string_from_utf8())
	if not (parsed is Dictionary):
		report.errors.append(tr("The package's manifest is corrupted (not valid JSON)."))
		report.overall = "errors"
		reader.close()
		return report
	var manifest: Dictionary = parsed
	report.manifest = manifest

	report.godot_version = _check_godot_version(manifest)
	report.plugins = _check_plugins(manifest, target_project_path)
	report.autoloads = _check_autoloads(manifest, target_project_path)
	report.settings = _check_settings(manifest, target_project_path)
	report.files = _check_files(manifest, target_project_path, reader)
	report.warnings = _manifest_warnings(manifest)

	reader.close()
	report.overall = _overall(report)
	return report


# --- Category checks --------------------------------------------------------

func _check_godot_version(manifest: Dictionary) -> Dictionary:
	var src: String = String(manifest.get("godot_version", ""))
	var tgt: String = Engine.get_version_info().get("string", "unknown")
	var status: String = "ok"
	# Compare the first two components (major.minor). A major-version skew
	# is an error; minor skew is a warning; patch/build skew is fine.
	var src_parts: PackedStringArray = src.split(".")
	var tgt_parts: PackedStringArray = tgt.split(".")
	if src_parts.size() >= 2 and tgt_parts.size() >= 2:
		if src_parts[0] != tgt_parts[0]:
			status = "missing"  # major mismatch — treat as blocking
		elif src_parts[1] != tgt_parts[1]:
			status = "warn_overwrite"
	return {"source": src, "target": tgt, "status": status}


func _check_plugins(manifest: Dictionary, target_project: String) -> Array:
	var required: Array = manifest.get("required_plugins", [])
	var out: Array = []
	var project_godot: String = target_project.path_join("project.godot")
	var enabled: Dictionary = _enabled_plugin_cfgs(project_godot)
	for entry: Variant in required:
		if not (entry is Dictionary):
			continue
		var e: Dictionary = entry
		var cfg_rel: String = String(e.get("path", ""))
		var cfg_abs: String = _resolve_res(cfg_rel, target_project)
		var status: String = "missing"
		if FileAccess.file_exists(cfg_abs):
			status = "disabled"
			if enabled.has(cfg_rel):
				status = "ok"
		out.append({
			"name": String(e.get("name", "")),
			"path": cfg_rel,
			"version": String(e.get("version", "")),
			"description": String(e.get("description", "")),
			"install_hint": String(e.get("install_hint", "")),
			"status": status,
		})
	return out


func _check_autoloads(manifest: Dictionary, target_project: String) -> Array:
	var required: Array = manifest.get("required_autoloads", [])
	var out: Array = []
	var project_godot: String = target_project.path_join("project.godot")
	var cfg: ConfigFile = ConfigFile.new()
	var loaded: bool = cfg.load(project_godot) == OK

	for entry: Variant in required:
		if not (entry is Dictionary):
			continue
		var e: Dictionary = entry
		var name: String = String(e.get("name", ""))
		var path: String = String(e.get("path", ""))
		var singleton: bool = bool(e.get("singleton", true))
		var status: String = "new"
		var current_value: String = ""
		if loaded and cfg.has_section_key("autoload", name):
			current_value = String(cfg.get_value("autoload", name, ""))
			var current_path: String = current_value.trim_prefix("*")
			if _is_same_autoload_script(current_path, path, target_project):
				status = "ok"
			else:
				# Name collision with a different script — user must resolve.
				status = "missing"
		out.append({
			"name": name,
			"path": path,
			"singleton": singleton,
			"current_value": current_value,
			"status": status,
		})
	return out


# The exporter always writes autoload paths as res:// (autoload_scanner
# resolves uid:// at export time), but the target project may register the
# same autoload by UID — Godot 4.4+ does that by default, and the hackathon
# base project does it for ArduinoManager and FmodManager. Treat a uid://
# value as the same script when it resolves to the manifest's res:// path.
func _is_same_autoload_script(current_path: String, path: String, target_project: String) -> bool:
	if current_path == path:
		return true
	if not current_path.begins_with("uid://") or not path.begins_with("res://"):
		return false
	# 1. The target's own .uid sidecar for that script (works headless and
	#    whichever project is open in the editor).
	var sidecar: String = target_project.path_join(path.trim_prefix("res://") + ".uid")
	if FileAccess.file_exists(sidecar):
		if FileAccess.get_file_as_string(sidecar).strip_edges() == current_path:
			return true
	# 2. The engine's UID registry, when the target is the open project.
	var id: int = ResourceUID.text_to_id(current_path)
	if id != ResourceUID.INVALID_ID and ResourceUID.has_id(id):
		return ResourceUID.get_id_path(id) == path
	return false


func _check_settings(manifest: Dictionary, target_project: String) -> Array:
	var required: Array = manifest.get("required_project_settings", [])
	var out: Array = []
	var project_godot: String = target_project.path_join("project.godot")
	var cfg: ConfigFile = ConfigFile.new()
	var loaded: bool = cfg.load(project_godot) == OK

	for entry: Variant in required:
		if not (entry is Dictionary):
			continue
		var e: Dictionary = entry
		var key: String = String(e.get("key", ""))
		var value: Variant = e.get("value")
		var policy: String = String(e.get("overwrite_policy", "warn"))
		var section: String = ""
		var leaf: String = ""
		var slash: int = key.find("/")
		if slash > 0:
			section = key.substr(0, slash)
			leaf = key.substr(slash + 1)
		else:
			section = "globals"
			leaf = key

		var status: String = "new"
		var current: Variant = null
		if loaded and cfg.has_section_key(section, leaf):
			current = cfg.get_value(section, leaf)
			if _values_equal(current, value):
				status = "ok"
			else:
				match policy:
					"skip_if_exists":
						status = "skipped"
					"error":
						status = "missing"
					_:
						status = "warn_overwrite"
		out.append({
			"key": key,
			"value": value,
			"current": current,
			"policy": policy,
			"status": status,
		})
	return out


func _check_files(manifest: Dictionary, target_project: String, reader: ZIPReader) -> Array:
	var files: Array = manifest.get("files", [])
	var out: Array = []
	var zip_entries: Dictionary = {}
	for entry: String in reader.get_files():
		zip_entries[entry] = true
	for entry: Variant in files:
		if not (entry is Dictionary):
			continue
		var e: Dictionary = entry
		var path: String = String(e.get("path", ""))
		var rel: String = path.trim_prefix("res://")
		var abs: String = target_project.path_join(rel)
		var status: String = "new"
		var target_size: int = 0
		var expected_sha: String = String(e.get("sha256", ""))
		if FileAccess.file_exists(abs):
			var f: FileAccess = FileAccess.open(abs, FileAccess.READ)
			if f != null:
				target_size = f.get_length()
				f.close()
			# Content-equal files are not a conflict — the importer would
			# rewrite byte-identical data. Compare SHA-256 to tell the user
			# only about real changes.
			var target_sha: String = FileAccess.get_sha256(abs)
			if expected_sha != "" and target_sha == expected_sha:
				status = "ok"
			else:
				status = "warn_overwrite"
		var zip_present: bool = zip_entries.has(FILES_PREFIX + rel)
		out.append({
			"path": path,
			"kind": String(e.get("kind", "resource")),
			"size": int(e.get("size", 0)),
			"sha256": String(e.get("sha256", "")),
			"target_size": target_size,
			"zip_present": zip_present,
			"status": status,
		})
	return out


func _manifest_warnings(manifest: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for w: Variant in manifest.get("warnings", []):
		out.append(String(w))
	return out


# --- Helpers -----------------------------------------------------------------

func _enabled_plugin_cfgs(project_godot: String) -> Dictionary:
	var out: Dictionary = {}
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(project_godot) != OK:
		return out
	if not cfg.has_section_key("editor_plugins", "enabled"):
		return out
	var arr: Variant = cfg.get_value("editor_plugins", "enabled", PackedStringArray())
	if arr is PackedStringArray:
		for p: String in arr:
			out[p] = true
	return out


func _resolve_res(res_path: String, target_project: String) -> String:
	if res_path.begins_with("res://"):
		return target_project.path_join(res_path.trim_prefix("res://"))
	return res_path


func _values_equal(a: Variant, b: Variant) -> bool:
	# Int/float round-trips through JSON can lose exactness (1.5 vs 1.5000001).
	# Project settings written back via ConfigFile are typed, so direct
	# equality works for most cases. Allow a small epsilon for floats.
	if typeof(a) == TYPE_FLOAT and typeof(b) == TYPE_FLOAT:
		return absf(a - b) < 0.000001
	return a == b


func _overall(report: Dictionary) -> String:
	if not report.errors.is_empty():
		return "errors"
	var has_warn: bool = false
	if report.godot_version.status == "missing":
		return "errors"
	if report.godot_version.status == "warn_overwrite":
		has_warn = true
	for p: Dictionary in report.plugins:
		if p.status == "missing":
			return "errors"
		if p.status == "disabled":
			has_warn = true
	for a: Dictionary in report.autoloads:
		if a.status == "missing":
			return "errors"
	for s: Dictionary in report.settings:
		if s.status == "missing":
			return "errors"
		if s.status in ["warn_overwrite", "skipped"]:
			has_warn = true
	for f: Dictionary in report.files:
		if f.status == "warn_overwrite":
			has_warn = true
	return "warnings" if has_warn else "ok"
