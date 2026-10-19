# import_flow.gd — user-facing driver for the import side. Owns the
# sequence: pick a zip → preflight dialog → progress panel → apply →
# result dialog.
#
# Who calls: context_menu.gd (right-click .zip) or plugin.gd tool menu.
# Lifecycle: single-use. Create via `new(editor_interface)`, call
# `begin()` (prompts file picker) or `begin_with_zip(path)`, then free
# once `finished` is emitted.

@tool
class_name SceneExporterImportFlow
extends RefCounted


const ImportDialog := preload("res://addons/scene_exporter/ui/import_dialog.gd")
const ProgressPanel := preload("res://addons/scene_exporter/ui/progress_panel.gd")
const Importer := preload("res://addons/scene_exporter/core/importer.gd")


signal finished(report: Dictionary)


var _editor_interface: EditorInterface
var _base_control: Control
var _file_dialog: EditorFileDialog
var _import_dialog: ConfirmationDialog
var _progress: PopupPanel
var _result_dialog: AcceptDialog


func _init(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface
	_base_control = editor_interface.get_base_control()


func begin() -> void:
	_file_dialog = EditorFileDialog.new()
	_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	_file_dialog.title = tr("Choose a Scene Package")
	_file_dialog.add_filter("*.zip", tr("Scene Packages (*.zip)"))
	_file_dialog.file_selected.connect(_on_zip_selected)
	_file_dialog.canceled.connect(_on_cancelled)
	_base_control.add_child(_file_dialog)
	_file_dialog.popup_centered_ratio(0.7)


func begin_with_zip(zip_abs_path: String) -> void:
	_on_zip_selected(zip_abs_path)


func _on_zip_selected(zip_abs_path: String) -> void:
	var target_root: String = _project_root_abs()
	_import_dialog = ImportDialog.new(zip_abs_path, target_root)
	_import_dialog.import_requested.connect(_on_import_requested)
	_import_dialog.canceled.connect(_on_cancelled)
	_base_control.add_child(_import_dialog)
	_import_dialog.popup_centered()


func _on_import_requested(zip_abs_path: String) -> void:
	var importer := Importer.new()

	_progress = ProgressPanel.new()
	_progress.setup(tr("Importing package..."))
	importer.progress.connect(_progress.on_progress)
	_base_control.add_child(_progress)
	_progress.popup_centered()

	await _base_control.get_tree().process_frame

	var report: Dictionary = importer.import_package(zip_abs_path, _project_root_abs())

	if _progress != null:
		_progress.finish()
		_progress = null

	_show_result(report)
	_refresh_filesystem()


func _show_result(report: Dictionary) -> void:
	_result_dialog = AcceptDialog.new()
	_result_dialog.title = tr("Import complete") if report.ok else tr("Import failed")
	_result_dialog.dialog_text = _format_result_text(report)
	_result_dialog.confirmed.connect(_on_cancelled)
	_result_dialog.canceled.connect(_on_cancelled)
	_base_control.add_child(_result_dialog)
	_result_dialog.popup_centered()


func _format_result_text(report: Dictionary) -> String:
	var lines: Array[String] = []
	if not report.ok:
		lines.append(tr("Something went wrong:"))
		for e: String in report.errors:
			lines.append("  • %s" % e)
	else:
		lines.append(tr("{count} files written.").format({"count": report.files_written}))
		if report.autoloads_applied > 0:
			lines.append(tr("{count} autoloads registered (restart the editor to activate them).").format({"count": report.autoloads_applied}))
		if report.settings_applied > 0:
			lines.append(tr("{count} project settings updated.").format({"count": report.settings_applied}))
	var backed_up: Array = report.get("backed_up", [])
	if not backed_up.is_empty():
		lines.append("")
		lines.append(tr("{count} of your files were replaced. Your previous version of each one was saved in {path}:").format(
			{"count": backed_up.size(), "path": "res://" + String(report.get("backup_dir", ""))}
		))
		for b: Variant in backed_up:
			lines.append("  • %s" % String(b))
	if not report.warnings.is_empty():
		lines.append("")
		lines.append(tr("Notes:"))
		for w: String in report.warnings:
			lines.append("  • %s" % w)
	return "\n".join(lines)


func _refresh_filesystem() -> void:
	if _editor_interface == null:
		return
	var fs: EditorFileSystem = _editor_interface.get_resource_filesystem()
	if fs != null:
		fs.scan()


func _project_root_abs() -> String:
	return ProjectSettings.globalize_path("res://").trim_suffix("/")


func _on_cancelled() -> void:
	if _file_dialog != null:
		_file_dialog.queue_free()
		_file_dialog = null
	if _import_dialog != null:
		_import_dialog.queue_free()
		_import_dialog = null
	if _progress != null:
		_progress.queue_free()
		_progress = null
	if _result_dialog != null:
		_result_dialog.queue_free()
		_result_dialog = null
	finished.emit({})
