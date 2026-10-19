# export_dialog.gd — preview shown before the exporter writes the zip.
#
# Who instantiates: ui/export_flow.gd after the user picks an output path.
# What it shows:
#   - The starting scene + every discovered dependency (read-only list so
#     the user can inspect what's going into the package).
#   - Autoloads, required plugins, and project settings with per-row
#     checkboxes — unchecking means "don't include this in the package".
#     Files are not unchecking-editable: removing a dep would break the
#     scene on import.
#   - Any dynamic-load warnings surfaced by the walker.
#
# Lifecycle:
#   1. new(plan). Populates the tree from the exporter's plan Dictionary.
#   2. popup_centered(). Shown by the flow.
#   3. confirmed → emit export_confirmed(modified_plan) where the plan has
#      the user's exclusions applied. Cancelled → emit canceled.
#
# Never does IO of its own. The real write happens in exporter.write()
# triggered by the flow once this dialog emits export_confirmed.

@tool
class_name SceneExporterExportDialog
extends ConfirmationDialog


signal export_confirmed(plan: Dictionary)


# Keep the original plan and the mutable checkbox state in parallel;
# _finalized_plan() rebuilds a copy with excluded items dropped.
var _plan: Dictionary
var _tree: Tree
var _summary_label: Label
var _warnings_label: RichTextLabel

# TreeItem → "autoloads" | "plugins" | "settings" | "files" and the index
# into the matching plan array. Used when the user toggles a checkbox.
var _item_kind: Dictionary = {}
var _item_index: Dictionary = {}


func _init(plan: Dictionary) -> void:
	_plan = plan

	title = tr("Export Scene Package")
	ok_button_text = tr("Export")
	cancel_button_text = tr("Cancel")
	min_size = Vector2i(680, 520)

	var root: VBoxContainer = VBoxContainer.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	add_child(root)

	_summary_label = Label.new()
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_summary_label)

	_tree = Tree.new()
	_tree.columns = 2
	_tree.column_titles_visible = false
	_tree.set_column_expand(0, true)
	_tree.set_column_expand(1, false)
	_tree.set_column_custom_minimum_width(1, 160)
	_tree.hide_root = true
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.item_edited.connect(_on_item_edited)
	root.add_child(_tree)

	_warnings_label = RichTextLabel.new()
	_warnings_label.bbcode_enabled = true
	_warnings_label.fit_content = true
	_warnings_label.custom_minimum_size = Vector2(0, 60)
	root.add_child(_warnings_label)

	confirmed.connect(_on_confirmed)

	_render()


func _render() -> void:
	_summary_label.text = _summary_text()
	_tree.clear()
	_item_kind.clear()
	_item_index.clear()

	var root: TreeItem = _tree.create_item()

	_render_files(root)
	_render_checkable_section(root, tr("Autoloads"), _plan.get("required_autoloads", []),
		"autoloads", func(e: Dictionary) -> String:
			return "%s → %s" % [e.get("name", "?"), e.get("path", "?")]
	)
	_render_checkable_section(root, tr("Required plugins"), _plan.get("required_plugins", []),
		"plugins", func(e: Dictionary) -> String:
			var v: String = String(e.get("version", ""))
			if v != "":
				return "%s  (%s)  v%s" % [e.get("name", "?"), e.get("path", "?"), v]
			return "%s  (%s)" % [e.get("name", "?"), e.get("path", "?")]
	)
	_render_checkable_section(root, tr("Project settings"), _plan.get("required_settings", []),
		"settings", func(e: Dictionary) -> String:
			return "%s = %s" % [e.get("key", "?"), str(e.get("value", ""))]
	)

	_render_warnings()


func _render_files(root: TreeItem) -> void:
	var entries: Array = _plan.get("file_entries", [])
	var heading: TreeItem = _tree.create_item(root)
	heading.set_text(0, tr("Files ({count})").format({"count": entries.size()}))
	heading.set_selectable(0, false)
	heading.set_selectable(1, false)
	heading.set_custom_color(0, Color(0.85, 0.85, 0.95))
	for raw: Variant in entries:
		if not (raw is Dictionary):
			continue
		var e: Dictionary = raw
		var leaf: TreeItem = _tree.create_item(heading)
		var size_kb: float = float(e.get("size", 0)) / 1024.0
		leaf.set_text(0, "%s  (%.1f KB)" % [e.get("path", "?"), size_kb])
		leaf.set_text(1, String(e.get("kind", "")))
		leaf.set_custom_color(1, Color(0.7, 0.7, 0.7))
		leaf.set_selectable(0, false)
		leaf.set_selectable(1, false)


func _render_checkable_section(root: TreeItem, heading: String, entries: Array, kind: String, describe: Callable) -> void:
	if entries == null or entries.is_empty():
		return
	var section: TreeItem = _tree.create_item(root)
	section.set_text(0, heading)
	section.set_selectable(0, false)
	section.set_selectable(1, false)
	section.set_custom_color(0, Color(0.85, 0.85, 0.95))
	var i: int = 0
	for raw: Variant in entries:
		if not (raw is Dictionary):
			i += 1
			continue
		var e: Dictionary = raw
		var leaf: TreeItem = _tree.create_item(section)
		leaf.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		leaf.set_checked(0, true)
		leaf.set_editable(0, true)
		leaf.set_text(0, describe.call(e))
		leaf.set_text(1, tr("Included"))
		leaf.set_custom_color(1, Color(0.55, 0.9, 0.55))
		_item_kind[leaf] = kind
		_item_index[leaf] = i
		i += 1


func _on_item_edited() -> void:
	var item: TreeItem = _tree.get_edited()
	if item == null or not _item_kind.has(item):
		return
	if item.is_checked(0):
		item.set_text(1, tr("Included"))
		item.set_custom_color(1, Color(0.55, 0.9, 0.55))
	else:
		item.set_text(1, tr("Excluded"))
		item.set_custom_color(1, Color(0.7, 0.7, 0.7))


func _render_warnings() -> void:
	_warnings_label.clear()
	var warnings: Array = _plan.get("dynamic_load_warnings", [])
	if warnings.is_empty():
		return
	_warnings_label.append_text("[b]%s:[/b]\n" % tr("Heads up"))
	for w: Dictionary in warnings:
		_warnings_label.append_text("  • %s\n" % tr("Dynamic load() at {file}:{line} — {arg} cannot be followed automatically.").format({
			"file": w.get("file", "?"),
			"line": w.get("line", 0),
			"arg": w.get("argument", ""),
		}))


func _summary_text() -> String:
	var n_files: int = int(_plan.get("file_entries", []).size())
	var n_auto: int = int(_plan.get("required_autoloads", []).size())
	var n_plug: int = int(_plan.get("required_plugins", []).size())
	var n_set: int = int(_plan.get("required_settings", []).size())
	return tr("{scene}: {files} files, {autoloads} autoloads, {plugins} plugins, {settings} settings. Uncheck items below to exclude them.").format({
		"scene": String(_plan.get("scene_path", "")).get_file(),
		"files": n_files,
		"autoloads": n_auto,
		"plugins": n_plug,
		"settings": n_set,
	})


func _on_confirmed() -> void:
	export_confirmed.emit(_finalized_plan())


func _finalized_plan() -> Dictionary:
	# Build a deep copy that excludes items the user unchecked. Files are
	# never excluded — they're deps of the scene.
	var out: Dictionary = _plan.duplicate(true)
	var keep_by_kind: Dictionary = {
		"autoloads": _collect_kept("autoloads"),
		"plugins": _collect_kept("plugins"),
		"settings": _collect_kept("settings"),
	}
	out.required_autoloads = _filter_by_indices(out.get("required_autoloads", []), keep_by_kind.autoloads)
	out.required_plugins = _filter_by_indices(out.get("required_plugins", []), keep_by_kind.plugins)
	out.required_settings = _filter_by_indices(out.get("required_settings", []), keep_by_kind.settings)
	return out


func _collect_kept(kind: String) -> Dictionary:
	var kept: Dictionary = {}
	for item: Variant in _item_kind.keys():
		var ti: TreeItem = item
		if _item_kind[ti] == kind and ti.is_checked(0):
			kept[_item_index[ti]] = true
	return kept


func _filter_by_indices(source: Array, kept: Dictionary) -> Array:
	var out: Array = []
	for i: int in range(source.size()):
		if kept.has(i):
			out.append(source[i])
	return out
