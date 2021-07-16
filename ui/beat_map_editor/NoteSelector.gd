tool
extends MarginContainer

onready var _notes_container = $VBoxContainer/ScrollContainer/NotesContainer
onready var _scene = get_owner()

signal note_selection_changed
const NoteButton = preload("res://addons/beat_map_editor/ui/note_button/note_button.tscn")
var selected_note = 0

var _mode = "normal"
var _selection = null

func _ready():
	call_deferred("refresh")

func refresh():
	var tile_ids = _scene.tileset.get_tiles_ids()
	print(_scene.keyboard_note_shortcuts_inv)
	for note in _notes_container.get_children():
		note.queue_free()
	for tile_id in tile_ids:
		if not _scene.display_note_id_in_note_selector(_scene.tileset, tile_id):
			continue
		var tile_name = _scene.tileset.tile_get_name(tile_id)
		var button = NoteButton.instance()
		button.texture_normal = _scene.get_texture_atlas(_scene.tileset, tile_id)
		button.rect_min_size = Vector2(0, 32)
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.expand = true
		button.connect("gui_input", self, "_on_note_button_gui_input", [tile_name, button])
		if tile_name in _scene.keyboard_note_shortcuts_inv:
			var scancode = _scene.keyboard_note_shortcuts_inv[tile_name]
			button.get_node("Shortcut").text = OS.get_scancode_string(scancode) + str(_scene.keyboard_note_shortcuts[scancode].x)
		else:
			button.get_node("Shortcut").text = ""
		_notes_container.add_child(button)

func _on_note_button_gui_input(event, tile_name, button):
	if event is InputEventMouseButton:
		if event.pressed:
			match event.button_index:
				BUTTON_LEFT:
					selected_note = tile_name
					emit_signal("note_selection_changed", selected_note)
				BUTTON_RIGHT:
					if _mode == "normal":
						_mode = "select_shortcut"
						_selection = {
							tile_name = tile_name,
							button = button
						}
						button.get_node("Shortcut").text = "_"
					elif _mode == "select_shortcut":
						_mode = "normal"
						button.get_node("Shortcut").text = ""
						_scene.keyboard_note_shortcuts.erase(_scene.keyboard_note_shortcuts_inv[tile_name])
						_scene.keyboard_note_shortcuts_inv.erase(tile_name)

func _input(event):
	if event is InputEventKey:
		if event.pressed and _mode == "select_shortcut":
			if KEY_0 <= event.scancode and event.scancode <= KEY_9:
				_selection.button.get_node("Shortcut").text = OS.get_scancode_string(_scene.keyboard_note_shortcuts_inv[_selection.tile_name]) + str(event.scancode - KEY_0)
				
				var scancode = int(_scene.keyboard_note_shortcuts_inv[_selection.tile_name])
				_scene.keyboard_note_shortcuts[scancode].x = event.scancode - KEY_0
				_mode = "normal"
			else:
				_selection.button.get_node("Shortcut").text = OS.get_scancode_string(event.scancode)
				if _selection.tile_name in _scene.keyboard_note_shortcuts_inv:
					_scene.keyboard_note_shortcuts.erase(_scene.keyboard_note_shortcuts_inv[_selection.tile_name])
				_scene.keyboard_note_shortcuts[event.scancode] = {
					tile_name= _selection.tile_name,
					x = -1
				} 
				_scene.keyboard_note_shortcuts_inv[_selection.tile_name] = event.scancode
				_mode = "normal"
			return true
