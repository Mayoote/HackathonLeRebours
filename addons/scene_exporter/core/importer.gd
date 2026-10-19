# importer.gd — headless import of a Scene Package zip into a target project.
#
# Who calls: tests/scripts/run_import.gd now; ui/import_dialog.gd in Phase 4.
# What it does:
#   1. Open the zip, read package.json.
#   2. Extract every `files/<res-path>` entry into the target project at its
#      original res:// path (i.e. target_root/<res-path>).
#   3. Apply required_autoloads to target/project.godot.
#   4. Apply required_project_settings to target/project.godot, respecting
#      each setting's overwrite_policy.
#
# Phase-4 additions (NOT done here): pre-flight dialog, plugin checks, user
# confirmation, per-file overwrite review, EditorInterface filesystem scan.
# This Phase-3 importer is a pure headless applier — no UI, no prompts.
#
# Invariant: never writes outside the target project's filesystem. The zip
# is read-only. Never destroys the user's work silently: an existing file
# whose content differs from the package is copied to
# res://scene_exporter_backups/<date>/ (ignored by Godot via .gdignore)
# before being replaced (19/10/2026). If an autoload/setting would conflict, we currently follow
# the policy at face value (Phase 4 adds user confirmation).

@tool
class_name SceneExporterImporter
extends RefCounted


const MANIFEST_ENTRY: String = "package.json"
const FILES_PREFIX: String = "files/"
# Folder (relative to the target root) where replaced files are saved. A
# .gdignore keeps Godot from importing the copies (no duplicate class_name,
# no duplicate UIDs, nothing shown in the FileSystem dock).
const BACKUP_ROOT: String = "scene_exporter_backups"


# Emitted as the importer extracts entries. `current` is 1-based; `total`
# is the final count (all payload entries + manifest). UI panels can
# watch this; headless callers ignore it.
signal progress(current: int, total: int, label: String)


# target_project_path: OS-absolute path to the project root (contains
#                      project.godot). Note: this is NOT a res:// path —
#                      the importer writes via absolute FS paths because
#                      it may run from a different project's context.
func import_package(zip_path: String, target_project_path: String) -> Dictionary:
	var report: Dictionary = {
		"ok": false,
		"zip_path": zip_path,
		"target_project_path": target_project_path,
		"files_written": 0,
		"autoloads_applied": 0,
		"settings_applied": 0,
		"backed_up": [] as Array[String],
		"backup_dir": "",
		"warnings": [] as Array[String],
		"errors": [] as Array[String],
	}

	# --- 1. Open zip, parse manifest ----------------------------------------
	var reader: ZIPReader = ZIPReader.new()
	var open_err: int = reader.open(zip_path)
	if open_err != OK:
		report.errors.append(tr("Could not open the package at {path}. Is the file actually a Scene Package?").format({"path": zip_path}))
		return report

	var manifest_bytes: PackedByteArray = reader.read_file(MANIFEST_ENTRY)
	if manifest_bytes.size() == 0:
		report.errors.append(tr("The package has no package.json — it doesn't look like a Scene Package."))
		reader.close()
		return report

	var manifest_variant: Variant = JSON.parse_string(manifest_bytes.get_string_from_utf8())
	if not (manifest_variant is Dictionary):
		report.errors.append(tr("The package's manifest is corrupted (not valid JSON)."))
		reader.close()
		return report
	var manifest: Dictionary = manifest_variant

	# --- 2. Extract payload -------------------------------------------------
	var all_entries: PackedStringArray = reader.get_files()
	var payload_total: int = 0
	for entry: String in all_entries:
		if entry != MANIFEST_ENTRY and entry.begins_with(FILES_PREFIX) and not entry.ends_with("/"):
			payload_total += 1
	var idx: int = 0
	for entry: String in all_entries:
		if entry == MANIFEST_ENTRY:
			continue
		if not entry.begins_with(FILES_PREFIX):
			report.warnings.append(tr("Ignored unexpected entry in the package: {entry}").format({"entry": entry}))
			continue
		# Directory entries ("files/art/"): Godot 4.7's ZIPPacker writes them
		# automatically, and zips re-made by Finder / Windows Explorer have
		# them too. They carry no data — the folder is created on demand
		# by _write_file_abs(). Treating them as files made every import
		# fail with "Could not write art/ to the project".
		if entry.ends_with("/"):
			continue
		var rel_path: String = entry.trim_prefix(FILES_PREFIX)
		# Refuse entries that would escape the project folder ("../", absolute
		# paths). A hand-edited or malicious zip must never write outside it.
		# Godot's FileAccess treats "\\" as a separator on every OS, so
		# "files/..\\x" would escape too: check a "/"-normalised copy (revue 16/10).
		var rel_norm: String = rel_path.replace("\\", "/")
		if rel_norm.is_absolute_path() or rel_norm.begins_with("/") or ".." in rel_norm.split("/"):
			report.errors.append(tr("The package contains a file with an unsafe path, it was skipped: {path}").format({"path": rel_path}))
			continue
		idx += 1
		progress.emit(idx, payload_total, rel_path.get_file())
		var dest_abs: String = target_project_path.path_join(rel_path)
		var bytes: PackedByteArray = reader.read_file(entry)
		if not _backup_if_different(dest_abs, rel_path, bytes, target_project_path, report):
			report.errors.append(tr("Could not save a backup of {path}, so it was not replaced.").format({"path": rel_path}))
			continue
		if _write_file_abs(dest_abs, bytes):
			report.files_written += 1
		else:
			report.errors.append(tr("Could not write {path} to the project. Is the folder writable?").format({"path": rel_path}))
	reader.close()

	# --- 3. Apply manifest to target project.godot --------------------------
	var project_godot: String = target_project_path.path_join("project.godot")
	var cfg: ConfigFile = ConfigFile.new()
	var load_err: int = cfg.load(project_godot)
	if load_err != OK:
		report.errors.append(tr("Could not read the target's project.godot — is {path} really a Godot project?").format({"path": target_project_path}))
		return report

	report.autoloads_applied = _apply_autoloads(cfg, manifest.get("required_autoloads", []))
	report.settings_applied = _apply_settings(cfg, manifest.get("required_project_settings", []), report.warnings)

	var save_err: int = cfg.save(project_godot)
	if save_err != OK:
		report.errors.append(tr("Could not save changes to the target's project.godot — is the file read-only?"))
		return report

	report.ok = report.errors.is_empty()
	return report


# --- Private ---------------------------------------------------------------

# Copies the target's current file to the backup folder when the package is
# about to replace it with different content. Returns false only when a
# backup was needed and could not be written (the caller then skips the file).
func _backup_if_different(dest_abs: String, rel_path: String, new_bytes: PackedByteArray,
		target_project_path: String, report: Dictionary) -> bool:
	if not FileAccess.file_exists(dest_abs):
		return true
	var old_bytes: PackedByteArray = FileAccess.get_file_as_bytes(dest_abs)
	if old_bytes == new_bytes:
		return true
	if report.backup_dir == "":
		report.backup_dir = _new_backup_dir(target_project_path)
		if report.backup_dir == "":
			return false
	var backup_abs: String = target_project_path.path_join(report.backup_dir).path_join(rel_path)
	if not _write_file_abs(backup_abs, old_bytes):
		return false
	report.backed_up.append(rel_path)
	return true


# Creates <target>/scene_exporter_backups/<date>[_n]/ and the .gdignore.
# Returns the folder relative to the target root, or "" on failure.
func _new_backup_dir(target_project_path: String) -> String:
	var root_abs: String = target_project_path.path_join(BACKUP_ROOT)
	if DirAccess.make_dir_recursive_absolute(root_abs) != OK:
		return ""
	var ignore_abs: String = root_abs.path_join(".gdignore")
	if not FileAccess.file_exists(ignore_abs):
		var f: FileAccess = FileAccess.open(ignore_abs, FileAccess.WRITE)
		if f == null:
			return ""
		f.close()
	# "2026-10-19T14:05:09" → "2026-10-19_14-05-09" (no ":" — Windows-safe).
	var stamp: String = Time.get_datetime_string_from_system().replace("T", "_").replace(":", "-")
	var rel: String = BACKUP_ROOT.path_join(stamp)
	var n: int = 2
	while DirAccess.dir_exists_absolute(target_project_path.path_join(rel)):
		rel = BACKUP_ROOT.path_join("%s_%d" % [stamp, n])
		n += 1
	if DirAccess.make_dir_recursive_absolute(target_project_path.path_join(rel)) != OK:
		return ""
	return rel


func _write_file_abs(abs_path: String, bytes: PackedByteArray) -> bool:
	var dir_path: String = abs_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var mk_err: int = DirAccess.make_dir_recursive_absolute(dir_path)
		if mk_err != OK:
			push_error("[importer] could not mkdir %s (err=%d)" % [dir_path, mk_err])
			return false
	var f: FileAccess = FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		push_error("[importer] could not open %s for write (err=%d)" % [abs_path, FileAccess.get_open_error()])
		return false
	f.store_buffer(bytes)
	f.close()
	return true


func _apply_autoloads(cfg: ConfigFile, autoloads: Variant) -> int:
	if not (autoloads is Array):
		return 0
	var count: int = 0
	for a: Variant in autoloads:
		if not (a is Dictionary):
			continue
		var d: Dictionary = a
		var name: String = String(d.get("name", ""))
		var path: String = String(d.get("path", ""))
		var singleton: bool = bool(d.get("singleton", true))
		if name == "" or path == "":
			continue
		var value: String = ("*" if singleton else "") + path
		cfg.set_value("autoload", name, value)
		count += 1
	return count


func _apply_settings(cfg: ConfigFile, settings: Variant, warnings: Array) -> int:
	if not (settings is Array):
		return 0
	var count: int = 0
	for s: Variant in settings:
		if not (s is Dictionary):
			continue
		var d: Dictionary = s
		var key: String = String(d.get("key", ""))
		if key == "":
			continue
		var value: Variant = d.get("value")
		var policy: String = String(d.get("overwrite_policy", "warn"))
		var section: String = ""
		var leaf: String = ""
		var slash: int = key.find("/")
		if slash <= 0:
			# Settings without a namespace are rare but valid. Use a
			# synthetic "globals" section; ConfigFile requires both.
			section = "globals"
			leaf = key
		else:
			section = key.substr(0, slash)
			leaf = key.substr(slash + 1)

		var already: bool = cfg.has_section_key(section, leaf)
		if already and policy == "skip_if_exists":
			continue
		if already and policy == "warn":
			# We still write, but surface the warning so the Phase-4 dialog
			# can highlight it. Target value is now the source value.
			warnings.append(tr("The project setting {key} was replaced by the value from the package.").format({"key": key}))
		cfg.set_value(section, leaf, value)
		count += 1
	return count
