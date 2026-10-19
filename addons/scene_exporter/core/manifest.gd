# manifest.gd — builds and validates the package.json manifest.
#
# Who calls: exporter.gd during export; importer.gd during import.
# What it produces: a Dictionary that serializes to the package.json schema
# documented in PLAN.md §1.
#
# The manifest is the contract between export and import. The importer trusts
# ONLY what's here — it does not re-scan the zip or guess at dependencies.

@tool
class_name SceneExporterManifest
extends RefCounted


const FORMAT_VERSION: int = 1
const PLUGIN_NAME: String = "scene_exporter"
const PLUGIN_VERSION: String = "0.1.1"


static func build(
	scene_path: String,
	file_list: Array[String],
	dynamic_load_warnings: Array,
	referenced_settings: Array,
	required_autoloads: Array,
	required_plugins: Array,
	required_settings: Array,
) -> Dictionary:
	var warnings: Array[String] = []
	for raw_w: Variant in dynamic_load_warnings:
		if not (raw_w is Dictionary):
			continue
		var w: Dictionary = raw_w
		warnings.append(
			"Dynamic load() in %s:%d — verify the resource is present (arg: %s)"
			% [w.file, w.line, w.argument]
		)

	var files_entries: Array = []
	for p: String in file_list:
		files_entries.append(_describe_file(p))

	return {
		"format_version": FORMAT_VERSION,
		"created_by": "%s %s" % [PLUGIN_NAME, PLUGIN_VERSION],
		"created_at": Time.get_datetime_string_from_system(true),
		"godot_version": Engine.get_version_info().get("string", "unknown"),
		"root_scene": scene_path,
		"required_plugins": required_plugins,
		"required_autoloads": required_autoloads,
		"required_project_settings": required_settings,
		"files": files_entries,
		"warnings": warnings,
		"referenced_settings": referenced_settings.duplicate(),
	}


# --- File description --------------------------------------------------------

static func _describe_file(path: String) -> Dictionary:
	var size: int = _file_size(path)
	return {
		"path": path,
		"size": size,
		"sha256": _sha256(path),
		"kind": _kind_for(path),
	}


static func _file_size(path: String) -> int:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var n: int = f.get_length()
	f.close()
	return n


static func _sha256(path: String) -> String:
	# FileAccess.get_sha256(path) is available in 4.3+; returns empty string
	# on failure, which is what we want as a fallback in the manifest.
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_sha256(path)


static func _kind_for(path: String) -> String:
	var ext: String = path.get_extension().to_lower()
	if ext in ["import", "uid"]:
		return "resource_sidecar"
	if ext in ["tscn", "scn", "tres", "res", "gd", "gdshader", "gdshaderinc",
			"png", "jpg", "jpeg", "svg", "webp",
			"ogg", "wav", "mp3",
			"ttf", "otf", "fnt"]:
		return "resource"
	return "opaque_binary"
