tool
extends EditorPlugin


const MainPanel = preload("res://addons/beat_map_editor/ui/beat_map_editor/beat_map_editor.tscn")

var main_panel_instance

func _enter_tree():
	main_panel_instance = MainPanel.instance()
	get_editor_interface().get_editor_viewport().add_child(main_panel_instance)
	make_visible(false)

func _exit_tree():
	if main_panel_instance:
		main_panel_instance.queue_free()

func has_main_screen():
	return true

func make_visible(visible):
	if main_panel_instance:
		main_panel_instance.visible = visible

func get_plugin_name():
	return "BeatMapEditor"

func get_plugin_icon():
	return get_editor_interface().get_base_control().get_icon("Node", "EditorIcons")
