# shader_scanner.gd — regex scanner for .gdshader / .gdshaderinc files.
# Godot tracks no dependencies for shader includes; we must do it manually.
#
# Who calls: deps_walker.gd, once per shader file discovered during the BFS.
# What it emits: `includes[]` — res:// paths mentioned via `#include "..."`.
#
# Recursion: .gdshaderinc can itself `#include "res://..."`, so the walker
# feeds every included file back through scan() until nothing new appears.
#
# Invariant: only absolute res:// includes are tracked. GLSL-style relative
# includes are not supported by Godot's shader compiler in 4.6, so we
# don't pretend to handle them.

@tool
class_name SceneExporterShaderScanner
extends RefCounted


const _INCLUDE_REGEX: String = "#\\s*include\\s+\"(res://[^\"]+)\""


func scan(shader_path: String) -> Array[String]:
	var out: Array[String] = []
	var f: FileAccess = FileAccess.open(shader_path, FileAccess.READ)
	if f == null:
		push_warning("[shader_scanner] could not read %s" % shader_path)
		return out
	var src: String = f.get_as_text()
	f.close()

	var re := RegEx.new()
	if re.compile(_INCLUDE_REGEX) != OK:
		push_error("[shader_scanner] regex compile failed")
		return out

	var pos: int = 0
	while true:
		var m: RegExMatch = re.search(src, pos)
		if m == null:
			break
		var include_path: String = m.get_string(1)
		if include_path != "" and not out.has(include_path):
			out.append(include_path)
		pos = m.get_end()
	return out
