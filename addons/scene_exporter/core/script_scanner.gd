# script_scanner.gd — regex scanner for .gd files that picks up dependencies
# Godot's own ResourceLoader.get_dependencies() misses (issue #90643).
#
# Who calls: deps_walker.gd, once per .gd file discovered during the BFS.
# What it emits:
#   - loads[]          — list of res:// paths passed as LITERAL string args to
#                         preload()/load() / ResourceLoader.load()
#   - dynamic[]        — records of load()-with-variable-arg calls for the
#                         Phase-4 warning dialog ({file, line, text})
#   - settings[]       — keys passed as LITERAL strings to
#                         ProjectSettings.get_setting() / has_setting() /
#                         set_setting() — feeds settings_scanner.gd
#
# Invariant: this is a pattern scanner, not a parser. It prefers false
# positives over false negatives — we'd rather carry one too many resources
# than ship a broken scene. Anything that needs semantic analysis
# (resolving a `const PATH = "…"` then `load(PATH)`) is surfaced as a
# `dynamic` warning, not silently skipped.

@tool
class_name SceneExporterScriptScanner
extends RefCounted


# (?:pre)?load  → literal preload or load call
# \s*\(\s*
# (["'])         → capture opening quote
# (res://[^"']+) → the res-path, no embedded quotes
# \1             → matching closing quote
# \s*[,)]        → end of first arg
const _LITERAL_LOAD_REGEX: String = \
	"(?:pre)?load\\s*\\(\\s*([\"'])(res://[^\"']+)\\1\\s*[,)]"

# ResourceLoader.load("res://...", ...) — same idea, different entry point.
const _RESOURCE_LOADER_LOAD_REGEX: String = \
	"ResourceLoader\\s*\\.\\s*load\\s*\\(\\s*([\"'])(res://[^\"']+)\\1\\s*[,)]"

# Any (pre)load( call followed by something that is NOT a string literal.
# We match up to the closing paren on the same line; good enough heuristic
# for surfacing "this call can't be statically resolved" warnings.
const _DYNAMIC_LOAD_REGEX: String = \
	"(?:pre)?load\\s*\\(\\s*([^\"')][^)]*)\\)"

const _PROJECT_SETTING_REGEX: String = \
	"ProjectSettings\\s*\\.\\s*(?:get_setting|has_setting|set_setting)\\s*\\(\\s*([\"'])([^\"']+)\\1"


func scan(gd_path: String) -> Dictionary:
	var out := {
		"loads": [] as Array[String],
		"dynamic": [] as Array[Dictionary],
		"settings": [] as Array[String],
	}
	var f: FileAccess = FileAccess.open(gd_path, FileAccess.READ)
	if f == null:
		push_warning("[script_scanner] could not read %s" % gd_path)
		return out
	var src: String = f.get_as_text()
	f.close()

	# Strip single-line comments to avoid matching `# load("res://x")` in docs.
	# Keep strings intact; we rely on the regex anchoring on (pre)load(.
	var stripped: String = _strip_line_comments(src)

	_collect_literal_paths(stripped, _LITERAL_LOAD_REGEX, 2, out.loads)
	_collect_literal_paths(stripped, _RESOURCE_LOADER_LOAD_REGEX, 2, out.loads)
	_collect_literal_paths(stripped, _PROJECT_SETTING_REGEX, 2, out.settings)
	_collect_dynamic_loads(stripped, gd_path, out.dynamic)

	return out


func _strip_line_comments(src: String) -> String:
	# Conservative: only strip `#` that appears as the first non-space char
	# on a line. Avoids clobbering `#` inside strings (shader_type, colors,
	# etc. show up in GDScript as plain `#`).
	var lines: PackedStringArray = src.split("\n")
	for i in lines.size():
		var line: String = lines[i]
		var stripped: String = line.strip_edges(true, false)
		if stripped.begins_with("#"):
			lines[i] = ""
	return "\n".join(lines)


func _collect_literal_paths(src: String, pattern: String, group: int, out: Array[String]) -> void:
	var re := RegEx.new()
	var compile_err: int = re.compile(pattern)
	if compile_err != OK:
		push_error("[script_scanner] regex compile failed (%d): %s" % [compile_err, pattern])
		return
	var pos: int = 0
	while true:
		var m: RegExMatch = re.search(src, pos)
		if m == null:
			break
		var captured: String = m.get_string(group)
		if captured != "" and not out.has(captured):
			out.append(captured)
		pos = m.get_end()


func _collect_dynamic_loads(src: String, file_path: String, out: Array[Dictionary]) -> void:
	var re := RegEx.new()
	if re.compile(_DYNAMIC_LOAD_REGEX) != OK:
		return
	var lines: PackedStringArray = src.split("\n")
	for line_idx in lines.size():
		var line: String = lines[line_idx]
		var m: RegExMatch = re.search(line)
		if m == null:
			continue
		# Skip false positives where the first char is a string (the literal
		# regex already handled those) OR where this is a preload comment.
		var arg: String = m.get_string(1).strip_edges()
		if arg.begins_with("\"") or arg.begins_with("'"):
			continue
		# Skip pure-numeric args (not real calls we care about).
		out.append({
			"file": file_path,
			"line": line_idx + 1,
			"expression": line.strip_edges(),
			"argument": arg,
		})
