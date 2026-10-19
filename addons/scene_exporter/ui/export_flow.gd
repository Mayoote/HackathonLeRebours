# export_flow.gd — user-facing driver for the export side. Owns the
# sequence: pick output path → plan → preview dialog (Phase 7) →
# progress panel → write → result dialog.
#
# Who calls: context_menu.gd when the user right-clicks a .tscn.
# Lifecycle: single-use. Create via `new(editor_interface, scene_res_path)`,
# call `begin()`, free once `finished` is emitted.

@tool
class_name SceneExporterExportFlow
extends RefCounted


const Exporter := preload("res://addons/scene_exporter/core/exporter.gd")
const ExportDialog := preload("res://addons/scene_exporter/ui/export_dialog.gd")
const ProgressPanel := preload("res://addons/scene_exporter/ui/progress_panel.gd")


signal finished(report: Dictionary)


var _editor_interface: EditorInterface
var _base_control: Control
var _scene_path: String
var _file_dialog: EditorFileDialog
var _export_dialog: ConfirmationDialog
var _progress: PopupPanel
var _result_dialog: AcceptDialog
var _chosen_output: String


func _init(editor_interface: EditorInterface, scene_res_path: String) -> void:
	_editor_interface = editor_interface
	_base_control = editor_interface.get_base_control()
	_scene_path = scene_res_path


func begin() -> void:
	_file_dialog = EditorFileDialog.new()
	_file_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_file_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	_file_dialog.title = tr("Save Scene Package")
	_file_dialog.add_filter("*.zip", tr("Scene Packages (*.zip)"))
	_file_dialog.current_file = _default_zip_name()
	_file_dialog.file_selected.connect(_on_output_selected)
	_file_dialog.canceled.connect(_on_cancelled)
	_base_control.add_child(_file_dialog)
	_file_dialog.popup_centered_ratio(0.7)


func _on_output_selected(zip_abs_path: String) -> void:
	_chosen_output = zip_abs_path

	# Planning does the dep-walk + scanners; it's fast for typical scenes
	# but still worth doing off the click handler so the preview dialog
	# never opens empty.
	var exporter := Exporter.new()
	var plan: Dictionary = exporter.plan(_scene_path)

	if not plan.get("errors", []).is_empty():
		_show_result({"ok": false, "errors": plan.errors, "warnings": plan.get("warnings", []), "files_written": 0, "zip_path": zip_abs_path})
		return

	_export_dialog = ExportDialog.new(plan)
	_export_dialog.export_confirmed.connect(_on_export_confirmed)
	_export_dialog.canceled.connect(_on_cancelled)
	_base_control.add_child(_export_dialog)
	_export_dialog.popup_centered()


func _on_export_confirmed(finalized_plan: Dictionary) -> void:
	var exporter := Exporter.new()

	_progress = ProgressPanel.new()
	_progress.setup(tr("Packaging scene..."))
	exporter.progress.connect(_progress.on_progress)
	_base_control.add_child(_progress)
	_progress.popup_centered()

	# Let the editor render the panel before the (mostly synchronous) zip
	# write blocks the main loop. Without this the user sees no feedback
	# on fast exports.
	await _base_control.get_tree().process_frame

	var report: Dictionary = exporter.write(finalized_plan, _chosen_output)

	if _progress != null:
		_progress.finish()
		_progress = null

	_show_result(report)


func _show_result(report: Dictionary) -> void:
	_result_dialog = AcceptDialog.new()
	var ok: bool = bool(report.get("ok", false))
	_result_dialog.title = tr("Export complete") if ok else tr("Export failed")
	_result_dialog.dialog_text = _format_result(report)
	_result_dialog.confirmed.connect(_on_cancelled)
	_result_dialog.canceled.connect(_on_cancelled)
	_base_control.add_child(_result_dialog)
	_result_dialog.popup_centered()


func _format_result(report: Dictionary) -> String:
	var lines: Array[String] = []
	var ok: bool = bool(report.get("ok", false))
	var errors: Array = report.get("errors", [])
	var warnings: Array = report.get("warnings", [])
	if not ok:
		lines.append(tr("Something went wrong:"))
		for e: Variant in errors:
			lines.append("  • %s" % String(e))
		return "\n".join(lines)
	lines.append(tr("{count} files packaged.").format({"count": report.get("files_written", 0)}))
	lines.append(String(report.get("zip_path", "")))
	if not warnings.is_empty():
		lines.append("")
		lines.append(tr("{count} warning(s):").format({"count": warnings.size()}))
		for w: Variant in warnings:
			lines.append("  • %s" % String(w))
	return "\n".join(lines)


func _default_zip_name() -> String:
	var stem: String = _scene_path.get_file().get_basename()
	return "%s_package.zip" % stem


func _on_cancelled() -> void:
	if _file_dialog != null:
		_file_dialog.queue_free()
		_file_dialog = null
	if _export_dialog != null:
		_export_dialog.queue_free()
		_export_dialog = null
	if _progress != null:
		_progress.queue_free()
		_progress = null
	if _result_dialog != null:
		_result_dialog.queue_free()
		_result_dialog = null
	finished.emit({})
