# plugin.gd — EditorPlugin entry point for the Scene Package Exporter.
#
# Registered in plugin.cfg. Loaded by the Godot editor when the plugin is
# enabled in Project Settings → Plugins.
#
# Responsibilities:
#   • Register translations (EN + FR) with the engine's TranslationServer.
#   • Install the FileSystem dock context menu for .tscn / .zip files.
#   • Register a "Project → Tools → Import Scene Package..." entry so the
#     import flow is discoverable without needing a .zip already in the
#     project tree.
#
# Invariant: must remain cheap to instantiate. No heavy work in _enter_tree,
# no file IO beyond loading the .po translations.

@tool
extends EditorPlugin


const PLUGIN_NAME: String = "scene_exporter"
const PLUGIN_VERSION: String = "0.1.1"

const ContextMenu := preload("res://addons/scene_exporter/context_menu.gd")
const ImportFlow := preload("res://addons/scene_exporter/ui/import_flow.gd")

const _I18N_PATHS: Array[String] = [
	"res://addons/scene_exporter/i18n/en.po",
	"res://addons/scene_exporter/i18n/fr.po",
]
const _IMPORT_MENU_LABEL: String = "Import Scene Package..."
const _PLUGIN_ICON: String = "res://addons/scene_exporter/icons/plugin_icon.svg"


var _context_menu: EditorContextMenuPlugin
var _active_flows: Array = []


func _enter_tree() -> void:
	print("[scene_exporter] hello from plugin.gd v%s" % PLUGIN_VERSION)
	_load_translations()
	_context_menu = ContextMenu.new(get_editor_interface())
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM, _context_menu)
	add_tool_menu_item(tr(_IMPORT_MENU_LABEL), _on_import_menu_pressed)


func _exit_tree() -> void:
	remove_tool_menu_item(tr(_IMPORT_MENU_LABEL))
	if _context_menu != null:
		remove_context_menu_plugin(_context_menu)
		_context_menu = null
	print("[scene_exporter] goodbye")


func _load_translations() -> void:
	for p: String in _I18N_PATHS:
		var t: Translation = load(p) as Translation
		if t == null:
			push_warning("[scene_exporter] could not load %s" % p)
			continue
		TranslationServer.add_translation(t)


func _on_import_menu_pressed() -> void:
	var flow: SceneExporterImportFlow = ImportFlow.new(get_editor_interface())
	_active_flows.append(flow)
	flow.finished.connect(func(_r): _active_flows.erase(flow))
	flow.begin()


func _get_plugin_name() -> String:
	return "Scene Package Exporter"


func _get_plugin_icon() -> Texture2D:
	# Shown next to the plugin name in the main editor UI where plugins
	# expose a dock or screen. We don't own a screen, but returning an
	# icon here also seeds the editor's plugin list entry.
	var tex: Texture2D = load(_PLUGIN_ICON) as Texture2D
	return tex
