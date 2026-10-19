# context_menu.gd — FileSystem dock right-click integration.
#
# Adds two context items:
#   • "Export Scene Package..." when the user right-clicks a .tscn / .scn
#   • "Import Scene Package..."  when the user right-clicks a .zip
#
# Who instantiates: plugin.gd at _enter_tree(). Registered via
# EditorPlugin.add_context_menu_plugin(CONTEXT_SLOT_FILESYSTEM, ...).
#
# The flow objects (export_flow / import_flow) handle the actual work.
# This class is a thin dispatcher that translates selected paths into
# flow invocations.

@tool
class_name SceneExporterContextMenu
extends EditorContextMenuPlugin


const ExportFlow := preload("res://addons/scene_exporter/ui/export_flow.gd")
const ImportFlow := preload("res://addons/scene_exporter/ui/import_flow.gd")

const _EXPORT_ICON: String = "res://addons/scene_exporter/icons/export_action.svg"
const _IMPORT_ICON: String = "res://addons/scene_exporter/icons/import_action.svg"


var _editor_interface: EditorInterface
var _active_flows: Array = []
var _export_icon: Texture2D
var _import_icon: Texture2D


func _init(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface
	_export_icon = load(_EXPORT_ICON) as Texture2D
	_import_icon = load(_IMPORT_ICON) as Texture2D


func _popup_menu(paths: PackedStringArray) -> void:
	if paths.size() != 1:
		# Multi-select is out of scope for Phase 4 — one scene per package.
		return
	var path: String = paths[0]
	var ext: String = path.get_extension().to_lower()
	if ext == "tscn" or ext == "scn":
		add_context_menu_item(
			tr("Export Scene Package..."),
			_on_export_chosen.bind(path),
			_export_icon,
		)
	elif ext == "zip":
		add_context_menu_item(
			tr("Import Scene Package..."),
			_on_import_chosen.bind(path),
			_import_icon,
		)


func _on_export_chosen(_unused_paths: PackedStringArray, scene_path: String) -> void:
	var flow: SceneExporterExportFlow = ExportFlow.new(_editor_interface, scene_path)
	_active_flows.append(flow)
	flow.finished.connect(_clear_flow.bind(flow))
	flow.begin()


func _on_import_chosen(_unused_paths: PackedStringArray, zip_res_path: String) -> void:
	var zip_abs: String = ProjectSettings.globalize_path(zip_res_path)
	var flow: SceneExporterImportFlow = ImportFlow.new(_editor_interface)
	_active_flows.append(flow)
	flow.finished.connect(_clear_flow.bind(flow))
	flow.begin_with_zip(zip_abs)


func _clear_flow(_report: Variant, flow: RefCounted) -> void:
	_active_flows.erase(flow)
