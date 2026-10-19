# exporter.gd — orchestrates export: walks deps, runs scanners, assembles
# the manifest, writes the ZIP.
#
# Two-phase API so the UI can preview before writing:
#   1. plan(scene_path) -> Dictionary
#        Runs every read-only step (dep walk, scanners, manifest build)
#        and returns a plan the UI can display and the user can mutate
#        (e.g. uncheck optional autoloads). No files are touched.
#   2. write(plan, output_zip) -> Dictionary
#        Takes a (possibly mutated) plan and produces the zip. Emits
#        `progress(current, total, label)` per file so an observer (UI
#        progress panel, test logger) can track state. Synchronous —
#        the write loop is fast enough that mid-op UI ticks aren't
#        worth the complexity of a coroutine API.
#
# The legacy single-shot entry point export_scene() is kept as a thin
# wrapper for callers that don't need the preview step (e.g. CI).
#
# Invariant: never writes outside the requested output_zip path.

@tool
class_name SceneExporterExporter
extends RefCounted


const DepsWalker := preload("res://addons/scene_exporter/core/deps_walker.gd")
const AutoloadScanner := preload("res://addons/scene_exporter/core/autoload_scanner.gd")
const PluginScanner := preload("res://addons/scene_exporter/core/plugin_scanner.gd")
const SettingsScanner := preload("res://addons/scene_exporter/core/settings_scanner.gd")
const Manifest := preload("res://addons/scene_exporter/core/manifest.gd")
const GltfScanner := preload("res://addons/scene_exporter/core/gltf_scanner.gd")

# File extensions we skip explicitly even if they're adjacent to a resource.
const _SKIP_EXTENSIONS: Array = []

# Script-like resources store their UID in an external .uid sidecar. Without
# it, the target project generates a fresh UID on import and every
# `uid://...` reference in a scene goes stale. Resources with embedded UIDs
# (.tscn/.tres) don't have or need sidecars.
const _UID_SIDECAR_EXTENSIONS: Array = ["gd", "gdshader", "gdshaderinc"]

const _PROJECT_GODOT: String = "res://project.godot"

# Emitted per file during write(). `current` is 1-based; `total` is the
# final count (includes the manifest entry).
signal progress(current: int, total: int, label: String)


# --- Phase 1: plan ---------------------------------------------------------

func plan(scene_path: String) -> Dictionary:
	var plan_out: Dictionary = {
		"scene_path": scene_path,
		"file_list": [] as Array[String],
		"file_entries": [] as Array[Dictionary],
		"required_autoloads": [] as Array[Dictionary],
		"required_plugins": [] as Array[Dictionary],
		"required_settings": [] as Array[Dictionary],
		"dynamic_load_warnings": [] as Array[Dictionary],
		"warnings": [] as Array[String],
		"errors": [] as Array[String],
	}

	if not FileAccess.file_exists(scene_path):
		plan_out.errors.append(tr("Could not find the scene at {path}.").format({"path": scene_path}))
		return plan_out

	# --- Walk deps -----------------------------------------------------------
	var walker: SceneExporterDepsWalker = DepsWalker.new()
	var deps: Dictionary = walker.walk([scene_path])

	# --- Resolve file list including .import sidecars -----------------------
	var file_list: Array[String] = []
	for p: String in deps.keys():
		if _should_skip(p):
			continue
		if not FileAccess.file_exists(p):
			plan_out.warnings.append(tr("Expected dependency {path} is not on disk — it'll be skipped.").format({"path": p}))
			continue
		file_list.append(p)
		var import_path: String = p + ".import"
		if FileAccess.file_exists(import_path):
			file_list.append(import_path)
		if p.get_extension().to_lower() in _UID_SIDECAR_EXTENSIONS:
			var uid_path: String = p + ".uid"
			if FileAccess.file_exists(uid_path):
				file_list.append(uid_path)

	# --- Scan .gltf for external buddy files (.bin, referenced textures) ----
	# Godot's dep graph treats .gltf as one node and misses raw-binary
	# siblings. Shipping the .gltf without its .bin produces a permanently
	# broken model in the target project.
	var already_in_list: Dictionary = {}
	for p: String in file_list:
		already_in_list[p] = true
	var gltf_sources: Array[String] = []
	for p: String in file_list:
		if p.get_extension().to_lower() == "gltf":
			gltf_sources.append(p)
	for gltf_path: String in gltf_sources:
		var scan_result: Dictionary = GltfScanner.scan(gltf_path)
		for w: String in scan_result.warnings:
			plan_out.warnings.append(w)
		for buddy: String in scan_result.buddies:
			if already_in_list.has(buddy):
				continue
			if not FileAccess.file_exists(buddy):
				plan_out.warnings.append(
					tr("{gltf} references {file} but that file is missing on disk — skipping.").format(
						{"gltf": gltf_path, "file": buddy}
					)
				)
				continue
			file_list.append(buddy)
			already_in_list[buddy] = true
			var buddy_import: String = buddy + ".import"
			if FileAccess.file_exists(buddy_import) and not already_in_list.has(buddy_import):
				file_list.append(buddy_import)
				already_in_list[buddy_import] = true

	file_list.sort()

	# --- Run scanners --------------------------------------------------------
	var carried_scripts: Array[String] = []
	for p: String in file_list:
		if p.get_extension().to_lower() == "gd":
			carried_scripts.append(p)
	var script_sources: Array[String] = _load_script_sources(carried_scripts)
	var scene_classes: Array[String] = _collect_scene_classes(scene_path)

	var autoload_scanner: SceneExporterAutoloadScanner = AutoloadScanner.new()
	var plugin_scanner: SceneExporterPluginScanner = PluginScanner.new()
	var settings_scanner: SceneExporterSettingsScanner = SettingsScanner.new()

	var required_autoloads: Array[Dictionary] = autoload_scanner.scan(
		_PROJECT_GODOT, deps.keys(), script_sources
	)
	var required_plugins: Array[Dictionary] = plugin_scanner.scan(
		_PROJECT_GODOT, deps.keys(), scene_classes
	)
	var required_settings: Array[Dictionary] = settings_scanner.scan(walker.referenced_settings)

	# Autoload scripts themselves must also travel. Add any we didn't
	# already pick up via walker dep set.
	for entry: Dictionary in required_autoloads:
		var p: String = entry.path
		if p != "" and not file_list.has(p) and FileAccess.file_exists(p):
			file_list.append(p)
			var import_path: String = p + ".import"
			if FileAccess.file_exists(import_path):
				file_list.append(import_path)
	file_list.sort()

	# --- File entries (path + size + kind) for UI preview -------------------
	var file_entries: Array[Dictionary] = []
	for p: String in file_list:
		file_entries.append({
			"path": p,
			"size": FileAccess.get_file_as_bytes(p).size() if FileAccess.file_exists(p) else 0,
			"kind": _classify_file(p, deps),
		})

	plan_out.file_list = file_list
	plan_out.file_entries = file_entries
	plan_out.required_autoloads = required_autoloads
	plan_out.required_plugins = required_plugins
	plan_out.required_settings = required_settings
	plan_out.dynamic_load_warnings = walker.dynamic_load_warnings.duplicate()
	return plan_out


# --- Phase 2: write --------------------------------------------------------

func write(plan_in: Dictionary, output_zip_path: String) -> Dictionary:
	var report: Dictionary = {
		"ok": false,
		"zip_path": output_zip_path,
		"files_written": 0,
		"warnings": [] as Array[String],
		"errors": [] as Array[String],
	}
	for w: String in plan_in.get("warnings", []):
		report.warnings.append(w)

	if not plan_in.get("errors", []).is_empty():
		for e: String in plan_in.errors:
			report.errors.append(e)
		return report

	var file_list: Array = plan_in.get("file_list", [])
	var referenced_settings_from_plan: Array = []
	for s: Dictionary in plan_in.get("required_settings", []):
		referenced_settings_from_plan.append(String(s.get("key", "")))
	var manifest: Dictionary = Manifest.build(
		String(plan_in.get("scene_path", "")),
		_as_string_array(file_list),
		plan_in.get("dynamic_load_warnings", []),
		referenced_settings_from_plan,
		plan_in.get("required_autoloads", []),
		plan_in.get("required_plugins", []),
		plan_in.get("required_settings", []),
	)

	var packer: ZIPPacker = ZIPPacker.new()
	var open_err: int = packer.open(output_zip_path)
	if open_err != OK:
		report.errors.append(tr("Could not create the package at {path}. Check the folder is writable.").format(
			{"path": output_zip_path}
		))
		return report

	var total: int = file_list.size() + 1  # +1 for the manifest entry
	var idx: int = 0

	progress.emit(idx + 1, total, "package.json")
	_write_entry_to_zip(packer, "package.json", JSON.stringify(manifest, "  ").to_utf8_buffer())
	idx += 1

	for p: String in file_list:
		progress.emit(idx + 1, total, p.get_file())
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(p)
		if bytes.size() == 0 and FileAccess.get_open_error() != OK:
			report.warnings.append(tr("Could not read {path} — skipped.").format({"path": p}))
			idx += 1
			continue
		var zip_entry_path: String = "files/" + p.trim_prefix("res://")
		_write_entry_to_zip(packer, zip_entry_path, bytes)
		report.files_written += 1
		idx += 1

	packer.close()

	for w: Dictionary in plan_in.get("dynamic_load_warnings", []):
		report.warnings.append(
			tr(
				"Dynamic load() at {file}:{line} — {argument} cannot be followed automatically."
				+ " Double-check it works in the target project."
			).format({"file": w.file, "line": w.line, "argument": w.argument})
		)

	report.ok = report.errors.is_empty()
	return report


# --- Legacy single-shot entry (kept for CI / run_export.gd) ---------------

func export_scene(scene_path: String, output_zip_path: String) -> Dictionary:
	var plan_out: Dictionary = plan(scene_path)
	return write(plan_out, output_zip_path)


# --- Private ---------------------------------------------------------------

func _should_skip(path: String) -> bool:
	var ext: String = path.get_extension().to_lower()
	return _SKIP_EXTENSIONS.has(ext)


func _write_entry_to_zip(packer: ZIPPacker, entry_path: String, bytes: PackedByteArray) -> void:
	var start_err: int = packer.start_file(entry_path)
	if start_err != OK:
		push_error("[exporter] ZIPPacker.start_file(%s) failed: %d" % [entry_path, start_err])
		return
	var write_err: int = packer.write_file(bytes)
	if write_err != OK:
		push_error("[exporter] ZIPPacker.write_file(%s) failed: %d" % [entry_path, write_err])
	var close_err: int = packer.close_file()
	if close_err != OK:
		push_error("[exporter] ZIPPacker.close_file(%s) failed: %d" % [entry_path, close_err])


func _load_script_sources(script_paths: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for p: String in script_paths:
		var f: FileAccess = FileAccess.open(p, FileAccess.READ)
		if f == null:
			continue
		out.append(f.get_as_text())
		f.close()
	return out


func _collect_scene_classes(scene_path: String) -> Array[String]:
	var out: Array[String] = []
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		return out
	var root: Node = packed.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	if root == null:
		return out
	var seen: Dictionary = {}
	_visit_node_classes(root, seen)
	root.queue_free()
	var typed: Array[String] = []
	for k: Variant in seen.keys():
		typed.append(String(k))
	return typed


func _visit_node_classes(node: Node, seen: Dictionary) -> void:
	var cls: String = node.get_class()
	if cls != "":
		seen[cls] = true
	for c: Node in node.get_children():
		_visit_node_classes(c, seen)


func _classify_file(path: String, deps: Dictionary) -> String:
	var info: Variant = deps.get(path)
	if info is Dictionary and info.has("kind"):
		return String(info.kind)
	match path.get_extension().to_lower():
		"gd": return "script"
		"gdshader", "gdshaderinc": return "shader"
		"tscn", "scn": return "scene"
		"tres", "res": return "resource"
		"import": return "import_sidecar"
		_: return "asset"


func _as_string_array(arr: Array) -> Array[String]:
	var out: Array[String] = []
	for e: Variant in arr:
		out.append(String(e))
	return out


