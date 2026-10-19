# progress_panel.gd — tiny modal shown while exporter/importer runs.
#
# Who uses it: ui/export_flow.gd + ui/import_flow.gd.
#
# Subscribe a panel to an exporter/importer's `progress(current, total,
# label)` signal; the panel updates its label and bar. The panel is
# popup-modal so the user cannot interact with the editor mid-operation
# (exporter + importer run on the main thread today).
#
# Typical use:
#   var panel := ProgressPanel.new()
#   panel.setup(tr("Packaging scene..."))
#   exporter.progress.connect(panel.on_progress)
#   base_control.add_child(panel)
#   panel.popup_centered()
#   var report = exporter.write(plan, zip_path)
#   panel.finish()           # queue_frees itself
#
# The panel is a PopupPanel so it has no OS chrome / close button —
# the user shouldn't be able to dismiss an in-flight operation.

@tool
class_name SceneExporterProgressPanel
extends PopupPanel


var _label: Label
var _bar: ProgressBar
var _detail: Label


func _init() -> void:
	min_size = Vector2i(420, 100)
	exclusive = true

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	_label = Label.new()
	vbox.add_child(_label)

	_bar = ProgressBar.new()
	_bar.min_value = 0
	_bar.max_value = 100
	_bar.value = 0
	_bar.custom_minimum_size = Vector2(380, 18)
	vbox.add_child(_bar)

	_detail = Label.new()
	_detail.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	vbox.add_child(_detail)


func setup(title_text: String) -> void:
	_label.text = title_text
	_detail.text = ""
	_bar.value = 0


func on_progress(current: int, total: int, label: String) -> void:
	if total <= 0:
		return
	_bar.max_value = total
	_bar.value = current
	_detail.text = "%d / %d  —  %s" % [current, total, label]


func finish() -> void:
	hide()
	queue_free()
