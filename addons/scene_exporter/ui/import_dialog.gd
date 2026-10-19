# import_dialog.gd — modal shown to the user before writing anything to the
# target project during an import.
#
# Who instantiates: ui/import_flow.gd after the user picks a .zip.
# Lifecycle:
#   1. new(zip_abs_path). Runs preflight. Populates the tree.
#   2. show_in_editor(). Shows the dialog.
#   3. confirmed signal → run importer.import_package() → emit
#      import_complete(report) which import_flow picks up to show the
#      post-import summary dialog.
#
# The dialog does NOT itself execute the importer — it's a pure UI
# surface. That keeps the confirm/cancel contract clean and makes the
# dialog trivially testable by passing a pre-built preflight report.
#
# All user-facing strings go through tr().

@tool
class_name SceneExporterImportDialog
extends ConfirmationDialog


const Preflight := preload("res://addons/scene_exporter/core/preflight.gd")


signal import_requested(zip_path: String)


var _zip_path: String
var _target_project_path: String
var _preflight_report: Dictionary
var _tree: Tree
var _summary_label: Label
var _warnings_label: RichTextLabel


func _init(zip_path: String, target_project_path: String) -> void:
	_zip_path = zip_path
	_target_project_path = target_project_path

	title = tr("Import Scene Package")
	ok_button_text = tr("Import")
	cancel_button_text = tr("Cancel")
	min_size = Vector2i(640, 480)

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
	_tree.set_column_custom_minimum_width(1, 240)
	_tree.hide_root = true
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_tree)

	_warnings_label = RichTextLabel.new()
	_warnings_label.bbcode_enabled = true
	_warnings_label.fit_content = true
	_warnings_label.custom_minimum_size = Vector2(0, 60)
	root.add_child(_warnings_label)

	confirmed.connect(_on_confirmed)

	_run_preflight()
	_render()


func _run_preflight() -> void:
	var preflight: SceneExporterPreflight = Preflight.new()
	_preflight_report = preflight.check(_zip_path, _target_project_path)


func _render() -> void:
	_summary_label.text = _summary_text()
	get_ok_button().disabled = _preflight_report.overall == "errors"

	_tree.clear()
	var root: TreeItem = _tree.create_item()

	_render_section(root, tr("Godot version"), [_preflight_report.godot_version], func(e: Dictionary) -> Dictionary:
		return {
			"label": "%s → %s" % [e.get("source", "?"), e.get("target", "?")],
			"status": e.get("status", "ok"),
			"detail": "",
		}
	)
	_render_section(root, tr("Required plugins"), _preflight_report.plugins, func(e: Dictionary) -> Dictionary:
		var detail: String = ""
		if e.status == "missing" and e.install_hint != "":
			detail = e.install_hint
		return {
			"label": "%s  (%s)" % [e.name, e.path],
			"status": e.status,
			"detail": detail,
		}
	)
	_render_section(root, tr("Autoloads"), _preflight_report.autoloads, func(e: Dictionary) -> Dictionary:
		var detail: String = ""
		if e.status == "missing":
			detail = tr(
				"conflict: your project already has an autoload with this name ({value}). "
				+ "Change or remove it in Project → Project Settings → Globals, then import again."
			).format({"value": e.current_value})
		return {
			"label": "%s → %s" % [e.name, e.path],
			"status": e.status,
			"detail": detail,
		}
	)
	_render_section(root, tr("Project settings"), _preflight_report.settings, func(e: Dictionary) -> Dictionary:
		var detail: String = ""
		if e.status == "warn_overwrite":
			detail = tr("current: {current} → new: {new}").format({"current": str(e.current), "new": str(e.value)})
		return {
			"label": "%s = %s" % [e.key, str(e.value)],
			"status": e.status,
			"detail": detail,
		}
	)
	_render_section(root, tr("Files"), _preflight_report.files, func(e: Dictionary) -> Dictionary:
		var size_kb: float = float(e.size) / 1024.0
		return {
			"label": "%s  (%.1f KB)" % [e.path, size_kb],
			"status": e.status,
			"detail": "",
		}
	)

	_render_warnings()


func _render_section(root: TreeItem, heading: String, entries: Array, describe: Callable) -> void:
	if entries == null or entries.is_empty():
		return
	var section: TreeItem = _tree.create_item(root)
	section.set_text(0, heading)
	section.set_selectable(0, false)
	section.set_selectable(1, false)
	section.set_custom_color(0, Color(0.85, 0.85, 0.95))
	for raw: Variant in entries:
		if not (raw is Dictionary):
			continue
		var e: Dictionary = raw
		var desc: Dictionary = describe.call(e)
		var leaf: TreeItem = _tree.create_item(section)
		var label: String = "%s %s" % [_status_glyph(desc.status), desc.label]
		if desc.detail != "":
			label += "  —  %s" % desc.detail
		leaf.set_text(0, label)
		leaf.set_text(1, _status_label(desc.status))
		leaf.set_selectable(0, false)
		leaf.set_selectable(1, false)
		leaf.set_custom_color(1, _status_color(desc.status))


func _render_warnings() -> void:
	_warnings_label.clear()
	if _preflight_report.warnings.is_empty():
		return
	_warnings_label.append_text("[b]%s:[/b]\n" % tr("Warnings from exporter"))
	for w: String in _preflight_report.warnings:
		_warnings_label.append_text("  • %s\n" % w)


func _summary_text() -> String:
	return _overall_text() + _overwrite_text()


# Files the import will replace with different content. Shown above the tree
# so a beginner cannot miss it among dozens of "Will add" lines (19/10/2026).
func _overwrite_text() -> String:
	var replaced: Array[String] = []
	for raw: Variant in _preflight_report.files:
		if raw is Dictionary and String(raw.get("status", "")) == "warn_overwrite":
			replaced.append(String(raw.get("path", "")))
	if replaced.is_empty():
		return ""
	var text: String = "\n\n" + tr(
		"⚠ {count} file(s) of your project are different from the package and will be REPLACED. "
		+ "A copy of your current version will be saved in res://scene_exporter_backups/ first:"
	).format({"count": replaced.size()})
	var shown: int = mini(replaced.size(), 8)
	for i: int in range(shown):
		text += "\n  • %s" % replaced[i]
	if replaced.size() > shown:
		text += "\n  • …"
	return text


func _overall_text() -> String:
	match _preflight_report.overall:
		"errors":
			return tr("Cannot proceed — resolve errors first")
		"warnings":
			return tr("Review changes below before importing")
		_:
			# Could be "ok"; if there are literally no changes at all, say so.
			var has_work: bool = not _preflight_report.files.is_empty() \
				or not _preflight_report.autoloads.is_empty() \
				or not _preflight_report.settings.is_empty()
			if not has_work:
				return tr("No changes — package already matches target")
			return tr("Review changes below before importing")


func _on_confirmed() -> void:
	import_requested.emit(_zip_path)


# --- Status vocabulary rendering --------------------------------------------

func _status_glyph(status: String) -> String:
	match status:
		"ok": return "✓"
		"new": return "➕"
		"warn_overwrite": return "⚠"
		"missing": return "✖"
		"disabled": return "⚠"
		"mismatch": return "⚠"
		"skipped": return "—"
	return "·"


func _status_label(status: String) -> String:
	match status:
		"ok": return tr("Status: OK")
		"new": return tr("Will add")
		"warn_overwrite": return tr("Will overwrite")
		"missing": return tr("Missing")
		"disabled": return tr("Disabled")
		"mismatch": return tr("Conflict")
		"skipped": return tr("Skipped (target value kept)")
	return ""


func _status_color(status: String) -> Color:
	match status:
		"ok": return Color(0.55, 0.9, 0.55)
		"new": return Color(0.7, 0.85, 1.0)
		"warn_overwrite", "disabled", "mismatch": return Color(1.0, 0.8, 0.3)
		"missing": return Color(1.0, 0.45, 0.45)
		"skipped": return Color(0.7, 0.7, 0.7)
	return Color(1, 1, 1)
