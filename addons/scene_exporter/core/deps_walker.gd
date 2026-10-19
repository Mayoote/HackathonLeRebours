# deps_walker.gd — recursive dependency resolver for the scene exporter.
#
# Who calls: exporter.gd, with the list of starting resource paths (typically
# just the root scene the user right-clicked).
#
# What it returns: a Dictionary keyed by res:// path. Each value is:
#   {
#     "kind": "resource" | "script" | "shader" | "shader_include",
#     "discovered_via": [ <path or "root"> ]  # for debugging / warning context
#   }
#
# Strategy:
#   1. BFS over ResourceLoader.get_dependencies() for classic resources.
#   2. For every .gd discovered (either as a script dep of a scene/resource
#      OR as a load() target), run ScriptScanner and enqueue any literal
#      load paths. Also collect dynamic-load warnings and settings refs.
#   3. For every .gdshader / .gdshaderinc discovered, run ShaderScanner and
#      enqueue #include targets.
#   4. Stop when no new paths are found in a full iteration.
#
# Invariant: the walker never writes to disk or opens the network. It only
# reads files in the project via FileAccess / ResourceLoader. This keeps
# it safe to call from headless contexts and from tests.

@tool
class_name SceneExporterDepsWalker
extends RefCounted


const ScriptScanner := preload("res://addons/scene_exporter/core/script_scanner.gd")
const ShaderScanner := preload("res://addons/scene_exporter/core/shader_scanner.gd")


var _script_scanner: RefCounted = ScriptScanner.new()
var _shader_scanner: RefCounted = ShaderScanner.new()

# Aggregated side-output collected over the whole walk.
var dynamic_load_warnings: Array[Dictionary] = []
var referenced_settings: Array[String] = []


func walk(starting_paths: Array) -> Dictionary:
	var resolved: Dictionary = {}
	var queue: Array[String] = []
	for p: Variant in starting_paths:
		var s: String = String(p)
		if s == "" or resolved.has(s):
			continue
		queue.append(s)
		resolved[s] = _make_entry(s, "root")

	while not queue.is_empty():
		var path: String = queue.pop_front()
		var ext: String = path.get_extension().to_lower()
		var discoveries: Array[String] = []

		if ext == "gd":
			discoveries = _scan_script(path)
		elif ext == "gdshader" or ext == "gdshaderinc":
			discoveries = _scan_shader(path)
		else:
			# Everything else goes through ResourceLoader's dependency graph,
			# which handles .tscn → sub-scene, .tres → sub-.tres, textures,
			# audio streams, fonts, shaders referenced by materials, etc.
			discoveries = _resource_deps(path)

		for dep_path: String in discoveries:
			if dep_path == "" or resolved.has(dep_path):
				continue
			resolved[dep_path] = _make_entry(dep_path, path)
			queue.append(dep_path)

	return resolved


# --- Strategy helpers --------------------------------------------------------

func _resource_deps(path: String) -> Array[String]:
	# ResourceLoader returns strings like "<uid>::<type>::<res_path>". We
	# want the res_path — the last :: slice.
	var raw: PackedStringArray = ResourceLoader.get_dependencies(path)
	var out: Array[String] = []
	for entry: String in raw:
		var res_path: String = _extract_path_from_dep(entry)
		if res_path == "":
			continue
		if res_path == path:
			continue
		out.append(res_path)
	return out


func _extract_path_from_dep(entry: String) -> String:
	# Examples seen:
	#   uid://xyz::PackedScene::res://scenes/enemy.tscn
	#   res://art/player.png (some older Godot builds)
	if entry.begins_with("res://"):
		return entry
	var parts: PackedStringArray = entry.split("::")
	if parts.size() == 0:
		return ""
	var last: String = parts[parts.size() - 1]
	if last.begins_with("res://"):
		return last
	# Fallback: sometimes the path is in slot 2.
	if parts.size() >= 3 and parts[2].begins_with("res://"):
		return parts[2]
	return ""


func _scan_script(path: String) -> Array[String]:
	var r: Dictionary = _script_scanner.scan(path)
	for w: Dictionary in r.dynamic:
		dynamic_load_warnings.append(w)
	for key: String in r.settings:
		if not referenced_settings.has(key):
			referenced_settings.append(key)
	# Only the literal load targets enter the dep graph.
	var loads: Array[String] = []
	for p: String in r.loads:
		loads.append(p)
	return loads


func _scan_shader(path: String) -> Array[String]:
	return _shader_scanner.scan(path)


func _make_entry(path: String, via: String) -> Dictionary:
	return {
		"kind": _classify(path),
		"discovered_via": [via],
	}


func _classify(path: String) -> String:
	match path.get_extension().to_lower():
		"gd":
			return "script"
		"gdshader":
			return "shader"
		"gdshaderinc":
			return "shader_include"
		_:
			return "resource"
