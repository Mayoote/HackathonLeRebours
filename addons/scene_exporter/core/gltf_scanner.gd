# gltf_scanner.gd — finds external buddy files referenced by a .gltf.
#
# Why this exists: .gltf is a JSON document that references its binary
# geometry (`.bin`) and, optionally, textures via external URIs. Those
# buddies are plain files — not Godot Resources — so they don't appear in
# `ResourceLoader.get_dependencies()` and the dep walker misses them.
# Without this scanner we ship the .gltf stripped of its geometry and the
# target project can't import the model.
#
# Who calls: core/exporter.gd during plan(), right after the dep walk.
#
# Scope: URIs that resolve to local files only. data: URIs are skipped
# (they're embedded, no file to ship). http(s): URIs produce a warning —
# shipping a portable package of a net-dependent asset is out of scope.
# .glb is intentionally NOT scanned: it's a self-contained binary container.

@tool
class_name SceneExporterGltfScanner
extends RefCounted


# Returns Dictionary { buddies: Array[String], warnings: Array[String] }.
# `buddies` are res:// absolute paths (unique, present on disk unchecked).
# Caller is responsible for FileAccess.file_exists() before adding to the
# package — this function only parses the JSON.
static func scan(gltf_res_path: String) -> Dictionary:
	var result: Dictionary = {
		"buddies": [] as Array[String],
		"warnings": [] as Array[String],
	}

	var text: String = _read_text(gltf_res_path)
	if text.is_empty():
		return result

	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		# Malformed gltf — not our job to validate; the target project will
		# error out the same way the source did. Move on.
		return result

	var doc: Dictionary = parsed
	var base_dir: String = gltf_res_path.get_base_dir()
	var seen: Dictionary = {}

	# Both buffers[] and images[] use the same "uri" field per glTF 2.0 spec.
	# Extension objects can also carry URIs but those are rare; skip for now
	# and let Phase 6 widen coverage if a real project trips on it.
	for section_name: String in ["buffers", "images"]:
		var section: Variant = doc.get(section_name)
		if not (section is Array):
			continue
		for entry: Variant in (section as Array):
			if not (entry is Dictionary):
				continue
			var uri_raw: Variant = (entry as Dictionary).get("uri", "")
			if not (uri_raw is String):
				continue
			var uri: String = (uri_raw as String).strip_edges()
			if uri.is_empty():
				continue
			if uri.begins_with("data:"):
				# Embedded payload — nothing to ship.
				continue
			if uri.begins_with("http://") or uri.begins_with("https://"):
				result.warnings.append(
					TranslationServer.translate(
						"{gltf} references a remote URI ({uri}); remote assets are not packaged."
					).format({"gltf": gltf_res_path, "uri": uri})
				)
				continue

			var resolved: String = _resolve_relative(base_dir, uri)
			if seen.has(resolved):
				continue
			seen[resolved] = true
			(result.buddies as Array[String]).append(resolved)

	return result


static func _read_text(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var t: String = f.get_as_text()
	f.close()
	return t


# Joins `base_dir` (a res:// absolute path to a directory, no trailing slash)
# with `rel` (a URI-encoded relative path). Decodes the URI so paths like
# "textures/diff%20map.png" map back to "textures/diff map.png".
static func _resolve_relative(base_dir: String, rel: String) -> String:
	var decoded: String = rel.uri_decode()
	# Normalize Windows separators just in case the gltf was authored on one.
	decoded = decoded.replace("\\", "/")
	if decoded.begins_with("/"):
		decoded = decoded.substr(1)
	var joined: String = base_dir.path_join(decoded)
	return joined.simplify_path()
