# plugin_scanner.gd — detects which editor plugins / GDExtensions the
# exported scene actually depends on.
#
# Who calls: manifest.gd during export.
# What it emits: Array[Dictionary] like
#   [{"name": "fmod",
#     "path": "res://addons/fmod/plugin.cfg",
#     "version_min": "6.0.0",
#     "install_hint": "Download from https://..."}]
#
# Detection strategy:
#   1. Enumerate enabled plugin.cfg paths from project.godot's
#      [editor_plugins].enabled array.
#   2. For every carried script / resource path in dep_paths, check if it
#      lives under res://addons/<addon>/. Any hit → that addon is required.
#   3. For every GDExtension declared in res://addons/<addon>/*.gdextension,
#      parse its class list. If any class is referenced by a carried scene
#      (scene_used_classes argument), the addon is required.
#
# Excludes scene_exporter itself — it's a dev-time editor tool, not a
# runtime dependency, so shipping a package that forces the target project
# to install our own plugin is wrong.
#
# Invariant: read-only scan. Never touches target project.

@tool
class_name SceneExporterPluginScanner
extends RefCounted


const _SELF_ADDON_DIR: String = "res://addons/scene_exporter"


func scan(
	project_godot_path: String,
	dep_paths: Array,
	scene_used_classes: Array[String],
) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var hit_addons: Dictionary = {}

	# --- 1. Addon dirs touched by any dep path ------------------------------
	for p: Variant in dep_paths:
		var addon: String = _addon_dir_for_path(String(p))
		if addon != "" and addon != _SELF_ADDON_DIR:
			hit_addons[addon] = true

	# --- 2. Addon dirs owning any custom class referenced by the scene ------
	var class_to_addon: Dictionary = _index_gdextension_classes()
	for cls: String in scene_used_classes:
		if class_to_addon.has(cls):
			var addon: String = class_to_addon[cls]
			if addon != _SELF_ADDON_DIR:
				hit_addons[addon] = true

	# --- 3. Emit plugin.cfg metadata for each hit addon ---------------------
	var enabled: Dictionary = _enabled_plugin_cfgs(project_godot_path)
	for addon_dir: String in hit_addons.keys():
		var cfg_path: String = addon_dir + "/plugin.cfg"
		if not FileAccess.file_exists(cfg_path):
			continue
		var entry: Dictionary = _read_plugin_cfg(cfg_path, addon_dir)
		entry["enabled_in_source"] = enabled.has(cfg_path)
		out.append(entry)

	return out


# --- Helpers -----------------------------------------------------------------

func _addon_dir_for_path(path: String) -> String:
	if not path.begins_with("res://addons/"):
		return ""
	# res://addons/<name>/foo/bar.gd → res://addons/<name>
	var after: String = path.trim_prefix("res://addons/")
	var slash: int = after.find("/")
	if slash <= 0:
		return ""
	return "res://addons/" + after.substr(0, slash)


func _enabled_plugin_cfgs(project_godot_path: String) -> Dictionary:
	var out: Dictionary = {}
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(project_godot_path) != OK:
		return out
	if not cfg.has_section_key("editor_plugins", "enabled"):
		return out
	var arr: Variant = cfg.get_value("editor_plugins", "enabled", PackedStringArray())
	if arr is PackedStringArray:
		for p: String in arr:
			out[p] = true
	return out


func _read_plugin_cfg(cfg_path: String, addon_dir: String) -> Dictionary:
	var cfg: ConfigFile = ConfigFile.new()
	var entry: Dictionary = {
		"name": addon_dir.get_file(),
		"path": cfg_path,
		"version": "",
		"description": "",
	}
	if cfg.load(cfg_path) != OK:
		return entry
	entry["name"] = String(cfg.get_value("plugin", "name", entry["name"]))
	entry["version"] = String(cfg.get_value("plugin", "version", ""))
	entry["description"] = String(cfg.get_value("plugin", "description", ""))
	return entry


func _index_gdextension_classes() -> Dictionary:
	# Map "ClassName" → "res://addons/<dir>". Scans every .gdextension file
	# under res://addons/. We parse a minimal subset of the format:
	#   [classes]
	#   SomeClass = "SomeClass"
	# or just an explicit list in the [general] section, varying by plugin.
	# We fall back to greping for lines that look like class identifiers.
	var out: Dictionary = {}
	var addons_root: String = "res://addons"
	if not DirAccess.dir_exists_absolute(addons_root):
		return out
	var dir: DirAccess = DirAccess.open(addons_root)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry not in [".", ".."] and dir.current_is_dir():
			var addon_dir: String = addons_root + "/" + entry
			for ext_path: String in _list_gdextension_files(addon_dir):
				for cls: String in _classes_in_gdextension(ext_path):
					out[cls] = addon_dir
		entry = dir.get_next()
	dir.list_dir_end()
	return out


func _list_gdextension_files(addon_dir: String) -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(addon_dir)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.get_extension().to_lower() == "gdextension":
			out.append(addon_dir + "/" + entry)
		entry = dir.get_next()
	dir.list_dir_end()
	return out


func _classes_in_gdextension(path: String) -> Array[String]:
	# Many gdextensions don't list their classes explicitly; the set is
	# registered at runtime. We do a best-effort scan for lines like
	#   class_name = "FmodEventEmitter2D"
	# or a [classes] section with one class per line. If neither is present
	# we return empty and fall back to the dep-path heuristic.
	var out: Array[String] = []
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var src: String = f.get_as_text()
	f.close()
	var re: RegEx = RegEx.new()
	if re.compile("class[\\s_]*name\\s*=\\s*\"([^\"]+)\"") != OK:
		return out
	var pos: int = 0
	while true:
		var m: RegExMatch = re.search(src, pos)
		if m == null:
			break
		out.append(m.get_string(1))
		pos = m.get_end()
	return out
